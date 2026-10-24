#!/usr/bin/env bash
# Add targeted, read-only NV406E semaphore tracing to the pinned RPCS3 checkout.
# Idempotent: safe for Ninja/CI rebuilds. Never changes acquire/release semantics.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$root/src/rpcs3/rpcs3/Emu/RSX/rsx_methods.cpp"
python3 - "$source_file" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
marker = 'PS5-RSX-SEMA-DIAG'
if marker in s:
    print('[rsx-sema-diag] already patched')
    raise SystemExit(0)
original = """\t\tbind(NV406E_SEMAPHORE_ACQUIRE, nv406e::semaphore_acquire);
\t\tbind(NV406E_SEMAPHORE_RELEASE, nv406e::semaphore_release);"""
replacement = """\t\tbind(NV406E_SEMAPHORE_ACQUIRE, ps5_diag_semaphore_acquire);
\t\tbind(NV406E_SEMAPHORE_RELEASE, ps5_diag_semaphore_release);\n\t\trsx_log.warning("PS5-RSX-SEMA-DIAG v2 installed: NV406E command hooks active");"""
anchor = '\tvoid invalid_method(context* ctx, u32 reg, u32 arg)\n'
wrapper = """\t// PS5-RSX-SEMA-DIAG v2: observe command inputs without modifying NV406E behavior.
\tstatic void ps5_diag_semaphore_acquire(context* ctx, u32 reg, u32 arg)
\t{
\t\tstatic u32 sample_count = 0;
\t\tconst u32 offset = REGS(ctx)->registers[NV406E_SEMAPHORE_OFFSET];
\t\tconst u32 base = RSX(ctx)->label_addr;
\t\tif (sample_count++ < 256 || (sample_count % 4096) == 0)
\t\t{
\t\t\trsx_log.warning("PS5-RSX-SEMA-DIAG v2 acquire offset=0x%x arg=0x%x label_base=0x%x candidate_addr=0x%x fifo_cmd=0x%x count=%u",
\t\t\t\toffset, arg, base, base + offset, RSX(ctx)->get_fifo_cmd(), sample_count);
\t\t}
\t\tnv406e::semaphore_acquire(ctx, reg, arg);
\t}
\tstatic void ps5_diag_semaphore_release(context* ctx, u32 reg, u32 arg)
\t{
\t\tstatic u32 sample_count = 0;
\t\tconst u32 offset = REGS(ctx)->registers[NV406E_SEMAPHORE_OFFSET];
\t\tconst u32 base = RSX(ctx)->label_addr;
\t\tif (sample_count++ < 256 || (sample_count % 4096) == 0)
\t\t{
\t\t\trsx_log.warning("PS5-RSX-SEMA-DIAG v2 release offset=0x%x arg=0x%x label_base=0x%x candidate_addr=0x%x fifo_cmd=0x%x count=%u",
\t\t\t\toffset, arg, base, base + offset, RSX(ctx)->get_fifo_cmd(), sample_count);
\t\t}
\t\tnv406e::semaphore_release(ctx, reg, arg);
\t}

"""
if s.count(original) != 1 or s.count(anchor) != 1:
    raise SystemExit('[rsx-sema-diag] expected source anchors not found; refusing to patch')
s = s.replace(anchor, wrapper + anchor, 1).replace(original, replacement, 1)
p.write_text(s)
print('[rsx-sema-diag] patched NV406E acquire/release handlers v2')
PY
