#!/usr/bin/env python3
import json
from pathlib import Path
import tempfile
import unittest

import check_ui as ui

class StyleRules(unittest.TestCase):
    def scan(self, source):
        return ui.scan("apps/example/Page.qml", source, {"Button", "ListItem", "Page"})

    def test_comments_and_strings_are_not_bindings(self):
        self.assertEqual(self.scan('Item {\n// color: "red"\n/* radius: 99 */\n'
            'property string sample: "font.pixelSize: 12"\n'
            'property string sample2: `radius: 25`\n}'), [])

    def test_direct_style_literals_and_grouped_properties(self):
        source = 'Item {\ncolor: "#ffffff"\nfont {\n pixelSize: 14\n family: "New Font"\n}\n'
        source += 'radius: 12\nanchors {\n leftMargin: 7\n}\nspacing: 13\n}'
        self.assertEqual([f.rule for f in self.scan(source)], ["color", "font", "font", "radius", "spacing", "spacing"])

    def test_semantic_roles_transparency_and_zero_spacing(self):
        source = 'Item {\ncolor: Theme.primaryColor\nradius: MRadius.md\nfont.pixelSize: Theme.fontSizeSmall\n'
        source += 'anchors.margins: 0\nspacing: 0\ncolor: "transparent"\n}'
        self.assertEqual(self.scan(source), [])

    def test_single_quotes_and_custom_color_property(self):
        findings = self.scan("Item {\nreadonly property color localAccent: 'red'\n}")
        self.assertEqual([f.rule for f in findings], ["color"])
        self.assertEqual(findings[0].line, 2)

    def test_scaled_local_literals_are_still_local(self):
        self.assertEqual(self.scan("Item { radius: 20 * Theme.pixelRatio }")[0].rule, "radius")

    def test_semantic_spacing_multiples_do_not_hide_extra_literals(self):
        self.assertEqual(self.scan("Item { spacing: 2 * Theme.paddingLarge }"), [])
        self.assertEqual(self.scan("Item { spacing: Theme.paddingLarge * 2 }"), [])
        self.assertEqual(self.scan("Item { spacing: 2 * Theme.paddingLarge + 13 }")[0].rule, "spacing")

    def test_layout_spacing_and_parenthesized_literals(self):
        source = 'GridLayout { rowSpacing: 17; columnSpacing: 19; Layout.leftMargin: 21; radius: (23); color: ("red") }'
        self.assertEqual([f.rule for f in self.scan(source)], ["spacing", "spacing", "spacing", "radius", "color"])
        self.assertEqual(self.scan("Item { Layout { leftMargin: 21 } }")[0].rule, "spacing")

    def test_literal_color_functions_and_semantic_color_functions(self):
        self.assertEqual(self.scan("Item { color: Qt.rgba(0, 0, 0, 0.5) }")[0].rule, "color")
        self.assertEqual(self.scan("Item { color: Qt.rgba(Theme.overlayBackgroundColor.r, Theme.overlayBackgroundColor.g, Theme.overlayBackgroundColor.b, 1) }"), [])

    def test_ternary_branch_is_not_a_property_declaration(self):
        self.assertEqual(self.scan('Item { source: "image://theme/test" + (pressed ? "?" + highlightColor : "") }'), [])

    def test_control_import_order(self):
        source = "import Marathon.Silica 1.0\nimport Sailfish.Silica 1.0\nButton {}"
        self.assertEqual([f.rule for f in self.scan(source)], ["silica-import"])
        source = "import Sailfish.Silica 1.0\nimport Marathon.Silica 1.0\nButton {}"
        self.assertEqual(self.scan(source), [])

    def test_alias_does_not_shadow_unqualified_controls(self):
        source = "import Sailfish.Silica 1.0\nimport Marathon.Silica 1.0 as M\nButton {}"
        self.assertEqual([f.rule for f in self.scan(source)], ["silica-import"])
        self.assertEqual(self.scan("import Sailfish.Silica as S\nS.Button {}"), [])

    def test_unused_silica_import_and_fake_import_string(self):
        source = 'import Sailfish.Silica 1.0\nItem {\nproperty string example: "import QtQuick.Controls"\n}'
        self.assertEqual(self.scan(source), [])

    def test_foreign_control_family_is_visible(self):
        self.assertEqual([f.rule for f in self.scan("import QtQuick.Controls 2.15 as C\nC.Button {}")], ["controls"])

    def test_baseline_is_exact_and_counts_duplicates(self):
        before = self.scan('Item {\ncolor: "red"\n}')
        baseline = ui.Counter(f.key() for f in before)
        self.assertEqual(ui.compare(self.scan('// shifted\nItem {\ncolor: /* why */ "red"\n}'), baseline), [])
        self.assertEqual(len(ui.compare(self.scan('Item {\ncolor: "blue"\n}'), baseline)), 1)
        self.assertEqual(len(ui.compare(self.scan('Item {\ncolor: "red"\n}\nItem {\ncolor: "red"\n}'), baseline)), 1)
        moved = [ui.Finding("apps/other/Page.qml", f.rule, f.expression, f.line) for f in before]
        self.assertEqual(len(ui.compare(moved, baseline)), 1)

    def test_baseline_rejects_unknown_rules_duplicate_or_invalid_counts(self):
        row = {"path": "apps/a.qml", "rule": "color", "expression": 'color:"red"', "count": 1}
        for data in [{"schema": 2, "findings": []}, {"schema": 1, "findings": [row, row]},
                     {"schema": 1, "findings": [dict(row, count=0)]},
                     {"schema": 1, "findings": [dict(row, count=True)]},
                     {"schema": 1, "findings": [dict(row, rule="unknown")]}]:
            with self.subTest(data=data), self.assertRaises(ValueError):
                ui.baseline_counts(data)

    def test_inventory_detects_new_app_without_journey(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "apps/newapp").mkdir(parents=True)
            (root / "apps/newapp/Main.qml").write_text("Item {}")
            policy = {"schema": 1, "apps": [], "token_owners": {}}
            self.assertIn("newapp", ui.inventory_errors(root, policy)[0])
            policy["apps"] = [{"directory": "newapp", "journey": "Open an item and return.",
                               "stage": "native-review-needed"}]
            self.assertEqual(ui.inventory_errors(root, policy), [])
            policy["apps"][0]["stage"] = "verified"
            self.assertTrue(ui.inventory_errors(root, policy))

    def test_nested_app_inventory_and_fixture_only_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path in ["apps/newapp/ui/Main.qml", "apps/fixture/tests/Fake.qml"]:
                p = root / path
                p.parent.mkdir(parents=True)
                p.write_text("Item {}")
            errors = ui.inventory_errors(root, {"schema": 1, "apps": [], "token_owners": {}})
            self.assertIn("newapp", errors[0])
            self.assertNotIn("fixture", errors[0])
            self.assertEqual(ui.inventory_errors(root, {"schema": 2}), ["Unsupported native UI policy schema"])

    def test_removed_debt_must_retire_its_allowance(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "apps").mkdir()
            directory = root / "tools/native-ui-consistency"
            directory.mkdir(parents=True)
            module = root / "marathon-silica/Marathon/Silica"
            module.mkdir(parents=True)
            (module / "qmldir").write_text("module Marathon.Silica\n")
            (directory / "policy.json").write_text(json.dumps({"schema": 1, "apps": [], "token_owners": {}}))
            baseline = {"schema": 1, "findings": [{"path": "apps/removed.qml", "rule": "color", "expression": 'color:"red"', "count": 1}]}
            (directory / "baseline.json").write_text(json.dumps(baseline))
            self.assertEqual(ui.main(["--root", tmp]), 1)
            baseline["findings"] = []
            (directory / "baseline.json").write_text(json.dumps(baseline))
            self.assertEqual(ui.main(["--root", tmp]), 0)

    def test_token_ownership_is_scoped_to_rule_and_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            module = root / "marathon-silica/Marathon/Silica"
            module.mkdir(parents=True)
            (module / "qmldir").write_text("module Marathon.Silica\nButton 1.0 Button.qml\n")
            theme = root / "shell/qml/theme"
            theme.mkdir(parents=True)
            (theme / "MColors.qml").write_text('Item {\ncolor: "red"\nradius: 20\n}')
            findings = ui.collect(root, {"token_owners": {"shell/qml/theme/MColors.qml": ["color"]}})
            self.assertEqual([f.rule for f in findings], ["radius"])

    def test_production_scope_excludes_fixtures_but_covers_templates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path in ["apps/example/Main.qml", "apps/example/tests/Fixture.qml",
                         "apps/template/TemplateApp.qml", "apps/test/TestApp.qml",
                         "shell/qml/Main.qml", "marathon-silica/Marathon/Silica/Button.qml"]:
                p = root / path
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text("Item {}")
            self.assertEqual(len(list(ui.production_paths(root))), 4)

    def test_missing_configuration_is_not_a_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(ui.main(["--root", tmp]), 2)

if __name__ == "__main__":
    unittest.main()
