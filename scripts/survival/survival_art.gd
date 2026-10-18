class_name SurvivalArt
extends RefCounted
## Procedural art for the survival screen: pictures of each ruined place,
## item icons, map marker glyphs and the rescue helicopter. Everything is
## drawn in normalized rect space so it scales with the layout.

const SKY_TOP := Color(0.11, 0.055, 0.05)
const SKY_GLOW := Color(0.66, 0.31, 0.12)
const ASH := Color(0.80, 0.76, 0.72)
const SOOT := Color(0.085, 0.065, 0.06)
const RUBBLE := Color(0.26, 0.2, 0.16)
const RAD_GREEN := Color(0.56, 0.98, 0.36)
const LINE := Color(0.07, 0.05, 0.05)
const BRICK := Color(0.45, 0.22, 0.16)
const CONCRETE := Color(0.42, 0.39, 0.36)


# --- tiny helpers ------------------------------------------------------------------

static func P(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


static func R(r: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(P(r, x, y), Vector2(w * r.size.x, h * r.size.y))


static func poly(r: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		var p: Vector2 = v
		out.append(P(r, p.x, p.y))
	return out


static func fill(ci: CanvasItem, r: Rect2, pts: Array, c: Color) -> void:
	ci.draw_colored_polygon(poly(r, pts), c)


static func shape(ci: CanvasItem, r: Rect2, pts: Array, c: Color, line: Color = LINE, w: float = 1.5) -> void:
	var p := poly(r, pts)
	ci.draw_colored_polygon(p, c)
	var closed := p.duplicate()
	closed.append(p[0])
	ci.draw_polyline(closed, line, w, true)


static func grad(ci: CanvasItem, rect: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func hash01(i: int, salt: int = 0) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floor(v)


static func lw(r: Rect2) -> float:
	return maxf(1.0, minf(r.size.x, r.size.y) * 0.012)


# --- shared scenery -------------------------------------------------------------------

## An orange-brown ruined sky down to `horizon` (0..1 of the rect).
static func sky(ci: CanvasItem, r: Rect2, horizon: float, t: float, weather: String = "haze") -> void:
	var top := SKY_TOP
	var glow := SKY_GLOW
	match weather:
		"clear":
			top = Color(0.16, 0.09, 0.08)
			glow = Color(0.78, 0.45, 0.2)
		"overcast":
			top = Color(0.09, 0.07, 0.07)
			glow = Color(0.42, 0.26, 0.16)
		"ash":
			top = Color(0.16, 0.14, 0.13)
			glow = Color(0.5, 0.36, 0.26)
	var hz := R(r, 0, 0, 1, horizon)
	grad(ci, hz, top, glow)
	# a sullen sun behind the haze
	var sun := P(r, 0.2, horizon * 0.45)
	var sr := r.size.y * 0.06
	ci.draw_circle(sun, sr * 2.2, Color(1.0, 0.6, 0.25, 0.08))
	ci.draw_circle(sun, sr, Color(1.0, 0.72, 0.4, 0.35 if weather == "clear" else 0.18))
	# drifting smoke bands
	for i in 3:
		var y := horizon * (0.25 + i * 0.22)
		var x := fposmod(0.15 * i + t * 0.01 * (i + 1), 1.4) - 0.2
		var band := R(r, x - 0.3, y - 0.03, 0.7, 0.06)
		ci.draw_colored_polygon(ellipse(band.get_center(), band.size.x * 0.5, band.size.y * 0.5, 18), Color(0.05, 0.03, 0.03, 0.18))


static func ground(ci: CanvasItem, r: Rect2, horizon: float, near: Color = Color(0.2, 0.15, 0.12)) -> void:
	grad(ci, R(r, 0, horizon, 1, 1.0 - horizon), near.darkened(0.35), near)


## Flecks of ash falling through the rect.
static func ash_flecks(ci: CanvasItem, r: Rect2, t: float, n: int = 22, alpha: float = 0.55) -> void:
	var s := maxf(1.5, r.size.x * 0.007)
	for i in n:
		var x := fposmod(hash01(i, 1) + t * (0.012 + hash01(i, 2) * 0.02) + sin(t * 0.7 + i) * 0.01, 1.0)
		var y := fposmod(hash01(i, 3) + t * (0.03 + hash01(i, 4) * 0.03), 1.0)
		ci.draw_rect(Rect2(P(r, x, y), Vector2(s, s)), Color(ASH.r, ASH.g, ASH.b, alpha * (0.4 + 0.6 * hash01(i, 5))))


## A low line of rubble mounds along y (0..1).
static func rubble(ci: CanvasItem, r: Rect2, y: float, h: float, salt: int, col: Color = RUBBLE) -> void:
	var pts: Array = [Vector2(0, 1), Vector2(0, y)]
	var n := 14
	for i in n + 1:
		var x := float(i) / n
		pts.append(Vector2(x, y - h * (0.3 + 0.7 * hash01(i, salt))))
	pts.append(Vector2(1, 1))
	fill(ci, r, pts, col)
	for i in 9:
		var bx := hash01(i, salt + 7)
		var by := y + hash01(i, salt + 8) * (1.0 - y) * 0.6
		var br := R(r, bx, by, 0.03 + hash01(i, salt + 9) * 0.04, 0.02 + hash01(i, salt + 3) * 0.02)
		ci.draw_rect(br, col.lightened(0.12 + hash01(i, salt) * 0.15))


static func broken_window(ci: CanvasItem, rect: Rect2, glow: float = 0.0) -> void:
	ci.draw_rect(rect, Color(0.05, 0.04, 0.04))
	if glow > 0.0:
		ci.draw_rect(rect, Color(1.0, 0.55, 0.2, glow))
	var a := rect.position
	var b := rect.end
	ci.draw_colored_polygon(PackedVector2Array([a, Vector2(a.x + rect.size.x * 0.4, a.y), Vector2(a.x, a.y + rect.size.y * 0.5)]), Color(0.7, 0.75, 0.78, 0.35))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(b.x, b.y), Vector2(b.x - rect.size.x * 0.35, b.y), Vector2(b.x, b.y - rect.size.y * 0.4)]), Color(0.7, 0.75, 0.78, 0.25))


static func label_text(ci: CanvasItem, pos: Vector2, text: String, fs: int, col: Color, center: bool = true) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(w * 0.5 if center else 0.0, 0)
	ci.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func flame(ci: CanvasItem, base: Vector2, h: float, t: float, seed_value: float = 0.0) -> void:
	var k := 1.0 + sin(t * 11.0 + seed_value) * 0.1 + sin(t * 17.0 + seed_value * 2.0) * 0.06
	var w := h * 0.42
	ci.draw_circle(base - Vector2(0, h * 0.4), h * 0.9, Color(1.0, 0.5, 0.15, 0.12))
	var outer := PackedVector2Array([base + Vector2(-w, 0), base + Vector2(-w * 0.8, -h * 0.45), base + Vector2(-w * 0.2, -h * 0.7 * k),
		base + Vector2(0, -h * k), base + Vector2(w * 0.35, -h * 0.62 * k), base + Vector2(w * 0.85, -h * 0.4), base + Vector2(w, 0)])
	ci.draw_colored_polygon(outer, Color(0.95, 0.4, 0.1))
	var inner := PackedVector2Array()
	for p in outer:
		inner.append(base + (p - base) * 0.58)
	ci.draw_colored_polygon(inner, Color(1.0, 0.85, 0.4))


static func smoke(ci: CanvasItem, base: Vector2, s: float, t: float, n: int = 7, col: Color = Color(0.2, 0.18, 0.17)) -> void:
	for i in n:
		var k := fposmod(t * 0.25 + float(i) / n, 1.0)
		var p := base + Vector2(sin(k * 5.0 + i) * s * 0.3 + k * s * 0.8, -k * s * 3.0)
		var c := col
		c.a = 0.55 * (1.0 - k)
		ci.draw_circle(p, s * (0.25 + k * 0.6), c)


## The radiation trefoil.
static func trefoil(ci: CanvasItem, c: Vector2, rad: float, fg: Color = Color(0.08, 0.06, 0.04), bg: Color = Color(0.98, 0.82, 0.2)) -> void:
	if bg.a > 0.0:
		ci.draw_circle(c, rad, bg)
	for k in 3:
		var a0 := -PI * 0.5 + TAU * k / 3.0 - PI / 6.0
		var pts := PackedVector2Array()
		pts.append(c + Vector2(cos(a0 + PI / 6.0), sin(a0 + PI / 6.0)) * rad * 0.2)
		for j in 7:
			var a := a0 + (PI / 3.0) * j / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad * 0.85)
		ci.draw_colored_polygon(pts, fg)
	ci.draw_circle(c, rad * 0.16, fg)


