#!/usr/bin/env python3
"""Capture production Qt/Keel app pages with synthetic service fixtures.

This is a visual-review aid, not a screenshot comparison test. It requires the
real Qt Quick Test runner and Keel modules used by the native UI test gate.
Fontconfig must be available; captures use only the repository's production
Source Sans 3 fonts and Sail Sans aliases, checked before every app launch.
The generated harnesses and configuration are temporary; PNGs, runtime logs,
JUnit reports and a provenance manifest are written to --output.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = Path(__file__).with_name("capture_templates")
SCENES = {
    "email": [
        ("mail-inbox-320x640", 320, 640, "Inbox with long sender, preview and account context"),
        ("mail-source-720x720", 720, 720, "Keyboard-opened source message, with a duplicate-name decoy"),
    ],
    "phone": [
        ("phone-incoming-320x640", 320, 640, "Incoming call: long identity above fixed native actions"),
        ("phone-contacts-720x720", 720, 720, "Native contacts tab: same names, distinct numbers"),
    ],
    "notes": [
        ("notes-task-large-320x640", 320, 640, "Long task with the native huge text setting"),
        ("notes-workspace-1024x768", 1024, 768, "Task collection and its original note in the wide workspace"),
    ],
    "pilot": [
        ("pilot-main-320x640", 320, 640, "Production MainPage with a source explanation and retained prompt"),
        ("pilot-main-1024x768", 1024, 768, "The same conversation and prompt after widening the native page"),
    ],
}

HELPERS = """
    Text {
        id: captureFontProbe
        visible: false
        text: "Native capture font"
        textFormat: Text.PlainText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
    }

    function resizeApp(app, w, h) {
        testCase.width = w;
        testCase.height = h;
        testCase.Window.window.width = w;
        testCase.Window.window.height = h;
        app.width = w;
        app.height = h;
        tryCompare(app.contentItem, "width", w);
        tryCompare(app.contentItem, "height", h);
        verify(waitForPolish(testCase.Window.window));
        testCase.Window.window.update();
        verify(waitForRendering(app));
        compare(Theme.fontFamily, "Sail Sans Pro Light");
        compare(captureFontProbe.fontInfo.family, "Source Sans 3");
    }

    function capture(app, name, w, h) {
        resizeApp(app, w, h);
        tryVerify(() => app.pageStack.currentPage !== null && !app.pageStack.busy);
        tryCompare(app.pageStack.currentPage, "status", PageStatus.Active);
        tryVerify(() => app.visible && app.contentItem.visible && app.pageStack.currentPage.visible);
        const sheet = findChild(app, "sheet");
        if (sheet && sheet.moving !== undefined)
            tryVerify(() => !sheet.moving);
        // Native page/text transitions can still be drawing after the stack
        // reports idle. Let their short fades finish before recording pixels.
        wait(500);
        verify(waitForPolish(testCase.Window.window));
        // A settled static page need not schedule another frame on its own.
        // Request a real render without changing any UI property.
        testCase.Window.window.update();
        verify(waitForRendering(app));
        // ApplicationWindow's real background is a sibling of contentItem.
        // Grab the production root so the image includes both, without a mock
        // backdrop or a second rendering of its controls.
        const shot = grabImage(app);
        compare(shot.width, w);
        compare(shot.height, h);
        shot.save(@OUTPUT@ + "/" + name + ".png");
        console.info("NATIVE_CAPTURE " + JSON.stringify({
            name: name, width: w, height: h,
            fontFamily: Theme.fontFamily,
            resolvedFont: captureFontProbe.fontInfo,
            fontSizeMedium: Theme.fontSizeMedium,
            pixelRatio: Theme.pixelRatio
        }));
    }
