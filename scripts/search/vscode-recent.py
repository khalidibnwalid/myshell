#!/usr/bin/env python3
"""Launcher source: folders and workspaces recently opened in VS Code (or VSCodium).
usage: vscode-recent.py QUERY   prints  title<TAB>path<TAB>path  (at most 5 lines)"""
import json, os, sqlite3, sys, urllib.parse

query = (sys.argv[1] if len(sys.argv) > 1 else "").lower().split()
home = os.path.expanduser("~")
dbs = [f"{home}/.config/{d}/User/globalStorage/state.vscdb" for d in ("Code", "VSCodium", "Code - OSS")]
seen, out = set(), []

# current versions list every workspace they opened in storage.json, newest last
for d in ("Code", "VSCodium", "Code - OSS"):
    f = f"{home}/.config/{d}/User/globalStorage/storage.json"
    try:
        spaces = json.load(open(f)).get("profileAssociations", {}).get("workspaces", {})
    except Exception:
        continue
    for uri in reversed(list(spaces)):
        if not uri.startswith("file://"):
            continue
        p = urllib.parse.unquote(uri[7:])
        if p in seen or not os.path.exists(p):
            continue
        seen.add(p)
        if not query or all(q in p.lower() for q in query):
            out.append((os.path.basename(p.rstrip("/")), p))

# older versions keep the list in the state database
for db in dbs:
    if not os.path.exists(db):
        continue
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=1)
        row = con.execute("SELECT value FROM ItemTable WHERE key='history.recentlyOpenedPathsList'").fetchone()
        con.close()
        entries = json.loads(row[0]).get("entries", []) if row else []
    except Exception:
        continue
    for e in entries:
        uri = e.get("folderUri") or e.get("fileUri") or (e.get("workspace") or {}).get("configPath") or ""
        if not uri.startswith("file://"):
            continue
        p = urllib.parse.unquote(uri[7:])
        if p in seen or not os.path.exists(p):
            continue
        seen.add(p)
        if query and not all(q in p.lower() for q in query):
            continue
        out.append((os.path.basename(p.rstrip("/")), p))
for name, p in out[:5]:
    print(f"{name}\t{p.replace(home, '~')}\t{p}")
