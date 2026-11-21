// keyring talks to the Secret Service (gnome-keyring, KWallet's bridge, KeePassXC) for the
// Passwords page in Settings. One command per run:
//
//	keyring list                      keyrings and their items as one JSON object
//	keyring lock PATH                 lock a keyring
//	keyring unlock PATH               unlock a keyring; the service asks for the password
//	keyring password PATH             change a keyring's password (the service asks)
//	keyring create LABEL              new keyring; the service asks for its password
//	keyring default PATH              make a keyring the default one
//	keyring delete PATH               delete an item or a whole keyring
//	keyring secret PATH               print an item's secret to stdout (for wl-copy)
//	keyring store PATH LABEL ACCOUNT  new item in keyring PATH, its secret read from stdin
//
// Prompts belong to the connection that asked for them, so this waits for each prompt
// to finish before it exits. Secrets never go through the shell's QML.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sort"
	"strings"

	"github.com/godbus/dbus/v5"
)

const (
	busName  = "org.freedesktop.secrets"
	rootPath = dbus.ObjectPath("/org/freedesktop/secrets")
	service  = "org.freedesktop.Secret.Service"
	coll     = "org.freedesktop.Secret.Collection"
	item     = "org.freedesktop.Secret.Item"
)

type secretValue struct {
	Session     dbus.ObjectPath
	Parameters  []byte
	Value       []byte
	ContentType string
}

type itemInfo struct {
	Path     string            `json:"path"`
	Label    string            `json:"label"`
	Locked   bool              `json:"locked"`
	Created  uint64            `json:"created"`
	Modified uint64            `json:"modified"`
	Attrs    map[string]string `json:"attrs"`
}

type collInfo struct {
	Path     string     `json:"path"`
	Label    string     `json:"label"`
	Locked   bool       `json:"locked"`
	Default  bool       `json:"default"`
	Created  uint64     `json:"created"`
	Modified uint64     `json:"modified"`
	Items    []itemInfo `json:"items"`
}

var conn *dbus.Conn

func fail(format string, a ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", a...)
	os.Exit(1)
}

func obj(p dbus.ObjectPath) dbus.BusObject { return conn.Object(busName, p) }

func prop(p dbus.ObjectPath, iface, name string) (dbus.Variant, error) {
	return obj(p).GetProperty(iface + "." + name)
}

// prompt runs a prompt the service handed back and waits for its answer.
// Returns false when the user dismissed it.
func prompt(p dbus.ObjectPath) (bool, dbus.Variant) {
	if p == "/" || p == "" {
		return true, dbus.Variant{}
	}
	ch := make(chan *dbus.Signal, 4)
	conn.Signal(ch)
	_ = conn.AddMatchSignal(dbus.WithMatchObjectPath(p), dbus.WithMatchInterface("org.freedesktop.Secret.Prompt"), dbus.WithMatchMember("Completed"))
	if err := obj(p).Call("org.freedesktop.Secret.Prompt.Prompt", 0, "").Err; err != nil {
		fail("%v", err)
	}
	for s := range ch {
		if s.Path == p && s.Name == "org.freedesktop.Secret.Prompt.Completed" && len(s.Body) >= 2 {
			dismissed, _ := s.Body[0].(bool)
			v, _ := s.Body[1].(dbus.Variant)
			return !dismissed, v
		}
	}
	return false, dbus.Variant{}
}

func openSession() dbus.ObjectPath {
	var out dbus.Variant
	var session dbus.ObjectPath
	if err := obj(rootPath).Call(service+".OpenSession", 0, "plain", dbus.MakeVariant("")).Store(&out, &session); err != nil {
		fail("%v", err)
	}
	return session
}

func list() {
	var def dbus.ObjectPath
	_ = obj(rootPath).Call(service+".ReadAlias", 0, "default").Store(&def)
	v, err := prop(rootPath, service, "Collections")
	if err != nil {
		fail("%v", err)
	}
	paths, _ := v.Value().([]dbus.ObjectPath)
	out := []collInfo{}
	for _, c := range paths {
		var props map[string]dbus.Variant
		if obj(c).Call("org.freedesktop.DBus.Properties.GetAll", 0, coll).Store(&props) != nil {
			continue
		}
		ci := collInfo{Path: string(c), Default: c == def, Items: []itemInfo{}}
		ci.Label, _ = props["Label"].Value().(string)
		ci.Locked, _ = props["Locked"].Value().(bool)
		ci.Created, _ = props["Created"].Value().(uint64)
		ci.Modified, _ = props["Modified"].Value().(uint64)
		items, _ := props["Items"].Value().([]dbus.ObjectPath)
		for _, i := range items {
			var ip map[string]dbus.Variant
			if obj(i).Call("org.freedesktop.DBus.Properties.GetAll", 0, item).Store(&ip) != nil {
				continue
			}
			ii := itemInfo{Path: string(i), Attrs: map[string]string{}}
			ii.Label, _ = ip["Label"].Value().(string)
			ii.Locked, _ = ip["Locked"].Value().(bool)
			ii.Created, _ = ip["Created"].Value().(uint64)
			ii.Modified, _ = ip["Modified"].Value().(uint64)
			if a, ok := ip["Attributes"].Value().(map[string]string); ok {
				ii.Attrs = a
			}
			ci.Items = append(ci.Items, ii)
		}
		sort.Slice(ci.Items, func(a, b int) bool {
			return strings.ToLower(ci.Items[a].Label) < strings.ToLower(ci.Items[b].Label)
		})
		out = append(out, ci)
	}
	_ = json.NewEncoder(os.Stdout).Encode(out)
}

