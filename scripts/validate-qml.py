#!/usr/bin/env python3
"""Strict Qt 6 QML validation. Missing tooling or coverage is a failure.

Qt's JSON diagnostics distinguish messages from source excerpts. In particular,
a property called mmscError is not an error. Do not infer severity from text or
discard qmllint's status: syntax errors can be emitted as warning diagnostics.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
PRUNE = {"tests", "third-party", "thirdparty", "vendor", "node_modules", ".git"}


def find_qmllint(requested=None):
    """An explicit tool is authoritative; never silently replace a broken one."""
    if requested:
        candidates = [requested]
    else:
        candidates = []
        for name in ("qtpaths6", "qtpaths-qt6"):
            qtpaths = shutil.which(name)
            if qtpaths:
                result = subprocess.run([qtpaths, "--query", "QT_INSTALL_BINS"],
                                        capture_output=True, text=True, check=False)
                if result.returncode == 0 and result.stdout.strip():
                    candidates.append(str(Path(result.stdout.strip()) / "qmllint"))
        candidates += ["/usr/lib/qt6/bin/qmllint", "/usr/lib64/qt6/bin/qmllint",
                       "qmllint6", "qmllint-qt6", "qmllint"]
    problems = []
    for candidate in candidates:
        tool = shutil.which(candidate)
        if not tool:
            continue
        result = subprocess.run([tool, "--version"], capture_output=True,
                                text=True, check=False)
        version = (result.stdout + result.stderr).strip()
        if result.returncode == 0 and re.search(r"\bqmllint 6\.\d+", version):
            return tool
        problems.append(f"{tool}: {version or 'version check failed'}")
    detail = "; ".join(problems) or (str(requested) if requested else "not installed")
    raise ValueError(f"Qt 6 qmllint is required ({detail}); set QMLLINT or --qmllint")


def qml_files(paths):
    files = set()
    for name in paths:
        path = Path(name).resolve()
        if path.is_file() and path.suffix == ".qml":
            files.add(path)
        elif path.is_dir():
            for directory, dirs, names in os.walk(path):
                dirs[:] = sorted(d for d in dirs if d not in PRUNE
                                 and not d.startswith("build") and not d.startswith("."))
                if (Path(directory) / "CMakeCache.txt").exists():
                    dirs[:] = []
                    continue
                files.update((Path(directory) / n).resolve() for n in names if n.endswith(".qml"))
        else:
            raise ValueError(f"QML source path does not exist or is not QML: {path}")
    if not files:
        raise ValueError("no QML files selected; zero validation coverage is not a pass")
    return sorted(files)


def import_paths(args):
    build = Path(args.build_dir).resolve()
    apps = Path(args.apps_build_dir).resolve()
    candidates = [build / "qmllint-types", build / "shell/qml", build,
                  ROOT / "shell/qml", ROOT / "marathon-silica"]
    candidates += sorted((apps / "apps").glob("*/"))
    explicit = [Path(p).resolve() for p in args.import_path]
    if os.environ.get("KEEL_QML"):
        explicit.append(Path(os.environ["KEEL_QML"]).resolve())
    for path in explicit:
        if not path.is_dir():
            raise ValueError(f"QML import directory does not exist: {path}")
    return list(dict.fromkeys([p for p in candidates if p.is_dir()] + explicit))


def validate(tool, files, imports):
    # Respect per-category .qmllint.ini policy, but enforce every enabled warning.
    command = [tool, "--json", "-", "--max-warnings", "0"]
    for directory in imports:
        command += ["-I", str(directory)]
    result = subprocess.run(command + [str(p) for p in files],
                            capture_output=True, text=True, check=False)
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    try:
        report = json.loads(result.stdout)
        entries = report["files"]
        if not isinstance(entries, list):
            raise ValueError("files is not a list")
        reported = [Path(entry["filename"]).resolve() for entry in entries]
        if sorted(reported) != files:
            raise ValueError("qmllint did not report each requested file exactly once")
        failed_files = 0
        counts = {"warning": 0, "error": 0, "info": 0}
        for entry in entries:
            if not isinstance(entry.get("success"), bool):
                raise ValueError("missing file success status")
            failed_files += not entry["success"]
            if not isinstance(entry.get("warnings"), list):
                raise ValueError("missing file diagnostics")
            for diagnostic in entry["warnings"]:
                severity = diagnostic["type"]
                if severity not in counts:
                    raise ValueError(f"unknown diagnostic severity: {severity}")
                counts[severity] += 1
                print(f"{entry['filename']}:{diagnostic.get('line', 0)}:"
                      f"{diagnostic.get('column', 0)}: {severity}: "
                      f"{diagnostic['message']} [{diagnostic.get('id', 'unknown')}]")
    except (json.JSONDecodeError, KeyError, TypeError, ValueError) as error:
        raise ValueError(f"invalid or incomplete qmllint JSON (exit {result.returncode}): {error}") from error
    failed = result.returncode != 0 or failed_files or counts["warning"] or counts["error"]
    print(f"[qml] {'FAIL' if failed else 'PASS'}: {len(files)} files, "
          f"{counts['error']} errors, {counts['warning']} warnings, "
          f"{counts['info']} informational diagnostics; qmllint exit {result.returncode}")
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", help="QML files or source directories; default: shell, apps, Marathon.Silica")
    parser.add_argument("--qmllint", default=os.environ.get("QMLLINT"))
    parser.add_argument("--print-tool", action="store_true", help="resolve and verify Qt 6 qmllint, then exit")
    parser.add_argument("-I", "--import-path", action="append", default=[])
    parser.add_argument("--build-dir", default=os.environ.get("BUILD_DIR", str(ROOT / "build")))
    parser.add_argument("--apps-build-dir", default=os.environ.get("APPS_BUILD_DIR", str(ROOT / "build-apps")))
    args = parser.parse_args()
    try:
        tool = find_qmllint(args.qmllint)
        if args.print_tool:
            print(tool)
            return 0
        files = qml_files(args.paths or [ROOT / "shell/qml", ROOT / "apps", ROOT / "marathon-silica"])
        imports = import_paths(args)
        print(f"[qml] Qt 6 tool: {tool}; selected {len(files)} QML files", flush=True)
        return validate(tool, files, imports)
    except (OSError, ValueError) as error:
        print(f"[qml] FAIL: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
