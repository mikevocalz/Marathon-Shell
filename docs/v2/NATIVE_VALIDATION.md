# Native validation gate (R08)

## Required CI coverage

The `native-ui` job in `.github/workflows/ci.yml` now runs a required, bounded
native gate. It builds the real Keel source pinned by
`packaging/packages/keel-silica/APKBUILD`, verifies the checked-out commit, builds
its Silica, Actions, Share and Configuration plugins against the job's Qt, and
runs these six CTests:

| CTest | Required evidence |
| --- | --- |
| `NativeUI_Toolkit` | Qt 6 imports and instantiates real Silica and Configuration; imports real Keel.Actions, Sailfish.Share and QtWayland.Compositor |
| `Qml_apps_notes_tests` | The complete existing Notes/Tasks UI, actions and persistence suite through its original `run.sh` |
| `Qml_settings_AppPages` | The actual Settings AppPages suite, including the installer change's pending-cleanup retry UI; other Settings pages remain separate |
| `Qml_shell_PageViewHub` | The actual launcher PageViewHub test, including accepted, partial and failed uninstall outcomes; broader shell UI remains separate |
| `Lint_QmlValidator` | 12 executable contract tests, using real `qmllint` for QML behavior |
| `NativeUI_GateContract` | 8 contract tests: real Qt pass/failure/skip/empty execution, missing tooling, required/optional dependency configuration, and the CMake lint target |

This gate uses Keel's supported JSON Configuration fallback in an isolated
per-run directory. Notes retains its existing platform-service test doubles;
Silica, Actions, Share and Configuration are the actual native plugins. It runs
offscreen with Qt's software renderer. The CI job supplies a session bus with
`dbus-run-session`.

Required configuration fails if the runner, Python, or required Keel module
entries are missing. Import/plugin failures, including a missing real
QtWayland.Compositor module, fail the toolkit fixture before the UI suites run.
The result wrapper checks Qt's JUnit report, requires a Qt 6 runtime and at least
one `test_` function/data row, and fails on skips, assertions, process failures,
missing reports or malformed reports. Setup/cleanup alone is zero coverage.
`ctest --no-tests=error` also rejects an empty label selection.

The full shell build keeps optional local native UI registration, with an
explicit `NOT REGISTERED` message when dependencies are missing. Set
`MARATHON_REQUIRE_NATIVE_UI_TESTS=ON` to make that absence a configure error.
The standalone project defaults to required mode:

```sh
export KEEL_QML=/absolute/path/to/real-keel-build/qml
export QMLTESTRUNNER=/absolute/path/to/qt6/bin/qmltestrunner
export QMLLINT=/absolute/path/to/qt6/bin/qmllint
cmake -S tests/native-ui -B build-native-ui \
  -DMARATHON_REQUIRE_NATIVE_UI_TESTS=ON
ctest --test-dir build-native-ui -L native-ui-required \
  --no-tests=error --output-on-failure
```

The reports under `build-native-ui/reports/` are `toolkit.xml`, `notes.xml`,
`settings-apppages.xml`, and `pageviewhub.xml`. The
container workflow is reproducible with the invocation in `ci.yml` and
`scripts/ci/native-ui.sh`. The native CI container installs Alpine
`qt6-qtwayland-dev` for the real QtWayland.Compositor module. If that matching
Qt module lives in a separate SDK prefix locally, supply its QML root with
`QML_IMPORT_PATH` and its native libraries through the platform library path.

## Strict source validation

`scripts/validate-qml.sh` remains the entry point. It now runs the Qt 6 linter
with JSON diagnostics and `--max-warnings 0`, preserving the linter's exit
status as well as checking every per-file result. It requires one result for
every selected file. Missing tools, wrong Qt major versions, missing explicit
imports, missing source paths and empty input sets fail. Paths containing
spaces remain separate arguments.

Source excerpts are never parsed as diagnostic severity. A `mmscError:`
property no longer becomes a fabricated `Error:`; a real warning on that line
is reported as a warning and still fails the strict gate. Enabled warning
categories keep their existing `.qmllint.ini` policy. No broad suppression or
warning baseline was added.

