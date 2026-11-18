package main

import (
	"fmt"
	"image"
	"math"
	"math/rand"
)

// ---- adjustments and effects ----

func rgb2hsl(r, g, b float64) (h, s, l float64) {
	mx, mn := math.Max(r, math.Max(g, b)), math.Min(r, math.Min(g, b))
	l = (mx + mn) / 2
	if mx == mn {
		return 0, 0, l
	}
	d := mx - mn
	if l > 0.5 {
		s = d / (2 - mx - mn)
	} else {
		s = d / (mx + mn)
	}
	switch mx {
	case r:
		h = (g - b) / d
		if g < b {
			h += 6
		}
	case g:
		h = (b-r)/d + 2
	default:
		h = (r-g)/d + 4
	}
	return h / 6, s, l
}

func hsl2rgb(h, s, l float64) (float64, float64, float64) {
	if s == 0 {
		return l, l, l
	}
	var q float64
	if l < 0.5 {
		q = l * (1 + s)
	} else {
		q = l + s - l*s
	}
	p := 2*l - q
	f := func(t float64) float64 {
		t = math.Mod(t+1, 1)
		switch {
		case t < 1.0/6:
			return p + (q-p)*6*t
		case t < 0.5:
			return q
		case t < 2.0/3:
			return p + (q-p)*(2.0/3-t)*6
		}
		return p
	}
	return f(h + 1.0/3), f(h), f(h - 1.0/3)
}

func boxBlur(src *image.NRGBA, radius int) *image.NRGBA {
	if radius < 1 {
		return cloneImg(src)
	}
	w, h := src.Rect.Dx(), src.Rect.Dy()
	// premultiplied float buffers so transparent pixels do not bleed their colour
	a := make([]float32, w*h*4)
	for i := 0; i < w*h; i++ {
		al := float32(src.Pix[i*4+3]) / 255
		a[i*4], a[i*4+1], a[i*4+2], a[i*4+3] = float32(src.Pix[i*4])*al, float32(src.Pix[i*4+1])*al, float32(src.Pix[i*4+2])*al, al*255
	}
	b := make([]float32, len(a))
	pass := func(in, out []float32, n, stride, step, lines, lineStep int) {
		for l := 0; l < lines; l++ {
			base := l * lineStep
			var sum [4]float32
			cnt := float32(2*radius + 1)
			at := func(i int) int {
				if i < 0 {
					i = 0
				}
				if i >= n {
					i = n - 1
				}
				return base + i*step
			}
			for i := -radius; i <= radius; i++ {
				o := at(i) * 4
				for k := 0; k < 4; k++ {
					sum[k] += in[o+k]
				}
			}
			for i := 0; i < n; i++ {
				o := (base + i*step) * 4
				for k := 0; k < 4; k++ {
					out[o+k] = sum[k] / cnt
				}
				add, rem := at(i+radius+1)*4, at(i-radius)*4
				for k := 0; k < 4; k++ {
					sum[k] += in[add+k] - in[rem+k]
				}
			}
		}
	}
	for i := 0; i < 3; i++ {
		pass(a, b, w, 0, 1, h, w)
		pass(b, a, h, 0, w, w, 1)
	}
	out := image.NewNRGBA(src.Rect)
	for i := 0; i < w*h; i++ {
		al := a[i*4+3] / 255
		if al > 0.0001 {
			out.Pix[i*4], out.Pix[i*4+1], out.Pix[i*4+2] = to8(a[i*4]/al/255), to8(a[i*4+1]/al/255), to8(a[i*4+2]/al/255)
		}
		out.Pix[i*4+3] = to8(al)
	}
	return out
}

