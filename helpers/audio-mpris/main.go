// Publishes the Audio player on the session bus as an MPRIS player (org.mpris.MediaPlayer2, .Player and
// .TrackList), so the media card of Quick Settings, `playerctl` and the media keys see it like any other.
// The shell talks to it over stdin/stdout, one JSON object per line:
//
//	in:  {"state": {...}, "queue": [...]}   what the player is doing now (queue only when it changed)
//	out: {"cmd": "play" | "pause" | "next" | ..., ...}   what a client asked for
package main

import (
	"bufio"
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
	"github.com/godbus/dbus/v5/introspect"
)

const (
	busName   = "org.mpris.MediaPlayer2.quickshell_audio"
	objPath   = dbus.ObjectPath("/org/mpris/MediaPlayer2")
	ifRoot    = "org.mpris.MediaPlayer2"
	ifPlayer  = "org.mpris.MediaPlayer2.Player"
	ifTracks  = "org.mpris.MediaPlayer2.TrackList"
	ifProps   = "org.freedesktop.DBus.Properties"
	noTrack   = dbus.ObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack")
	trackBase = "/org/quickshell/audio/track/"
)

const introXML = `<node>
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect"><arg direction="out" type="s"/></method>
  </interface>
  <interface name="org.freedesktop.DBus.Properties">
    <method name="Get"><arg direction="in" type="s"/><arg direction="in" type="s"/><arg direction="out" type="v"/></method>
    <method name="GetAll"><arg direction="in" type="s"/><arg direction="out" type="a{sv}"/></method>
    <method name="Set"><arg direction="in" type="s"/><arg direction="in" type="s"/><arg direction="in" type="v"/></method>
    <signal name="PropertiesChanged"><arg type="s"/><arg type="a{sv}"/><arg type="as"/></signal>
  </interface>
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
</node>`

var (
	playerProps = []string{"PlaybackStatus", "LoopStatus", "Rate", "Shuffle", "Metadata", "Volume", "Position", "MinimumRate", "MaximumRate", "CanGoNext", "CanGoPrevious", "CanPlay", "CanPause", "CanSeek", "CanControl"}
	// the ones that are announced when they change (Position is only read, and told by Seeked)
	watchedProps = []string{"PlaybackStatus", "LoopStatus", "Rate", "Shuffle", "Metadata", "Volume", "CanGoNext", "CanGoPrevious", "CanPlay", "CanPause", "CanSeek", "CanControl"}
	rootProps    = []string{"CanQuit", "Fullscreen", "CanSetFullscreen", "CanRaise", "HasTrackList", "Identity", "DesktopEntry", "SupportedUriSchemes", "SupportedMimeTypes"}
)

// a track as the shell sends it; the numbers may come as text
type track struct {
	Path        string `json:"path"`
	Title       string `json:"title"`
	Artist      string `json:"artist"`
	Album       string `json:"album"`
	AlbumArtist string `json:"albumArtist"`
	Genre       string `json:"genre"`
	Track       any    `json:"track"`
	Disc        any    `json:"disc"`
	Duration    any    `json:"duration"`
	URL         string `json:"url"`
	Art         string `json:"art"`
}

type state struct {
	Status  string  `json:"status"`
	Path    string  `json:"path"`
	Index   int     `json:"index"`
	Pos     float64 `json:"pos"`
	Rate    float64 `json:"rate"`
	Volume  float64 `json:"volume"`
	Shuffle bool    `json:"shuffle"`
	Loop    string  `json:"loop"`
	CanNext bool    `json:"canNext"`
	CanPrev bool    `json:"canPrev"`
	Track   *track  `json:"track"`
	Seeked  bool    `json:"seeked"`
}

type message struct {
	State *state  `json:"state"`
	Queue []track `json:"queue"`
}

var (
	mu         sync.Mutex
	conn       *dbus.Conn
	st         = state{Status: "Stopped", Index: -1, Rate: 1, Volume: 1, Loop: "None"}
	queue      []track
	stamp      = time.Now()
	last       = map[string]dbus.Variant{}
	lastTracks []dbus.ObjectPath
	outMu      sync.Mutex
	out        = json.NewEncoder(os.Stdout)
)