"""


def git_output(*args):
    result = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True,
                            text=True, check=False)
    return result.stdout.strip() if result.returncode == 0 else None


def executable(value):
    resolved = shutil.which(value) if value else None
    if not resolved:
        raise ValueError("set --runner or QMLTESTRUNNER to an executable Qt 6 qmltestrunner")
    return str(Path(resolved).resolve())


def png_dimensions(path):
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"not a PNG image: {path}")
    return struct.unpack(">II", header[16:24])


def production_font_environment(state, env):
    """Use the packaged fonts, without the host's fallback font collection."""
    font_directory = ROOT / "marathon-fonts/source-sans-3"
    alias_file = ROOT / "marathon-fonts/60-marathon-sail-sans.conf"
    expected = font_directory / "SourceSans3-Light.ttf"
    for path in (expected, alias_file):
        if not path.is_file():
            raise ValueError(f"required production font input is absent: {path}")
    matcher = shutil.which("fc-match")
    if matcher is None:
        raise ValueError("Fontconfig fc-match is required to verify the production capture font")
    config = ET.Element("fontconfig")
    ET.SubElement(config, "dir").text = str(font_directory)
    ET.SubElement(config, "cachedir").text = str(state / "font-cache")
    ET.SubElement(config, "include").text = str(alias_file)
    config_file = state / "fonts.conf"
    ET.ElementTree(config).write(config_file, encoding="utf-8", xml_declaration=True)
    env.update(FONTCONFIG_FILE=str(config_file), FONTCONFIG_PATH=str(state))
    # A caller's Qt font-directory override must not reintroduce host fonts.
    env.pop("QT_QPA_FONTDIR", None)
    query = "Sail Sans Pro Light"
    match = subprocess.run([matcher, "--format=%{file}\n%{family}\n%{style}\n", query],
                           env=env, capture_output=True, text=True, timeout=10, check=False)
    lines = match.stdout.splitlines()
    if match.returncode or len(lines) != 3:
        raise ValueError(f"fc-match could not resolve {query}: {match.stderr.strip()}")
    resolved = Path(lines[0]).resolve()
    if resolved != expected.resolve():
        raise ValueError(f"{query} resolved to {resolved}; expected {expected}")
    return {
        "isolation": "Only repository source-sans-3 fonts and the production Sail Sans alias configuration",
        "font_directory": str(font_directory),
        "fontconfig_alias_file": str(alias_file),
        "fontconfig_alias_sha256": hashlib.sha256(alias_file.read_bytes()).hexdigest(),
        "fc_match": str(Path(matcher).resolve()),
        "requested_family": query,
        "matched_file": str(resolved),
        "repository_file": resolved.relative_to(ROOT).as_posix(),
        "matched_file_sha256": hashlib.sha256(resolved.read_bytes()).hexdigest(),
        "matched_family": lines[1],
        "matched_style": lines[2],
        "match_scope": "Fontconfig alias preflight; each image also records a Qt text probe's resolved family and style",
    }


def source_inputs(apps):
    """Fingerprint the actual inputs, independently of a publication commit ID."""
    directories = [*(f"apps/{app}" for app in apps), "marathon-silica/Marathon/Silica",
                   "tools/native-ui-consistency/capture_templates", "marathon-fonts"]
    trees = []
    for directory in directories:
        files = sorted(p for p in (ROOT / directory).rglob("*") if p.is_file()
                       and (p.suffix in {".qml", ".js", ".json"} or p.name == "qmldir"
                            or p.name.endswith(".qml.in")
                            or (directory == "marathon-fonts" and p.suffix in {".ttf", ".conf"})))
        entries = [(p.relative_to(ROOT).as_posix(), hashlib.sha256(p.read_bytes()).hexdigest())
                   for p in files]
        content = "".join(f"{name}\0{digest}\n" for name, digest in entries).encode()
        trees.append({"path": directory, "file_count": len(entries),
                      "source_sha256": hashlib.sha256(content).hexdigest(),
                      "git_tree": git_output("rev-parse", f"HEAD:{directory}")})
    files = [Path(__file__), ROOT / "packaging/packages/keel-silica/APKBUILD"]
    selected = {
        "email": ["EmailApp.qml", "pages/InboxPage.qml", "pages/MailMessagePage.qml"],
        "phone": ["PhoneApp.qml", "pages/IncomingCallPage.qml", "pages/PeopleTab.qml"],
        "notes": ["NotesApp.qml", "pages/NotesWorkspace.qml", "pages/TasksPage.qml", "pages/NoteEditorPage.qml"],
        "pilot": ["ui/pages/MainPage.qml", "ui/components/Conversation.qml", "ui/components/PromptField.qml"],
    }
    for app in apps:
        files.extend(ROOT / "apps" / app / name for name in selected[app])
    return {"tree_digest_format": "SHA-256 of sorted UTF-8 'repository-relative-path NUL file-sha256 LF' records; QML, JS, JSON, qmldir and .qml.in files, plus TTF and conf files in marathon-fonts",
            "trees": trees,
            "files": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in files}}


