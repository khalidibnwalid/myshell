// The shell's file chooser for xdg-desktop-portal: owns org.freedesktop.impl.portal.desktop.quickshell and
// implements org.freedesktop.impl.portal.FileChooser, so the "Open" and "Save" dialogs of apps (VS Code,
// Firefox, ...) are drawn by the shell. It draws nothing itself; it talks to the shell over stdin/stdout,
// one JSON object per line:
//
//	out: {"id": 1, "kind": "open" | "save" | "savefiles", "app": "...", "title": "...", "options": {...}}
//	     {"id": 1, "close": true}                  the app withdrew the request
//	in:  {"id": 1, "paths": ["/home/me/a.txt"]}    the user chose these (empty or "cancelled": true = no)
//
// Run with `install` or `uninstall` to write or remove the small files that make xdg-desktop-portal prefer
// this backend for file dialogs (`install` prints "changed" when it wrote something new). The portal asks
// D-Bus to start this backend when nobody owns the name, e.g. before the shell is up or after it quit; that
// instance runs as `--fallback` and just hands every dialog to the GTK portal, and the shell's own instance
// takes the name over when it starts.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/godbus/dbus/v5"
)

const (
	busName   = "org.freedesktop.impl.portal.desktop.quickshell"
	gtkName   = "org.freedesktop.impl.portal.desktop.gtk"
	objPath   = dbus.ObjectPath("/org/freedesktop/portal/desktop")
	ifChooser = "org.freedesktop.impl.portal.FileChooser"
	ifRequest = "org.freedesktop.impl.portal.Request"
	marker    = "# written by the quickshell shell (helpers/portal-filechooser); `uninstall` removes it"
)

type pattern struct {
	Kind    uint32 // 0 = glob, 1 = mime type
	Pattern string
}

type filter struct {
	Name     string
	Patterns []pattern
}

type filterJSON struct {
	Name     string   `json:"name"`
	Patterns []string `json:"patterns"` // globs, e.g. "*.png"
	Mimes    []string `json:"mimes"`
}

type options struct {
	Multiple      bool         `json:"multiple"`
	Directory     bool         `json:"directory"`
	Filters       []filterJSON `json:"filters"`
	CurrentFilter *filterJSON  `json:"currentFilter,omitempty"`
	CurrentFolder string       `json:"currentFolder,omitempty"`
	CurrentName   string       `json:"currentName,omitempty"`
	AcceptLabel   string       `json:"acceptLabel,omitempty"`
	Files         []string     `json:"files,omitempty"` // names to save (SaveFiles)
}

type outMsg struct {
	ID      int      `json:"id"`
	Kind    string   `json:"kind,omitempty"`
	App     string   `json:"app,omitempty"`
	Title   string   `json:"title,omitempty"`
	Options *options `json:"options,omitempty"`
	Close   bool     `json:"close,omitempty"`
}

type inMsg struct {
	ID        int      `json:"id"`
	Paths     []string `json:"paths"`
	Cancelled bool     `json:"cancelled"`
}

type chooser struct {
	fallback bool
	conn     *dbus.Conn
	mu       sync.Mutex
	next     int
	pending  map[int]chan inMsg
	out      *json.Encoder
}

type request struct {
	c  *chooser
	id int
}

// Close is called by the portal when the app cancels the dialog.
func (r *request) Close() *dbus.Error {
	r.c.deliver(inMsg{ID: r.id, Cancelled: true})
	r.c.send(outMsg{ID: r.id, Close: true})
	return nil
}

func (c *chooser) send(m outMsg) {
	c.mu.Lock()
	defer c.mu.Unlock()
	_ = c.out.Encode(m)
}

func (c *chooser) deliver(m inMsg) {
	c.mu.Lock()
	ch := c.pending[m.ID]
	delete(c.pending, m.ID)
	c.mu.Unlock()
	if ch != nil {
		ch <- m
	}
}

func filtersOf(v dbus.Variant) []filterJSON {
	var list []filter
	if err := v.Store(&list); err != nil {
		return nil
	}
	return convert(list)
}

func convert(list []filter) []filterJSON {
	out := make([]filterJSON, 0, len(list))
	for _, f := range list {
		j := filterJSON{Name: f.Name}
		for _, p := range f.Patterns {
			if p.Kind == 0 {
				j.Patterns = append(j.Patterns, p.Pattern)
			} else {
				j.Mimes = append(j.Mimes, p.Pattern)
			}
		}
		out = append(out, j)
	}
	return out
}

