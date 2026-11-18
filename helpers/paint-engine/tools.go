package main

import (
	"image"
	"math"
	"strconv"
)

type rgba struct{ R, G, B, A uint8 }

func parseColor(s string) rgba {
	c := rgba{0, 0, 0, 255}
	if len(s) > 0 && s[0] == '#' {
		s = s[1:]
	}
	if len(s) != 6 && len(s) != 8 {
		return c
	}
	v, err := strconv.ParseUint(s, 16, 32)
	if err != nil {
		return c
	}
	if len(s) == 6 {
		return rgba{uint8(v >> 16), uint8(v >> 8), uint8(v), 255}
	}
	return rgba{uint8(v >> 24), uint8(v >> 16), uint8(v >> 8), uint8(v)}
}

func clampf(v, lo, hi float64) float64 { return math.Max(lo, math.Min(hi, v)) }

func (m *Mask) at(x, y int) float32 {
	if m == nil {
		return 1
	}
	if x < 0 || y < 0 || x >= m.W || y >= m.H {
		return 0
	}
	return float32(m.A[y*m.W+x]) / 255
}

func (m *Mask) bounds(w, h int) image.Rectangle {
	if m == nil {
		return image.Rect(0, 0, w, h)
	}
	return image.Rect(m.X0, m.Y0, m.X1, m.Y1)
}

func newMask(w, h int) *Mask { return &Mask{W: w, H: h, A: make([]uint8, w*h)} }

func (m *Mask) fit() *Mask {
	x0, y0, x1, y1 := m.W, m.H, 0, 0
	for y := 0; y < m.H; y++ {
		row := m.A[y*m.W : (y+1)*m.W]
		for x, v := range row {
			if v != 0 {
				if x < x0 {
					x0 = x
				}
				if x+1 > x1 {
					x1 = x + 1
				}
				if y < y0 {
					y0 = y
				}
				if y+1 > y1 {
					y1 = y + 1
				}
			}
		}
	}
	if x1 == 0 {
		return nil
	}
	m.X0, m.Y0, m.X1, m.Y1 = x0, y0, x1, y1
	return m
}

// combine merges a new selection into the old one: replace, add, subtract or intersect.
func combine(old, n *Mask, mode string) *Mask {
	if n == nil {
		if mode == "replace" {
			return nil
		}
		return old
	}
	if old == nil || mode == "replace" || mode == "" {
		if mode == "subtract" || mode == "intersect" {
			return old
		}
		return n.fit()
	}
	for i := range n.A {
		a, b := old.A[i], n.A[i]
		switch mode {
		case "add":
			if b > a {
				a = b
			}
		case "subtract":
			a = uint8(uint32(a) * uint32(255-b) / 255)
		case "intersect":
			a = uint8(uint32(a) * uint32(b) / 255)
		}
		n.A[i] = a
	}
	return n.fit()
}

func polyMask(w, h int, pts [][2]float64) *Mask {
	m := newMask(w, h)
	fillPoly(pts, w, h, func(x, y int, c float32) {
		if c >= 0.5 {
			m.A[y*w+x] = 255
		}
	})
	return m
}

func rectMask(w, h int, x0, y0, x1, y1 float64) *Mask {
	m := newMask(w, h)
	ix0, iy0 := int(math.Max(0, math.Round(math.Min(x0, x1)))), int(math.Max(0, math.Round(math.Min(y0, y1))))
	ix1, iy1 := int(math.Min(float64(w), math.Round(math.Max(x0, x1)))), int(math.Min(float64(h), math.Round(math.Max(y0, y1))))
	for y := iy0; y < iy1; y++ {
		for x := ix0; x < ix1; x++ {
			m.A[y*w+x] = 255
		}
	}
	return m
}

func ellipseMask(w, h int, x0, y0, x1, y1 float64) *Mask {
	m := newMask(w, h)
	cx, cy := (x0+x1)/2, (y0+y1)/2
	rx, ry := math.Abs(x1-x0)/2, math.Abs(y1-y0)/2
	if rx < 0.5 || ry < 0.5 {
		return m
	}
	for y := int(math.Max(0, cy-ry)); y < h && float64(y) <= cy+ry; y++ {
		for x := int(math.Max(0, cx-rx)); x < w && float64(x) <= cx+rx; x++ {
			dx, dy := (float64(x)+0.5-cx)/rx, (float64(y)+0.5-cy)/ry
			if dx*dx+dy*dy <= 1 {
				m.A[y*w+x] = 255
			}
		}
	}
	return m
}