func (d *Doc) adjust(c *Cmd) {
	li := d.idx(c.Layer)
	if li < 0 || d.Layers[li].Kind != "raster" {
		return
	}
	src := d.Layers[li].Img
	out := cloneImg(src)
	amt := c.Amount
	per := func(f func(r, g, b float64) (float64, float64, float64)) {
		for i := 0; i < len(out.Pix); i += 4 {
			r, g, b := f(float64(out.Pix[i])/255, float64(out.Pix[i+1])/255, float64(out.Pix[i+2])/255)
			out.Pix[i], out.Pix[i+1], out.Pix[i+2] = to8(float32(r)), to8(float32(g)), to8(float32(b))
		}
	}
	luma := func(r, g, b float64) float64 { return 0.299*r + 0.587*g + 0.114*b }
	switch c.Kind {
	case "invert":
		per(func(r, g, b float64) (float64, float64, float64) { return 1 - r, 1 - g, 1 - b })
	case "grayscale":
		per(func(r, g, b float64) (float64, float64, float64) { l := luma(r, g, b); return l, l, l })
	case "sepia":
		per(func(r, g, b float64) (float64, float64, float64) {
			l := luma(r, g, b)
			return l * 1.07, l * 0.74, l * 0.43
		})
	case "brightness":
		per(func(r, g, b float64) (float64, float64, float64) { return r + amt, g + amt, b + amt })
	case "contrast":
		k := math.Tan((amt + 1) * math.Pi / 4)
		per(func(r, g, b float64) (float64, float64, float64) {
			return (r-0.5)*k + 0.5, (g-0.5)*k + 0.5, (b-0.5)*k + 0.5
		})
	case "saturation":
		per(func(r, g, b float64) (float64, float64, float64) {
			l := luma(r, g, b)
			return l + (r-l)*(1+amt), l + (g-l)*(1+amt), l + (b-l)*(1+amt)
		})
	case "hue":
		per(func(r, g, b float64) (float64, float64, float64) {
			h, s, l := rgb2hsl(clampf(r, 0, 1), clampf(g, 0, 1), clampf(b, 0, 1))
			return hsl2rgb(math.Mod(h+amt/360+1, 1), s, l)
		})
	case "posterize":
		n := math.Max(2, math.Round(amt))
		q := func(v float64) float64 { return math.Round(clampf(v, 0, 1)*(n-1)) / (n - 1) }
		per(func(r, g, b float64) (float64, float64, float64) { return q(r), q(g), q(b) })
	case "noise":
		per(func(r, g, b float64) (float64, float64, float64) {
			n := (rand.Float64() - 0.5) * amt
			return r + n, g + n, b + n
		})
	case "blur":
		out = boxBlur(src, int(math.Max(1, amt)))
	case "sharpen":
		bl := boxBlur(src, 2)
		k := math.Max(0.1, amt)
		for i := 0; i < len(out.Pix); i += 4 {
			for j := 0; j < 3; j++ {
				out.Pix[i+j] = to8(float32((float64(src.Pix[i+j]) + (float64(src.Pix[i+j])-float64(bl.Pix[i+j]))*k) / 255))
			}
		}
	case "pixelate":
		n := int(math.Max(2, amt))
		for by := 0; by < d.H; by += n {
			for bx := 0; bx < d.W; bx += n {
				var s [4]int
				cnt := 0
				for y := by; y < by+n && y < d.H; y++ {
					for x := bx; x < bx+n && x < d.W; x++ {
						o := y*src.Stride + x*4
						al := int(src.Pix[o+3])
						s[0] += int(src.Pix[o]) * al
						s[1] += int(src.Pix[o+1]) * al
						s[2] += int(src.Pix[o+2]) * al
						s[3] += al
						cnt++
					}
				}
				var px [4]uint8
				if s[3] > 0 {
					px = [4]uint8{uint8(s[0] / s[3]), uint8(s[1] / s[3]), uint8(s[2] / s[3]), uint8(s[3] / cnt)}
				}
				for y := by; y < by+n && y < d.H; y++ {
					for x := bx; x < bx+n && x < d.W; x++ {
						copy(out.Pix[y*out.Stride+x*4:], px[:])
					}
				}
			}
		}
	default:
		return
	}
	b := d.Sel.bounds(d.W, d.H)
	dst := d.writable(li)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			m := d.Sel.at(x, y)
			o := y*dst.Stride + x*4
			if m >= 1 {
				copy(dst.Pix[o:o+4], out.Pix[o:o+4])
			} else if m > 0 {
				for k := 0; k < 4; k++ {
					dst.Pix[o+k] = to8((float32(src.Pix[o+k])*(1-m) + float32(out.Pix[o+k])*m) / 255)
				}
			}
		}
	}
	d.dirtyRect(b)
}

// ---- image-wide operations ----

