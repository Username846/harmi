class_name RaceView
extends Control
## The drag strip at night, seen from the side. The world is drawn in a
## simple perspective: depth d scales everything (1 = near lane, smaller =
## further back) and sets the ground line between the horizon and the near
## lane. The camera follows both cars and zooms out when they spread apart.

const D_SKY_FAR := 0.16
const D_SKY_NEAR := 0.3
const D_CROWD := 0.6
const D_FENCE := 0.64
const D_LAMPS := 0.67
const D_ROAD_FAR := 0.70
const D_FOE := 0.80
const D_TREE := 0.9
const D_HERO := 1.0
const D_ROAD_NEAR := 1.08
const D_BARRIER := 1.13
const LAMP_GAP := 30.0

var sim: RaceSim
var hero_type := 2
var foe_type := 4
var hero_white := true
var foe_white := false
var hero_label := "You"
var foe_label := "Rival"

var cam_x := -2.5
var zoom := 1.0
var shake := 0.0
var show_tree := false
var banner := ""
var banner_sub := ""
var banner_col := UI.GOLD
var banner_t := 0.0

var smoke: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var flame := PackedFloat32Array([0.0, 0.0])
var lean := PackedFloat32Array([0.0, 0.0])
var lean_v := PackedFloat32Array([0.0, 0.0])
var pitch := PackedFloat32Array([0.0, 0.0])
var tire_smoke := PackedFloat32Array([0.0, 0.0])
var _streak_acc := 0.0
var _t := 0.0
var _off := Vector2.ZERO


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# --- projection ----------------------------------------------------------------

func base_ppm() -> float:
	return minf(size.x / 12.5, size.y / 10.5)


func ppm() -> float:
	return base_ppm() * zoom


func horizon() -> float:
	return size.y * 0.3


func gy(d: float) -> float:
	var hz := horizon()
	return hz + d * (size.y * 0.84 - hz) + _off.y


func sx(wx: float, d: float) -> float:
	return size.x * 0.5 + (wx - cam_x) * ppm() * d + _off.x


func at(wx: float, d: float, h: float = 0.0) -> Vector2:
	return Vector2(sx(wx, d), gy(d) - h * ppm() * d)


## World x range visible at depth d (with a margin in metres).
func _span(d: float, margin: float = 4.0) -> Vector2:
	var half := size.x * 0.5 / (ppm() * d)
	return Vector2(cam_x - half - margin, cam_x + half + margin)


static func _hash(i: int, salt: int) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _car_of(i: int) -> RaceSim.Car:
	return sim.hero if i == 0 else sim.foe


func _type_of(i: int) -> int:
	return hero_type if i == 0 else foe_type


func _lane(i: int) -> float:
	return D_HERO if i == 0 else D_FOE


# --- effects API (called by RaceScreen) -----------------------------------------

func float_text(who: int, text: String, col: Color, big: bool = false) -> void:
	floaters.append({"who": who, "text": text, "c": col, "t": 0.0, "big": big})


func on_launch(who: int) -> void:
	tire_smoke[who] = 0.9


func on_shift(who: int, quality: String) -> void:
	flame[who] = 1.0 if quality == "perfect" else 0.55
	if quality == "late" or quality == "redline":
		_puff(who, 6, Color(0.12, 0.11, 0.12, 0.7))


func on_stall(who: int) -> void:
	_puff(who, 10, Color(0.08, 0.075, 0.08, 0.8))


func on_nos(_who: int) -> void:
	shake = 1.0


func set_banner(text: String, sub: String, col: Color) -> void:
	if banner != text:
		banner_t = 0.0
	banner = text
	banner_sub = sub
	banner_col = col


func _puff(who: int, n: int, col: Color) -> void:
	var c := _car_of(who)
	var sp := RaceArt.spec(_type_of(who))
	var pipe: Array = sp["pipe"]
	var wx := c.pos - float(sp["len"]) + float(pipe[0])
	for k in n:
		smoke.append({"x": wx + randf_range(-0.3, 0.2), "d": _lane(who) + randf_range(-0.01, 0.02), "h": float(pipe[1]) + randf_range(0.0, 0.3),
			"vx": randf_range(-1.5, 0.5), "vh": randf_range(0.4, 1.2), "r": randf_range(0.2, 0.35), "g": 0.9,
			"t": 0.0, "life": randf_range(0.9, 1.6), "c": col})