func (m *Mask) shifted(dx, dy int) *Mask {
	n := newMask(m.W, m.H)
	for y := 0; y < m.H; y++ {
		ny := y + dy
		if ny < 0 || ny >= m.H {
			continue
		}
		for x := 0; x < m.W; x++ {
			nx := x + dx
			if nx >= 0 && nx < m.W {
				n.A[ny*m.W+nx] = m.A[y*m.W+x]
			}
		}
	}
	return n.fit()
}

func (m *Mask) inverted() *Mask {
	n := newMask(m.W, m.H)
	for i, v := range m.A {
		n.A[i] = 255 - v
	}
	return n.fit()
}

// fillPoly scans a polygon (even-odd) with 4 sub-scanlines and exact horizontal coverage.
func fillPoly(pts [][2]float64, w, h int, put func(x, y int, c float32)) {
	if len(pts) < 3 {
		return
	}
	minY, maxY := math.Inf(1), math.Inf(-1)
	for _, p := range pts {
		minY, maxY = math.Min(minY, p[1]), math.Max(maxY, p[1])
	}
	y0, y1 := int(math.Max(0, math.Floor(minY))), int(math.Min(float64(h-1), math.Ceil(maxY)))
	const ss = 4
	acc := make([]float32, w)
	for y := y0; y <= y1; y++ {
		for i := range acc {
			acc[i] = 0
		}
		touched := false
		for s := 0; s < ss; s++ {
			sy := float64(y) + (float64(s)+0.5)/ss
			var xs []float64
			for i := range pts {
				a, b := pts[i], pts[(i+1)%len(pts)]
				if (a[1] <= sy) == (b[1] <= sy) {
					continue
				}
				xs = append(xs, a[0]+(sy-a[1])/(b[1]-a[1])*(b[0]-a[0]))
			}
			for i := 1; i < len(xs); i++ {
				for j := i; j > 0 && xs[j] < xs[j-1]; j-- {
					xs[j], xs[j-1] = xs[j-1], xs[j]
				}
			}
			for i := 0; i+1 < len(xs); i += 2 {
				l, r := math.Max(0, xs[i]), math.Min(float64(w), xs[i+1])
				if r <= l {
					continue
				}
				touched = true
				for x := int(l); x < w && float64(x) < r; x++ {
					acc[x] += float32(math.Min(float64(x+1), r)-math.Max(float64(x), l)) / ss
				}
			}
		}
		if touched {
			for x, v := range acc {
				if v > 0 {
					put(x, y, v)
				}
			}
		}
	}
}

// ---- flood fill ----

func match(p []uint8, o int, sr, sg, sb, sa uint8, tol int) bool {
	d := func(a, b uint8) int {
		if a > b {
			return int(a - b)
		}
		return int(b - a)
	}
	return d(p[o], sr) <= tol && d(p[o+1], sg) <= tol && d(p[o+2], sb) <= tol && d(p[o+3], sa) <= tol
}

// flood returns a mask of the pixels like the one at (sx, sy): the connected ones, or all of them.
func flood(img *image.NRGBA, sx, sy int, tol float64, contiguous bool, sel *Mask) *Mask {
	w, h := img.Rect.Dx(), img.Rect.Dy()
	m := newMask(w, h)
	if sx < 0 || sy < 0 || sx >= w || sy >= h || sel.at(sx, sy) == 0 {
		return m
	}
	t := int(clampf(tol, 0, 1) * 255)
	so := sy*img.Stride + sx*4
	r, g, b, a := img.Pix[so], img.Pix[so+1], img.Pix[so+2], img.Pix[so+3]
	ok := func(x, y int) bool {
		return sel.at(x, y) > 0 && match(img.Pix, y*img.Stride+x*4, r, g, b, a, t)
	}
	if !contiguous {
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				if ok(x, y) {
					m.A[y*w+x] = 255
				}
			}
		}
		return m
	}
	stack := [][2]int{{sx, sy}}
	for len(stack) > 0 {
		p := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		x, y := p[0], p[1]
		if m.A[y*w+x] != 0 || !ok(x, y) {
			continue
		}
		l, rr := x, x
		for l > 0 && m.A[y*w+l-1] == 0 && ok(l-1, y) {
			l--
		}
		for rr < w-1 && m.A[y*w+rr+1] == 0 && ok(rr+1, y) {
			rr++
		}
		for i := l; i <= rr; i++ {
			m.A[y*w+i] = 255
		}
		for _, ny := range []int{y - 1, y + 1} {
			if ny < 0 || ny >= h {
				continue
			}
			in := false
			for i := l; i <= rr; i++ {
				if m.A[ny*w+i] == 0 && ok(i, ny) {
					if !in {
						stack = append(stack, [2]int{i, ny})
						in = true
					}
				} else {
					in = false
				}
			}
		}
	}
	return m
}

