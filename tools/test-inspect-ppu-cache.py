#!/usr/bin/env python3
"""Self-contained tests for tools/inspect-ppu-cache.py (no PS5 or game files needed)."""
import gzip
import importlib.util
import struct
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).with_name("inspect-ppu-cache.py")
spec = importlib.util.spec_from_file_location("ppu_cache_inspector", TOOL)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def elf64(machine=62, filetype=1):
    data = bytearray(64)
    data[:4] = b"\x7fELF"
    data[4], data[5], data[6] = 2, 1, 1
    struct.pack_into("<HH", data, 16, filetype, machine)
    return bytes(data)

class CacheInspectorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
    def sample(self, name, data):
        p = self.root / name
        p.write_bytes(data)
        return p
    def test_x64_relocatable_candidate(self):
        p = self.sample("v8-kusa-hash-settings-znver2.obj", elf64())
        self.assertEqual(mod.inspect(p)["status"], "candidate")
    def test_gzip_candidate(self):
        p = self.sample("v8-kusa-hash-settings-znver2.obj.gz", gzip.compress(elf64()))
        self.assertEqual(mod.inspect(p)["status"], "candidate")
    def test_wrong_machine_rejected(self):
        self.assertEqual(mod.inspect(self.sample("a.obj", elf64(machine=183)))["status"], "reject")
    def test_nonrelocatable_rejected(self):
        self.assertEqual(mod.inspect(self.sample("a.obj", elf64(filetype=2)))["status"], "reject")
    def test_truncated_gzip_rejected(self):
        self.assertEqual(mod.inspect(self.sample("a.obj.gz", b"\x1f\x8b"))["status"], "reject")
    def test_invalid_blob_rejected(self):
        self.assertEqual(mod.inspect(self.sample("a.obj", b"not an ELF"))["status"], "reject")
    def test_name_warning(self):
        self.assertTrue(mod.inspect(self.sample("a.obj", elf64()))["warnings"])

if __name__ == "__main__":
    unittest.main()
