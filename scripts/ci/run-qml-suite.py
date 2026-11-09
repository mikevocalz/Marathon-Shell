#!/usr/bin/env python3
"""Run a real Qt Quick suite and reject missing, empty, or skipped coverage."""

import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a suite command is required")
    try:
        report = args.report.resolve()
        report.parent.mkdir(parents=True, exist_ok=True)
        report.unlink(missing_ok=True)
        with tempfile.TemporaryDirectory(prefix="marathon-native-ui-") as state:
            env = dict(os.environ, KEEL_DCONF_FILE=str(Path(state) / "configuration.json"),
                       QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       QT_FORCE_STDERR_LOGGING="1")
            result = subprocess.run(command + ["-o", "-,txt", "-o", f"{report},junitxml"],
                                    env=env, check=False)
        tree = ET.parse(report)
        root = tree.getroot()
        if root.tag not in {"testsuite", "testsuites"}:
            raise ValueError("unrecognized Qt JUnit report")
        versions = [p.get("value", "") for p in root.iter("property") if p.get("name") == "QtVersion"]
        if not versions or any(not version.startswith("6.") for version in versions):
            raise ValueError("the report does not identify a Qt 6 runtime")
        cases = list(root.iter("testcase"))
        real_tests = [case for case in cases if "::test_" in case.get("name", "")]
        if not real_tests:
            raise ValueError("zero test functions ran (init/cleanup do not count)")
        failures = sum(len(list(root.iter(tag))) for tag in ("failure", "error"))
        skipped = len(list(root.iter("skipped")))
        print(f"[native-ui] {len(real_tests)} test functions/data rows, "
              f"{len(cases)} total results, {failures} failures, {skipped} skipped; "
              f"Qt {', '.join(sorted(set(versions)))}; runner exit {result.returncode}", flush=True)
        return 1 if result.returncode or failures or skipped else 0
    except (OSError, ET.ParseError, ValueError) as error:
        print(f"[native-ui] FAIL: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
