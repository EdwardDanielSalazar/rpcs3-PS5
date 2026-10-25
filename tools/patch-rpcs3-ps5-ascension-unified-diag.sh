#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'rpcs3/Emu/System.cpp'
s=p.read_text()
marker='PS5_ASCENSION_UNIFIED_DIAG_V1'
if marker not in s:
    anchor='''	// Reset defaults, cache them
	g_cfg_vfs.from_default();
	g_cfg.from_default();
	g_cfg.name.clear();'''
    replacement='''	// PS5_ASCENSION_UNIFIED_DIAG_V1: count emulator initialization cycles.
	// The counter survives game Reset but not a process restart.
	static u32 ps5_init_cycle = 0;
	++ps5_init_cycle;
	sys_log.notice("PS5-ASCENSION BOOT stage=defaults cycle=%u cfg_mode=%s", ps5_init_cycle, m_config_mode);
	// Reset defaults, cache them
	g_cfg_vfs.from_default();
	g_cfg.from_default();
	g_cfg.name.clear();'''
    if s.count(anchor)!=1: raise SystemExit('System defaults anchor mismatch')
    s=s.replace(anchor,replacement,1)
    anchor='''	// Disable incompatible settings
	fixup_settings(nullptr);

	// Backup config'''
    replacement='''	// PS5_ASCENSION_UNIFIED_DIAG_V1
	sys_log.notice("PS5-ASCENSION BOOT stage=global cycle=%u config=%s", ps5_init_cycle, g_cfg.name);
	// Disable incompatible settings
	fixup_settings(nullptr);

	// Backup config'''
    if s.count(anchor)!=1: raise SystemExit('System global anchor mismatch')
    s=s.replace(anchor,replacement,1)
    anchor='''			// Backup config
			g_backup_cfg.from_string(g_cfg.to_string());'''
    replacement='''			// PS5_ASCENSION_UNIFIED_DIAG_V1: final merged game config, after fixup.
			if (m_title_id == "BCES01741")
			{
				static u32 ps5_ascension_game_boot = 0;
				++ps5_ascension_game_boot;
				sys_log.notice("PS5-ASCENSION BOOT stage=game attempt=%u mode=%s custom=%s", ps5_ascension_game_boot, m_config_mode, g_cfg.name);
			}
			// Backup config
			g_backup_cfg.from_string(g_cfg.to_string());'''
    if s.count(anchor)!=1: raise SystemExit('System game anchor mismatch')
    s=s.replace(anchor,replacement,1)
    p.write_text(s)
    print('Installed unified PS5 Ascension boot lifecycle diagnostics')
else:
    print('Boot lifecycle diagnostics already installed')
p=root/'rpcs3/Emu/Cell/PPUThread.cpp'
s=p.read_text()
mark='PS5_ASCENSION_PPU_NULL_DIAG_V1'
if mark not in s:
    anchor='''void ppu_thread::dump_regs(std::string& ret, std::any& custom_data) const
{
	const system_state emu_state = Emu.GetStatus(false);'''
    replacement='''void ppu_thread::dump_regs(std::string& ret, std::any& custom_data) const
{
	// PS5_ASCENSION_PPU_NULL_DIAG_V1: only when a debugger/crash already
	// requests a register dump. Does not poll the hot LLVM execution path.
	if (cia == 0x001f6b54 && gpr[30] == 0)
	{
		fmt::append(ret, "PS5-ASCENSION PPU-NULL cia=0x%08x r3=0x%llx r28=0x%llx r29=0x%llx r30=0x%llx lr=0x%llx\\n",
			cia, gpr[3], gpr[28], gpr[29], gpr[30], lr);
	}
	const system_state emu_state = Emu.GetStatus(false);'''
    if s.count(anchor)!=1: raise SystemExit('PPU dump anchor mismatch')
    s=s.replace(anchor,replacement,1)
    p.write_text(s)
    print('Installed targeted PPU null crash dump marker')
else:
    print('PPU null dump diagnostics already installed')

p=root/'rpcs3/Emu/Cell/PPUThread.cpp'
s=p.read_text()
if 'PS5_ASCENSION_RETURN_TRACE_V1' not in s:
    anchor='''static void ppu_trace(u64 addr)
{
	ppu_log.notice("Trace: 0x%llx", addr);
}'''
    replacement=anchor+'''

// PS5_ASCENSION_RETURN_TRACE_V1: called only from four targeted guest PCs.
// Pure observer: no register or guest memory modifications.
static void ps5_ascension_return_trace(u64 pc, u64 r3, u64 r28, u64 r30)
{
	static atomic_t<u32> total{0};
	static atomic_t<u32> zero_count{0};
	const u32 seq = ++total;
	const bool zero = r3 == 0;
	const u32 zseq = zero ? ++zero_count : 0;
	if (seq <= 24 || (zero && zseq <= 48))
	{
		ppu_log.notice("PS5-ASCENSION RETURN pc=0x%08llx r3=0x%llx r28=0x%llx r30=0x%llx seq=%u null_seq=%u", pc, r3, r28, r30, seq, zseq);
	}
}'''
    if s.count(anchor)!=1: raise SystemExit('PPU helper anchor mismatch')
    s=s.replace(anchor,replacement,1)
    anchor='''{ "__trace", reinterpret_cast<u64>(&ppu_trace) },'''
    replacement=anchor+'''
			{ "__ps5_ascension_return_trace", reinterpret_cast<u64>(&ps5_ascension_return_trace) },'''
    if s.count(anchor)!=1: raise SystemExit('PPU symbol anchor mismatch')
    s=s.replace(anchor,replacement,1)
    p.write_text(s)
    print('Installed native PPU return tracing helper')
else: print('Native trace helper already installed')
p=root/'rpcs3/Emu/Cell/PPUTranslator.cpp'
s=p.read_text()
if 'PS5_ASCENSION_TARGETED_RETURN_TRACE_V1' not in s:
    anchor='''			const u32 op = *ensure(m_info.get_ptr<u32>(::narrow<u32>(m_addr + base)));

			(this->*(s_ppu_decoder.decode(op)))({op});'''
    replacement='''			const u32 op = *ensure(m_info.get_ptr<u32>(::narrow<u32>(m_addr + base)));

			// PS5_ASCENSION_TARGETED_RETURN_TRACE_V1:
			// Capture values before calls and just after their returns.
			// The two return PCs record r3 before the guest copies it to r30.
			if (m_addr + base == 0x001f6b04 || m_addr + base == 0x001f6b0c ||
				m_addr + base == 0x001f6b2c || m_addr + base == 0x001f6b30)
			{
				Call(GetType<void>(), "__ps5_ascension_return_trace",
					GetAddr(), GetGpr(3), GetGpr(28), GetGpr(30));
			}

			(this->*(s_ppu_decoder.decode(op)))({op});'''
    if s.count(anchor)!=1: raise SystemExit('Translator loop anchor mismatch')
    s=s.replace(anchor,replacement,1)
    p.write_text(s)
    print('Installed targeted PPU LLVM return trace calls')
else: print('LLVM return trace already installed')
PY
