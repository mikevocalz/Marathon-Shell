//! Include production code by path so wire drift fails the integration gate.

#[allow(
    dead_code,
    reason = "the UI state machine is tested by the primary Rust suite"
)]
#[path = "../../../../crates/marathon-shell-native/src/notes_task/model.rs"]
mod model;
#[path = "../../../../crates/marathon-shell-native/src/notes_task/transport.rs"]
mod transport;

use model::Capture;
use serde_json::{json, Value};

pub(super) async fn exercise() -> Result<Value, String> {
    // A capability check and every operation prepare independently, as the
    // real retained client does. Even a running owner must be woken first.
    transport::prepare_session()
        .await
        .map_err(|error| format!("real Notes capability discovery failed: {error:?}"))?;
    let capture = Capture {
        title: "Review <b>contract</b>".into(),
        body: "Captured notification body 📝\nKeep this text editable.".into(),
        source_id: "notification:42:1700000000000".into(),
        source_label: "<b>Mail</b> notification".into(),
    };
    let prepared = transport::prepare_session()
        .await
        .map_err(|error| format!("prepare capture failed: {error:?}"))?;
    let capture_id = prepared
        .invoke(
            "tasks.create",
            &capture
                .arguments()
                .map_err(|error| format!("capture input: {error:?}"))?,
            transport::INVOKE_TIMEOUT,
        )
        .await
        .map_err(|error| format!("real tasks.create failed: {error:?}"))?;
    if capture_id != 1 {
        return Err(format!(
            "isolated empty Notes should allocate id 1, got {capture_id}"
        ));
    }

    // A newer task prevents a generic show/latest-note fallback from passing.
    let decoy = Capture {
        title: "Newer decoy".into(),
        body: "This must not be the editor selected by notes.open.".into(),
        source_id: "notification:43:1700000000001".into(),
        source_label: "Calendar notification".into(),
    };
    let prepared = transport::prepare_session()
        .await
        .map_err(|error| format!("prepare second capture failed: {error:?}"))?;
    let second_id = prepared
        .invoke(
            "tasks.create",
            &decoy
                .arguments()
                .map_err(|error| format!("second input: {error:?}"))?,
            transport::INVOKE_TIMEOUT,
        )
        .await
        .map_err(|error| format!("second real tasks.create failed: {error:?}"))?;
    if second_id != 2 {
        return Err(format!("second allocation must be id 2, got {second_id}"));
    }

    let prepared = transport::prepare_session()
        .await
        .map_err(|error| format!("prepare exact open failed: {error:?}"))?;
    let opened_id = prepared
        .invoke(
            "notes.open",
            &json!({"id": capture_id}),
            transport::INVOKE_TIMEOUT,
        )
        .await
        .map_err(|error| format!("real notes.open failed: {error:?}"))?;
    if opened_id != capture_id {
        return Err(format!(
            "notes.open returned {opened_id}, expected {capture_id}"
        ));
    }
    Ok(json!({
        "capture_id": capture_id,
        "second_id": second_id,
        "opened_id": opened_id,
        "source_kind": "notification",
        "source_app_id": "org.marathonos.hub",
    }))
}