def review_report(path):
    root = ET.parse(path).getroot()
    versions = sorted({p.get("value", "") for p in root.iter("property")
                       if p.get("name") == "QtVersion"})
    cases = [c for c in root.iter("testcase") if "::test_" in c.get("name", "")]
    failed = any(list(root.iter(tag)) for tag in ("failure", "error", "skipped"))
    if not cases or not versions or any(not v.startswith("6.") for v in versions) or failed:
        raise ValueError("the native capture harness did not complete on Qt 6 without failures or skips")
    return versions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path,
                        help="directory for eight PNGs plus provenance and native runtime evidence")
    parser.add_argument("--runner", default=os.environ.get("QMLTESTRUNNER", "qmltestrunner"))
    parser.add_argument("--keel-qml", default=os.environ.get("KEEL_QML"), type=Path)
    parser.add_argument("--icons", default=os.environ.get("KEEL_THEME_ICON_DIRS"),
                        help="real theme icon directories, separated by the platform path separator")
    parser.add_argument("--app", action="append", choices=SCENES,
                        help="capture only this app; repeat to select several")
    args = parser.parse_args()
    try:
        runner = executable(args.runner)
        if args.keel_qml is None:
            raise ValueError("set --keel-qml or KEEL_QML to the real Keel build's qml directory")
        keel = args.keel_qml.resolve()
        if not (keel / "Sailfish/Silica/qmldir").is_file():
            raise ValueError(f"Sailfish.Silica is absent from {keel}")
        if not args.icons or any(not Path(p).is_dir() for p in args.icons.split(os.pathsep)):
            raise ValueError("set --icons or KEEL_THEME_ICON_DIRS to the built native theme icon directories")
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=True)
        apps = list(dict.fromkeys(args.app or SCENES))
        manifest = {
            "kind": "native-design-review",
            "source_commit": git_output("rev-parse", "HEAD"),
            "source_tree": git_output("rev-parse", "HEAD^{tree}"),
            "source_dirty": bool(git_output("status", "--porcelain")),
            "source_inputs": source_inputs(apps),
            "repository": str(ROOT),
            "runner": runner,
            "keel_qml": str(keel),
            "icon_dirs": args.icons.split(os.pathsep),
            "renderer": "Qt Quick offscreen software, Qt device scale 1, Keel theme pixel ratio 1",
            "data": "Synthetic fixture data only; no real account, message, contact or provider is read",
            "limits": [
                "Visual review captures, not pixel comparison tests or proof of all app states",
                "Native controls and production QML; app services use the existing test fixtures",
                "Pilot uses the production MainPage in a shared native ApplicationWindow, as its native tests do",
                "No shell decorations, system keyboard, modem/provider integration or device GPU evidence",
                "Repository fonts are isolated and checked; Qt/Keel versions and graphics backends can still change rasterization",
            ],
            "runs": [],
        }
        errors = []
        for app in apps:
            report = output / f"{app}.xml"
            log = output / f"{app}.log"
            expected = SCENES[app]
            for name, _, _, _ in expected:
                (output / f"{name}.png").unlink(missing_ok=True)
            report.unlink(missing_ok=True)
            run = {"app": app, "status": "failed", "report": report.name,
                   "log": log.name, "fixtures": f"apps/{app}/tests/stubs", "images": []}
            manifest["runs"].append(run)
            try:
                with tempfile.TemporaryDirectory(prefix=f"marathon-capture-{app}-") as temporary:
                    state = Path(temporary)
                    harness = state / "tst_capture.qml"
                    text = (TEMPLATES / f"{app}.qml.in").read_text(encoding="utf-8")
                    text = text.replace("@HELPERS@", HELPERS)
                    text = text.replace("@REPO@", ROOT.as_uri())
                    text = text.replace("@OUTPUT@", json.dumps(str(output)))
                    harness.write_text(text, encoding="utf-8")
                    command = [runner, "-import", str(keel), "-import", str(ROOT / "marathon-silica"),
                               "-import", str(ROOT / f"apps/{app}/tests/stubs"),
                               "-input", str(harness), "-o", "-,txt", "-o", f"{report},junitxml"]
                    env = dict(os.environ, KEEL_DCONF_FILE=str(state / "configuration.json"),
                               QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                               QT_FORCE_STDERR_LOGGING="1", QT_SCALE_FACTOR="1",
                               KEEL_THEME_PIXEL_RATIO="1",
                               QML_XHR_ALLOW_FILE_READ="1", KEEL_THEME_ICON_DIRS=args.icons,
                               LC_ALL="C.UTF-8", TZ="UTC")
                    run["fonts"] = production_font_environment(state, env)
                    with log.open("w", encoding="utf-8") as stream:
                        result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream,
                                                stderr=subprocess.STDOUT, timeout=60, check=False)
                    if result.returncode:
                        raise ValueError(f"qmltestrunner exited {result.returncode}; see {log}")
                    run["qt_versions"] = review_report(report)
                for name, width, height, description in expected:
                    path = output / f"{name}.png"
                    if png_dimensions(path) != (width, height):
                        raise ValueError(f"wrong capture dimensions: {path}")
                    run["images"].append({"file": path.name, "width": width, "height": height,
                                          "description": description,
                                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
                run["theme_evidence"] = [line.split("NATIVE_CAPTURE ", 1)[1]
                                         for line in log.read_text(encoding="utf-8").splitlines()
                                         if "NATIVE_CAPTURE " in line]
                run["status"] = "captured"
                print(f"[native-capture] {app}: {len(run['images'])} PNGs, Qt {', '.join(run['qt_versions'])}")
            except (OSError, ValueError, ET.ParseError, subprocess.TimeoutExpired) as error:
                errors.append(f"{app}: {error}")
                run["error"] = str(error)
                print(f"[native-capture] FAIL {app}: {error}", file=sys.stderr)
                if log.exists():
                    print("\n".join(log.read_text(encoding="utf-8").splitlines()[-35:]), file=sys.stderr)
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"[native-capture] evidence: {output / 'manifest.json'}")
        return 1 if errors else 0
    except (OSError, ValueError) as error:
        print(f"[native-capture] FAIL: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