With no source arguments the validator selects production QML under
`shell/qml`, `apps` and `marathon-silica`, excluding test doubles and generated
build trees. It prints the exact selected file count. To audit that full scope,
first build the real runtime-registration metadata and the app modules:

```sh
cmake --build build --target qmllint-types
BUILD_DIR=build APPS_BUILD_DIR=build-apps \
  scripts/validate-qml.sh
```

Use explicit files/directories and `-I` for a smaller, clearly named scope.
`KEEL_QML`, shell build imports, generated `qmllint-types`, Marathon.Silica and
app build imports are included. Explicit import directories must exist.
`scripts/lint.sh` uses the same validator after building the type metadata.

`cmake --build build --target marathon-qml-validation` aggregates the
registered module validation targets. The shell build currently registers the
shell's module file list; this command does **not** claim a full source-tree
pass. Each `<target>_validate_qml` depends on its compiled/generated types, and
the ordinary build does not depend back on validation. Qt's own
`<target>_qmllint` targets remain intact. `MARATHON_REQUIRE_QMLLINT=ON` requires
the tool at configuration; running the explicit validation target performs the
strict source check. The normal CI build requires the tool, while the focused
native job runs the executable validator regressions. A full-source warning
cleanup remains a separate requirement before claiming the whole tree clean.

## Verified evidence and limits

