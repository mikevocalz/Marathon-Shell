//! The real Keel cross-process ABI. In-process KeelActions.invoke only addresses
//! the caller's registry; it cannot invoke Notes from the shell.
//!
//! Public failures deliberately retain categories, not remote error strings or
//! parser excerpts that may contain notification text. `_source` bindings mark
//! those intentionally unretained details; no error is converted to success.

use std::collections::HashMap;
use std::time::Duration;

use serde_json::Value;
use zbus::{fdo::DBusProxy, names::OwnedUniqueName, Connection};

use super::model::{result_id, Error};
use crate::io;

pub(super) const SERVICE: &str = "org.marathonos.notes";
pub(super) const PATH: &str = "/org/shipwright/Keel/Actions";
const INTERFACE: &str = "org.shipwright.Keel.Actions";
pub(super) const PREPARE_TIMEOUT: Duration = Duration::from_secs(15);
pub(super) const INVOKE_TIMEOUT: Duration = Duration::from_secs(25);

pub(super) struct Prepared {
    connection: Connection,
    owner: OwnedUniqueName,
}

/// Discover the installed Notes action implementation, activating it through
/// Marathon's packaged D-Bus service if needed. Describe and Invoke are pinned
/// to the same unique owner: an app restart cannot receive a stale capture.
pub(super) async fn prepare(connection: Connection) -> Result<Prepared, Error> {
    // A frozen background app still owns its bus name, so bus activation alone
    // cannot wake it. Use Marathon's actual background-start/thaw admission on
    // every preparation, including a running owner, without foregrounding it.
    let wake = connection
        .call_method(
            Some("org.marathonos.Shell"),
            "/org/marathonos/Shell/Navigation",
            Some("org.marathonos.Shell.Navigation1"),
            "StartAppInBackground",
            &("notes",),
        )
        .await
        .map_err(|_source| Error::Unavailable)?;
    let accepted: bool = wake
        .body()
        .deserialize()
        .map_err(|_source| Error::Unavailable)?;
    if !accepted {
        return Err(Error::Unavailable);
    }
    let bus = DBusProxy::new(&connection)
        .await
        .map_err(|_source| Error::Transport)?;
    let name = SERVICE.try_into().map_err(|_source| Error::Unsupported)?;
    let owner = match bus.get_name_owner(name).await {
        Ok(owner) => owner,
        Err(zbus::fdo::Error::NameHasNoOwner(_)) => {
            bus.start_service_by_name(SERVICE.try_into().map_err(|_source| Error::Unsupported)?, 0)
                .await
                .map_err(|_source| Error::Unavailable)?;
            bus.get_name_owner(SERVICE.try_into().map_err(|_source| Error::Unsupported)?)
                .await
                .map_err(|_source| Error::Unavailable)?
        }
        Err(_source) => return Err(Error::Transport),
    };
    let reply = connection
        .call_method(Some(owner.as_str()), PATH, Some(INTERFACE), "Describe", &())
        .await
        .map_err(|_source| Error::Unavailable)?;
    let text: String = reply
        .body()
        .deserialize()
        .map_err(|_source| Error::Unsupported)?;
    let manifest: Value = serde_json::from_str(&text).map_err(|_source| Error::Unsupported)?;
    validate_manifest(&manifest)?;
    let current = bus
        .get_name_owner(SERVICE.try_into().map_err(|_source| Error::Unsupported)?)
        .await
        .map_err(|_source| Error::Unavailable)?;
    if current != owner {
        return Err(Error::Unavailable);
    }
    Ok(Prepared { connection, owner })
}

pub(super) async fn prepare_session() -> Result<Prepared, Error> {
    let result = io::timeout(PREPARE_TIMEOUT, async {
        prepare(
            io::session_bus()
                .await
                .map_err(|_source| Error::Unavailable)?,
        )
        .await
    })
    .await;
    result.unwrap_or(Err(Error::Timeout))
}

/// Narrow compatibility check for the two operations the capture depends on.
/// A manifest advertises a capability; it is not proof of source-message trust.
pub(super) fn validate_manifest(manifest: &Value) -> Result<(), Error> {
    if manifest.get("appId").and_then(Value::as_str) != Some(SERVICE) {
        return Err(Error::Unsupported);
    }
    let tools = manifest
        .get("tools")
        .and_then(Value::as_array)
        .ok_or(Error::Unsupported)?;
    for (action, idempotent) in [("tasks.create", false), ("notes.open", true)] {
        let matches: Vec<_> = tools
            .iter()
            .filter(|tool| {
                tool.pointer("/_meta/org.shipwright.keel~1action")
                    .and_then(Value::as_str)
                    == Some(action)
            })
            .collect();
        if matches.len() != 1 {
            return Err(Error::Unsupported);
        }
        let tool = matches[0];
        if tool["name"] != format!("{SERVICE}/{action}")
            || tool
                .pointer("/annotations/idempotentHint")
                .and_then(Value::as_bool)
                != Some(idempotent)
            || tool.pointer("/inputSchema/type").and_then(Value::as_str) != Some("object")
            || tool
                .pointer("/outputSchema/properties/id/type")
                .and_then(Value::as_str)
                != Some("integer")
            || tool
                .pointer("/_meta/org.shipwright.keel~1timeoutMs")
                .and_then(Value::as_u64)
                != Some(25_000)
        {
            return Err(Error::Unsupported);
        }
        if action == "tasks.create" {
            for field in ["title", "body"] {
                if tool["inputSchema"]["properties"][field]["type"] != "string" {
                    return Err(Error::Unsupported);
                }
            }
            let kinds = tool
                .pointer("/inputSchema/properties/source/properties/kind/enum")
                .and_then(Value::as_array)
                .ok_or(Error::Unsupported)?;
            if !kinds.iter().any(|kind| kind == "notification") {
                return Err(Error::Unsupported);
            }
        } else if tool
            .pointer("/inputSchema/properties/id/type")
            .and_then(Value::as_str)
            != Some("integer")
        {
            return Err(Error::Unsupported);
        }
    }
    Ok(())
}

