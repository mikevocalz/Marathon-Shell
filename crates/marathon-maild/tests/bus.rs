//! Actual Mail1 calls on an isolated bus, with cached mail and a shell gate.

#![allow(clippy::unwrap_used, reason = "tests")]

use std::collections::HashMap;

use marathon_rt::testing::PrivateBus;
use rusqlite::{params, Connection as Database};
use zbus::{Connection, OwnedVariant as OwnedValue};

const BUS: &str = "org.marathonos.Mail";
const ORIGINAL: &str = "0123456789abcdef0123456789abcdef";
const DECOY: &str = "fedcba9876543210fedcba9876543210";
const REPLACEMENT: &str = "11111111111111111111111111111111";

async fn message(
    bus: &Connection,
    reference: &str,
    account: &str,
) -> zbus::Result<HashMap<String, OwnedValue>> {
    bus.call_method(
        Some(BUS),
        "/org/marathonos/Shell/Mail",
        Some("org.marathonos.Shell.Mail1"),
        "GetMessageInAccount",
        &(format!("message:{reference}"), account),
    )
    .await?
    .body()
    .deserialize()
}

fn text(row: &HashMap<String, OwnedValue>, key: &str) -> String {
    String::try_from(row[key].try_clone().unwrap()).unwrap()
}

fn cache_message(db: &Database, row: i64, account: i64, folder: &str, reference: &str, raw: &[u8]) {
    db.execute(
        "INSERT INTO messages (id, account, folder, uid, seen, subject, sender, address,
             date, snippet, attachment, raw, reference, body_complete)
         VALUES (?1, ?2, ?3, ?1, 0, '', '', '', 0, '', 0, ?4, ?5, 1)",
        params![row, account, folder, raw, reference],
    )
    .unwrap();
}

#[test]
fn a_notification_reads_only_its_reference_and_account() {
    let Some(mut bus) = PrivateBus::start() else {
        return;
    };
    let home = tempfile::tempdir().unwrap();
    async_io::block_on(async {
        let _shell = bus.shell(&[]).await.unwrap();
        // Starting with no accounts avoids a provider dependency. Rows are
        // seeded only after the daemon has opened and migrated its own store.
        bus.run(env!("CARGO_BIN_EXE_marathon-maild"), home.path(), BUS)
            .await
            .unwrap();
        let app = bus.connect().await.unwrap();
        let db = Database::open(home.path().join("data/marathon/mail/mail.db")).unwrap();
        db.execute_batch(
            "INSERT INTO accounts VALUES
                 (1, 'Personal', 'personal@example.test', 'personal', '127.0.0.1', 0, 0,
                  '127.0.0.1', 0, 0, ''),
                 (2, 'Work', 'work@example.test', 'work', '127.0.0.1', 0, 0,
                  '127.0.0.1', 0, 0, '');
             INSERT INTO folders (account, path, name, kind, validity) VALUES
                 (1, 'INBOX', 'Inbox', 'inbox', 10),
                 (2, 'Projects', 'Projects', 'other', 20);",
        )
        .unwrap();
        cache_message(
            &db,
            41,
            1,
            "INBOX",
            DECOY,
            b"From: Ben <ben@example.test>\r\nSubject: Newer message\r\n\r\nA different item",
        );
        cache_message(
            &db, 42, 2, "Projects", ORIGINAL,
            b"From: Ada <ada@example.test>\r\nSubject: Original message\r\n\r\nThe exact cached body",
        );

        let original = message(&app, ORIGINAL, "2").await.unwrap();
        assert_eq!(text(&original, "messageId"), format!("message:{ORIGINAL}"));
        assert_eq!(text(&original, "accountId"), "2");
        assert_eq!(text(&original, "accountName"), "Work");
        assert_eq!(text(&original, "folderId"), "Projects");
        assert_eq!(text(&original, "subject"), "Original message");
        assert_eq!(text(&original, "bodyPlain"), "The exact cached body");
        let wrong_account = message(&app, ORIGINAL, "1").await;
        assert!(matches!(wrong_account, Err(zbus::Error::FDO(error))
            if matches!(*error, zbus::fdo::Error::FileNotFound(_))));

        db.execute("DELETE FROM messages WHERE reference = ?1", [ORIGINAL])
            .unwrap();
        cache_message(
            &db, 42, 2, "Projects", REPLACEMENT,
            b"From: Cy <cy@example.test>\r\nSubject: Replacement\r\n\r\nNever open this for the old notification",
        );
        let removed = message(&app, ORIGINAL, "2").await;
        assert!(matches!(removed, Err(zbus::Error::FDO(error))
            if matches!(*error, zbus::fdo::Error::FileNotFound(_))));
        let replacement = message(&app, REPLACEMENT, "2").await.unwrap();
        assert_eq!(text(&replacement, "subject"), "Replacement");
        let unread: i64 = db
            .query_row("SELECT count(*) FROM messages WHERE seen = 0", [], |r| {
                r.get(0)
            })
            .unwrap();
        assert_eq!(
            unread, 2,
            "reading the wire result must not mark provider mail read"
        );
    });
}

#[test]
fn a_message_reference_does_not_bypass_the_shell_permission_gate() {
    let Some(mut bus) = PrivateBus::start() else {
        return;
    };
    let home = tempfile::tempdir().unwrap();
    async_io::block_on(async {
        let _shell = bus.shell(&["secret-service"]).await.unwrap();
        bus.run(env!("CARGO_BIN_EXE_marathon-maild"), home.path(), BUS)
            .await
            .unwrap();
        let app = bus.connect().await.unwrap();
        let refused = message(&app, ORIGINAL, "2").await;
        assert!(matches!(refused, Err(zbus::Error::FDO(error))
            if matches!(error.as_ref(), zbus::fdo::Error::AccessDenied(reason)
                if reason == "Missing permission: secret-service")));
    });
}