func lockOrUnlock(method string, p dbus.ObjectPath) {
	var done []dbus.ObjectPath
	var pr dbus.ObjectPath
	if err := obj(rootPath).Call(service+"."+method, 0, []dbus.ObjectPath{p}).Store(&done, &pr); err != nil {
		fail("%v", err)
	}
	if ok, _ := prompt(pr); !ok {
		os.Exit(2)
	}
}

func main() {
	if len(os.Args) < 2 {
		fail("usage: keyring list|lock|unlock|password|create|default|delete|secret|store ...")
	}
	var err error
	if conn, err = dbus.ConnectSessionBus(); err != nil {
		fail("%v", err)
	}
	arg := func(i int) string {
		if len(os.Args) <= i {
			fail("missing argument")
		}
		return os.Args[i]
	}
	switch os.Args[1] {
	case "list":
		list()
	case "lock":
		lockOrUnlock("Lock", dbus.ObjectPath(arg(2)))
	case "unlock":
		lockOrUnlock("Unlock", dbus.ObjectPath(arg(2)))
	case "password":
		var pr dbus.ObjectPath
		if err := obj(rootPath).Call("org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface.ChangeWithPrompt", 0, dbus.ObjectPath(arg(2))).Store(&pr); err != nil {
			fail("%v", err)
		}
		if ok, _ := prompt(pr); !ok {
			os.Exit(2)
		}
	case "create":
		props := map[string]dbus.Variant{coll + ".Label": dbus.MakeVariant(arg(2))}
		var c, pr dbus.ObjectPath
		if err := obj(rootPath).Call(service+".CreateCollection", 0, props, "").Store(&c, &pr); err != nil {
			fail("%v", err)
		}
		if ok, _ := prompt(pr); !ok {
			os.Exit(2)
		}
	case "default":
		if err := obj(rootPath).Call(service+".SetAlias", 0, "default", dbus.ObjectPath(arg(2))).Err; err != nil {
			fail("%v", err)
		}
	case "delete":
		p := dbus.ObjectPath(arg(2))
		iface := item
		if strings.Count(strings.TrimPrefix(string(p), "/org/freedesktop/secrets/collection/"), "/") == 0 {
			iface = coll
		}
		var pr dbus.ObjectPath
		if err := obj(p).Call(iface+".Delete", 0).Store(&pr); err != nil {
			fail("%v", err)
		}
		if ok, _ := prompt(pr); !ok {
			os.Exit(2)
		}
	case "secret":
		p := dbus.ObjectPath(arg(2))
		if v, err := prop(p, item, "Locked"); err == nil && v.Value() == true {
			lockOrUnlock("Unlock", p)
		}
		var s secretValue
		if err := obj(p).Call(item+".GetSecret", 0, openSession()).Store(&s); err != nil {
			fail("%v", err)
		}
		_, _ = os.Stdout.Write(s.Value)
	case "store":
		c := dbus.ObjectPath(arg(2))
		label, account := arg(3), arg(4)
		value, err := io.ReadAll(os.Stdin)
		if err != nil {
			fail("%v", err)
		}
		value = []byte(strings.TrimRight(string(value), "\n"))
		attrs := map[string]string{"xdg:schema": "org.freedesktop.Secret.Generic", "service": label}
		if account != "" {
			attrs["user"] = account
		}
		props := map[string]dbus.Variant{
			item + ".Label":      dbus.MakeVariant(label),
			item + ".Attributes": dbus.MakeVariant(attrs),
		}
		s := secretValue{Session: openSession(), Parameters: []byte{}, Value: value, ContentType: "text/plain"}
		var i, pr dbus.ObjectPath
		if err := obj(c).Call(coll+".CreateItem", 0, props, s, false).Store(&i, &pr); err != nil {
			fail("%v", err)
		}
		if ok, _ := prompt(pr); !ok {
			os.Exit(2)
		}
	default:
		fail("unknown command %s", os.Args[1])
	}
}