impl Prepared {
    /// Any error after this method is entered is uncertain for tasks.create:
    /// even a typed Keel Failed can follow the side effect (output validation).
    /// This method deliberately has no retry.
    pub(super) async fn invoke(
        &self,
        action: &str,
        arguments: &Value,
        timeout: Duration,
    ) -> Result<i32, Error> {
        let mut options = HashMap::new();
        // Keel may strip this hint for an untrusted caller. It never grants the
        // shell privileges, and neither Notes action relies on it for admission.
        options.insert("userInitiated", zbus::Variant::from(true));
        let result = io::timeout(
            timeout,
            self.connection.call_method(
                Some(self.owner.as_str()),
                PATH,
                Some(INTERFACE),
                "Invoke",
                &(action, arguments.to_string(), options),
            ),
        )
        .await
        .ok_or(Error::Timeout)?;
        let reply = result.map_err(|error| {
            if matches!(&error, zbus::Error::MethodError(name, _, _) if name.as_str() == "org.freedesktop.DBus.Error.NoReply") {
                Error::Timeout
            } else {
                Error::Transport
            }
        })?;
        let text: String = reply
            .body()
            .deserialize()
            .map_err(|_source| Error::InvalidResult)?;
        let value = serde_json::from_str(&text).map_err(|_source| Error::InvalidResult)?;
        result_id(&value)
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    fn compatible_manifest() -> Value {
        json!({
            "appId": SERVICE,
            "tools": [
                {
                    "name": "org.marathonos.notes/tasks.create",
                    "_meta": {"org.shipwright.keel/action":"tasks.create", "org.shipwright.keel/timeoutMs":25000},
                    "annotations": {"idempotentHint":false},
                    "inputSchema": {"type":"object", "properties": {
                        "title":{"type":"string"}, "body":{"type":"string"},
                        "source":{"properties":{"kind":{"enum":["notification"]}}}
                    }},
                    "outputSchema": {"properties":{"id":{"type":"integer"}}}
                },
                {
                    "name": "org.marathonos.notes/notes.open",
                    "_meta": {"org.shipwright.keel/action":"notes.open", "org.shipwright.keel/timeoutMs":25000},
                    "annotations": {"idempotentHint":true},
                    "inputSchema": {"type":"object", "properties":{"id":{"type":"integer"}}},
                    "outputSchema": {"properties":{"id":{"type":"integer"}}}
                }
            ]
        })
    }

    #[test]
    fn capability_requires_exact_open_and_notification_capture() -> Result<(), &'static str> {
        let manifest = compatible_manifest();
        assert_eq!(validate_manifest(&manifest), Ok(()));
        let mut missing_open = manifest.clone();
        missing_open["tools"]
            .as_array_mut()
            .ok_or("the fixture must declare a tools array")?
            .pop();
        assert_eq!(validate_manifest(&missing_open), Err(Error::Unsupported));
        let mut old_source = manifest.clone();
        old_source["tools"][0]["inputSchema"]["properties"]["source"]["properties"]["kind"]
            ["enum"] = json!(["message"]);
        assert_eq!(validate_manifest(&old_source), Err(Error::Unsupported));
        let mut wrong_app = manifest.clone();
        wrong_app["appId"] = json!("org.other.notes");
        assert_eq!(validate_manifest(&wrong_app), Err(Error::Unsupported));
        let mut duplicate = manifest;
        let tool = duplicate["tools"][0].clone();
        duplicate["tools"]
            .as_array_mut()
            .ok_or("the fixture must declare a tools array")?
            .push(tool);
        assert_eq!(validate_manifest(&duplicate), Err(Error::Unsupported));
        Ok(())
    }

    #[test]
    fn capability_rejects_replayable_create_or_non_idempotent_open() {
        for (index, value) in [(0, true), (1, false)] {
            let mut manifest = compatible_manifest();
            manifest["tools"][index]["annotations"]["idempotentHint"] = json!(value);
            assert_eq!(validate_manifest(&manifest), Err(Error::Unsupported));
        }
    }
}