// ---- strokes ----

type stroke struct {
	tool        string
	li          int
	base, cur   *image.NRGBA
	cov         []uint8
	size, hard  float64
	step        float64
	col, col2   rgba
	aa          bool
	lx, ly, rem float64
	ox, oy      float64
	tol         int
	dirty       image.Rectangle
	sel         *Mask
	w, h        int
}

func (d *Doc) strokeBegin(c *Cmd) {
	li := d.idx(c.Layer)
	if li < 0 || d.Layers[li].Kind != "raster" {
		return
	}
	s := &stroke{tool: c.Kind, li: li, base: d.Layers[li].Img, w: d.W, h: d.H}
	s.cur = d.writable(li)
	s.cov = make([]uint8, d.W*d.H)
	s.size, s.hard = math.Max(1, c.Size), clampf(c.Hardness, 0, 1)
	s.col, s.col2, s.aa = parseColor(c.Color), parseColor(c.Color2), c.AA
	s.ox, s.oy, s.tol = c.OX, c.OY, int(clampf(c.Tol, 0, 1)*255)
	s.sel = d.Sel
	step := s.size * c.Spacing
	if c.Kind == "pencil" {
		s.hard, s.aa, step = 1, false, 0.5
	}
	s.step = math.Max(0.5, step)
	d.stroke = s
	s.stamp(d, c.X, c.Y)
	s.lx, s.ly, s.rem = c.X, c.Y, s.step
}

func (d *Doc) strokeMove(c *Cmd) {
	s := d.stroke
	if s == nil {
		return
	}
	dx, dy := c.X-s.lx, c.Y-s.ly
	l := math.Hypot(dx, dy)
	if l == 0 {
		return
	}
	pos := s.rem
	for pos <= l {
		s.stamp(d, s.lx+dx*pos/l, s.ly+dy*pos/l)
		pos += s.step
	}
	s.rem = pos - l
	s.lx, s.ly = c.X, c.Y
}

func (d *Doc) strokeEnd(label, icon string) {
	if d.stroke == nil {
		return
	}
	d.stroke = nil
	d.commit(label, icon)
}

func (s *stroke) stamp(d *Doc, x, y float64) {
	r := s.size / 2
	x0, y0 := int(math.Max(0, math.Floor(x-r-1))), int(math.Max(0, math.Floor(y-r-1)))
	x1, y1 := int(math.Min(float64(s.w), math.Ceil(x+r+1))), int(math.Min(float64(s.h), math.Ceil(y+r+1)))
	if s.tool == "pencil" && s.size <= 1.5 {
		x0, y0, x1, y1 = int(math.Floor(x)), int(math.Floor(y)), int(math.Floor(x))+1, int(math.Floor(y))+1
		x0, y0 = int(math.Max(0, float64(x0))), int(math.Max(0, float64(y0)))
		x1, y1 = int(math.Min(float64(s.w), float64(x1))), int(math.Min(float64(s.h), float64(y1)))
		for py := y0; py < y1; py++ {
			for px := x0; px < x1; px++ {
				s.cov[py*s.w+px] = 255
				s.apply(px, py)
			}
		}
		s.mark(x0, y0, x1, y1)
		return
	}
	inner := r * s.hard
	for py := y0; py < y1; py++ {
		for px := x0; px < x1; px++ {
			dist := math.Hypot(float64(px)+0.5-x, float64(py)+0.5-y)
			var c float64
			switch {
			case s.hard >= 0.999 && s.aa:
				c = clampf(r-dist+0.5, 0, 1)
			case s.hard >= 0.999:
				if dist <= r {
					c = 1
				}
			case dist <= inner:
				c = 1
			case dist < r:
				t := 1 - (dist-inner)/(r-inner)
				c = t * t * (3 - 2*t)
			}
			if c <= 0 {
				continue
			}
			v := uint8(c*255 + 0.5)
			i := py*s.w + px
			if v > s.cov[i] {
				s.cov[i] = v
				s.apply(px, py)
			}
		}
	}
	s.mark(x0, y0, x1, y1)
}

