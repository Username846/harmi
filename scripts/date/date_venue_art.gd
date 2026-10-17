class_name DateVenueArt
extends RefCounted
## Procedural backdrops for the four date venues, drawn into the picture rect
## `r`. draw_back() paints everything behind the date piece, draw_front() the
## props in front of it (picnic basket, ball return, the table, the boat).


## Where the date piece stands (its base), in the same coordinates as `r`.
static func piece_spot(venue: String, r: Rect2, t: float) -> Vector2:
	match venue:
		"park":
			return _p(r, 0.33, 0.80)
		"bowling":
			return _p(r, 0.30, 0.93)
		"dinner":
			return _p(r, 0.33, 0.80)
		"cruise":
			var b := _boat_size(r)
			return _boat_center(r, t) + Vector2(-0.30 * b, 0.10 * b).rotated(_boat_tilt(t))
	return _p(r, 0.33, 0.85)


## Extra lean for the piece (it rocks with the boat).
static func piece_tilt(venue: String, t: float) -> float:
	if venue == "cruise":
		return _boat_tilt(t)
	return 0.0


static func draw_back(ci: CanvasItem, venue: String, r: Rect2, t: float) -> void:
	match venue:
		"park":
			_park_back(ci, r, t)
		"bowling":
			_bowling_back(ci, r, t)
		"dinner":
			_dinner_back(ci, r, t)
		"cruise":
			_cruise_back(ci, r, t)
		_:
			_vgrad(ci, r, Color(0.12, 0.09, 0.11), Color(0.05, 0.04, 0.05))


static func draw_front(ci: CanvasItem, venue: String, r: Rect2, t: float) -> void:
	match venue:
		"park":
			_park_front(ci, r, t)
		"bowling":
			_bowling_front(ci, r, t)
		"dinner":
			_dinner_front(ci, r, t)
		"cruise":
			_cruise_front(ci, r, t)


# --- helpers -------------------------------------------------------------------

static func _k(r: Rect2) -> float:
	return minf(r.size.x, r.size.y)


static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + r.size * Vector2(x, y)


## Stable pseudo-random 0..1 from an index (no state, so scenes don't flicker).
static func _h(i: int, salt: int) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floorf(v)


static func _vgrad(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _glow(ci: CanvasItem, c: Vector2, radius: float, col: Color, rings: int = 6) -> void:
	# many faint rings rather than a few strong ones, so there's no visible banding
	var n := rings * 3
	var faint := Color(col, col.a / 3.0)
	for i in n:
		ci.draw_circle(c, radius * (1.0 - float(i) / n), faint)


static func _closed(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var c := pts.duplicate()
	c.append(pts[0])
	ci.draw_polyline(c, col, w, true)


static func _cloud(ci: CanvasItem, c: Vector2, w: float, col: Color) -> void:
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, w * 0.15), w * 1.5, w * 0.42), col)
	ci.draw_circle(c + Vector2(-w * 0.55, 0), w * 0.5, col)
	ci.draw_circle(c + Vector2(0.1 * w, -w * 0.25), w * 0.62, col)
	ci.draw_circle(c + Vector2(w * 0.7, 0.05 * w), w * 0.42, col)


static func _hills(ci: CanvasItem, r: Rect2, base_y: float, amp: float, freq: float, phase: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 28
	for i in n + 1:
		var x := float(i) / n
		pts.append(_p(r, x, base_y - amp * (0.55 + 0.45 * sin(x * TAU * freq + phase))))
	pts.append(_p(r, 1.0, 0.64))
	pts.append(_p(r, 0.0, 0.64))
	ci.draw_colored_polygon(pts, col)


## A tiny far-off castle silhouette (base centre, size s).
static func _castle(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(base.x - s, base.y - s * 0.7, s * 2.0, s * 0.7), col)
	for tx in [-1.15, 0.75]:
		var x: float = base.x + tx * s
		ci.draw_rect(Rect2(x, base.y - s * 1.25, s * 0.42, s * 1.25), col)
		for m in 3:
			ci.draw_rect(Rect2(x + m * s * 0.16, base.y - s * 1.4, s * 0.1, s * 0.16), col)
	ci.draw_rect(Rect2(base.x - s * 0.22, base.y - s * 1.05, s * 0.44, s * 0.4), col)


static func _flame(ci: CanvasItem, base: Vector2, h: float, w: float, t: float, seed: float) -> void:
	var f := 1.0 + 0.14 * sin(t * 17.0 + seed) + 0.08 * sin(t * 29.0 + seed * 2.0)
	var tip := base + Vector2(sin(t * 9.0 + seed) * w * 0.35, -h * f)
	# a teardrop: a rounded bottom and a flickering point on top
	var outer := PackedVector2Array()
	for i in 11:
		var a2 := PI * i / 10.0
		outer.append(base + Vector2(cos(a2) * w, sin(a2) * w * 0.9 - w * 0.6))
	outer.append(tip)
	ci.draw_colored_polygon(outer, Color(1.0, 0.55, 0.15, 0.95))
	var inner := PackedVector2Array()
	for i in 11:
		var a3 := PI * i / 10.0
		inner.append(base + Vector2(cos(a3) * w * 0.5, sin(a3) * w * 0.45 - w * 0.4))
	inner.append(base.lerp(tip, 0.65))
	ci.draw_colored_polygon(inner, Color(1.0, 0.92, 0.6))


# --- park --------------------------------------------------------------------

static func _park_back(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	_vgrad(ci, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.62)), Color(0.40, 0.62, 0.86), Color(0.96, 0.88, 0.72))
	var sun := _p(r, 0.9, 0.13)
	_glow(ci, sun, k * 0.22, Color(1.0, 0.95, 0.7, 0.06))
	ci.draw_circle(sun, k * 0.05, Color(1.0, 0.97, 0.82))
	for i in 3:
		var cx := fposmod(0.1 + i * 0.41 + t * 0.008 * (1.0 + i * 0.4), 1.4) - 0.2
		_cloud(ci, _p(r, cx, 0.09 + 0.08 * i), k * (0.045 + 0.012 * i), Color(1, 1, 1, 0.8))
	_hills(ci, r, 0.50, 0.04, 1.4, 0.3, Color(0.60, 0.69, 0.62))
	_castle(ci, _p(r, 0.76, 0.475), k * 0.035, Color(0.52, 0.6, 0.58))
	_hills(ci, r, 0.56, 0.035, 2.3, 1.9, Color(0.45, 0.62, 0.38))
	_vgrad(ci, Rect2(r.position.x, r.position.y + r.size.y * 0.585, r.size.x, r.size.y * 0.42), Color(0.42, 0.63, 0.30), Color(0.22, 0.41, 0.16))
	for tr in [[0.06, 0.64, 1.3], [0.54, 0.6, 0.7], [0.66, 0.615, 0.95], [0.95, 0.67, 1.35]]:
		_tree(ci, _p(r, tr[0], tr[1]), k * 0.13 * float(tr[2]), t)
	var flower_cols := [Color(1, 0.95, 0.5), Color(1, 0.62, 0.72), Color(1, 1, 1), Color(0.78, 0.64, 1.0)]
	for i in 36:
		var fp := _p(r, _h(i, 1), 0.63 + _h(i, 2) * 0.37)
		var fc: Color = flower_cols[i % 4]
		ci.draw_circle(fp, 1.5 + k * 0.005, fc)
	_blanket(ci, r)