# --- update ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	banner_t += delta
	if sim == null:
		return
	_update_camera(delta)
	for i in 2:
		_update_car_fx(i, delta)
	_update_particles(delta)
	shake = maxf(0.0, shake - delta * 1.6)
	if sim.hero.nos_left > 0.0:
		shake = maxf(shake, 0.45)
	_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake * 6.0
	for f in floaters:
		f["t"] = float(f["t"]) + delta
	floaters = floaters.filter(func(f: Dictionary) -> bool: return float(f["t"]) < 1.5)
	queue_redraw()


func _update_camera(delta: float) -> void:
	var hc := sim.hero.pos - RaceArt.car_length(hero_type) * 0.5
	var fc := sim.foe.pos - RaceArt.car_length(foe_type) * 0.5
	var target := (hc + fc) * 0.5 + maxf(sim.hero.speed, sim.foe.speed) * 0.05
	if not sim.hero.launched and not sim.foe.launched:
		target = -2.5
	# the player's car always stays in frame; a runaway rival gets an edge marker
	var half := size.x * 0.5 / ppm()
	target = clampf(target, hc - half * 0.55, hc + half * 0.55)
	cam_x = lerpf(cam_x, target, 1.0 - exp(-delta * 4.0))
	var need := absf(hc - fc) + 12.0
	var zt := clampf((size.x * 0.92 / base_ppm()) / need, 0.45, 1.0)
	zoom = lerpf(zoom, zt, 1.0 - exp(-delta * 2.5))


func _update_car_fx(i: int, delta: float) -> void:
	var c := _car_of(i)
	var target := clampf(-c.accel * 0.012, -0.24, 0.16)
	lean_v[i] += ((target - lean[i]) * 70.0 - lean_v[i] * 6.0) * delta
	lean[i] += lean_v[i] * delta
	pitch[i] = lerpf(pitch[i], clampf(-c.accel * 0.0035, -0.045, 0.03), 1.0 - exp(-delta * 6.0))
	flame[i] = maxf(0.0, flame[i] - delta * 3.0)
	var sp := RaceArt.spec(_type_of(i))
	var wheels: Array = sp["wheels"]
	var rear: Array = wheels[0]
	if tire_smoke[i] > 0.0:
		tire_smoke[i] -= delta
		var wx := c.pos - float(sp["len"]) + float(rear[0])
		for k in 3:
			smoke.append({"x": wx + randf_range(-0.4, 0.3), "d": _lane(i) + randf_range(-0.02, 0.03), "h": 0.25,
				"vx": randf_range(-2.5, 1.0), "vh": randf_range(0.2, 0.9), "r": randf_range(0.3, 0.55), "g": 1.3,
				"t": 0.0, "life": randf_range(1.3, 2.2), "c": Color(0.78, 0.76, 0.74, 0.42)})
	elif not c.launched and not c.stalled and sim.tree_on and randf() < delta * 6.0:
		_puff(i, 1, Color(0.5, 0.5, 0.52, 0.25))


func _update_particles(delta: float) -> void:
	for p in smoke:
		p["t"] = float(p["t"]) + delta
		p["x"] = float(p["x"]) + float(p["vx"]) * delta
		p["h"] = float(p["h"]) + float(p["vh"]) * delta
		p["r"] = float(p["r"]) + float(p["g"]) * delta
	smoke = smoke.filter(func(p: Dictionary) -> bool: return float(p["t"]) < float(p["life"]))
	if smoke.size() > 260:
		smoke = smoke.slice(smoke.size() - 260)
	var v := sim.hero.speed
	if v > 16.0:
		_streak_acc += delta * (v - 16.0) * 1.6
	while _streak_acc >= 1.0:
		_streak_acc -= 1.0
		streaks.append({"x": size.x + randf() * 60.0, "y": randf_range(horizon() * 0.5, size.y * 0.97),
			"len": randf_range(40.0, 170.0), "v": v * ppm() * randf_range(1.3, 2.2), "a": randf_range(0.06, 0.2) * clampf((v - 16.0) / 25.0, 0.2, 1.0)})
	for s in streaks:
		s["x"] = float(s["x"]) - float(s["v"]) * delta
	streaks = streaks.filter(func(s: Dictionary) -> bool: return float(s["x"]) + float(s["len"]) > 0.0)


