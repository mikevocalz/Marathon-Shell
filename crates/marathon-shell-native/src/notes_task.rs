//! A retained, single-flight Hub capture client. Only admission and publishing
//! run on the GUI thread; the owned operation runs on marathon-rt's I/O actor.

mod model;
mod transport;

use std::pin::Pin;

use async_channel::{Receiver, Sender};
use cxx_qt::{CxxQtThread, CxxQtType, Threading};
use cxx_qt_lib::{QMap, QMapPair_QString_QVariant, QString};
use futures_lite::future;
use serde_json::json;

use crate::{io, variant};
use model::{Capture, DispatchGate, Error, State};

#[cxx_qt::bridge(namespace = "marathon")]
pub mod qobject {
    #[namespace = ""]
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qmap.h");
        type QMap_QString_QVariant = cxx_qt_lib::QMap<cxx_qt_lib::QMapPair_QString_QVariant>;
    }

    extern "RustQt" {
        #[qobject]
        /// One atomic view of the operation: state, optional error, optional taskId.
        #[qproperty(QMap_QString_QVariant, snapshot, READ, NOTIFY)]
        /// Shared by home Hub and Peek; remains alive when their views recycle.
        #[qproperty(QMap_QString_QVariant, draft, READ, NOTIFY)]
        type NotesTaskClient = super::NotesTaskClientRust;

        /// Copies one notification snapshot; never replaces an existing flow.
        #[qinvokable]
        #[cxx_name = "beginCapture"]
        fn begin_capture(self: Pin<&mut NotesTaskClient>, seed: &QMap_QString_QVariant) -> bool;
        /// Changes only title/body while the unsent draft is editable.
        #[qinvokable]
        #[cxx_name = "updateDraft"]
        fn update_draft(self: Pin<&mut NotesTaskClient>, edits: &QMap_QString_QVariant) -> bool;
        /// Checks the installed action contract; may start/wake Notes.
        #[qinvokable]
        #[cxx_name = "checkAvailable"]
        fn check_available(self: Pin<&mut NotesTaskClient>) -> bool;
        /// True means admitted, never that Notes has created a task.
        #[qinvokable]
        #[cxx_name = "createTask"]
        fn create_task(self: Pin<&mut NotesTaskClient>) -> bool;
        /// Opens only the exact identity returned by this capture's create call.
        #[qinvokable]
        #[cxx_name = "openTask"]
        fn open_task(self: Pin<&mut NotesTaskClient>) -> bool;
        /// Cancels only before Invoke is admitted. False means it is too late.
        #[qinvokable]
        #[cxx_name = "cancelPreparation"]
        fn cancel_preparation(self: Pin<&mut NotesTaskClient>) -> bool;
        /// Clears a finished/rejected capture. An uncertain create needs the
        /// separate explicit acknowledgement below; neither permits busy reset.
        #[qinvokable]
        fn reset(self: Pin<&mut NotesTaskClient>) -> bool;
        #[qinvokable]
        #[cxx_name = "acknowledgeUnknown"]
        fn acknowledge_unknown(self: Pin<&mut NotesTaskClient>) -> bool;
    }

    impl cxx_qt::Threading for NotesTaskClient {}
}

use qobject::NotesTaskClient;

type Qt = CxxQtThread<NotesTaskClient>;

struct Operation {
    gate: DispatchGate,
    // The only sender: dropping the QObject or cancelling preparation releases
    // the owned future. There is no remote cancellation method in Keel's ABI.
    _lifetime: Sender<()>,
}

impl Drop for Operation {
    fn drop(&mut self) {
        // A queued preparation may become ready at the same instant its Qt
        // owner is destroyed. Close the dispatch gate before dropping the
        // channel; otherwise polling the ready I/O branch first could send it.
        self.gate.cancel();
    }
}

pub struct NotesTaskClientRust {
    snapshot: QMap<QMapPair_QString_QVariant>,
    draft: QMap<QMapPair_QString_QVariant>,
    capture: Option<Capture>,
    state: State,
    generation: u64,
    operation: Option<Operation>,
}

impl Default for NotesTaskClientRust {
    fn default() -> Self {
        Self {
            snapshot: variant::map(&State::Idle.snapshot()),
            draft: QMap::default(),
            capture: None,
            state: State::Idle,
            generation: 0,
            operation: None,
        }
    }
}

impl NotesTaskClient {
    fn publish_draft(mut self: Pin<&mut Self>, capture: Option<Capture>) {
        if self.capture == capture {
            return;
        }
        {
            let mut rust = self.as_mut().rust_mut();
            rust.draft = capture
                .as_ref()
                .map(|capture| variant::map(&capture.draft()))
                .unwrap_or_default();
            rust.capture = capture;
        }
        self.draft_changed();
    }

