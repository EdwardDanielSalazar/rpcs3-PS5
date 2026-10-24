#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
base=root/'rpcs3/Emu/RSX/Overlays/HomeMenu'
h=base/'overlay_home_menu_settings.h'
c=base/'overlay_home_menu_settings.cpp'
hs=h.read_text()
cs=c.read_text()
marker='PS5_BOOT_SETTINGS_V1'
if marker in hs and marker in cs:
    print('PS5 boot settings already patched')
    sys.exit(0)
if marker in hs or marker in cs:
    raise SystemExit('partial PS5 boot settings patch; aborting')

# Extend the existing native overlay controls with labels for settings not localized upstream.
old='''\t\t\tvoid add_checkbox(cfg::_bool* setting, localized_string_id loc_id)
\t\t\t{
\t\t\t\tensure(setting && setting->get_is_dynamic());

\t\t\t\tconst std::string localized_text = get_localized_string(loc_id);'''
new='''\t\t\tvoid add_checkbox(cfg::_bool* setting, localized_string_id loc_id)
\t\t\t{
\t\t\t\tadd_checkbox(setting, get_localized_string(loc_id));
\t\t\t}

\t\t\tvoid add_checkbox(cfg::_bool* setting, const std::string& localized_text)
\t\t\t{
\t\t\t\tensure(setting);'''
if hs.count(old)!=1: raise SystemExit('checkbox helper layout changed; aborting')
hs=hs.replace(old,new)
old='''\t\t\ttemplate <typename T>
\t\t\tvoid add_dropdown(cfg::_enum<T>* setting, localized_string_id loc_id)
\t\t\t{
\t\t\t\tensure(setting && setting->get_is_dynamic());

\t\t\t\tconst std::string localized_text = get_localized_string(loc_id);'''
new='''\t\t\ttemplate <typename T>
\t\t\tvoid add_dropdown(cfg::_enum<T>* setting, localized_string_id loc_id)
\t\t\t{
\t\t\t\tadd_dropdown(setting, get_localized_string(loc_id));
\t\t\t}

\t\t\ttemplate <typename T>
\t\t\tvoid add_dropdown(cfg::_enum<T>* setting, const std::string& localized_text)
\t\t\t{
\t\t\t\tensure(setting);'''
if hs.count(old)!=1: raise SystemExit('dropdown helper layout changed; aborting')
hs=hs.replace(old,new)
# This class is only for the Big Picture shell (before running a game).
needle='''\t\tstruct home_menu_settings_audio : public home_menu_settings_page'''
replacement='''\t\t// PS5_BOOT_SETTINGS_V1: Cold-start options, edited before launching a game.
\t\tstruct home_menu_settings_ps5_boot : public home_menu_settings_page
\t\t{
\t\t\thome_menu_settings_ps5_boot(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent);
\t\t};

'''+needle
if hs.count(needle)!=1: raise SystemExit('settings header insertion changed')
hs=hs.replace(needle,replacement)

needle='''\t\t\tadd_page(home_menu::fa_icon::bug, std::make_shared<home_menu_settings_debug>(x, y, width, height, use_separators, nullptr));'''
replacement=needle+'''
\t\t\t// PS5_BOOT_SETTINGS_V1: use_separators=false is the PS5 Big Picture shell.
\t\t\t// Static options are deliberately not exposed in the in-game pause menu.
\t\t\tif (!use_separators)
\t\t\t{
\t\t\t\tadd_page(home_menu::fa_icon::settings, std::make_shared<home_menu_settings_ps5_boot>(x, y, width, height, use_separators, nullptr));
\t\t\t}'''
if cs.count(needle)!=1: raise SystemExit('settings cpp insertion changed')
cs=cs.replace(needle,replacement)
needle='''\t\thome_menu_settings_audio::home_menu_settings_audio('''
addition='''\t\t// PS5_BOOT_SETTINGS_V1. These options are persistent, but only take effect
\t\t// when the next game is booted. Do not edit them from a running game.
\t\thome_menu_settings_ps5_boot::home_menu_settings_ps5_boot(s16 x, s16 y, u16 width, u16 height, bool use_separators, home_menu_page* parent)
\t\t\t: home_menu_settings_page(x, y, width, height, use_separators, parent, "PS5 Boot (restart game)")
\t\t{
\t\t\tadd_dropdown(&g_cfg.core.spu_block_size, "SPU Block Size");
\t\t\tadd_checkbox(&g_cfg.core.spu_loop_detection, "SPU loop detection");
\t\t\tadd_dropdown(&g_cfg.core.rsx_fifo_accuracy, "RSX FIFO Fetch Accuracy");
\t\t\tadd_dropdown(&g_cfg.core.sleep_timers_accuracy, "Sleep Timers Accuracy");
\t\t\tadd_checkbox(&g_cfg.core.rsx_accurate_res_access, "Accurate RSX reservation access");
\t\t\tadd_checkbox(&g_cfg.video.vk.asynchronous_texture_streaming, "Asynchronous Texture Streaming");
\t\t\tadd_checkbox(&g_cfg.video.relaxed_zcull_sync, "Relaxed ZCULL Sync");
\t\t\tadd_dropdown(&g_cfg.video.antialiasing_level, "MSAA");
\t\t\tadd_checkbox(&g_cfg.video.disable_on_disk_shader_cache, "Disable On-Disk Shader Cache");
\t\t\tadd_unsigned_slider(&g_cfg.video.driver_wakeup_delay, localized_string_id::HOME_MENU_SETTINGS_ADVANCED_DRIVER_WAKE_UP_DELAY, " us", 10, {}, {}, 0, 800);
\t\t\tapply_layout();
\t\t}

'''+needle
if cs.count(needle)!=1: raise SystemExit('settings ctor insertion changed')
cs=cs.replace(needle,addition)
h.write_text(hs)
c.write_text(cs)
print('PS5 Boot menu patched: 10 controls, native save/discard, only in pre-boot Big Picture')
PY