func (s *stroke) mark(x0, y0, x1, y1 int) {
	r := image.Rect(x0, y0, x1, y1)
	if s.dirty.Empty() {
		s.dirty = r
	} else {
		s.dirty = s.dirty.Union(r)
	}
}

func (s *stroke) apply(x, y int) {
	e := float32(s.cov[y*s.w+x]) / 255 * s.sel.at(x, y)
	o := y*s.base.Stride + x*4
	b := s.base.Pix[o : o+4]
	p := s.cur.Pix[o : o+4]
	copy(p, b)
	if e <= 0 {
		return
	}
	switch s.tool {
	case "eraser":
		p[3] = to8(float32(b[3]) / 255 * (1 - e))
	case "recolor":
		if match(b, 0, s.col2.R, s.col2.G, s.col2.B, 255, s.tol) || (b[3] > 0 && match(b, 0, s.col2.R, s.col2.G, s.col2.B, b[3], s.tol)) {
			p[0] = to8(float32(b[0])/255*(1-e) + float32(s.col.R)/255*e)
			p[1] = to8(float32(b[1])/255*(1-e) + float32(s.col.G)/255*e)
			p[2] = to8(float32(b[2])/255*(1-e) + float32(s.col.B)/255*e)
		}
	case "clone":
		sx, sy := x+int(s.ox), y+int(s.oy)
		if sx >= 0 && sy >= 0 && sx < s.w && sy < s.h {
			so := sy*s.base.Stride + sx*4
			overPix(p, s.base.Pix[so], s.base.Pix[so+1], s.base.Pix[so+2], float32(s.base.Pix[so+3])/255*e)
		}
	default:
		overPix(p, s.col.R, s.col.G, s.col.B, float32(s.col.A)/255*e)
	}
}

// ---- gradient and fill ----

func (d *Doc) paintMask(li int, m *Mask, col rgba) {
	img := d.writable(li)
	b := d.Sel.bounds(d.W, d.H)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			e := float32(m.A[y*d.W+x]) / 255 * d.Sel.at(x, y)
			if e > 0 {
				o := y*img.Stride + x*4
				overPix(img.Pix[o:o+4], col.R, col.G, col.B, float32(col.A)/255*e)
			}
		}
	}
	d.dirtyRect(b)
}

func lerpCol(a, b rgba, t float64) rgba {
	f := func(x, y uint8) uint8 { return uint8(float64(x) + (float64(y)-float64(x))*t + 0.5) }
	return rgba{f(a.R, b.R), f(a.G, b.G), f(a.B, b.B), f(a.A, b.A)}
}

func (d *Doc) gradient(c *Cmd) {
	li := d.idx(c.Layer)
	if li < 0 || d.Layers[li].Kind != "raster" {
		return
	}
	img := d.writable(li)
	c0, c1 := parseColor(c.Color), parseColor(c.Color2)
	dx, dy := c.X1-c.X0, c.Y1-c.Y0
	l2 := dx*dx + dy*dy
	if l2 == 0 {
		return
	}
	l := math.Sqrt(l2)
	b := d.Sel.bounds(d.W, d.H)
	for y := b.Min.Y; y < b.Max.Y; y++ {
		for x := b.Min.X; x < b.Max.X; x++ {
			e := d.Sel.at(x, y)
			if e == 0 {
				continue
			}
			px, py := float64(x)+0.5-c.X0, float64(y)+0.5-c.Y0
			var t float64
			switch c.Mode {
			case "radial":
				t = math.Hypot(px, py) / l
			case "diamond":
				t = (math.Abs(px*dx+py*dy) + math.Abs(px*dy-py*dx)) / l2
			case "conical":
				t = math.Mod(math.Atan2(py, px)-math.Atan2(dy, dx)+4*math.Pi, 2*math.Pi) / (2 * math.Pi)
			case "reflected":
				t = math.Abs((px*dx + py*dy) / l2)
			default:
				t = (px*dx + py*dy) / l2
			}
			col := lerpCol(c0, c1, clampf(t, 0, 1))
			o := y*img.Stride + x*4
			overPix(img.Pix[o:o+4], col.R, col.G, col.B, float32(col.A)/255*e)
		}
	}
	d.dirtyRect(b)
}

