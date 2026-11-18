package main

import (
	"encoding/json"
	"image"
	"math"
)

// Layer pixels are never changed in place once a snapshot may hold them: an operation first takes a
// writable copy (Doc.writable), so the history is a list of cheap snapshots that share unchanged buffers.
type Layer struct {
	ID      int
	Name    string
	Kind    string // "raster" or "text"
	Visible bool
	Opacity float64
	Blend   string
	Img     *image.NRGBA // raster: the pixels, document size
	X, Y    int          // text: where its rendered image sits
	Props   json.RawMessage
	TextImg *image.NRGBA // text: the image QML rendered
}

type Mask struct {
	W, H           int
	A              []uint8
	X0, Y0, X1, Y1 int // bounding box, X1/Y1 exclusive
}

type docState struct {
	W, H   int
	Layers []Layer // bottom to top
	Active int     // layer id
	Sel    *Mask
}

type histEntry struct {
	Label, Icon string
	S           docState
}

type Doc struct {
	docState
	nextID   int
	hist     []histEntry
	hi       int
	fresh    map[*image.NRGBA]bool
	comp     *image.NRGBA
	tiles    map[[2]int]bool
	editing  int
	clip     *image.NRGBA
	selVer   int
	selDirty bool
	stroke   *stroke
	lift     *lift
}

const maxHistory = 60

func newDoc(w, h int) *Doc {
	d := &Doc{fresh: map[*image.NRGBA]bool{}, tiles: map[[2]int]bool{}}
	d.W, d.H = w, h
	d.comp = image.NewNRGBA(image.Rect(0, 0, w, h))
	return d
}

func (d *Doc) newLayer(name string) *Layer {
	d.nextID++
	return &Layer{ID: d.nextID, Name: name, Kind: "raster", Visible: true, Opacity: 1, Blend: "normal", Img: image.NewNRGBA(image.Rect(0, 0, d.W, d.H))}
}

func (d *Doc) idx(id int) int {
	for i := range d.Layers {
		if d.Layers[i].ID == id {
			return i
		}
	}
	return -1
}

func (d *Doc) activeIdx() int { return d.idx(d.Active) }

func (d *Doc) insertAbove(i int, l Layer) {
	d.Layers = append(d.Layers, Layer{})
	copy(d.Layers[i+2:], d.Layers[i+1:])
	d.Layers[i+1] = l
}

func cloneImg(src *image.NRGBA) *image.NRGBA {
	dst := image.NewNRGBA(src.Rect)
	copy(dst.Pix, src.Pix)
	return dst
}

// writable returns the pixels of layer i in a buffer no snapshot holds.
func (d *Doc) writable(i int) *image.NRGBA {
	img := d.Layers[i].Img
	if d.fresh[img] {
		return img
	}
	n := cloneImg(img)
	d.fresh[n] = true
	d.Layers[i].Img = n
	return n
}

func (d *Doc) snap() docState {
	s := d.docState
	s.Layers = append([]Layer(nil), d.Layers...)
	return s
}

func (d *Doc) commit(label, icon string) {
	d.fresh = map[*image.NRGBA]bool{}
	if d.hi+1 < len(d.hist) {
		d.hist = d.hist[:d.hi+1]
	}
	d.hist = append(d.hist, histEntry{label, icon, d.snap()})
	if len(d.hist) > maxHistory {
		d.hist = d.hist[len(d.hist)-maxHistory:]
	}
	d.hi = len(d.hist) - 1
}

func (d *Doc) gotoHist(i int) {
	if i < 0 || i >= len(d.hist) || i == d.hi {
		return
	}
	d.hi = i
	s := d.hist[i].S
	s.Layers = append([]Layer(nil), s.Layers...)
	oldW, oldH := d.W, d.H
	d.docState = s
	d.fresh = map[*image.NRGBA]bool{}
	d.selDirty = true
	if d.W != oldW || d.H != oldH {
		d.comp = image.NewNRGBA(image.Rect(0, 0, d.W, d.H))
	}
	d.dirtyAll()
}

func (d *Doc) dirtyRect(r image.Rectangle) {
	r = r.Intersect(d.comp.Rect)
	if r.Empty() {
		return
	}
	d.recomp(r)
	for ty := r.Min.Y / tileSize; ty <= (r.Max.Y-1)/tileSize; ty++ {
		for tx := r.Min.X / tileSize; tx <= (r.Max.X-1)/tileSize; tx++ {
			d.tiles[[2]int{tx, ty}] = true
		}
	}
}

func (d *Doc) dirtyAll() { d.dirtyRect(d.comp.Rect) }

type src struct {
	img    *image.NRGBA
	ox, oy int
	op     float32
	blend  func(b, s float32) float32
}

func (d *Doc) sources() []src {
	var out []src
	for i := range d.Layers {
		l := &d.Layers[i]
		if !l.Visible || l.ID == d.editing {
			continue
		}
		s := src{op: float32(l.Opacity), blend: blendFunc(l.Blend)}
		if l.Kind == "text" {
			if l.TextImg == nil {
				continue
			}
			s.img, s.ox, s.oy = l.TextImg, l.X, l.Y
		} else {
			s.img = l.Img
		}
		out = append(out, s)
	}
	return out
}