    fn begin_capture(mut self: Pin<&mut Self>, seed: &QMap<QMapPair_QString_QVariant>) -> bool {
        if self.capture.is_some() || self.state != State::Idle {
            return false;
        }
        let capture = (|| {
            Ok::<_, Error>(Capture {
                title: string_field(seed, "title")?,
                body: string_field(seed, "body")?,
                source_id: string_field(seed, "sourceId")?,
                source_label: string_field(seed, "sourceLabel")?,
            })
        })();
        let Ok(capture) = capture else {
            return false;
        };
        self.as_mut().publish_draft(Some(capture));
        self.check_available();
        true
    }

    fn update_draft(mut self: Pin<&mut Self>, edits: &QMap<QMapPair_QString_QVariant>) -> bool {
        if self.state.busy()
            || self.state.task_id().is_some()
            || matches!(self.state, State::Unknown(_))
        {
            return false;
        }
        let Some(mut capture) = self.capture.clone() else {
            return false;
        };
        let (Ok(title), Ok(body)) = (string_field(edits, "title"), string_field(edits, "body"))
        else {
            return false;
        };
        capture.title = title;
        capture.body = body;
        self.as_mut().publish_draft(Some(capture));
        true
    }

    fn publish(mut self: Pin<&mut Self>, state: State) {
        {
            let mut rust = self.as_mut().rust_mut();
            rust.state = state;
            rust.snapshot = variant::map(&state.snapshot());
        }
        self.snapshot_changed();
    }

    fn begin(mut self: Pin<&mut Self>, state: State) -> (u64, DispatchGate, Receiver<()>) {
        let (sender, receiver) = async_channel::bounded(1);
        let gate = DispatchGate::default();
        let generation = {
            let mut rust = self.as_mut().rust_mut();
            rust.generation = rust.generation.wrapping_add(1);
            rust.operation = Some(Operation {
                gate: gate.clone(),
                _lifetime: sender,
            });
            rust.generation
        };
        self.publish(state);
        (generation, gate, receiver)
    }

    fn finish(mut self: Pin<&mut Self>, generation: u64, state: State) {
        if self.generation != generation || !self.state.busy() {
            return;
        }
        self.as_mut().rust_mut().operation = None;
        self.publish(state);
    }

    fn check_available(mut self: Pin<&mut Self>) -> bool {
        if self.capture.is_none()
            || !matches!(
                self.state,
                State::Idle | State::Ready | State::Unavailable(_) | State::Rejected(_)
            )
        {
            return false;
        }
        let (generation, _, lifetime) = self.as_mut().begin(State::Checking);
        let qt = self.qt_thread();
        let result = io::try_spawn(async move {
            let result = future::or(
                async {
                    Some(match transport::prepare_session().await {
                        Ok(_) => State::Ready,
                        Err(error) => State::Unavailable(error),
                    })
                },
                async {
                    // Channel closure is the lifetime signal, not a failure.
                    let _end_of_lifetime = lifetime.recv().await;
                    None
                },
            )
            .await;
            if let Some(state) = result {
                complete(&qt, generation, state);
            }
        });
        if result.is_err() {
            self.finish(generation, State::Unavailable(Error::Executor));
            return false;
        }
        true
    }

    fn create_task(mut self: Pin<&mut Self>) -> bool {
        if !self.state.can_create() {
            return false;
        }
        let arguments = self
            .capture
            .as_ref()
            .ok_or(Error::InvalidInput)
            .and_then(Capture::arguments);
        let arguments = match arguments {
            Ok(arguments) => arguments,
            Err(error) => {
                self.publish(State::Rejected(error));
                return false;
            }
        };
        let (generation, gate, lifetime) = self.as_mut().begin(State::Preparing);
        let qt = self.qt_thread();
        let result = io::try_spawn(async move {
            let result = future::or(
                async {
                    let prepared = match transport::prepare_session().await {
                        Ok(prepared) => prepared,
                        Err(error) => return Some(State::Rejected(error)),
                    };
                    if !gate.dispatch() {
                        return None;
                    }
                    if let Err(error) = qt.queue(move |obj| {
                        if obj.generation == generation && obj.state == State::Preparing {
                            obj.publish(State::Creating);
                        }
                    }) {
                        report_queue_failure(&error);
                        // Do not send the mutation when its GUI admission
                        // cannot be published. No Invoke has happened yet.
                        return Some(State::Rejected(Error::Executor));
                    }
                    Some(
                        match prepared
                            .invoke("tasks.create", &arguments, transport::INVOKE_TIMEOUT)
                            .await
                        {
                            Ok(id) => State::Created(id),
                            Err(error) => State::Unknown(error),
                        },
                    )
                },
                async {
                    // Channel closure is the lifetime signal, not a failure.
                    let _end_of_lifetime = lifetime.recv().await;
                    None
                },
            )
            .await;
            if let Some(state) = result {
                complete(&qt, generation, state);
            }
        });
        if result.is_err() {
            self.finish(generation, State::Rejected(Error::Executor));
            return false;
        }
        true
    }

