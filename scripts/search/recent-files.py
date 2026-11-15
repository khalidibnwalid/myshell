#!/usr/bin/env python3
"""Launcher source: files you opened lately (the desktop's recent-files list).
usage: recent-files.py QUERY   prints  title<TAB>folder<TAB>path  (at most 5 lines)"""
import os, sys, urllib.parse, xml.etree.ElementTree as ET

query = (sys.argv[1] if len(sys.argv) > 1 else "").lower().split()
path = os.path.expanduser("~/.local/share/recently-used.xbel")
rows = []
try:
    for b in ET.parse(path).getroot().iter("bookmark"):
        href = b.get("href", "")
        if not href.startswith("file://"):
            continue
        p = urllib.parse.unquote(href[7:])
        name = os.path.basename(p)
        hay = p.lower()
        if query and not all(q in hay for q in query):
            continue
        if os.path.exists(p):
            rows.append((b.get("modified", ""), name, os.path.dirname(p).replace(os.path.expanduser("~"), "~"), p))
except Exception:
    pass
for _, name, folder, p in sorted(rows, reverse=True)[:5]:
    print(f"{name}\t{folder}\t{p}")