func say(obj map[string]any) {
	outMu.Lock()
	defer outMu.Unlock()
	_ = out.Encode(obj)
}

func num(v any) float64 {
	switch n := v.(type) {
	case float64:
		return n
	case string:
		f, _ := strconv.ParseFloat(strings.TrimSpace(n), 64)
		return f
	}
	return 0
}

// "3" and "3/12" both give 3
func whole(v any) int32 {
	if s, ok := v.(string); ok {
		if i := strings.IndexAny(s, "/ "); i >= 0 {
			s = s[:i]
		}
		v = s
	}
	return int32(num(v))
}

func tid(i int, path string) dbus.ObjectPath {
	sum := md5.Sum([]byte(fmt.Sprintf("%d:%s", i, path)))
	return dbus.ObjectPath(trackBase + hex.EncodeToString(sum[:]))
}

func metaOf(t *track, id dbus.ObjectPath) map[string]dbus.Variant {
	m := map[string]dbus.Variant{"mpris:trackid": dbus.MakeVariant(id)}
	if t == nil {
		return m
	}
	m["mpris:length"] = dbus.MakeVariant(int64(num(t.Duration) * 1e6))
	if t.Art != "" {
		m["mpris:artUrl"] = dbus.MakeVariant(t.Art)
	}
	m["xesam:url"] = dbus.MakeVariant(t.URL)
	m["xesam:title"] = dbus.MakeVariant(t.Title)
	if t.Artist != "" {
		m["xesam:artist"] = dbus.MakeVariant([]string{t.Artist})
	}
	if t.Album != "" {
		m["xesam:album"] = dbus.MakeVariant(t.Album)
	}
	if t.AlbumArtist != "" {
		m["xesam:albumArtist"] = dbus.MakeVariant([]string{t.AlbumArtist})
	}
	if t.Genre != "" {
		m["xesam:genre"] = dbus.MakeVariant([]string{t.Genre})
	}
	if n := whole(t.Track); n != 0 {
		m["xesam:trackNumber"] = dbus.MakeVariant(n)
	}
	if n := whole(t.Disc); n != 0 {
		m["xesam:discNumber"] = dbus.MakeVariant(n)
	}
	return m
}

func currentID() dbus.ObjectPath {
	if st.Index < 0 || st.Path == "" {
		return noTrack
	}
	return tid(st.Index, st.Path)
}

func positionUs() int64 {
	pos := st.Pos
	if st.Status == "Playing" {
		pos += float64(time.Since(stamp).Milliseconds()) * st.Rate
	}
	if pos < 0 {
		pos = 0
	}
	return int64(pos * 1000)
}

func trackIDs() []dbus.ObjectPath {
	ids := make([]dbus.ObjectPath, len(queue))
	for i := range queue {
		ids[i] = tid(i, queue[i].Path)
	}
	return ids
}

func playerProp(name string) (dbus.Variant, bool) {
	has := st.Path != ""
	switch name {
	case "PlaybackStatus":
		return dbus.MakeVariant(st.Status), true
	case "LoopStatus":
		return dbus.MakeVariant(st.Loop), true
	case "Rate":
		return dbus.MakeVariant(st.Rate), true
	case "Shuffle":
		return dbus.MakeVariant(st.Shuffle), true
	case "Metadata":
		if !has {
			return dbus.MakeVariant(map[string]dbus.Variant{"mpris:trackid": dbus.MakeVariant(noTrack)}), true
		}
		return dbus.MakeVariant(metaOf(st.Track, currentID())), true
	case "Volume":
		return dbus.MakeVariant(st.Volume), true
	case "Position":
		return dbus.MakeVariant(positionUs()), true
	case "MinimumRate":
		return dbus.MakeVariant(0.25), true
	case "MaximumRate":
		return dbus.MakeVariant(4.0), true
	case "CanGoNext":
		return dbus.MakeVariant(st.CanNext), true
	case "CanGoPrevious":
		return dbus.MakeVariant(st.CanPrev), true
	case "CanPlay", "CanPause", "CanSeek":
		return dbus.MakeVariant(has), true
	case "CanControl":
		return dbus.MakeVariant(true), true
	}
	return dbus.Variant{}, false
}