static func _tree(ci: CanvasItem, base: Vector2, s: float, t: float) -> void:
	var sway := sin(t * 0.9 + base.x * 0.013) * s * 0.035
	ci.draw_rect(Rect2(base.x - s * 0.09, base.y - s * 1.15, s * 0.18, s * 1.15), Color(0.36, 0.24, 0.15))
	ci.draw_line(base + Vector2(0, -s * 0.8), base + Vector2(s * 0.35 + sway, -s * 1.25), Color(0.36, 0.24, 0.15), s * 0.07)
	var top := base + Vector2(sway, -s * 1.4)
	var cols := [Color(0.16, 0.33, 0.15), Color(0.24, 0.45, 0.2), Color(0.37, 0.59, 0.27)]
	var blobs := [[Vector2(-0.4, 0.2), 0.42, 0], [Vector2(0.38, 0.22), 0.4, 0], [Vector2(0.0, -0.12), 0.54, 0],
		[Vector2(-0.2, 0.3), 0.36, 1], [Vector2(0.22, -0.04), 0.36, 1], [Vector2(-0.16, -0.26), 0.24, 2], [Vector2(0.3, 0.12), 0.16, 2]]
	for bl in blobs:
		var off: Vector2 = bl[0]
		var rad: float = bl[1]
		var col: Color = cols[int(bl[2])]
		ci.draw_circle(top + off * s, rad * s, col)


static func _bil(a: Vector2, b: Vector2, c: Vector2, d: Vector2, u: float, v: float) -> Vector2:
	return a.lerp(b, u).lerp(c.lerp(d, u), v)


static func _blanket(ci: CanvasItem, r: Rect2) -> void:
	var fl := _p(r, 0.08, 0.70)
	var fr := _p(r, 0.66, 0.70)
	var nl := _p(r, -0.08, 1.06)
	var nr := _p(r, 0.86, 1.06)
	var sh := Vector2(5, 5)
	ci.draw_colored_polygon(PackedVector2Array([fl + sh, fr + sh, nr + sh, nl + sh]), Color(0, 0, 0, 0.2))
	var cols := 7
	var rows := 5
	for j in rows:
		var v0 := pow(float(j) / rows, 1.3)
		var v1 := pow(float(j + 1) / rows, 1.3)
		for i in cols:
			var u0 := float(i) / cols
			var u1 := float(i + 1) / cols
			var quad := PackedVector2Array([_bil(fl, fr, nl, nr, u0, v0), _bil(fl, fr, nl, nr, u1, v0),
				_bil(fl, fr, nl, nr, u1, v1), _bil(fl, fr, nl, nr, u0, v1)])
			var c := Color(0.80, 0.21, 0.22) if (i + j) % 2 == 0 else Color(0.97, 0.93, 0.83)
			ci.draw_colored_polygon(quad, c)
	_closed(ci, PackedVector2Array([fl, fr, nr, nl]), Color(0.5, 0.1, 0.12), 2.0)


