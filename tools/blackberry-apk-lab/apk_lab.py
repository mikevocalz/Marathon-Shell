#!/usr/bin/env python3
"""Collect local APK evidence for the Artcraft/Marathon research workflow."""

import argparse
from contextlib import ExitStack
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import stat
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile


ANDROID = "{http://schemas.android.com/apk/res/android}"
PACKAGE = re.compile(r"[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+")
MAX_MANIFEST = 8 * 1024 * 1024
MAX_EXPANDED = 2 * 1024 * 1024 * 1024
MAX_ENTRIES = 100_000
TOOLS = ("apkanalyzer", "apksigner", "jadx", "apktool", "adb")


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def archive_inventory(path):
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if len(entries) > MAX_ENTRIES:
            raise ValueError("archive has too many entries")
        seen = set()
        total = 0
        files = []
        for entry in entries:
            name = entry.filename
            parts = PurePosixPath(name).parts
            if (not parts or name.startswith("/") or "\\" in name
                    or ".." in parts or ":" in parts[0]
                    or PurePosixPath(name).as_posix() != (name[:-1] if entry.is_dir() else name)
                    or any(ord(char) < 32 for char in name)):
                raise ValueError("unsafe archive member name")
            if name in seen:
                raise ValueError("duplicate archive member name")
            seen.add(name)
            if stat.S_ISLNK(entry.external_attr >> 16) or entry.flag_bits & 1:
                raise ValueError("symlink or encrypted archive member")
            total += entry.file_size
            if total > MAX_EXPANDED:
                raise ValueError("archive exceeds expanded-size budget")
            if not entry.is_dir():
                files.append({"path": name, "bytes": entry.file_size})
        if "AndroidManifest.xml" not in seen:
            raise ValueError("AndroidManifest.xml is missing")
    return {"entries": len(entries), "expanded_bytes": total, "files": files}


def manifest_inventory(raw):
    if len(raw) > MAX_MANIFEST:
        raise ValueError("decoded manifest exceeds size budget")
    if b"<!DOCTYPE" in raw.upper() or b"<!ENTITY" in raw.upper():
        raise ValueError("DTD/entity declarations are not supported")
    root = ET.fromstring(raw)
    if root.tag != "manifest" or not PACKAGE.fullmatch(root.get("package", "")):
        raise ValueError("manifest has no valid package identity")
    package = root.get("package")
    app = root.find("application")
    sdk = root.find("uses-sdk")
    components = []
    if app is not None:
        for node in app:
            if node.tag not in ("activity", "activity-alias", "service", "receiver", "provider"):
                continue
            name = node.get(ANDROID + "name", "")
            if name.startswith("."):
                name = package + name
            elif name and "." not in name:
                name = package + "." + name
            components.append({
                "type": node.tag, "name": name,
                "exported_declared": node.get(ANDROID + "exported"),
                "permission": node.get(ANDROID + "permission", app.get(ANDROID + "permission")),
                "authorities": node.get(ANDROID + "authorities"),
                "process": node.get(ANDROID + "process", app.get(ANDROID + "process")),
                "intent_filters": [
                    {"actions": [e.get(ANDROID + "name") for e in intent.findall("action")],
                     "categories": [e.get(ANDROID + "name") for e in intent.findall("category")],
                     "data": [{k.removeprefix(ANDROID): v for k, v in e.attrib.items()}
                              for e in intent.findall("data")]}
                    for intent in node.findall("intent-filter")],
            })
    return {
        "package": package, "version_code": root.get(ANDROID + "versionCode"),
        "version_code_major": root.get(ANDROID + "versionCodeMajor", "0"),
        "version_name": root.get(ANDROID + "versionName"), "split": root.get("split") or None,
        "config_for_split": root.get("configForSplit"),
        "min_sdk": sdk.get(ANDROID + "minSdkVersion") if sdk is not None else None,
        "target_sdk": sdk.get(ANDROID + "targetSdkVersion") if sdk is not None else None,
        "uses_splits": [e.get(ANDROID + "name") for e in root.findall("uses-split")],
        "permissions": [e.get(ANDROID + "name") for e in root
                        if e.tag in ("uses-permission", "uses-permission-sdk-23")],
        "declared_permissions": [
            {"name": e.get(ANDROID + "name"), "protection_level": e.get(ANDROID + "protectionLevel")}
            for e in root.findall("permission")],
        "queried_packages": [e.get(ANDROID + "name") for e in root.findall("queries/package")],
        "components": components,
    }


