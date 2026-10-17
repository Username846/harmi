class_name BeybladeArt
extends RefCounted
## A spinning battle top, drawn in a squashed three-quarter view so rotating
## the blade outline reads as spin.

const SQUASH := 0.42
const METAL := Color(0.78, 0.8, 0.86)
const METAL_DARK := Color(0.36, 0.38, 0.46)
const RING := Color(0.86, 0.22, 0.2)
const BOLT := Color(0.96, 0.78, 0.3)
const OUTLINE := Color(0.06, 0.06, 0.1)


## c: centre of the attack ring, r: its radius, spin: rotation angle (radians),
## tilt: wobble in radians, broken: one blade snapped off, blur: 0..1 motion blur.
static func draw_top(ci: CanvasItem, c: Vector2, r: float, spin: float, tilt: float = 0.0, broken: bool = false, blur: float = 0.0) -> void:
	ci.draw_set_transform(c, tilt, Vector2.ONE)
	var lw := maxf(1.0, r * 0.06)
	# shadow
	ci.draw_colored_polygon(_ellipse(Vector2(0, r * 0.62), r * 0.7, r * 0.16, 20), Color(0, 0, 0, 0.3))
	# performance tip and spin track
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-r * 0.2, r * 0.12), Vector2(r * 0.2, r * 0.12), Vector2(r * 0.07, r * 0.5), Vector2(0, r * 0.6), Vector2(-r * 0.07, r * 0.5)]), Color(0.9, 0.72, 0.25))
	ci.draw_colored_polygon(_ellipse(Vector2(0, r * 0.14), r * 0.36, r * 0.36 * SQUASH, 18), METAL_DARK)
	# attack ring: three hooked blades
	var ring := PackedVector2Array()
	var n := 72
	for j in n:
		var a := TAU * j / n
		var ph := fposmod((a - spin) * 3.0 / TAU, 1.0)
		var rr := r * (0.66 + 0.34 * ph * ph)
		if broken and fposmod(a - spin, TAU) > 0.4 and fposmod(a - spin, TAU) < 1.9:
			rr = r * (0.5 + 0.12 * sin(a * 9.0))
		ring.append(Vector2(cos(a) * rr, sin(a) * rr * SQUASH))
	var under := PackedVector2Array()
	for p in ring:
		under.append(p + Vector2(0, r * 0.14))
	ci.draw_colored_polygon(under, METAL_DARK)
	ci.draw_colored_polygon(ring, METAL)
	var closed := ring.duplicate()
	closed.append(ring[0])
	ci.draw_polyline(closed, OUTLINE, lw, true)
	# energy ring with notches
	ci.draw_colored_polygon(_ellipse(Vector2.ZERO, r * 0.52, r * 0.52 * SQUASH, 24), RING if not broken else RING.darkened(0.4))
	for k in 4:
		var a2 := spin * 1.0 + TAU * k / 4.0
		var p2 := Vector2(cos(a2) * r * 0.42, sin(a2) * r * 0.42 * SQUASH)
		ci.draw_circle(p2, r * 0.06, Color(0.9, 0.95, 1.0, 0.85))
	# face bolt with a little knight emblem
	ci.draw_colored_polygon(_ellipse(Vector2(0, -r * 0.05), r * 0.24, r * 0.24 * 0.62, 18), BOLT)
	ci.draw_colored_polygon(_star(Vector2(0, -r * 0.05), r * 0.17, spin * 0.5), Color(0.55, 0.12, 0.1))
	# highlight
	ci.draw_arc(Vector2(-r * 0.15, -r * 0.12), r * 0.4, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.55), lw, true)
	if blur > 0.01:
		for k in 3:
			var rad := r * (0.78 + k * 0.12)
			var start := -spin * 2.0 + k
			ci.draw_arc(Vector2.ZERO, rad, start, start + 1.4, 16, Color(0.75, 0.85, 1.0, 0.35 * blur), lw, true)
	if broken:
		ci.draw_line(Vector2(-r * 0.1, -r * 0.05), Vector2(r * 0.25, r * 0.12), OUTLINE, lw)
		ci.draw_line(Vector2(r * 0.25, r * 0.12), Vector2(r * 0.4, r * 0.05), OUTLINE, lw)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A squashed five-pointed star that turns with the top.
static func _star(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var a := rot + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		out.append(c + Vector2(cos(a) * rr, sin(a) * rr * SQUASH * 1.4))
	return out


static func _knight(c: Vector2, e: float) -> PackedVector2Array:
	var pts := [Vector2(-0.5, 0.6), Vector2(0.55, 0.6), Vector2(0.45, -0.05), Vector2(0.2, -0.6), Vector2(-0.1, -0.75),
		Vector2(-0.6, -0.3), Vector2(-0.55, -0.1), Vector2(-0.1, -0.15), Vector2(-0.35, 0.25)]
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * e * 1.6)
	return out


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out
