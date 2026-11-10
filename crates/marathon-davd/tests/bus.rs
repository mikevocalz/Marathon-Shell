//! marathon-davd on a private bus, as the apps and the shell call it.

#![allow(clippy::unwrap_used, reason = "tests")]

use std::collections::HashMap;

use marathon_rt::testing::PrivateBus;
use zbus::Connection;
use zbus::{OwnedVariant as OwnedValue, Variant};

const BUS: &str = "org.marathonos.Dav";

async fn call<R: serde::de::DeserializeOwned + zbus::Type>(
    bus: &Connection,
    object: &str,
    method: &str,
    body: &(impl serde::Serialize + zbus::DynamicType),
) -> zbus::Result<R> {
    let path = format!("/org/marathonos/Shell/{object}");
    let interface = format!("org.marathonos.Shell.{object}1");
    bus.call_method(
        Some(BUS),
        path.as_str(),
        Some(interface.as_str()),
        method,
        body,
    )
    .await?
    .body()
    .deserialize()
}

fn text(row: &HashMap<String, OwnedValue>, key: &str) -> String {
    String::try_from(row[key].try_clone().unwrap()).unwrap()
}

#[test]
fn the_address_book_answers_permitted_callers() {
    let Some(mut bus) = PrivateBus::start() else {
        return;
    };
    let home = tempfile::tempdir().unwrap();
    async_io::block_on(async {
        let _shell = bus.shell(&["system"]).await.unwrap();
        bus.run(env!("CARGO_BIN_EXE_marathon-davd"), home.path(), BUS)
            .await
            .unwrap();
        let app = bus.connect().await.unwrap();

        call::<()>(
            &app,
            "Contacts",
            "AddContact",
            &("Maya Chen", "+1 415 555 0142", "maya@example.com"),
        )
        .await
        .unwrap();
        let all: Vec<OwnedValue> = call(&app, "Contacts", "GetContacts", &()).await.unwrap();
        let first =
            HashMap::<String, OwnedValue>::try_from(all.into_iter().next().unwrap()).unwrap();
        assert_eq!(text(&first, "name"), "Maya Chen");
        let found: HashMap<String, OwnedValue> =
            call(&app, "Contacts", "GetContactByNumber", &("4155550142",))
                .await
                .unwrap();
        assert_eq!(text(&found, "email"), "maya@example.com");
        let none: HashMap<String, OwnedValue> =
            call(&app, "Contacts", "GetContactByNumber", &("999",))
                .await
                .unwrap();
        assert!(!none.contains_key("name"));

        // As QML's contact editor sends it: av of a{sv}.
        let entry = |kind: &str, value: &str| {
            Variant::from(HashMap::from([
                ("type".to_owned(), Variant::from(kind.to_owned())),
                ("value".to_owned(), Variant::from(value.to_owned())),
            ]))
        };
        let details = HashMap::from([
            ("name".to_owned(), Variant::from("Sam Rivera")),
            (
                "phones".to_owned(),
                Variant::from(vec![
                    entry("mobile", "+1 555 0002"),
                    entry("work", "+1 555 0003"),
                ]),
            ),
            ("note".to_owned(), Variant::from("Met at the conference")),
        ]);
        let id: i32 = call(&app, "Contacts", "CreateContact", &(details,))
            .await
            .unwrap();
        let sam: HashMap<String, OwnedValue> =
            call(&app, "Contacts", "GetContactByNumber", &("15550003",))
                .await
                .unwrap();
        assert_eq!(i32::try_from(&sam["id"]).unwrap(), id);
        assert_eq!(text(&sam, "phone"), "+1 555 0002");
        assert_eq!(text(&sam, "note"), "Met at the conference");
        let phones =
            Vec::<HashMap<String, OwnedValue>>::try_from(sam["phones"].try_clone().unwrap())
                .unwrap();
        assert_eq!(text(&phones[1], "type"), "work");
        assert!(home
            .path()
            .join("data/Marathon OS/Marathon Shell/marathon/contacts/Maya_Chen_1.vcf")
            .exists());

        let refused = call::<Vec<OwnedValue>>(&app, "Dav", "ListAccounts", &()).await;
        assert!(matches!(refused, Err(zbus::Error::FDO(error))
            if matches!(error.as_ref(), zbus::fdo::Error::AccessDenied(text) if text == "Missing permission: system")));
    });
}

