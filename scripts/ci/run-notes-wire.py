#!/usr/bin/env python3
"""Require the production Hub transport to create/open in the real Notes app."""

import argparse
import json
import os
from pathlib import Path
import queue
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET

READY = "MARATHON_NOTES_WIRE_READY"
VERIFIED = "MARATHON_NOTES_WIRE_VERIFIED "


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", required=True, type=Path)
    parser.add_argument("--runner", required=True, type=Path)
    parser.add_argument("--keel", required=True, type=Path)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    # Keep the actual qmltestrunner input visible to test reachability tooling.
    parser.add_argument("-input", required=True, type=Path)
    parser.add_argument("--private-bus", action="store_true", help=argparse.SUPPRESS)
    return parser.parse_args()


def isolated_environment(state):
    # Only fixture data and runtime discovery variables enter the test. No
    # personal bus, credentials, provider configuration, or terminal session.
    env = {name: os.environ[name] for name in ("PATH", "LD_LIBRARY_PATH", "QT_PLUGIN_PATH")
           if name in os.environ}
    for name, subdir in (("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data"),
                         ("XDG_CACHE_HOME", "cache"), ("XDG_RUNTIME_DIR", "runtime")):
        directory = state / subdir
        directory.mkdir(mode=0o700)
        env[name] = str(directory)
    env.update(QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
               QT_FORCE_STDERR_LOGGING="1", QML_XHR_ALLOW_FILE_READ="1",
               KEEL_DCONF_FILE=str(state / "configuration.json"), LANG="C.UTF-8",
               DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent-marathon-wire-system-bus")
    return env


def check_report(report):
    root = ET.parse(report).getroot()
    if root.tag not in {"testsuite", "testsuites"}:
        raise ValueError("unrecognized real Qt provider report")
    versions = [p.get("value", "") for p in root.iter("property") if p.get("name") == "QtVersion"]
    if not versions or any(not version.startswith("6.") for version in versions):
        raise ValueError("provider report does not identify a real Qt 6 runtime")
    if any(list(root.iter(tag)) for tag in ("failure", "error", "skipped")):
        raise ValueError("the real Notes provider failed or skipped an assertion")
    cases = [case for case in root.iter("testcase")
             if case.get("name", "").endswith("::test_realHubCaptureAndExactOpen")]
    if len(cases) != 1:
        raise ValueError("the required real Notes capture/open test did not run exactly once")


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def on_private_bus(args):
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise ValueError("private D-Bus session missing; coverage cannot be skipped")
    report = args.report.resolve()
    report.parent.mkdir(parents=True, exist_ok=True)
    report.unlink(missing_ok=True)
    report.with_suffix(".json").unlink(missing_ok=True)
    provider_env = dict(os.environ,
                        KEEL_ACTIONS_APP_ID="org.marathonos.notes",
                        KEEL_ACTIONS_MANIFEST=str(args.root / "apps/notes/keel-actions.json"))
    command = [str(args.runner), "-import", str(args.keel),
               "-import", str(args.root / "marathon-silica"),
               "-import", str(args.root / "apps/notes/tests/stubs"),
               "-input", str(args.input), "-o", "-,txt", "-o", f"{report},junitxml"]
    lines = []
    output = queue.Queue()
    provider = subprocess.Popen(command, env=provider_env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, bufsize=1)

    def collect():
        for line in provider.stdout:
            lines.append(line)
            print(line, end="", flush=True)
            output.put(line)
        output.put(None)

    reader = threading.Thread(target=collect, daemon=True)
    reader.start()
    try:
        deadline = time.monotonic() + 20
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise ValueError("real Notes never became ready")
            try:
                line = output.get(timeout=remaining)
            except queue.Empty as error:
                raise ValueError("real Notes never became ready") from error
            if line is None:
                raise ValueError("real Notes exited before registering its provider")
            if READY in line:
                break
        client = subprocess.run([str(args.client)], check=False, capture_output=True,
                                text=True, timeout=110)
        print(client.stdout, end="", flush=True)
        print(client.stderr, end="", file=sys.stderr, flush=True)
        if client.returncode:
            raise ValueError(f"production Rust transport failed, exit {client.returncode}")
        wire = json.loads(client.stdout)
        if wire != {"capture_id": 1, "second_id": 2, "opened_id": 1,
                    "source_kind": "notification", "source_app_id": "org.marathonos.hub",
                    "background_start_calls": 4}:
            raise ValueError(f"unexpected wire results: {wire}")
        if provider.wait(timeout=20):
            raise ValueError("real Notes provider assertions failed")
        reader.join(timeout=5)
        check_report(report)
        verified = [line.split(VERIFIED, 1)[1].strip() for line in lines if VERIFIED in line]
        if len(verified) != 1:
            raise ValueError("real Notes did not publish its checked editor/store evidence")
        observed = json.loads(verified[0])
        expected = {"created_count": 2, "selected_id": 1,
                    "selected_body": "Review <b>contract</b>\nCaptured notification body 📝\nKeep this text editable.",
                    "source_kind": "notification", "source_app_id": "org.marathonos.hub",
                    "source_label": "<b>Mail</b> notification"}
        if observed != expected:
            raise ValueError(f"real Notes editor/store evidence did not match: {observed}")
        evidence = {"wire": wire, "notes": observed,
                    "scope": "real Hub Rust transport and Notes QML/Keel; shell wake admission fixture"}
        report.with_suffix(".json").write_text(json.dumps(evidence, indent=2) + "\n")
        print("[notes-wire] PASS: 2 real creates, notification metadata, exact older-note open, "
              "real editor/body, and 4 background-start admissions; no skips", flush=True)
    finally:
        stop(provider)
        reader.join(timeout=5)


def main():
    args = arguments()
    # Invalidate earlier evidence even when a dependency or the private bus
    # fails before the provider process can start.
    args.report = args.report.resolve()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.unlink(missing_ok=True)
    args.report.with_suffix(".json").unlink(missing_ok=True)
    for name in ("client", "runner", "input"):
        value = getattr(args, name).resolve()
        if not value.is_file():
            raise ValueError(f"required {name} is missing: {value}")
        setattr(args, name, value)
    args.root = args.root.resolve()
    args.keel = args.keel.resolve()
    if args.private_bus:
        on_private_bus(args)
        return 0
    dbus = shutil.which("dbus-run-session")
    if not dbus:
        raise ValueError("dbus-run-session is required; missing bus cannot pass this gate")
    with tempfile.TemporaryDirectory(prefix="marathon-notes-wire-") as temporary:
        env = isolated_environment(Path(temporary))
        command = [dbus, "--", sys.executable, str(Path(__file__).resolve()),
                   "--private-bus", *sys.argv[1:]]
        session = subprocess.Popen(command, env=env, start_new_session=True)
        try:
            return session.wait(timeout=160)
        finally:
            if session.poll() is None:
                # Every descendant is this test's own private bus/provider.
                os.killpg(session.pid, signal.SIGTERM)
                try:
                    session.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(session.pid, signal.SIGKILL)
                    session.wait(timeout=5)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, ET.ParseError, subprocess.TimeoutExpired) as error:
        print(f"[notes-wire] FAIL: {error}", file=sys.stderr)
        sys.exit(1)