// ---- shapes ----

func bezier(p0, p1, p2, p3 [2]float64, n int) [][2]float64 {
	out := make([][2]float64, 0, n+1)
	for i := 0; i <= n; i++ {
		t := float64(i) / float64(n)
		u := 1 - t
		out = append(out, [2]float64{
			u*u*u*p0[0] + 3*u*u*t*p1[0] + 3*u*t*t*p2[0] + t*t*t*p3[0],
			u*u*u*p0[1] + 3*u*u*t*p1[1] + 3*u*t*t*p2[1] + t*t*t*p3[1],
		})
	}
	return out
}

func regularPoly(x0, y0, x1, y1 float64, n int, star bool) [][2]float64 {
	cx, cy := (x0+x1)/2, (y0+y1)/2
	rx, ry := math.Abs(x1-x0)/2, math.Abs(y1-y0)/2
	var pts [][2]float64
	cnt := n
	if star {
		cnt = n * 2
	}
	for i := 0; i < cnt; i++ {
		a := -math.Pi/2 + 2*math.Pi*float64(i)/float64(cnt)
		k := 1.0
		if star && i%2 == 1 {
			k = 0.42
		}
		pts = append(pts, [2]float64{cx + math.Cos(a)*rx*k, cy + math.Sin(a)*ry*k})
	}
	return pts
}

func shapePath(c *Cmd) (pts [][2]float64, closed bool) {
	x0, y0, x1, y1 := c.X0, c.Y0, c.X1, c.Y1
	switch c.Kind {
	case "line":
		return [][2]float64{{x0, y0}, {x1, y1}}, false
	case "curve":
		return bezier([2]float64{x0, y0}, [2]float64{c.CX, c.CY}, [2]float64{c.C2X, c.C2Y}, [2]float64{x1, y1}, 64), false
	case "rect":
		return [][2]float64{{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}}, true
	case "rrect":
		lx, hx := math.Min(x0, x1), math.Max(x0, x1)
		ly, hy := math.Min(y0, y1), math.Max(y0, y1)
		r := math.Min(math.Max(c.Radius, 0), math.Min(hx-lx, hy-ly)/2)
		corner := func(cx, cy, a0 float64) {
			for i := 0; i <= 12; i++ {
				a := a0 + math.Pi/2*float64(i)/12
				pts = append(pts, [2]float64{cx + math.Cos(a)*r, cy + math.Sin(a)*r})
			}
		}
		corner(hx-r, ly+r, -math.Pi/2)
		corner(hx-r, hy-r, 0)
		corner(lx+r, hy-r, math.Pi/2)
		corner(lx+r, ly+r, math.Pi)
		return pts, true
	case "ellipse":
		return regularPoly(x0, y0, x1, y1, 160, false), true
	case "triangle":
		return [][2]float64{{(x0 + x1) / 2, y0}, {x1, y1}, {x0, y1}}, true
	case "diamond":
		return regularPoly(x0, y0, x1, y1, 4, false), true
	case "pentagon":
		return regularPoly(x0, y0, x1, y1, 5, false), true
	case "hexagon":
		return regularPoly(x0, y0, x1, y1, 6, false), true
	case "star":
		return regularPoly(x0, y0, x1, y1, 5, true), true
	}
	return nil, false
}

