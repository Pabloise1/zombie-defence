class_name Icons
extends RefCounted

static func draw(ci: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y)
	match kind:
		"wall":
			var bw := s * 0.4
			var bh := s * 0.24
			var g := s * 0.05
			var top := c.y - bh - g * 0.5
			for row in 3:
				var y := top + (row - 1) * (bh + g) + bh * 0.5
				var off := (bw + g) * 0.5 if row % 2 == 1 else 0.0
				for k in range(-1, 2):
					var x := c.x + k * (bw + g) - bw * 0.5 + off
					var rr := Rect2(x, y - bh * 0.5, bw, bh).intersection(Rect2(c.x - s * 0.5, c.y - s * 0.5, s, s))
					if rr.size.x > 2.0:
						ci.draw_rect(rr, col)
		"turret":
			ci.draw_circle(c + Vector2(0, s * 0.12), s * 0.26, col)
			ci.draw_circle(c + Vector2(0, s * 0.12), s * 0.14, Color(0, 0, 0, 0.35))
			var a := c + Vector2(0, s * 0.12)
			var dir := Vector2(0.62, -0.78).normalized()
			ci.draw_line(a, a + dir * s * 0.5, col, s * 0.11)
			ci.draw_rect(Rect2(c.x - s * 0.36, c.y + s * 0.3, s * 0.72, s * 0.1), col)
		"spikes":
			ci.draw_rect(Rect2(c.x - s * 0.42, c.y + s * 0.22, s * 0.84, s * 0.12), col)
			for k in 4:
				var x := c.x - s * 0.33 + k * s * 0.22
				ci.draw_colored_polygon(PackedVector2Array([
					Vector2(x - s * 0.08, c.y + s * 0.22), Vector2(x, c.y - s * 0.32), Vector2(x + s * 0.08, c.y + s * 0.22)]), col)
		"mine":
			ci.draw_circle(c + Vector2(0, s * 0.08), s * 0.3, col)
			ci.draw_circle(c + Vector2(0, s * 0.08), s * 0.2, Color(0, 0, 0, 0.3))
			ci.draw_circle(c + Vector2(0, s * 0.08), s * 0.09, col)
			for k in 3:
				var ang := -PI * 0.5 + (k - 1) * 0.55
				var p0 := c + Vector2(0, s * 0.08) + Vector2(cos(ang), sin(ang)) * s * 0.34
				ci.draw_line(p0, p0 + Vector2(cos(ang), sin(ang)) * s * 0.14, col, s * 0.07)
		"dig":
			var a := c + Vector2(-s * 0.3, -s * 0.36)
			var b := c + Vector2(s * 0.12, s * 0.08)
			ci.draw_line(a, b, col, s * 0.09)
			ci.draw_line(a + Vector2(-s * 0.09, s * 0.09), a + Vector2(s * 0.09, -s * 0.09), col, s * 0.08)
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x)
			var tip := b + d * s * 0.36
			ci.draw_colored_polygon(PackedVector2Array([
				b + n * s * 0.16, b - n * s * 0.16, tip - n * s * 0.1 + d * s * 0.02, tip, tip + n * s * 0.1 + d * s * 0.02]), col)
		"remove":
			ci.draw_arc(c, s * 0.34, 0, TAU, 32, col, s * 0.08, true)
			var k := s * 0.17
			ci.draw_line(c + Vector2(-k, -k), c + Vector2(k, k), col, s * 0.09)
			ci.draw_line(c + Vector2(k, -k), c + Vector2(-k, k), col, s * 0.09)
		"supplies":
			var rr := Rect2(c.x - s * 0.36, c.y - s * 0.3, s * 0.72, s * 0.6)
			ci.draw_rect(rr, col)
			ci.draw_rect(rr.grow(-s * 0.08), Color(0, 0, 0, 0.3))
			ci.draw_line(rr.position + Vector2(s * 0.08, s * 0.08), rr.end - Vector2(s * 0.08, s * 0.08), col, s * 0.08)
			ci.draw_line(Vector2(rr.position.x, c.y), Vector2(rr.end.x, c.y), col, s * 0.06)
		"hq":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.42), c + Vector2(s * 0.34, -s * 0.28), c + Vector2(s * 0.3, s * 0.1),
				c + Vector2(0, s * 0.42), c + Vector2(-s * 0.3, s * 0.1), c + Vector2(-s * 0.34, -s * 0.28)]), col)
		"zombie":
			ci.draw_circle(c + Vector2(0, -s * 0.05), s * 0.3, col)
			ci.draw_rect(Rect2(c.x - s * 0.18, c.y + s * 0.15, s * 0.36, s * 0.2), col)
			ci.draw_circle(c + Vector2(-s * 0.11, -s * 0.05), s * 0.075, Color(0, 0, 0, 0.75))
			ci.draw_circle(c + Vector2(s * 0.11, -s * 0.05), s * 0.075, Color(0, 0, 0, 0.75))
			for k in 3:
				ci.draw_line(Vector2(c.x - s * 0.1 + k * s * 0.1, c.y + s * 0.18), Vector2(c.x - s * 0.1 + k * s * 0.1, c.y + s * 0.33), Color(0, 0, 0, 0.6), s * 0.03)
		"mortar":
			ci.draw_rect(Rect2(c.x - s * 0.38, c.y + s * 0.26, s * 0.76, s * 0.1), col)
			var base := c + Vector2(-s * 0.1, s * 0.26)
			var d := Vector2(0.5, -0.86)
			ci.draw_line(base, base + d * s * 0.5, col, s * 0.15)
			ci.draw_line(base + Vector2(s * 0.05, 0), base + Vector2(s * 0.22, -s * 0.2), col, s * 0.05)
			for k in 4:
				var t := float(k) / 3.0
				var p := c + Vector2(lerpf(s * 0.1, s * 0.42, t), -s * 0.3 + s * 0.5 * t * t - s * 0.1)
				ci.draw_circle(p, s * 0.035, col)
		"sniper":
			ci.draw_arc(c, s * 0.3, 0, TAU, 32, col, s * 0.07, true)
			ci.draw_line(c + Vector2(-s * 0.44, 0), c + Vector2(-s * 0.12, 0), col, s * 0.06)
			ci.draw_line(c + Vector2(s * 0.12, 0), c + Vector2(s * 0.44, 0), col, s * 0.06)
			ci.draw_line(c + Vector2(0, -s * 0.44), c + Vector2(0, -s * 0.12), col, s * 0.06)
			ci.draw_line(c + Vector2(0, s * 0.12), c + Vector2(0, s * 0.44), col, s * 0.06)
			ci.draw_circle(c, s * 0.05, col)
		"flame":
			var pts := PackedVector2Array()
			for k in 24:
				var a := float(k) / 24.0 * TAU
				var rr := s * 0.26
				var p := Vector2(sin(a) * rr, -cos(a) * rr * 1.5)
				if p.y < 0.0:
					p.x *= 1.0 - (-p.y / (rr * 1.5)) * 0.85
				pts.append(c + Vector2(0, s * 0.1) + p)
			ci.draw_colored_polygon(pts, col)
			ci.draw_circle(c + Vector2(0, s * 0.2), s * 0.1, Color(0, 0, 0, 0.35))
		"wire":
			ci.draw_line(c + Vector2(-s * 0.42, s * 0.32), c + Vector2(-s * 0.2, -s * 0.32), col, s * 0.06)
			ci.draw_line(c + Vector2(-s * 0.2, s * 0.32), c + Vector2(-s * 0.42, -s * 0.32), col, s * 0.06)
			ci.draw_line(c + Vector2(s * 0.42, s * 0.32), c + Vector2(s * 0.2, -s * 0.32), col, s * 0.06)
			ci.draw_line(c + Vector2(s * 0.2, s * 0.32), c + Vector2(s * 0.42, -s * 0.32), col, s * 0.06)
			for k in 4:
				ci.draw_arc(c + Vector2(-s * 0.21 + k * s * 0.14, 0), s * 0.13, 0, TAU, 14, col, s * 0.04, true)
		"garrison":
			ci.draw_arc(c + Vector2(0, s * 0.18), s * 0.38, PI, TAU, 24, col, s * 0.2, true)
			ci.draw_rect(Rect2(c.x - s * 0.46, c.y + s * 0.16, s * 0.92, s * 0.14), col)
			ci.draw_rect(Rect2(c.x - s * 0.17, c.y - s * 0.06, s * 0.34, s * 0.06), Color(0, 0, 0, 0.6))
		"soldier":
			ci.draw_circle(c + Vector2(0, -s * 0.18), s * 0.14, col)
			ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.2, PI, TAU, 16, col, s * 0.08, true)
			ci.draw_rect(Rect2(c.x - s * 0.2, c.y, s * 0.4, s * 0.36), col)
		"concrete":
			ci.draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.38, s * 0.8, s * 0.76), col)
			for k in 2:
				ci.draw_line(Vector2(c.x - s * 0.13 + k * s * 0.26, c.y - s * 0.38), Vector2(c.x - s * 0.13 + k * s * 0.26, c.y + s * 0.38), Color(0, 0, 0, 0.4), s * 0.04)
			ci.draw_line(Vector2(c.x - s * 0.4, c.y), Vector2(c.x + s * 0.4, c.y), Color(0, 0, 0, 0.4), s * 0.04)
		"gate":
			ci.draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.38, s * 0.12, s * 0.76), col)
			ci.draw_rect(Rect2(c.x + s * 0.32, c.y - s * 0.38, s * 0.12, s * 0.76), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.3), c + Vector2(-s * 0.04, -s * 0.18), c + Vector2(-s * 0.04, s * 0.38), c + Vector2(-s * 0.3, s * 0.3)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.3), c + Vector2(s * 0.04, -s * 0.18), c + Vector2(s * 0.04, s * 0.38), c + Vector2(s * 0.3, s * 0.3)]), col)
		"person":
			ci.draw_circle(c + Vector2(0, -s * 0.22), s * 0.15, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.26, s * 0.4), c + Vector2(-s * 0.2, s * 0.0), c + Vector2(s * 0.2, s * 0.0), c + Vector2(s * 0.26, s * 0.4)]), col)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.28, -s * 0.34), c + Vector2(s * 0.36, 0), c + Vector2(-s * 0.28, s * 0.34)]), col)
		"close":
			var k := s * 0.22
			ci.draw_line(c + Vector2(-k, -k), c + Vector2(k, k), col, s * 0.12)
			ci.draw_line(c + Vector2(k, -k), c + Vector2(-k, k), col, s * 0.12)
		"clock":
			ci.draw_arc(c, s * 0.34, 0, TAU, 32, col, s * 0.09, true)
			ci.draw_line(c, c + Vector2(0, -s * 0.22), col, s * 0.08)
			ci.draw_line(c, c + Vector2(s * 0.16, 0), col, s * 0.08)
		"house":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, -s * 0.02), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.42, -s * 0.02)]), col)
			ci.draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.04, s * 0.64, s * 0.42), col)
			ci.draw_rect(Rect2(c.x - s * 0.08, c.y + s * 0.12, s * 0.16, s * 0.26), Color(0, 0, 0, 0.5))
		"depot":
			ci.draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.22, s * 0.88, s * 0.58), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.48, -s * 0.2), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.48, -s * 0.2)]), col)
			for k in 3:
				ci.draw_line(Vector2(c.x - s * 0.22, c.y + k * s * 0.1), Vector2(c.x + s * 0.22, c.y + k * s * 0.1), Color(0, 0, 0, 0.5), s * 0.04)
		"workshop":
			ci.draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.1, s * 0.8, s * 0.46), col)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.36), c + Vector2(s * 0.12, -s * 0.02), col, s * 0.1)
			ci.draw_circle(c + Vector2(s * 0.2, -s * 0.24), s * 0.13, col)
			ci.draw_circle(c + Vector2(s * 0.2, -s * 0.24), s * 0.05, Color(0, 0, 0, 0.5))
		"barracks":
			ci.draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.12, s * 0.88, s * 0.48), col)
			ci.draw_rect(Rect2(c.x - s * 0.44, c.y - s * 0.24, s * 0.88, s * 0.1), col)
			for k in 4:
				ci.draw_rect(Rect2(c.x - s * 0.36 + k * s * 0.2, c.y, s * 0.1, s * 0.1), Color(0, 0, 0, 0.5))
			ci.draw_line(c + Vector2(-s * 0.06, -s * 0.24), c + Vector2(-s * 0.06, -s * 0.46), col, s * 0.04)
			ci.draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.46, s * 0.2, s * 0.1), col)
		"watchtower":
			ci.draw_rect(Rect2(c.x - s * 0.14, c.y - s * 0.26, s * 0.28, s * 0.64), col)
			ci.draw_rect(Rect2(c.x - s * 0.24, c.y - s * 0.42, s * 0.48, s * 0.18), col)
			ci.draw_rect(Rect2(c.x - s * 0.06, c.y - s * 0.12, s * 0.12, s * 0.08), Color(0, 0, 0, 0.5))
		"platform":
			ci.draw_rect(Rect2(c.x - s * 0.38, c.y - s * 0.12, s * 0.76, s * 0.1), col)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.02), c + Vector2(-s * 0.3, s * 0.42), col, s * 0.07)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.02), c + Vector2(s * 0.3, s * 0.42), col, s * 0.07)
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.4), c + Vector2(s * 0.3, s * 0.02), col, s * 0.04)
			ci.draw_circle(c + Vector2(0, -s * 0.24), s * 0.13, col)
			ci.draw_line(c + Vector2(0, -s * 0.24), c + Vector2(s * 0.3, -s * 0.42), col, s * 0.07)
		"ammo_point":
			for k in 3:
				ci.draw_rect(Rect2(c.x - s * 0.42 + k * s * 0.29, c.y + s * 0.04, s * 0.26, s * 0.3), col)
			ci.draw_rect(Rect2(c.x - s * 0.27, c.y - s * 0.3, s * 0.26, s * 0.3), col)
			ci.draw_rect(Rect2(c.x + s * 0.02, c.y - s * 0.3, s * 0.26, s * 0.3), col)
			ci.draw_line(Vector2(c.x - s * 0.42, c.y + s * 0.16), Vector2(c.x + s * 0.42, c.y + s * 0.16), Color(0.95, 0.8, 0.2), s * 0.05)
		"radio":
			ci.draw_line(c + Vector2(-s * 0.22, s * 0.42), c + Vector2(0, -s * 0.36), col, s * 0.07)
			ci.draw_line(c + Vector2(s * 0.22, s * 0.42), c + Vector2(0, -s * 0.36), col, s * 0.07)
			ci.draw_line(c + Vector2(-s * 0.12, s * 0.1), c + Vector2(s * 0.12, s * 0.1), col, s * 0.05)
			ci.draw_arc(c + Vector2(0, -s * 0.36), s * 0.18, -2.4, -0.7, 10, col, s * 0.05, true)
			ci.draw_arc(c + Vector2(0, -s * 0.36), s * 0.3, -2.4, -0.7, 12, col, s * 0.05, true)
		"fuel":
			ci.draw_rect(Rect2(c.x - s * 0.4, c.y - s * 0.18, s * 0.8, s * 0.42), col, true)
			ci.draw_circle(c + Vector2(-s * 0.4, s * 0.03), s * 0.21, col)
			ci.draw_circle(c + Vector2(s * 0.4, s * 0.03), s * 0.21, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.12), c + Vector2(s * 0.1, s * 0.06), c + Vector2(0, s * 0.14), c + Vector2(-s * 0.1, s * 0.06)]), Color(0, 0, 0, 0.55))
		"room_block":
			for k in 3:
				ci.draw_rect(Rect2(c.x - s * 0.3, c.y + s * 0.18 - k * s * 0.27, s * 0.6, s * 0.24), col)
				ci.draw_rect(Rect2(c.x - s * 0.08, c.y + s * 0.24 - k * s * 0.27, s * 0.16, s * 0.1), Color(0, 0, 0, 0.5))
			ci.draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.46, s * 0.72, s * 0.08), col)
		"stairs":
			for k in 4:
				ci.draw_rect(Rect2(c.x - s * 0.4 + k * s * 0.2, c.y + s * 0.3 - k * s * 0.2, s * 0.2, s * 0.1 + k * s * 0.2), col)
			ci.draw_line(c + Vector2(-s * 0.42, s * 0.1), c + Vector2(s * 0.3, -s * 0.44), col, s * 0.05)
		"bridge":
			ci.draw_rect(Rect2(c.x - s * 0.46, c.y - s * 0.04, s * 0.92, s * 0.1), col)
			ci.draw_rect(Rect2(c.x - s * 0.46, c.y - s * 0.04, s * 0.14, s * 0.46), col)
			ci.draw_rect(Rect2(c.x + s * 0.32, c.y - s * 0.04, s * 0.14, s * 0.46), col)
			for k in 5:
				ci.draw_line(Vector2(c.x - s * 0.32 + k * s * 0.16, c.y - s * 0.04), Vector2(c.x - s * 0.32 + k * s * 0.16, c.y - s * 0.24), col, s * 0.04)
			ci.draw_line(Vector2(c.x - s * 0.4, c.y - s * 0.24), Vector2(c.x + s * 0.4, c.y - s * 0.24), col, s * 0.05)
		"helipad", "helipad_large", "heli":
			ci.draw_arc(c, s * 0.42, 0, TAU, 32, col, s * 0.07, true)
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.24, s * 0.09, s * 0.48), col)
			ci.draw_rect(Rect2(c.x + s * 0.13, c.y - s * 0.24, s * 0.09, s * 0.48), col)
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y - s * 0.045, s * 0.44, s * 0.09), col)
		"rescue":
			ci.draw_circle(c + Vector2(-s * 0.18, -s * 0.2), s * 0.11, col)
			ci.draw_circle(c + Vector2(s * 0.18, -s * 0.2), s * 0.11, col)
			ci.draw_rect(Rect2(c.x - s * 0.32, c.y - s * 0.06, s * 0.28, s * 0.36), col)
			ci.draw_rect(Rect2(c.x + s * 0.04, c.y - s * 0.06, s * 0.28, s * 0.36), col)
			ci.draw_line(c + Vector2(0, -s * 0.46), c + Vector2(0, -s * 0.3), col, s * 0.06)
		"patrol":
			ci.draw_arc(c, s * 0.34, 0.3, TAU - 0.3, 24, col, s * 0.07, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.34, -s * 0.24), c + Vector2(s * 0.46, s * 0.04), c + Vector2(s * 0.2, s * 0.02)]), col)
			ci.draw_circle(c, s * 0.08, col)
		"hammer", "rebuild":
			var hd := c + Vector2(-s * 0.06, -s * 0.2)
			ci.draw_colored_polygon(PackedVector2Array([hd + Vector2(-s * 0.3, -s * 0.12), hd + Vector2(s * 0.22, -s * 0.12), hd + Vector2(s * 0.3, -s * 0.02), hd + Vector2(s * 0.22, s * 0.1), hd + Vector2(-s * 0.3, s * 0.1)]), col)
			ci.draw_line(hd + Vector2(-s * 0.02, s * 0.08), c + Vector2(s * 0.14, s * 0.44), col, s * 0.11)
		"crate":
			var rr := Rect2(c.x - s * 0.38, c.y - s * 0.3, s * 0.76, s * 0.6)
			ci.draw_rect(rr, col)
			ci.draw_rect(Rect2(rr.position.x, c.y - s * 0.06, rr.size.x, s * 0.12), Color(0, 0, 0, 0.35))
			ci.draw_rect(Rect2(c.x - s * 0.06, rr.position.y, s * 0.12, rr.size.y), Color(0, 0, 0, 0.2))
		"menu", "sound":
			ci.draw_rect(Rect2(c.x - s * 0.34, c.y - s * 0.12, s * 0.18, s * 0.24), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.12), c + Vector2(s * 0.06, -s * 0.34), c + Vector2(s * 0.06, s * 0.34), c + Vector2(-s * 0.18, s * 0.12)]), col)
			ci.draw_arc(c + Vector2(s * 0.06, 0), s * 0.2, -0.9, 0.9, 10, col, s * 0.07, true)
			ci.draw_arc(c + Vector2(s * 0.06, 0), s * 0.36, -0.9, 0.9, 12, col, s * 0.07, true)
		"muted":
			ci.draw_rect(Rect2(c.x - s * 0.34, c.y - s * 0.12, s * 0.18, s * 0.24), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.12), c + Vector2(s * 0.06, -s * 0.34), c + Vector2(s * 0.06, s * 0.34), c + Vector2(-s * 0.18, s * 0.12)]), col)
			ci.draw_line(c + Vector2(s * 0.16, -s * 0.14), c + Vector2(s * 0.42, s * 0.14), col, s * 0.08)
			ci.draw_line(c + Vector2(s * 0.42, -s * 0.14), c + Vector2(s * 0.16, s * 0.14), col, s * 0.08)
		"upgrade":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.34, -s * 0.02), c + Vector2(s * 0.12, -s * 0.02), c + Vector2(s * 0.12, s * 0.36), c + Vector2(-s * 0.12, s * 0.36), c + Vector2(-s * 0.12, -s * 0.02), c + Vector2(-s * 0.34, -s * 0.02)]), col)
		"ports":
			ci.draw_rect(Rect2(c.x - s * 0.42, c.y - s * 0.3, s * 0.84, s * 0.6), col)
			ci.draw_rect(Rect2(c.x - s * 0.3, c.y - s * 0.07, s * 0.22, s * 0.1), Color(0, 0, 0, 0.7))
			ci.draw_rect(Rect2(c.x + s * 0.08, c.y - s * 0.07, s * 0.22, s * 0.1), Color(0, 0, 0, 0.7))
		"trash", "sell":
			ci.draw_rect(Rect2(c.x - s * 0.36, c.y - s * 0.3, s * 0.72, s * 0.08), col)
			ci.draw_rect(Rect2(c.x - s * 0.1, c.y - s * 0.4, s * 0.2, s * 0.08), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.18), c + Vector2(s * 0.28, -s * 0.18), c + Vector2(s * 0.22, s * 0.4), c + Vector2(-s * 0.22, s * 0.4)]), col)
			for k in 2:
				ci.draw_line(c + Vector2(-s * 0.07 + k * s * 0.14, -s * 0.08), c + Vector2(-s * 0.07 + k * s * 0.14, s * 0.3), Color(0, 0, 0, 0.45), s * 0.05)
		"flag", "claim":
			ci.draw_line(c + Vector2(-s * 0.26, -s * 0.4), c + Vector2(-s * 0.26, s * 0.42), col, s * 0.08)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.4), c + Vector2(s * 0.36, -s * 0.24), c + Vector2(-s * 0.22, -s * 0.04)]), col)
		"reshape":
			var pts2 := [c + Vector2(-s * 0.36, s * 0.28), c + Vector2(-s * 0.1, -s * 0.3), c + Vector2(s * 0.36, -s * 0.1)]
			ci.draw_polyline(PackedVector2Array(pts2), col, s * 0.07, true)
			for q in pts2:
				ci.draw_circle(q, s * 0.11, col)
		"expand":
			for k in 4:
				var ang := PI * 0.25 + k * PI * 0.5
				var d2 := Vector2(cos(ang), sin(ang))
				var tip2 := c + d2 * s * 0.42
				ci.draw_line(c + d2 * s * 0.1, tip2, col, s * 0.07)
				var n2 := Vector2(-d2.y, d2.x)
				ci.draw_colored_polygon(PackedVector2Array([tip2, tip2 - d2 * s * 0.16 + n2 * s * 0.1, tip2 - d2 * s * 0.16 - n2 * s * 0.1]), col)
		"auto":
			ci.draw_arc(c, s * 0.3, -2.6, 0.6, 16, col, s * 0.08, true)
			var e1 := c + Vector2(cos(0.6), sin(0.6)) * s * 0.3
			ci.draw_colored_polygon(PackedVector2Array([e1 + Vector2(-s * 0.14, -s * 0.02), e1 + Vector2(s * 0.08, -s * 0.12), e1 + Vector2(s * 0.06, s * 0.12)]), col)
			ci.draw_arc(c, s * 0.3, 0.55, 2.2, 10, Color(col.r, col.g, col.b, col.a * 0.4), s * 0.08, true)
		"move":
			ci.draw_line(c + Vector2(-s * 0.4, 0), c + Vector2(s * 0.4, 0), col, s * 0.07)
			ci.draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.4), col, s * 0.07)
			for k in 4:
				var ang2 := k * PI * 0.5
				var d3 := Vector2(cos(ang2), sin(ang2))
				var tip3 := c + d3 * s * 0.44
				var n3 := Vector2(-d3.y, d3.x)
				ci.draw_colored_polygon(PackedVector2Array([tip3, tip3 - d3 * s * 0.16 + n3 * s * 0.12, tip3 - d3 * s * 0.16 - n3 * s * 0.12]), col)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.32, 0), c + Vector2(-s * 0.08, s * 0.24), c + Vector2(s * 0.34, -s * 0.24)]), col, s * 0.12, true)
		"chevron_down":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.1), c + Vector2(0, s * 0.18), c + Vector2(s * 0.3, -s * 0.1)]), col, s * 0.1, true)
		"undo":
			ci.draw_arc(c + Vector2(s * 0.04, s * 0.06), s * 0.26, -PI * 0.95, PI * 0.5, 16, col, s * 0.09, true)
			var u0 := c + Vector2(s * 0.04, s * 0.06) + Vector2(cos(-PI * 0.95), sin(-PI * 0.95)) * s * 0.26
			ci.draw_colored_polygon(PackedVector2Array([u0 + Vector2(-s * 0.16, -s * 0.04), u0 + Vector2(s * 0.08, -s * 0.18), u0 + Vector2(s * 0.08, s * 0.12)]), col)
		"rubble":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.44, s * 0.36), c + Vector2(-s * 0.3, s * 0.04), c + Vector2(-s * 0.08, s * 0.16), c + Vector2(s * 0.1, -s * 0.14), c + Vector2(s * 0.3, s * 0.1), c + Vector2(s * 0.44, s * 0.36)]), col)
			ci.draw_rect(Rect2(c.x - s * 0.2, c.y - s * 0.38, s * 0.16, s * 0.12), col)
			ci.draw_rect(Rect2(c.x + s * 0.16, c.y - s * 0.3, s * 0.12, s * 0.1), col)
		"zone":
			ci.draw_arc(c, s * 0.36, 0, TAU, 28, col, s * 0.08, true)
			ci.draw_circle(c, s * 0.12, col)
		"heart":
			ci.draw_circle(c + Vector2(-s * 0.15, -s * 0.08), s * 0.18, col)
			ci.draw_circle(c + Vector2(s * 0.15, -s * 0.08), s * 0.18, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.32, 0), c + Vector2(s * 0.32, 0), c + Vector2(0, s * 0.36)]), col)
		"plus":
			ci.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), col, s * 0.11)
			ci.draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), col, s * 0.11)
		"minus":
			ci.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), col, s * 0.11)
		_:
			ci.draw_circle(c, s * 0.3, col)

