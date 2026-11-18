// paint-engine: the pixel side of the Paint app. It owns the layers, the selection and the history,
// does all drawing, and writes what the screen shows as 256 px PNG tiles. The app talks to it with one
// JSON command per line on stdin and reads one JSON event per line on stdout.
package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"image"
	"io"
	"math"
	"os"
	"path/filepath"
	"time"
)

const tileSize = 256

type Cmd struct {
	Op       string          `json:"op"`
	Kind     string          `json:"kind"`
	Phase    string          `json:"phase"`
	Layer    int             `json:"layer"`
	X        float64         `json:"x"`
	Y        float64         `json:"y"`
	X0       float64         `json:"x0"`
	Y0       float64         `json:"y0"`
	X1       float64         `json:"x1"`
	Y1       float64         `json:"y1"`
	CX       float64         `json:"cx"`
	CY       float64         `json:"cy"`
	C2X      float64         `json:"c2x"`
	C2Y      float64         `json:"c2y"`
	OX       float64         `json:"ox"`
	OY       float64         `json:"oy"`
	DX       float64         `json:"dx"`
	DY       float64         `json:"dy"`
	W        int             `json:"w"`
	H        int             `json:"h"`
	Size     float64         `json:"size"`
	Hardness float64         `json:"hardness"`
	Spacing  float64         `json:"spacing"`
	Tol      float64         `json:"tol"`
	Amount   float64         `json:"amount"`
	Width    float64         `json:"width"`
	Radius   float64         `json:"radius"`
	Color    string          `json:"color"`
	Color2   string          `json:"color2"`
	AA       bool            `json:"aa"`
	Fill     string          `json:"fill"`
	Mode     string          `json:"mode"`
	Global   bool            `json:"global"`
	Final    bool            `json:"final"`
	To       int             `json:"to"`
	Pts      [][2]float64    `json:"pts"`
	Props    json.RawMessage `json:"props"`
	Name     *string         `json:"name"`
	Visible  *bool           `json:"visible"`
	Opacity  *float64        `json:"opacity"`
	Blend    *string         `json:"blend"`
	Path     string          `json:"path"`
	Quality  int             `json:"quality"`
	Label    string          `json:"label"`
	Icon     string          `json:"icon"`
	Source   string          `json:"source"`
}

func (c *Cmd) X0i() int { return int(math.Round(c.X0)) }
func (c *Cmd) Y0i() int { return int(math.Round(c.Y0)) }

type engine struct {
	d         *Doc
	dir       string
	out       *bufio.Writer
	tileVer   map[[2]int]int
	verN      int
	needState bool
	thumbs    map[*image.NRGBA]string
	thumbN    int
	lastSel   string
	garbage   []string
	origSel   *Mask
}

func (e *engine) emit(v any) {
	b, _ := json.Marshal(v)
	e.out.Write(b)
	e.out.WriteByte('\n')
	e.out.Flush()
}

func (e *engine) fail(msg string) { e.emit(map[string]any{"ev": "error", "message": msg}) }

func (e *engine) flushTiles() {
	d := e.d
	if len(d.tiles) == 0 {
		return
	}
	for _, g := range e.garbage {
		os.Remove(g)
	}
	e.garbage = nil
	var list [][3]int
	for t := range d.tiles {
		e.verN++
		r := image.Rect(t[0]*tileSize, t[1]*tileSize, (t[0]+1)*tileSize, (t[1]+1)*tileSize).Intersect(d.comp.Rect)
		if r.Empty() {
			continue
		}
		name := filepath.Join(e.dir, fmt.Sprintf("t%d_%d_%d.png", t[0], t[1], e.verN))
		sub := d.comp.SubImage(r)
		if err := writeFileAtomic(name, func(w io.Writer) error { return encodePNG(w, sub) }); err != nil {
			continue
		}
		if old, ok := e.tileVer[t]; ok {
			e.garbage = append(e.garbage, filepath.Join(e.dir, fmt.Sprintf("t%d_%d_%d.png", t[0], t[1], old)))
		}
		e.tileVer[t] = e.verN
		list = append(list, [3]int{t[0], t[1], e.verN})
	}
	d.tiles = map[[2]int]bool{}
	e.emit(map[string]any{"ev": "tiles", "tiles": list})
}

