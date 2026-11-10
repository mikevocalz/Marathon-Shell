//! Client half of NativeUI_NotesWire. Its provider is the real NotesApp QML,
//! on an isolated D-Bus session with a private Configuration file.

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

use marathon_rt::io;
use serde_json::{json, Value};

mod notes_task;

struct Navigation {
    calls: Arc<AtomicUsize>,
}

// Only the shell's background-start admission is a fixture. It does not
// simulate Notes, Keel, action validation, storage, or the selected editor.
#[zbus::interface(name = "org.marathonos.Shell.Navigation1")]
impl Navigation {
    fn start_app_in_background(&self, app_id: &str) -> bool {
        if app_id != "notes" {
            return false;
        }
        self.calls.fetch_add(1, Ordering::SeqCst);
        true
    }
}

async fn run() -> Result<Value, String> {
    if std::env::var_os("DBUS_SESSION_BUS_ADDRESS").is_none() {
        return Err("the required private D-Bus session is missing".into());
    }
    let calls = Arc::new(AtomicUsize::new(0));
    let _shell = zbus::connection::Builder::session()
        .name("org.marathonos.Shell")
        .serve_at(
            "/org/marathonos/Shell/Navigation",
            Navigation {
                calls: Arc::clone(&calls),
            },
        )
        .build()
        .await
        .map_err(|error| format!("could not register background-start fixture: {error}"))?;
    let mut evidence = notes_task::exercise().await?;
    let wake_count = calls.load(Ordering::SeqCst);
    if wake_count != 4 {
        return Err(format!(
            "expected background-start admission on all four preparations, got {wake_count}"
        ));
    }
    evidence["background_start_calls"] = json!(wake_count);
    Ok(evidence)
}

fn main() {
    match async_io::block_on(run()) {
        Ok(evidence) => println!("{evidence}"),
        Err(error) => {
            eprintln!("[notes-wire] FAIL: {error}");
            std::process::exit(1);
        }
    }
}
