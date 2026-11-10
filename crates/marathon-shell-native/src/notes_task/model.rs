//! The capture's admission and lifetime rules, independent of Qt and D-Bus.

use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::Arc;

use serde_json::{json, Value};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum Error {
    Unavailable,
    Unsupported,
    InvalidInput,
    Transport,
    Timeout,
    InvalidResult,
    Executor,
}

impl Error {
    fn code(self) -> &'static str {
        match self {
            Self::Unavailable => "unavailable",
            Self::Unsupported => "unsupported",
            Self::InvalidInput => "invalid-input",
            Self::Transport => "transport",
            Self::Timeout => "timeout",
            Self::InvalidResult => "invalid-result",
            Self::Executor => "executor",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum State {
    Idle,
    Checking,
    Ready,
    Unavailable(Error),
    Preparing,
    Creating,
    Rejected(Error),
    Created(i32),
    Unknown(Error),
    Opening(i32),
    Opened(i32),
    OpenFailed(i32, Error),
}

impl State {
    pub(super) fn busy(self) -> bool {
        matches!(
            self,
            Self::Checking | Self::Preparing | Self::Creating | Self::Opening(_)
        )
    }

    pub(super) fn can_create(self) -> bool {
        matches!(self, Self::Ready | Self::Rejected(_))
    }

    pub(super) fn task_id(self) -> Option<i32> {
        match self {
            Self::Created(id) | Self::Opening(id) | Self::Opened(id) | Self::OpenFailed(id, _) => {
                Some(id)
            }
            _ => None,
        }
    }

    pub(super) fn snapshot(self) -> Value {
        let (name, error) = match self {
            Self::Idle => ("idle", None),
            Self::Checking => ("checking", None),
            Self::Ready => ("ready", None),
            Self::Unavailable(error) => ("unavailable", Some(error)),
            Self::Preparing => ("preparing", None),
            Self::Creating => ("creating", None),
            Self::Rejected(error) => ("rejected", Some(error)),
            Self::Created(_) => ("created", None),
            Self::Unknown(error) => ("unknown", Some(error)),
            Self::Opening(_) => ("opening", None),
            Self::Opened(_) => ("opened", None),
            Self::OpenFailed(_, error) => ("open-failed", Some(error)),
        };
        let mut value = json!({"state": name});
        if let Some(error) = error {
            value["error"] = json!(error.code());
        }
        if let Some(id) = self.task_id() {
            value["taskId"] = json!(id);
        }
        value
    }
}

/// Only one side can win: cancel before dispatch, or admit the single Invoke.
/// Dropping a future after dispatch does not cancel an action in Notes.
#[derive(Clone, Default)]
pub(super) struct DispatchGate(Arc<AtomicU8>);

impl DispatchGate {
    pub(super) fn dispatch(&self) -> bool {
        self.0
            .compare_exchange(0, 1, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
    }

    pub(super) fn cancel(&self) -> bool {
        self.0
            .compare_exchange(0, 2, Ordering::AcqRel, Ordering::Acquire)
            .is_ok()
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Capture {
    pub title: String,
    pub body: String,
    pub source_id: String,
    pub source_label: String,
}

impl Capture {
    pub(super) fn draft(&self) -> Value {
        json!({"title": self.title, "body": self.body, "sourceId": self.source_id, "sourceLabel": self.source_label})
    }

    pub(super) fn arguments(&self) -> Result<Value, Error> {
        // Keel/Qt count UTF-16 code units. Match that boundary, including emoji.
        let length = |value: &str| value.encode_utf16().count();
        if self.title.trim().is_empty()
            || length(&self.title) > 200
            || length(&self.body) > 20_000
            || self.source_id.is_empty()
            || length(&self.source_id) > 512
            || self.source_label.trim().is_empty()
            || length(&self.source_label) > 200
        {
            return Err(Error::InvalidInput);
        }
        Ok(json!({
            "title": self.title,
            "body": self.body,
            "source": {
                "kind": "notification",
                "appId": "org.marathonos.hub",
                "itemId": self.source_id,
                "label": self.source_label,
            },
        }))
    }
}

pub(super) fn result_id(value: &Value) -> Result<i32, Error> {
    let object = value.as_object().ok_or(Error::InvalidResult)?;
    if object.len() != 1 {
        return Err(Error::InvalidResult);
    }
    object
        .get("id")
        .and_then(Value::as_i64)
        .and_then(|id| i32::try_from(id).ok())
        .filter(|id| *id > 0)
        .ok_or(Error::InvalidResult)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn draft() -> Capture {
        Capture {
            title: "Review the document".into(),
            body: "Keep this editable text".into(),
            source_id: "notification:42:123456".into(),
            source_label: "Mail notification".into(),
        }
    }

    #[test]
    fn input_is_bounded_without_truncation_or_provider_identity() -> Result<(), Error> {
        let mut capture = draft();
        let value = capture.arguments()?;
        assert_eq!(value["body"], capture.body);
        assert_eq!(value["source"]["kind"], "notification");
        assert_eq!(value["source"]["appId"], "org.marathonos.hub");
        capture.title = "📝".repeat(100);
        assert!(capture.arguments().is_ok());
        capture.title.push('x');
        assert_eq!(capture.arguments(), Err(Error::InvalidInput));
        capture = draft();
        capture.body = "x".repeat(20_001);
        assert_eq!(capture.arguments(), Err(Error::InvalidInput));
        capture = draft();
        capture.title = " \n\t".into();
        assert_eq!(capture.arguments(), Err(Error::InvalidInput));
        Ok(())
    }

    #[test]
    fn successful_identity_is_exact_and_bounded() {
        for value in [
            json!({}),
            json!({"id":0}),
            json!({"id":-1}),
            json!({"id":2_147_483_648_i64}),
            json!({"id":"7"}),
            json!({"id":7.5}),
            json!({"id":7.0}),
            json!({"id":true}),
            json!({"id":7,"extra":true}),
        ] {
            assert_eq!(result_id(&value), Err(Error::InvalidResult), "{value}");
        }
        assert_eq!(result_id(&json!({"id":2_147_483_647})), Ok(i32::MAX));
    }

    #[test]
    fn cancellation_and_dispatch_are_mutually_exclusive() {
        let gate = DispatchGate::default();
        assert!(gate.cancel());
        assert!(!gate.dispatch());
        let gate = DispatchGate::default();
        assert!(gate.dispatch());
        assert!(!gate.cancel());
        assert!(!gate.dispatch());
    }

    #[test]
    fn pending_or_uncertain_creation_cannot_be_replayed() {
        for state in [
            State::Checking,
            State::Preparing,
            State::Creating,
            State::Unknown(Error::Timeout),
            State::Created(7),
            State::Opening(7),
            State::OpenFailed(7, Error::Transport),
            State::Opened(7),
        ] {
            assert!(!state.can_create(), "{state:?}");
        }
        assert!(State::Ready.can_create());
        assert!(State::Rejected(Error::Unavailable).can_create());
    }
}
