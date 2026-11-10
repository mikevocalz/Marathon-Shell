#![allow(clippy::unwrap_used, reason = "tests")]

use super::*;
use crate::events::Events;
use std::fmt::Write;
use zbus::Variant;

const COLLECTION: &str = "https://calendar.example/events/";

fn calendar(events: &[&str]) -> String {
    let mut calendar = String::from("BEGIN:VCALENDAR\r\n");
    for properties in events {
        write!(calendar, "BEGIN:VEVENT\r\n{properties}\r\nEND:VEVENT\r\n").unwrap();
    }
    calendar.push_str("END:VCALENDAR\r\n");
    calendar
}

fn fixture_pull(resources: &[(&str, Option<String>)]) -> Result<Pulled, String> {
    let mut report = String::from("<multistatus xmlns=\"DAV:\">");
    for (href, body) in resources {
        let status = if body.is_some() {
            "200 OK"
        } else {
            "404 Not Found"
        };
        write!(report, "<response><href>{COLLECTION}{href}</href><status>HTTP/1.1 {status}</status></response>").map_err(|error| error.to_string())?;
    }
    report.push_str("<sync-token>next</sync-token></multistatus>");
    pull_changes(COLLECTION, &report, true, |url| {
        resources
            .iter()
            .find(|(href, _)| url == format!("{COLLECTION}{href}"))
            .and_then(|(_, body)| body.clone())
            .ok_or_else(|| format!("Unexpected GET {url}"))
    })
}

fn stored() -> (tempfile::TempDir, Events) {
    let temp = tempfile::tempdir().unwrap();
    let mut store = Events::open(&temp.path().join("events.db")).unwrap();
    let resources: Vec<Resource> = ["valid", "unsupported", "deleted", "orphan"]
        .into_iter()
        .map(|uid| Resource {
            href: format!("{COLLECTION}{uid}.ics"),
            events: vec![Event {
                uid: uid.into(),
                summary: format!("Cached {uid}"),
                start_ms: 1_792_490_400_000,
                end_ms: 1_792_491_300_000,
                ..Event::default()
            }],
        })
        .collect();
    store
        .apply("a", COLLECTION, &resources, &[], true, &[])
        .unwrap();
    (temp, store)
}

fn titles(store: &Events) -> Vec<String> {
    let rows = store
        .list(&[Account {
            id: "a".into(),
            enabled: true,
            collections_calendar: vec![COLLECTION.into()],
            ..Account::default()
        }])
        .unwrap();
    let mut titles: Vec<String> = rows
        .iter()
        .map(|row| {
            let Variant::Dict(row) = row else {
                unreachable!()
            };
            row.iter()
                .find_map(|(key, value)| {
                    (key.downcast_ref::<&str>().ok() == Some("title"))
                        .then(|| value.downcast_ref::<String>().unwrap())
                })
                .unwrap()
        })
        .collect();
    titles.sort();
    titles
}

fn check_partial_refresh(full: bool) {
    let (_temp, mut store) = stored();
    let pulled = fixture_pull(&[
        (
            "valid.ics",
            Some(calendar(&[
                "UID:valid\r\nSUMMARY:Updated valid\r\nDTSTART:20261020T100000Z",
            ])),
        ),
        (
            "unsupported.ics",
            Some(calendar(&[
                // Even a readable sibling in this resource must not replace
                // half of the last cached series.
                "UID:unsupported\r\nSUMMARY:Partial replacement\r\nDTSTART:20261020T100000Z",
                "UID:unsupported\r\nRECURRENCE-ID:20261021T100000Z\r\nDTSTART:20261021T100000Z\r\nDURATION:PT1H",
            ])),
        ),
        ("deleted.ics", None),
    ])
    .unwrap();
    assert_eq!(
        pulled.next_token(),
        None,
        "partial sync must retry its token"
    );
    let warning = pulled.warning().unwrap();
    assert!(warning.contains("DURATION"));
    assert!(warning.contains("sync will retry"));
    assert_eq!(pulled.events.len(), 1);
    assert_eq!(
        pulled.unsupported_resources,
        [format!("{COLLECTION}unsupported.ics")]
    );
    store
        .apply(
            "a",
            COLLECTION,
            &pulled.events,
            &pulled.deleted,
            full,
            &pulled.unsupported_resources,
        )
        .unwrap();
    let expected = if full {
        vec!["Cached unsupported", "Updated valid"]
    } else {
        vec!["Cached orphan", "Cached unsupported", "Updated valid"]
    };
    assert_eq!(titles(&store), expected);
}

#[test]
fn incremental_sync_applies_supported_siblings_and_reports_a_retry() {
    check_partial_refresh(false);
}

#[test]
fn full_refresh_preserves_only_the_unsupported_cached_resources() {
    check_partial_refresh(true);
}

#[test]
fn a_retry_can_replace_the_deferred_resource_and_advance_the_token() {
    let (_temp, mut store) = stored();
    let pulled = fixture_pull(&[(
        "unsupported.ics",
        Some(calendar(&[
            "UID:unsupported\r\nSUMMARY:Now readable\r\nDTSTART:20261020T100000Z\r\nDTEND:20261020T110000Z",
        ])),
    )])
    .unwrap();
    assert_eq!(pulled.next_token(), Some("next"));
    assert_eq!(pulled.warning(), None);
    store
        .apply(
            "a",
            COLLECTION,
            &pulled.events,
            &pulled.deleted,
            false,
            &pulled.unsupported_resources,
        )
        .unwrap();
    assert_eq!(
        titles(&store),
        [
            "Cached deleted",
            "Cached orphan",
            "Cached valid",
            "Now readable"
        ]
    );
}

#[test]
fn structural_decode_failure_does_not_return_a_partial_collection() {
    let (_temp, store) = stored();
    let before = titles(&store);
    let result = fixture_pull(&[
        (
            "valid.ics",
            Some(calendar(&[
                "UID:valid\r\nSUMMARY:Do not commit\r\nDTSTART:20261020T100000Z",
            ])),
        ),
        (
            "broken.ics",
            Some("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:broken\r\n".into()),
        ),
    ]);
    let error = result.err().unwrap();
    assert!(error.contains("Invalid calendar resource"), "{error}");
    assert_eq!(titles(&store), before);
}

#[test]
fn duration_does_not_hide_invalid_dates_or_a_later_malformed_event() {
    for events in [
        vec!["UID:e\r\nDURATION:PT1H\r\nDTSTART:bad"],
        vec!["UID:e\r\nDTSTART:bad\r\nDURATION:PT1H"],
        vec!["DURATION:PT1H\r\nDTSTART:20261020T100000Z"],
        vec!["UID:e\r\nDURATION:PT1H"],
        vec!["UID:e\r\nDTSTART:20261020T100000Z\r\nDURATION:"],
        vec!["UID:e\r\nDTSTART:20261020T100000Z\r\nDTEND:20261020T110000Z\r\nDURATION:PT1H"],
        vec![
            "UID:e\r\nDTSTART:20261020T100000Z\r\nDURATION:PT1H",
            "UID:broken\r\nDTSTART:bad",
        ],
    ] {
        assert!(fixture_pull(&[("event.ics", Some(calendar(&events)))]).is_err());
    }
}