static func chess_tile(ci: CanvasItem, c: Vector2, s: float, rot: float, light: bool) -> void:
	var col := Color(0.86, 0.8, 0.66) if light else Color(0.24, 0.19, 0.2)
	var pts := PackedVector2Array()
	for k in 4:
		var a := rot + PI * 0.25 + TAU * k / 4.0
		pts.append(c + Vector2(cos(a), sin(a) * 0.62) * s * 0.7)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0, 0, 0, 0.5), 1.0, true)


# --- location pictures ----------------------------------------------------------------

## Draws a picture of a place in rect r. opts: weather, sos, fire, radio, picked.
static func draw_location(ci: CanvasItem, r: Rect2, id: String, t: float, opts: Dictionary = {}) -> void:
	var weather: String = opts.get("weather", "haze")
	match id:
		"shelter":
			_pic_shelter(ci, r, t, opts)
		"store":
			_pic_store(ci, r, t, weather)
		"pharmacy":
			_pic_pharmacy(ci, r, t, weather)
		"hardware":
			_pic_hardware(ci, r, t, weather)
		"school":
			_pic_school(ci, r, t, weather)
		"fire_station":
			_pic_fire_station(ci, r, t, weather)
		"police":
			_pic_police(ci, r, t, weather)
		"water_tower":
			_pic_water_tower(ci, r, t, weather)
		"radio_station":
			_pic_radio_station(ci, r, t, weather)
		"ground_zero":
			_pic_ground_zero(ci, r, t, weather)
	ash_flecks(ci, r, t, 26 if weather == "ash" else 14, 0.6 if weather == "ash" else 0.4)
	if bool(opts.get("picked", false)):
		var font := ThemeDB.fallback_font
		var fs := int(clampf(r.size.y * 0.13, 15.0, 24.0))
		var txt := "PICKED OVER"
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c := r.get_center()
		ci.draw_rect(Rect2(c - Vector2(w * 0.5 + 10, fs * 0.8), Vector2(w + 20, fs * 1.3)), Color(0, 0, 0, 0.55))
		ci.draw_string(font, c + Vector2(-w * 0.5, fs * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.9, 0.8, 0.6, 0.9))
	# vignette
	var k := Color(0, 0, 0, 0.45)
	var z := Color(0, 0, 0, 0)
	var e := r.size.x * 0.12
	ci.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(e, 0), Vector2(r.position.x + e, r.end.y), Vector2(r.position.x, r.end.y)]), PackedColorArray([k, z, z, k]))
	ci.draw_polygon(PackedVector2Array([Vector2(r.end.x - e, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(r.end.x - e, r.end.y)]), PackedColorArray([z, k, k, z]))


static func _pic_shelter(ci: CanvasItem, r: Rect2, t: float, opts: Dictionary) -> void:
	var weather: String = opts.get("weather", "haze")
	sky(ci, r, 0.6, t, weather)
	ground(ci, r, 0.6)
	var w := lw(r)
	# far ruins
	for i in 7:
		var x := 0.02 + i * 0.14
		var h := 0.08 + hash01(i, 21) * 0.14
		fill(ci, r, [Vector2(x, 0.6), Vector2(x, 0.6 - h), Vector2(x + 0.04, 0.6 - h - 0.03), Vector2(x + 0.08, 0.6 - h + 0.02), Vector2(x + 0.11, 0.6)], SOOT.lightened(0.05))
	# what's left of the house: one wall, a tilted roof slab
	shape(ci, r, [Vector2(0.1, 0.78), Vector2(0.1, 0.36), Vector2(0.18, 0.3), Vector2(0.22, 0.42), Vector2(0.3, 0.34), Vector2(0.34, 0.5), Vector2(0.34, 0.78)], BRICK.darkened(0.25), LINE, w)
	broken_window(ci, R(r, 0.16, 0.5, 0.1, 0.12), 0.0)
	var roof := [Vector2(0.3, 0.74), Vector2(0.38, 0.42), Vector2(0.86, 0.5), Vector2(0.82, 0.78)]
	shape(ci, r, roof, Color(0.33, 0.27, 0.24), LINE, w)
	for i in 5:
		var k := 0.15 + i * 0.17
		ci.draw_line(P(r, lerpf(0.3, 0.38, k), lerpf(0.74, 0.42, k)), P(r, lerpf(0.82, 0.86, k), lerpf(0.78, 0.5, k)), Color(0.22, 0.18, 0.16), w * 0.7)
	if bool(opts.get("sos", false)):
		var font := ThemeDB.fallback_font
		var fs := int(r.size.y * 0.17)
		ci.draw_set_transform(P(r, 0.44, 0.67), 0.12, Vector2(1.25, 0.8))
		ci.draw_string(font, Vector2.ZERO, "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.45, 0.1))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the hatch down to the basement, warm light inside
	var hatch := R(r, 0.5, 0.84, 0.16, 0.07)
	ci.draw_rect(hatch.grow(3), Color(0.3, 0.22, 0.14))
	ci.draw_rect(hatch, Color(1.0, 0.62, 0.25, 0.75))
	ci.draw_colored_polygon(poly(r, [Vector2(0.5, 0.84), Vector2(0.66, 0.84), Vector2(0.63, 0.74), Vector2(0.53, 0.74)]), Color(0.42, 0.3, 0.18))
	ci.draw_circle(hatch.get_center(), r.size.x * 0.12, Color(1.0, 0.6, 0.2, 0.08))
	if bool(opts.get("radio", false)):
		ci.draw_line(P(r, 0.64, 0.86), P(r, 0.9, 0.2), Color(0.15, 0.13, 0.12), w)
		ci.draw_line(P(r, 0.9, 0.2), P(r, 0.9, 0.62), Color(0.3, 0.27, 0.25), w * 1.6)
		var blink := 0.5 + 0.5 * sin(t * 4.0)
		ci.draw_circle(P(r, 0.9, 0.2), r.size.x * 0.012, Color(1.0, 0.2, 0.15, 0.4 + 0.6 * blink))
	if bool(opts.get("fire", false)):
		var base := P(r, 0.22, 0.9)
		smoke(ci, base - Vector2(0, r.size.y * 0.08), r.size.y * 0.16, t, 8)
		ci.draw_line(base + Vector2(-r.size.x * 0.05, 0), base + Vector2(r.size.x * 0.05, -4), Color(0.3, 0.2, 0.12), w * 3.0)
		ci.draw_line(base + Vector2(-r.size.x * 0.05, -4), base + Vector2(r.size.x * 0.05, 0), Color(0.35, 0.22, 0.14), w * 3.0)
		flame(ci, base, r.size.y * 0.16, t)
	rubble(ci, r, 0.95, 0.06, 3)


static func _pic_store(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.64, t, weather)
	ground(ci, r, 0.64, Color(0.2, 0.17, 0.15))
	var w := lw(r)
	# the shop
	shape(ci, r, [Vector2(0.5, 0.78), Vector2(0.5, 0.36), Vector2(0.7, 0.33), Vector2(0.76, 0.38), Vector2(0.96, 0.36), Vector2(0.96, 0.78)], Color(0.48, 0.42, 0.34), LINE, w)
	ci.draw_rect(R(r, 0.5, 0.38, 0.46, 0.08), Color(0.62, 0.16, 0.12))
	label_text(ci, P(r, 0.73, 0.445), "GAMBIT GOODS", int(r.size.y * 0.06), Color(1.0, 0.86, 0.55))
	broken_window(ci, R(r, 0.53, 0.5, 0.17, 0.18), 0.05)
	broken_window(ci, R(r, 0.76, 0.5, 0.17, 0.18), 0.05)
	ci.draw_rect(R(r, 0.715, 0.55, 0.035, 0.23), Color(0.08, 0.06, 0.05))
	# the canopy, one pillar gone
	ci.draw_line(P(r, 0.1, 0.8), P(r, 0.1, 0.38), Color(0.6, 0.58, 0.55), w * 2.5)
	fill(ci, r, [Vector2(0.04, 0.33), Vector2(0.46, 0.42), Vector2(0.46, 0.47), Vector2(0.04, 0.38)], Color(0.7, 0.66, 0.6))
	fill(ci, r, [Vector2(0.04, 0.38), Vector2(0.46, 0.47), Vector2(0.46, 0.49), Vector2(0.04, 0.4)], Color(0.62, 0.16, 0.12))
	# melted pumps
	for i in 2:
		var x := 0.18 + i * 0.15
		shape(ci, r, [Vector2(x, 0.8), Vector2(x, 0.6), Vector2(x + 0.02, 0.56), Vector2(x + 0.05, 0.6), Vector2(x + 0.07, 0.57), Vector2(x + 0.08, 0.64), Vector2(x + 0.08, 0.8)],
			Color(0.75, 0.2, 0.15).darkened(0.2 * i), LINE, w)
		ci.draw_rect(R(r, x + 0.015, 0.64, 0.05, 0.05), Color(0.15, 0.13, 0.12))
		# a drip of melted plastic
		ci.draw_line(P(r, x + 0.08, 0.66), P(r, x + 0.09, 0.74), Color(0.75, 0.2, 0.15).darkened(0.3), w * 1.4)
	# the price sign with a pawn on it
	ci.draw_line(P(r, 0.43, 0.82), P(r, 0.43, 0.2), Color(0.35, 0.33, 0.3), w * 2.0)
	ci.draw_rect(R(r, 0.37, 0.14, 0.12, 0.12), Color(0.9, 0.84, 0.7))
	ci.draw_rect(R(r, 0.37, 0.14, 0.12, 0.12), LINE, false, w)
	ci.draw_circle(P(r, 0.43, 0.175), r.size.y * 0.018, LINE)
	fill(ci, r, [Vector2(0.415, 0.24), Vector2(0.445, 0.24), Vector2(0.437, 0.19), Vector2(0.423, 0.19)], LINE)
	rubble(ci, r, 0.93, 0.05, 11)


static func _pic_pharmacy(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.62, t, weather)
	ground(ci, r, 0.62)
	var w := lw(r)
	shape(ci, r, [Vector2(0.08, 0.8), Vector2(0.08, 0.3), Vector2(0.4, 0.3), Vector2(0.48, 0.24), Vector2(0.56, 0.32), Vector2(0.92, 0.3), Vector2(0.92, 0.8)], Color(0.55, 0.52, 0.48), LINE, w)
	ci.draw_rect(R(r, 0.08, 0.34, 0.84, 0.08), Color(0.2, 0.42, 0.28))
	label_text(ci, P(r, 0.5, 0.405), "PHARMACY", int(r.size.y * 0.065), Color(0.92, 0.95, 0.88))
	broken_window(ci, R(r, 0.13, 0.48, 0.28, 0.2), 0.0)
	broken_window(ci, R(r, 0.59, 0.48, 0.28, 0.2), 0.0)
	# shelves through the glass, with a few bottles
	for i in 2:
		var y := 0.55 + i * 0.07
		ci.draw_line(P(r, 0.13, y), P(r, 0.41, y), Color(0.4, 0.35, 0.3), w)
		ci.draw_line(P(r, 0.59, y), P(r, 0.87, y), Color(0.4, 0.35, 0.3), w)
		for j in 4:
			if hash01(i * 7 + j, 31) < 0.5:
				ci.draw_rect(R(r, 0.15 + j * 0.065, y - 0.035, 0.022, 0.035), Color(0.9, 0.9, 0.88))
			if hash01(i * 7 + j, 33) < 0.4:
				ci.draw_rect(R(r, 0.61 + j * 0.065, y - 0.035, 0.022, 0.035), Color(0.9, 0.6, 0.2))
	ci.draw_rect(R(r, 0.45, 0.5, 0.1, 0.3), Color(0.06, 0.05, 0.05))
	# the green cross, hanging by one bolt
	var pivot := P(r, 0.86, 0.12)
	ci.draw_line(P(r, 0.92, 0.12), pivot, Color(0.3, 0.3, 0.3), w * 1.5)
	ci.draw_set_transform(pivot, 0.45 + sin(t * 1.3) * 0.04, Vector2.ONE)
	var s := r.size.y * 0.055
	var cross := PackedVector2Array([Vector2(-s, 0), Vector2(s, 0), Vector2(s, s), Vector2(2 * s, s), Vector2(2 * s, 2 * s), Vector2(s, 2 * s), Vector2(s, 3 * s),
		Vector2(-s, 3 * s), Vector2(-s, 2 * s), Vector2(-2 * s, 2 * s), Vector2(-2 * s, s), Vector2(-s, s)])
	ci.draw_colored_polygon(cross, Color(0.3, 0.85, 0.4))
	cross.append(cross[0])
	ci.draw_polyline(cross, LINE, w, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(P(r, 0.86, 0.3), r.size.x * 0.1, Color(0.3, 0.9, 0.4, 0.05))
	rubble(ci, r, 0.94, 0.05, 17)
	for i in 5:
		ci.draw_rect(R(r, 0.2 + hash01(i, 41) * 0.6, 0.86 + hash01(i, 42) * 0.08, 0.02, 0.012), Color(0.92, 0.92, 0.9))


static func _pic_hardware(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.6, t, weather)
	ground(ci, r, 0.6)
	var w := lw(r)
	shape(ci, r, [Vector2(0.04, 0.8), Vector2(0.04, 0.32), Vector2(0.96, 0.32), Vector2(0.96, 0.8)], Color(0.5, 0.46, 0.4), LINE, w)
	# corrugated roof, caved in on the right: a zigzag top edge over a sagging underside
	var top_edge: Array = []
	var under: Array = []
	for i in 14:
		var x := 0.02 + i * 0.0738
		var sag := 0.0 if x < 0.55 else (x - 0.55) * 0.45
		top_edge.append(Vector2(x, 0.28 + sag - (0.02 if i % 2 == 0 else 0.0)))
		under.push_front(Vector2(x, 0.33 + sag))
	fill(ci, r, top_edge + under, Color(0.38, 0.38, 0.4))
	ci.draw_rect(R(r, 0.2, 0.37, 0.4, 0.08), Color(0.92, 0.6, 0.1))
	label_text(ci, P(r, 0.4, 0.435), "HARDWARE", int(r.size.y * 0.065), Color(0.12, 0.08, 0.05))
	ci.draw_rect(R(r, 0.08, 0.5, 0.36, 0.3), Color(0.07, 0.06, 0.05))
	# roller door half up
	for i in 5:
		ci.draw_line(P(r, 0.08, 0.5 + i * 0.022), P(r, 0.44, 0.5 + i * 0.022), Color(0.55, 0.55, 0.57), w * 1.2)
	broken_window(ci, R(r, 0.56, 0.5, 0.3, 0.16), 0.0)
	# a pallet of paint cans and a leaning ladder
	for i in 4:
		var x := 0.52 + i * 0.075
		var col: Color = [Color(0.9, 0.4, 0.1), Color(0.2, 0.5, 0.85), Color(0.9, 0.85, 0.2), Color(0.85, 0.2, 0.2)][i]
		ci.draw_rect(R(r, x, 0.76, 0.06, 0.08), col)
		ci.draw_rect(R(r, x, 0.76, 0.06, 0.012), col.lightened(0.3))
	ci.draw_rect(R(r, 0.5, 0.84, 0.33, 0.025), Color(0.5, 0.36, 0.2))
	ci.draw_line(P(r, 0.9, 0.86), P(r, 0.82, 0.48), Color(0.75, 0.7, 0.6), w * 1.5)
	ci.draw_line(P(r, 0.95, 0.86), P(r, 0.87, 0.48), Color(0.75, 0.7, 0.6), w * 1.5)
	for i in 5:
		var k := 0.15 + i * 0.17
		ci.draw_line(P(r, lerpf(0.9, 0.82, k), lerpf(0.86, 0.48, k)), P(r, lerpf(0.95, 0.87, k), lerpf(0.86, 0.48, k)), Color(0.75, 0.7, 0.6), w)
	rubble(ci, r, 0.95, 0.04, 23)


static func _pic_school(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.62, t, weather)
	ground(ci, r, 0.62, Color(0.22, 0.2, 0.14))
	var w := lw(r)
	shape(ci, r, [Vector2(0.06, 0.8), Vector2(0.06, 0.4), Vector2(0.34, 0.4), Vector2(0.5, 0.22), Vector2(0.66, 0.4), Vector2(0.8, 0.4), Vector2(0.84, 0.5), Vector2(0.86, 0.8)], BRICK, LINE, w)
	# clock stopped at the moment of the flash
	var cc := P(r, 0.5, 0.33)
	var cr := r.size.y * 0.055
	ci.draw_circle(cc, cr, Color(0.9, 0.86, 0.75))
	ci.draw_arc(cc, cr, 0, TAU, 20, LINE, w, true)
	ci.draw_line(cc, cc + Vector2(0, -cr * 0.8), LINE, w)
	ci.draw_line(cc, cc + Vector2(cr * 0.55, cr * 0.25), LINE, w)
	for i in 4:
		broken_window(ci, R(r, 0.1 + i * 0.18 + (0.04 if i > 1 else 0.0), 0.47, 0.11, 0.12), 0.0)
		broken_window(ci, R(r, 0.1 + i * 0.18 + (0.04 if i > 1 else 0.0), 0.63, 0.11, 0.1), 0.0)
	ci.draw_rect(R(r, 0.45, 0.6, 0.1, 0.2), Color(0.08, 0.06, 0.05))
	# a scorched flagpole and the swing set
	ci.draw_line(P(r, 0.95, 0.84), P(r, 0.95, 0.18), Color(0.6, 0.6, 0.62), w * 1.3)
	fill(ci, r, [Vector2(0.95, 0.19), Vector2(0.995, 0.21), Vector2(0.98, 0.24), Vector2(0.95, 0.26)], Color(0.25, 0.2, 0.2))
	ci.draw_line(P(r, 0.02, 0.9), P(r, 0.08, 0.66), Color(0.5, 0.5, 0.5), w * 1.2)
	ci.draw_line(P(r, 0.14, 0.9), P(r, 0.08, 0.66), Color(0.5, 0.5, 0.5), w * 1.2)
	ci.draw_line(P(r, 0.08, 0.66), P(r, 0.3, 0.66), Color(0.5, 0.5, 0.5), w * 1.2)
	var sw := sin(t * 1.4) * 0.02
	ci.draw_line(P(r, 0.2, 0.66), P(r, 0.2 + sw, 0.84), Color(0.4, 0.4, 0.4), w * 0.7)
	ci.draw_line(P(r, 0.25, 0.66), P(r, 0.25 + sw, 0.84), Color(0.4, 0.4, 0.4), w * 0.7)
	ci.draw_rect(R(r, 0.195 + sw, 0.84, 0.06, 0.012), Color(0.3, 0.2, 0.12))
	rubble(ci, r, 0.95, 0.04, 29)


static func _pic_fire_station(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.6, t, weather)
	ground(ci, r, 0.6)
	var w := lw(r)
	shape(ci, r, [Vector2(0.06, 0.8), Vector2(0.06, 0.3), Vector2(0.7, 0.3), Vector2(0.74, 0.4), Vector2(0.8, 0.36), Vector2(0.8, 0.8)], BRICK.lightened(0.05), LINE, w)
	shape(ci, r, [Vector2(0.8, 0.8), Vector2(0.8, 0.12), Vector2(0.94, 0.12), Vector2(0.94, 0.8)], BRICK.darkened(0.1), LINE, w)
	for i in 4:
		broken_window(ci, R(r, 0.835, 0.18 + i * 0.13, 0.07, 0.07), 0.0)
	ci.draw_rect(R(r, 0.06, 0.33, 0.68, 0.06), Color(0.85, 0.82, 0.75))
	label_text(ci, P(r, 0.4, 0.38), "FIRE STATION", int(r.size.y * 0.055), Color(0.6, 0.12, 0.1))
	# two bays: one shut and dented, one open with the engine's nose
	for i in 2:
		var bay := R(r, 0.1 + i * 0.33, 0.44, 0.27, 0.36)
		ci.draw_rect(bay, Color(0.06, 0.05, 0.05))
		if i == 0:
			for j in 6:
				ci.draw_line(Vector2(bay.position.x, bay.position.y + j * bay.size.y / 6.0 + 2), Vector2(bay.end.x, bay.position.y + j * bay.size.y / 6.0 + 2 + (3.0 if j == 3 else 0.0)), Color(0.55, 0.52, 0.5), w * 1.4)
	var eng := R(r, 0.45, 0.58, 0.21, 0.22)
	ci.draw_rect(eng, Color(0.75, 0.12, 0.1))
	broken_window(ci, R(r, 0.47, 0.6, 0.17, 0.07), 0.0)
	ci.draw_rect(R(r, 0.47, 0.71, 0.17, 0.02), Color(0.85, 0.85, 0.85))
	ci.draw_circle(P(r, 0.48, 0.75), r.size.y * 0.018, Color(1.0, 0.9, 0.6, 0.6))
	ci.draw_circle(P(r, 0.63, 0.75), r.size.y * 0.018, Color(0.3, 0.3, 0.3))
	# the bell
	ci.draw_colored_polygon(poly(r, [Vector2(0.4, 0.2), Vector2(0.43, 0.2), Vector2(0.45, 0.28), Vector2(0.38, 0.28)]), Color(0.85, 0.65, 0.25))
	ci.draw_line(P(r, 0.415, 0.2), P(r, 0.415, 0.3), Color(0.3, 0.3, 0.3), w * 0.6)
	rubble(ci, r, 0.95, 0.04, 37)


static func _pic_police(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.6, t, weather)
	ground(ci, r, 0.6)
	var w := lw(r)
	shape(ci, r, [Vector2(0.08, 0.8), Vector2(0.08, 0.34), Vector2(0.55, 0.34), Vector2(0.6, 0.28), Vector2(0.64, 0.36), Vector2(0.92, 0.34), Vector2(0.92, 0.8)], CONCRETE, LINE, w)
	ci.draw_rect(R(r, 0.3, 0.38, 0.4, 0.07), Color(0.12, 0.18, 0.35))
	label_text(ci, P(r, 0.5, 0.435), "POLICE", int(r.size.y * 0.065), Color(0.92, 0.92, 0.95))
	for i in 5:
		broken_window(ci, R(r, 0.11 + i * 0.165, 0.5, 0.1, 0.1), 0.0)
	ci.draw_rect(R(r, 0.45, 0.62, 0.1, 0.18), Color(0.06, 0.05, 0.05))
	# antenna mast with a bent dish, and the light that still turns
	ci.draw_line(P(r, 0.8, 0.34), P(r, 0.8, 0.08), Color(0.55, 0.55, 0.58), w * 1.2)
	ci.draw_arc(P(r, 0.83, 0.14), r.size.y * 0.05, PI * 0.6, PI * 1.5, 10, Color(0.75, 0.75, 0.78), w * 1.6, true)
	var on := fmod(t, 1.6) < 0.8
	ci.draw_circle(P(r, 0.6, 0.27), r.size.y * 0.025, Color(0.3, 0.45, 1.0) if on else Color(0.9, 0.2, 0.2))
	ci.draw_circle(P(r, 0.6, 0.27), r.size.y * 0.09, Color(0.3, 0.45, 1.0, 0.12) if on else Color(0.9, 0.2, 0.2, 0.1))
	# a burned-out patrol car
	var car := R(r, 0.12, 0.76, 0.3, 0.1)
	ci.draw_rect(car, Color(0.12, 0.11, 0.11))
	fill(ci, r, [Vector2(0.17, 0.76), Vector2(0.21, 0.7), Vector2(0.33, 0.7), Vector2(0.37, 0.76)], Color(0.16, 0.15, 0.15))
	ci.draw_rect(R(r, 0.2, 0.79, 0.14, 0.03), Color(0.75, 0.72, 0.68))
	ci.draw_circle(P(r, 0.17, 0.86), r.size.y * 0.03, Color(0.05, 0.05, 0.05))
	ci.draw_circle(P(r, 0.37, 0.86), r.size.y * 0.03, Color(0.05, 0.05, 0.05))
	rubble(ci, r, 0.96, 0.03, 43)


static func _pic_water_tower(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.7, t, weather)
	ground(ci, r, 0.7)
	var w := lw(r)
	var legs := [[0.36, 0.3], [0.44, 0.33], [0.6, 0.33], [0.68, 0.3]]
	for l in legs:
		ci.draw_line(P(r, float(l[0]), 0.88), P(r, float(l[0]) + (0.04 if float(l[0]) < 0.5 else -0.04), 0.4), Color(0.4, 0.37, 0.34), w * 2.0)
	for i in 3:
		var y := 0.5 + i * 0.12
		ci.draw_line(P(r, 0.37 + (2 - i) * 0.013, y), P(r, 0.67 - (2 - i) * 0.013, y + 0.06), Color(0.35, 0.32, 0.3), w)
		ci.draw_line(P(r, 0.37 + (2 - i) * 0.013, y + 0.06), P(r, 0.67 - (2 - i) * 0.013, y), Color(0.35, 0.32, 0.3), w)
	# the tilted tank
	ci.draw_set_transform(P(r, 0.52, 0.3), -0.12, Vector2.ONE)
	var tw := r.size.x * 0.2
	var th := r.size.y * 0.2
	ci.draw_rect(Rect2(-tw, -th * 0.5, tw * 2.0, th), Color(0.55, 0.53, 0.48))
	ci.draw_colored_polygon(ellipse(Vector2(0, -th * 0.5), tw, th * 0.2, 20), Color(0.48, 0.46, 0.42))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-tw, -th * 0.5), Vector2(0, -th * 1.2), Vector2(tw, -th * 0.5)]), Color(0.42, 0.4, 0.36))
	for i in 3:
		ci.draw_line(Vector2(-tw, -th * 0.2 + i * th * 0.3), Vector2(tw, -th * 0.2 + i * th * 0.3), Color(0.4, 0.38, 0.35), w)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a leak, dripping into a grey puddle
	var src := P(r, 0.66, 0.36)
	ci.draw_colored_polygon(ellipse(P(r, 0.72, 0.9), r.size.x * 0.12, r.size.y * 0.035, 20), Color(0.35, 0.38, 0.36, 0.8))
	for i in 6:
		var k := fposmod(t * 1.2 + i / 6.0, 1.0)
		var p := src.lerp(P(r, 0.72, 0.9), k) + Vector2(sin(k * 3.0) * 4.0, 0)
		ci.draw_circle(p, r.size.y * 0.008 + 1.0, Color(0.55, 0.6, 0.55, 0.85))
	rubble(ci, r, 0.97, 0.03, 47)


