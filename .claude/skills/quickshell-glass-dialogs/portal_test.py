# Opens a portal file dialog and stays connected until the dialog is answered (or 40 s).
# usage: portal_test.py open|save|dir [multiple] [folder=/path]
import sys
from gi.repository import Gio, GLib

mode = sys.argv[1] if len(sys.argv) > 1 else "open"
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()
opts = {}
method = "OpenFile"
if mode == "save":
    method = "SaveFile"
    opts["current_name"] = GLib.Variant("s", "notes.txt")
elif mode == "dir":
    opts["directory"] = GLib.Variant("b", True)
for a in sys.argv:
    if a.startswith("folder="):
        opts["current_folder"] = GLib.Variant("ay", a[7:].encode() + b"\0")
if "multiple" in sys.argv:
    opts["multiple"] = GLib.Variant("b", True)
if mode == "open":
    opts["filters"] = GLib.Variant("a(sa(us))", [("Images", [(0, "*.png"), (0, "*.jpg")]), ("All files", [(0, "*")])])

def on_response(conn, sender, path, iface, name, params, data):
    code, results = params.unpack()
    print("RESPONSE", code, results, flush=True)
    loop.quit()

token = "qstest"
sender = bus.get_unique_name().lstrip(":").replace(".", "_")
req = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response", req, None, Gio.DBusSignalFlags.NONE, on_response, None)
opts["handle_token"] = GLib.Variant("s", token)
bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop", "org.freedesktop.portal.FileChooser", method,
              GLib.Variant("(ssa{sv})", ("", "Quickshell test", opts)), None, Gio.DBusCallFlags.NONE, -1, None)
print("asked", flush=True)
GLib.timeout_add_seconds(40, loop.quit)
loop.run()
