class_name ObjectArt
extends RefCounted
## Procedural drawings for labyrinth objects. Each draws inside pixel rect b.

const INK := Color(0.07, 0.05, 0.05)


static func pt(b: Rect2, x: float, y: float) -> Vector2:
	return b.position + Vector2(x * b.size.x, y * b.size.y)


static func sub(b: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(pt(b, x, y), b.size * Vector2(w, h))


static func poly(b: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(pt(b, v.x, v.y))
	return out


static func shape(ci: CanvasItem, b: Rect2, pts: Array, fill: Color, line: Color = INK, w: float = 2.0) -> void:
	var p := poly(b, pts)
	ci.draw_colored_polygon(p, fill)
	if line.a > 0.0:
		var c := p.duplicate()
		c.append(p[0])
		ci.draw_polyline(c, line, w, true)


static func box(ci: CanvasItem, r: Rect2, fill: Color, line: Color = INK, w: float = 2.0) -> void:
	ci.draw_rect(r, fill)
	if line.a > 0.0:
		ci.draw_rect(r, line, false, w)


static func shadow(ci: CanvasItem, b: Rect2, y: float = 1.0, wk: float = 0.55) -> void:
	var c := pt(b, 0.5, y)
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(c + Vector2(cos(a) * b.size.x * wk, sin(a) * b.size.x * 0.08))
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.3))