func rootProp(name string) (dbus.Variant, bool) {
	switch name {
	case "CanQuit", "CanRaise", "HasTrackList":
		return dbus.MakeVariant(true), true
	case "Fullscreen", "CanSetFullscreen":
		return dbus.MakeVariant(false), true
	case "Identity":
		return dbus.MakeVariant("Audio"), true
	case "DesktopEntry":
		return dbus.MakeVariant("quickshell-audio"), true
	case "SupportedUriSchemes":
		return dbus.MakeVariant([]string{"file"}), true
	case "SupportedMimeTypes":
		return dbus.MakeVariant([]string{"audio/mpeg", "audio/flac", "audio/ogg", "audio/opus", "audio/mp4", "audio/x-wav", "audio/aac", "video/mp4", "video/x-matroska", "video/webm"}), true
	}
	return dbus.Variant{}, false
}

func tracksProp(name string) (dbus.Variant, bool) {
	switch name {
	case "Tracks":
		return dbus.MakeVariant(trackIDs()), true
	case "CanEditTracks":
		return dbus.MakeVariant(true), true
	}
	return dbus.Variant{}, false
}

func lookup(iface, name string) (dbus.Variant, bool) {
	switch iface {
	case ifRoot:
		return rootProp(name)
	case ifPlayer:
		return playerProp(name)
	case ifTracks:
		return tracksProp(name)
	}
	return dbus.Variant{}, false
}

func namesOf(iface string) []string {
	switch iface {
	case ifRoot:
		return rootProps
	case ifPlayer:
		return playerProps
	case ifTracks:
		return []string{"Tracks", "CanEditTracks"}
	}
	return nil
}

func pathOf(id dbus.ObjectPath) (int, bool) {
	for i := range queue {
		if tid(i, queue[i].Path) == id {
			return i, true
		}
	}
	return -1, false
}

// org.freedesktop.DBus.Properties
type props struct{}

func (props) Get(iface, name string) (dbus.Variant, *dbus.Error) {
	mu.Lock()
	defer mu.Unlock()
	if v, ok := lookup(iface, name); ok {
		return v, nil
	}
	return dbus.Variant{}, dbus.MakeFailedError(fmt.Errorf("no property %s.%s", iface, name))
}

func (props) GetAll(iface string) (map[string]dbus.Variant, *dbus.Error) {
	mu.Lock()
	defer mu.Unlock()
	all := map[string]dbus.Variant{}
	for _, n := range namesOf(iface) {
		if v, ok := lookup(iface, n); ok {
			all[n] = v
		}
	}
	return all, nil
}

func (props) Set(iface, name string, value dbus.Variant) *dbus.Error {
	if iface != ifPlayer {
		return dbus.MakeFailedError(fmt.Errorf("read-only"))
	}
	switch name {
	case "LoopStatus":
		s, _ := value.Value().(string)
		say(map[string]any{"cmd": "loop", "v": s})
	case "Rate":
		f, _ := value.Value().(float64)
		say(map[string]any{"cmd": "rate", "v": f})
	case "Shuffle":
		b, _ := value.Value().(bool)
		say(map[string]any{"cmd": "shuffle", "v": b})
	case "Volume":
		f, _ := value.Value().(float64)
		say(map[string]any{"cmd": "volume", "v": f})
	default:
		return dbus.MakeFailedError(fmt.Errorf("read-only"))
	}
	return nil
}

type root struct{}

func (root) Raise() *dbus.Error { say(map[string]any{"cmd": "raise"}); return nil }
func (root) Quit() *dbus.Error  { say(map[string]any{"cmd": "quit"}); return nil }

type player struct{}

func (player) Next() *dbus.Error      { say(map[string]any{"cmd": "next"}); return nil }
func (player) Previous() *dbus.Error  { say(map[string]any{"cmd": "previous"}); return nil }
func (player) Pause() *dbus.Error     { say(map[string]any{"cmd": "pause"}); return nil }
func (player) PlayPause() *dbus.Error { say(map[string]any{"cmd": "playpause"}); return nil }
func (player) Stop() *dbus.Error      { say(map[string]any{"cmd": "stop"}); return nil }
func (player) Play() *dbus.Error      { say(map[string]any{"cmd": "play"}); return nil }

func (player) Seek(offset int64) *dbus.Error {
	say(map[string]any{"cmd": "seek", "ms": float64(offset) / 1000})
	return nil
}