static func _pic_radio_station(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.72, t, weather)
	ground(ci, r, 0.72)
	var w := lw(r)
	# the hill
	fill(ci, r, [Vector2(0, 1), Vector2(0, 0.8), Vector2(0.2, 0.66), Vector2(0.45, 0.58), Vector2(0.7, 0.62), Vector2(1, 0.78), Vector2(1, 1)], Color(0.24, 0.19, 0.14))
	# lattice mast
	var top := P(r, 0.5, 0.06)
	var bl := P(r, 0.44, 0.6)
	var br := P(r, 0.56, 0.6)
	ci.draw_line(bl, top, Color(0.68, 0.3, 0.2), w * 1.4)
	ci.draw_line(br, top, Color(0.68, 0.3, 0.2), w * 1.4)
	for i in 9:
		var k0 := i / 9.0
		var k1 := (i + 1) / 9.0
		ci.draw_line(bl.lerp(top, k0), br.lerp(top, k1), Color(0.8, 0.78, 0.74), w * 0.7)
		ci.draw_line(br.lerp(top, k0), bl.lerp(top, k1), Color(0.8, 0.78, 0.74), w * 0.7)
	var blink := 0.5 + 0.5 * sin(t * 3.0)
	ci.draw_circle(top, r.size.y * 0.02, Color(1.0, 0.2, 0.15, 0.5 + 0.5 * blink))
	ci.draw_circle(top, r.size.y * 0.07, Color(1.0, 0.2, 0.15, 0.12 * blink))
	# broadcast rings
	for i in 3:
		var k := fposmod(t * 0.4 + i / 3.0, 1.0)
		ci.draw_arc(top, r.size.y * (0.05 + k * 0.3), -PI * 0.9, -PI * 0.1, 16, Color(1.0, 0.85, 0.6, 0.35 * (1.0 - k)), w, true)
	# the studio hut, the generator and a dish
	shape(ci, r, [Vector2(0.62, 0.7), Vector2(0.62, 0.52), Vector2(0.86, 0.52), Vector2(0.86, 0.7)], CONCRETE, LINE, w)
	ci.draw_rect(R(r, 0.62, 0.52, 0.24, 0.05), Color(0.62, 0.16, 0.12))
	label_text(ci, P(r, 0.74, 0.565), "RADIO", int(r.size.y * 0.05), Color(1.0, 0.9, 0.7))
	broken_window(ci, R(r, 0.66, 0.6, 0.07, 0.06), 0.0)
	ci.draw_rect(R(r, 0.77, 0.6, 0.06, 0.1), Color(0.06, 0.05, 0.05))
	shape(ci, r, [Vector2(0.2, 0.74), Vector2(0.2, 0.66), Vector2(0.34, 0.66), Vector2(0.34, 0.74)], Color(0.3, 0.42, 0.28), LINE, w)
	ci.draw_line(P(r, 0.22, 0.7), P(r, 0.32, 0.7), Color(0.2, 0.25, 0.18), w)
	ci.draw_arc(P(r, 0.92, 0.48), r.size.y * 0.06, PI * 0.5, PI * 1.4, 10, Color(0.8, 0.8, 0.8), w * 1.6, true)
	ci.draw_line(P(r, 0.92, 0.5), P(r, 0.92, 0.68), Color(0.55, 0.55, 0.55), w)


