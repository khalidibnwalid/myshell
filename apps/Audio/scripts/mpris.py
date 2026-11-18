#!/usr/bin/python3
# Publishes the Audio player on the session bus as an MPRIS player (org.mpris.MediaPlayer2, .Player and
# .TrackList), so the media card of Quick Settings, `playerctl` and the media keys see it like any other.
# The shell talks to it over stdin/stdout, one JSON object per line:
#   in:  {"state": {...}, "queue": [...]}   what the player is doing now (queue only when it changed)
#   out: {"cmd": "play" | "pause" | "next" | ..., ...}   what a client asked for
# Needs python-gobject (Gio) of the system Python.
import hashlib
import json
import os
import sys
import time

from gi.repository import Gio, GLib

NAME = "org.mpris.MediaPlayer2.quickshell_audio"
OBJ = "/org/mpris/MediaPlayer2"
ROOT = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
TRACKLIST = "org.mpris.MediaPlayer2.TrackList"
PROPS = "org.freedesktop.DBus.Properties"
NO_TRACK = "/org/mpris/MediaPlayer2/TrackList/NoTrack"

XML = """
<node>
  <interface name="org.mpris.MediaPlayer2">
    <method name="Raise"/>
    <method name="Quit"/>
    <property name="CanQuit" type="b" access="read"/>
    <property name="Fullscreen" type="b" access="readwrite"/>
    <property name="CanSetFullscreen" type="b" access="read"/>
    <property name="CanRaise" type="b" access="read"/>
    <property name="HasTrackList" type="b" access="read"/>
    <property name="Identity" type="s" access="read"/>
    <property name="DesktopEntry" type="s" access="read"/>
    <property name="SupportedUriSchemes" type="as" access="read"/>
    <property name="SupportedMimeTypes" type="as" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.Player">
    <method name="Next"/>
    <method name="Previous"/>
    <method name="Pause"/>
    <method name="PlayPause"/>
    <method name="Stop"/>
    <method name="Play"/>
    <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
    <method name="SetPosition">
      <arg direction="in" name="TrackId" type="o"/>
      <arg direction="in" name="Position" type="x"/>
    </method>
    <method name="OpenUri"><arg direction="in" name="Uri" type="s"/></method>
    <signal name="Seeked"><arg name="Position" type="x"/></signal>
    <property name="PlaybackStatus" type="s" access="read"/>
    <property name="LoopStatus" type="s" access="readwrite"/>
    <property name="Rate" type="d" access="readwrite"/>
    <property name="Shuffle" type="b" access="readwrite"/>
    <property name="Metadata" type="a{sv}" access="read"/>
    <property name="Volume" type="d" access="readwrite"/>
    <property name="Position" type="x" access="read"/>
    <property name="MinimumRate" type="d" access="read"/>
    <property name="MaximumRate" type="d" access="read"/>
    <property name="CanGoNext" type="b" access="read"/>
    <property name="CanGoPrevious" type="b" access="read"/>
    <property name="CanPlay" type="b" access="read"/>
    <property name="CanPause" type="b" access="read"/>
    <property name="CanSeek" type="b" access="read"/>
    <property name="CanControl" type="b" access="read"/>
  </interface>
  <interface name="org.mpris.MediaPlayer2.TrackList">
    <method name="GetTracksMetadata">
      <arg direction="in" name="TrackIds" type="ao"/>
      <arg direction="out" name="Metadata" type="aa{sv}"/>
    </method>
    <method name="AddTrack">
      <arg direction="in" name="Uri" type="s"/>
      <arg direction="in" name="AfterTrack" type="o"/>
      <arg direction="in" name="SetAsCurrent" type="b"/>
    </method>
    <method name="RemoveTrack"><arg direction="in" name="TrackId" type="o"/></method>
    <method name="GoTo"><arg direction="in" name="TrackId" type="o"/></method>
    <signal name="TrackListReplaced">
      <arg name="Tracks" type="ao"/>
      <arg name="CurrentTrack" type="o"/>
    </signal>
    <signal name="TrackAdded">
      <arg name="Metadata" type="a{sv}"/>
      <arg name="AfterTrack" type="o"/>
    </signal>
    <signal name="TrackRemoved"><arg name="TrackId" type="o"/></signal>
    <signal name="TrackMetadataChanged">
      <arg name="TrackId" type="o"/>
      <arg name="Metadata" type="a{sv}"/>
    </signal>
    <property name="Tracks" type="ao" access="read"/>
    <property name="CanEditTracks" type="b" access="read"/>
  </interface>
</node>
"""

