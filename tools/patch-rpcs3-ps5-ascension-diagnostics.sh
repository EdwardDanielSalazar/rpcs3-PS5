#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1])
p=root/'rpcs3/Emu/System.cpp'
s=p.read_text()
mark='PS5_CUSTOM_CONFIG_DIRECTORY_V1'
if mark not in s:
    needle='\t// Save config atomically\n\tfs::pending_file temp(config_name);'
    repl='''\t// PS5_CUSTOM_CONFIG_DIRECTORY_V1: custom_configs/ may not exist on a
\t// fresh PS5 installation. pending_file does not create parent folders.
\tconst std::string parent_dir = fs::get_parent_dir(config_name);
\tif (!fs::is_dir(parent_dir) && !fs::create_path(parent_dir))
\t{
\t\tsys_log.error("Could not create config directory %s (error=%s)", parent_dir, fs::g_tls_error);
\t\treturn;
\t}
\t// Save config atomically
\tfs::pending_file temp(config_name);'''
    if s.count(needle)!=1:raise SystemExit('SaveSettings anchor mismatch')
    s=s.replace(needle,repl,1)
    p.write_text(s)
    print('PS5 custom config directory creation patched')
else:print('PS5 custom config directory already patched')
p=root/'rpcs3/Emu/CPU/CPUThread.cpp'
s=p.read_text()
mark='PS5_ASCENSION_SCHEDULER_DIAGNOSTIC_V1'
if mark not in s:
    needle='''\tif (g_cfg.core.thread_scheduler != thread_scheduler_mode::os)
\t{
\t\tthread_ctrl::set_thread_affinity_mask(thread_ctrl::get_affinity_mask(get_class()));
\t}

\tensure(g_fxo->is_init<cpu_profiler>());'''
    repl='''\t// PS5_ASCENSION_SCHEDULER_DIAGNOSTIC_V1
\t// One log entry per emulated PPU/SPU thread (not per-frame):
\t// diagnose which emulation classes receive affinity restrictions.
\tconst auto affinity = thread_ctrl::get_affinity_mask(get_class());
\tif (g_cfg.core.thread_scheduler != thread_scheduler_mode::os)
\t{
\t\tthread_ctrl::set_thread_affinity_mask(affinity);
\t}
#if defined(__PROSPERO__)
\tif (get_class() == thread_class::ppu || get_class() == thread_class::spu)
\t{
\t\tsys_log.notice("PS5 scheduler diagnostic: thread=%s id=0x%08x class=%u scheduler=%s affinity=0x%llx", get_name(), id, static_cast<u32>(get_class()), g_cfg.core.thread_scheduler == thread_scheduler_mode::os ? "OS" : "RPCS3", static_cast<unsigned long long>(affinity));
\t}
#endif

\tensure(g_fxo->is_init<cpu_profiler>());'''
    if s.count(needle)!=1:raise SystemExit('CPU operator anchor mismatch')
    s=s.replace(needle,repl,1)
    p.write_text(s)
    print('PS5 scheduler startup diagnostics patched')
else:print('PS5 scheduler diagnostics already patched')
PY
