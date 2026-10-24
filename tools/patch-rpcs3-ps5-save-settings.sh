#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
base=root/'rpcs3/Emu/RSX/Overlays/HomeMenu'
p=base/'overlay_home_menu_settings.cpp'
s=p.read_text()
marker='PS5_SHARED_CONFIG_STATE_V1'
if marker in s:
    print('PS5 shared config state already patched')
    sys.exit(0)
needle='''\t\tvoid home_menu_settings::add_page(home_menu::fa_icon icon, std::shared_ptr<home_menu_page> page)
\t\t{
\t\t\tauto panel = std::static_pointer_cast<overlay_element>(page);'''
repl='''\t\tvoid home_menu_settings::add_page(home_menu::fa_icon icon, std::shared_ptr<home_menu_page> page)
\t\t{
\t\t\t// PS5_SHARED_CONFIG_STATE_V1: All settings tabs must share the dirty flag
\t\t\t// and confirmation dialog with the owner. Otherwise each tab tracks
\t\t\t// only its own changes and the main menu cannot save them together.
\t\t\tpage->m_config_changed = m_config_changed;
\t\t\tpage->m_message_box = m_message_box;
\t\t\tauto panel = std::static_pointer_cast<overlay_element>(page);'''
if s.count(needle)!=1:raise SystemExit('settings add_page anchor changed')
p.write_text(s.replace(needle,repl))
print('PS5 menu state shared across all tabs')
PY
