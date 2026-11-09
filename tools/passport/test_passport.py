#!/usr/bin/env python3
import contextlib
import io
import json
import os
import plistlib
import random
import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import passport


def elf(bits=32, endian="<", machine=40, interpreter=None):
    ident = b"\x7fELF" + bytes([1 if bits == 32 else 2, 1 if endian == "<" else 2, 1]) + bytes(9)
    ehsize, phsize = (52, 32) if bits == 32 else (64, 56)
    payload = interpreter.encode() + b"\0" if interpreter else b""
    header = struct.pack(endian + ("HHIIIIIHHHHHH" if bits == 32 else "HHIQQQIHHHHHH"),
                         3, machine, 1, 0, ehsize if payload else 0, 0, 0x05000200,
                         ehsize, phsize, int(bool(payload)), 0, 0, 0)
    if not payload:
        return ident + header
    offset = ehsize + phsize
    segment = (struct.pack(endian + "8I", 3, offset, offset, offset, len(payload), len(payload), 4, 1)
               if bits == 32 else
               struct.pack(endian + "II6Q", 3, 4, offset, offset, offset, len(payload), len(payload), 1))
    return ident + header + segment + payload


def change(data, offset, fmt, value):
    data = bytearray(data)
    struct.pack_into(fmt, data, offset, value)
    return bytes(data)


class ElfTests(unittest.TestCase):
    def test_qnx_not_inferred_linux_from_sysv_osabi(self):
        result = passport.inspect_elf(elf(interpreter="/usr/lib/ldqnx.so.2"))
        self.assertEqual(result["osabi_byte"], 0)
        self.assertTrue(result["header_matches_arm32_le"])
        self.assertIn("QNX", result["runtime_evidence"])
        self.assertEqual(result["arm_eabi_version"], 5)
        self.assertEqual(result["arm_float_flags"], {"soft": True, "hard": False})

    def test_static_image_os_is_unknown(self):
        result = passport.inspect_elf(elf())
        self.assertIsNone(result["interpreter"])
        self.assertIn("unknown", result["runtime_evidence"])

    def test_loader_hints_are_not_phone_results(self):
        for path, hint in (("/system/bin/linker", "Android"),
                           ("/lib/ld-linux-armhf.so.3", "Linux"),
                           ("/lib/ld-musl-armhf.so.1", "Linux"),
                           ("/custom/loader", "unknown")):
            with self.subTest(path=path):
                self.assertIn(hint, passport.inspect_elf(elf(interpreter=path))["runtime_evidence"])

    def test_aarch64_rejected_as_passport_header(self):
        result = passport.inspect_elf(elf(bits=64, machine=183, interpreter="/system/bin/linker64"))
        self.assertFalse(result["header_matches_arm32_le"])
        self.assertEqual(result["bits"], 64)

    def test_big_endian_and_other_machines(self):
        for data in (elf(endian=">"), elf(machine=3), elf(bits=64, machine=40)):
            self.assertFalse(passport.inspect_elf(data)["header_matches_arm32_le"])

    def test_all_truncated_headers(self):
        for bits in (32, 64):
            data = elf(bits=bits)
            for n in range(len(data)):
                with self.subTest(bits=bits, size=n), self.assertRaises(ValueError):
                    passport.inspect_elf(data[:n])

    def test_bad_identification(self):
        for offset, value in ((0, 0), (4, 3), (5, 0), (6, 2)):
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                passport.inspect_elf(change(elf(), offset, "B", value))

    def test_invalid_header_and_table_fields(self):
        base = elf(interpreter="/usr/lib/ldqnx.so.2")
        cases = ((20, "<I", 2), (40, "<H", 0), (42, "<H", 1),
                 (28, "<I", 0), (28, "<I", 0xFFFFFFF0),
                 (44, "<H", 0xFFFF), (44, "<H", 5000), (48, "<H", 5000),
                 (32, "<I", 52), (50, "<H", 0xFFFF), (50, "<H", 1))
        for offset, fmt, value in cases:
            with self.subTest(offset=offset, value=value), self.assertRaises(ValueError):
                passport.inspect_elf(change(base, offset, fmt, value))

    def test_segment_extent_and_interpreter_errors(self):
        base = elf(interpreter="/usr/lib/ldqnx.so.2")
        for data in (change(base, 56, "<I", 0xFFFFFF00),
                     change(base, 68, "<I", 0xFFFFFF00), base[:-1], base[:-1] + b"x",
                     base[:-2] + b"\0\0"):
            with self.subTest(data=data.hex()), self.assertRaises(ValueError):
                passport.inspect_elf(data)

    def test_load_segment_memory_and_alignment(self):
        base = change(elf(interpreter="/fake/loader"), 52, "<I", 1)
        passport.inspect_elf(base)
        for offset, value in ((72, 1), (80, 3)):
            with self.subTest(offset=offset, value=value), self.assertRaises(ValueError):
                passport.inspect_elf(change(base, offset, "<I", value))
        with self.assertRaises(ValueError):
            passport.inspect_elf(change(change(base, 80, "<I", 16), 60, "<I", 85))

    def test_nobits_is_not_file_payload(self):
        data = change(elf(), 32, "<I", 52)
        data = change(data, 46, "<H", 40)
        data = change(data, 48, "<H", 1)
        section = struct.pack("<10I", 0, 8, 0, 0, 0xFFFFFF00, 0xFFFFFF00, 0, 0, 1, 0)
        self.assertEqual(passport.inspect_elf(data + section)["section_count"], 1)
        with self.assertRaises(ValueError):
            passport.inspect_elf(data + change(section, 4, "<I", 1))

    def test_seeded_malformed_inputs_do_not_escape_validation(self):
        rng = random.Random(8974)
        base = elf(interpreter="/usr/lib/ldqnx.so.2")
        for _ in range(500):
            data = bytearray(base)
            for _ in range(rng.randrange(1, 6)):
                data[rng.randrange(len(data))] = rng.randrange(256)
            try:
                passport.inspect_elf(bytes(data))
            except ValueError:
                pass