# --- drawing ----------------------------------------------------------------------

func _draw() -> void:
	if sim == null or size.x < 10.0:
		return
	_draw_sky()
	_draw_skyline(D_SKY_FAR, 16.0, 22.0, 70.0, Color(0.045, 0.04, 0.06), 0.12)
	_draw_skyline(D_SKY_NEAR, 11.0, 10.0, 34.0, Color(0.065, 0.055, 0.075), 0.22)
	draw_rect(Rect2(0, gy(D_SKY_NEAR), size.x, size.y), Color(0.05, 0.043, 0.055))
	_draw_crowd()
	_draw_fence()
	_draw_lamps(false)
	_draw_signs()
	_draw_road()
	_draw_lamps(true)
	_draw_car(1)
	_draw_smoke(0.0, D_TREE)
	_draw_world_tree()
	_draw_car(0)
	_draw_smoke(D_TREE, 9.0)
	_draw_barrier()
	for s in streaks:
		var y: float = s["y"]
		var x: float = s["x"]
		draw_line(Vector2(x, y), Vector2(x + float(s["len"]), y), Color(1, 0.95, 0.85, float(s["a"])), 1.5)
	_draw_hud()
	draw_rect(Rect2(Vector2.ZERO, size), UI.BORDER, false, 2.0)


func _draw_sky() -> void:
	var hz := horizon()
	var top := Color(0.025, 0.025, 0.06)
	var low := Color(0.2, 0.09, 0.08)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, hz + size.y * 0.1), Vector2(0, hz + size.y * 0.1)]),
		PackedColorArray([top, top, low, low]))
	for i in 70:
		var p := Vector2(_hash(i, 1) * size.x, _hash(i, 2) * hz * 1.1)
		var a := 0.25 + 0.5 * _hash(i, 3) * (0.6 + 0.4 * sin(_t * (1.0 + _hash(i, 4) * 3.0) + i))
		draw_circle(p, 0.8 + _hash(i, 5) * 0.9, Color(1, 0.96, 0.9, a))
	var mc := Vector2(size.x * 0.84, size.y * 0.11)
	var mr := size.y * 0.045
	for k in 4:
		draw_circle(mc, mr * (1.6 + k * 0.7), Color(0.9, 0.85, 0.7, 0.035))
	draw_circle(mc, mr, Color(0.93, 0.9, 0.8))
	draw_circle(mc + Vector2(mr * 0.35, -mr * 0.15), mr * 0.85, Color(0.9, 0.86, 0.74))
	draw_circle(mc + Vector2(-mr * 0.3, mr * 0.2), mr * 0.18, Color(0.8, 0.76, 0.66))


func _draw_skyline(d: float, gap: float, hmin: float, hmax: float, col: Color, lit: float) -> void:
	var span := _span(d, gap)
	var p := ppm() * d
	var base := gy(d)
	var salt := int(d * 100.0)
	var win_px := 0.9 * p
	for i in range(int(floor(span.x / gap)), int(ceil(span.y / gap)) + 1):
		var bw := gap * (0.55 + 0.42 * _hash(i, salt + 1))
		var bh := hmin + (hmax - hmin) * _hash(i, salt + 2)
		var x0 := sx(i * gap, d)
		var top := base - bh * p
		draw_rect(Rect2(x0, top, bw * p, base - top + 2.0), col)
		if _hash(i, salt + 3) < 0.3:
			draw_rect(Rect2(x0 + bw * p * 0.4, top - 3.0 * p, 0.25 * p, 3.0 * p), col)
			draw_circle(Vector2(x0 + bw * p * 0.4 + 0.12 * p, top - 3.0 * p), maxf(1.5, 0.25 * p), Color(1, 0.2, 0.15, 0.5 + 0.5 * sin(_t * 3.0 + i)))
		if win_px < 1.6:
			continue
		var cols := int(bw / 2.6)
		var rows := int((bh - 2.0) / 3.4)
		for r in rows:
			for c in cols:
				var hsh := _hash(i * 977 + r * 31 + c, salt + 4)
				if hsh < lit:
					var wc := Color(1.0, 0.78, 0.42, 0.35 + hsh * 2.0) if hsh > lit * 0.2 else Color(0.6, 0.75, 1.0, 0.45)
					draw_rect(Rect2(x0 + (0.9 + c * 2.6) * p, top + (1.6 + r * 3.4) * p, win_px, 1.3 * p), wc)