static func draw(ci: CanvasItem, o: Dictionary, b: Rect2, t: float, foe_white: bool) -> void:
	var s: Dictionary = o["st"]
	var col: Color = o["color"]
	var lw := maxf(1.5, b.size.x * 0.012)
	match String(o["art"]):
		"item":
			var side := minf(b.size.x, b.size.y) * 1.1
			var ir := Rect2(b.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
			var glint := 0.5 + 0.5 * sin(t * 4.0 + b.position.x)
			ci.draw_circle(ir.get_center(), side * 0.55, Color(1, 0.9, 0.6, 0.1 * glint))
			ItemArt.draw_icon(ci, o["pickup"], ir, t)
		"cot", "bunk":
			if o["art"] == "bunk":
				for yy in [0.0, 0.5]:
					box(ci, sub(b, 0.0, yy + 0.25, 1.0, 0.1), Color(0.35, 0.25, 0.16))
					box(ci, sub(b, 0.03, yy + 0.18, 0.94, 0.08), Color(0.45, 0.45, 0.38))
				for xx in [0.0, 0.95]:
					box(ci, sub(b, xx, 0.0, 0.05, 1.0), Color(0.3, 0.2, 0.13))
			else:
				shadow(ci, b, 0.98)
				box(ci, sub(b, 0.0, 0.3, 1.0, 0.28), Color(0.38, 0.4, 0.3))
				box(ci, sub(b, 0.02, 0.15, 0.25, 0.18), Color(0.7, 0.68, 0.6))
				for xx in [0.02, 0.92]:
					box(ci, sub(b, xx, 0.58, 0.06, 0.4), Color(0.3, 0.2, 0.13))
		"chest":
			shadow(ci, b, 0.98)
			var open: bool = s.get("open", false)
			box(ci, sub(b, 0.0, 0.35, 1.0, 0.65), col)
			ci.draw_line(pt(b, 0.0, 0.6), pt(b, 1.0, 0.6), col.darkened(0.4), lw)
			if open:
				shape(ci, b, [Vector2(0.0, 0.35), Vector2(1.0, 0.35), Vector2(0.95, 0.0), Vector2(0.05, 0.0)], col.darkened(0.25))
				box(ci, sub(b, 0.05, 0.35, 0.9, 0.12), Color(0.05, 0.04, 0.04), Color(0, 0, 0, 0))
			else:
				shape(ci, b, [Vector2(0.0, 0.35), Vector2(1.0, 0.35), Vector2(0.97, 0.12), Vector2(0.03, 0.12)], col.lightened(0.08))
				box(ci, sub(b, 0.44, 0.3, 0.12, 0.16), Color(0.75, 0.6, 0.3))
			for xx in [0.12, 0.84]:
				box(ci, sub(b, xx, 0.12 if not open else 0.35, 0.05, 0.88 if not open else 0.65), Color(0.25, 0.25, 0.27), Color(0, 0, 0, 0))
		"poster":
			box(ci, b, Color(0.78, 0.7, 0.55))
			box(ci, sub(b, 0.1, 0.08, 0.8, 0.12), Color(0.6, 0.15, 0.12), Color(0, 0, 0, 0))
			PieceArt.draw_piece(ci, 1, true, b.get_center().x, b.position.y + b.size.y * 0.85, b.size.x * 0.55, Color(1, 1, 1, 0.9), false)
			ci.draw_line(pt(b, 0.15, 0.92), pt(b, 0.85, 0.92), Color(0.3, 0.2, 0.15), lw)
		"sandbags":
			var broken: bool = s.get("broken", false)
			for row in 3:
				for i in 3 - (row % 2):
					var x := 0.02 + i * 0.32 + (0.16 if row % 2 == 1 else 0.0)
					var y := 0.66 - row * 0.3
					var bag := sub(b, x, y, 0.32, 0.32)
					if broken and row == 1 and i == 0:
						shape(ci, bag, [Vector2(0, 1), Vector2(1, 1), Vector2(0.8, 0.8), Vector2(0.2, 0.85)], Color(0.55, 0.48, 0.35))
						continue
					shape(ci, bag, [Vector2(0.05, 0.3), Vector2(0.95, 0.25), Vector2(1, 0.75), Vector2(0.9, 0.95), Vector2(0.1, 0.95), Vector2(0, 0.7)], Color(0.6, 0.53, 0.38))
					if row == 1 and i == 0:
						ci.draw_line(pt(bag, 0.3, 0.5), pt(bag, 0.7, 0.55), Color(0.3, 0.25, 0.15), lw)
						ci.draw_circle(pt(bag, 0.5, 0.55), bag.size.x * 0.05, Color(1, 0.85, 0.5, 0.5 + 0.5 * sin(t * 5.0)))
		"periscope":
			box(ci, sub(b, 0.35, 0.1, 0.3, 0.9), Color(0.3, 0.32, 0.28))
			box(ci, sub(b, 0.15, 0.0, 0.7, 0.14), Color(0.3, 0.32, 0.28))
			box(ci, sub(b, 0.2, 0.03, 0.4, 0.08), Color(0.6, 0.75, 0.85, 0.8), Color(0, 0, 0, 0))
		"crate":
			shadow(ci, b, 0.98)
			if s.get("broken", false):
				for i in 5:
					var a := 0.3 + i * 0.5
					var c := pt(b, 0.15 + i * 0.17, 0.85)
					ci.draw_line(c, c + Vector2(cos(a), sin(a) * 0.2) * b.size.x * 0.25, Color(0.5, 0.38, 0.22), lw * 3.0)
				ci.draw_circle(pt(b, 0.5, 0.9), b.size.x * 0.2, Color(0.75, 0.65, 0.35, 0.6))
			else:
				box(ci, b, Color(0.55, 0.42, 0.25))
				for k in [0.33, 0.66]:
					ci.draw_line(pt(b, 0.0, k), pt(b, 1.0, k), Color(0.35, 0.25, 0.14), lw)
				ci.draw_line(pt(b, 0, 0), pt(b, 1, 1), Color(0.4, 0.3, 0.17), lw * 2.0)
				ci.draw_string(ThemeDB.fallback_font, pt(b, 0.12, 0.6), "FRAGILE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(b.size.y * 0.14), Color(0.65, 0.15, 0.1, 0.8))
		"satchel":
			shadow(ci, b, 0.98)
			var open2: bool = s.get("open", false)
			shape(ci, b, [Vector2(0.05, 0.3), Vector2(0.95, 0.3), Vector2(1.0, 1.0), Vector2(0.0, 1.0)], Color(0.55, 0.5, 0.36))
			if not open2:
				shape(ci, b, [Vector2(0.05, 0.3), Vector2(0.95, 0.3), Vector2(0.85, 0.65), Vector2(0.15, 0.65)], Color(0.5, 0.45, 0.32))
			box(ci, sub(b, 0.42, 0.68, 0.16, 0.2), Color(0.85, 0.85, 0.8), Color(0, 0, 0, 0))
			box(ci, sub(b, 0.47, 0.7, 0.06, 0.16), Color(0.75, 0.1, 0.1), Color(0, 0, 0, 0))
			box(ci, sub(b, 0.43, 0.75, 0.14, 0.06), Color(0.75, 0.1, 0.1), Color(0, 0, 0, 0))
			ci.draw_arc(pt(b, 0.5, 0.3), b.size.x * 0.35, PI, TAU, 16, Color(0.4, 0.33, 0.22), lw * 1.5, true)
		"planks":
			for i in 5:
				var y := 0.08 + i * 0.19
				var tilt := (0.03 if i % 2 == 0 else -0.04)
				shape(ci, b, [Vector2(-0.05, y + tilt), Vector2(1.05, y - tilt), Vector2(1.05, y - tilt + 0.12), Vector2(-0.05, y + tilt + 0.12)], Color(0.45, 0.33, 0.2).darkened(i * 0.05))
				ci.draw_circle(pt(b, 0.05, y + 0.06), lw, Color(0.25, 0.25, 0.25))
				ci.draw_circle(pt(b, 0.95, y + 0.06), lw, Color(0.25, 0.25, 0.25))
		"skull":
			shape(ci, b, [Vector2(0.1, 0.9), Vector2(0.05, 0.5), Vector2(0.2, 0.15), Vector2(0.5, 0.05), Vector2(0.8, 0.15), Vector2(0.95, 0.5), Vector2(0.9, 0.9)], Color(0.4, 0.42, 0.36))
			ci.draw_line(pt(b, 0.0, 0.62), pt(b, 1.0, 0.62), Color(0.25, 0.25, 0.22), lw * 2.0)
		"helmet":
			# post with a helmet padlocked to it
			box(ci, sub(b, 0.44, 0.35, 0.12, 0.65), Color(0.3, 0.2, 0.13))
			shadow(ci, b, 1.0, 0.25)
			shape(ci, b, [Vector2(0.08, 0.5), Vector2(0.12, 0.25), Vector2(0.3, 0.08), Vector2(0.5, 0.04), Vector2(0.7, 0.08), Vector2(0.88, 0.25), Vector2(0.92, 0.5), Vector2(1.0, 0.56), Vector2(0.0, 0.56)], Color(0.35, 0.36, 0.34))
			ci.draw_line(pt(b, 0.2, 0.18), pt(b, 0.45, 0.1), Color(1, 1, 1, 0.25), lw * 2.0)
			var pulse := 0.5 + 0.5 * sin(t * 4.0)
			ci.draw_circle(pt(b, 0.5, 0.3), b.size.x * 0.25, Color(1.0, 0.4, 0.1, 0.05 + 0.06 * pulse))
			if not s.get("unlocked", false):
				ci.draw_arc(pt(b, 0.5, 0.58), b.size.x * 0.07, PI, TAU, 10, Color(0.45, 0.3, 0.2), lw * 2.0, true)
				box(ci, sub(b, 0.4, 0.58, 0.2, 0.12), Color(0.55, 0.32, 0.18))
		"heart":
			_heart(ci, b, t, foe_white)
		"well":
			shadow(ci, b, 0.98, 0.6)
			box(ci, sub(b, 0.08, 0.0, 0.06, 0.6), Color(0.35, 0.24, 0.15))
			box(ci, sub(b, 0.86, 0.0, 0.06, 0.6), Color(0.35, 0.24, 0.15))
			box(ci, sub(b, 0.05, 0.08, 0.9, 0.06), Color(0.4, 0.28, 0.17))
			if s.get("roped", false):
				ci.draw_line(pt(b, 0.5, 0.14), pt(b, 0.5, 0.62), Color(0.72, 0.6, 0.4), lw * 2.0)
			else:
				ci.draw_line(pt(b, 0.5, 0.14), pt(b, 0.5, 0.22), Color(0.35, 0.3, 0.2), lw)
			shape(ci, b, [Vector2(0.0, 0.55), Vector2(1.0, 0.55), Vector2(0.96, 1.0), Vector2(0.04, 1.0)], Color(0.45, 0.43, 0.4))
			ci.draw_colored_polygon(_ellipse(pt(b, 0.5, 0.55), b.size.x * 0.5, b.size.y * 0.08), Color(0.05, 0.05, 0.06))
			for i in 3:
				ci.draw_line(pt(b, 0.02, 0.68 + i * 0.1), pt(b, 0.98, 0.68 + i * 0.1), Color(0.3, 0.29, 0.27), lw)
		"notice":
			box(ci, b, Color(0.8, 0.74, 0.6))
			for i in 5:
				ci.draw_line(pt(b, 0.12, 0.2 + i * 0.15), pt(b, 0.88 - (i % 2) * 0.2, 0.2 + i * 0.15), Color(0.3, 0.25, 0.2, 0.7), lw)
			ci.draw_circle(pt(b, 0.5, 0.06), lw * 1.5, Color(0.6, 0.15, 0.1))
		"cabinet":
			shadow(ci, b, 0.99, 0.5)
			var open3: bool = s.get("open", false)
			box(ci, b, col)
			if open3:
				box(ci, sub(b, 0.06, 0.05, 0.88, 0.9), Color(0.07, 0.05, 0.04))
				for k in [0.35, 0.65]:
					ci.draw_line(pt(b, 0.06, k), pt(b, 0.94, k), col.darkened(0.3), lw * 2.0)
				shape(ci, b, [Vector2(0.0, 0.05), Vector2(-0.3, 0.12), Vector2(-0.3, 0.88), Vector2(0.0, 0.95)], col.darkened(0.15))
				shape(ci, b, [Vector2(1.0, 0.05), Vector2(1.3, 0.12), Vector2(1.3, 0.88), Vector2(1.0, 0.95)], col.darkened(0.15))
			else:
				ci.draw_line(pt(b, 0.5, 0.05), pt(b, 0.5, 0.95), col.darkened(0.45), lw)
				for xx in [0.42, 0.58]:
					ci.draw_circle(pt(b, xx, 0.5), lw * 1.6, Color(0.75, 0.6, 0.3))
				box(ci, sub(b, 0.1, 0.08, 0.32, 0.38), Color(0, 0, 0, 0), col.darkened(0.3), lw)
				box(ci, sub(b, 0.58, 0.08, 0.32, 0.38), Color(0, 0, 0, 0), col.darkened(0.3), lw)
		"hearth":
			box(ci, b, Color(0.45, 0.3, 0.25))
			for i in 6:
				ci.draw_line(pt(b, 0, i / 6.0), pt(b, 1, i / 6.0), Color(0.3, 0.2, 0.16), lw)
			box(ci, sub(b, 0.2, 0.45, 0.6, 0.55), Color(0.06, 0.04, 0.04))
			ci.draw_colored_polygon(_ellipse(pt(b, 0.5, 0.96), b.size.x * 0.22, b.size.y * 0.04), Color(0.3, 0.29, 0.28, 0.9))
			if s.get("broken", false):
				box(ci, sub(b, 0.62, 0.18, 0.16, 0.1), Color(0.05, 0.03, 0.03), Color(0, 0, 0, 0))
			else:
				box(ci, sub(b, 0.6, 0.17, 0.19, 0.12), Color(0.52, 0.34, 0.28), Color(0.25, 0.15, 0.12), lw)
		"statue":
			shadow(ci, b, 0.98, 0.45)
			var turned: bool = s.get("turned", false)
			var dx := 0.22 if turned else 0.0
			var stone := Color(0.45, 0.46, 0.44)
			box(ci, sub(b, 0.15 + dx, 0.88, 0.7, 0.12), stone.darkened(0.2))
			shape(ci, b, [Vector2(0.25 + dx, 0.88), Vector2(0.75 + dx, 0.88), Vector2(0.65 + dx, 0.3), Vector2(0.58 + dx, 0.12), Vector2(0.5 + dx, 0.06), Vector2(0.42 + dx, 0.12), Vector2(0.35 + dx, 0.3)], stone)
			ci.draw_colored_polygon(_ellipse(pt(b, 0.5 + dx, 0.2), b.size.x * 0.06, b.size.y * 0.04), Color(0.1, 0.1, 0.1))
			if turned:
				shape(ci, b, [Vector2(0.4 + dx, 0.45), Vector2(0.2 + dx, 0.55), Vector2(0.2 + dx, 0.6), Vector2(0.42 + dx, 0.52)], stone.darkened(0.1))
			else:
				shape(ci, b, [Vector2(0.62, 0.45), Vector2(0.95, 0.5), Vector2(0.95, 0.56), Vector2(0.62, 0.53)], stone.darkened(0.1))
		"jar":
			shadow(ci, b, 0.98, 0.4)
			shape(ci, b, [Vector2(0.3, 0.0), Vector2(0.7, 0.0), Vector2(0.7, 0.15), Vector2(0.95, 0.45), Vector2(0.85, 1.0), Vector2(0.15, 1.0), Vector2(0.05, 0.45), Vector2(0.3, 0.15)], Color(0.6, 0.38, 0.25))
			box(ci, sub(b, 0.25, 0.0, 0.5, 0.1), Color(0.75, 0.2, 0.15))
			ci.draw_circle(pt(b, 0.5, 0.55), b.size.x * 0.22, Color(1.0, 0.5, 0.15, 0.25 + 0.15 * sin(t * 4.0)))
		"barrel":
			shadow(ci, b, 0.98, 0.5)
			if s.get("broken", false):
				for i in 6:
					var x := 0.05 + i * 0.16
					shape(ci, b, [Vector2(x, 0.9), Vector2(x + 0.12, 0.88), Vector2(x + 0.2, 0.98), Vector2(x + 0.05, 1.0)], Color(0.45, 0.3, 0.17))
				ci.draw_colored_polygon(_ellipse(pt(b, 0.5, 0.95), b.size.x * 0.6, b.size.y * 0.06), Color(0.7, 0.62, 0.4, 0.7))
			else:
				shape(ci, b, [Vector2(0.1, 0.05), Vector2(0.9, 0.05), Vector2(1.0, 0.5), Vector2(0.9, 0.95), Vector2(0.1, 0.95), Vector2(0.0, 0.5)], Color(0.5, 0.34, 0.2))
				for k in [0.18, 0.5, 0.82]:
					ci.draw_line(pt(b, 0.04, k), pt(b, 0.96, k), Color(0.25, 0.25, 0.26), lw * 2.0)
				ci.draw_colored_polygon(_ellipse(pt(b, 0.5, 0.06), b.size.x * 0.4, b.size.y * 0.04), Color(0.4, 0.27, 0.15))
		"table", "desk":
			shadow(ci, b, 0.99, 0.55)
			var wood := Color(0.42, 0.29, 0.17) if o["art"] == "table" else Color(0.35, 0.22, 0.13)
			shape(ci, b, [Vector2(0.05, 0.0), Vector2(0.95, 0.0), Vector2(1.0, 0.22), Vector2(0.0, 0.22)], wood.lightened(0.1))
			box(ci, sub(b, 0.04, 0.22, 0.08, 0.78), wood.darkened(0.2))
			box(ci, sub(b, 0.88, 0.22, 0.08, 0.78), wood.darkened(0.2))
			if o["art"] == "desk":
				box(ci, sub(b, 0.55, 0.22, 0.4, 0.4), wood)
				var drawer := sub(b, 0.6, 0.3, 0.3, 0.14)
				if s.get("open", false):
					drawer.position.y += b.size.y * 0.06
					box(ci, drawer, wood.darkened(0.3))
				else:
					box(ci, drawer, wood.lightened(0.05))
				ci.draw_circle(drawer.get_center(), lw * 1.4, Color(0.75, 0.6, 0.3))
		"pillow":
			shape(ci, b, [Vector2(0.05, 0.2), Vector2(0.95, 0.1), Vector2(1.0, 0.8), Vector2(0.0, 0.9)], Color(0.85, 0.84, 0.78))
			if s.get("empty", false):
				for i in 6:
					ci.draw_circle(pt(b, 0.1 + i * 0.17, 0.0 - (i % 2) * 0.4), lw * 1.5, Color(1, 1, 1, 0.7))
		"lever":
			box(ci, sub(b, 0.2, 0.75, 0.6, 0.25), Color(0.3, 0.3, 0.32))
			var down: bool = s.get("down", false)
			var top := pt(b, 0.85, 0.65) if down else pt(b, 0.5, 0.0)
			ci.draw_line(pt(b, 0.5, 0.8), top, INK, lw * 4.0, true)
			ci.draw_line(pt(b, 0.5, 0.8), top, Color(0.45, 0.45, 0.48), lw * 2.4, true)
			ci.draw_circle(top, b.size.x * 0.16, Color(0.6, 0.15, 0.1))
		"drum":
			var beat := absf(sin(t * 2.6))
			var sc := 1.0 + beat * 0.04
			var bb := Rect2(b.get_center() - b.size * sc * 0.5, b.size * sc)
			shadow(ci, bb, 1.0, 0.45)
			box(ci, sub(bb, 0.05, 0.2, 0.9, 0.7), Color(0.55, 0.12, 0.1))
			for i in 5:
				ci.draw_line(pt(bb, 0.05 + i * 0.22, 0.25), pt(bb, 0.16 + i * 0.22, 0.85), Color(0.9, 0.8, 0.5), lw)
			ci.draw_colored_polygon(_ellipse(pt(bb, 0.5, 0.2), bb.size.x * 0.45, bb.size.y * 0.1), Color(0.9, 0.85, 0.72))
			ci.draw_circle(pt(bb, 0.5, 0.45), bb.size.x * (0.4 + beat * 0.2), Color(1, 0.3, 0.1, 0.08 * beat))
		"winchbox":
			box(ci, b, Color(0.35, 0.36, 0.38))
			ci.draw_circle(b.get_center(), b.size.x * 0.25, Color(0.2, 0.2, 0.22))
			if s.get("cranked", false):
				ci.draw_line(b.get_center(), b.get_center() + Vector2(b.size.x * 0.4, -b.size.y * 0.3), Color(0.5, 0.5, 0.55), lw * 3.0)
			else:
				box(ci, Rect2(b.get_center() - Vector2(4, 4), Vector2(8, 8)), Color(0.05, 0.05, 0.05), Color(0, 0, 0, 0))
		"armor":
			shadow(ci, b, 0.99, 0.4)
			var steel := Color(0.55, 0.57, 0.6)
			if s.get("fallen", false):
				for i in 5:
					ci.draw_colored_polygon(_ellipse(pt(b, 0.15 + i * 0.18, 0.93 - (i % 2) * 0.03), b.size.x * 0.13, b.size.y * 0.04), steel.darkened(i * 0.05))
			else:
				ci.draw_colored_polygon(_ellipse(pt(b, 0.5, 0.1), b.size.x * 0.18, b.size.y * 0.09), steel)
				box(ci, sub(b, 0.4, 0.08, 0.2, 0.025), INK, Color(0, 0, 0, 0))
				shape(ci, b, [Vector2(0.25, 0.2), Vector2(0.75, 0.2), Vector2(0.7, 0.55), Vector2(0.3, 0.55)], steel)
				box(ci, sub(b, 0.08, 0.22, 0.14, 0.35), steel.darkened(0.1))
				box(ci, sub(b, 0.78, 0.22, 0.14, 0.35), steel.darkened(0.1))
				box(ci, sub(b, 0.32, 0.55, 0.14, 0.43), steel.darkened(0.15))
				box(ci, sub(b, 0.54, 0.55, 0.14, 0.43), steel.darkened(0.15))
				box(ci, sub(b, 0.76, 0.55, 0.18, 0.06), Color(0.45, 0.45, 0.48))
		"book":
			shape(ci, b, [Vector2(0.0, 0.2), Vector2(0.5, 0.0), Vector2(1.0, 0.2), Vector2(1.0, 1.0), Vector2(0.5, 0.85), Vector2(0.0, 1.0)], Color(0.88, 0.82, 0.68))
			ci.draw_line(pt(b, 0.5, 0.0), pt(b, 0.5, 0.85), Color(0.5, 0.4, 0.3), lw)
		"slit":
			box(ci, b, Color(0.55, 0.62, 0.72))
			box(ci, sub(b, 0.0, 0.7, 1.0, 0.3), Color(0.35, 0.3, 0.25), Color(0, 0, 0, 0))
		"stone_block":
			if s.get("out", false):
				box(ci, b, Color(0.04, 0.03, 0.03))
			else:
				box(ci, b.grow(2), Color(0.42, 0.41, 0.4))
				ci.draw_rect(b.grow(2), Color(1, 1, 1, 0.12 + 0.06 * sin(t * 2.0)), false, lw)
		"bell":
			ci.draw_line(pt(b, -0.2, 0.02), pt(b, 1.2, 0.02), Color(0.3, 0.2, 0.12), lw * 5.0)
			var sw := sin(t * 1.5) * 0.02
			shape(ci, b, [Vector2(0.38 + sw, 0.06), Vector2(0.62 + sw, 0.06), Vector2(0.75, 0.45), Vector2(0.95, 0.88), Vector2(0.05, 0.88), Vector2(0.25, 0.45)], Color(0.7, 0.5, 0.22))
			ci.draw_line(pt(b, 0.1, 0.8), pt(b, 0.9, 0.8), Color(0.5, 0.35, 0.15), lw * 2.0)
			ci.draw_line(pt(b, 0.35, 0.2), pt(b, 0.25, 0.7), Color(1, 0.9, 0.6, 0.35), lw * 2.0)
		"cage":
			var open4: bool = s.get("open", false)
			ci.draw_line(pt(b, 0.5, -0.4), pt(b, 0.5, 0.0), Color(0.3, 0.3, 0.32), lw * 1.5)
			box(ci, sub(b, 0.0, 0.0, 1.0, 0.06), Color(0.25, 0.25, 0.27))
			box(ci, sub(b, 0.0, 0.94, 1.0, 0.06), Color(0.25, 0.25, 0.27))
			var n := 7
			for i in n + 1:
				var x := float(i) / n
				if open4 and x > 0.2 and x < 0.8:
					continue
				ci.draw_line(pt(b, x, 0.03), pt(b, x, 0.97), Color(0.35, 0.35, 0.38), lw * 1.6)
			if open4:
				for i in 3:
					ci.draw_line(pt(b, 1.05 + i * 0.07, 0.08), pt(b, 1.05 + i * 0.07, 0.92), Color(0.35, 0.35, 0.38), lw * 1.4)
		"skeleton":
			var bone := Color(0.82, 0.8, 0.7)
			ci.draw_circle(pt(b, 0.5, 0.15), b.size.x * 0.17, bone)
			ci.draw_circle(pt(b, 0.43, 0.14), b.size.x * 0.05, INK)
			ci.draw_circle(pt(b, 0.57, 0.14), b.size.x * 0.05, INK)
			ci.draw_line(pt(b, 0.5, 0.3), pt(b, 0.5, 0.65), bone, lw * 2.0)
			for i in 4:
				ci.draw_line(pt(b, 0.3, 0.36 + i * 0.07), pt(b, 0.7, 0.36 + i * 0.07), bone, lw * 1.2)
			ci.draw_line(pt(b, 0.5, 0.65), pt(b, 0.1, 0.95), bone, lw * 2.0)
			ci.draw_line(pt(b, 0.5, 0.65), pt(b, 0.95, 0.9), bone, lw * 2.0)
			ci.draw_line(pt(b, 0.32, 0.38), pt(b, 0.05, 0.62), bone, lw * 1.6)
			ci.draw_line(pt(b, 0.68, 0.38), pt(b, 0.9, 0.6), bone, lw * 1.6)
			box(ci, sub(b, 0.82, 0.55, 0.16, 0.1), Color(0.85, 0.8, 0.65))
		"painting":
			box(ci, b.grow(4), Color(0.6, 0.45, 0.2))
			box(ci, b, Color(0.25, 0.22, 0.25))
			PieceArt.draw_piece(ci, 4, foe_white, b.get_center().x, b.end.y - b.size.y * 0.08, b.size.y * 0.62, Color(1, 1, 1, 0.85), false)
		"sacks":
			for i in 3:
				var sb := sub(b, i * 0.3, 0.2 + (i % 2) * 0.15, 0.42, 0.7)
				shape(ci, sb, [Vector2(0.3, 0.0), Vector2(0.7, 0.0), Vector2(0.95, 0.5), Vector2(0.85, 1.0), Vector2(0.15, 1.0), Vector2(0.05, 0.5)], Color(0.6, 0.52, 0.36).darkened(i * 0.08))
		"chains":
			for k in [0.25, 0.75]:
				var y := 0.0
				while y < 0.9:
					ci.draw_arc(pt(b, k, y + 0.05), b.size.x * 0.08, 0, TAU, 10, Color(0.4, 0.33, 0.28), lw * 1.4, true)
					y += 0.1
				ci.draw_arc(pt(b, k, 0.95), b.size.x * 0.16, 0, PI, 10, Color(0.4, 0.33, 0.28), lw * 2.0, true)
		"stained":
			var colors: Array = o.get("colors", ["red", "blue", "gold"])
			var cmap := {"red": Color(0.85, 0.15, 0.15), "blue": Color(0.2, 0.35, 0.9), "gold": Color(0.95, 0.75, 0.2)}
			shape(ci, b, [Vector2(0.0, 1.0), Vector2(0.0, 0.2), Vector2(0.5, 0.0), Vector2(1.0, 0.2), Vector2(1.0, 1.0)], Color(0.2, 0.18, 0.2), Color(0.35, 0.33, 0.3), lw * 2.0)
			var glow := 0.75 + 0.25 * sin(t * 1.5)
			for i in 3:
				var c: Color = cmap[colors[i]]
				var pane := sub(b, 0.12, 0.2 + i * 0.26, 0.76, 0.22)
				box(ci, pane, Color(c.r * glow, c.g * glow, c.b * glow), INK, lw)
				_emblem(ci, pane, String(colors[i]))
		"votive":
			box(ci, sub(b, 0.0, 0.55, 1.0, 0.45), Color(0.3, 0.2, 0.15))
			for i in 5:
				var x := 0.1 + i * 0.2
				box(ci, sub(b, x - 0.05, 0.35, 0.1, 0.2), Color(0.95, 0.9, 0.8), Color(0, 0, 0, 0))
				var fl := 1.0 + sin(t * 9.0 + i) * 0.15
				ci.draw_circle(pt(b, x, 0.28), b.size.x * 0.035 * fl, Color(1.0, 0.75, 0.3))
				ci.draw_circle(pt(b, x, 0.28), b.size.x * 0.09, Color(1.0, 0.6, 0.2, 0.15))
		"pews":
			for i in 2:
				var pb := sub(b, 0.0, i * 0.5, 1.0, 0.5)
				box(ci, sub(pb, 0.0, 0.0, 0.42, 0.75), Color(0.45, 0.43, 0.4))
				box(ci, sub(pb, 0.58, 0.0, 0.42, 0.75), Color(0.45, 0.43, 0.4))
		"robes":
			ci.draw_line(pt(b, 0.0, 0.03), pt(b, 1.0, 0.03), Color(0.3, 0.2, 0.12), lw * 3.0)
			for i in 2:
				var x := 0.05 + i * 0.5
				shape(ci, b, [Vector2(x + 0.15, 0.05), Vector2(x + 0.3, 0.05), Vector2(x + 0.45, 1.0), Vector2(x, 1.0)], Color(0.55, 0.12, 0.2) if i == 0 else Color(0.85, 0.82, 0.75))
		"lamp":
			var lit: bool = s.get("lit", false)
			box(ci, sub(b, 0.42, 0.45, 0.16, 0.55), Color(0.3, 0.28, 0.25))
			shape(ci, b, [Vector2(0.15, 0.1), Vector2(0.85, 0.1), Vector2(0.75, 0.45), Vector2(0.25, 0.45)], col.darkened(0.0 if lit else 0.5), INK, lw)
			if lit:
				var fl2 := 1.0 + sin(t * 8.0 + b.position.x) * 0.1
				ci.draw_circle(pt(b, 0.5, 0.25), b.size.x * 0.9 * fl2, Color(col.r, col.g, col.b, 0.12))
				ci.draw_circle(pt(b, 0.5, 0.25), b.size.x * 0.2 * fl2, Color(1, 0.95, 0.7, 0.9))
		"altar":
			var moved: bool = s.get("moved", false)
			var off := 0.35 if moved else 0.0
			shadow(ci, b, 0.99, 0.55)
			box(ci, sub(b, 0.0 + off, 0.2, 1.0, 0.8), Color(0.12, 0.11, 0.13))
			box(ci, sub(b, -0.05 + off, 0.1, 1.1, 0.15), Color(0.18, 0.17, 0.2))
			for i in 4:
				ci.draw_line(pt(b, 0.1 + i * 0.2 + off, 0.3), pt(b, 0.25 + i * 0.2 + off, 0.95), Color(0.3, 0.28, 0.32), lw)
		"reliquary":
			shadow(ci, b, 0.99, 0.55)
			var open5: bool = s.get("open", false)
			box(ci, sub(b, 0.0, 0.3, 1.0, 0.7), Color(0.5, 0.48, 0.44))
			for i in 4:
				ci.draw_line(pt(b, 0.1 + i * 0.22, 0.4), pt(b, 0.2 + i * 0.22, 0.9), Color(0.35, 0.33, 0.3), lw)
			if open5:
				box(ci, sub(b, -0.1, 0.05, 0.5, 0.12), Color(0.55, 0.53, 0.5))
				box(ci, sub(b, 0.05, 0.3, 0.9, 0.08), Color(0.9, 0.85, 0.6, 0.6), Color(0, 0, 0, 0))
			else:
				box(ci, sub(b, -0.04, 0.2, 1.08, 0.12), Color(0.55, 0.53, 0.5))
				ci.draw_line(pt(b, 0.0, 0.33), pt(b, 1.0, 0.33), Color(1, 0.9, 0.6, 0.4 + 0.2 * sin(t * 3.0)), lw)
		"bookshelf":
			box(ci, b, Color(0.3, 0.19, 0.11))
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for shelf in 5:
				var y1 := 0.05 + (shelf + 1) * 0.18
				var x := 0.06
				while x < 0.92:
					var w := rng.randf_range(0.05, 0.1)
					var hh := rng.randf_range(0.11, 0.16)
					var c := Color.from_hsv(rng.randf_range(0.0, 0.12), 0.5, rng.randf_range(0.3, 0.55))
					if shelf == 2 and x > 0.4 and x < 0.55:
						c = Color(0.7, 0.55, 0.2)
					box(ci, sub(b, x, y1 - hh, w, hh), c, Color(0, 0, 0, 0))
					x += w + 0.01
				ci.draw_line(pt(b, 0.04, y1), pt(b, 0.96, y1), Color(0.18, 0.11, 0.06), lw * 2.0)
		"lectern":
			shadow(ci, b, 0.99, 0.4)
			box(ci, sub(b, 0.4, 0.25, 0.2, 0.75), Color(0.35, 0.23, 0.13))
			shape(ci, b, [Vector2(0.0, 0.25), Vector2(1.0, 0.1), Vector2(1.0, 0.3), Vector2(0.0, 0.4)], Color(0.42, 0.28, 0.16))
			shape(ci, b, [Vector2(0.08, 0.2), Vector2(0.5, 0.08), Vector2(0.92, 0.12), Vector2(0.5, 0.24)], Color(0.9, 0.85, 0.7))
		"dial":
			ci.draw_circle(b.get_center(), minf(b.size.x, b.size.y) * 0.5, Color(0.75, 0.6, 0.3))
			ci.draw_circle(b.get_center(), minf(b.size.x, b.size.y) * 0.4, Color(0.18, 0.14, 0.1))
			var v := str(int(s.get("value", 0)))
			var fs := int(b.size.y * 0.6)
			var font := ThemeDB.fallback_font
			var tw := font.get_string_size(v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			ci.draw_string(font, b.get_center() + Vector2(-tw * 0.5, fs * 0.35), v, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.9, 0.6))
		"stool":
			shadow(ci, b, 0.99, 0.5)
			box(ci, sub(b, 0.0, 0.0, 1.0, 0.3), Color(0.4, 0.27, 0.16))
			box(ci, sub(b, 0.1, 0.3, 0.12, 0.7), Color(0.32, 0.21, 0.12))
			box(ci, sub(b, 0.78, 0.3, 0.12, 0.7), Color(0.32, 0.21, 0.12))
		_:
			box(ci, b, col)


static func _emblem(ci: CanvasItem, r: Rect2, kind: String) -> void:
	var c := Color(0.1, 0.07, 0.05, 0.7)
	match kind:
		"gold":
			ci.draw_circle(r.get_center(), r.size.y * 0.25, c)
		"blue":
			shape(ci, r, [Vector2(0.25, 0.5), Vector2(0.5, 0.3), Vector2(0.7, 0.5), Vector2(0.5, 0.7)], c, Color(0, 0, 0, 0))
			shape(ci, r, [Vector2(0.7, 0.5), Vector2(0.82, 0.32), Vector2(0.82, 0.68)], c, Color(0, 0, 0, 0))
		"red":
			ci.draw_circle(r.get_center() + Vector2(-r.size.x * 0.12, 0), r.size.y * 0.22, c)
			shape(ci, r, [Vector2(0.45, 0.35), Vector2(0.8, 0.4), Vector2(0.8, 0.75), Vector2(0.45, 0.7)], c, Color(0, 0, 0, 0))


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _heart(ci: CanvasItem, b: Rect2, t: float, foe_white: bool) -> void:
	var beat := pow(absf(sin(t * 2.4)), 6.0)
	var sc := 1.0 + beat * 0.12
	var c := b.get_center()
	var base := Color(0.92, 0.85, 0.6) if foe_white else Color(0.45, 0.12, 0.22)
	var glow := Color(1.0, 0.85, 0.4) if foe_white else Color(1.0, 0.35, 0.12)
	for i in 4:
		ci.draw_circle(c, b.size.x * (0.5 + i * 0.25) * sc, Color(glow.r, glow.g, glow.b, 0.05 + beat * 0.04))
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * (b.size.x / 34.0) * sc)
	ci.draw_colored_polygon(pts, base)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, glow, 2.0, true)
	ci.draw_circle(c + Vector2(-b.size.x * 0.15, -b.size.y * 0.12) * sc, b.size.x * 0.08, Color(1, 1, 1, 0.35))
	# ember cracks
	ci.draw_line(c + Vector2(-0.1, -0.15) * b.size.x, c + Vector2(0.05, 0.1) * b.size.x, Color(glow.r, glow.g, glow.b, 0.8), 1.5, true)
	ci.draw_line(c + Vector2(0.05, 0.1) * b.size.x, c + Vector2(0.15, 0.0) * b.size.x, Color(glow.r, glow.g, glow.b, 0.8), 1.5, true)