static func _park_front(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	# a sandwich and a bottle of lemonade on the blanket
	var sp := _p(r, 0.57, 0.87)
	var bread := PackedVector2Array([sp + Vector2(-0.06, 0.02) * k, sp + Vector2(0.06, 0.02) * k, sp + Vector2(0.0, -0.05) * k])
	ci.draw_colored_polygon(bread, Color(0.95, 0.82, 0.55))
	ci.draw_line(sp + Vector2(-0.055, 0.012) * k, sp + Vector2(0.055, 0.012) * k, Color(0.4, 0.75, 0.3), maxf(2.0, k * 0.008))
	_closed(ci, bread, Color(0.55, 0.38, 0.2), 1.5)
	var bp := _p(r, 0.67, 0.83)
	ci.draw_rect(Rect2(bp.x - k * 0.018, bp.y - k * 0.08, k * 0.036, k * 0.08), Color(0.32, 0.6, 0.38, 0.9))
	ci.draw_rect(Rect2(bp.x - k * 0.008, bp.y - k * 0.115, k * 0.016, k * 0.04), Color(0.32, 0.6, 0.38, 0.9))
	ci.draw_rect(Rect2(bp.x - k * 0.018, bp.y - k * 0.055, k * 0.036, k * 0.025), Color(0.98, 0.9, 0.5))
	_basket(ci, _p(r, 0.86, 0.97), k * 0.2)
	# butterflies
	for i in 2:
		var p := _p(r, 0.5 + 0.22 * sin(t * 0.33 + i * 2.3), 0.5 + 0.07 * sin(t * 0.9 + i * 1.3))
		var flap := 0.25 + 0.75 * absf(sin(t * 11.0 + i))
		var bc: Color = [Color(1.0, 0.72, 0.28), Color(0.62, 0.76, 1.0)][i]
		var wsz := k * 0.016
		ci.draw_colored_polygon(_ellipse(p + Vector2(-wsz * flap, 0), wsz * flap, wsz, 12), bc)
		ci.draw_colored_polygon(_ellipse(p + Vector2(wsz * flap, 0), wsz * flap, wsz, 12), bc)
		ci.draw_line(p + Vector2(0, -wsz), p + Vector2(0, wsz), Color(0.2, 0.15, 0.1), 2.0)


static func _basket(ci: CanvasItem, c: Vector2, s: float) -> void:
	var wick := Color(0.66, 0.46, 0.24)
	var dark := Color(0.42, 0.28, 0.14)
	ci.draw_arc(c + Vector2(0, -s * 0.5), s * 0.36, PI, TAU, 18, dark, s * 0.06, true)
	var body := PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.5), c + Vector2(s * 0.5, -s * 0.5), c + Vector2(s * 0.42, 0), c + Vector2(-s * 0.42, 0)])
	ci.draw_colored_polygon(body, wick)
	for i in 4:
		var y := c.y - s * 0.12 * (i + 0.6)
		ci.draw_line(Vector2(c.x - s * 0.47, y), Vector2(c.x + s * 0.47, y), dark, 1.5)
	for i in 7:
		var x := -0.36 + i * 0.12
		ci.draw_line(c + Vector2(x * s * 1.15, -s * 0.5), c + Vector2(x * s, 0), Color(dark, 0.6), 1.5)
	ci.draw_rect(Rect2(c.x - s * 0.53, c.y - s * 0.58, s * 1.06, s * 0.1), dark)
	var cloth := PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.58), c + Vector2(s * 0.05, -s * 0.58), c + Vector2(-s * 0.2, -s * 0.3)])
	ci.draw_colored_polygon(cloth, Color(0.85, 0.25, 0.25))
	_closed(ci, body, dark, 2.0)


# --- bowling -----------------------------------------------------------------

const LANE_FAR := 0.47
const LANE_NEAR := 1.0


static func _lane_x(lane: int, u: float, v: float) -> float:
	## x (0..1) of a point across lane `lane` (u 0..1) at depth v (0 far, 1 near).
	var a := (lane + u) / 3.0
	return lerpf(lerpf(0.25, 0.75, a), lerpf(-0.12, 1.12, a), v)


static func _bowling_back(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	_vgrad(ci, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.48)), Color(0.07, 0.04, 0.12), Color(0.20, 0.09, 0.26))
	for i in 9:
		var x := r.position.x + r.size.x * i / 8.0
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y * 0.4), Color(0, 0, 0, 0.25), 2.0)
	# neon sign and a neon stripe
	var on := fposmod(t, 5.3) < 4.9 or fposmod(t * 12.0, 1.0) < 0.5
	_neon_text(ci, "BOWL", _p(r, 0.04, 0.17), int(maxf(18.0, k * 0.105)), Color(1.0, 0.42, 0.78), on)
	var pin_c := _p(r, 0.04, 0.17) + Vector2(ThemeDB.fallback_font.get_string_size("BOWL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(18.0, k * 0.105))).x + k * 0.04, -k * 0.035)
	_neon_ring(ci, pin_c, k * 0.03, Color(0.35, 0.9, 1.0))
	var sy := r.position.y + r.size.y * 0.385
	ci.draw_line(Vector2(r.position.x, sy), Vector2(r.end.x, sy), Color(0.3, 0.9, 1.0, 0.18), maxf(6.0, k * 0.025))
	ci.draw_line(Vector2(r.position.x, sy), Vector2(r.end.x, sy), Color(0.7, 0.98, 1.0, 0.9), 2.0)
	# pin deck
	ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.40, r.size.x, r.size.y * (LANE_FAR - 0.40) + 1.0), Color(0.04, 0.03, 0.06))
	# floor between lanes
	ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * LANE_FAR, r.size.x, r.size.y * (1.0 - LANE_FAR)), Color(0.12, 0.08, 0.17))
	for lane in 3:
		var gut := PackedVector2Array([_p(r, _lane_x(lane, 0.0, 0.0), LANE_FAR), _p(r, _lane_x(lane, 1.0, 0.0), LANE_FAR),
			_p(r, _lane_x(lane, 1.0, 1.0), LANE_NEAR), _p(r, _lane_x(lane, 0.0, 1.0), LANE_NEAR)])
		ci.draw_colored_polygon(gut, Color(0.2, 0.19, 0.23))
		var g := 0.1
		var wood := PackedVector2Array([_p(r, _lane_x(lane, g, 0.0), LANE_FAR), _p(r, _lane_x(lane, 1.0 - g, 0.0), LANE_FAR),
			_p(r, _lane_x(lane, 1.0 - g, 1.0), LANE_NEAR), _p(r, _lane_x(lane, g, 1.0), LANE_NEAR)])
		var far_c := Color(0.52, 0.36, 0.21)
		var near_c := Color(0.88, 0.66, 0.42)
		ci.draw_polygon(wood, PackedColorArray([far_c, far_c, near_c, near_c]))
		for bi in range(1, 9):
			var u := lerpf(g, 1.0 - g, bi / 9.0)
			ci.draw_line(_p(r, _lane_x(lane, u, 0.0), LANE_FAR), _p(r, _lane_x(lane, u, 1.0), LANE_NEAR), Color(0.45, 0.3, 0.16, 0.3), 1.0)
		# polished shine
		var shine := PackedVector2Array([_p(r, _lane_x(lane, 0.42, 0.0), LANE_FAR), _p(r, _lane_x(lane, 0.52, 0.0), LANE_FAR),
			_p(r, _lane_x(lane, 0.62, 1.0), LANE_NEAR), _p(r, _lane_x(lane, 0.38, 1.0), LANE_NEAR)])
		ci.draw_colored_polygon(shine, Color(1, 1, 1, 0.08))
		# aiming arrows
		var dv := 0.55
		var ay := lerpf(LANE_FAR, LANE_NEAR, dv)
		for ai in 5:
			var ax := _lane_x(lane, 0.2 + ai * 0.15, dv)
			var ap := _p(r, ax, ay)
			var asz := k * 0.012
			ci.draw_colored_polygon(PackedVector2Array([ap + Vector2(0, -asz * 1.6), ap + Vector2(asz, asz * 0.6), ap + Vector2(-asz, asz * 0.6)]), Color(0.35, 0.2, 0.1, 0.7))
	# pins, and a ball rolling down the right lane every few seconds
	var phase := fposmod(t, 4.6)
	var knocked := phase >= 2.0 and phase < 3.7
	for lane in 3:
		_pins(ci, _p(r, _lane_x(lane, 0.5, 0.0), LANE_FAR - 0.004), k * 0.05, knocked and lane == 2, lane)
	if phase < 2.0:
		var pr := phase / 2.0
		var dv2 := 1.0 - pow(pr, 0.8)
		var bpos := _p(r, _lane_x(2, 0.5, dv2 * 0.92), lerpf(LANE_FAR, LANE_NEAR, dv2 * 0.92))
		var brad := lerpf(k * 0.012, k * 0.045, dv2)
		_ball(ci, bpos - Vector2(0, brad), brad, Color(0.25, 0.35, 0.85))
	# the approach: a shared wooden floor with the foul line
	var ap0 := r.position.y + r.size.y * 0.87
	ci.draw_rect(Rect2(r.position.x, ap0, r.size.x, r.end.y - ap0 + 2.0), Color(0.78, 0.6, 0.4))
	for i in 12:
		var x2 := r.position.x + r.size.x * i / 11.0
		ci.draw_line(Vector2(x2, ap0), Vector2(x2, r.end.y), Color(0.6, 0.42, 0.25, 0.4), 1.0)
	ci.draw_line(Vector2(r.position.x, ap0), Vector2(r.end.x, ap0), Color(0.15, 0.1, 0.08), 3.0)