func _draw_crowd() -> void:
	var d := D_CROWD
	var span := _span(d, 2.0)
	var p := ppm() * d
	var base := gy(d)
	var gap := 0.8
	for i in range(int(floor(span.x / gap)), int(ceil(span.y / gap)) + 1):
		var x := i * gap
		var dense := (x > -35.0 and x < 40.0) or (x > 360.0 and x < 445.0)
		if _hash(i, 11) > (0.95 if dense else 0.3):
			continue
		var hh := 1.5 + 0.4 * _hash(i, 12)
		var px := sx(x + _hash(i, 13) * 0.4, d)
		var col := Color(0.035, 0.03, 0.045).lerp(Color(0.12, 0.08, 0.09), _hash(i, 14))
		var sw := 0.24 * p
		var top := base - (hh - 0.28) * p
		draw_rect(Rect2(px - sw, top + 0.08 * p, sw * 2.0, base - top), col)
		draw_circle(Vector2(px, top + 0.06 * p), sw * 0.95, col)
		draw_circle(Vector2(px, base - hh * p + 0.1 * p), 0.13 * p, col)
		# cheer when a car is close
		var near := minf(absf(sim.hero.pos - x), absf(sim.foe.pos - x)) < 14.0 and (sim.hero.launched or sim.foe.launched)
		if near or _hash(i, 15) < 0.12:
			var wav := sin(_t * 10.0 + i) * 0.12
			var sh := Vector2(px, top + 0.1 * p)
			draw_line(sh + Vector2(-sw * 0.8, 0), sh + Vector2(-sw * 1.6, -0.55 * p) + Vector2(wav * p, 0), col, maxf(1.5, 0.09 * p))
			draw_line(sh + Vector2(sw * 0.8, 0), sh + Vector2(sw * 1.6, -0.55 * p) - Vector2(wav * p, 0), col, maxf(1.5, 0.09 * p))
			if _hash(i, 16) < 0.25:
				var hp := sh + Vector2(sw * 1.6, -0.6 * p)
				var flash := _hash(i + int(_t * 4.0) * 17, 17) < 0.15
				draw_rect(Rect2(hp - Vector2(0.06, 0.1) * p, Vector2(0.12, 0.2) * p), Color(0.75, 0.85, 1.0, 0.95 if flash else 0.55))
				if flash:
					draw_circle(hp, 0.5 * p, Color(1, 1, 1, 0.2))


func _draw_fence() -> void:
	var d := D_FENCE
	var p := ppm() * d
	var base := gy(d)
	var top := base - 0.85 * p
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, base), Vector2(0, base)]),
		PackedColorArray([Color(0.3, 0.29, 0.31), Color(0.3, 0.29, 0.31), Color(0.16, 0.15, 0.17), Color(0.16, 0.15, 0.17)]))
	var span := _span(d, 3.0)
	for i in range(int(floor(span.x / 3.0)), int(ceil(span.y / 3.0)) + 1):
		var x := i * 3.0
		var a := sx(x, d)
		draw_line(Vector2(a, top), Vector2(a, base), Color(0, 0, 0, 0.5), 1.5)
		if (x >= -12.0 and x < 12.0) or (x >= 390.0 and x < 414.0):
			if i % 2 == 0:
				draw_rect(Rect2(a + 1.0, top + 0.2 * p, 3.0 * p - 2.0, 0.3 * p), UI.RED.darkened(0.2))
			else:
				draw_rect(Rect2(a + 1.0, top + 0.2 * p, 3.0 * p - 2.0, 0.3 * p), Color(0.85, 0.82, 0.75))
	draw_line(Vector2(0, top), Vector2(size.x, top), Color(0.5, 0.48, 0.5), 1.5)


