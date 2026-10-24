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
PY
