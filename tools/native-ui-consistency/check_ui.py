#!/usr/bin/env python3
"""Detect new direct QML style literals and control-import drift.

This is a narrow lexical check, not a QML parser or a visual/accessibility test.
The reviewed baseline records existing debt; it does not certify that debt.
"""
import argparse
from collections import Counter
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
RULES = {
    "color": "Use Theme or MColors semantic color roles.",
    "font": "Use Theme or MTypography font roles.",
    "radius": "Use the shared radius family; document intentional object geometry.",
    "spacing": "Use Theme padding/margins or MSpacing.",
    "controls": "Use the native Keel/Marathon.Silica control family.",
    "silica-import": "Import Marathon.Silica after unaliased Sailfish.Silica controls.",
}
TOKEN = re.compile(
    r"(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)"
    r"|(?P<string>\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)"
    r"|(?P<number>(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)"
    r"|(?P<name>[A-Za-z_]\w*)|(?P<other>[^\s])"
)
SPACING = {"spacing", "padding", "leftPadding", "rightPadding", "topPadding", "bottomPadding",
           "rowSpacing", "columnSpacing", "Layout.margins", "Layout.leftMargin", "Layout.rightMargin",
           "Layout.topMargin", "Layout.bottomMargin",
           "anchors.margins", "anchors.leftMargin", "anchors.rightMargin",
           "anchors.topMargin", "anchors.bottomMargin"}
COLOR = {"color", "border.color", "backgroundColor", "highlightColor", "textColor",
         "selectionColor", "selectedTextColor"}

@dataclass(frozen=True)
class Finding:
    path: str
    rule: str
    expression: str
    line: int

    def key(self):
        return self.path, self.rule, self.expression


def tokens(source):
    return [(m.lastgroup, m.group(), m.start(), m.end())
            for m in TOKEN.finditer(source) if m.lastgroup != "comment"]


def scan(path, source, shadowed):
    ts = tokens(source)
    findings = []
    def add(rule, expression, offset):
        findings.append(Finding(path, rule, expression, source.count("\n", 0, offset) + 1))

    # Grouped font/anchors/border properties and qualified property bindings
    # share a spelling for baseline comparison. Strings/comments are never code.
    stack = []
    for i, (kind, value, start, end) in enumerate(ts):
        if value == "{":
            prev = ts[i - 1][1] if i else ""
            stack.append(prev if prev in {"font", "anchors", "border", "Layout"} else "")
            continue
        if value == "}":
            if stack:
                stack.pop()
            continue
        if kind != "name":
            continue
        typed_property = i >= 2 and ts[i - 2][1] == "property"
        if i and not typed_property and ts[i - 1][1] not in {"{", ";", "}"} and "\n" not in source[ts[i - 1][3]:start]:
            continue
        j = i + 1
        name = value
        while j + 1 < len(ts) and ts[j][1] == "." and ts[j + 1][0] == "name":
            name += "." + ts[j + 1][1]
            j += 2
        # Only inspect the beginning of a qualified name.
        if i and ts[i - 1][1] == ".":
            continue
        if j + 1 >= len(ts) or ts[j][1] != ":":
            continue
        if stack and stack[-1] and "." not in name:
            name = stack[-1] + "." + name
        k = j + 2
        while k < len(ts) and ts[k][1] not in {";", "}"} and "\n" not in source[ts[k-1][3]:ts[k][2]]:
            k += 1
        expression = "".join(t[1] for t in ts[j + 1:k])
        value_index = j + 1
        while value_index < k and ts[value_index][1] == "(":
            value_index += 1
        if value_index == k:
            continue
        literal_kind, literal, _, _ = ts[value_index]
        rule = None
        typed_color = i >= 2 and ts[i - 2][1] == "property" and ts[i - 1][1] == "color"
        if (name in COLOR or typed_color) and literal_kind == "string" and literal[1:-1] != "transparent":
            rule = "color"
        elif (name in COLOR or typed_color) and re.fullmatch(r"Qt\.(?:rgba|hsla|hsva)\([-+\d.eE]+,[-+\d.eE]+,[-+\d.eE]+,[-+\d.eE]+\)", expression):
            rule = "color"
        elif name in {"font.family", "font.pixelSize", "font.pointSize"} and literal_kind in {"string", "number"}:
            rule = "font"
        elif name == "radius" and literal_kind == "number" and float(literal) > 0:
            rule = "radius"
        elif name in SPACING and literal_kind == "number" and float(literal) > 0:
            semantic_multiple = re.fullmatch(r"[\d.]+\*(?:(?:\w+\.)?Theme\.(?:padding\w+|horizontalPageMargin)|MSpacing\.\w+)", expression)
            if not semantic_multiple:
                rule = "spacing"
        if rule:
            # Include the binding expression, so replacing one literal with
            # another cannot spend an unrelated baseline allowance.
            expr = name + ":" + expression
            add(rule, expr, start)

    # Imports are taken from tokens at the start of a source line, never from
    # a quoted description or commented example.
    imports = []
    for i, t in enumerate(ts):
        if t[0:2] != ("name", "import"):
            continue
        start = t[2]
        if source[source.rfind("\n", 0, start) + 1:start].strip():
            continue
        line_end = source.find("\n", t[3])
        line_end = len(source) if line_end < 0 else line_end
        parts = [x[1] for x in ts[i+1:] if x[2] < line_end]
        imports.append(("".join(parts).split("as")[0], "as" in parts, start))
    for module, _, start in imports:
        if module.startswith("QtQuick.Controls"):
            add("controls", "import:" + module, start)
    silica = next((x for x in imports if re.fullmatch(r"Sailfish\.Silica(?:[\d.]+)?", x[0]) and not x[1]), None)
    marathon = next((x for x in imports if re.fullmatch(r"Marathon\.Silica(?:[\d.]+)?", x[0]) and not x[1]), None)
    uses_control = any(t[0] == "name" and t[1] in shadowed and i + 1 < len(ts)
                       and ts[i+1][1] == "{" and (i == 0 or ts[i-1][1] != ".")
                       for i, t in enumerate(ts))
    if silica and uses_control and (not marathon or marathon[2] < silica[2]):
        add("silica-import", "native-control-import-order", silica[2])
    return findings