func _draw_lamps(pools: bool) -> void:
	var d := D_LAMPS
	var p := ppm() * d
	var span := _span(d, 14.0)
	for i in range(int(floor((span.x + 15.0) / LAMP_GAP)), int(ceil((span.y + 15.0) / LAMP_GAP)) + 1):
		var x := i * LAMP_GAP - 15.0
		var head := at(x + 1.4, d, 7.4)
		if pools:
			# light pool on the asphalt and a faint cone of light
			var cc := Color(1.0, 0.78, 0.48, 0.16)
			var ce := Color(1.0, 0.78, 0.48, 0.0)
			var ctr := at(x + 1.4, 0.89)
			var prev := Vector2.ZERO
			for k in 17:
				var a := TAU * k / 16.0
				var dd := 0.89 + 0.19 * sin(a)
				var q := at(x + 1.4 + cos(a) * 8.0, dd)
				if k > 0:
					draw_polygon(PackedVector2Array([ctr, prev, q]), PackedColorArray([cc, ce, ce]))
				prev = q
			var l := at(x + 1.4 - 5.0, 1.06)
			var r := at(x + 1.4 + 5.0, 1.06)
			draw_polygon(PackedVector2Array([head + Vector2(-0.3 * p, 0), head + Vector2(0.3 * p, 0), r, l]),
				PackedColorArray([Color(1, 0.8, 0.5, 0.07), Color(1, 0.8, 0.5, 0.07), Color(1, 0.8, 0.5, 0.0), Color(1, 0.8, 0.5, 0.0)]))
			continue
		var foot := at(x, d)
		var pole := Color(0.13, 0.12, 0.14)
		draw_line(foot, at(x, d, 7.0), pole, maxf(2.0, 0.16 * p))
		var arc := PackedVector2Array()
		for k in 7:
			var u := k / 6.0
			arc.append(at(x + u * 1.4, d, 7.0 + sin(u * PI) * 0.6))
		draw_polyline(arc, pole, maxf(2.0, 0.12 * p), true)
		draw_rect(Rect2(head - Vector2(0.45, 0.12) * p, Vector2(0.9, 0.24) * p), pole)
		for k in 4:
			draw_circle(head + Vector2(0, 0.15 * p), (0.6 + k * 0.7) * p, Color(1, 0.8, 0.5, 0.06))
		draw_circle(head + Vector2(0, 0.12 * p), 0.22 * p, Color(1, 0.92, 0.72))


func _sign(x0: float, x1: float, h0: float, h1: float, text: String, col: Color, checker: bool) -> void:
	var d := D_LAMPS
	var p := ppm() * d
	var a := at(x0, d, h1)
	var b := at(x1, d, h0)
	var r := Rect2(a, b - a)
	var post := Color(0.12, 0.11, 0.13)
	draw_line(at(x0 + 0.2, d), at(x0 + 0.2, d, h0), post, maxf(2.0, 0.14 * p))
	draw_line(at(x1 - 0.2, d), at(x1 - 0.2, d, h0), post, maxf(2.0, 0.14 * p))
	draw_rect(r.grow(0.08 * p), Color(0.02, 0.02, 0.03))
	draw_rect(r, Color(0.1, 0.09, 0.11))
	if checker:
		var n := int((x1 - x0) / 0.35)
		var cw := r.size.x / n
		for k in n:
			for row in 2:
				if (k + row) % 2 == 0:
					draw_rect(Rect2(r.position.x + k * cw, r.position.y + row * cw, cw, cw), Color(0.9, 0.9, 0.88))
					draw_rect(Rect2(r.position.x + k * cw, r.end.y - (row + 1) * cw, cw, cw), Color(0.9, 0.9, 0.88))
	draw_rect(r, col, false, maxf(1.0, 0.06 * p))
	var fs := int(clampf((h1 - h0) * 0.45 * p, 8.0, 64.0))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(r.position.x, r.get_center().y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)


func _draw_signs() -> void:
	var span := _span(D_LAMPS, 8.0)
	if span.x < 4.0 and span.y > -4.0:
		_sign(-3.4, 3.4, 4.0, 5.6, "START", UI.GOLD, false)
	for m in [100, 200, 300]:
		var mx := float(m)
		if span.x < mx + 2.0 and span.y > mx - 2.0:
			_sign(mx - 1.6, mx + 1.6, 2.6, 3.9, "%d m" % m, UI.TEXT, false)
	if span.x < RaceSim.TRACK + 5.0 and span.y > RaceSim.TRACK - 5.0:
		_sign(RaceSim.TRACK - 4.0, RaceSim.TRACK + 4.0, 4.4, 6.6, "FINISH", UI.GOLD, true)