func bytesString(v dbus.Variant) string {
	var b []byte
	if err := v.Store(&b); err != nil {
		return ""
	}
	return strings.TrimRight(string(b), "\x00")
}

func parse(kind string, opts map[string]dbus.Variant) *options {
	o := &options{}
	if v, ok := opts["multiple"]; ok {
		_ = v.Store(&o.Multiple)
	}
	if v, ok := opts["directory"]; ok {
		_ = v.Store(&o.Directory)
	}
	if v, ok := opts["filters"]; ok {
		o.Filters = filtersOf(v)
	}
	if v, ok := opts["current_filter"]; ok {
		var f filter
		if v.Store(&f) == nil {
			c := convert([]filter{f})
			o.CurrentFilter = &c[0]
		}
	}
	if v, ok := opts["current_folder"]; ok {
		o.CurrentFolder = bytesString(v)
	}
	if v, ok := opts["current_name"]; ok {
		_ = v.Store(&o.CurrentName)
	}
	if v, ok := opts["accept_label"]; ok {
		_ = v.Store(&o.AcceptLabel)
	}
	if v, ok := opts["files"]; ok {
		var raw [][]byte
		if v.Store(&raw) == nil {
			for _, b := range raw {
				o.Files = append(o.Files, strings.TrimRight(string(b), "\x00"))
			}
		}
	}
	if kind == "savefiles" {
		o.Directory = true
	}
	return o
}

func toURIs(paths []string) []string {
	uris := make([]string, 0, len(paths))
	for _, p := range paths {
		u := url.URL{Scheme: "file", Path: p}
		uris = append(uris, u.String())
	}
	return uris
}

// forward hands the dialog to the GTK portal (used while the shell is not running).
func (c *chooser) forward(kind string, handle dbus.ObjectPath, app, parent, title string, opts map[string]dbus.Variant) (uint32, map[string]dbus.Variant, *dbus.Error) {
	method := map[string]string{"open": "OpenFile", "save": "SaveFile", "savefiles": "SaveFiles"}[kind]
	var code uint32
	var results map[string]dbus.Variant
	call := c.conn.Object(gtkName, objPath).Call(ifChooser+"."+method, 0, handle, app, parent, title, opts)
	if err := call.Store(&code, &results); err != nil {
		return 2, map[string]dbus.Variant{}, nil
	}
	return code, results, nil
}

func (c *chooser) run(kind string, handle dbus.ObjectPath, app, parent, title string, opts map[string]dbus.Variant) (uint32, map[string]dbus.Variant, *dbus.Error) {
	if c.fallback {
		return c.forward(kind, handle, app, parent, title, opts)
	}
	ch := make(chan inMsg, 1)
	c.mu.Lock()
	c.next++
	id := c.next
	c.pending[id] = ch
	c.mu.Unlock()

	_ = c.conn.Export(&request{c: c, id: id}, handle, ifRequest)
	defer c.conn.Export(nil, handle, ifRequest)

	o := parse(kind, opts)
	c.send(outMsg{ID: id, Kind: kind, App: app, Title: title, Options: o})
	r := <-ch
	if r.Cancelled || len(r.Paths) == 0 {
		return 1, map[string]dbus.Variant{}, nil
	}
	paths := r.Paths
	if kind == "savefiles" && len(o.Files) > 0 {
		// the user picked a folder; the files go into it under the names the app gave
		dir := r.Paths[0]
		paths = paths[:0]
		for _, name := range o.Files {
			paths = append(paths, filepath.Join(dir, filepath.Base(name)))
		}
	}
	return 0, map[string]dbus.Variant{"uris": dbus.MakeVariant(toURIs(paths))}, nil
}

func (c *chooser) OpenFile(handle dbus.ObjectPath, app, parent, title string, opts map[string]dbus.Variant) (uint32, map[string]dbus.Variant, *dbus.Error) {
	return c.run("open", handle, app, parent, title, opts)
}

func (c *chooser) SaveFile(handle dbus.ObjectPath, app, parent, title string, opts map[string]dbus.Variant) (uint32, map[string]dbus.Variant, *dbus.Error) {
	return c.run("save", handle, app, parent, title, opts)
}

func (c *chooser) SaveFiles(handle dbus.ObjectPath, app, parent, title string, opts map[string]dbus.Variant) (uint32, map[string]dbus.Variant, *dbus.Error) {
	return c.run("savefiles", handle, app, parent, title, opts)
}

// ---- install / uninstall ----

