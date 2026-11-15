#!/usr/bin/env python3
"""Launcher source: pages from the history of a Chromium based browser (Helium, Chrome,
Chromium, Brave, Edge). The history file is copied first, as the browser keeps it locked.
usage: browser-history.py QUERY   prints  title<TAB>address<TAB>address  (at most 5 lines)"""
import os, shutil, sqlite3, sys, tempfile

query = (sys.argv[1] if len(sys.argv) > 1 else "").lower().split()
if not query:
    sys.exit(0)
home = os.path.expanduser("~")
cfg = os.environ.get("XDG_CONFIG_HOME", f"{home}/.config")
candidates = ["net.imput.helium", "google-chrome", "chromium", "BraveSoftware/Brave-Browser", "microsoft-edge"]
want = os.environ.get("QS_BROWSER_CLASS", "").lower()
candidates.sort(key=lambda d: 0 if want and want in d.lower() else 1)
db = next((f"{cfg}/{d}/Default/History" for d in candidates if os.path.exists(f"{cfg}/{d}/Default/History")), None)
if not db:
    sys.exit(0)
tmp = tempfile.mktemp(suffix=".sqlite")
try:
    shutil.copyfile(db, tmp)
    con = sqlite3.connect(tmp)
    where = " AND ".join(["(lower(title) LIKE ? OR lower(url) LIKE ?)"] * len(query))
    args = [x for q in query for x in (f"%{q}%", f"%{q}%")]
    rows = con.execute(f"SELECT title, url FROM urls WHERE {where} ORDER BY (visit_count * 2 + typed_count * 8) DESC, last_visit_time DESC LIMIT 5", args).fetchall()
    for title, url in rows:
        print(f"{(title or url).replace(chr(9), ' ')}\t{url.replace(chr(9), '')[:80]}\t{url}")
except Exception:
    pass
finally:
    try:
        os.remove(tmp)
    except OSError:
        pass