func _road_quad(x0: float, x1: float, d0: float, d1: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at(x0, d0), at(x1, d0), at(x1, d1), at(x0, d1)]), col)


func _draw_road() -> void:
	var y0 := gy(D_ROAD_FAR)
	var y1 := gy(D_ROAD_NEAR)
	var asphalt := Color(0.085, 0.078, 0.092)
	draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
		PackedColorArray([asphalt.darkened(0.25), asphalt.darkened(0.25), asphalt, asphalt]))
	# rubber laid down at the launch
	for d in [D_FOE, D_HERO]:
		var lane: float = d
		var a := at(-2.0, lane - 0.012)
		var b := at(80.0, lane - 0.012)
		var c := at(80.0, lane + 0.012)
		var e := at(-2.0, lane + 0.012)
		var dark := Color(0.02, 0.018, 0.02, 0.6)
		draw_polygon(PackedVector2Array([a, b, c, e]), PackedColorArray([dark, Color(dark, 0.0), Color(dark, 0.0), dark]))
	var span := _span(D_ROAD_FAR, 6.0)
	var line_col := Color(0.82, 0.78, 0.62, 0.55)
	draw_line(Vector2(0, gy(0.715)), Vector2(size.x, gy(0.715)), line_col, 2.0)
	draw_line(Vector2(0, gy(1.065)), Vector2(size.x, gy(1.065)), line_col, 2.5)
	# dashed centre line
	var yc := gy(D_TREE)
	for k in range(int(floor(span.x / 6.0)), int(ceil(span.y / 6.0)) + 1):
		var x := k * 6.0
		draw_line(Vector2(sx(x, D_TREE), yc), Vector2(sx(x + 3.0, D_TREE), yc), Color(0.9, 0.75, 0.3, 0.6), 2.5)
	# distance ticks every 10 m along both edges
	for k in range(int(floor(span.x / 10.0)), int(ceil(span.y / 10.0)) + 1):
		var x2 := k * 10.0
		if x2 < 0.0 or x2 > RaceSim.TRACK:
			continue
		var big := int(x2) % 50 == 0
		draw_line(at(x2, D_ROAD_FAR), at(x2, D_ROAD_FAR + (0.05 if big else 0.025)), line_col, 2.0)
		draw_line(at(x2, D_ROAD_NEAR - (0.04 if big else 0.02)), at(x2, D_ROAD_NEAR), line_col, 2.0)
	# start line and checkered finish
	_road_quad(-0.2, 0.2, D_ROAD_FAR, D_ROAD_NEAR, Color(0.92, 0.9, 0.85, 0.85))
	var f := RaceSim.TRACK
	var rows := 8
	for row in rows:
		var da := lerpf(D_ROAD_FAR, D_ROAD_NEAR, float(row) / rows)
		var db := lerpf(D_ROAD_FAR, D_ROAD_NEAR, float(row + 1) / rows)
		for col in 3:
			var c2 := Color(0.92, 0.92, 0.9) if (row + col) % 2 == 0 else Color(0.05, 0.05, 0.06)
			_road_quad(f + col * 0.45, f + (col + 1) * 0.45, da, db, c2)


func _draw_world_tree() -> void:
	var x := 0.6
	var span := _span(D_TREE, 3.0)
	if x < span.x or x > span.y:
		return
	var p := ppm() * D_TREE
	var foot := at(x, D_TREE)
	var k := 0.75 * p / 74.0
	var box_top := at(x, D_TREE, 4.3)
	draw_line(foot, box_top, Color(0.18, 0.17, 0.2), maxf(2.0, 0.12 * p))
	var lights := sim.ambers()
	RaceArt.draw_tree(self, box_top, k, lights, sim.is_green(), sim.foe.false_start and sim.foe.stalled or (sim.foe.false_start and not sim.is_green()),
		sim.hero.false_start, false)


