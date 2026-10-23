#!/usr/bin/env bash
# PS5-only RPCS3 RNG fix. The PS5 title's filesystem does not reliably
# provide a readable /dev/urandom; use the BSD libc random-byte API instead.
# Idempotent: designed for the pinned src/rpcs3 submodule checkout.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
file="$root/src/rpcs3/rpcs3/Emu/Cell/lv2/sys_ss.cpp"
[[ -f $file ]] || { echo "RPCS3 source missing: $file" >&2; exit 1; }
python3 - "$file" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''#else
\tfs::file rnd{"/dev/urandom"};

\tif (!rnd || rnd.read(temp.get(), size) != size)
\t{
\t\tfmt::throw_exception("sys_ss_random_number_generator(): Failed to generate pseudo-random numbers");
\t}
#endif'''
new = '''#elif defined(RPCS3_PS5_RNG)
\t// On the PS5 native title, /dev/urandom may not be accessible via fs::file.
\t// arc4random_buf is provided by the FreeBSD-derived target C library.
\tarc4random_buf(temp.get(), static_cast<size_t>(size));
#else
\tfs::file rnd{"/dev/urandom"};

\tif (!rnd || rnd.read(temp.get(), size) != size)
\t{
\t\tfmt::throw_exception("sys_ss_random_number_generator(): Failed to generate pseudo-random numbers");
\t}
#endif'''
if new in s:
    print("==> [rpcs3] RNG patch already applied")
elif s.count(old) == 1:
    s = s.replace(old,new)
    if '#include <stdlib.h>' not in s:
        s = '#include <stdlib.h>\n' + s
    p.write_text(s)
    print("==> [rpcs3] patched sys_ss RNG for PS5")
else:
    raise SystemExit("RNG patch: expected source not found; upstream changed. Refusing unsafe patch.")
PY
