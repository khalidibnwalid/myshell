#!/usr/bin/env python3
# Installs the icon and the desktop entry of every app in apps/*/app.json, and removes the entry of the
# ones that are switched off. Standard library only.
# usage: install-apps.py SHELL_DIR [DISABLED_ID]...
import glob
import json
import os
import shutil
import subprocess
import sys


def main():
    shell = sys.argv[1]
    disabled = set(sys.argv[2:])
    data = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    icons = os.path.join(data, "icons/hicolor/scalable/apps")
    entries = os.path.join(data, "applications")
    os.makedirs(icons, exist_ok=True)
    os.makedirs(entries, exist_ok=True)
    icon_changed = False
    mime_changed = False

    for path in sorted(glob.glob(os.path.join(shell, "apps/*/app.json"))):
        folder = os.path.dirname(path)
        try:
            with open(path, encoding="utf-8") as f:
                m = json.load(f)
            app = m["id"]
            name = m["name"]
        except (OSError, ValueError, KeyError):
            continue
        entry = os.path.join(entries, "quickshell-%s.desktop" % app)
        if app in disabled:
            if os.path.exists(entry):
                os.remove(entry)
                mime_changed = True
            continue

        svg = os.path.join(folder, m.get("icon", ""))
        target = os.path.join(icons, "quickshell-%s.svg" % app)
        if os.path.isfile(svg):
            same = os.path.isfile(target) and open(svg, "rb").read() == open(target, "rb").read()
            if not same:
                shutil.copyfile(svg, target)
                icon_changed = True

        if m.get("open"):
            exec_line = '"%s" %%F' % os.path.join(folder, m["open"])
        else:
            exec_line = "qs ipc call %s open" % m.get("ipc", app)
        lines = [
            "[Desktop Entry]",
            "Version=1.5",
            "Type=Application",
            "Name=%s" % name,
            "Comment=%s" % m.get("description", ""),
            "Exec=%s" % exec_line,
            "Icon=quickshell-%s" % app,
            "Categories=%s" % m.get("categories", "Utility;"),
        ]
        if m.get("mime"):
            lines.append("MimeType=%s;" % ";".join(m["mime"]))
        if m.get("desktopKeywords"):
            lines.append("Keywords=%s" % m["desktopKeywords"])
        lines.append("Terminal=false")
        want = "\n".join(lines) + "\n"
        have = None
        if os.path.isfile(entry):
            with open(entry, encoding="utf-8") as f:
                have = f.read()
        if have != want:
            with open(entry, "w", encoding="utf-8") as f:
                f.write(want)
            if m.get("mime"):
                mime_changed = True

    hicolor = os.path.join(data, "icons/hicolor")
    if icon_changed and shutil.which("gtk-update-icon-cache"):
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", hicolor], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if icon_changed:
        os.utime(hicolor, None)
    # so the system lists the apps that open audio files (Settings → Default apps)
    if mime_changed and shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", entries], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


main()
