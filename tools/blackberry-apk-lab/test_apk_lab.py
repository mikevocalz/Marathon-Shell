#!/usr/bin/env python3
"""Exercise the local research boundary with synthetic APKs and SDK tools."""

import contextlib
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET
import zipfile

import apk_lab as lab


MANIFEST = b'''<manifest xmlns:android="http://schemas.android.com/apk/res/android"
 package="com.example.hub" android:versionCode="12" android:versionName="1.2">
 <uses-sdk android:minSdkVersion="23" android:targetSdkVersion="35"/>
 <uses-permission android:name="android.permission.READ_CONTACTS"/>
 <permission android:name="com.example.ACCESS" android:protectionLevel="signature"/>
 <queries><package android:name="com.example.services"/></queries>
 <application android:permission="com.example.ACCESS">
  <activity android:name=".Inbox" android:exported="true">
   <intent-filter><action android:name="android.intent.action.VIEW"/>
    <data android:scheme="example" android:host="message"/></intent-filter>
  </activity>
  <provider android:name="Messages" android:authorities="com.example.messages"/>
 </application>
</manifest>'''
FINGERPRINT = "a" * 64


class ApkLabTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / "base $(not-a-command).apk"
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"synthetic binary manifest")
            archive.writestr("classes.dex", b"fixture")
            archive.writestr("lib/arm64-v8a/libexample.so", b"fixture")

    def tool(self, name, body):
        path = self.root / name
        path.write_text(f"#!{sys.executable}\n" + body, encoding="utf-8")
        path.chmod(0o755)
        return str(path)

    def sdk(self, signature_code=0, manifest=MANIFEST):
        return {
            "apksigner": self.tool("apksigner", "import sys\n"
                f"print('Signer #1 certificate SHA-256 digest: {FINGERPRINT}')\n"
                f"sys.exit({signature_code})\n"),
            "apkanalyzer": self.tool("apkanalyzer", "import sys\n"
                "assert sys.argv[1:3] == ['manifest', 'print']\n"
                f"sys.stdout.buffer.write({manifest!r})\n"),
            "jadx": None, "apktool": None, "adb": None,
        }

    def invoke(self, *args, tools=None):
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            with patch.object(lab, "tools_on_path", return_value=tools or dict.fromkeys(lab.TOOLS)):
                return lab.main(list(args))

    def test_archive_inventory_without_extraction(self):
        result = lab.archive_inventory(self.apk)
        self.assertEqual(result["entries"], 3)
        self.assertEqual(result["files"][2]["path"], "lib/arm64-v8a/libexample.so")
        self.assertFalse((self.root / "classes.dex").exists())

    def test_workflow_checks_committed_ranges_with_a_fetched_base(self):
        repository = self.root / "repository"
        repository.mkdir()

        def git(*args, cwd=repository, check=True):
            return subprocess.run(["git", *args], cwd=cwd, capture_output=True,
                                  text=True, check=check)

        def commit(message):
            git("add", ".")
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "commit", "-qm", message)
            return git("rev-parse", "HEAD").stdout.strip()

        git("init", "-q")
        (repository / "fixture.py").write_text("value = 1\n")
        base = commit("fixture: base")
        (repository / "fixture.py").write_text("value = 1\nadded = 2 \n")
        commit("fixture: committed whitespace")
        (repository / "another.py").write_text("clean = True\n")
        head = commit("fixture: later clean commit")
        checkout = self.root / "shallow checkout"
        git("clone", "--quiet", "--depth=1", repository.as_uri(), str(checkout))
        self.assertNotEqual(git("cat-file", "-e", f"{base}^{{commit}}",
                                cwd=checkout, check=False).returncode, 0)
        self.assertEqual(git("status", "--porcelain", cwd=checkout).stdout, "")
        self.assertEqual(git("diff", "--check", cwd=checkout).returncode, 0)
        checker = Path(__file__).with_name("check_whitespace.py")

        def check_range(before, after, cwd=checkout):
            return subprocess.run([sys.executable, str(checker), before, after], cwd=cwd,
                                  capture_output=True, text=True, check=False)

        result = check_range(base, head)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture.py:2: trailing whitespace", result.stdout)
        self.assertEqual(git("cat-file", "-e", f"{base}^{{commit}}", cwd=checkout).returncode, 0)
        self.assertNotEqual(check_range("--output=unexpected", head).returncode, 0)
        self.assertFalse((checkout / "unexpected").exists())
        (repository / "fixture.py").write_text("value = 1\nadded = 2\n")
        corrected = commit("fixture: correct whitespace")
        self.assertEqual(check_range(base, corrected, cwd=repository).returncode, 0)

    def test_workflow_branch_creation_checks_changes_from_default_ancestor(self):
        repository = self.root / "default repository"
        repository.mkdir()

        def git(*args, cwd=repository):
            return subprocess.run(["git", *args], cwd=cwd, capture_output=True,
                                  text=True, check=True)

        def commit(message, cwd=repository):
            git("add", ".", cwd=cwd)
            git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                "commit", "-qm", message, cwd=cwd)
            return git("rev-parse", "HEAD", cwd=cwd).stdout.strip()

        git("init", "-q", "--initial-branch=main")
        (repository / "inherited.py").write_text("inherited = True \n")
        commit("fixture: existing default-branch whitespace")
        checkout = self.root / "new branch checkout"
        git("clone", "--quiet", repository.as_uri(), str(checkout))
        git("checkout", "-qb", "v2", cwd=checkout)
        checker = Path(__file__).with_name("check_whitespace.py")

        def check_creation(default="main", head_ref="refs/heads/v2"):
            head = git("rev-parse", "HEAD", cwd=checkout).stdout.strip()
            return subprocess.run([sys.executable, str(checker), "0" * 40, head,
                                   "--default-branch", default, "--head-ref", head_ref],
                                  cwd=checkout, capture_output=True, text=True, check=False)

        result = check_creation()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("unavailable", result.stdout)
        (checkout / "added.py").write_text("new_whitespace = True \n")
        commit("fixture: new branch whitespace", cwd=checkout)
        result = check_creation()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("added.py:1: trailing whitespace", result.stdout)
        self.assertNotIn("inherited.py", result.stdout)
        for default, head_ref in (("missing", "refs/heads/v2"), ("main", "refs/heads/main")):
            with self.subTest(default=default, head_ref=head_ref):
                result = check_creation(default, head_ref)
                self.assertEqual(result.returncode, 0)
                self.assertIn("range unavailable for branch creation", result.stdout)
        git("checkout", "--orphan", "unrelated", cwd=checkout)
        commit("fixture: unrelated history", cwd=checkout)
        result = check_creation()
        self.assertEqual(result.returncode, 0)
        self.assertIn("unrelated histories", result.stdout)

    def test_inspection_output_is_private_without_changing_input_or_umask(self):
        ancestor = self.root / "existing parent"
        ancestor.mkdir(mode=0o710)
        ancestor_mode = stat.S_IMODE(ancestor.stat().st_mode)
        self.apk.chmod(0o640)
        for mask in (0o000, 0o022):
            with self.subTest(umask=mask):
                output = ancestor / f"inspection-{mask:o}"
                previous = os.umask(mask)
                try:
                    code = self.invoke("inspect", str(self.apk), "--archive-only",
                                       "--output", str(output))
                finally:
                    remaining = os.umask(previous)
                self.assertEqual(code, 0)
                self.assertEqual(remaining, mask)
                self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
                self.assertEqual(stat.S_IMODE(ancestor.stat().st_mode), ancestor_mode)
                self.assertEqual(stat.S_IMODE(self.apk.stat().st_mode), 0o640)
                original = (output / "inventory.json").read_bytes()
                self.assertEqual(self.invoke("inspect", str(self.apk), "--archive-only",
                                             "--output", str(output)), 2)
                self.assertEqual((output / "inventory.json").read_bytes(), original)

    def test_collection_output_is_private_without_changing_parent_or_umask(self):
        adb = self.tool("adb", "import sys\nfrom pathlib import Path\n"
            "if sys.argv[3:6] == ['shell', 'pm', 'path']:\n"
            " print('package:/data/app/example/base.apk')\n"
            "elif sys.argv[3] == 'pull':\n"
            " Path(sys.argv[5]).write_bytes(b'synthetic APK')\n"
            "else:\n raise AssertionError(sys.argv)\n")
        ancestor = self.root / "existing parent"
        ancestor.mkdir(mode=0o710)
        ancestor_mode = stat.S_IMODE(ancestor.stat().st_mode)
        for mask in (0o000, 0o022):
            with self.subTest(umask=mask), patch.object(lab.shutil, "which", return_value=adb):
                output = ancestor / f"collection-{mask:o}"
                previous = os.umask(mask)
                try:
                    code = self.invoke("pull", "--serial", "fixture-device", "--package",
                                       "com.example.hub", "--output", str(output))
                finally:
                    remaining = os.umask(previous)
                self.assertEqual(code, 0)
                self.assertEqual(remaining, mask)
                self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
                self.assertEqual(stat.S_IMODE(ancestor.stat().st_mode), ancestor_mode)
                self.assertEqual((output / "00-base.apk").read_bytes(), b"synthetic APK")
                original = (output / "collection.json").read_bytes()
                self.assertEqual(self.invoke("pull", "--serial", "fixture-device", "--package",
                                             "com.example.hub", "--output", str(output)), 2)
                self.assertEqual((output / "collection.json").read_bytes(), original)

    def test_reject_unsafe_archive_paths(self):
        for name in ("../outside", "/absolute", "a\\..\\b", "C:/drive", "line\nbreak",
                     "a/./b", "a//b", "a//"):
            with self.subTest(name=name):
                bad = self.root / "bad.apk"
                with zipfile.ZipFile(bad, "w") as archive:
                    archive.writestr("AndroidManifest.xml", b"fixture")
                    archive.writestr(name, b"fixture")
                with self.assertRaises(ValueError):
                    lab.archive_inventory(bad)

    def test_reject_symlink_member(self):
        bad = self.root / "link.apk"
        entry = zipfile.ZipInfo("linked")
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        with zipfile.ZipFile(bad, "w") as archive:
            archive.writestr("AndroidManifest.xml", b"fixture")
            archive.writestr(entry, "../target")
        with self.assertRaises(ValueError):
            lab.archive_inventory(bad)

    def test_archive_budget(self):
        with patch.object(lab, "MAX_EXPANDED", 1), self.assertRaises(ValueError):
            lab.archive_inventory(self.apk)

    def test_manifest_components_and_unstated_export(self):
        result = lab.manifest_inventory(MANIFEST)
        self.assertEqual(result["package"], "com.example.hub")
        self.assertEqual(result["version_code"], "12")
        self.assertEqual(result["queried_packages"], ["com.example.services"])
        activity, provider = result["components"]
        self.assertEqual(activity["name"], "com.example.hub.Inbox")
        self.assertEqual(provider["name"], "com.example.hub.Messages")
        self.assertIsNone(provider["exported_declared"])
        self.assertEqual(provider["permission"], "com.example.ACCESS")
        self.assertEqual(activity["intent_filters"][0]["data"][0]["host"], "message")

    def test_provider_permissions_keep_declared_and_effective_controls(self):
        android = "{http://schemas.android.com/apk/res/android}"
        app_permission, common = "com.example.APP", "com.example.PROVIDER"
        read, write = "com.example.READ", "com.example.WRITE"
        cases = [
            ("separate", app_permission, common, read, write,
             (app_permission, common, read, write)),
            ("provider_fallback", app_permission, common, None, None,
             (app_permission, common, common, common)),
            ("application_fallback", app_permission, None, None, None,
             (app_permission, app_permission, app_permission, app_permission)),
            ("absent", None, None, None, None, (None, None, None, None)),
            ("clear_provider", app_permission, "", None, None,
             (app_permission, None, None, None)),
            ("clear_read", app_permission, common, "", None,
             (app_permission, common, None, common)),
            ("clear_write", app_permission, common, None, "",
             (app_permission, common, common, None)),
            ("clear_application_read", app_permission, None, "", None,
             (app_permission, app_permission, None, app_permission)),
            ("clear_application", "", None, None, None, (None, None, None, None)),
            ("read_over_cleared_provider", app_permission, "", read, None,
             (app_permission, None, read, None)),
        ]
        for name, app_value, provider_value, read_value, write_value, effective in cases:
            with self.subTest(name=name):
                root = ET.fromstring(MANIFEST)
                app = root.find("application")
                if app_value is None:
                    del app.attrib[android + "permission"]
                else:
                    app.set(android + "permission", app_value)
                provider = app.find("provider")
                for attribute, value in [("permission", provider_value),
                                         ("readPermission", read_value), ("writePermission", write_value)]:
                    if value is not None:
                        provider.set(android + attribute, value)
                inventory = lab.manifest_inventory(ET.tostring(root))
                provider = inventory["components"][1]
                self.assertEqual(inventory["application_permission_declared"], app_value)
                self.assertEqual(provider["permission_declared"], provider_value)
                self.assertEqual(provider["read_permission_declared"], read_value)
                self.assertEqual(provider["write_permission_declared"], write_value)
                self.assertEqual((inventory["application_permission_effective"],
                                  provider["permission_effective"], provider["read_permission_effective"],
                                  provider["write_permission_effective"]), effective)

    def test_reject_manifest_entities_and_oversize(self):
        with self.assertRaises(ValueError):
            lab.manifest_inventory(b'<!DOCTYPE manifest [<!ENTITY x "expanded">]>' + MANIFEST)
        with patch.object(lab, "MAX_MANIFEST", 1), self.assertRaises(ValueError):
            lab.manifest_inventory(MANIFEST)

    def test_archive_only_is_explicit_and_does_not_call_tools(self):
        output = self.root / "archive evidence"
        with patch.object(lab, "run", side_effect=AssertionError("unexpected tool execution")):
            code = self.invoke("inspect", str(self.apk), "--output", str(output), "--archive-only")
        self.assertEqual(code, 0)
        report = json.loads((output / "inventory.json").read_text())
        self.assertEqual(report["analysis_level"], "archive_only")
        self.assertNotIn("manifest", report["apks"][0])
        self.assertEqual(report["apks"][0]["sha256"], lab.sha256(self.apk))

    def test_missing_tools_produce_incomplete_report(self):
        output = self.root / "missing"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output)), 2)
        report = json.loads((output / "inventory.json").read_text())
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(len(report["problems"]), 2)

    def test_full_inspection_with_literal_path_and_synthetic_sdk(self):
        output = self.root / "full evidence"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output), tools=self.sdk()), 0)
        report = json.loads((output / "inventory.json").read_text())
        self.assertEqual(report["status"], "complete")
        self.assertEqual(report["apks"][0]["signers_sha256"], [FINGERPRINT])
        self.assertEqual(report["apks"][0]["manifest"]["package"], "com.example.hub")

    def test_manifest_stderr_is_evidence_not_xml(self):
        tools = self.sdk()
        tools["apkanalyzer"] = self.tool("apkanalyzer", "import sys\n"
            "print('synthetic JVM warning', file=sys.stderr)\n"
            f"sys.stdout.buffer.write({MANIFEST!r})\n")
        output = self.root / "manifest with warning"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output), tools=tools), 0)
        self.assertEqual((output / "apk-01/manifest.xml").read_bytes(), MANIFEST)
        self.assertIn("synthetic JVM warning", (output / "apk-01/manifest-stderr.txt").read_text())

    def test_invalid_signature_blocks_decompilation(self):
        tools = self.sdk(signature_code=1)
        marker = self.root / "decoder-ran"
        body = f"from pathlib import Path\nPath({str(marker)!r}).touch()\n"
        tools.update(jadx=self.tool("jadx", body), apktool=self.tool("apktool", body))
        output = self.root / "invalid signature"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output),
                                     "--decompile", tools=tools), 2)
        self.assertFalse(marker.exists())
        report = json.loads((output / "inventory.json").read_text())
        self.assertIn("apk-01: signature failed", report["problems"])

    def test_decoder_failure_is_not_reported_as_success(self):
        tools = self.sdk()
        tools.update(jadx=self.tool("jadx", "import sys\nsys.exit(7)\n"),
                     apktool=self.tool("apktool", "print('synthetic decode')\n"))
        output = self.root / "decoder failure"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output),
                                     "--decompile", tools=tools), 2)
        report = json.loads((output / "inventory.json").read_text())
        self.assertIn("apk-01: jadx failed", report["problems"])
        self.assertEqual(report["analysis_level"], "manifest_signature_and_decompilation")

    def test_refuse_existing_output_and_duplicate_inputs(self):
        for inputs in ([str(self.apk)], [str(self.apk), str(self.apk)]):
            with self.subTest(inputs=inputs):
                self.assertEqual(self.invoke("inspect", *inputs, "--output", str(self.root), "--archive-only"), 2)
        self.assertEqual(len(list(self.root.glob("*.apk"))), 1)

    def test_invalid_manifest_remains_incomplete(self):
        output = self.root / "invalid manifest"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output),
                                     tools=self.sdk(manifest=b"warning followed by invalid XML")), 2)
        self.assertEqual(json.loads((output / "inventory.json").read_text())["status"], "incomplete")

    def test_split_identity_checks(self):
        base = {"manifest": lab.manifest_inventory(MANIFEST), "signers_sha256": [FINGERPRINT]}
        split = {"manifest": dict(base["manifest"], split="config.arm64_v8a"),
                 "signers_sha256": [FINGERPRINT]}
        self.assertEqual(lab.check_groups([base, split]), [])
        self.assertTrue(lab.check_groups([split]))
        self.assertTrue(lab.check_groups([base, base]))
        split["manifest"]["version_code"] = "13"
        self.assertTrue(any("mixed version" in p for p in lab.check_groups([base, split])))
        split["manifest"]["version_code"] = "12"
        split["signers_sha256"] = ["b" * 64]
        self.assertTrue(any("signer" in p for p in lab.check_groups([base, split])))
        base["manifest"]["uses_splits"] = ["feature.missing"]
        self.assertTrue(any("dependency" in p for p in lab.check_groups([base])))

    def test_configuration_split_requires_its_feature_and_same_major_version(self):
        base = {"manifest": lab.manifest_inventory(MANIFEST), "signers_sha256": [FINGERPRINT]}
        feature = {"manifest": dict(base["manifest"], split="feature"), "signers_sha256": [FINGERPRINT]}
        config_xml = MANIFEST.replace(b'package="com.example.hub"',
            b'package="com.example.hub" split="feature.config.en" configForSplit="feature"')
        config = {"manifest": lab.manifest_inventory(config_xml), "signers_sha256": [FINGERPRINT]}
        self.assertTrue(any("dependency" in p for p in lab.check_groups([base, config])))
        self.assertEqual(lab.check_groups([base, feature, config]), [])
        feature["manifest"]["version_code_major"] = "1"
        self.assertTrue(any("mixed version" in p for p in lab.check_groups([base, feature, config])))

    def test_split_namespace_provenance_and_missing_feature(self):
        base = {"manifest": lab.manifest_inventory(MANIFEST), "signers_sha256": [FINGERPRINT]}
        feature = {"manifest": dict(base["manifest"], split="feature"), "signers_sha256": [FINGERPRINT]}
        for declaration, source, declared in [
            (b'configForSplit="feature"', "unqualified",
             {"unqualified": "feature", "android_namespace": None}),
            (b'android:configForSplit="feature"', "android_namespace_legacy",
             {"unqualified": None, "android_namespace": "feature"}),
            (b'configForSplit="feature" android:configForSplit="feature"', "unqualified",
             {"unqualified": "feature", "android_namespace": "feature"}),
        ]:
            with self.subTest(declaration=declaration):
                xml = MANIFEST.replace(b'package="com.example.hub"',
                    b'package="com.example.hub" split="feature.config.en" ' + declaration)
                manifest = lab.manifest_inventory(xml)
                self.assertEqual(manifest["config_for_split"], "feature")
                self.assertEqual(manifest["config_for_split_source"], source)
                self.assertEqual(manifest["config_for_split_declared"], declared)
                config = {"manifest": manifest, "signers_sha256": [FINGERPRINT]}
                self.assertTrue(any("dependency" in p for p in lab.check_groups([base, config])))
                self.assertEqual(lab.check_groups([base, feature, config]), [])

    def test_conflicting_split_namespaces_remain_incomplete(self):
        xml = MANIFEST.replace(b'package="com.example.hub"',
            b'package="com.example.hub" split="config.en" '
            b'configForSplit="feature" android:configForSplit="other"')
        output = self.root / "conflicting split namespaces"
        self.assertEqual(self.invoke("inspect", str(self.apk), "--output", str(output),
                                     tools=self.sdk(manifest=xml)), 2)
        report = json.loads((output / "inventory.json").read_text())
        self.assertEqual(report["status"], "incomplete")
        self.assertTrue(any("conflicting configForSplit" in p for p in report["problems"]))

    def test_tool_timeout_is_explicit(self):
        result = lab.run([sys.executable, "-c", "import time; time.sleep(10)"],
                         self.root / "timeout.txt", 0.05)
        self.assertEqual(result["status"], "timeout")

    def test_collect_every_split_with_explicit_device(self):
        adb = self.tool("adb", "import sys\nfrom pathlib import Path\n"
            "assert sys.argv[1:3] == ['-s', 'device-123']\n"
            "if sys.argv[3:6] == ['shell', 'pm', 'path']:\n"
            " print('package:/data/app/example/base.apk')\n"
            " print('package:/data/app/example/split_config.arm64_v8a.apk')\n"
            "elif sys.argv[3] == 'pull':\n"
            " Path(sys.argv[5]).write_bytes(b'synthetic APK')\n"
            "else:\n raise AssertionError(sys.argv)\n")
        output = self.root / "collected"
        with patch.object(lab.shutil, "which", return_value=adb):
            self.assertEqual(self.invoke("pull", "--serial", "device-123", "--package", "com.example.hub",
                                         "--output", str(output)), 0)
        report = json.loads((output / "collection.json").read_text())
        self.assertEqual(report["device_serial"], "device-123")
        self.assertTrue(report["created_at"])
        self.assertEqual(len(report["apks"]), 2)
        self.assertEqual(len(list(output.glob("*.apk"))), 2)

    def test_collection_keeps_adb_stderr_separate_from_package_paths(self):
        adb = self.tool("adb", "import sys\nfrom pathlib import Path\n"
            "assert sys.argv[1:3] == ['-s', 'device-123']\n"
            "if sys.argv[3:6] == ['shell', 'pm', 'path']:\n"
            " print('* daemon not running; starting now at tcp:5037', file=sys.stderr)\n"
            " print('* daemon started successfully', file=sys.stderr)\n"
            " print('package:/data/app/example/base.apk')\n"
            "elif sys.argv[3] == 'pull':\n"
            " Path(sys.argv[5]).write_bytes(b'synthetic APK')\n")
        output = self.root / "adb starting"
        with patch.object(lab.shutil, "which", return_value=adb):
            self.assertEqual(self.invoke("pull", "--serial", "device-123", "--package", "com.example.hub",
                                         "--output", str(output)), 0)
        self.assertEqual((output / "package-paths.txt").read_text(),
                         "package:/data/app/example/base.apk\n")
        self.assertIn("daemon started successfully", (output / "package-paths-stderr.txt").read_text())
        report = json.loads((output / "collection.json").read_text())
        self.assertEqual(len(report["apks"]), 1)

    def test_failed_pm_path_retains_diagnostics_and_no_completion_manifest(self):
        adb = self.tool("adb", "import sys\n"
            "print('error: device unauthorized', file=sys.stderr)\n"
            "sys.exit(1)\n")
        output = self.root / "adb refused"
        with patch.object(lab.shutil, "which", return_value=adb):
            self.assertEqual(self.invoke("pull", "--serial", "device-123", "--package", "com.example.hub",
                                         "--output", str(output)), 2)
        self.assertEqual((output / "package-paths.txt").read_text(), "")
        self.assertIn("device unauthorized", (output / "package-paths-stderr.txt").read_text())
        self.assertFalse((output / "collection.json").exists())

    def test_collection_rejects_package_shell_syntax(self):
        with patch.object(lab, "run", side_effect=AssertionError("unexpected tool execution")):
            self.assertEqual(self.invoke("pull", "--serial", "device-123", "--package", "com.example;id",
                                         "--output", str(self.root / "rejected")), 2)

    def test_partial_collection_has_no_completion_manifest(self):
        adb = self.tool("adb", "import sys\n"
            "if 'path' in sys.argv:\n print('package:/data/app/example/base.apk')\n"
            "else:\n sys.exit(1)\n")
        output = self.root / "failed pull"
        with patch.object(lab.shutil, "which", return_value=adb):
            self.assertEqual(self.invoke("pull", "--serial", "device-123", "--package", "com.example.hub",
                                         "--output", str(output)), 2)
        self.assertFalse((output / "collection.json").exists())


if __name__ == "__main__":
    unittest.main()
