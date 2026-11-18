package main

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/gif"
	"image/jpeg"
	"image/png"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func toNRGBA(src image.Image) *image.NRGBA {
	if n, ok := src.(*image.NRGBA); ok && n.Rect.Min == (image.Point{}) {
		return n
	}
	b := src.Bounds()
	out := image.NewNRGBA(image.Rect(0, 0, b.Dx(), b.Dy()))
	draw.Draw(out, out.Rect, src, b.Min, draw.Src)
	return out
}

func loadImage(path string) (*image.NRGBA, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	img, _, err := image.Decode(f)
	if err != nil {
		return nil, err
	}
	return toNRGBA(img), nil
}

func encodePNG(w io.Writer, img image.Image) error {
	return (&png.Encoder{CompressionLevel: png.BestSpeed}).Encode(w, img)
}

func writeFileAtomic(path string, fn func(w io.Writer) error) error {
	tmp := path + ".tmp"
	f, err := os.Create(tmp)
	if err != nil {
		return err
	}
	if err = fn(f); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// ---- export ----

func (d *Doc) save(path string, quality int) error {
	ext := strings.ToLower(filepath.Ext(path))
	if ext == ".ora" {
		return d.saveORA(path)
	}
	flat := d.flat()
	return writeFileAtomic(path, func(w io.Writer) error {
		switch ext {
		case ".jpg", ".jpeg":
			bg := image.NewRGBA(flat.Rect)
			draw.Draw(bg, bg.Rect, image.White, image.Point{}, draw.Src)
			draw.Draw(bg, bg.Rect, flat, image.Point{}, draw.Over)
			if quality <= 0 {
				quality = 92
			}
			return jpeg.Encode(w, bg, &jpeg.Options{Quality: quality})
		case ".gif":
			pal := image.NewPaletted(flat.Rect, palette256())
			draw.FloydSteinberg.Draw(pal, pal.Rect, flat, image.Point{})
			return gif.Encode(w, pal, nil)
		case ".png":
			return png.Encode(w, flat)
		}
		return fmt.Errorf("unknown format %q (use .png, .jpg, .gif or .ora)", ext)
	})
}

func palette256() color.Palette {
	var p color.Palette
	for r := 0; r < 6; r++ {
		for g := 0; g < 6; g++ {
			for b := 0; b < 6; b++ {
				p = append(p, color.RGBA{uint8(r * 51), uint8(g * 51), uint8(b * 51), 255})
			}
		}
	}
	for i := 0; i < 40; i++ {
		v := uint8(i * 255 / 39)
		p = append(p, color.RGBA{v, v, v, 255})
	}
	return p
}

// ---- OpenRaster (.ora), with the text of a text layer kept in extra attributes ----

type oraLayer struct {
	Name  string  `xml:"name,attr"`
	Src   string  `xml:"src,attr"`
	X     int     `xml:"x,attr"`
	Y     int     `xml:"y,attr"`
	Vis   string  `xml:"visibility,attr"`
	Op    float64 `xml:"opacity,attr"`
	Comp  string  `xml:"composite-op,attr"`
	Kind  string  `xml:"qs-kind,attr"`
	Props string  `xml:"qs-props,attr"`
}

type oraStack struct {
	Layers []oraLayer `xml:"layer"`
	Stacks []oraStack `xml:"stack"`
}

type oraImage struct {
	W     int      `xml:"w,attr"`
	H     int      `xml:"h,attr"`
	Stack oraStack `xml:"stack"`
}

var oraBlend = map[string]string{"normal": "svg:src-over", "multiply": "svg:multiply", "screen": "svg:screen", "overlay": "svg:overlay", "darken": "svg:darken", "lighten": "svg:lighten", "add": "svg:plus", "difference": "svg:difference"}

func (d *Doc) saveORA(path string) error {
	return writeFileAtomic(path, func(w io.Writer) error {
		zw := zip.NewWriter(w)
		mt, _ := zw.CreateHeader(&zip.FileHeader{Name: "mimetype", Method: zip.Store})
		mt.Write([]byte("image/openraster"))
		var sb strings.Builder
		fmt.Fprintf(&sb, `<?xml version="1.0" encoding="UTF-8"?>`+"\n"+`<image version="0.0.3" w="%d" h="%d"><stack>`, d.W, d.H)
		for i := len(d.Layers) - 1; i >= 0; i-- {
			l := d.Layers[i]
			img, x, y := l.Img, 0, 0
			if l.Kind == "text" {
				img, x, y = l.TextImg, l.X, l.Y
				if img == nil {
					img = image.NewNRGBA(image.Rect(0, 0, 1, 1))
				}
			}
			name := fmt.Sprintf("data/layer%d.png", l.ID)
			fw, err := zw.Create(name)
			if err != nil {
				return err
			}
			if err = png.Encode(fw, img); err != nil {
				return err
			}
			vis := "visible"
			if !l.Visible {
				vis = "hidden"
			}
			op := oraBlend[l.Blend]
			if op == "" {
				op = "svg:src-over"
			}
			extra := ""
			if l.Kind == "text" {
				extra = fmt.Sprintf(` qs-kind="text" qs-props="%s"`, xmlEsc(string(l.Props)))
			}
			fmt.Fprintf(&sb, `<layer name="%s" src="%s" x="%d" y="%d" visibility="%s" opacity="%s" composite-op="%s"%s/>`,
				xmlEsc(l.Name), name, x, y, vis, strconv.FormatFloat(l.Opacity, 'f', 3, 64), op, extra)
		}
		sb.WriteString(`</stack></image>`)
		sx, _ := zw.Create("stack.xml")
		sx.Write([]byte(sb.String()))
		mi, _ := zw.Create("mergedimage.png")
		png.Encode(mi, d.flat())
		return zw.Close()
	})
}

func xmlEsc(s string) string {
	var b bytes.Buffer
	xml.EscapeText(&b, []byte(s))
	return b.String()
}

func openORA(path string) (*Doc, error) {
	zr, err := zip.OpenReader(path)
	if err != nil {
		return nil, err
	}
	defer zr.Close()
	files := map[string]*zip.File{}
	for _, f := range zr.File {
		files[f.Name] = f
	}
	sf := files["stack.xml"]
	if sf == nil {
		return nil, fmt.Errorf("not an OpenRaster file")
	}
	rc, _ := sf.Open()
	var im oraImage
	err = xml.NewDecoder(rc).Decode(&im)
	rc.Close()
	if err != nil {
		return nil, err
	}
	var all []oraLayer
	var walk func(s oraStack)
	walk = func(s oraStack) {
		all = append(all, s.Layers...)
		for _, c := range s.Stacks {
			walk(c)
		}
	}
	walk(im.Stack)
	if im.W < 1 || im.H < 1 || im.W > 16000 || im.H > 16000 || len(all) == 0 {
		return nil, fmt.Errorf("empty or too large image")
	}
	d := newDoc(im.W, im.H)
	rev := map[string]string{}
	for k, v := range oraBlend {
		rev[v] = k
	}
	for i := len(all) - 1; i >= 0; i-- {
		ol := all[i]
		lf := files[ol.Src]
		if lf == nil {
			continue
		}
		r, _ := lf.Open()
		data, _ := io.ReadAll(io.LimitReader(r, 512<<20))
		r.Close()
		pic, _, err := image.Decode(bytes.NewReader(data))
		if err != nil {
			continue
		}
		pix := toNRGBA(pic)
		l := d.newLayer(ol.Name)
		l.Visible = ol.Vis != "hidden"
		l.Opacity = ol.Op
		if ol.Op == 0 && ol.Vis == "" {
			l.Opacity = 1
		}
		if b := rev[ol.Comp]; b != "" {
			l.Blend = b
		}
		if ol.Kind == "text" {
			l.Kind, l.Img, l.TextImg, l.X, l.Y = "text", nil, pix, ol.X, ol.Y
			l.Props = json.RawMessage(ol.Props)
		} else {
			blit(l.Img, pix, ol.X, ol.Y)
		}
		d.Layers = append(d.Layers, *l)
	}
	if len(d.Layers) == 0 {
		return nil, fmt.Errorf("no layers")
	}
	d.Active = d.Layers[len(d.Layers)-1].ID
	return d, nil
}
