#!/usr/bin/env bash
# On PS5, the host process affinity may be reported as zero.
# Never pass an empty cpu_set_t to pthread_setaffinity_np (EINVAL/ERANGE).
# This is a safe fallback to OS scheduling, not an affinity optimization.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
file="$root/src/rpcs3/Utilities/Thread.cpp"
python3 - "$file" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
marker = 'PS5_EMPTY_AFFINITY_FALLBACK_V1'
if marker in s:
    print('[ps5-affinity] already applied')
    raise SystemExit(0)
old = '''\tif (!mask)
\t{
\t\t// Reset affinity mask
\t\tmask = process_affinity_mask;
\t}

\tcpu_set_t cs;'''
new = '''\tif (!mask)
\t{
\t\t// Reset affinity mask
\t\tmask = process_affinity_mask;
\t}

\t// PS5_EMPTY_AFFINITY_FALLBACK_V1: leave host scheduling unchanged
\t// when the process affinity was not provided by this platform.
\tif (!mask)
\t{
\t\treturn;
\t}

\tcpu_set_t cs;'''
if s.count(old) != 1:
    raise SystemExit('[ps5-affinity] expected POSIX affinity anchor absent; refusing edit')
p.write_text(s.replace(old, new, 1))
print('[ps5-affinity] skip zero effective CPU masks; keep normal masks unchanged')
PY