func _draw_car(i: int) -> void:
	var c := _car_of(i)
	var t := _type_of(i)
	var d := _lane(i)
	var s := ppm() * d
	var l := RaceArt.car_length(t)
	var o := at(c.pos - l, d)
	if not c.launched and not c.stalled:
		o.y += sin(_t * 46.0 + i * 1.7) * 0.6
	RaceArt.draw_car(self, t, hero_white if i == 0 else foe_white, o, s, {
		"pitch": pitch[i], "spin": c.pos, "lean": lean[i], "flame": flame[i],
		"nos": c.nos_left > 0.0, "brake": c.done(), "lights": true})


func _draw_smoke(d0: float, d1: float) -> void:
	var p0 := ppm()
	for sm in smoke:
		var d: float = sm["d"]
		if d < d0 or d >= d1:
			continue
		var k := float(sm["t"]) / float(sm["life"])
		var col: Color = sm["c"]
		col.a *= (1.0 - k) * minf(1.0, k * 8.0 + 0.3)
		draw_circle(at(float(sm["x"]), d, float(sm["h"])), float(sm["r"]) * p0 * d, col)


func _draw_barrier() -> void:
	var d := D_BARRIER
	var p := ppm() * d
	var base := gy(d)
	var top := base - 0.5 * p
	draw_rect(Rect2(0, base, size.x, size.y - base), Color(0.035, 0.03, 0.04))
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, base), Vector2(0, base)]),
		PackedColorArray([Color(0.26, 0.25, 0.27), Color(0.26, 0.25, 0.27), Color(0.12, 0.11, 0.13), Color(0.12, 0.11, 0.13)]))
	var span := _span(d, 4.0)
	for i in range(int(floor(span.x / 4.0)), int(ceil(span.y / 4.0)) + 1):
		var a := sx(i * 4.0, d)
		draw_line(Vector2(a, top), Vector2(a, base), Color(0, 0, 0, 0.55), 2.0)
	draw_line(Vector2(0, top), Vector2(size.x, top), Color(0.45, 0.43, 0.45), 2.0)


# --- HUD ---------------------------------------------------------------------------

