#!/usr/bin/env python3
"""Passive macOS USB inventory and offline ELF inspection; no device protocol support."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import plistlib
import stat
import struct
import subprocess
import sys
from pathlib import Path

MAX_FILE = 256 * 1024 * 1024
MAX_HEADERS = 4096
USB_FIELDS = ("idVendor", "idProduct", "bcdDevice", "bDeviceClass",
              "bDeviceSubClass", "bDeviceProtocol")
INTERFACE_FIELDS = ("bInterfaceNumber", "bInterfaceClass",
                    "bInterfaceSubClass", "bInterfaceProtocol")


def usb_inventory(roots: list) -> list[dict]:
    devices = []
    seen = set()

    def interfaces(node):
        found = []
        if node.get("IOObjectClass") == "IOUSBHostInterface":
            found.append({k: node[k] for k in INTERFACE_FIELDS
                          if type(node.get(k)) is int})
            return found
        for child in node.get("IORegistryEntryChildren", []):
            if child.get("IOObjectClass") != "IOUSBHostDevice":
                found.extend(interfaces(child))
        return found

    def walk(node):
        if node.get("IOObjectClass") == "IOUSBHostDevice" and node.get("idVendor") == 0x0FCA:
            identity = node.get("IORegistryEntryID")
            if identity is None or identity not in seen:
                if identity is not None:
                    seen.add(identity)
                device = {k: node[k] for k in USB_FIELDS
                          if type(node.get(k)) is int}
                device["interfaces"] = interfaces(node)
                device["model"] = "unknown"
                device["bb10_software_release"] = "unknown"
                device["bb10_os_version"] = "unknown"
                device["hardware_revision"] = "unknown"
                device["root_status"] = "unknown"
                devices.append(device)
        for child in node.get("IORegistryEntryChildren", []):
            walk(child)

    for root in roots:
        walk(root)
    return devices


def inventory() -> dict:
    if platform.system() != "Darwin":
        raise ValueError("inventory requires macOS on the USB-attached host, not a remote VM")
    result = subprocess.run(
        ["/usr/sbin/ioreg", "-a", "-l", "-r", "-c", "IOUSBHostDevice"],
        capture_output=True, check=True, timeout=20,
    )
    return {"schema": 1, "status": "Observed on the USB host",
            "host_os": "macOS", "host_architecture": platform.machine(),
            "devices": usb_inventory(plistlib.loads(result.stdout)),
            "limitations": [
                "Only cached IORegistry descriptors are queried; no USB device is opened.",
                "Absent devices may be asleep, disconnected or not enumerated; no reset is attempted.",
                "VID/PID and USB class do not establish Passport variant, firmware, root or recovery.",
                "No serial, PIN, IMEI, MAC address, registry path or volume contents are included.",
            ]}


def span(data: bytes, offset: int, size: int, label: str) -> memoryview:
    if offset < 0 or size < 0 or offset > len(data) or size > len(data) - offset:
        raise ValueError(f"{label} exceeds file bounds")
    return memoryview(data)[offset:offset + size]


def inspect_elf(data: bytes) -> dict:
    ident = span(data, 0, 16, "ELF identification")
    if ident[:4] != b"\x7fELF":
        raise ValueError("not an ELF file; vendor containers are not guessed")
    if ident[4] not in (1, 2) or ident[5] not in (1, 2) or ident[6] != 1:
        raise ValueError("unsupported ELF class, byte order or version")
    bits = 32 if ident[4] == 1 else 64
    endian = "<" if ident[5] == 1 else ">"
    layout = "HHIIIIIHHHHHH" if bits == 32 else "HHIQQQIHHHHHH"
    size = 16 + struct.calcsize(endian + layout)
    fields = struct.unpack(endian + layout, span(data, 16, size - 16, "ELF header"))
    kind, machine, version, entry, phoff, shoff, flags, ehsize, phsize, phnum, shsize, shnum, shstr = fields
    if version != 1 or ehsize != size:
        raise ValueError("invalid ELF version or header size")
    if phnum == 0xFFFF or shstr == 0xFFFF or (shoff and shnum == 0):
        raise ValueError("extended ELF table numbering is not supported")
    if phnum > MAX_HEADERS or shnum > MAX_HEADERS:
        raise ValueError("ELF table count exceeds inspection limit")
    expected_phsize, expected_shsize = (32, 40) if bits == 32 else (56, 64)
    for offset, count, stride, expected, name in (
        (phoff, phnum, phsize, expected_phsize, "program header table"),
        (shoff, shnum, shsize, expected_shsize, "section header table"),
    ):
        if count:
            if stride != expected or offset < size:
                raise ValueError(f"invalid {name} offset or entry size")
            span(data, offset, count * stride, name)
    if (shnum == 0 and shstr != 0) or (shnum and shstr >= shnum):
        raise ValueError("invalid section-name string table index")
    segments = []
    interpreter = None
    for index in range(phnum):
        raw = span(data, phoff + index * phsize, phsize, "program header")
        if bits == 32:
            ptype, offset, vaddr, paddr, filesz, memsz, pflags, align = struct.unpack(endian + "8I", raw)
        else:
            ptype, pflags, offset, vaddr, paddr, filesz, memsz, align = struct.unpack(endian + "II6Q", raw)
        payload = span(data, offset, filesz, f"segment {index}")
        if ptype == 1 and filesz > memsz:
            raise ValueError(f"load segment {index} file size exceeds memory size")
        if align > 1 and (align & (align - 1) or vaddr % align != offset % align):
            raise ValueError(f"invalid segment {index} alignment")
        if ptype == 3:
            if interpreter is not None or not 1 < filesz <= 4096 or payload[-1:] != b"\0":
                raise ValueError("invalid or duplicate PT_INTERP")
            interpreter_bytes = bytes(payload)
            if b"\0" in interpreter_bytes[:-1]:
                raise ValueError("embedded NUL in PT_INTERP")
            interpreter = interpreter_bytes[:-1].decode("ascii")
        segments.append({"type": ptype, "offset": offset, "file_size": filesz,
                         "memory_size": memsz, "virtual_address": hex(vaddr),
                         "physical_address": hex(paddr), "flags": pflags, "alignment": align})
    for index in range(shnum):
        raw = span(data, shoff + index * shsize, shsize, "section header")
        section = struct.unpack(endian + ("10I" if bits == 32 else "II4QII2Q"), raw)
        if section[1] != 8:  # SHT_NOBITS has no file payload.
            span(data, section[4], section[5], f"section {index}")
    runtime = "unknown (ELF format alone does not identify an OS)"
    if interpreter and interpreter.startswith("/usr/lib/ldqnx.so"):
        runtime = "QNX dynamic linker requested; not a Linux executable"
    elif interpreter in ("/system/bin/linker", "/system/bin/linker64"):
        runtime = "Android dynamic linker requested"
    elif interpreter and ("ld-linux" in interpreter or "ld-musl-" in interpreter):
        runtime = "Linux dynamic linker requested"
    arm32_le = bits == 32 and machine == 40 and ident[5] == 1
    return {"format": "elf", "bits": bits, "byte_order": "little" if ident[5] == 1 else "big",
            "machine": machine, "type": kind, "entry": hex(entry), "osabi_byte": ident[7],
            "flags": hex(flags), "arm_eabi_version": flags >> 24 if machine == 40 else None,
            "arm_float_flags": {"soft": bool(flags & 0x200), "hard": bool(flags & 0x400)}
            if machine == 40 else None,
            "interpreter": interpreter, "runtime_evidence": runtime,
            "header_matches_arm32_le": arm32_le, "program_headers": segments,
            "section_count": shnum,
            "limitations": ["Header compatibility does not establish ARM ISA coverage, libc ABI, signatures or bootability.",
                            "No signature authentication, BB10 container parsing or device execution is performed."]}


def inspect_file(path: Path) -> dict:
    before = path.lstat()
    if not stat.S_ISREG(before.st_mode):
        raise ValueError("only regular files are allowed, never symlinks, device nodes or pipes")
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or (before.st_dev, before.st_ino) != (info.st_dev, info.st_ino):
            raise ValueError("file identity changed during open")
        if info.st_size > MAX_FILE:
            raise ValueError("file exceeds 256 MiB inspection limit")
        data = stream.read(MAX_FILE + 1)
        if len(data) != info.st_size:
            raise ValueError("file changed during read or exceeds inspection limit")
    return {"schema": 1, "status": "Reproduced offline", "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(), **inspect_elf(data)}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("inventory", help="macOS IORegistry only; redacted JSON on stdout")
    inspect = sub.add_parser("inspect", help="bounded offline ELF header/segment inspection")
    inspect.add_argument("path", type=Path)
    inspect.add_argument("--require-arm32-le", action="store_true",
                         help="exit 1 unless the ELF header names little-endian 32-bit ARM")
    args = parser.parse_args(argv)
    try:
        result = inventory() if args.command == "inventory" else inspect_file(args.path)
        print(json.dumps(result, indent=2))
        if args.command == "inspect" and args.require_arm32_le and not result["header_matches_arm32_le"]:
            return 1
        return 0
    except (OSError, ValueError, subprocess.SubprocessError, plistlib.InvalidFileException) as exc:
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