static func _neon_text(ci: CanvasItem, text: String, pos: Vector2, fs: int, col: Color, on: bool) -> void:
	var font := ThemeDB.fallback_font
	var a := 1.0 if on else 0.22
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(col, 0.08 * a))
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(col, 0.28 * a))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lerp(Color.WHITE, 0.5), maxf(0.35, a)))


static func _neon_ring(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	ci.draw_arc(c, rad, 0, TAU, 28, Color(col, 0.18), 8.0, true)
	ci.draw_arc(c, rad, 0, TAU, 28, col.lerp(Color.WHITE, 0.4), 2.5, true)
	for h in [Vector2(-0.3, -0.35), Vector2(0.15, -0.45), Vector2(0.05, -0.1)]:
		ci.draw_circle(c + h * rad, rad * 0.12, col.lerp(Color.WHITE, 0.4))


static func _pins(ci: CanvasItem, base: Vector2, h: float, knocked: bool, lane: int) -> void:
	var rows := [[-1.5, -0.5, 0.5, 1.5], [-1.0, 0.0, 1.0], [-0.5, 0.5], [0.0]]
	var w := h * 0.36
	var n := 0
	for ri in 4:
		var row: Array = rows[ri]
		for xo in row:
			n += 1
			var p := base + Vector2(float(xo) * w * 1.15, -(3 - ri) * h * 0.07)
			var rot := 0.0
			if knocked:
				rot = (_h(n + lane * 10, 8) - 0.5) * 3.2
				p += Vector2((_h(n, 9) - 0.5) * w * 3.0, h * 0.25)
			_pin(ci, p, h, rot)


static func _pin(ci: CanvasItem, p: Vector2, h: float, rot: float) -> void:
	var prof := [Vector2(0.30, 0.0), Vector2(0.42, 0.16), Vector2(0.46, 0.32), Vector2(0.30, 0.56), Vector2(0.19, 0.66),
		Vector2(0.25, 0.82), Vector2(0.2, 0.94), Vector2(0.0, 1.0)]
	var w := h * 0.4
	var pts := PackedVector2Array()
	for v in prof:
		var q: Vector2 = v
		pts.append(Vector2(q.x * w, -q.y * h))
	for i in range(prof.size() - 1, -1, -1):
		var q2: Vector2 = prof[i]
		pts.append(Vector2(-q2.x * w, -q2.y * h))
	ci.draw_set_transform(p, rot, Vector2.ONE)
	ci.draw_colored_polygon(pts, Color(0.97, 0.96, 0.93))
	ci.draw_rect(Rect2(-0.2 * w, -0.66 * h, 0.4 * w, 0.07 * h), Color(0.85, 0.15, 0.18))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ball(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	ci.draw_circle(c, rad, col)
	ci.draw_circle(c + Vector2(-rad * 0.35, -rad * 0.35), rad * 0.35, Color(1, 1, 1, 0.25))
	for hp in [Vector2(0.15, -0.2), Vector2(0.4, -0.05), Vector2(0.3, 0.25)]:
		ci.draw_circle(c + hp * rad, rad * 0.11, Color(0.05, 0.05, 0.08))


static func _bowling_front(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	# ball return in the corner
	var c := _p(r, 0.87, 1.0)
	var hw := k * 0.17
	var hood := PackedVector2Array([c + Vector2(-hw, 0), c + Vector2(-hw * 0.9, -k * 0.1), c + Vector2(-hw * 0.4, -k * 0.15),
		c + Vector2(hw * 0.4, -k * 0.15), c + Vector2(hw * 0.9, -k * 0.1), c + Vector2(hw, 0)])
	ci.draw_colored_polygon(hood, Color(0.14, 0.11, 0.2))
	_closed(ci, hood, Color(0.95, 0.4, 0.75, 0.8), 2.0)
	var cols := [Color(0.85, 0.2, 0.3), Color(0.25, 0.75, 0.5), Color(0.95, 0.65, 0.2)]
	for i in 3:
		var bc: Color = cols[i]
		_ball(ci, c + Vector2((i - 1) * k * 0.085, -k * 0.13), k * 0.04, bc)
	# a flickering neon reflection on the approach
	var glow := 0.05 + 0.02 * sin(t * 3.0)
	ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.87, r.size.x, r.size.y * 0.13), Color(1.0, 0.4, 0.8, glow))


# --- candlelit dinner (in a castle keep) ----------------------------------------

static func _dinner_back(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	ci.draw_rect(r, Color(0.12, 0.085, 0.075))
	var bh := maxf(14.0, k * 0.075)
	var bw := bh * 2.1
	var rows := int(r.size.y * 0.75 / bh) + 1
	for j in rows:
		var y := r.position.y + j * bh
		var x := r.position.x - (bw * 0.5 if j % 2 == 1 else 0.0)
		var i := 0
		while x < r.end.x:
			var shade := 0.82 + 0.32 * _h(i + j * 31, 5)
			var c := Color(0.30 * shade, 0.235 * shade, 0.20 * shade)
			ci.draw_rect(Rect2(x + 1.5, y + 1.5, bw - 3.0, bh - 3.0), c)
			x += bw
			i += 1
	_vgrad(ci, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.72)), Color(0, 0, 0, 0.6), Color(0.35, 0.14, 0.02, 0.12))
	_arch_window(ci, Rect2(_p(r, 0.62, 0.24), r.size * Vector2(0.15, 0.38)), t)
	_banner(ci, _p(r, 0.055, 0.0), k * 0.085, k * 0.34)
	_banner(ci, _p(r, 0.945, 0.0), k * 0.085, k * 0.34)
	_sconce(ci, _p(r, 0.16, 0.47), k, t, 0.0)
	_sconce(ci, _p(r, 0.90, 0.50), k, t, 2.0)
	ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.68, r.size.x, r.size.y * 0.32), Color(0.09, 0.06, 0.05))


