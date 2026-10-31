class_name ItemArt
extends RefCounted
## Procedurally drawn inventory icons.

static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func _poly(r: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(_p(r, v.x, v.y))
	return out


static func _outline(ci: CanvasItem, pts: PackedVector2Array, c: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, c, w, true)


static func _shape(ci: CanvasItem, r: Rect2, pts: Array, fill: Color, line: Color, w: float) -> void:
	var p := _poly(r, pts)
	ci.draw_colored_polygon(p, fill)
	_outline(ci, p, line, w)


static func _flame(ci: CanvasItem, r: Rect2, x: float, y: float, sc: float, t: float) -> void:
	var flick := 1.0 + sin(t * 13.0 + x * 7.0) * 0.08
	var outer := [Vector2(x, y - 0.16 * sc * flick), Vector2(x + 0.07 * sc, y - 0.02 * sc), Vector2(x + 0.05 * sc, y + 0.05 * sc),
		Vector2(x, y + 0.07 * sc), Vector2(x - 0.05 * sc, y + 0.05 * sc), Vector2(x - 0.07 * sc, y - 0.02 * sc)]
	ci.draw_circle(_p(r, x, y), r.size.x * 0.16 * sc, Color(1, 0.6, 0.2, 0.18))
	ci.draw_colored_polygon(_poly(r, outer), Color(1.0, 0.55, 0.15))
	var inner := []
	for v in outer:
		inner.append(Vector2(x + (v.x - x) * 0.55, y + 0.02 * sc + (v.y - y) * 0.55))
	ci.draw_colored_polygon(_poly(r, inner), Color(1.0, 0.92, 0.55))


static func draw_icon(ci: CanvasItem, id: String, r: Rect2, t: float = 0.0) -> void:
	if not Game.ITEMS.has(id):
		return
	var info: Dictionary = Game.ITEMS[id]
	var col: Color = info["color"]
	var line := Color(0.08, 0.06, 0.06)
	var w := maxf(1.2, r.size.x * 0.035)
	match String(info["icon"]):
		"flask":
			_shape(ci, r, [Vector2(0.42, 0.14), Vector2(0.58, 0.14), Vector2(0.58, 0.36), Vector2(0.78, 0.62), Vector2(0.76, 0.84),
				Vector2(0.64, 0.9), Vector2(0.36, 0.9), Vector2(0.24, 0.84), Vector2(0.22, 0.62), Vector2(0.42, 0.36)],
				Color(0.85, 0.9, 0.95, 0.35), line, w)
			_shape(ci, r, [Vector2(0.29, 0.6), Vector2(0.71, 0.6), Vector2(0.745, 0.82), Vector2(0.63, 0.87), Vector2(0.37, 0.87), Vector2(0.255, 0.82)], col, col.darkened(0.4), w * 0.6)
			ci.draw_rect(Rect2(_p(r, 0.39, 0.08), r.size * Vector2(0.22, 0.09)), Color(0.55, 0.38, 0.25))
			ci.draw_circle(_p(r, 0.38, 0.68), r.size.x * 0.04, Color(1, 1, 1, 0.6))
		"ash":
			_shape(ci, r, [Vector2(0.14, 0.82), Vector2(0.3, 0.6), Vector2(0.45, 0.5), Vector2(0.58, 0.52), Vector2(0.72, 0.62), Vector2(0.86, 0.82)], col, Color(0.25, 0.24, 0.24), w)
			for i in 7:
				var px := 0.25 + fmod(i * 0.37, 0.5)
				var py := 0.62 + fmod(i * 0.23, 0.18)
				ci.draw_circle(_p(r, px, py), r.size.x * 0.018, Color(0.3, 0.29, 0.29))
			ci.draw_circle(_p(r, 0.52, 0.56), r.size.x * 0.03, Color(1, 0.5, 0.2, 0.6 + 0.3 * sin(t * 4.0)))
		"stone":
			_shape(ci, r, [Vector2(0.12, 0.62), Vector2(0.24, 0.4), Vector2(0.8, 0.32), Vector2(0.9, 0.5), Vector2(0.78, 0.7), Vector2(0.22, 0.76)], col, line, w)
			ci.draw_line(_p(r, 0.25, 0.48), _p(r, 0.78, 0.4), Color(1, 1, 1, 0.5), w)
		"charm":
			ci.draw_arc(_p(r, 0.5, 0.36), r.size.x * 0.22, PI * 1.05, PI * 1.95, 16, Color(0.7, 0.6, 0.4), w, true)
			var pts := []
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				pts.append(Vector2(0.5 + cos(a) * 0.22, 0.6 + sin(a) * 0.22))
			_shape(ci, r, pts, col, line, w)
			ci.draw_circle(_p(r, 0.5, 0.6), r.size.x * 0.08, Color(0.3, 0.75, 0.8))
		"matches":
			_shape(ci, r, [Vector2(0.18, 0.4), Vector2(0.82, 0.4), Vector2(0.82, 0.8), Vector2(0.18, 0.8)], col, line, w)
			for i in 3:
				var x := 0.34 + i * 0.14
				ci.draw_line(_p(r, x, 0.42), _p(r, x + 0.04, 0.16), Color(0.85, 0.75, 0.55), w * 1.2)
				ci.draw_circle(_p(r, x + 0.04, 0.16), r.size.x * 0.035, Color(0.7, 0.1, 0.1))
		"lantern", "lantern_lit":
			ci.draw_arc(_p(r, 0.5, 0.2), r.size.x * 0.12, PI, TAU, 12, line, w, true)
			_shape(ci, r, [Vector2(0.3, 0.24), Vector2(0.7, 0.24), Vector2(0.66, 0.32), Vector2(0.34, 0.32)], col.darkened(0.3), line, w)
			var glass := Color(1, 0.8, 0.4, 0.75) if info["icon"] == "lantern_lit" else Color(0.5, 0.5, 0.45, 0.4)
			_shape(ci, r, [Vector2(0.34, 0.32), Vector2(0.66, 0.32), Vector2(0.7, 0.78), Vector2(0.3, 0.78)], glass, line, w)
			_shape(ci, r, [Vector2(0.26, 0.78), Vector2(0.74, 0.78), Vector2(0.74, 0.88), Vector2(0.26, 0.88)], Color(0.35, 0.33, 0.3), line, w)
			if info["icon"] == "lantern_lit":
				_flame(ci, r, 0.5, 0.6, 1.0, t)
		"key":
			ci.draw_circle(_p(r, 0.3, 0.5), r.size.x * 0.16, line)
			ci.draw_circle(_p(r, 0.3, 0.5), r.size.x * 0.14, col)
			ci.draw_circle(_p(r, 0.3, 0.5), r.size.x * 0.06, Color(0.08, 0.06, 0.06))
			_shape(ci, r, [Vector2(0.43, 0.46), Vector2(0.88, 0.46), Vector2(0.88, 0.54), Vector2(0.43, 0.54)], col, line, w)
			_shape(ci, r, [Vector2(0.72, 0.54), Vector2(0.78, 0.54), Vector2(0.78, 0.68), Vector2(0.72, 0.68)], col, line, w)
			_shape(ci, r, [Vector2(0.82, 0.54), Vector2(0.88, 0.54), Vector2(0.88, 0.64), Vector2(0.82, 0.64)], col, line, w)
		"rope":
			for i in 4:
				ci.draw_arc(_p(r, 0.5, 0.55), r.size.x * (0.3 - i * 0.065), 0, TAU, 24, col.darkened(i * 0.12), r.size.x * 0.05, true)
			ci.draw_line(_p(r, 0.78, 0.55), _p(r, 0.9, 0.85), col, r.size.x * 0.05, true)
		"oilcan":
			_shape(ci, r, [Vector2(0.2, 0.45), Vector2(0.6, 0.45), Vector2(0.66, 0.85), Vector2(0.14, 0.85)], col, line, w)
			_shape(ci, r, [Vector2(0.32, 0.36), Vector2(0.48, 0.36), Vector2(0.5, 0.45), Vector2(0.3, 0.45)], col.darkened(0.2), line, w)
			ci.draw_line(_p(r, 0.55, 0.52), _p(r, 0.9, 0.16), line, w * 2.2, true)
			ci.draw_line(_p(r, 0.55, 0.52), _p(r, 0.9, 0.16), col.lightened(0.2), w, true)
		"coin":
			ci.draw_circle(_p(r, 0.5, 0.5), r.size.x * 0.3, line)
			ci.draw_circle(_p(r, 0.5, 0.5), r.size.x * 0.28, col)
			ci.draw_circle(_p(r, 0.5, 0.5), r.size.x * 0.2, col.darkened(0.15))
			_shape(ci, r, [Vector2(0.4, 0.56), Vector2(0.4, 0.44), Vector2(0.45, 0.5), Vector2(0.5, 0.42), Vector2(0.55, 0.5), Vector2(0.6, 0.44), Vector2(0.6, 0.56)], col.lightened(0.3), col.darkened(0.4), w * 0.6)
		"crank":
			ci.draw_line(_p(r, 0.25, 0.75), _p(r, 0.25, 0.3), line, w * 4.0, true)
			ci.draw_line(_p(r, 0.25, 0.3), _p(r, 0.75, 0.3), line, w * 4.0, true)
			ci.draw_line(_p(r, 0.75, 0.3), _p(r, 0.75, 0.55), line, w * 4.0, true)
			ci.draw_line(_p(r, 0.25, 0.75), _p(r, 0.25, 0.3), col, w * 2.4, true)
			ci.draw_line(_p(r, 0.25, 0.3), _p(r, 0.75, 0.3), col, w * 2.4, true)
			ci.draw_line(_p(r, 0.75, 0.3), _p(r, 0.75, 0.55), col, w * 2.4, true)
			_shape(ci, r, [Vector2(0.68, 0.55), Vector2(0.82, 0.55), Vector2(0.82, 0.82), Vector2(0.68, 0.82)], Color(0.45, 0.3, 0.2), line, w)
		"hammer":
			ci.draw_line(_p(r, 0.3, 0.88), _p(r, 0.62, 0.3), line, w * 4.0, true)
			ci.draw_line(_p(r, 0.3, 0.88), _p(r, 0.62, 0.3), col, w * 2.4, true)
			_shape(ci, r, [Vector2(0.42, 0.22), Vector2(0.72, 0.12), Vector2(0.86, 0.36), Vector2(0.56, 0.46)], Color(0.8, 0.55, 0.25), line, w)
		"flint":
			_shape(ci, r, [Vector2(0.14, 0.66), Vector2(0.24, 0.46), Vector2(0.46, 0.44), Vector2(0.52, 0.66), Vector2(0.32, 0.8)], Color(0.35, 0.36, 0.4), line, w)
			_shape(ci, r, [Vector2(0.55, 0.3), Vector2(0.88, 0.3), Vector2(0.88, 0.42), Vector2(0.64, 0.42), Vector2(0.64, 0.7), Vector2(0.55, 0.7)], col, line, w)
			for i in 4:
				var a := -1.2 + i * 0.4
				ci.draw_line(_p(r, 0.52, 0.46), _p(r, 0.52, 0.46) + Vector2(cos(a), sin(a)) * r.size.x * 0.12, Color(1, 0.85, 0.3), w, true)
		"torch", "torch_lit":
			_shape(ci, r, [Vector2(0.46, 0.4), Vector2(0.56, 0.4), Vector2(0.54, 0.92), Vector2(0.48, 0.92)], Color(0.5, 0.33, 0.18), line, w)
			_shape(ci, r, [Vector2(0.38, 0.3), Vector2(0.64, 0.3), Vector2(0.6, 0.46), Vector2(0.42, 0.46)], Color(0.35, 0.28, 0.22), line, w)
			if info["icon"] == "torch_lit":
				_flame(ci, r, 0.51, 0.2, 1.4, t)
		"candle", "candle_lit":
			_shape(ci, r, [Vector2(0.4, 0.32), Vector2(0.6, 0.32), Vector2(0.6, 0.82), Vector2(0.4, 0.82)], Color(0.96, 0.92, 0.8), line, w)
			_shape(ci, r, [Vector2(0.28, 0.82), Vector2(0.72, 0.82), Vector2(0.72, 0.9), Vector2(0.28, 0.9)], Color(0.6, 0.5, 0.3), line, w)
			ci.draw_line(_p(r, 0.5, 0.32), _p(r, 0.5, 0.25), line, w, true)
			if info["icon"] == "candle_lit":
				_flame(ci, r, 0.5, 0.2, 0.9, t)
		"ribbon":
			_shape(ci, r, [Vector2(0.38, 0.1), Vector2(0.62, 0.1), Vector2(0.62, 0.9), Vector2(0.5, 0.78), Vector2(0.38, 0.9)], col, line, w)
			for i in 3:
				ci.draw_circle(_p(r, 0.5, 0.28 + i * 0.17), r.size.x * 0.035, Color(0.95, 0.8, 0.4))
		"lens":
			ci.draw_line(_p(r, 0.58, 0.58), _p(r, 0.88, 0.88), Color(0.4, 0.26, 0.16), w * 3.5, true)
			ci.draw_circle(_p(r, 0.42, 0.42), r.size.x * 0.26, Color(0.75, 0.6, 0.3))
			ci.draw_circle(_p(r, 0.42, 0.42), r.size.x * 0.21, col)
			ci.draw_arc(_p(r, 0.42, 0.42), r.size.x * 0.14, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.8), w, true)
		"whistle":
			_shape(ci, r, [Vector2(0.12, 0.42), Vector2(0.56, 0.42), Vector2(0.56, 0.58), Vector2(0.12, 0.58)], col, line, w)
			ci.draw_circle(_p(r, 0.66, 0.58), r.size.x * 0.18, line)
			ci.draw_circle(_p(r, 0.66, 0.58), r.size.x * 0.16, col)
			ci.draw_rect(Rect2(_p(r, 0.42, 0.36), r.size * Vector2(0.1, 0.06)), Color(0.08, 0.06, 0.06))
		"espresso":
			# a tiny cup with a double shot and a lot of steam
			_shape(ci, r, [Vector2(0.24, 0.42), Vector2(0.7, 0.42), Vector2(0.66, 0.78), Vector2(0.28, 0.78)], Color(0.95, 0.94, 0.9), line, w)
			ci.draw_arc(_p(r, 0.74, 0.56), r.size.x * 0.09, -PI * 0.5, PI * 0.5, 10, line, w * 1.4, true)
			ci.draw_rect(Rect2(_p(r, 0.27, 0.44), r.size * Vector2(0.4, 0.07)), col)
			_shape(ci, r, [Vector2(0.14, 0.8), Vector2(0.82, 0.8), Vector2(0.76, 0.87), Vector2(0.2, 0.87)], Color(0.85, 0.84, 0.8), line, w)
			for i in 2:
				var x := 0.38 + i * 0.16
				var wob := sin(t * 3.0 + i) * 0.03
				ci.draw_polyline(PackedVector2Array([_p(r, x, 0.36), _p(r, x + 0.05 + wob, 0.27), _p(r, x - 0.03, 0.18), _p(r, x + 0.03 + wob, 0.1)]), Color(1, 1, 1, 0.6), w, true)
			ci.draw_string(ThemeDB.fallback_font, _p(r, 0.38, 0.68), "x2", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.y * 0.18), Color(0.3, 0.18, 0.1))
		"rifle":
			ci.draw_line(_p(r, 0.08, 0.62), _p(r, 0.92, 0.36), line, w * 3.2, true)
			ci.draw_line(_p(r, 0.08, 0.62), _p(r, 0.92, 0.36), col, w * 1.6, true)
			_shape(ci, r, [Vector2(0.06, 0.6), Vector2(0.34, 0.52), Vector2(0.38, 0.62), Vector2(0.12, 0.78)], Color(0.45, 0.3, 0.18), line, w)
			_shape(ci, r, [Vector2(0.4, 0.4), Vector2(0.62, 0.34), Vector2(0.63, 0.4), Vector2(0.41, 0.46)], Color(0.15, 0.15, 0.17), line, w)
			ci.draw_line(_p(r, 0.46, 0.55), _p(r, 0.44, 0.66), line, w * 1.5, true)
			ci.draw_circle(_p(r, 0.62, 0.37), r.size.x * 0.035, Color(0.6, 0.85, 1.0))
		"ram":
			_shape(ci, r, [Vector2(0.06, 0.34), Vector2(0.94, 0.34), Vector2(0.94, 0.66), Vector2(0.06, 0.66)], col, line, w)
			for i in 4:
				ci.draw_rect(Rect2(_p(r, 0.12 + i * 0.2, 0.39), r.size * Vector2(0.15, 0.17)), Color(0.1, 0.1, 0.12))
			for i in 12:
				ci.draw_rect(Rect2(_p(r, 0.09 + i * 0.07, 0.6), r.size * Vector2(0.04, 0.05)), Color(0.95, 0.8, 0.3))
		"nuke":
			# a battered suitcase with a radiation trefoil
			_shape(ci, r, [Vector2(0.1, 0.3), Vector2(0.9, 0.3), Vector2(0.9, 0.84), Vector2(0.1, 0.84)], Color(0.32, 0.3, 0.26), line, w)
			_outline(ci, _poly(r, [Vector2(0.38, 0.3), Vector2(0.38, 0.18), Vector2(0.62, 0.18), Vector2(0.62, 0.3)]), line, w * 1.4)
			var c := _p(r, 0.5, 0.57)
			var rad := r.size.x * 0.22
			ci.draw_circle(c, rad, col)
			for k in 3:
				var a0 := -PI * 0.5 + k * TAU / 3.0 - 0.5
				var pts := PackedVector2Array([c])
				for i in 7:
					pts.append(c + Vector2.from_angle(a0 + i / 6.0) * rad * 0.85)
				ci.draw_colored_polygon(pts, Color(0.1, 0.08, 0.06))
			ci.draw_circle(c, rad * 0.22, col)
			ci.draw_circle(c, rad * 0.13, Color(0.1, 0.08, 0.06))
			if int(t * 2.0) % 2 == 0:
				ci.draw_circle(_p(r, 0.82, 0.38), r.size.x * 0.035, Color(1, 0.2, 0.15))
		"phone":
			_shape(ci, r, [Vector2(0.32, 0.12), Vector2(0.68, 0.12), Vector2(0.7, 0.88), Vector2(0.3, 0.88)], col, line, w)
			ci.draw_rect(Rect2(_p(r, 0.37, 0.2), r.size * Vector2(0.26, 0.24)), Color(0.55, 0.9, 0.7))
			for i in 9:
				ci.draw_circle(_p(r, 0.4 + (i % 3) * 0.1, 0.56 + (i / 3) * 0.09), r.size.x * 0.025, Color(0.15, 0.08, 0.12))
			ci.draw_line(_p(r, 0.64, 0.12), _p(r, 0.66, 0.02), line, w * 1.5, true)
			if int(t * 3.0) % 2 == 0:
				ci.draw_arc(_p(r, 0.72, 0.18), r.size.x * 0.1, -1.2, 0.2, 8, UI.GOLD, w, true)
				ci.draw_arc(_p(r, 0.72, 0.18), r.size.x * 0.17, -1.2, 0.2, 8, UI.GOLD, w, true)
		"car":
			_shape(ci, r, [Vector2(0.08, 0.66), Vector2(0.1, 0.52), Vector2(0.3, 0.48), Vector2(0.4, 0.34), Vector2(0.66, 0.34), Vector2(0.78, 0.48), Vector2(0.92, 0.52), Vector2(0.92, 0.68)], col, line, w)
			_shape(ci, r, [Vector2(0.42, 0.38), Vector2(0.52, 0.38), Vector2(0.52, 0.48), Vector2(0.36, 0.48)], Color(0.8, 0.92, 1.0), line, w * 0.6)
			_shape(ci, r, [Vector2(0.56, 0.38), Vector2(0.64, 0.38), Vector2(0.72, 0.48), Vector2(0.56, 0.48)], Color(0.8, 0.92, 1.0), line, w * 0.6)
			for x in [0.27, 0.73]:
				ci.draw_circle(_p(r, x, 0.7), r.size.x * 0.1, line)
				ci.draw_circle(_p(r, x, 0.7), r.size.x * 0.05, Color(0.75, 0.75, 0.8))
			ci.draw_rect(Rect2(_p(r, 0.6, 0.8), r.size * Vector2(0.3, 0.12)), Color(1.0, 0.6, 0.8))
		"nitrous":
			_shape(ci, r, [Vector2(0.34, 0.26), Vector2(0.66, 0.26), Vector2(0.7, 0.34), Vector2(0.7, 0.86), Vector2(0.3, 0.86), Vector2(0.3, 0.34)], col, line, w)
			ci.draw_rect(Rect2(_p(r, 0.44, 0.12), r.size * Vector2(0.12, 0.14)), Color(0.7, 0.7, 0.75))
			ci.draw_rect(Rect2(_p(r, 0.3, 0.5), r.size * Vector2(0.4, 0.14)), Color(0.95, 0.95, 1.0))
			ci.draw_string(ThemeDB.fallback_font, _p(r, 0.33, 0.62), "NOS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r.size.y * 0.13), Color(0.85, 0.15, 0.1))
		"roses":
			ci.draw_line(_p(r, 0.5, 0.88), _p(r, 0.3, 0.42), Color(0.2, 0.55, 0.25), w * 1.4, true)
			ci.draw_line(_p(r, 0.5, 0.88), _p(r, 0.5, 0.36), Color(0.2, 0.55, 0.25), w * 1.4, true)
			ci.draw_line(_p(r, 0.5, 0.88), _p(r, 0.7, 0.42), Color(0.2, 0.55, 0.25), w * 1.4, true)
			for c in [Vector2(0.3, 0.36), Vector2(0.5, 0.28), Vector2(0.7, 0.36)]:
				ci.draw_circle(_p(r, c.x, c.y), r.size.x * 0.12, col.darkened(0.2))
				ci.draw_circle(_p(r, c.x, c.y), r.size.x * 0.08, col)
				ci.draw_arc(_p(r, c.x, c.y), r.size.x * 0.05, 0, PI * 1.5, 8, col.darkened(0.45), w * 0.8, true)
			_shape(ci, r, [Vector2(0.36, 0.62), Vector2(0.64, 0.62), Vector2(0.56, 0.78), Vector2(0.44, 0.78)], Color(0.95, 0.9, 0.75), line, w * 0.7)
		"headlamp":
			ci.draw_arc(_p(r, 0.5, 0.56), r.size.x * 0.3, PI * 0.95, PI * 2.05, 18, Color(0.25, 0.25, 0.3), w * 3.0, true)
			_shape(ci, r, [Vector2(0.36, 0.3), Vector2(0.64, 0.3), Vector2(0.66, 0.5), Vector2(0.34, 0.5)], Color(0.3, 0.3, 0.35), line, w)
			ci.draw_circle(_p(r, 0.5, 0.4), r.size.x * 0.08, col)
			ci.draw_colored_polygon(_poly(r, [Vector2(0.5, 0.4), Vector2(0.95, 0.1), Vector2(0.95, 0.7)]), Color(1.0, 0.95, 0.6, 0.25 + 0.1 * sin(t * 3.0)))
		"booster":
			_shape(ci, r, [Vector2(0.24, 0.12), Vector2(0.76, 0.12), Vector2(0.78, 0.88), Vector2(0.22, 0.88)], col, line, w)
			for i in 6:
				ci.draw_line(_p(r, 0.24 + i * 0.1, 0.12), _p(r, 0.29 + i * 0.1, 0.17), line, w * 0.6)
			ci.draw_colored_polygon(_poly(r, [Vector2(0.5, 0.3), Vector2(0.56, 0.45), Vector2(0.72, 0.46), Vector2(0.6, 0.56), Vector2(0.64, 0.72), Vector2(0.5, 0.63), Vector2(0.36, 0.72), Vector2(0.4, 0.56), Vector2(0.28, 0.46), Vector2(0.44, 0.45)]), UI.GOLD)
		"beyblade":
			BeybladeArt.draw_top(ci, _p(r, 0.5, 0.45), r.size.x * 0.36, t * 6.0, 0.0, false, 0.3)
		"gourd":
			ci.draw_circle(_p(r, 0.5, 0.66), r.size.x * 0.25, col)
			ci.draw_circle(_p(r, 0.5, 0.38), r.size.x * 0.15, col)
			for i in 3:
				ci.draw_arc(_p(r, 0.5, 0.66), r.size.x * (0.08 + i * 0.07), PI * 1.2, PI * 1.8, 8, col.darkened(0.25), w * 0.7, true)
			ci.draw_line(_p(r, 0.5, 0.24), _p(r, 0.56, 0.12), Color(0.35, 0.5, 0.2), w * 2.0, true)
			ci.draw_circle(_p(r, 0.62, 0.66), r.size.x * 0.05, Color(1, 1, 1, 0.3))
		"spoon":
			ci.draw_line(_p(r, 0.3, 0.86), _p(r, 0.55, 0.42), line, w * 3.2, true)
			ci.draw_line(_p(r, 0.3, 0.86), _p(r, 0.55, 0.42), col, w * 1.8, true)
			ci.draw_colored_polygon(PackedVector2Array([_p(r, 0.5, 0.42), _p(r, 0.52, 0.22), _p(r, 0.64, 0.12), _p(r, 0.74, 0.18), _p(r, 0.7, 0.34), _p(r, 0.58, 0.44)]), col)
			ci.draw_circle(_p(r, 0.33, 0.8), r.size.x * 0.06, UI.GOLD)
		"rock":
			_shape(ci, r, [Vector2(0.16, 0.72), Vector2(0.22, 0.48), Vector2(0.42, 0.36), Vector2(0.66, 0.38), Vector2(0.84, 0.56), Vector2(0.8, 0.76), Vector2(0.24, 0.8)], col, line, w)
			ci.draw_circle(_p(r, 0.42, 0.56), r.size.x * 0.04, Color(1, 1, 1))
			ci.draw_circle(_p(r, 0.6, 0.56), r.size.x * 0.04, Color(1, 1, 1))
			ci.draw_circle(_p(r, 0.43, 0.57), r.size.x * 0.02, line)
			ci.draw_circle(_p(r, 0.61, 0.57), r.size.x * 0.02, line)
			ci.draw_arc(_p(r, 0.51, 0.64), r.size.x * 0.05, 0.3, PI - 0.3, 6, line, w * 0.7, true)
		_:
			ci.draw_circle(r.get_center(), r.size.x * 0.3, col)