#[test]
fn the_calendar_feed_hides_disabled_accounts_and_requires_calendar_permission() {
    let Some(mut bus) = PrivateBus::start() else {
        return;
    };
    let home = tempfile::tempdir().unwrap();
    let data = home.path().join("data/Marathon OS/Marathon Shell/marathon");
    std::fs::create_dir_all(&data).unwrap();
    std::fs::write(data.join("dav-accounts.json"),
        r#"{"accounts":[{"id":"account-a","displayName":"Personal","enabled":true,"collectionsCalendar":["https://calendar.example/events/"]}]}"#).unwrap();
    async_io::block_on(async {
        let _shell = bus.shell(&[]).await.unwrap();
        bus.run(env!("CARGO_BIN_EXE_marathon-davd"), home.path(), BUS)
            .await
            .unwrap();
        let app = bus.connect().await.unwrap();
        // Write a cached provider row after the real daemon creates its schema.
        let database = rusqlite::Connection::open(data.join("dav-events.db")).unwrap();
        database
            .execute(
                "INSERT INTO calendar_events VALUES (?1, ?2, ?3, ?4, '', ?5, '', ?6, ?7, 0, '', 0)",
                rusqlite::params![
                    "account-a",
                    "https://calendar.example/events/",
                    "event.ics",
                    "event-uid",
                    "Dentist",
                    1_792_490_400_000i64,
                    1_792_491_300_000i64
                ],
            )
            .unwrap();
        let events: Vec<OwnedValue> = call(&app, "CalendarEvents", "ListEvents", &())
            .await
            .unwrap();
        assert_eq!(events.len(), 1);
        let event =
            HashMap::<String, OwnedValue>::try_from(events.into_iter().next().unwrap()).unwrap();
        assert_eq!(text(&event, "title"), "Dentist");
        assert_eq!(text(&event, "accountLabel"), "Personal");
        assert_eq!(text(&event, "source"), "caldav");
        assert!(bool::try_from(&event["readOnly"]).unwrap());
        assert!(text(&event, "id").contains("account-a"));

        call::<()>(&app, "Dav", "EnableAccount", &("account-a", false))
            .await
            .unwrap();
        let hidden: Vec<OwnedValue> = call(&app, "CalendarEvents", "ListEvents", &())
            .await
            .unwrap();
        assert_eq!(hidden, Vec::<OwnedValue>::new());
        call::<()>(&app, "Dav", "EnableAccount", &("account-a", true))
            .await
            .unwrap();
        let restored: Vec<OwnedValue> = call(&app, "CalendarEvents", "ListEvents", &())
            .await
            .unwrap();
        assert_eq!(restored.len(), 1);
        assert!(call::<bool>(&app, "Dav", "RemoveAccount", &("account-a",))
            .await
            .unwrap());
        let removed: Vec<OwnedValue> = call(&app, "CalendarEvents", "ListEvents", &())
            .await
            .unwrap();
        assert_eq!(removed, Vec::<OwnedValue>::new());
    });

    let Some(mut refused_bus) = PrivateBus::start() else {
        return;
    };
    let refused_home = tempfile::tempdir().unwrap();
    async_io::block_on(async {
        let _shell = refused_bus.shell(&["calendar"]).await.unwrap();
        refused_bus
            .run(
                env!("CARGO_BIN_EXE_marathon-davd"),
                refused_home.path(),
                BUS,
            )
            .await
            .unwrap();
        let app = refused_bus.connect().await.unwrap();
        let refused = call::<Vec<OwnedValue>>(&app, "CalendarEvents", "ListEvents", &()).await;
        assert!(matches!(refused, Err(zbus::Error::FDO(error))
            if matches!(error.as_ref(), zbus::fdo::Error::AccessDenied(text) if text == "Missing permission: calendar")));
    });
}