static func _arch_window(ci: CanvasItem, rect: Rect2, t: float) -> void:
	var rad := rect.size.x * 0.5
	var cen := Vector2(rect.get_center().x, rect.position.y + rad)
	var pts := PackedVector2Array()
	pts.append(Vector2(rect.position.x, rect.end.y))
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(cen + Vector2(cos(a), sin(a)) * rad)
	pts.append(Vector2(rect.end.x, rect.end.y))
	var frame := PackedVector2Array()
	for p in pts:
		frame.append(cen + (p - cen) * 1.0 + (p - rect.get_center()).normalized() * 7.0)
	ci.draw_colored_polygon(frame, Color(0.45, 0.38, 0.32))
	var cols := PackedColorArray()
	for p in pts:
		var k2 := clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		cols.append(Color(0.05, 0.06, 0.17).lerp(Color(0.18, 0.16, 0.36), k2))
	ci.draw_polygon(pts, cols)
	# moon and stars
	var moon := cen + Vector2(rad * 0.35, -rad * 0.1)
	ci.draw_circle(moon, rad * 0.26, Color(0.98, 0.95, 0.8))
	ci.draw_circle(moon + Vector2(rad * 0.1, -rad * 0.05), rad * 0.22, Color(0.06, 0.07, 0.19))
	for i in 7:
		var sp := Vector2(rect.position.x + rect.size.x * _h(i, 21), rect.position.y + rad * 0.5 + rect.size.y * 0.6 * _h(i, 22))
		var tw := 0.5 + 0.5 * sin(t * 2.0 + i * 1.7)
		ci.draw_circle(sp, 1.2 + tw, Color(1, 1, 0.9, 0.5 + 0.4 * tw))
	ci.draw_line(Vector2(cen.x, cen.y - rad), Vector2(cen.x, rect.end.y), Color(0.3, 0.25, 0.21), 4.0)
	ci.draw_line(Vector2(rect.position.x, rect.position.y + rect.size.y * 0.55), Vector2(rect.end.x, rect.position.y + rect.size.y * 0.55), Color(0.3, 0.25, 0.21), 4.0)
	ci.draw_rect(Rect2(rect.position.x - 10, rect.end.y, rect.size.x + 20, 7), Color(0.5, 0.43, 0.36))


static func _banner(ci: CanvasItem, top: Vector2, w: float, h: float) -> void:
	var gold := Color(0.88, 0.7, 0.32)
	ci.draw_line(top + Vector2(-w * 0.7, 3), top + Vector2(w * 0.7, 3), Color(0.55, 0.42, 0.22), 4.0)
	var pts := PackedVector2Array([top + Vector2(-w * 0.5, 4), top + Vector2(w * 0.5, 4), top + Vector2(w * 0.5, h),
		top + Vector2(0, h * 0.84), top + Vector2(-w * 0.5, h)])
	ci.draw_colored_polygon(pts, Color(0.55, 0.09, 0.12))
	_closed(ci, pts, gold, 2.0)
	# a little gold rook on it
	var c := top + Vector2(0, h * 0.48)
	var s := w * 0.32
	ci.draw_rect(Rect2(c.x - s * 0.55, c.y - s * 0.6, s * 1.1, s * 1.3), gold)
	ci.draw_rect(Rect2(c.x - s * 0.8, c.y + s * 0.6, s * 1.6, s * 0.35), gold)
	for m in 3:
		ci.draw_rect(Rect2(c.x - s * 0.8 + m * s * 0.6, c.y - s * 1.0, s * 0.4, s * 0.45), gold)