static func _pic_ground_zero(ci: CanvasItem, r: Rect2, t: float, weather: String) -> void:
	sky(ci, r, 0.55, t, weather)
	# what's left of the mushroom cloud, looming
	var cx := 0.5 + sin(t * 0.05) * 0.02
	for i in 9:
		var k := i / 8.0
		ci.draw_circle(P(r, cx + (k - 0.5) * 0.5, 0.13 + sin(k * PI) * -0.04), r.size.y * (0.1 + 0.05 * sin(k * PI)), Color(0.36, 0.24, 0.2, 0.55))
	fill(ci, r, [Vector2(cx - 0.05, 0.55), Vector2(cx - 0.03, 0.18), Vector2(cx + 0.03, 0.18), Vector2(cx + 0.05, 0.55)], Color(0.32, 0.22, 0.18, 0.6))
	ground(ci, r, 0.55, Color(0.17, 0.14, 0.12))
	# the crater, glowing faintly
	var c := P(r, 0.5, 0.74)
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	ci.draw_colored_polygon(ellipse(c, r.size.x * 0.4, r.size.y * 0.16, 32), Color(0.32, 0.25, 0.19))
	ci.draw_colored_polygon(ellipse(c + Vector2(0, r.size.y * 0.01), r.size.x * 0.33, r.size.y * 0.12, 32), Color(0.08, 0.1, 0.07))
	ci.draw_colored_polygon(ellipse(c + Vector2(0, r.size.y * 0.02), r.size.x * 0.2, r.size.y * 0.06, 28), Color(RAD_GREEN.r, RAD_GREEN.g, RAD_GREEN.b, 0.18 + 0.12 * pulse))
	ci.draw_colored_polygon(ellipse(c + Vector2(0, r.size.y * 0.02), r.size.x * 0.09, r.size.y * 0.025, 20), Color(0.8, 1.0, 0.6, 0.3 + 0.2 * pulse))
	# scattered tiles from the board
	for i in 14:
		var a := hash01(i, 51) * TAU
		var d := 0.42 + hash01(i, 52) * 0.25
		var p := c + Vector2(cos(a) * r.size.x * d * 0.95, sin(a) * r.size.y * d * 0.42)
		if p.y < r.position.y + r.size.y * 0.57:
			continue
		chess_tile(ci, p, r.size.y * 0.06, hash01(i, 53) * TAU, i % 2 == 0)
	# a black king, melted to a stub, still standing at the rim
	PieceArt.draw_piece(ci, 6, false, P(r, 0.8, 0.84).x, P(r, 0.8, 0.84).y, r.size.y * 0.28, Color(0.55, 0.45, 0.4))
	# shimmer
	for i in 10:
		var k := fposmod(t * 0.3 + hash01(i, 55), 1.0)
		var p2 := c + Vector2((hash01(i, 56) - 0.5) * r.size.x * 0.5, -k * r.size.y * 0.35)
		ci.draw_circle(p2, 1.5 + r.size.y * 0.006, Color(RAD_GREEN.r, RAD_GREEN.g, RAD_GREEN.b, 0.6 * (1.0 - k)))
	trefoil(ci, P(r, 0.12, 0.85), r.size.y * 0.07)