func (player) SetPosition(id dbus.ObjectPath, pos int64) *dbus.Error {
	mu.Lock()
	ok := id == currentID()
	mu.Unlock()
	if ok {
		say(map[string]any{"cmd": "setposition", "ms": float64(pos) / 1000})
	}
	return nil
}

func (player) OpenUri(uri string) *dbus.Error {
	say(map[string]any{"cmd": "open", "uri": uri})
	return nil
}

type tracklist struct{}

func (tracklist) GetTracksMetadata(ids []dbus.ObjectPath) ([]map[string]dbus.Variant, *dbus.Error) {
	mu.Lock()
	defer mu.Unlock()
	res := []map[string]dbus.Variant{}
	for _, id := range ids {
		if i, ok := pathOf(id); ok {
			res = append(res, metaOf(&queue[i], id))
		}
	}
	return res, nil
}

func (tracklist) AddTrack(uri string, after dbus.ObjectPath, current bool) *dbus.Error {
	say(map[string]any{"cmd": "add", "uri": uri, "current": current})
	return nil
}

func (tracklist) RemoveTrack(id dbus.ObjectPath) *dbus.Error {
	mu.Lock()
	i, ok := pathOf(id)
	mu.Unlock()
	if ok {
		say(map[string]any{"cmd": "remove", "index": i})
	}
	return nil
}

func (tracklist) GoTo(id dbus.ObjectPath) *dbus.Error {
	mu.Lock()
	i, ok := pathOf(id)
	mu.Unlock()
	if ok {
		say(map[string]any{"cmd": "goto", "index": i})
	}
	return nil
}

func emitChanged(iface string, changed map[string]dbus.Variant) {
	if len(changed) > 0 {
		_ = conn.Emit(objPath, ifProps+".PropertiesChanged", iface, changed, []string{})
	}
}

func publishPlayer() {
	changed := map[string]dbus.Variant{}
	for _, n := range watchedProps {
		v, _ := playerProp(n)
		if old, ok := last[n]; !ok || !reflect.DeepEqual(old.Value(), v.Value()) {
			changed[n] = v
			last[n] = v
		}
	}
	emitChanged(ifPlayer, changed)
}

func publishTracklist() {
	ids := trackIDs()
	if reflect.DeepEqual(ids, lastTracks) {
		return
	}
	lastTracks = ids
	_ = conn.Emit(objPath, ifTracks+".TrackListReplaced", ids, currentID())
	emitChanged(ifTracks, map[string]dbus.Variant{"Tracks": dbus.MakeVariant(ids)})
}

func apply(msg message) {
	mu.Lock()
	defer mu.Unlock()
	if msg.Queue != nil {
		queue = msg.Queue
	}
	if msg.State != nil {
		st = *msg.State
		stamp = time.Now()
		if st.Seeked {
			_ = conn.Emit(objPath, ifPlayer+".Seeked", positionUs())
		}
	}
	publishTracklist()
	publishPlayer()
}

func main() {
	var err error
	conn, err = dbus.ConnectSessionBus()
	if err != nil {
		fmt.Fprintln(os.Stderr, "mpris:", err)
		os.Exit(1)
	}
	reply, err := conn.RequestName(busName, dbus.NameFlagDoNotQueue)
	if err != nil || reply != dbus.RequestNameReplyPrimaryOwner {
		fmt.Fprintln(os.Stderr, "mpris: could not own the name", busName)
		os.Exit(1)
	}
	for iface, obj := range map[string]any{ifRoot: root{}, ifPlayer: player{}, ifTracks: tracklist{}, ifProps: props{}} {
		if err := conn.Export(obj, objPath, iface); err != nil {
			fmt.Fprintln(os.Stderr, "mpris:", err)
			os.Exit(1)
		}
	}
	_ = conn.Export(introspect.Introspectable(introXML), objPath, "org.freedesktop.DBus.Introspectable")
	say(map[string]any{"cmd": "ready"})

	sc := bufio.NewScanner(os.Stdin)
	sc.Buffer(make([]byte, 1<<20), 256<<20)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		var msg message
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			fmt.Fprintln(os.Stderr, "mpris:", err)
			continue
		}
		apply(msg)
	}
}