func paths() (portal, conf, service string) {
	home, _ := os.UserHomeDir()
	data := os.Getenv("XDG_DATA_HOME")
	if data == "" {
		data = filepath.Join(home, ".local", "share")
	}
	cfg := os.Getenv("XDG_CONFIG_HOME")
	if cfg == "" {
		cfg = filepath.Join(home, ".config")
	}
	desktop := strings.ToLower(strings.Split(os.Getenv("XDG_CURRENT_DESKTOP"), ":")[0])
	if desktop == "" {
		desktop = "hyprland"
	}
	return filepath.Join(data, "xdg-desktop-portal", "portals", "quickshell.portal"),
		filepath.Join(cfg, "xdg-desktop-portal", desktop+"-portals.conf"),
		filepath.Join(data, "dbus-1", "services", busName+".service")
}

func ours(path string) bool {
	b, err := os.ReadFile(path)
	return err == nil && strings.Contains(string(b), marker)
}

// put writes a file unless it already has this content; reports whether it changed.
func put(path, body string) (bool, error) {
	if old, err := os.ReadFile(path); err == nil && string(old) == body {
		return false, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return false, err
	}
	return true, os.WriteFile(path, []byte(body), 0o644)
}

func install() (bool, error) {
	portal, conf, service := paths()
	if _, err := os.Stat(conf); err == nil && !ours(conf) {
		return false, fmt.Errorf("%s already exists and is not ours; add\n  org.freedesktop.impl.portal.FileChooser=quickshell;gtk\nunder [preferred] yourself", conf)
	}
	exe, err := os.Executable()
	if err != nil {
		return false, err
	}
	files := []struct{ path, body string }{
		{portal, "[portal]\nDBusName=" + busName + "\nInterfaces=" + ifChooser + ";\nUseIn=Hyprland\n"},
		{conf, marker + "\n[preferred]\ndefault=hyprland;gtk\n" + ifChooser + "=quickshell;gtk\n"},
		{service, marker + "\n[D-BUS Service]\nName=" + busName + "\nExec=" + exe + " --fallback\n"},
	}
	changed := false
	for _, f := range files {
		c, err := put(f.path, f.body)
		if err != nil {
			return changed, err
		}
		changed = changed || c
	}
	return changed, nil
}

func uninstall() (bool, error) {
	portal, conf, service := paths()
	changed := false
	for _, f := range []string{portal, conf, service} {
		if f != portal && !ours(f) {
			continue
		}
		if err := os.Remove(f); err == nil {
			changed = true
		} else if !os.IsNotExist(err) {
			return changed, err
		}
	}
	return changed, nil
}

func main() {
	if len(os.Args) > 1 && os.Args[1] != "" {
		var err error
		var changed bool
		switch os.Args[1] {
		case "install":
			changed, err = install()
		case "uninstall":
			changed, err = uninstall()
		case "--fallback":
		default:
			err = fmt.Errorf("unknown command %q (install, uninstall)", os.Args[1])
		}
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		if os.Args[1] != "--fallback" {
			if changed {
				fmt.Println("changed")
			}
			return
		}
	}

	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fallback := len(os.Args) > 1 && os.Args[1] == "--fallback"
	c := &chooser{fallback: fallback, conn: conn, pending: map[int]chan inMsg{}, out: json.NewEncoder(os.Stdout)}
	if err := conn.Export(c, objPath, ifChooser); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	flags := dbus.NameFlagDoNotQueue | dbus.NameFlagReplaceExisting
	if fallback {
		flags = dbus.NameFlagDoNotQueue | dbus.NameFlagAllowReplacement
	}
	reply, err := conn.RequestName(busName, flags)
	if err != nil || reply != dbus.RequestNameReplyPrimaryOwner {
		fmt.Fprintln(os.Stderr, "the file chooser portal name is taken")
		os.Exit(1)
	}
	if fallback {
		// the shell replaces this instance when it starts; then the name is lost and this one ends
		lost := make(chan *dbus.Signal, 4)
		conn.Signal(lost)
		_ = conn.AddMatchSignal(dbus.WithMatchSender("org.freedesktop.DBus"), dbus.WithMatchMember("NameLost"))
		for s := range lost {
			if s.Name == "org.freedesktop.DBus.NameLost" {
				return
			}
		}
		return
	}

	// the shell's answers; when it goes away the name is released, so the GTK portal takes over again
	in := bufio.NewScanner(os.Stdin)
	in.Buffer(make([]byte, 1<<20), 1<<20)
	for in.Scan() {
		var m inMsg
		if json.Unmarshal(in.Bytes(), &m) == nil {
			c.deliver(m)
		}
	}
}
