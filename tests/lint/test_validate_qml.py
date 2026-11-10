#!/usr/bin/env python3
"""Exercise the entry point with real Qt 6 qmllint, not text-grep fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / 'scripts/validate-qml.sh'


class QmlValidatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        probe = subprocess.run([str(VALIDATOR), '--print-tool'], capture_output=True, text=True)
        if probe.returncode:
            raise RuntimeError(probe.stderr)
        cls.tool = probe.stdout.strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='qml validation spaces ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def qml(self, source, name='source with spaces.qml'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source)
        return path

    def run_validator(self, *args, tool=None):
        env = dict(os.environ, QMLLINT=tool or self.tool)
        env.pop('KEEL_QML', None)
        return subprocess.run([str(VALIDATOR), *map(str, args)], env=env,
                              capture_output=True, text=True)

    def test_clean_files_and_import_paths_with_spaces(self):
        module = self.root / 'imports with spaces' / 'Example'
        module.mkdir(parents=True)
        (module / 'qmldir').write_text('module Example\nWidget 1.0 Widget.qml\n')
        (module / 'Widget.qml').write_text('import QtQuick\nItem {}\n')
        first = self.qml('import Example 1.0\nWidget {}\n')
        second = self.qml('import QtQuick\nItem {}\n', 'another clean.qml')
        result = self.run_validator('-I', module.parent, first, second, first)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS: 2 files', result.stdout)

    def test_syntax_error_preserves_native_failure(self):
        result = self.run_validator(self.qml('import QtQuick\nItem { property string broken: }\n'))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[syntax]', result.stdout)
        self.assertNotIn('qmllint exit 0', result.stdout)

    def test_error_word_in_clean_source_is_not_a_diagnostic(self):
        result = self.run_validator(self.qml('import QtQuick\nItem { property string mmscError: "Error: unavailable" }\n'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('0 errors, 0 warnings', result.stdout)

    def test_warning_excerpt_with_mmsc_error_is_a_warning(self):
        path = self.qml('import QtQuick\nItem { property bool other: true; QtObject { property bool mmscError: !other } }\n')
        # The actual human-readable tool output contains the old false match.
        native = subprocess.run([self.tool, str(path)], capture_output=True, text=True)
        self.assertIn('mmscError:', native.stderr)
        result = self.run_validator(path)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('0 errors, 1 warnings', result.stdout)
        self.assertIn('[unqualified]', result.stdout)

    def test_unresolved_import_is_not_green(self):
        result = self.run_validator(self.qml('import Missing.Marathon.Contract\nItem {}\n'))
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('[import]', result.stdout)

    def test_missing_explicit_tool_does_not_fall_back(self):
        result = self.run_validator(self.qml('import QtQuick\nItem {}\n'), tool=str(self.root / 'not installed'))
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('Qt 6 qmllint is required', result.stderr)

    def test_qt5_executable_is_rejected(self):
        tool = self.root / 'wrong qt version'
        tool.write_text('#!/bin/sh\necho "qmllint 5.15.18"\n')
        tool.chmod(0o755)
        result = self.run_validator(self.qml('import QtQuick\nItem {}\n'), tool=str(tool))
        self.assertEqual(result.returncode, 2)
        self.assertIn('Qt 6 qmllint is required', result.stderr)

    def test_empty_selection_fails(self):
        result = self.run_validator(self.root)
        self.assertEqual(result.returncode, 2)
        self.assertIn('zero validation coverage', result.stderr)

    def test_missing_file_fails(self):
        result = self.run_validator(self.root / 'absent.qml')
        self.assertEqual(result.returncode, 2)
        self.assertIn('does not exist', result.stderr)

    def test_missing_explicit_import_directory_fails(self):
        result = self.run_validator('-I', self.root / 'absent', self.qml('import QtQuick\nItem {}\n'))
        self.assertEqual(result.returncode, 2)
        self.assertIn('import directory does not exist', result.stderr)

    def test_default_scope_includes_shell_apps_and_toolkit(self):
        # Run the same code from a miniature source checkout to assert the
        # command's default scope, including the exclusion of test doubles.
        scripts = self.root / 'scripts'
        scripts.mkdir()
        for name in ('validate-qml.sh', 'validate-qml.py'):
            shutil.copy2(ROOT / 'scripts' / name, scripts / name)
        for name in ('shell/qml/Main.qml', 'apps/notes/Notes.qml', 'marathon-silica/Control.qml'):
            self.qml('import QtQuick\nItem {}\n', name)
        self.qml('invalid test double', 'apps/notes/tests/Stub.qml')
        self.qml('invalid generated file', 'apps/build-generated/Ignore.qml')
        result = subprocess.run([str(scripts / 'validate-qml.sh')], env=dict(os.environ, QMLLINT=self.tool),
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS: 3 files', result.stdout)

    def test_broken_tool_output_never_passes(self):
        # Fault injection tests process/report handling; QML behavior above
        # always comes from the real tool.
        path = self.qml('import QtQuick\nItem {}\n')
        for output, status in [('not JSON', 0), ('{"files":[]}', 0), ('', 23)]:
            with self.subTest(output=output, status=status):
                tool = self.root / 'broken tool'
                tool.write_text('#!/usr/bin/env python3\nimport sys\n'
                                'if "--version" in sys.argv:\n    print("qmllint 6.11.3")\n'
                                f'else:\n    print({output!r})\n    sys.exit({status})\n')
                tool.chmod(0o755)
                result = self.run_validator(path, tool=str(tool))
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn('invalid or incomplete qmllint JSON', result.stderr)


if __name__ == '__main__':
    unittest.main()