LOOP_PROPS = ["PlaybackStatus", "LoopStatus", "Rate", "Shuffle", "Metadata", "Volume", "CanGoNext", "CanGoPrevious", "CanPlay", "CanPause", "CanSeek", "CanControl"]

V = GLib.Variant
conn = None
loop = GLib.MainLoop()
node = Gio.DBusNodeInfo.new_for_xml(XML)

state = {
    "status": "Stopped",
    "path": "",
    "index": -1,
    "pos": 0,
    "rate": 1.0,
    "volume": 1.0,
    "shuffle": False,
    "loop": "None",
    "canNext": False,
    "canPrev": False,
    "track": None,
}
queue = []
stamp = time.monotonic()
last = {}
last_tracks = None


def say(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def tid(i, path):
    return "/org/quickshell/audio/track/" + hashlib.md5(("%d:%s" % (i, path)).encode()).hexdigest()


def meta_of(t, track_id):
    m = {"mpris:trackid": V("o", track_id)}
    if not t:
        return m
    m["mpris:length"] = V("x", int(float(t.get("duration", 0)) * 1000000))
    if t.get("art"):
        m["mpris:artUrl"] = V("s", t["art"])
    m["xesam:url"] = V("s", t.get("url", ""))
    m["xesam:title"] = V("s", t.get("title", ""))
    if t.get("artist"):
        m["xesam:artist"] = V("as", [t["artist"]])
    if t.get("album"):
        m["xesam:album"] = V("s", t["album"])
    if t.get("albumArtist"):
        m["xesam:albumArtist"] = V("as", [t["albumArtist"]])
    if t.get("genre"):
        m["xesam:genre"] = V("as", [t["genre"]])
    if t.get("track"):
        m["xesam:trackNumber"] = V("i", int(t["track"]))
    if t.get("disc"):
        m["xesam:discNumber"] = V("i", int(t["disc"]))
    return m


def current_id():
    if state["index"] < 0 or not state["path"]:
        return NO_TRACK
    return tid(state["index"], state["path"])


def position_us():
    pos = float(state["pos"])
    if state["status"] == "Playing":
        pos += (time.monotonic() - stamp) * 1000.0 * float(state["rate"])
    return int(max(0, pos) * 1000)


def player_prop(name):
    s = state
    has = s["path"] != ""
    if name == "PlaybackStatus":
        return V("s", s["status"])
    if name == "LoopStatus":
        return V("s", s["loop"])
    if name == "Rate":
        return V("d", float(s["rate"]))
    if name == "Shuffle":
        return V("b", bool(s["shuffle"]))
    if name == "Metadata":
        return V("a{sv}", meta_of(s["track"], current_id()) if has else {"mpris:trackid": V("o", NO_TRACK)})
    if name == "Volume":
        return V("d", float(s["volume"]))
    if name == "Position":
        return V("x", position_us())
    if name == "MinimumRate":
        return V("d", 0.25)
    if name == "MaximumRate":
        return V("d", 4.0)
    if name == "CanGoNext":
        return V("b", bool(s["canNext"]))
    if name == "CanGoPrevious":
        return V("b", bool(s["canPrev"]))
    if name in ("CanPlay", "CanPause", "CanSeek"):
        return V("b", has)
    if name == "CanControl":
        return V("b", True)
    return None


def track_ids():
    return [tid(i, q["path"]) for i, q in enumerate(queue)]


def root_prop(name):
    table = {
        "CanQuit": V("b", True),
        "Fullscreen": V("b", False),
        "CanSetFullscreen": V("b", False),
        "CanRaise": V("b", True),
        "HasTrackList": V("b", True),
        "Identity": V("s", "Audio"),
        "DesktopEntry": V("s", "quickshell-audio"),
        "SupportedUriSchemes": V("as", ["file"]),
        "SupportedMimeTypes": V("as", ["audio/mpeg", "audio/flac", "audio/ogg", "audio/opus", "audio/mp4", "audio/x-wav", "audio/aac", "video/mp4", "video/x-matroska", "video/webm"]),
    }
    return table.get(name)


def tracklist_prop(name):
    if name == "Tracks":
        return V("ao", track_ids())
    if name == "CanEditTracks":
        return V("b", True)
    return None


def get_property(connection, sender, path, iface, name):
    if iface == ROOT:
        return root_prop(name)
    if iface == PLAYER:
        return player_prop(name)
    if iface == TRACKLIST:
        return tracklist_prop(name)
    return None


def set_property(connection, sender, path, iface, name, value):
    if iface == PLAYER:
        if name == "LoopStatus":
            say({"cmd": "loop", "v": value.get_string()})
        elif name == "Rate":
            say({"cmd": "rate", "v": value.get_double()})
        elif name == "Shuffle":
            say({"cmd": "shuffle", "v": value.get_boolean()})
        elif name == "Volume":
            say({"cmd": "volume", "v": value.get_double()})
        else:
            return False
        return True
    return False


def path_of(track_id):
    for i, q in enumerate(queue):
        if tid(i, q["path"]) == track_id:
            return i, q["path"]
    return -1, ""


def method_call(connection, sender, path, iface, method, params, inv):
    ok = None
    if iface == ROOT:
        if method == "Raise":
            say({"cmd": "raise"})
        elif method == "Quit":
            say({"cmd": "quit"})
    elif iface == PLAYER:
        if method in ("Next", "Previous", "Pause", "PlayPause", "Stop", "Play"):
            say({"cmd": method.lower()})
        elif method == "Seek":
            say({"cmd": "seek", "ms": params.unpack()[0] / 1000.0})
        elif method == "SetPosition":
            track_id, pos = params.unpack()
            if track_id == current_id():
                say({"cmd": "setposition", "ms": pos / 1000.0})
        elif method == "OpenUri":
            say({"cmd": "open", "uri": params.unpack()[0]})
    elif iface == TRACKLIST:
        if method == "GetTracksMetadata":
            ids = params.unpack()[0]
            out = []
            for track_id in ids:
                i, p = path_of(track_id)
                if i >= 0:
                    out.append(meta_of(queue[i], track_id))
            inv.return_value(V("(aa{sv})", (out,)))
            return
        if method == "AddTrack":
            uri, after, current = params.unpack()
            say({"cmd": "add", "uri": uri, "current": current})
        elif method == "RemoveTrack":
            i, p = path_of(params.unpack()[0])
            if i >= 0:
                say({"cmd": "remove", "index": i})
        elif method == "GoTo":
            i, p = path_of(params.unpack()[0])
            if i >= 0:
                say({"cmd": "goto", "index": i})
    inv.return_value(ok)


def emit_changed(iface, changed):
    if changed:
        conn.emit_signal(None, OBJ, PROPS, "PropertiesChanged", V("(sa{sv}as)", (iface, changed, [])))


def publish_player():
    global last
    changed = {}
    for name in LOOP_PROPS:
        v = player_prop(name)
        old = last.get(name)
        if old is None or not old.equal(v):
            changed[name] = v
            last[name] = v
    emit_changed(PLAYER, changed)


def publish_tracklist():
    global last_tracks
    ids = track_ids()
    if ids == last_tracks:
        return
    last_tracks = ids
    conn.emit_signal(None, OBJ, TRACKLIST, "TrackListReplaced", V("(aoo)", (ids, current_id())))
    emit_changed(TRACKLIST, {"Tracks": V("ao", ids)})


def apply(msg):
    global stamp, queue
    if "queue" in msg:
        queue = msg["queue"]
    s = msg.get("state")
    if s:
        before = position_us()
        state.update(s)
        stamp = time.monotonic()
        if s.get("seeked"):
            conn.emit_signal(None, OBJ, PLAYER, "Seeked", V("(x)", (position_us(),)))
    publish_tracklist()
    publish_player()


buffer = b""


def on_stdin(fd, cond):
    global buffer
    if cond & (GLib.IO_HUP | GLib.IO_ERR) and not cond & GLib.IO_IN:
        loop.quit()
        return False
    chunk = os.read(fd, 65536)
    if not chunk:
        loop.quit()
        return False
    buffer += chunk
    while b"\n" in buffer:
        line, buffer = buffer.split(b"\n", 1)
        if line.strip():
            try:
                apply(json.loads(line.decode("utf-8")))
            except Exception as e:
                sys.stderr.write("mpris: %s\n" % e)
    return True


def on_bus(connection, name):
    global conn
    conn = connection
    for iface in (ROOT, PLAYER, TRACKLIST):
        connection.register_object(OBJ, node.lookup_interface(iface), method_call, get_property, set_property)
    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    say({"cmd": "ready"})


def on_lost(connection, name):
    sys.stderr.write("mpris: lost the name %s\n" % name)
    loop.quit()


Gio.bus_own_name(Gio.BusType.SESSION, NAME, Gio.BusNameOwnerFlags.NONE, on_bus, None, on_lost)
loop.run()
