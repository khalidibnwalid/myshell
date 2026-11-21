// audio-wave turns raw audio into the heights of a few bars, for the audio widget of the desktop.
//
// It reads signed 16-bit little-endian mono samples (22050 Hz) on stdin, as `pw-record --raw` writes
// them, and prints one line per frame (about 40 a second): BANDS numbers from 0 to 1 separated by
// spaces, low pitches first. It exits when the input ends.
package main

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"math/cmplx"
	"os"
	"strconv"
	"strings"
)

const (
	rate   = 22050
	window = 1024
	hop    = 551 // 40 frames a second
)

func fft(a []complex128) {
	n := len(a)
	for i, j := 1, 0; i < n; i++ {
		bit := n >> 1
		for ; j&bit != 0; bit >>= 1 {
			j ^= bit
		}
		j ^= bit
		if i < j {
			a[i], a[j] = a[j], a[i]
		}
	}
	for size := 2; size <= n; size <<= 1 {
		w := cmplx.Exp(complex(0, -2*math.Pi/float64(size)))
		for start := 0; start < n; start += size {
			f := complex(1, 0)
			for k := 0; k < size/2; k++ {
				u, v := a[start+k], a[start+k+size/2]*f
				a[start+k], a[start+k+size/2] = u+v, u-v
				f *= w
			}
		}
	}
}

func main() {
	bands := 32
	if len(os.Args) > 1 {
		if n, err := strconv.Atoi(os.Args[1]); err == nil && n >= 4 && n <= 128 {
			bands = n
		}
	}
	// band edges, spaced evenly on a log scale from 50 Hz to 10 kHz, as FFT bin numbers
	edges := make([]int, bands+1)
	binHz := float64(rate) / window
	for i := range edges {
		f := 50 * math.Pow(10000.0/50, float64(i)/float64(bands))
		edges[i] = int(f / binHz)
		if i > 0 && edges[i] <= edges[i-1] {
			edges[i] = edges[i-1] + 1
		}
	}
	hann := make([]float64, window)
	for i := range hann {
		hann[i] = 0.5 - 0.5*math.Cos(2*math.Pi*float64(i)/(window-1))
	}

	in := bufio.NewReaderSize(os.Stdin, 1<<16)
	out := bufio.NewWriter(os.Stdout)
	ring := make([]float64, window)
	buf := make([]byte, hop*2)
	data := make([]complex128, window)
	var sb strings.Builder
	for {
		if _, err := io.ReadFull(in, buf); err != nil {
			return
		}
		copy(ring, ring[hop:])
		for i := 0; i < hop; i++ {
			ring[window-hop+i] = float64(int16(binary.LittleEndian.Uint16(buf[i*2:]))) / 32768
		}
		for i := range data {
			data[i] = complex(ring[i]*hann[i], 0)
		}
		fft(data)
		sb.Reset()
		for b := 0; b < bands; b++ {
			peak := 0.0
			for k := edges[b]; k < edges[b+1] && k < window/2; k++ {
				if m := cmplx.Abs(data[k]); m > peak {
					peak = m
				}
			}
			// a full-scale sine gives window/4 here
			db := 20 * math.Log10(peak/(window/4)+1e-9)
			// quiet highs would never show: lift them a little
			db += 12 * float64(b) / float64(bands)
			v := (db + 54) / 44
			v = math.Max(0, math.Min(1, v))
			if b > 0 {
				sb.WriteByte(' ')
			}
			sb.WriteString(strconv.FormatFloat(v, 'f', 2, 64))
		}
		sb.WriteByte('\n')
		out.WriteString(sb.String())
		if err := out.Flush(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			return
		}
	}
}