The integration owner independently ran all **six required CTests** locally
against official **Qt 6.11.3** on the combined lifecycle/launch-attempt tree
`3082d2f677945dccb07e7041221795f92c88e7cb` on November 9, 2026: **6/6 passed**.
That source is preserved in [commit `066fbccf`](https://github.com/mikevocalz/Marathon-Shell/commit/066fbccff83057c28de3a30cd24b08c5c892e53a).
Its JUnit reports contain Notes **127/0/0**, Settings AppPages **23/0/0**,
PageViewHub **6/0/0**, and toolkit **4/0/0** (pass/fail/skip). Their actual
behavior-function/data-row counts are respectively **115, 21, 4 and 2**;
setup/cleanup results are included in the larger totals. The two infrastructure
suites pass **12 validator** and **8 gate-contract** cases. These figures are
overlapping evidence with the earlier isolated runs, not additional product
features or a complete shell qualification.

On the combined implementation base
`14b70b8f19ecabd2f5d71ccfca8b5e4418788e53`, with these gate changes, the six
required CTests pass against official Qt **6.11.3** and unmodified Keel
**0df499bf34e02cec7f571853cbf5a4323dc1609e**. Notes reports **127 passed,
0 failed, 0 skipped**: **115** test functions/data rows plus setup/cleanup.
The toolkit probe reports two actual test functions plus setup/cleanup.
Settings AppPages reports 22 total results on that base. With the accompanying
installer changes, its independently run native suite reports **23 passed,
0 failed, 0 skipped** (21 actual test functions/data rows), including retry
after removal, partial cleanup, preserving the retry row when its status query
fails, and removal of the completed cleanup row.
The focused PageViewHub suite also runs against the real Qt **6.11.3**
WaylandCompositor addon and real system Wayland server library. Its baseline
contains one behavior plus setup/cleanup; with the installer changes it
reports **6 passed, 0 failed, 0 skipped** (four behaviors), including accepted
requests, partial cleanup and asynchronous failure. Existing nested
TaskSwitcher fixture-role and `HAVE_WAYLAND` warnings remain visible; this does
not certify task-card rendering or a functioning compositor server.
The 12 validator and 8 gate-contract regressions exercise their failure paths
as well as success. Test reachability and shell/Python syntax checks pass.

The first hosted native checkpoint also passed: PR #9 head
`32b182497f7b19963c65e6bd25805964beb15064`, tree
`84bd1d7ac0dc39c4902f560c3c63b3cdf02d8945`, ran **4/4 CTests** successfully in
[native-ui job 129098591385](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42598985222/job/129098591385).
The job used Alpine/arm64 Qt base **6.11.1-r3**, declarative **6.11.1-r1**,
Rust **1.99.1-r0** and the same verified Keel source pin. Its tested PR merge
tree matches the recorded head tree. Format and commit-subject checks passed.
The separate [build-and-test job 129098591086](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42598985222/job/129098591086)
subsequently passed **53/53 registered CTests**. That job explicitly did not
register the real Keel UI suites in its optional configuration; the separate
native-ui job supplied the required four-test scope. These scopes overlap and
must not be summed as independent coverage. This first checkpoint precedes the
two added Settings/PageViewHub gates and the subsequent lifecycle/launcher
repairs; those require the latest candidate's own CI result.

The host cannot create a D-Bus session socket, and no Docker executable is
available here. The local run therefore does not certify external D-Bus share
transport. The hosted job supplies a real session bus, but these bounded
service-fixture tests still do not exercise external sharing. Neither
offscreen UI tests nor source lint certify compositor presentation, physical
input, device power, modem behavior, mlite/dconf persistence or every app.

An initial strict production Notes audit selected eight files and correctly
failed with four warnings: two missing `Marathon.Platform` metadata/import
warnings and two downstream unqualified references. That host run lacked the
real generated platform metadata and is not a clean-source claim. Supplying
service test doubles as production lint metadata would not resolve that gap.

A separate exploratory run of the 18 existing native QML suites on this
partial host build found further unqualified surfaces. Several failures were
missing native modules rather than demonstrated product bugs:

| Suite | Passed / failed | Observed boundary |
| --- | --- | --- |
| Marathon.Silica | 159 / 2 | Fling-stop interaction and dialog frost assertions |
| Shell UI | 547 / 9 | Broad partial-host baseline; only changed PageViewHub is now required |
| Browser | 86 / 0 | Host run passed |
| Calculator | 76 / 2 | Native Nemo.Ngf plugin not built |
| Calendar | 60 / 0 | Host run passed |
| Camera | 9 / 1 | Native Nemo.KeepAlive plugin not built |
| Clock | 107 / 0 | Host run passed |
| Email | 101 / 1 | Show-images assertion |
| Gallery | 39 / 25 | Broader platform module/runtime dependencies need qualification |
| Maps | 26 / 2 | Host QtPositioning module absent |
| Messages | 46 / 27 | Native Sailfish.Pickers module absent |
| Music | 34 / 4 | Broader platform module/runtime dependencies need qualification |
| Notes | 127 / 0 | Now the complete required application suite |
| Phone | 23 / 4 | Broader platform module/runtime dependencies need qualification |
| Settings | 176 / 0 | Broad exploratory baseline passed; only changed AppPages is now required |
| Template | 9 / 0 | Host run passed |
| Terminal | 28 / 4 | Broader platform module/runtime dependencies need qualification |
| Test app | 0 / 2 | Native platform imports did not load; zero successful coverage |

These exploratory counts include setup/cleanup, have zero skips, and do not
promote any additional suite into a release-qualified claim. Their missing
dependencies and assertion failures remain R08 follow-up work.

### Final combined native code checkpoint

The final code is preserved in [commit `1558a065`](https://github.com/mikevocalz/Marathon-Shell/commit/1558a065ca5c1f559dfb500cab912e57802903a2),
tree `103b97d210d8846dfcfe486cd5916c359451a690`. The integration owner verified
the following with Rust **1.99.1** and real Qt **6.11.3**/CXX-Qt **0.10.0**:

| Check | Result |
| --- | --- |
| `marathon-apps` | 52 passed, zero failed |
| `marathon-background` | 38 passed, zero failed |
| `marathon-store-handler` | 41 passed, zero failed, one existing ignored integration case |
| `marathon-shell-native` filter `sandbox::` | 14 passed, zero failed; includes policy, generation metadata and trusted catalogue visibility |
| `marathon-shell-native` filter `tasks::launch::tests` | 13 passed, zero failed; includes request-specific failure and replacement ownership |
| Strict Clippy for those four crates | Passed with `-D warnings`; shell includes both library and test targets |
| Actual Qt `Shell_ProcessCommand` | 1/1 CTest passed; three behaviors plus setup/cleanup, zero failures/skips |
| Actual `connectTasks` source with generated CXX-Qt declarations and real Wayland headers | Compiled successfully |
| Rust formatting, changed C++/QML formatting, test reachability and untranslated-string check | Passed |

The core suites use their final unchanged source from the preceding integrated
checkpoint; the two later launcher-only refactors are covered by the final
native filters. The six required CTests above were rerun on tree `3082d2f6` after the
lifecycle, catalogue and snapshot fixes. The only later code change moves the
unchanged override warning into launch preparation; UI sources and interfaces
are identical. These source boundaries are explicit rather than claiming a
single all-suite/device run.

Commands, from the repository root with the real Qt/CXX toolchain configured:

```sh
cargo test --manifest-path crates/Cargo.toml \
  -p marathon-apps -p marathon-background -p marathon-store-handler --locked
cargo test --manifest-path crates/Cargo.toml \
  -p marathon-shell-native --lib sandbox:: --locked
cargo test --manifest-path crates/Cargo.toml \
  -p marathon-shell-native --lib tasks::launch::tests --locked
cargo clippy --manifest-path crates/Cargo.toml \
  -p marathon-apps -p marathon-background -p marathon-store-handler \
  --all-targets --no-deps --locked -- -D warnings
cargo clippy --manifest-path crates/Cargo.toml \
  -p marathon-shell-native --lib --tests --no-deps --locked -- -D warnings
```

The compiler also reports the pre-existing gold-linker deprecation warning
during native test linking. Strict Clippy passed; this is not a claim that all
compiler/linker output is warning-free. A complete compositor link/runtime,
kernel isolation and physical device evidence remain separate gates.

### Native Rust/CXX host baseline failures

The first lifecycle branch's complete native compilation linked successfully.
`marathon-app-native` passed **11/11**, while `marathon-shell-native` reported
**150 passed / 3 failed**. These are recorded failures, not a green aggregate.
An independent comparison reran each failing test on gate-only commit
`931570c6520a5b4bcb197a5133859204400691fa`; its native source and assets are
identical to the pre-repair `14b70b8f` baseline. All three reproduced with
Cargo exit **101**, without skips or source changes:

| Exact test | Observed host boundary |
| --- | --- |
| `ambience::tests::every_built_in_wallpaper_measures_dark` | The host Qt build decodes the unchanged JPEG wallpaper, but the unchanged SVG returns `Unsupported image format`; its SVG image plugin is absent. |
| `gate::tests::a_service_updated_while_running_is_still_its_executable` | Numeric `/proc/<getpid()>` paths are absent in this host's process namespace, while `/proc/self` refers to the outer PID. The expected executable lookup returns `None`. |
| `gate::tests::the_launch_service_names_a_pid_and_its_children` | The same numeric process-path mismatch makes the expected parent lookup return `None`. |

This comparison distinguishes the observed host failures from the repair's
focused native tests. It does not qualify process identity enforcement on a
device. The full native/image CI and the actual device boundary tests remain
required; no test was disabled or rewritten to conceal these failures.

## Primary tooling references

- [Qt qmllint: JSON, warning limits, import paths and generated type information](https://doc.qt.io/qt-6/qtqml-tooling-qmllint.html)
- [Qt Quick Test: test functions, input paths, imports and offscreen execution](https://doc.qt.io/qt-6/qtquicktest-index.html)
- [Qt Test output formats and invocation](https://doc.qt.io/qt-6/qtest-overview.html)
- [Alpine Qt Wayland development package and compositor module](https://pkgs.alpinelinux.org/package/edge/community/aarch64/qt6-qtwayland-dev)
- [Alpine Qt declarative development package contents](https://pkgs.alpinelinux.org/contents?name=qt6-qtdeclarative-dev&repo=community&branch=edge&arch=aarch64)

The implementations were also checked against the installed tools'
`qmllint --help`, `qmltestrunner -help`, and their actual JSON/JUnit output.