func _draw_hud() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	# progress strip
	var bar := Rect2(12, 10, w - 24, 24)
	draw_rect(bar, Color(0.03, 0.025, 0.035, 0.82))
	draw_rect(bar, Color(UI.BORDER, 0.9), false, 1.5)
	var x0 := bar.position.x + 14.0
	var x1 := bar.end.x - 14.0
	var cy := bar.get_center().y
	draw_line(Vector2(x0, cy), Vector2(x1, cy), Color(0.4, 0.36, 0.33), 2.0)
	for m in [0.0, 100.0, 200.0, 300.0]:
		var tx := lerpf(x0, x1, float(m) / RaceSim.TRACK)
		draw_line(Vector2(tx, cy - 5), Vector2(tx, cy + 5), Color(0.55, 0.5, 0.45), 1.5)
	for k in 4:
		var cx := x1 - 6.0 + (k % 2) * 6.0
		draw_rect(Rect2(cx, bar.position.y + 3.0 + (k / 2) * 9.0, 6.0, 9.0), Color(0.9, 0.9, 0.88) if k % 3 == 0 else Color(0.1, 0.1, 0.1))
	for i in [1, 0]:
		var c := _car_of(i)
		var px := lerpf(x0, x1, clampf(c.pos / RaceSim.TRACK, 0.0, 1.0))
		var col := UI.GOLD if i == 0 else UI.EMBER
		draw_circle(Vector2(px, cy), 7.0, Color(0, 0, 0, 0.8))
		draw_circle(Vector2(px, cy), 5.5, col)
	# legend + clock
	var fs := 15
	var ly := bar.end.y + 18.0
	draw_circle(Vector2(18, ly - 5), 5.0, UI.GOLD)
	draw_string_outline(font, Vector2(28, ly), hero_label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(28, ly), hero_label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fs, UI.TEXT)
	draw_circle(Vector2(18, ly + 13), 5.0, UI.EMBER)
	draw_string_outline(font, Vector2(28, ly + 18), foe_label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(28, ly + 18), foe_label, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fs, UI.TEXT)
	var rt := maxf(0.0, sim.race_time()) if sim.tree_on else 0.0
	if sim.hero.done():
		rt = sim.hero.finish
	var clock := "%.2f s" % rt
	var cfs := 26
	draw_string_outline(font, Vector2(w - 172, ly + 12), clock, HORIZONTAL_ALIGNMENT_RIGHT, 160, cfs, 6, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(w - 172, ly + 12), clock, HORIZONTAL_ALIGNMENT_RIGHT, 160, cfs, UI.GOLD if sim.hero.done() else UI.TEXT)
	# off-screen markers
	for i in 2:
		_offscreen_marker(i, font)
	# floating text above the cars
	for f in floaters:
		var who: int = f["who"]
		var c2 := _car_of(who)
		var t := _type_of(who)
		var d := _lane(who)
		var ft: float = f["t"]
		var big: bool = f["big"]
		var fsz := 28 if big else 19
		var p := at(c2.pos - RaceArt.car_length(t) * 0.5, d, RaceArt.top_height(t) + 0.35)
		p.y -= ft * 30.0
		p.x = clampf(p.x, 90.0, w - 90.0)
		var a := 1.0 - clampf((ft - 1.0) / 0.5, 0.0, 1.0)
		var col: Color = f["c"]
		col.a = a
		var text: String = f["text"]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		draw_string_outline(font, p - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 6, Color(0, 0, 0, a * 0.9))
		draw_string(font, p - Vector2(tw * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
	# the christmas tree, big, while staging
	if show_tree:
		var k := clampf(size.y / 560.0, 0.62, 1.1)
		RaceArt.draw_tree(self, Vector2(w * 0.5, 44.0), k, sim.ambers(), sim.is_green(),
			sim.foe.false_start and (sim.foe.stalled or sim.foe.launched), sim.hero.false_start)
	if banner != "":
		_draw_banner(font)


func _offscreen_marker(i: int, font: Font) -> void:
	var c := _car_of(i)
	var t := _type_of(i)
	var d := _lane(i)
	var front := sx(c.pos, d)
	var rear := sx(c.pos - RaceArt.car_length(t), d)
	var y := gy(d) - 0.8 * ppm() * d
	var gap := c.pos - (sim.foe.pos if i == 0 else sim.hero.pos)
	var col := UI.GOLD if i == 0 else UI.EMBER
	var txt := "%+.1f m" % gap
	if rear > size.x - 4.0:
		var tip := Vector2(size.x - 8.0, y)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-16, -11), tip + Vector2(-16, 11)]), col)
		draw_string_outline(font, tip + Vector2(-120, 5), txt, HORIZONTAL_ALIGNMENT_RIGHT, 98, 16, 4, Color(0, 0, 0, 0.8))
		draw_string(font, tip + Vector2(-120, 5), txt, HORIZONTAL_ALIGNMENT_RIGHT, 98, 16, col)
	elif front < 4.0:
		var tip2 := Vector2(8.0, y)
		draw_colored_polygon(PackedVector2Array([tip2, tip2 + Vector2(16, 11), tip2 + Vector2(16, -11)]), col)
		draw_string_outline(font, tip2 + Vector2(22, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, 98, 16, 4, Color(0, 0, 0, 0.8))
		draw_string(font, tip2 + Vector2(22, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, 98, 16, col)


func _draw_banner(font: Font) -> void:
	var w := size.x
	var k := clampf(banner_t / 0.3, 0.0, 1.0)
	var bh := 104.0 if banner_sub != "" else 74.0
	var y := size.y * 0.36
	var band := Rect2(0, y - bh * 0.5 * k, w, bh * k)
	draw_rect(band, Color(0.02, 0.015, 0.025, 0.82))
	draw_line(band.position, Vector2(w, band.position.y), banner_col, 2.0)
	draw_line(Vector2(0, band.end.y), band.end, banner_col, 2.0)
	if k < 1.0:
		return
	var fs := int(clampf(w / 11.0, 30.0, 52.0))
	var ty := y + (fs * 0.35 if banner_sub == "" else -4.0)
	draw_string_outline(font, Vector2(0, ty), banner, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 8, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(0, ty), banner, HORIZONTAL_ALIGNMENT_CENTER, w, fs, banner_col)
	if banner_sub != "":
		draw_string(font, Vector2(0, ty + 36.0), banner_sub, HORIZONTAL_ALIGNMENT_CENTER, w, 22, UI.TEXT)