# --- item icons ------------------------------------------------------------------------

static func _can(ci: CanvasItem, r: Rect2, body: Color, band: Color, w: float) -> void:
	shape(ci, r, [Vector2(0.24, 0.24), Vector2(0.76, 0.24), Vector2(0.76, 0.84), Vector2(0.24, 0.84)], body, LINE, w)
	ci.draw_colored_polygon(ellipse(P(r, 0.5, 0.24), r.size.x * 0.26, r.size.y * 0.07, 18), body.lightened(0.25))
	ci.draw_arc(P(r, 0.5, 0.24), r.size.x * 0.26, 0, TAU, 18, LINE, w * 0.8, true)
	ci.draw_colored_polygon(poly(r, [Vector2(0.24, 0.4), Vector2(0.76, 0.4), Vector2(0.76, 0.7), Vector2(0.24, 0.7)]), band)
	ci.draw_arc(P(r, 0.5, 0.84), r.size.x * 0.26, 0, PI, 12, LINE, w * 0.8, true)


static func _bottle(ci: CanvasItem, r: Rect2, liquid: Color, w: float, murky: bool) -> void:
	var outline := [Vector2(0.42, 0.1), Vector2(0.58, 0.1), Vector2(0.58, 0.22), Vector2(0.7, 0.32), Vector2(0.7, 0.88), Vector2(0.3, 0.88), Vector2(0.3, 0.32), Vector2(0.42, 0.22)]
	fill(ci, r, outline, Color(0.85, 0.92, 0.98, 0.25))
	fill(ci, r, [Vector2(0.31, 0.4), Vector2(0.69, 0.4), Vector2(0.69, 0.87), Vector2(0.31, 0.87)], liquid)
	if murky:
		for i in 6:
			ci.draw_circle(P(r, 0.36 + hash01(i, 61) * 0.28, 0.48 + hash01(i, 62) * 0.35), r.size.x * 0.025, liquid.darkened(0.45))
	else:
		ci.draw_rect(R(r, 0.3, 0.52, 0.4, 0.14), Color(0.25, 0.5, 0.9))
	var p := poly(r, outline)
	p.append(p[0])
	ci.draw_polyline(p, LINE, w, true)
	ci.draw_rect(R(r, 0.41, 0.05, 0.18, 0.07), Color(0.2, 0.45, 0.85) if not murky else Color(0.45, 0.4, 0.3))
	ci.draw_line(P(r, 0.36, 0.36), P(r, 0.36, 0.8), Color(1, 1, 1, 0.45), w)


