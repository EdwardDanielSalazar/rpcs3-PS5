#!/usr/bin/env bash
# Read-only diagnostics for cellGame content permission protocol.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root/src/rpcs3/rpcs3/Emu/Cell/Modules/cellGame.cpp" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
marker = "PS5-CELLGAME-DIAG"
if marker in s:
    print("[cellgame-diag] already patched")
    raise SystemExit(0)
pairs = [
(
'''\tauto init = acquire_lock(perm.init);

\tif (!init)
\t{
\t\tlv2_sleep(300);
\t\treturn CELL_GAME_ERROR_BUSY;
\t}''',
'''\tauto init = acquire_lock(perm.init);

\tif (!init)
\t{
\t\tcellGame.error("PS5-CELLGAME-DIAG DataCheck BUSY type=%u name='%s' (content_permission.init not acquired)", type, name);
\t\tlv2_sleep(300);
\t\treturn CELL_GAME_ERROR_BUSY;
\t}
\tcellGame.warning("PS5-CELLGAME-DIAG DataCheck LOCKED type=%u name='%s' dir='%s'", type, name, dir);'''
),
(
'''\tperm.dir = std::move(name);
\tperm.can_create = type == CELL_GAME_GAMETYPE_GAMEDATA;
\tperm.mode = content_permission::check_mode::game_data;''',
'''\tperm.dir = std::move(name);
\tperm.can_create = type == CELL_GAME_GAMETYPE_GAMEDATA;
\tperm.mode = content_permission::check_mode::game_data;
\tcellGame.warning("PS5-CELLGAME-DIAG DataCheck STATE type=%u dir='%s' sfo_empty=%u can_create=%u", type, dir, static_cast<unsigned>(sfo.empty()), static_cast<unsigned>(type == CELL_GAME_GAMETYPE_GAMEDATA));'''
),
(
'''\tconst auto init = acquire_reset_lock(perm.init);

\tif (!init)
\t{
\t\treturn CELL_GAME_ERROR_FAILURE;
\t}

\tconst std::string dir = perm.dir.empty()''',
'''\tconst auto init = acquire_reset_lock(perm.init);

\tif (!init)
\t{
\t\tcellGame.error("PS5-CELLGAME-DIAG ContentPermit FAILED to acquire reset lock");
\t\treturn CELL_GAME_ERROR_FAILURE;
\t}
\tcellGame.warning("PS5-CELLGAME-DIAG ContentPermit LOCKED dir='%s' temp='%s' exists=%u can_create=%u", perm.dir, perm.temp, static_cast<unsigned>(perm.exists.load()), static_cast<unsigned>(perm.can_create.load()));

\tconst std::string dir = perm.dir.empty()'''
),
(
'''\tstrcpy_trunc(*contentInfoPath, dir);
\tstrcpy_trunc(*usrdirPath, dir + "/USRDIR");
\treturn CELL_OK;''',
'''\tstrcpy_trunc(*contentInfoPath, dir);
\tstrcpy_trunc(*usrdirPath, dir + "/USRDIR");
\tcellGame.warning("PS5-CELLGAME-DIAG ContentPermit OK content='%s' usrdir='%s'", dir, dir + "/USRDIR");
\treturn CELL_OK;'''
)
]
for old, new in pairs:
    matches=s.count(old)
    if matches != 1:
        raise SystemExit(f"[cellgame-diag] anchor has {matches} matches, expected 1: {old[:70]!r}")
    s=s.replace(old,new,1)
p.write_text(s)
print("[cellgame-diag] installed read-only cellGame diagnostics")
PY
