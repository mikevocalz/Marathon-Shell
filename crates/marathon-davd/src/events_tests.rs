#![allow(clippy::unwrap_used, reason = "tests")]

use std::io::BufReader;

use super::*;

fn parse(properties: &str) -> Result<Event, String> {
    let text = format!(
        "BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\n{properties}\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n"
    );
    let calendar = ical::IcalParser::new(BufReader::new(text.as_bytes()))
        .next()
        .ok_or("Missing test calendar")?
        .map_err(|e| e.to_string())?;
    Event::from_ical(&calendar.events[0]).map_err(|error| error.to_string())
}

fn event(uid: &str, title: &str) -> Event {
    Event {
        uid: uid.into(),
        summary: title.into(),
        start_ms: 1_792_490_400_000,
        end_ms: 1_792_491_300_000,
        ..Event::default()
    }
}

fn resource(href: &str, events: Vec<Event>) -> Resource {
    Resource {
        href: href.into(),
        events,
    }
}

fn account(id: &str, collections: &[&str]) -> Account {
    Account {
        id: id.into(),
        display_name: format!("Account {id}"),
        enabled: true,
        collections_calendar: collections.iter().map(|s| (*s).into()).collect(),
        ..Account::default()
    }
}

fn text(row: &Value<'_>, field: &str) -> String {
    let Value::Dict(row) = row else {
        unreachable!()
    };
    row.iter()
        .find_map(|(k, v)| {
            (k.downcast_ref::<&str>().ok() == Some(field))
                .then(|| v.downcast_ref::<String>().unwrap())
        })
        .unwrap()
}

#[test]
fn dates_and_named_timezones_have_explicit_meaning() {
    let utc =
        parse("UID:e1\r\nSUMMARY:Standup\r\nDTSTART:20261020T100000Z\r\nDTEND:20261020T101500Z")
            .unwrap();
    assert_eq!(
        (utc.start_ms, utc.end_ms),
        (1_792_490_400_000, 1_792_491_300_000)
    );
    let ny = parse("UID:e1\r\nDTSTART;TZID=America/New_York:20261020T060000").unwrap();
    assert_eq!(ny.start_ms, utc.start_ms);
    let all_day = parse("UID:e2\r\nDTSTART;VALUE=DATE:20261021").unwrap();
    assert_eq!(all_day.end_ms - all_day.start_ms, 86_400_000);
    let row = all_day
        .row(
            &account("a", &["c"]),
            "c",
            &TimeZone::get("America/Los_Angeles").unwrap(),
        )
        .unwrap();
    assert_eq!(text(&row, "date"), "2026-10-21");
    assert_eq!(text(&row, "endDate"), "2026-10-22");
}

#[test]
fn unsupported_or_invalid_times_are_not_published_as_epoch_events() {
    for properties in [
        "UID:e",
        "UID:e\r\nDTSTART:bad",
        "UID:e\r\nDTSTART:20260230T100000Z",
        "UID:e\r\nDTSTART;TZID=Unknown/Zone:20261020T100000",
        "DTSTART:20261020T100000Z",
        "UID:e\r\nDTSTART:20261020T100000Z\r\nDTEND:20261019T100000Z",
        "UID:e\r\nDTSTART:20261020T100000Z\r\nDURATION:PT1H",
    ] {
        assert!(parse(properties).is_err(), "{properties}");
    }
    assert!(instant("2026102éT10000", false, None).is_err());
}

#[test]
fn recurring_resources_remain_explicit_previews() {
    let preview = parse("UID:e\r\nDTSTART:20261020T100000Z\r\nRRULE:FREQ=WEEKLY;COUNT=3").unwrap();
    assert!(preview.recurrence_incomplete);
    let exception =
        parse("UID:e\r\nRECURRENCE-ID:20261027T100000Z\r\nDTSTART:20261027T110000Z").unwrap();
    assert!(exception.recurrence_incomplete);
    assert_ne!(
        text(
            &preview
                .row(&account("a", &["c"]), "c", &TimeZone::UTC)
                .unwrap(),
            "id"
        ),
        text(
            &exception
                .row(&account("a", &["c"]), "c", &TimeZone::UTC)
                .unwrap(),
            "id"
        )
    );
}