## Item icon in rect r (square works best).
static func draw_item(ci: CanvasItem, id: String, r: Rect2, t: float = 0.0) -> void:
	var w := maxf(1.2, r.size.x * 0.035)
	match id:
		"food":
			_can(ci, r, Color(0.68, 0.68, 0.7), Color(0.78, 0.45, 0.18), w)
			ci.draw_colored_polygon(ellipse(P(r, 0.62, 0.55), r.size.x * 0.1, r.size.y * 0.08, 12), Color(0.15, 0.1, 0.08, 0.7))
			ci.draw_circle(P(r, 0.4, 0.55), r.size.x * 0.06, Color(0.9, 0.75, 0.5))
		"water":
			_bottle(ci, r, Color(0.45, 0.7, 0.95, 0.65), w, false)
		"dirty_water":
			_bottle(ci, r, Color(0.45, 0.42, 0.25, 0.85), w, true)
		"tablets":
			shape(ci, r, [Vector2(0.18, 0.22), Vector2(0.82, 0.22), Vector2(0.82, 0.78), Vector2(0.18, 0.78)], Color(0.75, 0.78, 0.82), LINE, w)
			for i in 3:
				for j in 2:
					var c := P(r, 0.32 + i * 0.18, 0.37 + j * 0.26)
					ci.draw_circle(c, r.size.x * 0.075, Color(0.97, 0.97, 0.98))
					ci.draw_arc(c, r.size.x * 0.075, 0, TAU, 12, Color(0.5, 0.5, 0.55), w * 0.6, true)
			ci.draw_line(P(r, 0.22, 0.5), P(r, 0.78, 0.5), Color(0.25, 0.55, 0.9), w * 0.8)
		"rad_pills":
			shape(ci, r, [Vector2(0.28, 0.3), Vector2(0.72, 0.3), Vector2(0.72, 0.88), Vector2(0.28, 0.88)], Color(0.9, 0.55, 0.15, 0.95), LINE, w)
			shape(ci, r, [Vector2(0.24, 0.14), Vector2(0.76, 0.14), Vector2(0.76, 0.3), Vector2(0.24, 0.3)], Color(0.95, 0.95, 0.95), LINE, w)
			ci.draw_rect(R(r, 0.28, 0.44, 0.44, 0.32), Color(0.95, 0.93, 0.85))
			trefoil(ci, P(r, 0.5, 0.6), r.size.x * 0.13)
		"bandage":
			ci.draw_colored_polygon(poly(r, [Vector2(0.12, 0.66), Vector2(0.72, 0.38), Vector2(0.8, 0.52), Vector2(0.2, 0.8)]), Color(0.93, 0.88, 0.78))
			ci.draw_circle(P(r, 0.62, 0.36), r.size.x * 0.24, Color(0.95, 0.92, 0.85))
			ci.draw_arc(P(r, 0.62, 0.36), r.size.x * 0.24, 0, TAU, 20, LINE, w, true)
			ci.draw_arc(P(r, 0.62, 0.36), r.size.x * 0.14, 0, TAU, 16, Color(0.7, 0.65, 0.55), w * 0.8, true)
			ci.draw_circle(P(r, 0.62, 0.36), r.size.x * 0.05, Color(0.6, 0.55, 0.45))
			ci.draw_rect(R(r, 0.3, 0.58, 0.08, 0.08), Color(0.85, 0.2, 0.2))
		"first_aid":
			shape(ci, r, [Vector2(0.12, 0.3), Vector2(0.88, 0.3), Vector2(0.88, 0.84), Vector2(0.12, 0.84)], Color(0.95, 0.94, 0.9), LINE, w)
			ci.draw_arc(P(r, 0.5, 0.3), r.size.x * 0.13, PI, TAU, 10, LINE, w * 1.4, true)
			ci.draw_rect(R(r, 0.43, 0.4, 0.14, 0.36), Color(0.85, 0.15, 0.15))
			ci.draw_rect(R(r, 0.32, 0.51, 0.36, 0.14), Color(0.85, 0.15, 0.15))
		"battery":
			shape(ci, r, [Vector2(0.14, 0.32), Vector2(0.86, 0.32), Vector2(0.86, 0.84), Vector2(0.14, 0.84)], Color(0.18, 0.18, 0.2), LINE, w)
			ci.draw_rect(R(r, 0.14, 0.5, 0.72, 0.12), Color(0.95, 0.75, 0.15))
			ci.draw_rect(R(r, 0.22, 0.2, 0.14, 0.12), Color(0.85, 0.2, 0.2))
			ci.draw_rect(R(r, 0.64, 0.2, 0.14, 0.12), Color(0.3, 0.3, 0.32))
			label_text(ci, P(r, 0.5, 0.78), "12V", int(r.size.y * 0.16), Color(0.85, 0.85, 0.85))
		"radio_part":
			shape(ci, r, [Vector2(0.1, 0.5), Vector2(0.9, 0.5), Vector2(0.9, 0.86), Vector2(0.1, 0.86)], Color(0.2, 0.5, 0.28), LINE, w)
			for i in 3:
				ci.draw_rect(R(r, 0.18 + i * 0.24, 0.62, 0.14, 0.1), Color(0.08, 0.08, 0.08))
			ci.draw_line(P(r, 0.14, 0.78), P(r, 0.86, 0.78), Color(0.85, 0.7, 0.3), w * 0.7)
			# a vacuum tube with a warm filament
			fill(ci, r, [Vector2(0.38, 0.5), Vector2(0.38, 0.24), Vector2(0.44, 0.14), Vector2(0.56, 0.14), Vector2(0.62, 0.24), Vector2(0.62, 0.5)], Color(0.8, 0.9, 0.95, 0.35))
			ci.draw_line(P(r, 0.46, 0.44), P(r, 0.5, 0.26), Color(1.0, 0.55, 0.15), w * 0.9)
			ci.draw_line(P(r, 0.5, 0.26), P(r, 0.54, 0.44), Color(1.0, 0.55, 0.15), w * 0.9)
			ci.draw_circle(P(r, 0.5, 0.3), r.size.x * 0.08, Color(1.0, 0.55, 0.2, 0.25 + 0.1 * sin(t * 3.0)))
		"fuel":
			shape(ci, r, [Vector2(0.2, 0.26), Vector2(0.62, 0.26), Vector2(0.8, 0.4), Vector2(0.8, 0.88), Vector2(0.2, 0.88)], Color(0.82, 0.16, 0.12), LINE, w)
			ci.draw_line(P(r, 0.28, 0.42), P(r, 0.72, 0.8), Color(0.6, 0.1, 0.08), w * 1.3)
			ci.draw_line(P(r, 0.72, 0.42), P(r, 0.28, 0.8), Color(0.6, 0.1, 0.08), w * 1.3)
			ci.draw_rect(R(r, 0.26, 0.14, 0.2, 0.12), Color(0.2, 0.2, 0.2))
			ci.draw_line(P(r, 0.66, 0.3), P(r, 0.82, 0.12), Color(0.85, 0.75, 0.2), w * 2.0)
		"flare":
			ci.draw_set_transform(r.get_center(), -0.6, Vector2.ONE)
			var s := r.size.x
			ci.draw_rect(Rect2(-s * 0.08, -s * 0.3, s * 0.16, s * 0.62), Color(0.85, 0.15, 0.12))
			ci.draw_rect(Rect2(-s * 0.08, -s * 0.3, s * 0.16, s * 0.62), LINE, false, w)
			ci.draw_rect(Rect2(-s * 0.09, s * 0.22, s * 0.18, s * 0.1), Color(0.95, 0.85, 0.3))
			ci.draw_rect(Rect2(-s * 0.06, -s * 0.38, s * 0.12, s * 0.08), Color(0.2, 0.2, 0.2))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 4:
				var a := t * 6.0 + i * 1.7
				ci.draw_circle(P(r, 0.32, 0.26) + Vector2(cos(a), sin(a)) * r.size.x * 0.07, r.size.x * 0.025, Color(1.0, 0.8, 0.3, 0.8))
		"paint":
			_can(ci, r, Color(0.7, 0.7, 0.72), Color(1.0, 0.45, 0.1), w)
			ci.draw_arc(P(r, 0.5, 0.2), r.size.x * 0.3, PI * 1.05, PI * 1.95, 12, LINE, w * 1.2, true)
			ci.draw_line(P(r, 0.66, 0.26), P(r, 0.66, 0.46), Color(1.0, 0.45, 0.1), w * 2.0)
			ci.draw_circle(P(r, 0.66, 0.47), w * 1.3, Color(1.0, 0.45, 0.1))
			label_text(ci, P(r, 0.5, 0.63), "SOS", int(r.size.y * 0.18), Color(0.2, 0.1, 0.05))
		"mirror":
			ci.draw_circle(r.get_center(), r.size.x * 0.36, Color(0.5, 0.5, 0.52))
			ci.draw_circle(r.get_center(), r.size.x * 0.3, Color(0.75, 0.85, 0.95))
			ci.draw_circle(r.get_center(), r.size.x * 0.05, Color(0.2, 0.2, 0.22))
			ci.draw_arc(r.get_center(), r.size.x * 0.36, 0, TAU, 24, LINE, w, true)
			var g := P(r, 0.38, 0.38)
			var k := 0.6 + 0.4 * sin(t * 4.0)
			ci.draw_line(g - Vector2(r.size.x * 0.14 * k, 0), g + Vector2(r.size.x * 0.14 * k, 0), Color(1, 1, 1, 0.9), w)
			ci.draw_line(g - Vector2(0, r.size.x * 0.14 * k), g + Vector2(0, r.size.x * 0.14 * k), Color(1, 1, 1, 0.9), w)
		"pawn":
			var pulse := 0.5 + 0.5 * sin(t * 2.5)
			ci.draw_circle(P(r, 0.5, 0.55), r.size.x * 0.42, Color(RAD_GREEN.r, RAD_GREEN.g, RAD_GREEN.b, 0.12 + 0.1 * pulse))
			PieceArt.draw_piece(ci, 1, true, P(r, 0.5, 0.9).x, P(r, 0.5, 0.9).y, r.size.y * 0.82, Color(0.65, 1.0, 0.55), false)
		"beyblade":
			BeybladeArt.draw_top(ci, P(r, 0.5, 0.42), r.size.x * 0.34, t * 1.5, 0.25, true, 0.0)
			for i in 3:
				var x := 0.34 + i * 0.14
				ci.draw_line(P(r, x, 0.5), P(r, x + 0.01, 0.62 + 0.08 * hash01(i, 71)), Color(0.6, 0.62, 0.68), w * 1.6)
				ci.draw_circle(P(r, x + 0.01, 0.63 + 0.08 * hash01(i, 71)), w * 1.1, Color(0.6, 0.62, 0.68))
		"gourd":
			var col := Color(0.92, 0.62, 0.2)
			ci.draw_circle(P(r, 0.5, 0.66), r.size.x * 0.25, col)
			ci.draw_circle(P(r, 0.5, 0.38), r.size.x * 0.15, Color(0.85, 0.8, 0.3))
			for i in 3:
				ci.draw_arc(P(r, 0.5, 0.66), r.size.x * (0.08 + i * 0.07), PI * 1.2, PI * 1.8, 8, col.darkened(0.25), w * 0.7, true)
			ci.draw_line(P(r, 0.5, 0.24), P(r, 0.56, 0.12), Color(0.35, 0.5, 0.2), w * 2.0, true)
			ci.draw_circle(P(r, 0.62, 0.66), r.size.x * 0.05, Color(1, 1, 1, 0.3))