func (d *Doc) transform(kind string, c *Cmd) bool {
	d.rasterizeAll()
	nw, nh := d.W, d.H
	var mapPix func(x, y int) (int, int) // destination x, y of a source pixel
	switch kind {
	case "flipH":
		mapPix = func(x, y int) (int, int) { return d.W - 1 - x, y }
	case "flipV":
		mapPix = func(x, y int) (int, int) { return x, d.H - 1 - y }
	case "rotate180":
		mapPix = func(x, y int) (int, int) { return d.W - 1 - x, d.H - 1 - y }
	case "rotate90":
		nw, nh = d.H, d.W
		mapPix = func(x, y int) (int, int) { return d.H - 1 - y, x }
	case "rotate270":
		nw, nh = d.H, d.W
		mapPix = func(x, y int) (int, int) { return y, d.W - 1 - x }
	case "crop":
		r := d.Sel.bounds(d.W, d.H)
		if c.W > 0 && c.H > 0 {
			r = image.Rect(c.X0i(), c.Y0i(), c.X0i()+c.W, c.Y0i()+c.H).Intersect(image.Rect(0, 0, d.W, d.H))
		}
		if r.Empty() {
			return false
		}
		nw, nh = r.Dx(), r.Dy()
		mapPix = func(x, y int) (int, int) { return x - r.Min.X, y - r.Min.Y }
	case "canvas":
		if c.W < 1 || c.H < 1 || c.W > 16000 || c.H > 16000 {
			return false
		}
		ox, oy := 0, 0
		switch c.Mode {
		case "center":
			ox, oy = (c.W-d.W)/2, (c.H-d.H)/2
		case "bottomright":
			ox, oy = c.W-d.W, c.H-d.H
		}
		nw, nh = c.W, c.H
		mapPix = func(x, y int) (int, int) { return x + ox, y + oy }
	case "resize":
		if c.W < 1 || c.H < 1 || c.W > 16000 || c.H > 16000 {
			return false
		}
		nw, nh = c.W, c.H
		for i := range d.Layers {
			d.Layers[i].Img = scaleImg(d.Layers[i].Img, nw, nh, c.Mode == "nearest")
		}
		d.afterResize(nw, nh)
		return true
	default:
		return false
	}
	for i := range d.Layers {
		src := d.Layers[i].Img
		dst := image.NewNRGBA(image.Rect(0, 0, nw, nh))
		for y := 0; y < d.H; y++ {
			for x := 0; x < d.W; x++ {
				tx, ty := mapPix(x, y)
				if tx < 0 || ty < 0 || tx >= nw || ty >= nh {
					continue
				}
				copy(dst.Pix[ty*dst.Stride+tx*4:ty*dst.Stride+tx*4+4], src.Pix[y*src.Stride+x*4:])
			}
		}
		d.Layers[i].Img = dst
	}
	if d.Sel != nil {
		n := newMask(nw, nh)
		for y := 0; y < d.H; y++ {
			for x := 0; x < d.W; x++ {
				tx, ty := mapPix(x, y)
				if tx >= 0 && ty >= 0 && tx < nw && ty < nh {
					n.A[ty*nw+tx] = d.Sel.A[y*d.W+x]
				}
			}
		}
		d.Sel = n.fit()
		if kind == "crop" {
			d.Sel = nil
		}
	}
	d.afterResize(nw, nh)
	return true
}

func (d *Doc) afterResize(nw, nh int) {
	if d.Sel != nil && (d.Sel.W != nw || d.Sel.H != nh) {
		d.Sel = nil
	}
	d.W, d.H = nw, nh
	d.comp = image.NewNRGBA(image.Rect(0, 0, nw, nh))
	d.selDirty = true
	d.dirtyAll()
}

