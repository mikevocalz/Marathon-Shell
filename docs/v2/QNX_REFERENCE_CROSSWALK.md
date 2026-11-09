# QNX reference crosswalk for Marathon v2

Checked November 9, 2026. This document qualifies the supplied QNX reference and turns its useful architectural lessons into acceptance details for the existing [remediation queue](REMEDIATION_QUEUE.md). It changes no runtime code, adds no work packages and makes no real-time, hardware or BB10 binary-compatibility claim. All 37 approved packages retain their current status; Work/Personal Spaces remain **2.1 only**.

## 1. Exact reference and inspection boundary

The supplied `QNX Neutrino RTOS/QNX Neutrino RTOS - Programmer's Guide.pdf` matches the previously discussed [Himmele/My-Blog-Repository directory][archive] at revision `b1fd3e9410c1a6a0d7217c3be7e324e900470d2a`. The available conversation evidence did not identify a different repository. The directory contains four manuals and a `Programming/` example tree; a filename alone is not evidence that its APIs describe a current SDK.

| Verified source | Edition and identity | Inspection performed |
|---|---|---|
| [Programmer's Guide PDF][old-programmer] | **QNX Neutrino 6.3**, electronic edition 2005; publishing history starts July 2004; 510 PDF pages. Git blob `b6f7e50cb151ed4713f9bfa453829217dadccb8a`; 1,611,206 bytes. | Title/copyright, contents and selected process-termination and resource-manager lifecycle/unblock passages. |
| [System Architecture PDF][old-architecture] | **Release 6.3.0 or later**, electronic edition 2005; fifth-edition history June 2004; 404 PDF pages. Git blob `696c6a82f22d83cf2535e755bddf2d0793bc419a`; 2,513,322 bytes. | Title/copyright, contents and selected IPC and High Availability/recovery passages. |
| `C Library Reference.pdf`, `User's Guide.pdf` | Present in the same pinned directory. | Directory metadata only; their contents were not audited in this pass. |
| [`Programming/` examples][examples] | Historical QNX examples, including resource managers, Neutrino, SMP, process management and Photon. | Directory inventory and the existing RNQNX plans' explicit example review; no archived example was built or imported here. |

The original downloaded bytes were checked against the Git blob IDs above; PDF metadata, extracted text and a rendered cover agree on the old edition. The useful reading route is Programmer's Guide chapters 2–4 (processes, ownership and request handling), System Architecture chapter 2 (IPC/timing) and chapter 13 (service recovery), followed by current documentation. This is a targeted review, not a claim to have read every page.

The earlier companion title *Getting Started with QNX Neutrino: A Guide for Realtime Programmers* corresponds to the current official [Getting Started with the QNX OS][getting-started] guide. That title was not a separate PDF in the inspected directory. The current official [Programmer's Guide][current-programmer], [System Architecture][current-architecture] and [Writing a Resource Manager][current-resmgr] are the implementation references after the actual SDK version has been selected.

## 2. Keep the platform boundaries explicit

| Target | Appropriate application of the reference | Required boundary |
|---|---|---|
| MarathonOS v2 | Improve the existing Linux process, D-Bus, app-lifecycle and Qt/Keel contracts: authenticated callers, bounded work, resource ownership, explicit failure and recovery. | Preserve Linux/Wayland and the native Qt/QML shell. QNX `MsgSend`, channels, pulses, resource-manager callbacks, abilities and Screen APIs are not Linux implementations. |
| React Native QNX | Use current QNX APIs behind typed domain interfaces, owned asynchronous workers and the existing Qt/runtime lifetime contract. | Follow the separate repository's SDK/source pins and implementation plans. A merged plan is not a compiled transport, supervisor or qualified device feature. |
| Shared product design | Reuse interaction goals, error vocabulary, lifecycle tests and portable data schemas where they fit both systems. | Revalidate each platform adapter; do not infer BB10 application/service compatibility from QNX ancestry or a similar UI. Premium Forge packages remain outside mandatory OS/core fixtures. |

Current Marathon already has an asynchronous D-Bus seam in [`crates/marathon-shell-native/src/ipc.rs`][marathon-ipc]: service work uses the I/O runtime, authorization resolves the bus caller, and `on_gui` queues work to the Qt owner. Preserve and test that division before introducing another transport or service framework. The [coding rules][marathon-rules] already prohibit polling where events exist and reserve real-time scheduling for explicitly selected compositor/input work.

## 3. Architectural lessons mapped to existing repairs

The QNX column records source-backed concepts. The Marathon column is an **engineering inference and proposed acceptance requirement**, not an assertion that QNX supplies the Linux implementation or that the current fork has passed the test.

| Lesson and current reference | Marathon acceptance addition | Owner and existing ticket |
|---|---|---|
| **A lost reply is not a rolled-back operation.** Current [TimerTimeout][timeout] distinguishes SEND/REPLY blocking and server-mediated unblocking; the old guide also distinguishes abort before and after server receipt. | After installer/client failure, reconcile a transaction's durable generation/receipt before retrying. Test commit followed by lost completion; never infer that a timed-out update did not happen. This complements filesystem atomicity, not a replacement for it. | App platform + storage; R01. |
| **Resource ownership must survive abnormal client death.** Current resource-manager [open/close flow][resource-flow] binds a per-open context and arranges cleanup even after client death. | Define the Linux observer/owner responsible for every grant, subscription and cleanup record. Test killed clients as well as orderly close; a missing app callback cannot leave active grants or a false deletion result. Coordinate final deletion with lifecycle quiescence. | App lifecycle + identity; R02/R03. |
| **Authorize the actual peer and validate every boundary.** Current [resource-manager security guidance][resource-security] requires permission and message-length/content checks and reduced privileges. | Keep trusted peer identity separate from app-supplied fields. Test malformed/oversized requests, permission changes and replaced service owners. Invalidate cached authority when the authenticated peer/generation changes; warm adoption cannot inherit a previous identity. | IPC/security + launcher; R03/R04. |
| **An asynchronous-looking API may still stall its owner.** Current [IPC ordering guidance][ipc-ordering] explains dependency cycles; [process separation][processes] provides fault containment. | Keep blocking I/O and unbounded work off shell/Qt owners; bound admission and retained completions. A stalled app, AT client or provider must not stall unrelated shell input. During teardown, no owner waits synchronously for a worker that needs that owner to finish. | Native platform + accessibility + CI; R04/R08. |
| **Restart is only one step of recovery.** The archive's High Availability chapter and current [HA guidance][high-availability] cover reconnection/restoration; current [QPLMS][plms] is another QNX-specific supervision option. | On an allowlisted provider's death or hang, expose recovering/unavailable state, reconnect under current permission, obtain a fresh baseline and reject old-generation events. Reconcile unknown mutation outcomes; do not replay them automatically. Measure useful service progress and input/call/media latency under load, not just heartbeat-thread activity. | Device QA + service/lifecycle owners; R05/R06/R07. |
| **Elapsed deadlines, calendar dates and wake policy are different contracts.** Current [QNX clock guidance][qnx-clocks] separates monotonic and wall time; Linux [clock documentation][linux-clocks] additionally distinguishes suspend accounting. | Count queue time within request budgets. Select and document the actual Linux clock and suspend behavior; test time correction, timezone changes, freeze/resume and reboot separately. Keep persistent due dates/calendar schedules out of process-local elapsed-clock values. | Background/power + mail/meeting/task owners; R06. |
| **Observation needs ordering and a lifetime.** QNX request/event handling motivates explicit ownership; the existing RNQNX [recovery plan][rn-recovery] specifies a snapshot/stream handshake and service generations. | Give viewport and availability state a generation/sequence contract. Test initial-snapshot versus update races, hot-unplug/reconnect and warm adoption. Coalesce superseded state within a bound without losing required lifecycle transitions or delivering events after disposal. | Compositor + app lifecycle; R07. |
| **A historical sample is a lesson, not current build evidence.** Current [QNX migration guidance][migration] changes concrete types/APIs, and the RNQNX [systems-probe plan][rn-probes] already dispositions legacy examples. | Record source, SDK, target, actual imports and runtime lane for each fixture. Run malformed-input, timeout, death/reconnect and shutdown cases through the real affected native boundary. Host Linux/Qt evidence cannot certify QNX or physical-device behavior. | Build/CI + independent native reviewer; R08 and R05. |

Existing source seams remain the implementation starting points: R01/R02 use `crates/marathon-apps/src/install.rs`; R03 uses `crates/marathon-shell-native/src/{ipc,gate,sandbox}.rs`; R06 uses `crates/marathon-background/src/{task,generator}.rs` and the app's real advertised actions; R07 uses `shell/src/managers/screenmetrics.*`, shell launch/device setup and `tools/marathon-app-runner/main.cpp`; R08 uses `scripts/validate-qml.sh` and the registered native test jobs. R04 must select and verify the actual AT bridge API before naming an implementation. These paths are source seams, not fabricated new APIs.

## 4. Current QNX details that must not be copied blindly

For the separate QNX target, `TimerTimeout` must cover the relevant SEND and REPLY states and be armed immediately before the intended blocking call; another kernel call can consume its setup. With `_NTO_CHF_UNBLOCK`, an already-received request requires the server to handle the unblock and reply/error. Caller timeout therefore does not prove server cancellation, completed cleanup or that a mutation never occurred. Buffers remain owned until native use ends. The existing RNQNX [IPC plan][rn-ipc] already captures these requirements. [Official API][timeout].

The current QNX 8 migration guide requires 64-bit `rcvid_t` for stored receive identifiers, registered cross-process events and a preallocated stack for direct `ThreadCreate`; `pthread_create` supplies its own stack when needed. It also changes timer/clock behavior. Compile against the installed SDK and verify exact BSP/runtime behavior; neither an old sample's types nor introductory clock-tick prose establishes a latency guarantee. [Migration source][migration].

On Marathon's Linux target, `CLOCK_MONOTONIC` excludes suspended time while `CLOCK_BOOTTIME` includes it. Selecting a clock does not by itself wake the device or authorize wake work. R06 must state whether a deadline advances during suspend and how persistent schedules are reconstructed after boot. Native Qt elapsed-time helpers can support in-process duration measurement; their reference values are not portable saved calendar dates. [Linux clocks][linux-clocks], [Qt elapsed time][qt-elapsed].

## 5. Reuse the existing RNQNX work

Live GitHub PR records checked November 9 show the following **merged documentation plans**. Their bodies explicitly separate planned semantics from native/device execution. This crosswalk read the IPC, recovery and systems-probe plan bodies, plus the current-doc/catalog PR descriptions; it did not rerun their historical validation or change that repository.

| Existing work | Verified publication reference | Use here |
|---|---|---|
| [RNQNX #56][pr56] — IPC, deadlines and event ownership | Plan head `319d0ff3c50e77fc3cdbd5d040a978a9e4fa5db4`; merged November 7 | Retain its typed bounded IPC and actual timeout/ownership semantics. |
| [RNQNX #57][pr57] — service recovery | Plan head `5aaa5d890ec4585fca1e7809264f8bf3ade864d1`; merged November 7 | Retain generation, reconnect, unknown-outcome and shutdown contracts. |
| [RNQNX #62][pr62] — current systems probes | Plan head `843fd202c02e5b6b081cc7cf94f48ac80711bfc0`; merged November 7 | Reuse its archive disposition and target-specific probe ownership. |
| [RNQNX #63][pr63] — current documentation audit | Head `27d6601b6748a954b7e0e1057f6bc4120a50ed0b`; merged November 7 | Check selected current official sources and installed SDK evidence before implementation. |
| [RNQNX #64][pr64] — source/PR catalog and native-skill review | Head `ff9a9ae84d9dc2d264ca6ae79c0b97a91d55324f`; merged November 7 | Follow existing dependency/source mapping; keep the native-skill review's rejection of blocking IPC hidden by a Promise. |

## 6. Next bounded implementation and review

Start with R01's verified same-filesystem replacement transaction and lost-completion recovery fixture; its integrity defect is concrete and does not require a new OS abstraction. In parallel, R03/R04 can agree the authenticated app/AT boundary and R08 can make the actual native UI gate reliable. R06/R07 then add their lifetime, deadline and observation tests at the existing service seams. This is the queue's existing repair order, strengthened by the reference review.

For each affected slice, apply the native/API skills in [ENGINEERING_WORKFLOW.md](ENGINEERING_WORKFLOW.md), verify the selected APIs against source/headers, and delegate implementation and independent boundary review separately. Keep QNX-specific experiments in their own target with non-premium fixtures. Acceptance budgets must be selected and measured on the nominated platform; no number in a historical manual becomes a product promise.

Validation for this document is source/edition/PR qualification, local-link checks and diff review. No QNX SDK installation, archived-example execution, runtime port, scheduler change, build or new device test was performed for this crosswalk. Actual implementation/test receipts remain in the remediation queue and individual PRs; this document completes none of their release gates.

[archive]: https://github.com/Himmele/My-Blog-Repository/tree/b1fd3e9410c1a6a0d7217c3be7e324e900470d2a/QNX%20Neutrino%20RTOS
[old-programmer]: https://github.com/Himmele/My-Blog-Repository/blob/b1fd3e9410c1a6a0d7217c3be7e324e900470d2a/QNX%20Neutrino%20RTOS/QNX%20Neutrino%20RTOS%20-%20Programmer%27s%20Guide.pdf
[old-architecture]: https://github.com/Himmele/My-Blog-Repository/blob/b1fd3e9410c1a6a0d7217c3be7e324e900470d2a/QNX%20Neutrino%20RTOS/QNX%20Neutrino%20RTOS%20-%20System%20Architecture.pdf
[examples]: https://github.com/Himmele/My-Blog-Repository/tree/b1fd3e9410c1a6a0d7217c3be7e324e900470d2a/QNX%20Neutrino%20RTOS/Programming
[getting-started]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.getting_started/topic/about.html
[current-programmer]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/about.html
[current-architecture]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/ipc.html
[current-resmgr]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.resmgr/topic/about.html
[processes]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/overview_Application_as_processes.html
[ipc-ordering]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.sys_arch/topic/ipc_Robust.html
[timeout]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.lib_ref/topic/t/timertimeout.html
[resource-flow]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.getting_started/topic/s1_resmgr_general_flow.html
[resource-security]: https://qnx.com/developers/docs/8.0/com.qnx.doc.security.system/topic/manual/write_resource_manager.html
[high-availability]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/process_High_Availability.html
[plms]: https://qnx.com/developers/docs/8.0/com.qnx.doc.plms/topic/plms_overview.html
[qnx-clocks]: https://qnx.com/developers/docs/8.0/com.qnx.doc.neutrino.prog/topic/timing_Time_functions.html
[linux-clocks]: https://man7.org/linux/man-pages/man2/clock_gettime.2.html
[qt-elapsed]: https://doc.qt.io/qt-6/qelapsedtimer.html
[migration]: https://www.qnx.com/developers/docs/8.0/com.qnx.doc.qnxsdp.migration/topic/kernel.html
[marathon-ipc]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/crates/marathon-shell-native/src/ipc.rs
[marathon-rules]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/CODING_RULES.md
[rn-ipc]: https://github.com/mikevocalz/react-native-qnx/blob/319d0ff3c50e77fc3cdbd5d040a978a9e4fa5db4/docs/platform-modernization/07-qnx-ipc.md
[rn-recovery]: https://github.com/mikevocalz/react-native-qnx/blob/5aaa5d890ec4585fca1e7809264f8bf3ade864d1/docs/platform-modernization/08-service-recovery.md
[rn-probes]: https://github.com/mikevocalz/react-native-qnx/blob/843fd202c02e5b6b081cc7cf94f48ac80711bfc0/docs/platform-modernization/14-qnx-systems-probes.md
[pr56]: https://github.com/mikevocalz/react-native-qnx/pull/56
[pr57]: https://github.com/mikevocalz/react-native-qnx/pull/57
[pr62]: https://github.com/mikevocalz/react-native-qnx/pull/62
[pr63]: https://github.com/mikevocalz/react-native-qnx/pull/63
[pr64]: https://github.com/mikevocalz/react-native-qnx/pull/64