def production_paths(root):
    for directory in ("apps", "shell/qml", "marathon-silica/Marathon/Silica"):
        for path in sorted((root / directory).rglob("*.qml")):
            rel = path.relative_to(root)
            if "tests" in rel.parts or rel.parts[:2] == ("apps", "test"):
                continue
            yield path


def collect(root, policy):
    qmldir = root / "marathon-silica/Marathon/Silica/qmldir"
    shadowed = set(re.findall(r"^(\w+)\s+\d", qmldir.read_text(), re.M))
    owners = policy["token_owners"]
    findings = []
    for path in production_paths(root):
        rel = path.relative_to(root).as_posix()
        allowed = owners.get(rel, [])
        findings.extend(f for f in scan(rel, path.read_text(), shadowed) if f.rule not in allowed)
    return findings


def inventory_errors(root, policy):
    if policy.get("schema") != 1:
        return ["Unsupported native UI policy schema"]
    expected = {p.name for p in (root / "apps").iterdir()
                if p.is_dir() and any("tests" not in q.relative_to(p).parts for q in p.rglob("*.qml"))}
    rows = policy["apps"]
    names = [row["directory"] for row in rows]
    errors = []
    if len(names) != len(set(names)):
        errors.append("Duplicate app in the native review inventory.")
    if expected != set(names):
        errors.append("App inventory mismatch: missing=" + repr(sorted(expected - set(names)))
                      + ", stale=" + repr(sorted(set(names) - expected)))
    for row in rows:
        if not row.get("journey") or row.get("stage") not in {"native-review-needed", "support-only"}:
            errors.append("Every app needs a concrete journey and an honest review stage: " + row["directory"])
    for path, rules in policy["token_owners"].items():
        if not (root / path).is_file() or not rules or set(rules) - RULES.keys():
            errors.append("Invalid token owner: " + path)
    return errors


def baseline_counts(data):
    if data.get("schema") != 1:
        raise ValueError("Unsupported baseline schema")
    counts = Counter()
    for row in data["findings"]:
        key = row["path"], row["rule"], row["expression"]
        if row["rule"] not in RULES or type(row["count"]) is not int or row["count"] <= 0 or key in counts:
            raise ValueError("Invalid or duplicate baseline entry")
        counts[key] = row["count"]
    return counts


def compare(findings, baseline):
    remaining = baseline.copy()
    regressions = []
    for finding in findings:
        if remaining[finding.key()] > 0:
            remaining[finding.key()] -= 1
        else:
            regressions.append(finding)
    return regressions


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--report", action="store_true", help="List all current debt; no visual qualification implied")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    directory = root / "tools/native-ui-consistency"
    try:
        policy = json.loads((directory / "policy.json").read_text())
        baseline = baseline_counts(json.loads((directory / "baseline.json").read_text()))
        errors = inventory_errors(root, policy)
        findings = collect(root, policy)
        new = compare(findings, baseline)
        retired = baseline - Counter(f.key() for f in findings)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        print("UI consistency check could not run: " + str(exc), file=sys.stderr)
        return 2
    for error in errors:
        print(error, file=sys.stderr)
    for path, rule, expression in retired:
        print(f"Remove retired baseline allowance: {path}: {rule}: {expression}", file=sys.stderr)
    for finding in findings if args.report else new:
        print(f"{finding.path}:{finding.line}: {finding.rule}: {finding.expression} — {RULES[finding.rule]}")
    print(f"Native UI source check: {len(new)} new findings; {len(findings) - len(new)} inherited findings; "
          f"{len(policy['apps'])} app inventory entries. Native visual review is separate.")
    return 1 if new or errors or retired else 0


if __name__ == "__main__":
    sys.exit(main())
