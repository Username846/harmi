class_name PieceArt
extends RefCounted
## Procedural, deliberately elongated chess piece silhouettes.
## build() returns a list of shapes {"p": PackedVector2Array, "c": Color, "line": bool}
## drawn in order. Profiles use units of one board square: x = half width,
## y = height above the base.

const WHITE_FILL := Color(0.93, 0.88, 0.78)
const WHITE_SHADE := Color(0.45, 0.36, 0.28, 0.42)
const WHITE_LIGHT := Color(1.0, 1.0, 0.96, 0.55)
const WHITE_LINE := Color(0.16, 0.11, 0.09)
const BLACK_FILL := Color(0.21, 0.18, 0.23)
const BLACK_SHADE := Color(0.0, 0.0, 0.02, 0.5)
const BLACK_LIGHT := Color(0.62, 0.55, 0.66, 0.35)
const BLACK_LINE := Color(0.80, 0.66, 0.48)

const BASE := [Vector2(0.31, 0.0), Vector2(0.31, 0.05), Vector2(0.25, 0.088), Vector2(0.15, 0.125)]

const HEIGHTS := [0.0, 0.93, 1.40, 1.47, 1.30, 1.53, 1.78]


static func height(t: int) -> float:
	return HEIGHTS[t]


static func line_color(white: bool) -> Color:
	return WHITE_LINE if white else BLACK_LINE


static func _profile(t: int) -> Array:
	var p: Array = BASE.duplicate()
	match t:
		1:
			p += [Vector2(0.085, 0.19), Vector2(0.06, 0.50), Vector2(0.15, 0.55), Vector2(0.15, 0.59), Vector2(0.065, 0.625)]
		2:
			p += [Vector2(0.10, 0.20), Vector2(0.085, 0.55), Vector2(0.15, 0.60), Vector2(0.15, 0.64), Vector2(0.12, 0.65)]
		3:
			p += [Vector2(0.09, 0.22), Vector2(0.07, 0.78), Vector2(0.17, 0.84), Vector2(0.17, 0.88), Vector2(0.08, 0.915)]
		4:
			p += [Vector2(0.115, 0.20), Vector2(0.095, 0.72), Vector2(0.13, 0.90), Vector2(0.185, 0.96), Vector2(0.185, 1.11)]
		5:
			p += [Vector2(0.10, 0.24), Vector2(0.075, 0.95), Vector2(0.19, 1.01), Vector2(0.19, 1.05), Vector2(0.09, 1.08), Vector2(0.11, 1.18), Vector2(0.16, 1.245)]
		6:
			p += [Vector2(0.105, 0.24), Vector2(0.08, 0.98), Vector2(0.20, 1.04), Vector2(0.20, 1.08), Vector2(0.10, 1.11), Vector2(0.12, 1.20), Vector2(0.175, 1.30), Vector2(0.155, 1.38), Vector2(0.075, 1.425)]
	return p


