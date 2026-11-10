#!/usr/bin/env python3
"""Exercise required dependency checks and real Qt test result handling."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WRAPPER = ROOT / 'scripts/ci/run-qml-suite.py'


class NativeGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.runner = os.environ.get('QMLTESTRUNNER')
        if not cls.runner or not Path(cls.runner).is_file():
            raise RuntimeError('QMLTESTRUNNER must name the real Qt 6 runner; no skipped coverage')
        cls.cmake = os.environ.get('CMAKE_COMMAND') or shutil.which('cmake')
        if not cls.cmake:
            raise RuntimeError('CMake is required')

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='native gate spaces ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_suite(self, body):
        fixture = self.root / 'tst_contract.qml'
        fixture.write_text('import QtQuick 6.0\nimport QtTest 1.3\nTestCase { name: "GateContract"; ' + body + ' }\n')
        return subprocess.run([sys.executable, str(WRAPPER), '--report', str(self.root / 'report.xml'),
                               '--', self.runner, '-input', str(fixture)], capture_output=True, text=True)

    def test_real_qt_pass_and_failure(self):
        passed = self.run_suite('function test_native() { compare(1, 1) }')
        self.assertEqual(passed.returncode, 0, passed.stdout + passed.stderr)
        self.assertIn('1 test functions/data rows', passed.stdout)
        failed = self.run_suite('function test_native() { compare(1, 2) }')
        self.assertEqual(failed.returncode, 1, failed.stdout + failed.stderr)
        self.assertIn('1 failures', failed.stdout)

    def test_empty_suite_is_not_coverage(self):
        result = self.run_suite('')
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn('zero test functions ran', result.stderr)

    def test_skipped_test_is_not_green(self):
        result = self.run_suite('function test_native() { skip("deliberate contract fixture") }')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('1 skipped', result.stdout)

    def test_missing_tool_is_not_green(self):
        result = subprocess.run([sys.executable, str(WRAPPER), '--report', str(self.root / 'missing.xml'),
                                 '--', str(self.root / 'not-a-runner')], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('FAIL', result.stderr)

    def test_required_configuration_rejects_missing_keel(self):
        result = subprocess.run([self.cmake, '-S', str(ROOT / 'tests/native-ui'), '-B', str(self.root / 'build'),
                                 '-DMARATHON_REQUIRE_NATIVE_UI_TESTS=ON',
                                 f'-DQMLTESTRUNNER={self.runner}', f'-DKEEL_QML={self.root / "no-keel"}'],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Required native UI gate cannot run', result.stdout + result.stderr)

    def test_optional_configuration_reports_missing_coverage(self):
        result = subprocess.run([self.cmake, '-S', str(ROOT / 'tests/native-ui'), '-B', str(self.root / 'build'),
                                 '-DMARATHON_REQUIRE_NATIVE_UI_TESTS=OFF',
                                 f'-DQMLTESTRUNNER={self.runner}', f'-DKEEL_QML={self.root / "no-keel"}'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('NOT REGISTERED', result.stdout)

    def test_qml_target_has_no_dependency_cycle(self):
        source = self.root / 'cmake source'
        source.mkdir()
        (source / 'Clean.qml').write_text('import QtQuick\nItem {}\n')
        (source / 'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.21)\n'
            'project(QmlDependencyContract LANGUAGES NONE)\n'
            f'include("{ROOT / "cmake/QMLLint.cmake"}")\n'
            'add_custom_target(app)\nadd_qmllint_target(app Clean.qml)\n')
        build = self.root / 'cmake build'
        configured = subprocess.run([self.cmake, '-S', str(source), '-B', str(build),
                                     '-DMARATHON_REQUIRE_QMLLINT=ON'], capture_output=True, text=True)
        self.assertEqual(configured.returncode, 0, configured.stdout + configured.stderr)
        run = subprocess.run([self.cmake, '--build', str(build), '--target', 'marathon-qml-validation'],
                             capture_output=True, text=True)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn('PASS: 1 files', run.stdout)

    def test_required_qmllint_rejects_missing_explicit_tool(self):
        source = self.root / 'cmake source'
        source.mkdir()
        (source / 'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.21)\n'
            'project(QmlRequiredContract LANGUAGES NONE)\n'
            f'include("{ROOT / "cmake/QMLLint.cmake"}")\n')
        result = subprocess.run([self.cmake, '-S', str(source), '-B', str(self.root / 'build'),
                                 '-DMARATHON_REQUIRE_QMLLINT=ON',
                                 f'-DQMLLINT_EXECUTABLE={self.root / "no-qmllint"}'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('QML validation is required', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