    fn open_task(mut self: Pin<&mut Self>) -> bool {
        if self.state.busy() {
            return false;
        }
        let Some(id) = self.state.task_id() else {
            return false;
        };
        let (generation, gate, lifetime) = self.as_mut().begin(State::Opening(id));
        let qt = self.qt_thread();
        let result = io::try_spawn(async move {
            let result = future::or(
                async {
                    let result = async {
                        let prepared = transport::prepare_session().await?;
                        if !gate.dispatch() {
                            return Err(Error::Unavailable);
                        }
                        let opened = prepared
                            .invoke("notes.open", &json!({"id": id}), transport::INVOKE_TIMEOUT)
                            .await?;
                        if opened != id {
                            return Err(Error::InvalidResult);
                        }
                        Ok(())
                    }
                    .await;
                    Some(match result {
                        Ok(()) => State::Opened(id),
                        Err(error) => State::OpenFailed(id, error),
                    })
                },
                async {
                    // Channel closure is the lifetime signal, not a failure.
                    let _end_of_lifetime = lifetime.recv().await;
                    None
                },
            )
            .await;
            if let Some(state) = result {
                complete(&qt, generation, state);
            }
        });
        if result.is_err() {
            self.finish(generation, State::OpenFailed(id, Error::Executor));
            return false;
        }
        true
    }

    fn cancel_preparation(mut self: Pin<&mut Self>) -> bool {
        if !matches!(self.state, State::Checking | State::Preparing) {
            return false;
        }
        if !self
            .operation
            .as_ref()
            .is_some_and(|operation| operation.gate.cancel())
        {
            return false;
        }
        let state = if self.state == State::Checking {
            State::Idle
        } else {
            State::Ready
        };
        self.as_mut().rust_mut().generation = self.generation.wrapping_add(1);
        self.as_mut().rust_mut().operation = None;
        self.publish(state);
        true
    }

    fn reset(mut self: Pin<&mut Self>) -> bool {
        if self.state.busy() || matches!(self.state, State::Unknown(_)) {
            return false;
        }
        self.as_mut().rust_mut().generation = self.generation.wrapping_add(1);
        self.as_mut().publish_draft(None);
        self.publish(State::Idle);
        true
    }

    fn acknowledge_unknown(mut self: Pin<&mut Self>) -> bool {
        if !matches!(self.state, State::Unknown(_)) {
            return false;
        }
        self.as_mut().rust_mut().generation = self.generation.wrapping_add(1);
        self.as_mut().publish_draft(None);
        self.publish(State::Idle);
        true
    }
}

fn string_field(map: &QMap<QMapPair_QString_QVariant>, key: &str) -> Result<String, Error> {
    map.get(&QString::from(key))
        .filter(|value| value.type_name() == "QString")
        .and_then(|value| value.value::<QString>())
        .map(|value| value.to_string())
        .ok_or(Error::InvalidInput)
}

fn complete(qt: &Qt, generation: u64, state: State) {
    // A destroyed QObject rejects the queue. A cancelled/replaced request is
    // ignored by finish, so its late reply cannot overwrite a newer capture.
    if let Err(error) = qt.queue(move |obj| obj.finish(generation, state)) {
        report_queue_failure(&error);
    }
}

fn report_queue_failure(error: &cxx_qt::ThreadingQueueError) {
    // Destruction is an expected shutdown path. Other dispatch failures are
    // diagnostic errors; the object must still never be touched off-thread.
    if !matches!(error, cxx_qt::ThreadingQueueError::ObjectDestroyed) {
        crate::log::warn(
            "notes-task",
            format_args!("cannot publish capture state: {error}"),
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dropping_owner_closes_preparation_dispatch_gate() {
        let (sender, receiver) = async_channel::bounded(1);
        let gate = DispatchGate::default();
        drop(Operation {
            gate: gate.clone(),
            _lifetime: sender,
        });
        assert!(!gate.dispatch());
        assert!(receiver.is_closed());
    }

    #[test]
    fn dropping_owner_does_not_claim_to_cancel_dispatched_action() {
        let (sender, _) = async_channel::bounded(1);
        let gate = DispatchGate::default();
        assert!(gate.dispatch());
        drop(Operation {
            gate: gate.clone(),
            _lifetime: sender,
        });
        assert!(!gate.cancel());
        assert!(!gate.dispatch());
    }
}