# --- map marker glyphs --------------------------------------------------------------------

## A small glyph for a place, centered at c with radius s.
static func draw_glyph(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, t: float = 0.0) -> void:
	var w := maxf(1.5, s * 0.14)
	match id:
		"shelter":
			var pts := PackedVector2Array([c + Vector2(-s * 0.6, s * 0.55), c + Vector2(-s * 0.6, -s * 0.05), c + Vector2(0, -s * 0.6),
				c + Vector2(s * 0.6, -s * 0.05), c + Vector2(s * 0.6, s * 0.55)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, s * 0.1), Vector2(s * 0.3, s * 0.45)), Color(0.1, 0.07, 0.05))
		"store":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.5), Vector2(s * 0.6, s * 1.05)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.38), Vector2(s * 0.4, s * 0.3)), Color(0.1, 0.07, 0.05))
			ci.draw_line(c + Vector2(s * 0.15, -s * 0.2), c + Vector2(s * 0.5, -s * 0.05), col, w)
			ci.draw_line(c + Vector2(s * 0.5, -s * 0.05), c + Vector2(s * 0.5, s * 0.35), col, w)
		"pharmacy":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.55), Vector2(s * 0.36, s * 1.1)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.18), Vector2(s * 1.1, s * 0.36)), col)
		"hardware":
			ci.draw_line(c + Vector2(-s * 0.4, s * 0.55), c + Vector2(s * 0.2, -s * 0.15), col, w * 1.6)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.05, -s * 0.5), c + Vector2(s * 0.3, -s * 0.6), c + Vector2(s * 0.62, -s * 0.2), c + Vector2(s * 0.42, 0)]), col)
		"school":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, s * 0.35), c + Vector2(-s * 0.32, -s * 0.2), c + Vector2(0, -s * 0.5),
				c + Vector2(s * 0.32, -s * 0.2), c + Vector2(s * 0.45, s * 0.35)]), col)
			ci.draw_circle(c + Vector2(0, s * 0.5), s * 0.14, col)
		"fire_station":
			flame(ci, c + Vector2(0, s * 0.55), s * 1.05, t)
		"police":
			var star := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + TAU * k / 10.0
				var rr := s * (0.62 if k % 2 == 0 else 0.27)
				star.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(star, col)
		"water_tower":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.45, -s * 0.55), Vector2(s * 0.9, s * 0.45)), col)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.1), c + Vector2(-s * 0.4, s * 0.6), col, w)
			ci.draw_line(c + Vector2(s * 0.3, -s * 0.1), c + Vector2(s * 0.4, s * 0.6), col, w)
			ci.draw_line(c + Vector2(-s * 0.35, s * 0.25), c + Vector2(s * 0.35, s * 0.25), col, w * 0.7)
		"radio_station":
			ci.draw_line(c + Vector2(-s * 0.3, s * 0.6), c + Vector2(0, -s * 0.4), col, w)
			ci.draw_line(c + Vector2(s * 0.3, s * 0.6), c + Vector2(0, -s * 0.4), col, w)
			ci.draw_line(c + Vector2(-s * 0.15, s * 0.15), c + Vector2(s * 0.15, s * 0.15), col, w * 0.7)
			for i in 2:
				ci.draw_arc(c + Vector2(0, -s * 0.4), s * (0.3 + i * 0.22), -PI * 0.85, -PI * 0.15, 8, col, w * 0.7, true)
		"ground_zero":
			trefoil(ci, c, s * 0.7, Color(0.08, 0.06, 0.04), col)


