package core

import "math"

// BlendHalfWithHighlight blends an ON pixel down ~50% matching Twinkle Bulbs dim off state.
func BlendHalfWithHighlight(c RGBA) RGBA {
	return RGBA{
		R: uint8(float64(c.R)*0.30 + 24),
		G: uint8(float64(c.G)*0.30 + 24),
		B: uint8(float64(c.B)*0.30 + 26),
		A: c.A,
	}
}

// RenderBulbSprite renders a 32x32 (or 48x48) clean-room bulb sprite in RGBA byte order
// rotated inward according to RotDegrees (0, 90, 180, -90).
func RenderBulbSprite(size int, shapeKind int, c RGBA, intensity float64, bareSpacer bool, rotDeg int) []uint8 {
	if size != 48 {
		size = 32
	}
	raw := make([]RGBA, size*size)
	s := float64(size)
	cx := (s - 1.0) * 0.5

	// Green wire across top row 0..3px connecting seamlessly edge-to-edge
	for y := 0; y < size; y++ {
		wireY := 2.0 + math.Sin(float64(y)*0.1)*0.1
		_ = wireY
		for x := 0; x < size; x++ {
			if y >= 1 && y <= int(math.Max(2, s*0.09)) {
				raw[y*size+x] = RGBA{18, 92, 34, 255}
			}
		}
	}

	if bareSpacer {
		// Rotate and pack RGBA bytes
		return packRotated(raw, size, rotDeg)
	}

	// Socket / Brass cap under wire
	sockTop := int(s * 0.09)
	sockBot := int(s * 0.25)
	sockHalfW := s * 0.12
	for y := sockTop; y <= sockBot; y++ {
		for x := 0; x < size; x++ {
			if math.Abs(float64(x)-cx) <= sockHalfW {
				shade := 1.0 - math.Abs(float64(x)-cx)/(sockHalfW+1)*0.35
				raw[y*size+x] = RGBA{uint8(40 * shade), uint8(118 * shade), uint8(45 * shade), 255}
			}
		}
	}

	// Effective glass color scaled by intensity
	lit := RGBA{
		R: clampByte(float64(c.R)*intensity + float64(c.R)*0.12),
		G: clampByte(float64(c.G)*intensity + float64(c.G)*0.12),
		B: clampByte(float64(c.B)*intensity + float64(c.B)*0.12),
		A: 255,
	}

	// Bulb glass silhouette + outer corona halo when lit
	bodyTop := float64(sockBot)
	bodyBot := s - 2.0
	bodyMidY := (bodyTop + bodyBot) * 0.52
	maxR := s * 0.34

	for y := sockBot; y < size; y++ {
		fy := float64(y)
		for x := 0; x < size; x++ {
			fx := float64(x)
			dx := fx - cx
			dy := fy - bodyMidY

			var radiusAtY float64
			switch shapeKind % 5 {
			case 0: // Classic Outdoor / C9 teardrop cone
				t := (fy - bodyTop) / math.Max(1, bodyBot-bodyTop)
				if t < 0.38 {
					radiusAtY = maxR * (0.48 + 0.52*(t/0.38))
				} else {
					radiusAtY = maxR * math.Cos(((t-0.38)/0.62)*math.Pi*0.5)
				}
			case 1: // Round globe / Mini
				ry := (bodyBot - bodyTop) * 0.5
				ny := dy / math.Max(1, ry)
				if math.Abs(ny) <= 1.0 {
					radiusAtY = maxR * 0.95 * math.Sqrt(math.Max(0, 1.0-ny*ny))
				}
			case 2: // Star / Diamond
				t := (fy - bodyTop) / math.Max(1, bodyBot-bodyTop)
				if t < 0.5 {
					radiusAtY = maxR * (0.25 + 1.1*t)
				} else {
					radiusAtY = maxR * (0.25 + 1.1*(1.0-t))
				}
			case 3: // Candle flame
				t := (fy - bodyTop) / math.Max(1, bodyBot-bodyTop)
				radiusAtY = maxR * 0.72 * math.Sin(math.Min(1, math.Max(0, t))*math.Pi)
			default: // Icicle / Candy drop
				t := (fy - bodyTop) / math.Max(1, bodyBot-bodyTop)
				radiusAtY = maxR * 0.85 * (1.0 - t*0.88)
			}

			dist := math.Abs(dx)
			if radiusAtY > 0.5 && dist <= radiusAtY {
				// Specular glass highlight at top-left
				relX := dx / math.Max(1, radiusAtY)
				relY := dy / math.Max(1, (bodyBot-bodyTop)*0.5)
				rim := 1.0 - 0.25*(relX*relX+relY*relY*0.4)
				if rim < 0.35 {
					rim = 0.35
				}
				spec := 0.0
				if relX < -0.15 && relX > -0.65 && relY < 0.1 && relY > -0.55 {
					spec = 0.55 * intensity
				}
				r := clampByte(float64(lit.R)*rim + 255*spec)
				g := clampByte(float64(lit.G)*rim + 255*spec)
				b := clampByte(float64(lit.B)*rim + 255*spec)
				raw[y*size+x] = RGBA{r, g, b, 255}
			} else if intensity > 0.45 && dist <= radiusAtY+s*0.18 && fy >= bodyTop && fy <= bodyBot+2 {
				// Subtle additive-looking alpha halo around lit glass
				gap := (dist - radiusAtY) / (s * 0.18)
				if gap < 0 {
					gap = 0
				}
				haloAlpha := (1.0 - gap) * (1.0 - gap) * 0.42 * intensity
				if haloAlpha > 0.03 {
					raw[y*size+x] = RGBA{lit.R, lit.G, lit.B, uint8(haloAlpha * 255)}
				}
			}
		}
	}

	return packRotated(raw, size, rotDeg)
}

func packRotated(src []RGBA, size int, rotDeg int) []uint8 {
	out := make([]uint8, size*size*4)
	for y := 0; y < size; y++ {
		for x := 0; x < size; x++ {
			var sx, sy int
			switch rotDeg {
			case 90:
				sx, sy = y, size-1-x
			case -90, 270:
				sx, sy = size-1-y, x
			case 180:
				sx, sy = size-1-x, size-1-y
			default:
				sx, sy = x, y
			}
			px := src[sy*size+sx]
			off := (y*size + x) * 4
			out[off+0] = px.R
			out[off+1] = px.G
			out[off+2] = px.B
			out[off+3] = px.A
		}
	}
	return out
}

func clampByte(v float64) uint8 {
	if v < 0 {
		return 0
	}
	if v > 255 {
		return 255
	}
	return uint8(v)
}
