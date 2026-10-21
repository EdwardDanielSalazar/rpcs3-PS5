#!/usr/bin/env python3
"""Read-only preflight for RPCS3 PPU LLVM object caches. Not an LLVM validator."""
import argparse
import gzip
import hashlib
import json
import re
import struct
from pathlib import Path

MAX_UNPACKED = 128 * 1024 * 1024
NAME_RE = re.compile(r"^v8-kusa-[^-]+-[^-]+-[^-]+\.obj(?:\.gz)?$")

def inspect(path: Path):
    result = {"path": str(path), "status": "reject", "warnings": []}
    try:
        if not path.is_file():
            raise ValueError("not a regular file")
        result["compressed_bytes"] = path.stat().st_size
        if result["compressed_bytes"] > MAX_UNPACKED:
            raise ValueError("file exceeds conservative 128 MiB input limit")
        if path.suffix == ".gz":
            with gzip.open(path, "rb") as handle:
                data = handle.read(MAX_UNPACKED + 1)
        else:
            data = path.read_bytes()
        if len(data) > MAX_UNPACKED:
            raise ValueError("decompressed data exceeds 128 MiB")
        if len(data) < 64 or data[:4] != b"\x7fELF":
            raise ValueError("not an ELF object (LLVM may support other formats)")
        cls, byteorder = data[4], data[5]
        if cls != 2 or byteorder not in (1, 2):
            raise ValueError("expected ELF64, valid endianness")
        endian = "<" if byteorder == 1 else ">"
        e_type, e_machine = struct.unpack_from(endian + "HH", data, 16)
        result.update({"uncompressed_bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                       "format": "ELF64", "endianness": "little" if byteorder == 1 else "big",
                       "elf_type": e_type, "machine": e_machine})
        if e_type != 1 or e_machine != 62 or byteorder != 1:
            raise ValueError("not a little-endian x86-64 relocatable ELF")
        result["status"] = "candidate"
        if not NAME_RE.fullmatch(path.name):
            result["warnings"].append("file name does not match observed v8-kusa pattern")
        result["warnings"].append("ELF header check only: no ABI, symbol, relocation, CPU-feature or LLVM load test")
    except (OSError, EOFError, ValueError, struct.error, gzip.BadGzipFile) as exc:
        result["reason"] = str(exc)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path, help="Object file or directory")
    args = parser.parse_args()
    paths = sorted(p for p in args.path.rglob("*") if p.is_file() and (p.name.endswith(".obj") or p.name.endswith(".obj.gz"))) if args.path.is_dir() else [args.path]
    results = [inspect(p) for p in paths]
    print(json.dumps({"note": "Read-only heuristic, NOT acceptance by RPCS3", "files": results}, indent=2))
    return 0 if results and all(r["status"] == "candidate" for r in results) else 1

if __name__ == "__main__":
    raise SystemExit(main())