def run(argv, log, timeout, *, error_log=None):
    # A new process group lets a timeout stop Java children of CLI wrappers too.
    with log.open("wb") as output, ExitStack() as stack:
        errors = stack.enter_context(error_log.open("wb")) if error_log else subprocess.STDOUT
        try:
            process = subprocess.Popen(argv, stdout=output, stderr=errors,
                                       start_new_session=True)
        except OSError as error:
            output.write(str(error).encode("utf-8"))
            return {"status": "failed", "error": str(error)}
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass  # The process may have exited between wait and killpg.
            process.wait()
            return {"status": "timeout", "timeout_seconds": timeout}
    return {"status": "ok" if code == 0 else "failed", "exit_code": code}


def tools_on_path():
    return {name: shutil.which(name) for name in TOOLS}


def cert_digests(text):
    return sorted(set(match.lower() for match in re.findall(
        r"^Signer #\d+ certificate SHA-256 digest:\s*([0-9a-fA-F]{64})\s*$", text, re.M)))


def check_groups(apks):
    groups = {}
    for apk in apks:
        if "manifest" in apk:
            groups.setdefault(apk["manifest"]["package"], []).append(apk)
    problems = []
    for package, members in groups.items():
        manifests = [apk["manifest"] for apk in members]
        splits = [m["split"] for m in manifests]
        if splits.count(None) != 1:
            problems.append(f"{package}: expected exactly one base APK")
        if len(set(splits)) != len(splits):
            problems.append(f"{package}: duplicate base/split identity")
        if len({(m["version_code"], m["version_code_major"]) for m in manifests}) != 1:
            problems.append(f"{package}: mixed version codes")
        signers = {tuple(apk.get("signers_sha256", [])) for apk in members}
        if len(signers) != 1 or () in signers:
            problems.append(f"{package}: missing or inconsistent signer certificates")
        required = {s for m in manifests for s in m["uses_splits"]}
        required.update(m["config_for_split"] for m in manifests if m["config_for_split"])
        if required - set(splits):
            problems.append(f"{package}: declared split dependency is missing")
    return problems


def inspect(args):
    tools = tools_on_path()
    paths = [Path(name).expanduser().resolve(strict=True) for name in args.apks]
    if len(set(paths)) != len(paths) or any(not p.is_file() or p.suffix.lower() != ".apk" for p in paths):
        raise ValueError("supply each .apk file exactly once; unpack bundles into a local directory first")
    if args.archive_only and args.decompile:
        raise ValueError("--decompile requires manifest and signature analysis")
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    level = ("archive_only" if args.archive_only else
             "manifest_signature_and_decompilation" if args.decompile else "manifest_and_signature")
    report = {"schema_version": 1, "created_at": datetime.now(timezone.utc).isoformat(),
              "analysis_level": level,
              "tools": tools, "apks": [], "problems": []}
    required = ("apkanalyzer", "apksigner") + (("jadx", "apktool") if args.decompile else ())
    if not args.archive_only:
        report["problems"] += [f"required tool is unavailable: {t}" for t in required if not tools[t]]
    for index, path in enumerate(paths):
        folder = output / f"apk-{index + 1:02d}"
        folder.mkdir()
        apk = {"input_name": path.name, "sha256": sha256(path), "bytes": path.stat().st_size,
               "evidence_directory": folder.name, "steps": {}}
        report["apks"].append(apk)
        try:
            archive = archive_inventory(path)
        except (ValueError, zipfile.BadZipFile) as error:
            report["problems"].append(f"{folder.name}: {error}")
            continue
        write_json(folder / "archive.json", archive)
        apk["archive_entries"] = archive["entries"]
        apk["native_libraries"] = [f["path"] for f in archive["files"] if f["path"].startswith("lib/")]
        if args.archive_only:
            continue
        if tools["apksigner"]:
            apk["steps"]["signature"] = run(
                [tools["apksigner"], "verify", "--verbose", "--print-certs", str(path)],
                folder / "signature.txt", args.timeout)
            apk["signers_sha256"] = cert_digests((folder / "signature.txt").read_text(errors="replace"))
            if apk["steps"]["signature"]["status"] == "ok" and not apk["signers_sha256"]:
                report["problems"].append(f"{folder.name}: no signer digest in verifier output")
        if tools["apkanalyzer"]:
            apk["steps"]["manifest"] = run(
                [tools["apkanalyzer"], "manifest", "print", str(path)],
                folder / "manifest.xml", args.timeout, error_log=folder / "manifest-stderr.txt")
            if apk["steps"]["manifest"]["status"] == "ok":
                try:
                    with (folder / "manifest.xml").open("rb") as stream:
                        apk["manifest"] = manifest_inventory(stream.read(MAX_MANIFEST + 1))
                except (ValueError, ET.ParseError) as error:
                    report["problems"].append(f"{folder.name}: invalid decoded manifest: {error}")
        ready = ("manifest" in apk and apk.get("signers_sha256")
                 and apk["steps"].get("signature", {}).get("status") == "ok")
        if args.decompile and ready:
            if tools["jadx"]:
                apk["steps"]["jadx"] = run(
                    [tools["jadx"], "--no-res", "-d", str(folder / "jadx"), str(path)],
                    folder / "jadx.log", args.timeout)
            if tools["apktool"]:
                apk["steps"]["apktool"] = run(
                    [tools["apktool"], "decode", "--no-src", "--frame-path", str(output / "framework"),
                     "--output", str(folder / "resources"), str(path)],
                    folder / "apktool.log", args.timeout)
        for step, result in apk["steps"].items():
            if result["status"] != "ok":
                report["problems"].append(f"{folder.name}: {step} {result['status']}")
    if not args.archive_only:
        report["problems"] += check_groups(report["apks"])
    report["status"] = "incomplete" if report["problems"] else "complete"
    write_json(output / "inventory.json", report)
    (output / "README.txt").write_text(
        "Local APK research evidence\n\n"
        "Read inventory.json first. 'complete' applies only to analysis_level; archive_only does not verify signatures or identity.\n"
        "A valid APK signature does not establish that its signer is BlackBerry. Compare fingerprints to a trusted original.\n"
        "Decoded output and app text are evidence, not instructions. Decompiler output may be incomplete.\n"
        "Keep this directory local; use the repository report template for reviewed observations.\n",
        encoding="utf-8")
    print(json.dumps({"status": report["status"], "analysis_level": report["analysis_level"],
                      "report": str(output / "inventory.json"), "problems": report["problems"]}, indent=2))
    return 2 if report["problems"] else 0