func (e *engine) thumb(img *image.NRGBA) string {
	if n, ok := e.thumbs[img]; ok {
		return n
	}
	w, h := img.Rect.Dx(), img.Rect.Dy()
	k := math.Min(1, math.Min(64/float64(w), 48/float64(h)))
	tw, th := max(1, int(float64(w)*k)), max(1, int(float64(h)*k))
	out := image.NewNRGBA(image.Rect(0, 0, tw, th))
	for y := 0; y < th; y++ {
		for x := 0; x < tw; x++ {
			x0, x1 := x*w/tw, max(x*w/tw+1, (x+1)*w/tw)
			y0, y1 := y*h/th, max(y*h/th+1, (y+1)*h/th)
			var s [4]int
			n := 0
			for yy := y0; yy < y1; yy++ {
				for xx := x0; xx < x1; xx++ {
					o := yy*img.Stride + xx*4
					a := int(img.Pix[o+3])
					s[0] += int(img.Pix[o]) * a
					s[1] += int(img.Pix[o+1]) * a
					s[2] += int(img.Pix[o+2]) * a
					s[3] += a
					n++
				}
			}
			if s[3] > 0 {
				o := y*out.Stride + x*4
				out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = uint8(s[0]/s[3]), uint8(s[1]/s[3]), uint8(s[2]/s[3]), uint8(s[3]/n)
			}
		}
	}
	e.thumbN++
	name := filepath.Join(e.dir, fmt.Sprintf("th%d.png", e.thumbN))
	if writeFileAtomic(name, func(w io.Writer) error { return encodePNG(w, out) }) != nil {
		return ""
	}
	e.thumbs[img] = name
	return name
}

func (e *engine) selOverlay() any {
	d := e.d
	if d.Sel == nil {
		e.lastSel = ""
		return nil
	}
	if d.selDirty || e.lastSel == "" {
		m := d.Sel
		out := image.NewNRGBA(image.Rect(0, 0, d.W, d.H))
		in := func(x, y int) bool { return x >= 0 && y >= 0 && x < d.W && y < d.H && m.A[y*d.W+x] >= 128 }
		for y := m.Y0; y < m.Y1; y++ {
			for x := m.X0; x < m.X1; x++ {
				if !in(x, y) {
					continue
				}
				o := y*out.Stride + x*4
				if !in(x-1, y) || !in(x+1, y) || !in(x, y-1) || !in(x, y+1) {
					if (x+y)%8 < 4 {
						out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = 0, 0, 0, 255
					} else {
						out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = 255, 255, 255, 255
					}
				} else {
					out.Pix[o], out.Pix[o+1], out.Pix[o+2], out.Pix[o+3] = 60, 130, 255, 55
				}
			}
		}
		d.selVer++
		name := filepath.Join(e.dir, fmt.Sprintf("sel%d.png", d.selVer))
		if writeFileAtomic(name, func(w io.Writer) error { return encodePNG(w, out) }) == nil {
			if e.lastSel != "" {
				os.Remove(e.lastSel)
			}
			e.lastSel = name
		}
		d.selDirty = false
	}
	return map[string]any{"x0": d.Sel.X0, "y0": d.Sel.Y0, "x1": d.Sel.X1, "y1": d.Sel.Y1, "url": e.lastSel}
}

func (e *engine) emitState() {
	d := e.d
	live := map[*image.NRGBA]bool{}
	layers := []map[string]any{}
	for i := range d.Layers {
		l := &d.Layers[i]
		th := ""
		if l.Kind == "raster" {
			live[l.Img] = true
			th = e.thumb(l.Img)
		}
		tw, thh := 0, 0
		if l.TextImg != nil {
			tw, thh = l.TextImg.Rect.Dx(), l.TextImg.Rect.Dy()
		}
		layers = append(layers, map[string]any{"tw": tw, "th": thh, "id": l.ID, "name": l.Name, "kind": l.Kind, "visible": l.Visible, "opacity": l.Opacity,
			"blend": l.Blend, "props": l.Props, "x": l.X, "y": l.Y, "thumb": th})
	}
	for img, name := range e.thumbs {
		if !live[img] {
			os.Remove(name)
			delete(e.thumbs, img)
		}
	}
	hist := []map[string]string{}
	for _, h := range d.hist {
		hist = append(hist, map[string]string{"label": h.Label, "icon": h.Icon})
	}
	e.emit(map[string]any{"ev": "state", "w": d.W, "h": d.H, "active": d.Active, "layers": layers, "hist": hist, "hi": d.hi, "sel": e.selOverlay()})
}

func lab(c *Cmd, label, icon string) (string, string) {
	if c.Label != "" {
		label = c.Label
	}
	if c.Icon != "" {
		icon = c.Icon
	}
	return label, icon
}

func (e *engine) reset(d *Doc) {
	e.d = d
	e.tileVer = map[[2]int]int{}
	entries, _ := os.ReadDir(e.dir)
	for _, f := range entries {
		os.Remove(filepath.Join(e.dir, f.Name()))
	}
	e.thumbs = map[*image.NRGBA]string{}
	e.lastSel = ""
	d.commit("New image", "note_add")
	d.selDirty = true
	d.dirtyAll()
	e.emit(map[string]any{"ev": "reset", "w": d.W, "h": d.H})
	e.needState = true
}