static func _lathe(prof: Array, a: float, b: float, cx: float, by: float, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in prof:
		pts.append(Vector2(cx + b * v.x * s, by - v.y * s))
	for i in range(prof.size() - 1, -1, -1):
		var v: Vector2 = prof[i]
		pts.append(Vector2(cx + a * v.x * s, by - v.y * s))
	return pts


static func _poly(local: Array, cx: float, by: float, s: float, mirror: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for v in local:
		pts.append(Vector2(cx + v.x * s * mirror, by - v.y * s))
	return pts


static func _circle(c: Vector2, r: float, n: int = 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _body(shapes: Array, prof: Array, cx: float, by: float, s: float, white: bool) -> void:
	var fill := WHITE_FILL if white else BLACK_FILL
	shapes.append({"p": _lathe(prof, -1.0, 1.0, cx, by, s), "c": fill, "line": false})
	shapes.append({"p": _lathe(prof, 0.3, 1.0, cx, by, s), "c": WHITE_SHADE if white else BLACK_SHADE, "line": false})
	shapes.append({"p": _lathe(prof, -0.72, -0.42, cx, by, s), "c": WHITE_LIGHT if white else BLACK_LIGHT, "line": false})
	shapes.append({"p": _lathe(prof, -1.0, 1.0, cx, by, s), "c": Color(0, 0, 0, 0), "line": true})


static func _solid(shapes: Array, pts: PackedVector2Array, white: bool, shade: bool = true) -> void:
	var fill := WHITE_FILL if white else BLACK_FILL
	shapes.append({"p": pts, "c": fill, "line": true})
	if shade:
		pass


static func build(t: int, white: bool, cx: float, by: float, s: float) -> Array:
	var shapes: Array = []
	var line := line_color(white)
	_body(shapes, _profile(t), cx, by, s, white)
	match t:
		1:
			var head := _circle(Vector2(cx, by - 0.76 * s), 0.135 * s)
			_solid(shapes, head, white)
			shapes.append({"p": _circle(Vector2(cx + 0.045 * s, by - 0.74 * s), 0.08 * s), "c": WHITE_SHADE if white else BLACK_SHADE, "line": false})
			shapes.append({"p": _circle(Vector2(cx - 0.055 * s, by - 0.80 * s), 0.03 * s), "c": WHITE_LIGHT if white else BLACK_LIGHT, "line": false})
		2:
			var m := 1.0 if white else -1.0
			var head := _poly([Vector2(0.13, 0.62), Vector2(0.17, 0.80), Vector2(0.155, 0.98), Vector2(0.11, 1.16),
				Vector2(0.06, 1.27), Vector2(0.045, 1.40), Vector2(-0.005, 1.30), Vector2(-0.06, 1.265),
				Vector2(-0.16, 1.15), Vector2(-0.265, 1.035), Vector2(-0.285, 0.965), Vector2(-0.245, 0.925),
				Vector2(-0.15, 0.945), Vector2(-0.065, 0.965), Vector2(-0.075, 0.86), Vector2(-0.115, 0.72),
				Vector2(-0.13, 0.62)], cx, by, s, m)
			_solid(shapes, head, white)
			var mane := _poly([Vector2(0.13, 0.63), Vector2(0.17, 0.80), Vector2(0.155, 0.98), Vector2(0.11, 1.16),
				Vector2(0.06, 1.27), Vector2(0.065, 1.14), Vector2(0.09, 0.98), Vector2(0.10, 0.80), Vector2(0.075, 0.63)], cx, by, s, m)
			shapes.append({"p": mane, "c": WHITE_SHADE if white else BLACK_SHADE, "line": false})
			shapes.append({"p": _circle(Vector2(cx - 0.095 * s * m, by - 1.13 * s), 0.024 * s, 10), "c": line, "line": false})
			shapes.append({"p": _circle(Vector2(cx - 0.245 * s * m, by - 0.985 * s), 0.014 * s, 8), "c": line, "line": false})
		3:
			var mitre_prof := [Vector2(0.10, 0.905), Vector2(0.15, 0.98), Vector2(0.162, 1.08), Vector2(0.14, 1.20), Vector2(0.09, 1.30), Vector2(0.03, 1.375)]
			_body(shapes, mitre_prof, cx, by, s, white)
			shapes.append({"p": _poly([Vector2(0.115, 1.19), Vector2(0.135, 1.165), Vector2(-0.015, 1.02), Vector2(-0.04, 1.045)], cx, by, s), "c": line, "line": false})
			_solid(shapes, _circle(Vector2(cx, by - 1.42 * s), 0.045 * s, 14), white)
		4:
			var top := _poly([Vector2(-0.215, 1.10), Vector2(0.215, 1.10), Vector2(0.215, 1.30), Vector2(0.13, 1.30),
				Vector2(0.13, 1.22), Vector2(0.045, 1.22), Vector2(0.045, 1.30), Vector2(-0.045, 1.30),
				Vector2(-0.045, 1.22), Vector2(-0.13, 1.22), Vector2(-0.13, 1.30), Vector2(-0.215, 1.30)], cx, by, s)
			_solid(shapes, top, white)
			shapes.append({"p": _poly([Vector2(0.06, 1.10), Vector2(0.215, 1.10), Vector2(0.215, 1.30), Vector2(0.13, 1.30), Vector2(0.13, 1.22), Vector2(0.06, 1.22)], cx, by, s), "c": WHITE_SHADE if white else BLACK_SHADE, "line": false})
			shapes.append({"p": _poly([Vector2(-0.016, 0.74), Vector2(0.016, 0.74), Vector2(0.016, 0.88), Vector2(-0.016, 0.88)], cx, by, s), "c": line, "line": false})
		5:
			var crown := _poly([Vector2(-0.16, 1.24), Vector2(0.16, 1.24), Vector2(0.22, 1.43), Vector2(0.14, 1.33),
				Vector2(0.11, 1.47), Vector2(0.055, 1.34), Vector2(0.0, 1.52), Vector2(-0.055, 1.34),
				Vector2(-0.11, 1.47), Vector2(-0.14, 1.33), Vector2(-0.22, 1.43)], cx, by, s)
			_solid(shapes, crown, white)
			for tip in [Vector2(-0.22, 1.445), Vector2(-0.11, 1.49), Vector2(0.0, 1.54), Vector2(0.11, 1.49), Vector2(0.22, 1.445)]:
				_solid(shapes, _circle(Vector2(cx + tip.x * s, by - tip.y * s), 0.028 * s, 10), white)
		6:
			var cross := _poly([Vector2(-0.035, 1.41), Vector2(0.035, 1.41), Vector2(0.035, 1.57), Vector2(0.11, 1.57),
				Vector2(0.11, 1.64), Vector2(0.035, 1.64), Vector2(0.035, 1.77), Vector2(-0.035, 1.77),
				Vector2(-0.035, 1.64), Vector2(-0.11, 1.64), Vector2(-0.11, 1.57), Vector2(-0.035, 1.57)], cx, by, s)
			_solid(shapes, cross, white)
	return shapes


static func draw_shapes(ci: CanvasItem, shapes: Array, line: Color, width: float, modulate: Color = Color.WHITE) -> void:
	for sh in shapes:
		var c: Color = sh["c"]
		var pts: PackedVector2Array = sh["p"]
		if pts.size() < 3:
			continue
		if c.a > 0.0:
			ci.draw_colored_polygon(pts, c * modulate)
		if sh["line"]:
			var closed := pts.duplicate()
			closed.append(pts[0])
			ci.draw_polyline(closed, line * modulate, width, true)


## Convenience: draw a piece standing with its base centered at (cx, by).
static func draw_piece(ci: CanvasItem, t: int, white: bool, cx: float, by: float, s: float, modulate: Color = Color.WHITE, shadow: bool = true) -> void:
	if shadow:
		var sh := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			sh.append(Vector2(cx + cos(a) * 0.36 * s, by + sin(a) * 0.09 * s + 0.01 * s))
		ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * modulate.a))
	var shapes := build(t, white, cx, by, s)
	draw_shapes(ci, shapes, line_color(white), maxf(1.0, s * 0.028), modulate)


## Bounding box of a standing piece (used for hit testing).
static func bounds(t: int, cx: float, by: float, s: float) -> Rect2:
	var h := height(t) * s
	return Rect2(cx - 0.3 * s, by - h, 0.6 * s, h)


# --- Queen Cushy ----------------------------------------------------------------
# The queen as she sees herself: an hourglass body, honkers and a big booty.

const CURVY_QUEEN := [Vector2(0.10, 0.20), Vector2(0.085, 0.27), Vector2(0.15, 0.35), Vector2(0.225, 0.45),
	Vector2(0.225, 0.54), Vector2(0.16, 0.65), Vector2(0.085, 0.74), Vector2(0.12, 0.83), Vector2(0.12, 0.93),
	Vector2(0.07, 0.98), Vector2(0.19, 1.01), Vector2(0.19, 1.05), Vector2(0.09, 1.08), Vector2(0.11, 1.18), Vector2(0.16, 1.245)]


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Rounded part of the body: fill, a shaded underside, a highlight, an outline.
static func _curve(shapes: Array, c: Vector2, rx: float, ry: float, white: bool, s: float) -> void:
	shapes.append({"p": _ellipse(c, rx, ry), "c": WHITE_FILL if white else BLACK_FILL, "line": true})
	shapes.append({"p": _ellipse(c + Vector2(rx * 0.18, ry * 0.3), rx * 0.78, ry * 0.62), "c": WHITE_SHADE if white else BLACK_SHADE, "line": false})
	shapes.append({"p": _ellipse(c + Vector2(-rx * 0.35, -ry * 0.4), rx * 0.3, ry * 0.22), "c": WHITE_LIGHT if white else BLACK_LIGHT, "line": false})


## back = seen from behind (no honkers, two cheeks); jiggle bounces the booty
## (-1..1), sway shifts it sideways.
static func build_curvy_queen(white: bool, cx: float, by: float, s: float, back: bool = false, jiggle: float = 0.0, sway: float = 0.0) -> Array:
	var shapes: Array = []
	var prof: Array = BASE.duplicate() + CURVY_QUEEN
	if not back:
		# a three-quarter pose: the booty peeks out behind the hips
		_curve(shapes, Vector2(cx + (0.17 + sway) * s, by - (0.47 - jiggle * 0.025) * s), 0.15 * s, 0.13 * s, white, s)
	_body(shapes, prof, cx, by, s, white)
	if back:
		# one big booty: two cheeks joined at a crease, each bouncing out of step
		var fill := WHITE_FILL if white else BLACK_FILL
		var bl := jiggle * 0.03
		var br := -jiggle * 0.03
		var pts: Array = []
		for i in 13:
			var a := deg_to_rad(150.0 + i * 15.0)
			pts.append(Vector2(-0.12 + sway + cos(a) * 0.14, 0.46 + bl + sin(a) * 0.13))
		for i in 13:
			var a := deg_to_rad(210.0 + i * 15.0)
			pts.append(Vector2(0.12 + sway + cos(a) * 0.14, 0.46 + br + sin(a) * 0.13))
		pts.append(Vector2(0.13 + sway * 0.5, 0.62))
		pts.append(Vector2(-0.13 + sway * 0.5, 0.62))
		shapes.append({"p": _poly(pts, cx, by, s), "c": fill, "line": true})
		for k in [-1.0, 1.0]:
			var c := Vector2(cx + (k * 0.12 + sway) * s, by - (0.45 + (bl if k < 0.0 else br)) * s)
			shapes.append({"p": _ellipse(c + Vector2(0.03 * s, 0.035 * s), 0.1 * s, 0.07 * s), "c": WHITE_SHADE if white else BLACK_SHADE, "line": false})
			shapes.append({"p": _ellipse(c + Vector2(-0.045 * s, -0.04 * s), 0.04 * s, 0.028 * s), "c": WHITE_LIGHT if white else BLACK_LIGHT, "line": false})
		var crease := _poly([Vector2(sway - 0.006, 0.36), Vector2(sway + 0.006, 0.36), Vector2(sway + 0.004, 0.47), Vector2(sway - 0.004, 0.47)], cx, by, s)
		shapes.append({"p": crease, "c": line_color(white), "line": false})
	else:
		for k in [-1.0, 1.0]:
			_curve(shapes, Vector2(cx + k * 0.09 * s, by - (0.86 + jiggle * 0.01) * s), 0.1 * s, 0.095 * s, white, s)
	var crown := _poly([Vector2(-0.16, 1.24), Vector2(0.16, 1.24), Vector2(0.22, 1.43), Vector2(0.14, 1.33),
		Vector2(0.11, 1.47), Vector2(0.055, 1.34), Vector2(0.0, 1.52), Vector2(-0.055, 1.34),
		Vector2(-0.11, 1.47), Vector2(-0.14, 1.33), Vector2(-0.22, 1.43)], cx, by, s)
	_solid(shapes, crown, white)
	for tip in [Vector2(-0.22, 1.445), Vector2(-0.11, 1.49), Vector2(0.0, 1.54), Vector2(0.11, 1.49), Vector2(0.22, 1.445)]:
		shapes.append({"p": _circle(Vector2(cx + tip.x * s, by - tip.y * s), 0.028 * s, 10), "c": Color(0.95, 0.75, 0.3), "line": true})
	return shapes


static func draw_curvy_queen(ci: CanvasItem, white: bool, cx: float, by: float, s: float, back: bool = false, jiggle: float = 0.0, sway: float = 0.0, modulate: Color = Color.WHITE) -> void:
	var sh := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		sh.append(Vector2(cx + cos(a) * 0.4 * s, by + sin(a) * 0.09 * s + 0.01 * s))
	ci.draw_colored_polygon(sh, Color(0, 0, 0, 0.35 * modulate.a))
	draw_shapes(ci, build_curvy_queen(white, cx, by, s, back, jiggle, sway), line_color(white), maxf(1.0, s * 0.028), modulate)