func (d *Doc) shape(c *Cmd) {
	li := d.idx(c.Layer)
	if li < 0 || d.Layers[li].Kind != "raster" {
		return
	}
	pts, closed := shapePath(c)
	if len(pts) < 2 {
		return
	}
	w, h := d.W, d.H
	col, col2 := parseColor(c.Color), parseColor(c.Color2)
	hw := math.Max(0.5, c.Width/2)
	minX, minY, maxX, maxY := math.Inf(1), math.Inf(1), math.Inf(-1), math.Inf(-1)
	for _, p := range pts {
		minX, maxX = math.Min(minX, p[0]), math.Max(maxX, p[0])
		minY, maxY = math.Min(minY, p[1]), math.Max(maxY, p[1])
	}
	pad := hw + 2
	bb := image.Rect(int(minX-pad), int(minY-pad), int(maxX+pad)+1, int(maxY+pad)+1).Intersect(image.Rect(0, 0, w, h))
	if bb.Empty() {
		return
	}
	img := d.writable(li)
	paint := func(cov []float32, col rgba) {
		for y := bb.Min.Y; y < bb.Max.Y; y++ {
			for x := bb.Min.X; x < bb.Max.X; x++ {
				v := cov[y*w+x]
				if v <= 0 {
					continue
				}
				if !c.AA {
					if v < 0.5 {
						continue
					}
					v = 1
				}
				e := v * d.Sel.at(x, y)
				o := y*img.Stride + x*4
				overPix(img.Pix[o:o+4], col.R, col.G, col.B, float32(col.A)/255*e)
			}
		}
	}
	if closed && (c.Fill == "fill" || c.Fill == "both") {
		cov := make([]float32, w*h)
		fillPoly(pts, w, h, func(x, y int, v float32) { cov[y*w+x] = v })
		fc := col
		if c.Fill == "both" {
			fc = col2
		}
		paint(cov, fc)
	}
	if !closed || c.Fill != "fill" {
		cov := make([]float32, w*h)
		n := len(pts) - 1
		if closed {
			n = len(pts)
		}
		for i := 0; i < n; i++ {
			a, b := pts[i], pts[(i+1)%len(pts)]
			sx0, sy0 := int(math.Min(a[0], b[0])-pad), int(math.Min(a[1], b[1])-pad)
			sx1, sy1 := int(math.Max(a[0], b[0])+pad)+1, int(math.Max(a[1], b[1])+pad)+1
			r := image.Rect(sx0, sy0, sx1, sy1).Intersect(bb)
			vx, vy := b[0]-a[0], b[1]-a[1]
			l2 := vx*vx + vy*vy
			for y := r.Min.Y; y < r.Max.Y; y++ {
				for x := r.Min.X; x < r.Max.X; x++ {
					px, py := float64(x)+0.5-a[0], float64(y)+0.5-a[1]
					t := 0.0
					if l2 > 0 {
						t = clampf((px*vx+py*vy)/l2, 0, 1)
					}
					dist := math.Hypot(px-vx*t, py-vy*t)
					v := float32(clampf(hw-dist+0.5, 0, 1))
					if v > cov[y*w+x] {
						cov[y*w+x] = v
					}
				}
			}
		}
		paint(cov, col)
	}
	d.dirtyRect(bb)
}

// ---- move ----

type lift struct {
	li     int
	base   *image.NRGBA
	float  *image.NRGBA
	mask   *Mask
	dx, dy int
}

func (d *Doc) moveBegin(layer int) {
	li := d.idx(layer)
	if li < 0 || d.Layers[li].Kind != "raster" {
		return
	}
	src := d.Layers[li].Img
	base, fl := image.NewNRGBA(src.Rect), image.NewNRGBA(src.Rect)
	for y := 0; y < d.H; y++ {
		for x := 0; x < d.W; x++ {
			o := y*src.Stride + x*4
			m := d.Sel.at(x, y)
			copy(fl.Pix[o:o+4], src.Pix[o:o+4])
			fl.Pix[o+3] = to8(float32(src.Pix[o+3]) / 255 * m)
			copy(base.Pix[o:o+4], src.Pix[o:o+4])
			base.Pix[o+3] = to8(float32(src.Pix[o+3]) / 255 * (1 - m))
		}
	}
	d.lift = &lift{li: li, base: base, float: fl, mask: d.Sel}
}

func (d *Doc) moveTo(dx, dy int) {
	l := d.lift
	if l == nil || (dx == l.dx && dy == l.dy) {
		return
	}
	l.dx, l.dy = dx, dy
	img := cloneImg(l.base)
	d.fresh[img] = true
	blit(img, l.float, dx, dy)
	d.Layers[l.li].Img = img
	if l.mask != nil {
		d.Sel = l.mask.shifted(dx, dy)
		d.selDirty = true
	}
	d.dirtyAll()
}

func (d *Doc) moveEnd() {
	if d.lift == nil {
		return
	}
	moved := d.lift.dx != 0 || d.lift.dy != 0
	d.lift = nil
	if moved {
		d.commit("Move selected pixels", "open_with")
	}
}
