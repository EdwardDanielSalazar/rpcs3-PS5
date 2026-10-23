#!/usr/bin/env bash
# Temporary XMB diagnostic instrumentation. No syscall return values or
# emulated filesystem/storage behavior are changed.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3/rpcs3/Emu/Cell/lv2/sys_storage.cpp" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
old='''	if (auto q = manager.asyncequeue.load())
	{
		q->send(0, unk, unk, unk);
	}

	return CELL_OK;'''
new='''	if (auto q = manager.asyncequeue.load())
	{
		sys_storage.warning("PS5-XMB-DIAG async command cmd=0x%llx dev_handle=0x%x event_queue=present inlen=0x%llx outlen=0x%llx", cmd, dev_handle, inlen, outlen);
		q->send(0, unk, unk, unk);
	}
	else
	{
		sys_storage.warning("PS5-XMB-DIAG async command cmd=0x%llx dev_handle=0x%x event_queue=MISSING inlen=0x%llx outlen=0x%llx", cmd, dev_handle, inlen, outlen);
	}

	return CELL_OK;'''
if new in s:
    print("XMB async storage diagnostic already installed")
elif s.count(old)==1:
    p.write_text(s.replace(old,new))
    print("XMB async storage diagnostic installed")
else:
    raise SystemExit("Unexpected sys_storage.cpp; refusing patch")
PY