func (d *Doc) recomp(r image.Rectangle) {
	srcs := d.sources()
	c := d.comp
	for y := r.Min.Y; y < r.Max.Y; y++ {
		for x := r.Min.X; x < r.Max.X; x++ {
			var ba, br, bg, bb float32
			for k := range srcs {
				s := &srcs[k]
				sx, sy := x-s.ox, y-s.oy
				if sx < 0 || sy < 0 || sx >= s.img.Rect.Dx() || sy >= s.img.Rect.Dy() {
					continue
				}
				o := sy*s.img.Stride + sx*4
				a8 := s.img.Pix[o+3]
				if a8 == 0 {
					continue
				}
				sa := float32(a8) / 255 * s.op
				sr, sg, sb := float32(s.img.Pix[o])/255, float32(s.img.Pix[o+1])/255, float32(s.img.Pix[o+2])/255
				if ba == 0 {
					br, bg, bb, ba = sr, sg, sb, sa
					continue
				}
				ra := sa + ba*(1-sa)
				if s.blend == nil {
					br = (sr*sa + br*ba*(1-sa)) / ra
					bg = (sg*sa + bg*ba*(1-sa)) / ra
					bb = (sb*sa + bb*ba*(1-sa)) / ra
				} else {
					br = ((1-sa)*ba*br + sa*((1-ba)*sr+ba*s.blend(br, sr))) / ra
					bg = ((1-sa)*ba*bg + sa*((1-ba)*sg+ba*s.blend(bg, sg))) / ra
					bb = ((1-sa)*ba*bb + sa*((1-ba)*sb+ba*s.blend(bb, sb))) / ra
				}
				ba = ra
			}
			o := y*c.Stride + x*4
			c.Pix[o], c.Pix[o+1], c.Pix[o+2], c.Pix[o+3] = to8(br), to8(bg), to8(bb), to8(ba)
		}
	}
}

func to8(v float32) uint8 {
	if v <= 0 {
		return 0
	}
	if v >= 1 {
		return 255
	}
	return uint8(v*255 + 0.5)
}

func blendFunc(name string) func(b, s float32) float32 {
	switch name {
	case "multiply":
		return func(b, s float32) float32 { return b * s }
	case "screen":
		return func(b, s float32) float32 { return b + s - b*s }
	case "overlay":
		return func(b, s float32) float32 {
			if b < 0.5 {
				return 2 * b * s
			}
			return 1 - 2*(1-b)*(1-s)
		}
	case "darken":
		return func(b, s float32) float32 { return float32(math.Min(float64(b), float64(s))) }
	case "lighten":
		return func(b, s float32) float32 { return float32(math.Max(float64(b), float64(s))) }
	case "add":
		return func(b, s float32) float32 { return float32(math.Min(1, float64(b+s))) }
	case "difference":
		return func(b, s float32) float32 { return float32(math.Abs(float64(b - s))) }
	}
	return nil
}

// flat composites the visible layers into a new image (text layers included, even one being edited).
func (d *Doc) flat() *image.NRGBA {
	keep := d.editing
	d.editing = 0
	tmp := &Doc{docState: d.docState, comp: image.NewNRGBA(image.Rect(0, 0, d.W, d.H))}
	tmp.recomp(tmp.comp.Rect)
	d.editing = keep
	return tmp.comp
}

// layerPixels is what a layer looks like as document-sized pixels (a text layer is drawn into place).
func (d *Doc) layerPixels(l *Layer) *image.NRGBA {
	if l.Kind != "text" {
		return l.Img
	}
	out := image.NewNRGBA(image.Rect(0, 0, d.W, d.H))
	if l.TextImg != nil {
		blit(out, l.TextImg, l.X, l.Y)
	}
	return out
}

func (d *Doc) rasterize(i int) {
	l := &d.Layers[i]
	if l.Kind != "text" {
		return
	}
	l.Img = d.layerPixels(l)
	l.Kind, l.Props, l.TextImg, l.X, l.Y = "raster", nil, nil, 0, 0
	if d.editing == l.ID {
		d.editing = 0
	}
}

func (d *Doc) rasterizeAll() {
	for i := range d.Layers {
		d.rasterize(i)
	}
}

// blit draws src over dst at an offset (normal blend, no opacity).
func blit(dst, s *image.NRGBA, ox, oy int) {
	for y := 0; y < s.Rect.Dy(); y++ {
		dy := y + oy
		if dy < 0 || dy >= dst.Rect.Dy() {
			continue
		}
		for x := 0; x < s.Rect.Dx(); x++ {
			dx := x + ox
			if dx < 0 || dx >= dst.Rect.Dx() {
				continue
			}
			so := y*s.Stride + x*4
			if s.Pix[so+3] == 0 {
				continue
			}
			do := dy*dst.Stride + dx*4
			overPix(dst.Pix[do:do+4], s.Pix[so], s.Pix[so+1], s.Pix[so+2], float32(s.Pix[so+3])/255)
		}
	}
}

// overPix blends a colour with alpha a (0-1) over one NRGBA pixel.
func overPix(p []uint8, r, g, b uint8, a float32) {
	if a <= 0 {
		return
	}
	ba := float32(p[3]) / 255
	ra := a + ba*(1-a)
	if ra <= 0 {
		return
	}
	k := ba * (1 - a)
	p[0] = to8((float32(r)/255*a + float32(p[0])/255*k) / ra)
	p[1] = to8((float32(g)/255*a + float32(p[1])/255*k) / ra)
	p[2] = to8((float32(b)/255*a + float32(p[2])/255*k) / ra)
	p[3] = to8(ra)
}