#[test]
fn identity_is_account_and_collection_scoped_and_survives_resource_moves() {
    let temp = tempfile::tempdir().unwrap();
    let mut store = Events::open(&temp.path().join("events.db")).unwrap();
    for (account, collection) in [("a", "one"), ("a", "two"), ("b", "one")] {
        store
            .apply(
                account,
                collection,
                &[resource("old.ics", vec![event("same", "Title")])],
                &[],
                true,
                &[],
            )
            .unwrap();
    }
    let accounts = [account("a", &["one", "two"]), account("b", &["one"])];
    let before = store.list(&accounts).unwrap();
    let ids: std::collections::HashSet<_> = before.iter().map(|r| text(r, "id")).collect();
    assert_eq!(ids.len(), 3);
    store
        .apply(
            "a",
            "one",
            &[resource("new.ics", vec![event("same", "Updated")])],
            &["old.ics".into()],
            false,
            &[],
        )
        .unwrap();
    let after = store.list(&accounts).unwrap();
    assert_eq!(after.len(), 3);
    assert_eq!(ids, after.iter().map(|r| text(r, "id")).collect());
    assert!(after.iter().any(|r| text(r, "title") == "Updated"));
}

#[test]
fn deletion_and_full_refresh_never_cross_accounts_or_collections() {
    let temp = tempfile::tempdir().unwrap();
    let mut store = Events::open(&temp.path().join("events.db")).unwrap();
    for (account, collection) in [("a", "one"), ("a", "two"), ("b", "one")] {
        store
            .apply(
                account,
                collection,
                &[resource("shared.ics", vec![event("same", "Title")])],
                &[],
                true,
                &[],
            )
            .unwrap();
    }
    let accounts = [account("a", &["one", "two"]), account("b", &["one"])];
    store
        .apply("a", "one", &[], &["shared.ics".into()], false, &[])
        .unwrap();
    assert_eq!(store.list(&accounts).unwrap().len(), 2);
    store.apply("a", "two", &[], &[], true, &[]).unwrap();
    let remaining = store.list(&accounts).unwrap();
    assert_eq!(remaining.len(), 1);
    assert_eq!(text(&remaining[0], "accountId"), "b");
}

#[test]
fn a_failed_batch_keeps_the_previous_cache() {
    let temp = tempfile::tempdir().unwrap();
    let mut store = Events::open(&temp.path().join("events.db")).unwrap();
    store
        .apply(
            "a",
            "c",
            &[resource("old", vec![event("old", "Keep me")])],
            &[],
            true,
            &[],
        )
        .unwrap();
    store.0.execute_batch("CREATE TRIGGER fail_one BEFORE INSERT ON calendar_events WHEN NEW.uid = 'bad' BEGIN SELECT RAISE(ABORT, 'test write failure'); END;").unwrap();
    let result = store.apply(
        "a",
        "c",
        &[resource(
            "new",
            vec![event("new", "New"), event("bad", "Bad")],
        )],
        &[],
        true,
        &[],
    );
    assert!(result.is_err());
    let kept = store.list(&[account("a", &["c"])]).unwrap();
    assert_eq!(kept.len(), 1);
    assert_eq!(text(&kept[0], "title"), "Keep me");
}

#[test]
fn removed_disabled_and_undiscovered_accounts_are_hidden() {
    let temp = tempfile::tempdir().unwrap();
    let mut store = Events::open(&temp.path().join("events.db")).unwrap();
    store
        .apply(
            "a",
            "c",
            &[resource("event", vec![event("e", "Event")])],
            &[],
            true,
            &[],
        )
        .unwrap();
    assert_eq!(store.list(&[]).unwrap(), Vec::<Value>::new());
    assert_eq!(
        store.list(&[account("a", &[])]).unwrap(),
        Vec::<Value>::new()
    );
    let mut disabled = account("a", &["c"]);
    disabled.enabled = false;
    assert_eq!(store.list(&[disabled]).unwrap(), Vec::<Value>::new());
    assert_eq!(store.list(&[account("a", &["c"])]).unwrap().len(), 1);
}

#[test]
fn legacy_cache_is_preserved_until_a_scoped_refresh_is_available() {
    let temp = tempfile::tempdir().unwrap();
    let path = temp.path().join("events.db");
    Connection::open(&path).unwrap().execute_batch("CREATE TABLE events(uid TEXT PRIMARY KEY, account_id TEXT); INSERT INTO events VALUES('legacy', 'a');").unwrap();
    let store = Events::open(&path).unwrap();
    assert_eq!(
        store.list(&[account("a", &["c"])]).unwrap(),
        Vec::<Value>::new()
    );
    assert_eq!(
        store
            .0
            .query_row("SELECT uid FROM events", [], |row| row.get::<_, String>(0))
            .unwrap(),
        "legacy"
    );
}
