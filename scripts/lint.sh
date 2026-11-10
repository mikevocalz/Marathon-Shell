#!/usr/bin/env bash
# Mechanical enforcement for the rules in docs/CODING_RULES.md sections B & C.
#
# Runs:
#   - qmllint over shell/qml, apps/*/qml
#   - clazy-standalone (if installed) over compile_commands.json
#   - clang-tidy (always; we have it) with a Qt-aware check set
#
# Exits non-zero on warnings so CI / pre-push hooks can gate on it. Sources
# from docs/CODING_RULES.md: B1-B15 (C++/Qt), C1-C14 (QML). The checks below
# are the subset clazy / qmllint / clang-tidy can express today; review the
# unenforced rest by hand.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

BUILD_DIR="${BUILD_DIR:-build}"
COMPDB="$BUILD_DIR/compile_commands.json"

errors=0

# ─ QML ──────────────────────────────────────────────────────────────────────

# Runtime-only registrations need generated type metadata. The strict validator
# owns tool discovery, JSON diagnostics, imports, and source enumeration.
if ! cmake --build "$BUILD_DIR" --target qmllint-types; then
    echo "[lint] could not build $BUILD_DIR's qmllint-types" >&2
    errors=1
fi
"$PROJECT_ROOT/scripts/validate-qml.sh" --build-dir "$BUILD_DIR" || errors=1

# User-facing QML strings go through qsTr().
python3 tests/lint/check-untranslated.py || errors=1

# ─ C++ / Qt ──────────────────────────────────────────────────────────────────

if [ ! -f "$COMPDB" ]; then
    echo "[lint] $COMPDB not found -- run cmake -B $BUILD_DIR first" >&2
    exit 1
fi

# The apps are their own CMake project; lint them from its database too.
APPS_BUILD_DIR="${APPS_BUILD_DIR:-build-apps}"
APPS_COMPDB="$APPS_BUILD_DIR/compile_commands.json"
DATABASES=("$COMPDB")
if [ -f "$APPS_COMPDB" ]; then
    DATABASES+=("$APPS_COMPDB")
else
    echo "[lint] $APPS_COMPDB not found -- apps' C++ not checked" >&2
fi

# One entry per file: the shell's sources are compiled again into every test.
LINT_DB="$(mktemp -d)"
trap 'rm -rf "$LINT_DB"' EXIT
jq -s 'add | unique_by(.file)' "${DATABASES[@]}" >"$LINT_DB/compile_commands.json"

OWN_DIRS='shell|marathon-core|marathon-services|apps|tools|tests'

# Only lint our own source. Skip generated, build, third-party, asyncfuture.
filter_sources() {
    jq -r '.[].file' "$LINT_DB/compile_commands.json" |
        grep -E "^$PROJECT_ROOT/($OWN_DIRS)/" |
        grep -vE "/(build|third-party|\.qt|\.rcc|autogen|qmltyperegistrations|_qmlcache)" |
        grep -E '\.(cpp|cc)$'
}

mapfile -t SOURCES < <(filter_sources)
echo "[lint] ${#SOURCES[@]} C++ sources to check"
JOBS="${LINT_JOBS:-$(nproc)}"

CLAZY="$(command -v clazy-standalone || true)"
if [ -n "$CLAZY" ]; then
    echo "[lint] clazy-standalone via $CLAZY"
    # --header-filter keeps the report to our own headers. Without it clazy
    # lints Qt's installed headers too -- QtWebEngineQuickDepends alone
    # accounted for 12 no-module-include findings in /usr/include/qt6 that
    # nobody here can fix. -Werror: clazy exits 0 on warnings.
    printf '%s\0' "${SOURCES[@]}" | xargs -0 -n 1 -P "$JOBS" "$CLAZY" -p "$LINT_DB" \
        --header-filter="^$PROJECT_ROOT/($OWN_DIRS)/" \
        -checks=level0,level1,no-overloaded-signal,no-non-pod-global-static \
        --extra-arg=-Werror 2>&1 || errors=1
else
    echo "[lint] clazy-standalone not installed -- skipping (install: apt install clazy)" >&2
fi

CLANG_TIDY="$(command -v clang-tidy || true)"
if [ -n "$CLANG_TIDY" ]; then
    echo "[lint] clang-tidy via $CLANG_TIDY"
    # Bug-class checks only. misc-const-correctness and other style nits are
    # opinions, not safety -- not worth the churn they'd add to PR reviews
    # and the false-positive volume on Qt's implicit-shared types makes them
    # particularly noisy. Style enforcement lives in clang-format + review,
    # not here.
    CHECKS='bugprone-*,clang-analyzer-*,cppcoreguidelines-pro-type-cstyle-cast,'\
'cppcoreguidelines-slicing,misc-unused-using-decls,'\
'modernize-use-nullptr,modernize-use-override,performance-*,readability-redundant-member-init,'\
'-bugprone-easily-swappable-parameters,-bugprone-unchecked-optional-access,'\
'-bugprone-narrowing-conversions,-performance-no-int-to-ptr,'\
'-clang-analyzer-cplusplus.NewDeleteLeaks'
    # Restrict header-warning scope to OUR headers; otherwise every Qt
    # internal nit floods the output. Anchored at the source tree, so the
    # qtwaylandscanner headers and MOC autogen under the build dirs stay out.
    HEADER_FILTER="^$PROJECT_ROOT/($OWN_DIRS)/"
    # --warnings-as-errors is what makes clang-tidy actually exit non-zero on
    # warning hits; without it the binary returns 0 even with thousands of
    # diagnostics. Same check list as enabled so we don't accidentally elevate
    # something disabled above.
    printf '%s\0' "${SOURCES[@]}" | xargs -0 -n 1 -P "$JOBS" "$CLANG_TIDY" -p "$LINT_DB" \
        --quiet --checks="$CHECKS" --warnings-as-errors="$CHECKS" \
        --header-filter="$HEADER_FILTER" 2>&1 ||
        errors=1
else
    echo "[lint] clang-tidy not installed -- skipping" >&2
fi

if [ "$errors" -ne 0 ]; then
    echo "[lint] FAIL"
    exit 1
fi
echo "[lint] OK"
