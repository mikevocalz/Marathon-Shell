//! Account-scoped calendar resources and their read-only native presentation.

use std::collections::HashMap;
use std::path::Path;

use jiff::civil::DateTime;
use jiff::tz::TimeZone;
use jiff::Timestamp;
use rusqlite::{params, Connection};
use zbus::Variant as Value;

use crate::accounts::Account;

#[derive(Default, Debug, PartialEq)]
pub struct Event {
    pub uid: String,
    pub recurrence_id: String,
    pub summary: String,
    pub description: String,
    pub location: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub all_day: bool,
    pub recurrence_incomplete: bool,
}

pub struct Resource {
    pub href: String,
    pub events: Vec<Event>,
}

fn instant(value: &str, date_only: bool, timezone: Option<&str>) -> Result<i64, String> {
    if !value.is_ascii() {
        return Err("Invalid calendar date or time".into());
    }
    let date = || {
        Some(format!(
            "{}-{}-{}",
            value.get(..4)?,
            value.get(4..6)?,
            value.get(6..8)?
        ))
    };
    let text = if date_only && value.len() == 8 {
        format!("{}T00:00:00", date().ok_or("Invalid calendar date")?)
    } else if value.len() == 15 || (value.len() == 16 && value.ends_with('Z')) {
        if value.get(8..9) != Some("T") {
            return Err("Invalid calendar time".into());
        }
        format!(
            "{}T{}:{}:{}",
            date().ok_or("Invalid calendar date")?,
            &value[9..11],
            &value[11..13],
            &value[13..15]
        )
    } else {
        return Err("Invalid calendar date or time".into());
    };
    let civil: DateTime = text.parse().map_err(|e: jiff::Error| e.to_string())?;
    let zone = if date_only || value.ends_with('Z') {
        TimeZone::UTC
    } else if let Some(timezone) = timezone {
        TimeZone::get(timezone).map_err(|e| e.to_string())?
    } else {
        TimeZone::system()
    };
    civil
        .to_zoned(zone)
        .map(|at| at.timestamp().as_millisecond())
        .map_err(|e| e.to_string())
}

impl Event {
    pub fn from_ical(event: &ical::parser::ical::component::IcalEvent) -> Result<Self, String> {
        let mut out = Self::default();
        let (mut start, mut end) = (None, None);
        for property in &event.properties {
            let value = property.value.as_deref().unwrap_or_default().trim();
            let parameter = |name: &str| {
                property
                    .params
                    .iter()
                    .flatten()
                    .find(|(key, _)| key.eq_ignore_ascii_case(name))
                    .and_then(|(_, values)| values.first())
                    .map(String::as_str)
            };
            let date_only = parameter("VALUE").is_some_and(|v| v.eq_ignore_ascii_case("DATE"));
            match property.name.to_ascii_uppercase().as_str() {
                "UID" => value.clone_into(&mut out.uid),
                "RECURRENCE-ID" => {
                    value.clone_into(&mut out.recurrence_id);
                    out.recurrence_incomplete = true;
                }
                "RRULE" | "RDATE" | "EXDATE" => out.recurrence_incomplete = true,
                "SUMMARY" => value.clone_into(&mut out.summary),
                "DESCRIPTION" => value.clone_into(&mut out.description),
                "LOCATION" => value.clone_into(&mut out.location),
                "DTSTART" => {
                    start = Some(instant(value, date_only, parameter("TZID"))?);
                    out.all_day = date_only;
                }
                "DTEND" => end = Some(instant(value, date_only, parameter("TZID"))?),
                "DURATION" => return Err("Calendar DURATION is not supported yet".into()),
                _ => {}
            }
        }
        if out.uid.is_empty() {
            return Err("Calendar event has no UID".into());
        }
        out.start_ms = start.ok_or("Calendar event has no start")?;
        out.end_ms = end.unwrap_or(out.start_ms + if out.all_day { 86_400_000 } else { 0 });
        if out.end_ms < out.start_ms {
            return Err("Calendar event ends before it starts".into());
        }
        Ok(out)
    }

