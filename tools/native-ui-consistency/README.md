# Native UI consistency check

This check keeps new source changes aligned with
[Marathon's native UI contract](../../docs/v2/NATIVE_UI_CONSISTENCY.md).
It uses Python's standard library and works from a source archive without Git.

```sh
cmake -S tools/native-ui-consistency -B build-ui-consistency
ctest --test-dir build-ui-consistency --output-on-failure --no-tests=error
python3 tools/native-ui-consistency/check_ui.py --report
```

Both checks are also registered in the repository's CTest tree.
The dedicated GitHub workflow runs them when native UI or policy files change.

## Coverage

The scanner covers production QML in `apps/`, `shell/qml/` and
`marathon-silica/Marathon/Silica/`. App fixtures and the diagnostic app's
test-only QML are excluded; the app template is included. The journey inventory
still includes both support directories and requires entries for new app
directories, including apps whose QML is nested under `ui/`.

Rules report direct color literals/all-literal Qt color functions; literal
font families/sizes; positive radius and spacing literals; Qt Quick Controls
imports; and unqualified Silica controls whose Marathon wrapper import is
missing or precedes Silica. Grouped font/anchors/Layout/border properties,
parenthesized literals, comments and quoted examples have regression coverage.
Multiples of shared padding/spacing roles are allowed.

Each token-owner exemption names an exact file and rule. It does not exempt
every property or a whole directory.

## Existing findings and cleanup

`baseline.json` records the source inspected at
`094ed581d93e2ca0f8bca61c3a30c011ee601727`: 134 findings across
430 production QML files. They are source review candidates. A viewfinder,
compositing mask or emoji font can have a legitimate literal; do not replace
one mechanically with an unrelated theme role.

Every allowance matches an exact path, rule, normalized expression and count.
Moving it to another file, changing its value or adding another copy fails.
Removing a finding also fails until its retired allowance is removed from the
baseline, preventing a later reintroduction from using that old allowance.

To fix a finding, choose the appropriate existing role/shared control, verify
the native behavior, then remove or decrement its exact baseline entry.
For a genuinely new content-specific exception, document its reason and native
evidence in the PR before adding the narrow entry. Do not regenerate the whole
baseline to make a failing change pass. There is no automatic baseline-update
command.

The check reports inherited findings even when no new regression exists.
A zero exit status means the source rules and inventory passed, not that all
screens are consistent or visually qualified.

## Limits

This is a lexical guard, not a complete QML/JavaScript parser. It checks common
direct bindings and object construction. It does not evaluate arbitrary
conditional/function/JavaScript-assigned expressions, prove imported symbols
resolve, or identify every possible custom control. Numbers for data, sizes,
animation timing and intentional negative geometry are outside these rules.

Keep real qmllint/import/icon checks and native UI tests. Review contrast,
text clipping, focus order, touch, reduced motion, resize, service outcomes
and device performance through the native review matrix. Browser DOM scans
from the design pack cannot verify those native properties.

Exit status: 0 no new/retired findings and inventory complete; 1 source or
inventory findings need review; 2 inputs could not be read or validated.