class InventoryTests(unittest.TestCase):
    def test_only_allowlisted_fields_escape(self):
        node = {"IOObjectClass": "IOUSBHostDevice", "idVendor": 4042,
                "idProduct": 32788, "IORegistryEntryID": 7,
                "USB Serial Number": "PRIVATE", "USB Product Name": "OWNER",
                "pin": "PRIVATE", "IORegistryEntryChildren": [
                    {"IOObjectClass": "IOUSBHostInterface", "bInterfaceClass": 8, "bInterfaceSubClass": 6,
                     "bInterfaceProtocol": 80, "Serial Number": "PRIVATE"}]}
        devices = passport.usb_inventory([node, node, {"idVendor": 3034, "idProduct": 33107}])
        self.assertEqual(len(devices), 1)
        self.assertEqual(devices[0]["interfaces"][0]["bInterfaceClass"], 8)
        self.assertEqual(devices[0]["model"], "unknown")
        output = json.dumps(devices)
        for private in ("PRIVATE", "OWNER", "IORegistry", "Serial", "pin"):
            self.assertNotIn(private, output)

    def test_nested_device_interfaces_are_not_attributed_to_parent(self):
        child = {"IOObjectClass": "IOUSBHostDevice", "idVendor": 4042, "idProduct": 2,
                 "IORegistryEntryChildren": [{"IOObjectClass": "IOUSBHostInterface", "bInterfaceClass": 2}]}
        parent = {"IOObjectClass": "IOUSBHostDevice", "idVendor": 4042,
                  "idProduct": 1, "IORegistryEntryChildren": [child]}
        devices = passport.usb_inventory([parent])
        self.assertEqual(devices[0]["interfaces"], [])
        self.assertEqual(devices[1]["interfaces"], [{"bInterfaceClass": 2}])

    def test_inherited_driver_properties_are_not_extra_devices_or_interfaces(self):
        driver = {"IOObjectClass": "IOUSBMassStorageDriverNub", "idVendor": 4042,
                  "idProduct": 32788, "bInterfaceClass": 8}
        interface = {"IOObjectClass": "IOUSBHostInterface", "idVendor": 4042,
                     "idProduct": 32788, "bInterfaceClass": 8,
                     "IORegistryEntryChildren": [driver]}
        device = {"IOObjectClass": "IOUSBHostDevice", "idVendor": 4042,
                  "idProduct": 32788, "IORegistryEntryChildren": [interface]}
        result = passport.usb_inventory([device])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["interfaces"], [{"bInterfaceClass": 8}])

    def test_no_device_is_unknown_not_android_failure(self):
        self.assertEqual(passport.usb_inventory([]), [])

    @patch("passport.platform.system", return_value="Darwin")
    @patch("passport.subprocess.run")
    def test_inventory_uses_only_passive_ioreg(self, run, _):
        run.return_value.stdout = plistlib.dumps([])
        self.assertEqual(passport.inventory()["devices"], [])
        run.assert_called_once_with(
            ["/usr/sbin/ioreg", "-a", "-l", "-r", "-c", "IOUSBHostDevice"],
            capture_output=True, check=True, timeout=20)

    @patch("passport.platform.system", return_value="Darwin")
    @patch("passport.subprocess.run")
    def test_invalid_inventory_plist_has_redacted_structured_error(self, run, _):
        for data in (b"not a plist", b'<?xml version="1.0"?><plist><array>',
                     b'<?xml version="1.0"?><plist><integer>PRIVATE</integer></plist>'):
            with self.subTest(data=data):
                run.return_value.stdout = data
                with contextlib.redirect_stdout(io.StringIO()) as output, \
                        contextlib.redirect_stderr(io.StringIO()) as error:
                    self.assertEqual(passport.main(["inventory"]), 2)
                self.assertEqual(output.getvalue(), "")
                self.assertEqual(json.loads(error.getvalue()),
                                 {"error": "invalid IORegistry property-list response"})

    @patch("passport.platform.system", return_value="Darwin")
    @patch("passport.subprocess.run")
    def test_invalid_inventory_tree_has_redacted_structured_error(self, run, _):
        shapes = ("PRIVATE", {"private": "PRIVATE"}, [True],
                  [{"IORegistryEntryChildren": "PRIVATE"}],
                  [{"IORegistryEntryChildren": ["PRIVATE"]}])
        shapes += tuple([{"IOObjectClass": "IOUSBHostDevice", "idVendor": 4042,
                          "IORegistryEntryID": identity}]
                        for identity in (["PRIVATE"], True, -1))
        for shape in shapes:
            with self.subTest(shape=shape):
                run.return_value.stdout = plistlib.dumps(shape)
                with contextlib.redirect_stdout(io.StringIO()) as output, \
                        contextlib.redirect_stderr(io.StringIO()) as error:
                    self.assertEqual(passport.main(["inventory"]), 2)
                self.assertEqual(output.getvalue(), "")
                self.assertEqual(json.loads(error.getvalue()),
                                 {"error": "invalid IORegistry property-list response"})

    @patch("passport.platform.system", return_value="Linux")
    @patch("passport.subprocess.run")
    def test_remote_vm_cannot_claim_local_inventory(self, run, _):
        with self.assertRaises(ValueError):
            passport.inventory()
        run.assert_not_called()