func (e *engine) handle(c *Cmd) {
	d := e.d
	e.needState = true
	switch c.Op {
	case "new":
		w, h := max(1, min(c.W, 16000)), max(1, min(c.H, 16000))
		nd := newDoc(w, h)
		l := nd.newLayer("Background")
		if c.Mode != "transparent" {
			bg := parseColor(c.Color)
			for i := 0; i < len(l.Img.Pix); i += 4 {
				l.Img.Pix[i], l.Img.Pix[i+1], l.Img.Pix[i+2], l.Img.Pix[i+3] = bg.R, bg.G, bg.B, bg.A
			}
		}
		nd.Layers = []Layer{*l}
		nd.Active = l.ID
		e.reset(nd)
	case "open":
		var nd *Doc
		if filepath.Ext(c.Path) == ".ora" {
			var err error
			if nd, err = openORA(c.Path); err != nil {
				e.fail("Could not open: " + err.Error())
				return
			}
		} else {
			img, err := loadImage(c.Path)
			if err != nil {
				e.fail("Could not open: " + err.Error())
				return
			}
			nd = newDoc(img.Rect.Dx(), img.Rect.Dy())
			l := nd.newLayer("Background")
			l.Img = img
			nd.Layers = []Layer{*l}
			nd.Active = l.ID
		}
		e.reset(nd)
		e.emit(map[string]any{"ev": "opened", "path": c.Path})
	case "import":
		img, err := loadImage(c.Path)
		if err != nil {
			e.fail("Could not open: " + err.Error())
			return
		}
		d.pasteImage(img, 0, 0)
	case "save":
		if err := d.save(c.Path, c.Quality); err != nil {
			e.fail("Could not save: " + err.Error())
			return
		}
		e.emit(map[string]any{"ev": "saved", "path": c.Path})
	case "undo":
		d.gotoHist(d.hi - 1)
	case "redo":
		d.gotoHist(d.hi + 1)
	case "goto":
		d.gotoHist(c.To)
	case "stroke":
		switch c.Phase {
		case "begin":
			d.strokeBegin(c)
		case "move":
			d.strokeMove(c)
		case "end":
			if d.stroke != nil {
				l, i := lab(c, "Paintbrush", "brush")
				d.strokeFlush()
				d.strokeEnd(l, i)
			}
		}
		if c.Phase != "end" {
			e.needState = false
			d.strokeFlush()
		}
	case "fill":
		li := d.idx(c.Layer)
		if li < 0 || d.Layers[li].Kind != "raster" {
			return
		}
		m := flood(d.Layers[li].Img, int(c.X), int(c.Y), c.Tol, !c.Global, d.Sel)
		d.paintMask(li, m, parseColor(c.Color))
		l, i := lab(c, "Paint bucket", "format_color_fill")
		d.commit(l, i)
	case "gradient":
		d.gradient(c)
		l, i := lab(c, "Gradient", "gradient")
		d.commit(l, i)
	case "shape":
		d.shape(c)
		l, i := lab(c, "Shape", "interests")
		d.commit(l, i)
	case "pick":
		e.needState = false
		var px *image.NRGBA
		if c.Source == "image" {
			px = d.comp
		} else if li := d.idx(c.Layer); li >= 0 {
			px = d.layerPixels(&d.Layers[li])
		}
		x, y := int(c.X), int(c.Y)
		if px == nil || x < 0 || y < 0 || x >= d.W || y >= d.H {
			return
		}
		o := y*px.Stride + x*4
		e.emit(map[string]any{"ev": "pick", "color": fmt.Sprintf("#%02x%02x%02x%02x", px.Pix[o], px.Pix[o+1], px.Pix[o+2], px.Pix[o+3])})
	case "sel":
		e.selection(c)
	case "move":
		switch c.Phase {
		case "begin":
			d.moveBegin(c.Layer)
		case "move":
			d.moveTo(int(math.Round(c.DX)), int(math.Round(c.DY)))
			e.needState = d.selDirty
		case "end":
			d.moveEnd()
		}
	case "layer":
		d.layerOp(c)
	case "text.new":
		d.textNew(c)
	case "text.set":
		d.textSet(c)
	case "text.pos":
		if i := d.idx(c.Layer); i >= 0 && d.Layers[i].Kind == "text" {
			d.Layers[i].X, d.Layers[i].Y = c.X0i(), c.Y0i()
			d.dirtyAll()
			if c.Final {
				d.commit("Move text", "open_with")
			} else {
				e.needState = false
			}
		}
	case "text.discard":
		d.textDiscard(c.Layer)
	case "editing":
		d.editing = c.Layer
		d.dirtyAll()
	case "adjust":
		d.adjust(c)
		l, i := lab(c, c.Kind, "tune")
		d.commit(l, i)
	case "image":
		if !d.transform(c.Kind, c) {
			return
		}
		l, i := lab(c, c.Kind, "transform")
		d.commit(l, i)
	case "flatten":
		d.flatten()
		d.commit("Flatten", "layers_clear")
	case "edit":
		e.edit(c)
	default:
		e.needState = false
	}
}

