//! `CardDAV` and `CalDAV`: discovery (RFC 6764, then the principal's homes and
//! their collections) and sync-collection pulls (RFC 6578) into the address
//! book and `dav-events.db`.

use crate::accounts::Account;
use crate::contacts::Contact;
use crate::events::{Event, Resource};
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
    let changes = multistatus(&report);
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
        let body = webdav::request(agent, &auth, "GET", &url, None, None)?;
        if calendar {
            let mut resource = Resource {
                href: url,
                events: Vec::new(),
            };
            let mut found = false;
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
                    resource.events.push(Event::from_ical(&event)?);
                }
            }
            if !found {
                return Err("Calendar resource contains no calendar".into());
            }
            pulled.events.push(resource);
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