func scaleImg(src *image.NRGBA, nw, nh int, nearest bool) *image.NRGBA {
	sw, sh := src.Rect.Dx(), src.Rect.Dy()
	dst := image.NewNRGBA(image.Rect(0, 0, nw, nh))
	at := func(x, y int) (float64, float64, float64, float64) {
		x, y = max(0, min(sw-1, x)), max(0, min(sh-1, y))
		o := y*src.Stride + x*4
		a := float64(src.Pix[o+3])
		return float64(src.Pix[o]) * a, float64(src.Pix[o+1]) * a, float64(src.Pix[o+2]) * a, a
	}
	for y := 0; y < nh; y++ {
		fy := (float64(y)+0.5)*float64(sh)/float64(nh) - 0.5
		for x := 0; x < nw; x++ {
			fx := (float64(x)+0.5)*float64(sw)/float64(nw) - 0.5
			o := y*dst.Stride + x*4
			if nearest {
				copy(dst.Pix[o:o+4], src.Pix[max(0, min(sh-1, int(fy+0.5)))*src.Stride+max(0, min(sw-1, int(fx+0.5)))*4:])
				continue
			}
			x0, y0 := int(math.Floor(fx)), int(math.Floor(fy))
			tx, ty := fx-float64(x0), fy-float64(y0)
			var acc [4]float64
			for j := 0; j < 2; j++ {
				for i := 0; i < 2; i++ {
					wgt := (1 - tx + float64(i)*(2*tx-1)) * (1 - ty + float64(j)*(2*ty-1))
					r, g, b, a := at(x0+i, y0+j)
					acc[0] += r * wgt
					acc[1] += g * wgt
					acc[2] += b * wgt
					acc[3] += a * wgt
				}
			}
			if acc[3] > 0 {
				dst.Pix[o], dst.Pix[o+1], dst.Pix[o+2], dst.Pix[o+3] = uint8(acc[0]/acc[3]+0.5), uint8(acc[1]/acc[3]+0.5), uint8(acc[2]/acc[3]+0.5), uint8(acc[3]+0.5)
			}
		}
	}
	return dst
}

func (d *Doc) flatten() {
	f := d.flat()
	d.rasterizeAll()
	l := d.newLayer("Background")
	l.Img = f
	d.Layers = []Layer{*l}
	d.Active = l.ID
	d.dirtyAll()
}

// ---- layers ----

func (d *Doc) layerOp(c *Cmd) {
	i := d.idx(c.Layer)
	switch c.Kind {
	case "add":
		l := d.newLayer(fmt.Sprintf("Layer %d", d.nextID))
		at := len(d.Layers) - 1
		if a := d.activeIdx(); a >= 0 {
			at = a
		}
		d.insertAbove(at, *l)
		d.Active = l.ID
		d.commit("Add layer", "add")
	case "dup":
		if i < 0 {
			return
		}
		l := d.Layers[i]
		d.nextID++
		l.ID, l.Name = d.nextID, l.Name+" copy"
		d.insertAbove(i, l)
		d.Active = l.ID
		d.commit("Duplicate layer", "content_copy")
	case "delete":
		if i < 0 {
			return
		}
		if len(d.Layers) == 1 {
			d.Layers[0].Img = image.NewNRGBA(image.Rect(0, 0, d.W, d.H))
			d.Layers[0].Kind, d.Layers[0].Props, d.Layers[0].TextImg = "raster", nil, nil
		} else {
			d.Layers = append(d.Layers[:i], d.Layers[i+1:]...)
			d.Active = d.Layers[max(0, i-1)].ID
		}
		d.commit("Delete layer", "delete")
	case "up", "down":
		j := i + 1
		if c.Kind == "down" {
			j = i - 1
		}
		if i < 0 || j < 0 || j >= len(d.Layers) {
			return
		}
		d.Layers[i], d.Layers[j] = d.Layers[j], d.Layers[i]
		d.commit("Move layer", "swap_vert")
	case "move":
		if i < 0 || c.To < 0 || c.To >= len(d.Layers) || c.To == i {
			return
		}
		l := d.Layers[i]
		d.Layers = append(d.Layers[:i], d.Layers[i+1:]...)
		d.Layers = append(d.Layers, Layer{})
		copy(d.Layers[c.To+1:], d.Layers[c.To:])
		d.Layers[c.To] = l
		d.commit("Move layer", "swap_vert")
	case "merge":
		if i <= 0 {
			return
		}
		d.rasterize(i)
		d.rasterize(i - 1)
		below := d.writable(i - 1)
		top := d.Layers[i]
		tmp := &Doc{docState: docState{W: d.W, H: d.H, Layers: []Layer{d.Layers[i-1], top}}, comp: image.NewNRGBA(image.Rect(0, 0, d.W, d.H))}
		tmp.Layers[0].Visible = true
		tmp.Layers[0].Opacity = 1
		tmp.Layers[0].Blend = "normal"
		tmp.recomp(tmp.comp.Rect)
		copy(below.Pix, tmp.comp.Pix)
		d.Layers = append(d.Layers[:i], d.Layers[i+1:]...)
		d.Active = d.Layers[i-1].ID
		d.commit("Merge layer down", "merge")
	case "select":
		if i >= 0 {
			d.Active = c.Layer
		}
		return
	case "set":
		if i < 0 {
			return
		}
		l := &d.Layers[i]
		label := "Layer properties"
		if c.Name != nil {
			l.Name, label = *c.Name, "Rename layer"
		}
		if c.Visible != nil {
			l.Visible, label = *c.Visible, "Layer visibility"
		}
		if c.Opacity != nil {
			l.Opacity, label = clampf(*c.Opacity, 0, 1), "Layer opacity"
		}
		if c.Blend != nil {
			l.Blend, label = *c.Blend, "Layer blend mode"
		}
		d.dirtyAll()
		if c.Final {
			d.commit(label, "tune")
		}
		return
	default:
		return
	}
	d.dirtyAll()
}