    fn row(
        &self,
        account: &Account,
        collection: &str,
        zone: &TimeZone,
    ) -> Result<Value<'static>, String> {
        let zone = if self.all_day {
            TimeZone::UTC
        } else {
            zone.clone()
        };
        let start = Timestamp::from_millisecond(self.start_ms)
            .map_err(|e| e.to_string())?
            .to_zoned(zone.clone());
        let end = Timestamp::from_millisecond(self.end_ms)
            .map_err(|e| e.to_string())?
            .to_zoned(zone);
        let identity = format!(
            "dav:{}",
            serde_json::json!([account.id, collection, self.uid, self.recurrence_id])
        );
        Ok(Value::from(HashMap::from([
            ("id", Value::from(identity)),
            ("source", Value::from("caldav")),
            ("accountId", Value::from(account.id.clone())),
            ("accountLabel", Value::from(account.display_name.clone())),
            ("collectionId", Value::from(collection.to_owned())),
            ("uid", Value::from(self.uid.clone())),
            ("title", Value::from(self.summary.clone())),
            ("description", Value::from(self.description.clone())),
            ("location", Value::from(self.location.clone())),
            ("date", Value::from(start.strftime("%Y-%m-%d").to_string())),
            ("time", Value::from(start.strftime("%H:%M").to_string())),
            ("endDate", Value::from(end.strftime("%Y-%m-%d").to_string())),
            ("endTime", Value::from(end.strftime("%H:%M").to_string())),
            ("allDay", Value::from(self.all_day)),
            ("recurring", Value::from("none")),
            (
                "recurrenceIncomplete",
                Value::from(self.recurrence_incomplete),
            ),
            ("reminder", Value::from(-1i32)),
            ("readOnly", Value::from(true)),
        ])))
    }
}

pub struct Events(Connection);

impl Events {
    pub fn open(path: &Path) -> rusqlite::Result<Self> {
        let db = Connection::open(path)?;
        // The legacy UID-only table lacks resource/collection identity. Keep it
        // intact; a fresh collection sync builds this versioned cache.
        db.execute_batch(
            "PRAGMA journal_mode = WAL;
             CREATE TABLE IF NOT EXISTS calendar_events (
                 account_id TEXT NOT NULL, collection_id TEXT NOT NULL, href TEXT NOT NULL,
                 uid TEXT NOT NULL, recurrence_id TEXT NOT NULL, summary TEXT NOT NULL,
                 description TEXT NOT NULL, start_ms INTEGER NOT NULL, end_ms INTEGER NOT NULL,
                 all_day INTEGER NOT NULL, location TEXT NOT NULL, recurrence_incomplete INTEGER NOT NULL,
                 PRIMARY KEY(account_id, collection_id, uid, recurrence_id));
             CREATE INDEX IF NOT EXISTS idx_calendar_events_start ON calendar_events(start_ms);",
        )?;
        Ok(Self(db))
    }

    pub fn apply(
        &mut self,
        account: &str,
        collection: &str,
        resources: &[Resource],
        deleted: &[String],
        full: bool,
    ) -> rusqlite::Result<()> {
        let transaction = self.0.transaction()?;
        if full {
            transaction.execute(
                "DELETE FROM calendar_events WHERE account_id = ?1 AND collection_id = ?2",
                params![account, collection],
            )?;
        }
        for href in deleted
            .iter()
            .map(String::as_str)
            .chain(resources.iter().map(|r| r.href.as_str()))
        {
            transaction.execute("DELETE FROM calendar_events WHERE account_id = ?1 AND collection_id = ?2 AND href = ?3", params![account, collection, href])?;
        }
        for resource in resources {
            for event in &resource.events {
                transaction.execute(
                    "INSERT INTO calendar_events VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
                     ON CONFLICT(account_id, collection_id, uid, recurrence_id) DO UPDATE SET
                     href = ?3, summary = ?6, description = ?7, start_ms = ?8, end_ms = ?9,
                     all_day = ?10, location = ?11, recurrence_incomplete = ?12",
                    params![account, collection, resource.href, event.uid, event.recurrence_id,
                        event.summary, event.description, event.start_ms, event.end_ms,
                        event.all_day, event.location, event.recurrence_incomplete],
                )?;
            }
        }
        transaction.commit()
    }

    pub fn list(&self, accounts: &[Account]) -> Result<Vec<Value<'static>>, String> {
        let mut query = self
            .0
            .prepare(
                "SELECT account_id, collection_id, uid, recurrence_id, summary, description,
             start_ms, end_ms, all_day, location, recurrence_incomplete
             FROM calendar_events ORDER BY start_ms, account_id, collection_id, uid, recurrence_id",
            )
            .map_err(|e| e.to_string())?;
        let rows = query
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    Event {
                        uid: row.get(2)?,
                        recurrence_id: row.get(3)?,
                        summary: row.get(4)?,
                        description: row.get(5)?,
                        start_ms: row.get(6)?,
                        end_ms: row.get(7)?,
                        all_day: row.get(8)?,
                        location: row.get(9)?,
                        recurrence_incomplete: row.get(10)?,
                    },
                ))
            })
            .map_err(|e| e.to_string())?;
        let zone = TimeZone::system();
        let mut events = Vec::new();
        for row in rows {
            let (id, collection, event) = row.map_err(|e| e.to_string())?;
            if let Some(account) = accounts
                .iter()
                .find(|a| a.enabled && a.id == id && a.collections_calendar.contains(&collection))
            {
                events.push(event.row(account, &collection, &zone)?);
            }
        }
        Ok(events)
    }
}

#[cfg(test)]
#[path = "events_tests.rs"]
mod tests;
