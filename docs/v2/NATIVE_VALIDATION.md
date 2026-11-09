# Native validation gate (R08)

## Required CI coverage

The `native-ui` job in `.github/workflows/ci.yml` now runs a required, bounded
native gate. It builds the real Keel source pinned by
`packaging/packages/keel-silica/APKBUILD`, verifies the checked-out commit, builds
its Silica, Actions, Share and Configuration plugins against the job's Qt, and
runs these four CTests:

| CTest | Required evidence |
| --- | --- |
| `NativeUI_Toolkit` | Qt 6 imports and instantiates real Silica and Configuration; imports real Keel.Actions and Sailfish.Share |
| `Qml_apps_notes_tests` | The complete existing Notes/Tasks UI, actions and persistence suite through its original `run.sh` |
| `Lint_QmlValidator` | 12 executable contract tests, using real `qmllint` for QML behavior |
| `NativeUI_GateContract` | 8 contract tests: real Qt pass/failure/skip/empty execution, missing tooling, required/optional dependency configuration, and the CMake lint target |

This gate uses Keel's supported JSON Configuration fallback in an isolated
per-run directory. Notes retains its existing platform-service test doubles;
Silica, Actions, Share and Configuration are the actual native plugins. It runs
offscreen with Qt's software renderer. The CI job supplies a session bus with
`dbus-run-session`.

Required configuration fails if the runner, Python, or any required module is
missing. Import/plugin failures fail the toolkit fixture before Notes runs.
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

The reports are `build-native-ui/reports/toolkit.xml` and `notes.xml`. The
container workflow is reproducible with the invocation in `ci.yml` and
`scripts/ci/native-ui.sh`.

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

On the combined implementation base
`14b70b8f19ecabd2f5d71ccfca8b5e4418788e53`, with these gate changes, the four
required CTests pass against official Qt **6.11.3** and unmodified Keel
**0df499bf34e02cec7f571853cbf5a4323dc1609e**. Notes reports **127 passed,
0 failed, 0 skipped**: **115** test functions/data rows plus setup/cleanup.
The toolkit probe reports two actual test functions plus setup/cleanup.
The 12 validator and 8 gate-contract regressions exercise their failure paths
as well as success. Test reachability and shell/Python syntax checks pass.

The host cannot create a D-Bus session socket, and no Docker executable is
available here. The local run therefore does not certify external D-Bus share
transport or the new Alpine container job. The CI definition must still run on
its native Alpine/arm64 runner. Neither offscreen UI tests nor source lint
certify compositor presentation, physical input, device power, modem behavior,
mlite/dconf persistence or every app.

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
| Shell UI | 547 / 9 | Broader shell assertions; not part of this required Notes gate |
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
| Settings | 176 / 0 | Host run passed |
| Template | 9 / 0 | Host run passed |
| Terminal | 28 / 4 | Broader platform module/runtime dependencies need qualification |
| Test app | 0 / 2 | Native platform imports did not load; zero successful coverage |

These exploratory counts include setup/cleanup, have zero skips, and do not
promote any additional suite into a release-qualified claim. Their missing
dependencies and assertion failures remain R08 follow-up work.

## Primary tooling references

- [Qt qmllint: JSON, warning limits, import paths and generated type information](https://doc.qt.io/qt-6/qtqml-tooling-qmllint.html)
- [Qt Quick Test: test functions, input paths, imports and offscreen execution](https://doc.qt.io/qt-6/qtquicktest-index.html)
- [Qt Test output formats and invocation](https://doc.qt.io/qt-6/qtest-overview.html)
- [Alpine Qt declarative development package contents](https://pkgs.alpinelinux.org/contents?name=qt6-qtdeclarative-dev&repo=community&branch=edge&arch=aarch64)

The implementations were also checked against the installed tools'
`qmllint --help`, `qmltestrunner -help`, and their actual JSON/JUnit output.
