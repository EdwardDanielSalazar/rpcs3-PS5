#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])/'rpcs3/Emu/RSX/Overlays/BigPicture/overlay_big_picture.cpp'
s=p.read_text()
mark='PS5_BIG_PICTURE_SAVE_ON_BOOT_V1'
if mark in s:
    print('PS5 Big Picture save-on-boot already installed')
    sys.exit(0)
old='#include "Emu/System.h"'
new=old+'\n#include "Emu/system_config.h"'
if s.count(old)!=1:raise SystemExit('System header anchor changed')
s=s.replace(old,new,1)
old='''\t\t\t\t\t// Keep the game window alive across the handoff instead of closing and reopening it.
\t\t\t\t\tEmu.SetContinuousMode(true);'''
new='''\t\t\t\t\t// PS5_BIG_PICTURE_SAVE_ON_BOOT_V1
\t\t\t\t\t// Pre-boot options include non-dynamic emulation settings. Persist pending
\t\t\t\t\t// changes before the BPM shell is torn down, even when Square/Confirm
\t\t\t\t\t// was not used. This does not affect in-game pause settings.
\t\t\t\t\tif (g_cfg.to_string() != g_backup_cfg.to_string())
\t\t\t\t\t{
\t\t\t\t\t\trsx_log.notice("Big Picture Mode: saving pending settings to global config before boot");
\t\t\t\t\t\tEmulator::SaveSettings(g_cfg.to_string(), "");
\t\t\t\t\t}
\t\t\t\t\t// Keep the game window alive across the handoff instead of closing and reopening it.
\t\t\t\t\tEmu.SetContinuousMode(true);'''
if s.count(old)!=1:raise SystemExit('Big Picture launch anchor changed')
s=s.replace(old,new,1)
p.write_text(s)
print('PS5 Big Picture pending settings are saved before game handoff')
PY