// ---- text layers ----

func (d *Doc) textNew(c *Cmd) {
	l := d.newLayer("Text")
	l.Kind, l.Img = "text", nil
	l.X, l.Y = c.X0i(), c.Y0i()
	l.Props = c.Props
	at := len(d.Layers) - 1
	if a := d.activeIdx(); a >= 0 {
		at = a
	}
	d.insertAbove(at, *l)
	d.Active = l.ID
	d.editing = l.ID
}

func (d *Doc) textSet(c *Cmd) {
	i := d.idx(c.Layer)
	if i < 0 || d.Layers[i].Kind != "text" {
		return
	}
	l := &d.Layers[i]
	l.Props = c.Props
	l.X, l.Y = c.X0i(), c.Y0i()
	if c.Path != "" {
		if img, err := loadImage(c.Path); err == nil {
			l.TextImg = img
		}
	}
	if c.Name != nil {
		l.Name = *c.Name
	}
	if d.editing == l.ID {
		d.editing = 0
	}
	d.dirtyAll()
	d.commit("Text", "title")
}

func (d *Doc) textDiscard(id int) {
	i := d.idx(id)
	if i < 0 || d.Layers[i].Kind != "text" {
		return
	}
	d.Layers = append(d.Layers[:i], d.Layers[i+1:]...)
	if len(d.Layers) == 0 {
		return
	}
	d.Active = d.Layers[max(0, i-1)].ID
	d.editing = 0
	d.dirtyAll()
}

// ---- edit ----

func (d *Doc) copySel(i int) *image.NRGBA {
	l := &d.Layers[i]
	px := d.layerPixels(l)
	b := d.Sel.bounds(d.W, d.H)
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			o := y*px.Stride + x*4
			p := out.Pix[(y-b.Min.Y)*out.Stride+(x-b.Min.X)*4:]
			copy(p[:4], px.Pix[o:o+4])
			p[3] = to8(float32(px.Pix[o+3]) / 255 * d.Sel.at(x, y))
		}
	}
	return out
}

func (d *Doc) clearSel(i int, col *rgba) {
	d.rasterize(i)
	img := d.writable(i)
	b := d.Sel.bounds(d.W, d.H)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			m := d.Sel.at(x, y)
			if m <= 0 {
				continue
			}
			o := y*img.Stride + x*4
			if col != nil {
				overPix(img.Pix[o:o+4], col.R, col.G, col.B, float32(col.A)/255*m)
			} else {
				img.Pix[o+3] = to8(float32(img.Pix[o+3]) / 255 * (1 - m))
			}
		}
	}
	d.dirtyRect(b)
}

func (d *Doc) pasteImage(img *image.NRGBA, ox, oy int) {
	l := d.newLayer("Pasted")
	blit(l.Img, img, ox, oy)
	at := len(d.Layers) - 1
	if a := d.activeIdx(); a >= 0 {
		at = a
	}
	d.insertAbove(at, *l)
	d.Active = l.ID
	m := newMask(d.W, d.H)
	for y := 0; y < img.Rect.Dy(); y++ {
		for x := 0; x < img.Rect.Dx(); x++ {
			tx, ty := x+ox, y+oy
			if tx >= 0 && ty >= 0 && tx < d.W && ty < d.H {
				m.A[ty*d.W+tx] = 255
			}
		}
	}
	d.Sel = m.fit()
	d.selDirty = true
	d.dirtyAll()
	d.commit("Paste", "content_paste")
}
