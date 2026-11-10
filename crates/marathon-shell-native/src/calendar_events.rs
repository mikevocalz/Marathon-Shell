//! The same permission-gated calendar cache the native Calendar app reads.

use std::pin::Pin;

use async_channel::Sender;
use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::{QList, QString, QVariant};
use futures_lite::{future, StreamExt};
use zbus::{MatchRule, MessageStream, OwnedVariant};

use crate::{io, log};

#[cxx_qt::bridge(namespace = "marathon")]
pub mod qobject {
    #[namespace = ""]
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qlist.h");
        type QList_QVariant = cxx_qt_lib::QList<cxx_qt_lib::QVariant>;
    }

    extern "RustQt" {
        #[qobject]
        #[qproperty(QList_QVariant, events, READ, NOTIFY)]
        #[qproperty(QString, state, READ, NOTIFY)]
        type CalendarEventsClient = super::CalendarEventsClientRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut CalendarEventsClient>);
    }

    impl cxx_qt::Threading for CalendarEventsClient {}
    impl cxx_qt::Initialize for CalendarEventsClient {}
}

use qobject::CalendarEventsClient;

const BUS: &str = "org.marathonos.Dav";
const PATH: &str = "/org/marathonos/Shell/CalendarEvents";
const INTERFACE: &str = "org.marathonos.Shell.CalendarEvents1";
type Qt = cxx_qt::CxxQtThread<CalendarEventsClient>;

#[derive(Default)]
pub struct CalendarEventsClientRust {
    events: QList<QVariant>,
    state: QString,
    generation: u64,
    // The QObject owns the only sender; drop wakes the subscription's receiver.
    stop: Option<Sender<()>>,
}

async fn watch(qt: &Qt) -> zbus::Result<()> {
    let bus = io::session_bus().await?;
    let rule = MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(BUS)
        .path(PATH)
        .interface(INTERFACE)
        .member("EventsChanged")
        .build()?;
    let changed = MessageStream::for_match_rule(rule, &bus, None).await?;
    let dbus = zbus::fdo::DBusProxy::new(&bus).await?;
    let owners = dbus
        .receive_name_owner_changed_with_args(&[(0, BUS)])
        .await?;
    let changed = changed.map(|_| ()).or(owners.map(|_| ()));
    let mut changed = std::pin::pin!(changed);
    qt.queue(CalendarEventsClient::refresh).ok();
    while changed.next().await.is_some() {
        qt.queue(CalendarEventsClient::refresh).ok();
    }
    Ok(())
}

impl cxx_qt::Initialize for CalendarEventsClient {
    fn initialize(mut self: Pin<&mut Self>) {
        let (stop, stopped) = async_channel::bounded(1);
        self.as_mut().rust_mut().stop = Some(stop);
        let qt = self.qt_thread();
        io::spawn(async move {
            future::or(
                async {
                    if let Err(error) = watch(&qt).await {
                        log::warn("CalendarEvents", format_args!("subscription: {error}"));
                        qt.queue(|mut obj| {
                            obj.as_mut().rust_mut().state = QString::from("unavailable");
                            obj.state_changed();
                        })
                        .ok();
                    }
                },
                async {
                    stopped.recv().await.ok();
                },
            )
            .await;
        });
    }
}

impl CalendarEventsClient {
    fn refresh(mut self: Pin<&mut Self>) {
        self.as_mut().rust_mut().generation += 1;
        let generation = self.generation;
        self.as_mut().rust_mut().state = QString::from("loading");
        self.as_mut().state_changed();
        let qt = self.qt_thread();
        io::spawn(async move {
            let events = async {
                io::session_bus()
                    .await?
                    .call_method(Some(BUS), PATH, Some(INTERFACE), "ListEvents", &())
                    .await?
                    .body()
                    .deserialize::<Vec<OwnedVariant>>()
            }
            .await;
            qt.queue(move |mut obj| {
                if obj.generation != generation {
                    return;
                }
                match events {
                    Ok(events) => {
                        let mut rust = obj.as_mut().rust_mut();
                        rust.events = marathon_qt::qlist(&events);
                        rust.state = QString::from("ready");
                        obj.as_mut().events_changed();
                    }
                    Err(error) => {
                        log::warn("CalendarEvents", format_args!("cache: {error}"));
                        obj.as_mut().rust_mut().state = QString::from("unavailable");
                    }
                }
                obj.state_changed();
            })
            .ok();
        });
    }
}