static func _sconce(ci: CanvasItem, p: Vector2, k: float, t: float, seed: float) -> void:
	_glow(ci, p - Vector2(0, k * 0.09), k * 0.2, Color(1.0, 0.55, 0.2, 0.045), 6)
	ci.draw_rect(Rect2(p.x - k * 0.025, p.y - k * 0.01, k * 0.05, k * 0.03), Color(0.15, 0.13, 0.12))
	ci.draw_line(p, p + Vector2(0, -k * 0.07), Color(0.38, 0.25, 0.14), maxf(3.0, k * 0.014))
	_flame(ci, p + Vector2(0, -k * 0.075), k * 0.06, k * 0.02, t, seed)


static func _dinner_front(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	# tablecloth running to the bottom of the picture (you sit at the near edge)
	var tl := _p(r, 0.03, 0.70)
	var tr := _p(r, 0.97, 0.70)
	var nr := _p(r, 1.12, 1.02)
	var nl := _p(r, -0.12, 1.02)
	ci.draw_colored_polygon(PackedVector2Array([tl + Vector2(0, -4), tr + Vector2(0, -4), tr, tl]), Color(0.6, 0.56, 0.5))
	var far_c := Color(0.78, 0.74, 0.68)
	var near_c := Color(0.96, 0.93, 0.87)
	ci.draw_polygon(PackedVector2Array([tl, tr, nr, nl]), PackedColorArray([far_c, far_c, near_c, near_c]))
	# a burgundy runner
	var run := PackedVector2Array([_p(r, 0.5, 0.70), _p(r, 0.66, 0.70), _p(r, 0.74, 1.02), _p(r, 0.42, 1.02)])
	ci.draw_colored_polygon(run, Color(0.45, 0.08, 0.13, 0.85))
	# the date's plate and cutlery, just in front of it
	var pc := _p(r, 0.33, 0.745)
	ci.draw_colored_polygon(_ellipse(pc, k * 0.12, k * 0.026), Color(0.99, 0.99, 0.97))
	_closed(ci, _ellipse(pc, k * 0.08, k * 0.016), Color(0.75, 0.72, 0.68), 1.5)
	ci.draw_line(pc + Vector2(-k * 0.15, -k * 0.012), pc + Vector2(-k * 0.16, k * 0.02), Color(0.7, 0.7, 0.72), 2.5)
	ci.draw_line(pc + Vector2(k * 0.15, -k * 0.012), pc + Vector2(k * 0.16, k * 0.02), Color(0.7, 0.7, 0.72), 2.5)
	# your plate at the bottom
	var yc := _p(r, 0.55, 1.0)
	ci.draw_colored_polygon(_ellipse(yc, k * 0.26, k * 0.07), Color(0.99, 0.99, 0.97))
	_closed(ci, _ellipse(yc, k * 0.18, k * 0.045), Color(0.75, 0.72, 0.68), 2.0)
	# wine glasses, the candle, a rose
	_wine(ci, _p(r, 0.47, 0.80), k * 0.13)
	_wine(ci, _p(r, 0.73, 0.82), k * 0.13)
	var cb := _p(r, 0.60, 0.76)
	_candle(ci, cb, k, t)
	_rose(ci, _p(r, 0.85, 0.78), k * 0.2, t)
	# warm candle light over everything
	_glow(ci, cb - Vector2(0, k * 0.2), k * 0.55, Color(1.0, 0.6, 0.25, 0.03), 6)


static func _candle(ci: CanvasItem, base: Vector2, k: float, t: float) -> void:
	var brass := Color(0.78, 0.6, 0.28)
	ci.draw_colored_polygon(_ellipse(base, k * 0.045, k * 0.012), brass)
	ci.draw_rect(Rect2(base.x - k * 0.008, base.y - k * 0.06, k * 0.016, k * 0.06), brass)
	ci.draw_colored_polygon(_ellipse(base - Vector2(0, k * 0.06), k * 0.03, k * 0.009), brass)
	var ch := k * 0.13
	var cw := k * 0.026
	var top := base - Vector2(0, k * 0.06 + ch)
	ci.draw_rect(Rect2(top.x - cw * 0.5, top.y, cw, ch), Color(0.97, 0.94, 0.85))
	ci.draw_rect(Rect2(top.x + cw * 0.1, top.y, cw * 0.25, ch * 0.3), Color(1, 1, 0.95))
	ci.draw_line(top, top - Vector2(0, k * 0.012), Color(0.15, 0.1, 0.08), 1.5)
	_glow(ci, top - Vector2(0, k * 0.03), k * 0.12, Color(1.0, 0.7, 0.3, 0.06), 5)
	_flame(ci, top - Vector2(0, k * 0.008), k * 0.05, k * 0.012, t, 1.0)


static func _wine(ci: CanvasItem, base: Vector2, s: float) -> void:
	var glass := Color(0.85, 0.9, 0.97, 0.35)
	var rim := Color(0.95, 0.97, 1.0, 0.8)
	ci.draw_colored_polygon(_ellipse(base, s * 0.24, s * 0.05), glass)
	ci.draw_line(base, base - Vector2(0, s * 0.45), rim, 2.0)
	var c := base - Vector2(0, s * 0.72)
	var w := s * 0.27
	var bowl := PackedVector2Array()
	bowl.append(c + Vector2(-w, -s * 0.24))
	for i in 13:
		var a := PI - PI * i / 12.0
		bowl.append(c + Vector2(cos(a) * w, sin(a) * s * 0.28))
	bowl.append(c + Vector2(w, -s * 0.24))
	ci.draw_colored_polygon(bowl, glass)
	var wine := PackedVector2Array()
	for i in 13:
		var a2 := PI - PI * i / 12.0
		wine.append(c + Vector2(cos(a2) * w * 0.93, sin(a2) * s * 0.25 + s * 0.01))
	ci.draw_colored_polygon(wine, Color(0.48, 0.04, 0.12, 0.92))
	ci.draw_polyline(bowl, rim, 1.5, true)
	ci.draw_line(c + Vector2(-w * 0.6, -s * 0.15), c + Vector2(-w * 0.7, s * 0.1), Color(1, 1, 1, 0.6), 2.0)


static func _rose(ci: CanvasItem, base: Vector2, s: float, t: float) -> void:
	# a slim glass vase
	ci.draw_rect(Rect2(base.x - s * 0.07, base.y - s * 0.38, s * 0.14, s * 0.38), Color(0.75, 0.88, 0.95, 0.35))
	ci.draw_rect(Rect2(base.x - s * 0.07, base.y - s * 0.38, s * 0.14, s * 0.38), Color(0.9, 0.95, 1.0, 0.6), false, 1.5)
	var sway := sin(t * 0.8) * s * 0.02
	var bloom := base + Vector2(s * 0.08 + sway, -s * 0.95)
	var stem := PackedVector2Array([base - Vector2(0, s * 0.05), base + Vector2(s * 0.02, -s * 0.5), bloom + Vector2(-s * 0.02, s * 0.08)])
	ci.draw_polyline(stem, Color(0.22, 0.5, 0.2), maxf(2.0, s * 0.025), true)
	var leaf := _ellipse(Vector2.ZERO, s * 0.1, s * 0.035, 14)
	var lp := base + Vector2(s * 0.05, -s * 0.58)
	var leaf2 := PackedVector2Array()
	for q in leaf:
		leaf2.append(lp + q.rotated(-0.6) + Vector2(s * 0.08, 0))
	ci.draw_colored_polygon(leaf2, Color(0.25, 0.55, 0.22))
	ci.draw_circle(bloom, s * 0.11, Color(0.62, 0.05, 0.13))
	ci.draw_circle(bloom + Vector2(-s * 0.02, -s * 0.02), s * 0.08, Color(0.8, 0.1, 0.2))
	ci.draw_arc(bloom, s * 0.05, 0.3, 4.5, 12, Color(0.45, 0.02, 0.08), 2.0, true)
	ci.draw_arc(bloom + Vector2(s * 0.01, 0), s * 0.025, 2.0, 6.0, 10, Color(0.45, 0.02, 0.08), 1.5, true)


# --- sunset ash-scattering cruise -----------------------------------------------

const HORIZON := 0.56


static func _boat_center(r: Rect2, t: float) -> Vector2:
	return _p(r, 0.36, 0.84) + Vector2(0, sin(t * 1.5) * r.size.y * 0.008)


static func _boat_size(r: Rect2) -> float:
	return minf(r.size.x * 0.30, _k(r) * 0.55)


static func _boat_tilt(t: float) -> float:
	return sin(t * 1.1) * 0.025


static func _cruise_back(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	var mid := Color(0.74, 0.34, 0.38)
	_vgrad(ci, Rect2(r.position, Vector2(r.size.x, r.size.y * 0.3)), Color(0.19, 0.12, 0.31), mid)
	_vgrad(ci, Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * (HORIZON - 0.3) + 1.0)), mid, Color(0.99, 0.70, 0.42))
	for i in 4:
		var cx := fposmod(0.15 + i * 0.29 + t * 0.004, 1.3) - 0.15
		var cy := 0.12 + i * 0.07
		ci.draw_colored_polygon(_ellipse(_p(r, cx, cy), r.size.x * 0.16, k * 0.012, 20), Color(1.0, 0.6, 0.65, 0.22))
	var sun := _p(r, 0.72, HORIZON)
	_glow(ci, sun, k * 0.4, Color(1.0, 0.7, 0.4, 0.05), 6)
	ci.draw_circle(sun, k * 0.12, Color(1.0, 0.82, 0.48))
	# the far shore, with the silhouette of a castle
	var shore := PackedVector2Array([_p(r, 0.0, HORIZON - 0.07), _p(r, 0.08, HORIZON - 0.09), _p(r, 0.2, HORIZON - 0.06),
		_p(r, 0.32, HORIZON - 0.035), _p(r, 0.46, HORIZON - 0.01), _p(r, 0.5, HORIZON + 0.002), _p(r, 0.0, HORIZON + 0.002)])
	ci.draw_colored_polygon(shore, Color(0.27, 0.13, 0.25))
	_castle(ci, _p(r, 0.14, HORIZON - 0.075), k * 0.035, Color(0.27, 0.13, 0.25))
	var isle := PackedVector2Array([_p(r, 0.86, HORIZON + 0.002), _p(r, 0.92, HORIZON - 0.03), _p(r, 1.0, HORIZON - 0.04), _p(r, 1.0, HORIZON + 0.002)])
	ci.draw_colored_polygon(isle, Color(0.3, 0.15, 0.27))
	# water
	_vgrad(ci, Rect2(r.position + Vector2(0, r.size.y * HORIZON), Vector2(r.size.x, r.size.y * (1.0 - HORIZON) + 2.0)), Color(0.80, 0.44, 0.40), Color(0.14, 0.08, 0.19))
	ci.draw_line(_p(r, 0.0, HORIZON), _p(r, 1.0, HORIZON), Color(1.0, 0.85, 0.6, 0.6), 2.0)
	for i in 12:
		var yy := HORIZON + 0.012 + pow(i / 12.0, 1.4) * 0.4
		var wv := k * 0.12 * (1.0 - i / 14.0) * (0.6 + 0.4 * sin(t * 2.3 + i * 1.7))
		var cx2 := sun.x + sin(t * 1.3 + i) * 4.0
		ci.draw_rect(Rect2(cx2 - wv, r.position.y + r.size.y * yy, wv * 2.0, maxf(2.0, k * 0.007)), Color(1.0, 0.84, 0.52, 0.55 - i * 0.035))
	for i in 18:
		var rx := fposmod(_h(i, 11) + t * 0.006 * (1.0 + _h(i, 12)), 1.0)
		var ry := HORIZON + 0.05 + _h(i, 13) * 0.42
		var rp := _p(r, rx, ry)
		var rl := k * (0.02 + 0.03 * (ry - HORIZON))
		ci.draw_line(rp, rp + Vector2(rl, 0), Color(1.0, 0.8, 0.7, 0.18), 1.5)
	# two birds
	for i in 2:
		var bp := _p(r, fposmod(0.1 + i * 0.12 + t * 0.012, 1.2) - 0.1, 0.2 + i * 0.05)
		var flap := sin(t * 6.0 + i) * k * 0.008
		var bs := k * 0.018
		ci.draw_polyline(PackedVector2Array([bp + Vector2(-bs, -flap), bp, bp + Vector2(bs, -flap)]), Color(0.18, 0.08, 0.15), 2.0, true)


