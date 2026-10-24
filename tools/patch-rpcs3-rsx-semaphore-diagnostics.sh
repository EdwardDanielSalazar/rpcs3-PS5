#!/usr/bin/env bash
# PS5 performance build: keep upstream NV406E semaphore code unmodified.
# The former v4 instrumentation logged every watched acquire/release and
# successful wait. Upstream checks and timeout reporting remain untouched.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$root/src/rpcs3/rpcs3/Emu/RSX/rsx_methods.cpp"
wait_file="$root/src/rpcs3/rpcs3/Emu/RSX/NV47/HW/nv406e.cpp"
python3 - "$source_file" "$wait_file" <<'PY'
from pathlib import Path
import sys
methods = Path(sys.argv[1])
wait = Path(sys.argv[2])
m = methods.read_text()
w = wait.read_text()
hooks = (
    "bind(NV406E_SEMAPHORE_ACQUIRE, nv406e::semaphore_acquire);",
    "bind(NV406E_SEMAPHORE_RELEASE, nv406e::semaphore_release);",
)
if any(m.count(hook) != 1 for hook in hooks):
    raise SystemExit("[rsx-perf] native NV406E hooks missing; refusing unsafe build")
if "PS5-RSX-SEMA-DIAG" in m or "PS5-RSX-SEMA-DIAG" in w:
    raise SystemExit("[rsx-perf] previously instrumented source found; use a clean checkout")
if "semaphore_acquire" not in w or "timed out" not in w:
    raise SystemExit("[rsx-perf] original semaphore wait/timeout path not found")
print("[rsx-perf] no per-operation RSX tracing; native semaphore checks and timeouts retained")
PY