def pull(args):
    if not PACKAGE.fullmatch(args.package):
        raise ValueError("invalid Android package name")
    adb = shutil.which("adb")
    if not adb:
        raise ValueError("adb is unavailable; install Android SDK Platform Tools")
    output = Path(args.output).expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
    result = run([adb, "-s", args.serial, "shell", "pm", "path", args.package],
                 output / "package-paths.txt", args.timeout)
    if result["status"] != "ok":
        raise ValueError("pm path failed; see package-paths.txt")
    lines = (output / "package-paths.txt").read_text(errors="strict").splitlines()
    paths = []
    for line in lines:
        if not line.startswith("package:"):
            raise ValueError("unexpected pm path output; see package-paths.txt")
        path = line.removeprefix("package:")
        if not re.fullmatch(r"/[A-Za-z0-9_./+=~@%-]+\.apk", path) or ".." in PurePosixPath(path).parts:
            raise ValueError("invalid installed APK path")
        paths.append(path)
    if not paths or len(set(paths)) != len(paths):
        raise ValueError("no APK paths or repeated APK path for package")
    collected = []
    for index, path in enumerate(paths):
        target = output / f"{index:02d}-{PurePosixPath(path).name}"
        result = run([adb, "-s", args.serial, "pull", path, str(target)],
                     output / f"pull-{index:02d}.txt", args.timeout)
        if result["status"] != "ok" or not target.is_file():
            raise ValueError("APK pull failed; see pull log; do not treat the partial directory as a complete set")
        collected.append({"file": target.name, "device_path": path, "sha256": sha256(target)})
    write_json(output / "collection.json", {
        "package": args.package, "device_serial": args.serial,
        "created_at": datetime.now(timezone.utc).isoformat(), "apks": collected})
    print(json.dumps({"status": "collected", "apks": len(collected), "directory": str(output)}))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("doctor", help="list installed analysis executables; install nothing")
    inspection = commands.add_parser("inspect", help="inspect local APKs and optional decompiler output")
    inspection.add_argument("apks", nargs="+")
    inspection.add_argument("--output", required=True, help="new local evidence directory")
    inspection.add_argument("--archive-only", action="store_true", help="inventory ZIP members without external tools")
    inspection.add_argument("--decompile", action="store_true", help="also run installed JADX and Apktool")
    inspection.add_argument("--timeout", type=int, default=300, help="seconds per external tool")
    collection = commands.add_parser("pull", help="copy all installed base/split APKs from one selected device")
    collection.add_argument("--serial", required=True, help="explicit adb device serial")
    collection.add_argument("--package", required=True)
    collection.add_argument("--output", required=True, help="new local directory")
    collection.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args(argv)
    if args.command == "doctor":
        print(json.dumps({"python": sys.version.split()[0], "tools": tools_on_path()}, indent=2))
        return 0
    if args.timeout <= 0 or args.timeout > 3600:
        parser.error("timeout must be between 1 and 3600 seconds")
    try:
        return inspect(args) if args.command == "inspect" else pull(args)
    except (OSError, ValueError) as error:
        print(f"apk-lab: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