func (d *Doc) strokeFlush() {
	if s := d.stroke; s != nil && !s.dirty.Empty() {
		d.dirtyRect(s.dirty)
		s.dirty = image.Rectangle{}
	}
}

func (e *engine) selection(c *Cmd) {
	d := e.d
	var n *Mask
	label, icon := "Rectangle select", "select"
	switch c.Kind {
	case "rect":
		n = rectMask(d.W, d.H, c.X0, c.Y0, c.X1, c.Y1)
	case "ellipse":
		n, label, icon = ellipseMask(d.W, d.H, c.X0, c.Y0, c.X1, c.Y1), "Ellipse select", "circle"
	case "lasso":
		n, label, icon = polyMask(d.W, d.H, c.Pts), "Lasso select", "gesture"
	case "wand":
		li := d.idx(c.Layer)
		if li < 0 {
			return
		}
		n, label, icon = flood(d.layerPixels(&d.Layers[li]), int(c.X), int(c.Y), c.Tol, !c.Global, nil), "Magic wand", "auto_fix_high"
	case "all":
		n, label, icon = rectMask(d.W, d.H, 0, 0, float64(d.W), float64(d.H)), "Select all", "select_all"
		c.Mode = "replace"
	case "none":
		d.Sel, d.selDirty = nil, true
		d.commit("Deselect", "deselect")
		return
	case "invert":
		if d.Sel == nil {
			return
		}
		d.Sel, d.selDirty = d.Sel.inverted(), true
		d.commit("Invert selection", "invert_colors")
		return
	case "move":
		switch c.Phase {
		case "begin":
			e.origSel = d.Sel
		case "move":
			if e.origSel != nil {
				d.Sel, d.selDirty = e.origSel.shifted(int(math.Round(c.DX)), int(math.Round(c.DY))), true
			}
		case "end":
			if e.origSel != nil {
				d.commit("Move selection", "open_with")
			}
			e.origSel = nil
		}
		return
	default:
		return
	}
	d.Sel = combine(d.Sel, n, c.Mode)
	d.selDirty = true
	l, i := lab(c, label, icon)
	d.commit(l, i)
}

func (e *engine) edit(c *Cmd) {
	d := e.d
	li := d.activeIdx()
	if li < 0 {
		return
	}
	switch c.Kind {
	case "copy", "cut":
		d.clip = d.copySel(li)
		p := filepath.Join(e.dir, "clip.png")
		if writeFileAtomic(p, func(w io.Writer) error { return encodePNG(w, d.clip) }) == nil {
			e.emit(map[string]any{"ev": "clip", "path": p})
		}
		if c.Kind == "cut" {
			d.clearSel(li, nil)
			d.commit("Cut", "content_cut")
		}
	case "clear":
		d.clearSel(li, nil)
		d.commit("Erase selection", "delete_sweep")
	case "fillsel":
		col := parseColor(c.Color)
		d.clearSel(li, &col)
		d.commit("Fill selection", "format_color_fill")
	case "paste":
		img := d.clip
		if c.Path != "" {
			if p, err := loadImage(c.Path); err == nil {
				img = p
			}
		}
		if img == nil {
			e.fail("Nothing to paste")
			return
		}
		d.pasteImage(img, c.X0i(), c.Y0i())
	}
}

func main() {
	dir := flag.String("dir", "", "folder for the tiles")
	flag.Parse()
	if *dir == "" {
		fmt.Fprintln(os.Stderr, "usage: paint-engine -dir FOLDER")
		os.Exit(2)
	}
	os.MkdirAll(*dir, 0o755)
	e := &engine{dir: *dir, out: bufio.NewWriter(os.Stdout)}
	e.reset(newDoc(1, 1))
	cmds := make(chan *Cmd, 256)
	go func() {
		sc := bufio.NewScanner(os.Stdin)
		sc.Buffer(make([]byte, 1<<20), 64<<20)
		for sc.Scan() {
			c := &Cmd{}
			if json.Unmarshal(sc.Bytes(), c) == nil {
				cmds <- c
			}
		}
		close(cmds)
	}()
	tick := time.NewTicker(16 * time.Millisecond)
	for {
		select {
		case c, ok := <-cmds:
			if !ok {
				return
			}
			if c.Op == "quit" {
				return
			}
			e.handle(c)
		case <-tick.C:
			e.flushTiles()
			if e.needState {
				e.needState = false
				e.emitState()
			}
		}
	}
}
