# Passport research inspection tools

Experimental, inspection-only helpers for the **original** BlackBerry Passport.
These are not an installer, loader, root tool or supported Marathon device port.
They do not add Passport to the image builder or make an ARM64 image usable on it.

Requires Python 3.9+ on macOS or Linux for offline inspection; USB inventory requires
macOS on the computer physically connected to the phone. No extra Python modules
are needed. Commands print JSON to stdout; errors exit 2.

## Passive inventory

```sh
python3 tools/passport/passport.py inventory
```

Uses only `/usr/sbin/ioreg -a -l -r -c IOUSBHostDevice`. It reads cached properties;
it does not claim a USB interface, change configurations, send control transfers,
authenticate, reset, probe network ports, open storage, mount volumes or use ADB.
Only numeric USB identity/class fields for vendor `0x0fca` and interface class
fields are returned. Identifying strings, serials, PINs, MACs and registry paths
are never emitted. Other vendors' devices are omitted.

An empty list means no matching device was present in that snapshot, not that a
Passport is unsupported or an Android debugging interface is required. A USB
product identity cannot establish the exact model, firmware, board revision,
root status or recovery capability. These remain explicitly unknown. Obtain
model and firmware from the ordinary Settings → About screen; never substitute
another researcher's inventory for this phone's.

To retain a local record, use a private directory **outside Git**:

```sh
umask 077
python3 tools/passport/passport.py inventory > /path/to/private-record/inventory.json
```

## Offline ELF and ABI inspection

```sh
python3 tools/passport/passport.py inspect /path/to/public-or-authorized/image.elf
python3 tools/passport/passport.py inspect /path/to/image.elf --require-arm32-le
```

The second command exits 1 when the header is not ELF32 little-endian `EM_ARM`.
This is a **header gate only**, not an assertion that the CPU can execute every
instruction, that userspace matches its libc/float ABI, or that the boot chain
accepts the file. The Passport research target is ARMv7, not AArch64. A QNX
ELF can pass the CPU-header gate while being unusable as a Linux program.

The inspector reports all program headers, ELF class, endianness, machine, EABI
and float flags, `PT_INTERP`, and SHA-256. It labels runtime evidence from the
interpreter separately from the generic ELF OSABI byte. For example,
`/usr/lib/ldqnx.so.2` requests a QNX loader even when ELF OSABI is SYSV. A static
ELF without such evidence has an **unknown OS**, not an assumed Linux one.

Only regular, non-symlink files up to 256 MiB are accepted; input is opened
read-only. Header tables, segment/file extents, load sizes, alignment and
interpreter termination are checked. NOBITS sections are not read from the
file. Extended ELF table numbering is deliberately rejected. This is a narrow
inspector, not a complete executable verifier or firmware-container parser.
It neither extracts nor executes anything and never writes an image.

## Offline tests

```sh
python3 tools/passport/test_passport.py
python3 -m compileall -q tools/passport
```

`Passport_Inspection` registers the same suite with CTest when Marathon is
configured with `BUILD_TESTING=ON`. It covers redaction, duplicate registry
entries, interface attribution, exact passive command selection, non-macOS
refusal, QNX/Linux/Android interpreter distinctions, ARM32/AArch64 and endian
gates, malformed tables/segments, truncated files, NOBITS, pipes, device nodes,
symlinks, oversized files, and seeded malformed-input mutations. No phone is
needed or contacted by the tests.

## Research safety boundary

- The public research repository's `tools/session29-extcsd/extcsd_probe.c` is
  **not** read-only: it opens `boot0` with `O_RDWR` and issues write-protection
  clear controls. This utility intentionally has no equivalent command.
- Root inside BB10 is distinct from replacement-kernel execution, Linux boot,
  Marathon launch and a usable phone. Offline tests prove none of those milestones.
- A RAM-loader/authentication session can affect recovery even without an
  intended flash. Do not use a loader handshake as an identification probe.
- A user-data backup is not a boot/NV/calibration/RPMB recovery image. No backup
  or recoverability claim follows from this inventory.
- Never use another phone's image or a Q25 conversion image on this device.

Source references (evidence, not execution instructions):

- [ELF gABI header and program-header structures](https://refspecs.linuxfoundation.org/elf/gabi4+/contents.html)
- [ARM ELF ABI](https://github.com/ARM-software/abi-aa/blob/2025Q1/aaelf32/aaelf32.rst)
- [Audited probe source, pinned](https://github.com/stanw47/Blackberry-Passport-Research/blob/24848b248cf9d2f8feb68991895b463a795af321/tools/session29-extcsd/extcsd_probe.c)
- [Reported interrupted-handshake wipe](https://github.com/stanw47/Blackberry-Passport-Research/blob/24848b248cf9d2f8feb68991895b463a795af321/notes/session28-retail-ramloader-wipe-reroot.md)
- [Stage3 ELF generator, pinned](https://github.com/BBAndroids/passport_stage3/blob/b3ab5553db9b79c874e004cbb894099c283b98f4/make_stage3.cpp)
- [Marathon device requirements](../../docs/DEVICE_SUPPORT.md)