# --- the rescue helicopter ------------------------------------------------------------

## Helicopter centred at c, facing left when dir < 0. s ~ fuselage length.
static func draw_helicopter(ci: CanvasItem, c: Vector2, s: float, t: float, dir: float = -1.0, body: Color = Color(0.22, 0.26, 0.2)) -> void:
	var f := 1.0 if dir >= 0.0 else -1.0
	# tail boom and fin
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-f * s * 0.1, -s * 0.08), c + Vector2(-f * s * 0.85, -s * 0.12), c + Vector2(-f * s * 0.85, -s * 0.04), c + Vector2(-f * s * 0.1, s * 0.06)]), body)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-f * s * 0.78, -s * 0.1), c + Vector2(-f * s * 0.9, -s * 0.32), c + Vector2(-f * s * 0.95, -s * 0.3), c + Vector2(-f * s * 0.9, -s * 0.06)]), body)
	# tail rotor blur
	ci.draw_circle(c + Vector2(-f * s * 0.88, -s * 0.12), s * 0.12, Color(0.8, 0.8, 0.8, 0.18))
	var ta := t * 40.0
	ci.draw_line(c + Vector2(-f * s * 0.88, -s * 0.12) + Vector2(cos(ta), sin(ta)) * s * 0.12, c + Vector2(-f * s * 0.88, -s * 0.12) - Vector2(cos(ta), sin(ta)) * s * 0.12, Color(0.1, 0.1, 0.1, 0.6), 2.0)
	# fuselage and cockpit
	ci.draw_colored_polygon(ellipse(c, s * 0.34, s * 0.17, 22), body)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(f * s * 0.08, -s * 0.15), c + Vector2(f * s * 0.3, -s * 0.06), c + Vector2(f * s * 0.32, s * 0.04), c + Vector2(f * s * 0.08, s * 0.02)]), Color(0.55, 0.75, 0.85, 0.85))
	ci.draw_line(c + Vector2(-s * 0.2, s * 0.06), c + Vector2(s * 0.02, s * 0.06), Color(0.9, 0.85, 0.3), 2.0)
	# skids
	ci.draw_line(c + Vector2(-s * 0.3, s * 0.27), c + Vector2(s * 0.3, s * 0.27), Color(0.12, 0.12, 0.12), maxf(2.0, s * 0.03))
	ci.draw_line(c + Vector2(-s * 0.15, s * 0.15), c + Vector2(-s * 0.18, s * 0.27), Color(0.12, 0.12, 0.12), 2.0)
	ci.draw_line(c + Vector2(s * 0.15, s * 0.15), c + Vector2(s * 0.18, s * 0.27), Color(0.12, 0.12, 0.12), 2.0)
	# mast and main rotor, seen edge-on: a blur and two flickering blades
	var hub := c + Vector2(0, -s * 0.22)
	ci.draw_line(c + Vector2(0, -s * 0.15), hub, Color(0.15, 0.15, 0.15), 3.0)
	ci.draw_colored_polygon(ellipse(hub, s * 0.95, s * 0.05, 24), Color(0.75, 0.75, 0.75, 0.16))
	for k in 2:
		var a := t * 25.0 + k * PI
		var len := s * 0.95 * cos(a)
		ci.draw_line(hub, hub + Vector2(len, sin(a) * s * 0.03), Color(0.08, 0.08, 0.08, 0.85), maxf(2.0, s * 0.03))
	# blinking light
	if fmod(t, 1.0) < 0.15:
		ci.draw_circle(c + Vector2(-f * s * 0.85, -s * 0.13), s * 0.04, Color(1.0, 0.25, 0.2))


## A searchlight cone from `from` to a pool of light at `to`.
static func draw_searchlight(ci: CanvasItem, from: Vector2, to: Vector2, spread: float, alpha: float = 1.0) -> void:
	var d := (to - from)
	var n := Vector2(-d.y, d.x).normalized()
	var a := Color(1.0, 0.97, 0.8, 0.35 * alpha)
	var b := Color(1.0, 0.97, 0.8, 0.06 * alpha)
	ci.draw_polygon(PackedVector2Array([from, to + n * spread, to - n * spread]), PackedColorArray([a, b, b]))
	ci.draw_colored_polygon(ellipse(to, spread * 1.05, spread * 0.38, 22), Color(1.0, 0.97, 0.8, 0.22 * alpha))
	ci.draw_colored_polygon(ellipse(to, spread * 0.6, spread * 0.2, 18), Color(1.0, 1.0, 0.9, 0.25 * alpha))