class FileTests(unittest.TestCase):
    def test_regular_file_hash_and_architecture_exit(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "sample.elf"
            data = elf(bits=64, machine=183)
            path.write_bytes(data)
            self.assertEqual(passport.inspect_file(path)["bytes"], len(data))
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(passport.main(["inspect", str(path), "--require-arm32-le"]), 1)
            self.assertFalse(json.loads(output.getvalue())["header_matches_arm32_le"])
            self.assertEqual(path.read_bytes(), data)

    def test_device_nodes_and_symlinks_are_not_read(self):
        with patch("passport.os.open") as open_file:
            with self.assertRaises(ValueError):
                passport.inspect_file(Path("/dev/null"))
            open_file.assert_not_called()
        with tempfile.TemporaryDirectory() as temp:
            link = Path(temp) / "link"
            link.symlink_to("/dev/null")
            with self.assertRaises(ValueError):
                passport.inspect_file(link)

    def test_fifo_does_not_block(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "pipe"
            os.mkfifo(path)
            with self.assertRaises(ValueError):
                passport.inspect_file(path)

    def test_oversized_file_is_rejected_before_read(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "large"
            with path.open("wb") as stream:
                stream.truncate(passport.MAX_FILE + 1)
            with self.assertRaises(ValueError):
                passport.inspect_file(path)

    def test_invalid_file_has_structured_error(self):
        with contextlib.redirect_stderr(io.StringIO()) as output:
            self.assertEqual(passport.main(["inspect", "/does-not-exist"]), 2)
        self.assertIn("error", json.loads(output.getvalue()))


if __name__ == "__main__":
    unittest.main()