static func for_action(id: String) -> String:
	if id.begins_with("mount:"):
		return id.substr(6)
	match id:
		"upgrade", "upgrade_run", "upgrade_zone":
			return "upgrade"
		"ports":
			return "ports"
		"assign", "assign_all":
			return "soldier"
		"mount":
			return "turret"
		"bastion":
			return "watchtower"
		"gate":
			return "gate"
		"reshape":
			return "reshape"
		"sell", "clear_rubble", "inner_yes":
			return "trash"
		"move":
			return "move"
		"claim", "claim_fence":
			return "flag"
		"rebuild":
			return "hammer"
		"expand":
			return "expand"
		"zspeed", "horde":
			return "zombie"
		"auto_rebuild", "quality", "fps":
			return "auto"
		"floor":
			return "room_block"
		"buy_heli":
			return "heli"
		"heli_rescue":
			return "rescue"
		"heli_patrol":
			return "patrol"
		"heli_resupply":
			return "crate"
		"sound_test":
			return "sound"
		"mute":
			return "muted"
		"close", "cancel_claim", "ask_no", "inner_no":
			return "close"
	return ""

static func for_tab(id: String) -> String:
	match id:
		"defend":
			return "sniper"
		"high":
			return "room_block"
		"build":
			return "wall"
		"base":
			return "house"
		"supply":
			return "crate"
		"traps":
			return "spikes"
	return ""
