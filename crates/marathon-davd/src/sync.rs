//! `CardDAV` and `CalDAV`: discovery (RFC 6764, then the principal's homes and
//! their collections) and sync-collection pulls (RFC 6578) into the address
//! book and `dav-events.db`.

use crate::accounts::Account;
use crate::contacts::Contact;
use crate::events::{DecodeError, Event, Resource};
use crate::webdav::{self, multistatus};
use std::io::BufReader;

/// Finds the account's principal, its homes and their collections.
pub fn discover(agent: &ureq::Agent, account: &mut Account, secret: &str) -> Result<(), String> {
    let auth = webdav::authorization(&account.auth_kind, &account.username, secret);
    let propfind = |url: &str, depth: &str, xml: &str| {
        webdav::request(agent, &auth, "PROPFIND", url, Some(depth), Some(xml))
            .map(|body| multistatus(&body))
    };
    let mut well_known = account.base_url.clone();
    if !well_known.contains("/.well-known") {
        if !well_known.ends_with('/') {
            well_known.push('/');
        }
        well_known.push_str(".well-known/carddav");
    }
    let principal = [well_known.as_str(), account.base_url.as_str()]
        .into_iter()
        .find_map(|url| {
            propfind(url, "0", webdav::PRINCIPAL)
                .ok()
                .map(|m| m.principal)
                .filter(|p| !p.is_empty())
        })
        .ok_or("principal not found")?;
    let principal = webdav::resolve(&account.base_url, &principal);
    let homes = propfind(&principal, "0", webdav::HOMES)?;
    let home = |href: &str| {
        if href.is_empty() {
            String::new()
        } else {
            webdav::resolve(&principal, href)
        }
    };
    account.home_url_contacts = home(&homes.addressbook_home);
    account.home_url_calendar = home(&homes.calendar_home);
    let collections = |home: &str, kind: &str| -> Result<Vec<String>, String> {
        if home.is_empty() {
            return Ok(Vec::new());
        }
        let listed = propfind(home, "1", webdav::COLLECTIONS)?;
        Ok(listed
            .responses
            .iter()
            .filter(|r| r.resource_type.iter().any(|t| t == kind))
            .map(|r| webdav::resolve(home, &r.href))
            .collect())
    };
    account.collections_contacts = collections(&account.home_url_contacts, "addressbook")?;
    account.collections_calendar = collections(&account.home_url_calendar, "calendar")?;
    Ok(())
}

#[derive(Default)]
pub struct Pulled {
    pub contacts: Vec<Contact>,
    pub events: Vec<Resource>,
    pub deleted: Vec<String>,
    pub token: String,
    /// Keep these resources' last projection, including during a full refresh.
    pub unsupported_resources: Vec<String>,
}

impl Pulled {
    pub fn next_token(&self) -> Option<&str> {
        // Retry unsupported resources on the next sync instead of forgetting
        // them behind a new token. Supported sibling resources can still apply.
        self.unsupported_resources
            .is_empty()
            .then_some(self.token.as_str())
    }

    pub fn warning(&self) -> Option<String> {
        (!self.unsupported_resources.is_empty()).then(|| {
            let count = self.unsupported_resources.len();
            let resources = if count == 1 {
                "calendar resource uses"
            } else {
                "calendar resources use"
            };
            format!(
                "{count} {resources} unsupported DURATION. Previously cached events remain available; sync will retry."
            )
        })
    }
}

/// What changed in a collection since `token`: each new or changed
/// resource, fetched.
pub fn pull(
    agent: &ureq::Agent,
    account: &Account,
    secret: &str,
    collection: &str,
    token: &str,
    calendar: bool,
) -> Result<Pulled, String> {
    let auth = webdav::authorization(&account.auth_kind, &account.username, secret);
    let report = webdav::request(
        agent,
        &auth,
        "REPORT",
        collection,
        Some("1"),
        Some(&webdav::sync_collection(token)),
    )?;
    pull_changes(collection, &report, calendar, |url| {
        webdav::request(agent, &auth, "GET", url, None, None)
    })
}

fn pull_changes(
    collection: &str,
    report: &str,
    calendar: bool,
    mut fetch: impl FnMut(&str) -> Result<String, String>,
) -> Result<Pulled, String> {
    let changes = multistatus(report);
    let mut pulled = Pulled {
        token: changes.sync_token,
        ..Pulled::default()
    };
    for change in changes.responses.iter().filter(|r| !r.href.is_empty()) {
        let url = webdav::resolve(collection, &change.href);
        if url.trim_end_matches('/') == collection.trim_end_matches('/') {
            continue;
        }
        if change.gone {
            pulled.deleted.push(url);
            continue;
        }
        let body = fetch(&url)?;
        if calendar {
            let mut resource = Resource {
                href: url,
                events: Vec::new(),
            };
            let mut found = false;
            let mut unsupported = false;
            for parsed in ical::IcalParser::new(BufReader::new(body.as_bytes())) {
                let parsed = parsed.map_err(|e| format!("Invalid calendar resource: {e}"))?;
                found = true;
                for event in parsed.events {
                    if event.properties.iter().any(|p| {
                        p.name.eq_ignore_ascii_case("STATUS")
                            && p.value
                                .as_deref()
                                .is_some_and(|v| v.eq_ignore_ascii_case("CANCELLED"))
                    }) {
                        continue;
                    }
                    match Event::from_ical(&event) {
                        Ok(event) => resource.events.push(event),
                        Err(DecodeError::UnsupportedDuration) => unsupported = true,
                        Err(DecodeError::Invalid(error)) => return Err(error),
                    }
                }
            }
            if !found {
                return Err("Calendar resource contains no calendar".into());
            }
            if unsupported {
                // A DAV resource is the replacement unit. Do not publish half
                // of a series or erase its prior projection on a full refresh.
                pulled.unsupported_resources.push(resource.href);
            } else {
                pulled.events.push(resource);
            }
        } else {
            pulled.contacts.extend(
                ical::VcardParser::new(BufReader::new(body.as_bytes()))
                    .flatten()
                    .map(|card| Contact::from_vcard(&card))
                    .filter(|c| !c.name.is_empty()),
            );
        }
    }
    Ok(pulled)
}

#[cfg(test)]
#[path = "sync_tests.rs"]
mod tests;
