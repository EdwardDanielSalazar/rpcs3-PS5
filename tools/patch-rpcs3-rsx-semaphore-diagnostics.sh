#!/usr/bin/env bash
# Keep V4 semaphore observation and transition reads but downgrade its messages to TRACE for an A/B experiment.
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
\t\tbind(NV406E_SEMAPHORE_RELEASE, ps5_diag_semaphore_release);\n\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 installed: NV406E command hooks active");"""
anchor = '\tvoid invalid_method(context* ctx, u32 reg, u32 arg)\n'
wrapper = """\t// PS5-RSX-SEMA-DIAG v4: observe command inputs without modifying NV406E behavior.
\tstatic void ps5_diag_semaphore_acquire(context* ctx, u32 reg, u32 arg)
\t{
\t\tstatic u32 sample_count = 0;
\t\tconst u32 offset = REGS(ctx)->registers[NV406E_SEMAPHORE_OFFSET];
\t\tconst u32 base = RSX(ctx)->label_addr;
\t\tconst u32 dma_context = REGS(ctx)->semaphore_context_dma_406e();
\t\tconst u32 address = rsx::get_address(offset, dma_context);
\t\tconst bool watched = address == 0x50300510 || address == 0x50300520;
\t\tif (watched)
\t\t{
\t\t\tif (vm::check_addr(address, vm::page_readable))
\t\t\t{
\t\t\t\tconst u32 memory_value = vm::read32(address);
\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WATCH acquire offset=0x%x addr=0x%x requested=0x%x guest_mem=0x%x", offset, address, arg, memory_value);
\t\t\t}
\t\t\telse
\t\t\t{
\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WATCH acquire offset=0x%x addr=0x%x requested=0x%x guest_mem=unmapped", offset, address, arg);
\t\t\t}
\t\t}
\t\tif (sample_count++ < 256 || (sample_count % 4096) == 0 || watched)
\t\t{
\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 acquire offset=0x%x arg=0x%x label_base=0x%x candidate_addr=0x%x fifo_cmd=0x%x count=%u",
\t\t\t\toffset, arg, base, address, RSX(ctx)->get_fifo_cmd(), sample_count);
\t\t}
\t\tnv406e::semaphore_acquire(ctx, reg, arg);
\t}
\tstatic void ps5_diag_semaphore_release(context* ctx, u32 reg, u32 arg)
\t{
\t\tstatic u32 sample_count = 0;
\t\tconst u32 offset = REGS(ctx)->registers[NV406E_SEMAPHORE_OFFSET];
\t\tconst u32 base = RSX(ctx)->label_addr;
\t\tconst u32 dma_context = REGS(ctx)->semaphore_context_dma_406e();
\t\tconst u32 address = rsx::get_address(offset, dma_context);
\t\tconst bool watched = address == 0x50300510 || address == 0x50300520;
\t\tif (watched)
\t\t{
\t\t\tif (vm::check_addr(address, vm::page_readable))
\t\t\t{
\t\t\t\tconst u32 memory_value = vm::read32(address);
\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WATCH release offset=0x%x addr=0x%x requested=0x%x guest_mem=0x%x", offset, address, arg, memory_value);
\t\t\t}
\t\t\telse
\t\t\t{
\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WATCH release offset=0x%x addr=0x%x requested=0x%x guest_mem=unmapped", offset, address, arg);
\t\t\t}
\t\t}
\t\tif (sample_count++ < 256 || (sample_count % 4096) == 0 || watched)
\t\t{
\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 release offset=0x%x arg=0x%x label_base=0x%x candidate_addr=0x%x fifo_cmd=0x%x count=%u",
\t\t\t\toffset, arg, base, address, RSX(ctx)->get_fifo_cmd(), sample_count);
\t\t}
\t\tnv406e::semaphore_release(ctx, reg, arg);
\t}

"""
if s.count(original) != 1 or s.count(anchor) != 1:
    raise SystemExit('[rsx-sema-diag] expected source anchors not found; refusing to patch')
s = s.replace(anchor, wrapper + anchor, 1).replace(original, replacement, 1)
# Instrument the original wait loop to capture actual value transitions.
# This cannot attribute writes to a particular PPU/SPU/GPU thread.
nv = p.with_name('NV47') / 'HW' / 'nv406e.cpp'
n = nv.read_text()
if marker not in n:
    wait_anchor = 'u64 start = get_system_time();'
    if n.count(wait_anchor) != 1:
        raise SystemExit('[rsx-sema-diag] nv406e wait anchor not found')
    n = n.replace(wait_anchor, '''const bool ps5_diag_watch = (addr == 0x50300510 || addr == 0x50300520);
\t\t\tu32 ps5_diag_previous = static_cast<u32>(sema);
\t\t\tu32 ps5_diag_transitions = 0;
\t\t\tif (ps5_diag_watch)
\t\t\t{
\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WAIT begin addr=0x%x expected=0x%x initial=0x%x", addr, arg, ps5_diag_previous);
\t\t\t}
\t\t\tu64 start = get_system_time();''', 1)
    loop_anchor = 'while (sema != arg)\n\t\t\t{'
    if n.count(loop_anchor) != 1:
        raise SystemExit('[rsx-sema-diag] nv406e loop anchor not found')
    n = n.replace(loop_anchor, '''while (sema != arg)
\t\t\t{
\t\t\t\tif (ps5_diag_watch)
\t\t\t\t{
\t\t\t\t\tconst u32 value = static_cast<u32>(sema);
\t\t\t\t\tif (value != ps5_diag_previous)
\t\t\t\t\t{
\t\t\t\t\t\tif (ps5_diag_transitions++ < 64)
\t\t\t\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WAIT transition addr=0x%x old=0x%x new=0x%x expected=0x%x", addr, ps5_diag_previous, value, arg);
\t\t\t\t\t\tps5_diag_previous = value;
\t\t\t\t\t}
\t\t\t\t}''', 1)
    exit_anchor = 'RSX(ctx)->fifo_wake_delay();\n\t\t\tRSX(ctx)->performance_counters.idle_time'
    if n.count(exit_anchor) != 1:
        raise SystemExit('[rsx-sema-diag] nv406e exit anchor not found')
    n = n.replace(exit_anchor, '''if (ps5_diag_watch)
\t\t\t{
\t\t\t\trsx_log.trace("PS5-RSX-SEMA-DIAG v4 WAIT end addr=0x%x expected=0x%x final=0x%x transitions=%u", addr, arg, static_cast<u32>(sema), ps5_diag_transitions);
\t\t\t}
\t\t\tRSX(ctx)->fifo_wake_delay();
\t\t\tRSX(ctx)->performance_counters.idle_time''', 1)
    nv.write_text(n)
p.write_text(s)
print('[rsx-sema-diag] patched NV406E acquire/release handlers v4')
PY