static func _urn(ci: CanvasItem, base: Vector2, h: float) -> void:
	var col := Color(0.42, 0.47, 0.58)
	var body := PackedVector2Array()
	var prof := [Vector2(0.22, 0.0), Vector2(0.34, 0.25), Vector2(0.36, 0.5), Vector2(0.24, 0.75), Vector2(0.16, 0.85), Vector2(0.22, 0.92)]
	for v in prof:
		var q: Vector2 = v
		body.append(base + Vector2(q.x * h, -q.y * h))
	for i in range(prof.size() - 1, -1, -1):
		var q2: Vector2 = prof[i]
		body.append(base + Vector2(-q2.x * h, -q2.y * h))
	ci.draw_colored_polygon(body, col)
	ci.draw_rect(Rect2(base.x - h * 0.3, base.y - h * 0.5, h * 0.6, h * 0.06), Color(0.85, 0.7, 0.35))
	ci.draw_colored_polygon(_ellipse(base - Vector2(0, h * 0.92), h * 0.22, h * 0.05), Color(0.25, 0.25, 0.28))
	ci.draw_polyline(body, Color(0.2, 0.22, 0.3), 1.5, true)


static func _cruise_front(ci: CanvasItem, r: Rect2, t: float) -> void:
	var k := _k(r)
	var c := _boat_center(r, t)
	var b := _boat_size(r)
	var tilt := _boat_tilt(t)
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, b * 0.36), b * 1.1, b * 0.07), Color(0.05, 0.03, 0.08, 0.35))
	ci.draw_set_transform(c, tilt, Vector2.ONE)
	_urn(ci, Vector2(b * 0.6, -0.08 * b), b * 0.24)
	var hull_pts := [Vector2(-1.0, -0.10), Vector2(-0.93, 0.12), Vector2(-0.6, 0.25), Vector2(0.0, 0.28), Vector2(0.6, 0.22),
		Vector2(0.96, 0.02), Vector2(1.06, -0.24), Vector2(0.55, -0.13), Vector2(0.0, -0.11), Vector2(-0.5, -0.1)]
	var hull := PackedVector2Array()
	for v in hull_pts:
		var q: Vector2 = v
		hull.append(q * b)
	ci.draw_colored_polygon(hull, Color(0.43, 0.26, 0.15))
	for j in 2:
		var off := 0.08 + j * 0.08
		var plank := PackedVector2Array([Vector2(-0.97, -0.1 + off), Vector2(-0.5, -0.1 + off), Vector2(0.0, -0.11 + off), Vector2(0.55, -0.13 + off), Vector2(0.98, -0.2 + off * 1.4)])
		for i in plank.size():
			plank[i] = plank[i] * b
		ci.draw_polyline(plank, Color(0.3, 0.17, 0.09), 1.5, true)
	var rim := PackedVector2Array([Vector2(-1.0, -0.10), Vector2(-0.5, -0.1), Vector2(0.0, -0.11), Vector2(0.55, -0.13), Vector2(1.06, -0.24)])
	for i in rim.size():
		rim[i] = rim[i] * b
	ci.draw_polyline(rim, Color(0.66, 0.46, 0.27), maxf(3.0, b * 0.035), true)
	ci.draw_line(Vector2(-0.6, -0.12) * b, Vector2(-1.3, 0.3) * b, Color(0.55, 0.38, 0.2), maxf(3.0, b * 0.03))
	ci.draw_colored_polygon(_ellipse(Vector2(-1.3, 0.32) * b, b * 0.12, b * 0.04), Color(0.55, 0.38, 0.2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ash rising from the urn
	var mouth := c + (Vector2(b * 0.6, -0.08 * b - b * 0.24 * 0.95)).rotated(tilt)
	for i in 10:
		var ph := fposmod(t * 0.35 + i / 10.0, 1.0)
		var ap := mouth + Vector2(sin(t * 1.7 + i * 1.3) * k * 0.02 + ph * k * 0.12, -ph * k * 0.28)
		ci.draw_circle(ap, 1.5 + ph * 2.5, Color(0.72, 0.7, 0.68, 0.7 * (1.0 - ph)))
	# ash drifting across the lake
	for i in 36:
		var sp := 0.008 + _h(i, 3) * 0.02
		var x := fposmod(_h(i, 1) + t * sp, 1.0)
		var y := fposmod(_h(i, 2) + t * (0.006 + _h(i, 4) * 0.01), 1.0)
		var p := _p(r, x + sin(t * 1.5 + i) * 0.008, y)
		ci.draw_circle(p, 1.2 + _h(i, 6) * 1.8, Color(0.78, 0.75, 0.73, 0.35 + 0.35 * _h(i, 7)))
