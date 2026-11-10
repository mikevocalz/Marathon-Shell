# Hub → Notes wire gate

`NativeUI_NotesWire` runs the production Hub capture model and D-Bus transport
against the real `NotesApp.qml`, its generated manifest, Keel action registry,
Configuration backend, workspace, and editor in a separate process. The Rust
files are included by path, so the test cannot pass using a copied transport.

It checks two real `tasks.create` calls, persistent identifier allocation,
literal notification metadata, and `notes.open` selecting the requested older
note while a newer one exists. The provider independently checks the actual
selected editor, its body, and plain-text source label. JSON evidence and the
Qt JUnit report are written beside the other required native UI reports.

Only `Navigation1.StartAppInBackground` is a shell fixture, with all four
preparation calls checked. The existing Notes `Marathon.Platform` service
fixture is reused. The check does not qualify app-runner activation, cgroup
thaw, a device compositor, provider messaging, or durable device storage.

The conductor creates a private D-Bus session and isolated Configuration/XDG
directories. Its child environment contains fixture data and the minimal Qt
runtime discovery variables; it does not inherit personal service credentials
or a personal bus. Missing dependencies, bus startup failure, transport failure,
empty/missing Qt results, assertion failure, or skipped coverage fails the gate.

The required hosted entry point is `scripts/ci/native-ui.sh`. For a prepared
local Qt/Keel environment, build the locked client first:

```sh
cargo build --manifest-path tests/native-ui/notes-wire/Cargo.toml --locked \
    --target-dir build-native-ui/notes-wire-target
export MARATHON_NOTES_WIRE_CLIENT="$PWD/build-native-ui/notes-wire-target/debug/marathon-notes-wire"
cmake -S tests/native-ui -B build-native-ui -G Ninja \
    -DMARATHON_REQUIRE_NATIVE_UI_TESTS=ON \
    -DKEEL_QML="$KEEL_QML" -DQMLTESTRUNNER="$QMLTESTRUNNER" \
    -DMARATHON_NOTES_WIRE_CLIENT="$MARATHON_NOTES_WIRE_CLIENT"
ctest --test-dir build-native-ui -R NativeUI_NotesWire --output-on-failure
```
