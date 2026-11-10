# BlackBerry APK research for Marathon

Use this local workflow to examine BlackBerry's Android app contracts and interactions, then write original Qt/Keel implementation requirements for Marathon. Start with **Hub+ Inbox and Hub+ Services together**. BlackBerry describes Services as the suite's shared data/sync foundation; examining only the Inbox UI leaves that boundary unexplained.

This PR supplies a working evidence collector, an [Artcraft prompt](ARTCRAFT_PROMPT.md), an [APK checklist](APK_CHECKLIST.md), and a [findings template](REPORT_TEMPLATE.md). No BlackBerry APK has been supplied or analyzed by this PR. The collector's tests use synthetic APKs and fake SDK executables, not BlackBerry binaries.

## Local setup

The runner uses Python 3.10+ on macOS or Linux. Install analysis tools from their official distributions and put their executables on `PATH`:

| Tool | Used for | Official documentation |
| --- | --- | --- |
| Android SDK `apkanalyzer` | Decode the manifest and identify package/version/components | [APK Analyzer CLI](https://developer.android.com/tools/apkanalyzer) |
| Android SDK `apksigner` | Verify signatures and record certificate SHA-256 fingerprints | [APK signer](https://developer.android.com/tools/apksigner) |
| Android SDK `adb` | Optionally copy an installed app's base and split APKs from an explicitly selected device | [Android Debug Bridge](https://developer.android.com/tools/adb) |
| JADX | Optional local DEX decompilation | [JADX source and usage](https://github.com/skylot/jadx) |
| Apktool | Optional local resource decoding | [Apktool CLI](https://apktool.org/docs/cli-parameters/) |

SDK tools are in `cmdline-tools/<installed-version>/bin`, `build-tools/<installed-version>`, and `platform-tools` under your Android SDK directory. Select versions actually installed on your machine. Follow the selected JADX/Apktool release's Java requirement. The runner installs nothing and does not download APKs or SDKs.

```sh
python3 tools/blackberry-apk-lab/apk_lab.py doctor
```

`doctor` lists tool paths. A missing optional decompiler does not prevent basic signature/manifest analysis. It becomes a required tool when `--decompile` is requested.

## 1. Assemble the APK set

Place your original APKs under `.local-apk-research/apks/`, or use a local directory outside the repository. See the [checklist](APK_CHECKLIST.md) for the first six apps and optional references. Keep the complete base/split set for each installed version. Do not mix versions or rename a bundle container to `.apk`.

For apps installed on your own Android device, authorize USB debugging, inspect `adb devices -l`, then select its serial explicitly. These commands copy installed package files; they do not install an app, request root, or collect account databases:

```sh
python3 tools/blackberry-apk-lab/apk_lab.py pull \
  --serial YOUR_DEVICE_SERIAL --package com.blackberry.hub \
  --output .local-apk-research/apks/hub

python3 tools/blackberry-apk-lab/apk_lab.py pull \
  --serial YOUR_DEVICE_SERIAL --package com.blackberry.infrastructure \
  --output .local-apk-research/apks/services
```

Every path returned by `pm path` is copied, including splits. `collection.json` records the selected serial, collection time, paths and hashes, and is written only after all copies succeed. A failed/denied pull remains a failure; there is no root or permission-bypass fallback. Use a new output directory for a new collection.

## 2. Inspect identity, permissions, and components

```sh
python3 tools/blackberry-apk-lab/apk_lab.py inspect \
  --output .local-apk-research/reports/hub-services-001 \
  .local-apk-research/apks/hub/*.apk \
  .local-apk-research/apks/services/*.apk
```

The report records each input's SHA-256, size, archive inventory, native library paths, signature-verification result, signer fingerprints, package/version/split identity, SDK levels, requested/declarative permissions, component declarations, intent filters, provider authorities, and package queries. Tool output stays beside the normalized `inventory.json` as evidence. Manifest stderr is retained separately so tool warnings cannot corrupt the decoded XML.

The runner rejects duplicate inputs, existing output directories, unsafe or aliased ZIP paths, encrypted/symlink members, and excessive archive expansion. It checks that each package has one base, consistent version codes (including the major code)/signers, unique splits, and dependencies declared through `uses-split` or `configForSplit`. Those checks cannot establish that every device-specific configuration split is present; collection from `pm path` is the preferred way to retain the installed set.

**A successful signature verification establishes integrity under the reported certificate. It does not identify that signer as BlackBerry.** Compare the fingerprint to a trusted original, record the acquisition source/version in the findings, and keep that provenance claim separate from the cryptographic result.

Without SDK tools, you can still inventory files explicitly:

```sh
python3 tools/blackberry-apk-lab/apk_lab.py inspect --archive-only \
  --output .local-apk-research/reports/archive-only-001 \
  .local-apk-research/apks/hub/*.apk
```

`analysis_level: archive_only` never claims a decoded manifest, signature verification, or package authenticity.

## 3. Decode resources and DEX for local inspection

```sh
python3 tools/blackberry-apk-lab/apk_lab.py inspect --decompile --timeout 900 \
  --output .local-apk-research/reports/decompiled-001 \
  .local-apk-research/apks/hub/*.apk \
  .local-apk-research/apks/services/*.apk
```

This invokes the installed JADX with `--no-res` and Apktool with `decode --no-src`, retaining separate source/resource output and logs per APK. Apktool's framework cache stays inside the chosen evidence directory. It never builds, re-signs, installs, or executes the supplied app. No automatic network operation is part of the workflow; external tools remain subject to their own installed configuration.

The report identifies this requested level as `manifest_signature_and_decompilation`. Exit `0` means the requested analysis level completed. Exit `2` means invalid input or incomplete analysis. Check `inventory.json.problems` and individual logs. A timeout, decompiler error, missing tool, invalid manifest, or inconsistent split set is not silently counted as success. Decompiled code can be incomplete or misleading even when a tool exits successfully; retain confidence levels in the report.

## 4. Drive the research with Artcraft

Open this checkout in your **local Artcraft** session and paste [ARTCRAFT_PROMPT.md](ARTCRAFT_PROMPT.md). Give it the actual local APK/evidence paths. The prompt uses Artcraft's available terminal/file/image capabilities; this project assumes no undocumented Artcraft CLI, SDK, or cloud upload API.

Inspect the app's visible behavior with a disposable test account and synthetic contacts/messages if you can run the original on a compatible Android device. Record blocked behavior when a provider, subscription, or OS version prevents a flow. Static declarations are leads to investigate, not proof that the app performs a particular action at runtime.

The expected output is a reviewed dependency map and interaction specification using [REPORT_TEMPLATE.md](REPORT_TEMPLATE.md). Link every finding to a manifest location, local code/resource location, or a captured interaction. Classify it as observed, inferred, or unverified. Translate conclusions into Marathon service/API/UI work; the Android runtime and the premium Forge/RN products stay outside the shell dependency graph.

## Repository boundary

`.local-apk-research/` and APK/bundle file types are ignored. Keep raw/decompiled code, extracted assets, private screenshots, and account information there. Only deliberately reviewed observations and original Marathon implementation belong in a PR. Gitignore is a convenience, not a secret scanner; inspect the staged diff before publishing anything.

Work/Personal Spaces and enterprise deployment remain Marathon 2.1 scope. The consumer Hub research does not require UEM or Work APKs.

## Validation

```sh
python3 tools/blackberry-apk-lab/test_apk_lab.py
cmake -S tools/blackberry-apk-lab -B /tmp/marathon-apk-lab-tests
ctest --test-dir /tmp/marathon-apk-lab-tests --output-on-failure
python3 tests/lint/check-test-reachability.py
```

`BlackBerry_ApkResearch` is also registered in the repository's normal CTest suite. Tests cover archive/manifest boundaries, split consistency, literal subprocess arguments, incomplete-tool/decoder/signature outcomes, timeouts, and complete/partial device collections. Real BlackBerry analysis and local Artcraft/device interaction require your APKs and remain unverified until that run.
