class_name NukeScene
extends Control
## The hidden bomb goes off. A full-screen wide shot of the town where the match
## was being played: the flash, the fireball, the shockwave flattening the
## streets, the mushroom cloud, and then ash.

signal finished

const BLAST := preload("res://assets/audio/nuke.wav")
const SHOCK_HITS_VIEWER := 3.6
const TEXT_AT := 7.0
const CONTINUE_AT := 10.5
const AUTO_END := 18.0

var town := "Ashenford"
var caption := ""
var t := 0.0
var _done := false
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _buildings: Array = []
var _debris: Array = []
var _ash: Array = []
var _built_for := Vector2.ZERO


## The town is named after the player's time zone ("America/Chicago" ->
## "Chicago"), which the browser exposes without asking for a location.
static func town_name() -> String:
	if OS.has_feature("web"):
		var tz = JavaScriptBridge.eval("Intl.DateTimeFormat().resolvedOptions().timeZone", true)
		if tz is String:
			var parts := String(tz).split("/")
			if parts.size() >= 2 and parts[0] != "Etc":
				return parts[parts.size() - 1].replace("_", " ")
	return "Ashenford"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_player = AudioStreamPlayer.new()
	_player.stream = BLAST
	add_child(_player)
	_player.play()
	_rng.seed = 1945


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if t >= CONTINUE_AT:
			_finish()
		elif t > 2.5 and t < TEXT_AT:
			# impatient: jump to the aftermath
			t = TEXT_AT - 0.5
			for b in _buildings:
				_knock(b, 1.5)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()


func _process(delta: float) -> void:
	t += delta
	if t >= AUTO_END:
		_finish()
	if _built_for != size and size.x > 10.0:
		_build_town()
	var gy := _ground_y()
	var front := _shock_radius()
	for b in _buildings:
		var reached := t > SHOCK_HITS_VIEWER - 0.25 if int(b["row"]) == 2 else absf(float(b["cx"]) - _center().x) < front
		if not b["hit"] and reached:
			_knock(b, 0.0)
		if b["hit"]:
			b["rot"] = move_toward(float(b["rot"]), float(b["rot_to"]), delta * 1.6)
			b["crumble"] = move_toward(float(b["crumble"]), float(b["crumble_to"]), delta * 0.5)
			b["fire"] = minf(1.0, float(b["fire"]) + delta * 0.6)
	for d in _debris:
		d["v"] += Vector2(0, 340.0) * delta
		d["p"] += d["v"] * delta
		d["r"] += float(d["spin"]) * delta
		if d["p"].y > gy + 6.0:
			d["p"].y = gy + 6.0
			d["v"] *= 0.3
	_debris = _debris.filter(func(d): return d["p"].x > -200.0 and d["p"].x < size.x + 200.0)
	if t > 3.0:
		for i in 3:
			_ash.append({"p": Vector2(randf() * size.x, -10.0), "v": Vector2(randf_range(-20, 30), randf_range(25, 60)),
				"s": randf_range(1.0, 2.6), "ember": randf() < 0.25})
	for a in _ash:
		a["p"] += (a["v"] + Vector2(sin(t * 2.0 + a["s"] * 3.0) * 15.0, 0)) * delta
	_ash = _ash.filter(func(a): return a["p"].y < size.y + 10.0)
	queue_redraw()


# --- geometry ---------------------------------------------------------------------

func _u() -> float:
	return minf(size.x, size.y * 1.6) / 1000.0


func _ground_y() -> float:
	return size.y * (0.66 if size.x >= size.y else 0.6)


func _center() -> Vector2:
	return Vector2(size.x * 0.5, _ground_y())


## How tall the cloud grows: tied to the sky on wide screens, to the width on tall ones.
func _cloud_h() -> float:
	return minf(_ground_y() * 0.64, size.x * 0.6)


## Where the hill the viewer stands on begins.
func _hill_y() -> float:
	var gy := _ground_y()
	return gy + maxf(60.0 * _u(), (size.y - gy) * 0.45)


## How far the blast wave has travelled sideways along the ground.
func _shock_radius() -> float:
	return maxf(0.0, t - 0.15) * size.x * 0.17


func _build_town() -> void:
	_built_for = size
	_buildings.clear()
	_debris.clear()
	_rng.seed = 1945
	var u := _u()
	var gy := _ground_y()
	for row in 2:
		var x := -40.0 * u
		while x < size.x + 40.0 * u:
			var w := _rng.randf_range(40.0, 95.0) * u * (0.75 if row == 0 else 1.0)
			var h := _rng.randf_range(30.0, 130.0) * u * (0.6 if row == 0 else 1.0)
			var kind := "block"
			var r := _rng.randf()
			if row == 1:
				if r < 0.35:
					kind = "house"
					h = _rng.randf_range(35.0, 55.0) * u
				elif r < 0.42:
					kind = "spire"
				elif r < 0.48:
					kind = "tower"
			var near_center := absf(x + w * 0.5 - size.x * 0.5) < 70.0 * u
			if near_center and row == 1:
				# the plaza where the chessboard stood stays open
				x += w
				continue
			_buildings.append({"x": x, "w": w, "h": h, "cx": x + w * 0.5, "row": row, "kind": kind,
				"base": gy - (12.0 * u if row == 0 else 0.0), "rot": 0.0, "rot_to": 0.0, "crumble": 1.0, "crumble_to": 1.0,
				"fire": 0.0, "hit": false, "seed": _rng.randi()})
			x += w + _rng.randf_range(2.0, 14.0) * u
	# the near streets, right below the viewer's hill: the wave reaches them last
	var hy := _hill_y()
	var x2 := -30.0 * u
	while x2 < size.x + 30.0 * u:
		var w2 := _rng.randf_range(80.0, 150.0) * u
		var h2 := _rng.randf_range(45.0, 95.0) * u
		_buildings.append({"x": x2, "w": w2, "h": h2, "cx": x2 + w2 * 0.5, "row": 2, "kind": "house" if _rng.randf() < 0.6 else "block",
			"base": hy + 8.0 * u, "rot": 0.0, "rot_to": 0.0, "crumble": 1.0, "crumble_to": 1.0, "fire": 0.0, "hit": false, "seed": _rng.randi()})
		x2 += w2 + _rng.randf_range(10.0, 40.0) * u
	# the strip-mall shop from the board game, just right of the plaza
	_buildings.append({"x": size.x * 0.5 + 95.0 * u, "w": 120.0 * u, "h": 46.0 * u, "cx": size.x * 0.5 + 155.0 * u, "row": 1,
		"kind": "shop", "base": gy, "rot": 0.0, "rot_to": 0.0, "crumble": 1.0, "crumble_to": 1.0, "fire": 0.0, "hit": false, "seed": 7})


func _knock(b: Dictionary, _extra: float) -> void:
	if b["hit"]:
		return
	b["hit"] = true
	var away := signf(float(b["cx"]) - _center().x)
	if away == 0.0:
		away = 1.0
	var d := absf(float(b["cx"]) - _center().x) / maxf(size.x * 0.5, 1.0)
	b["rot_to"] = away * clampf(1.4 - d, 0.25, 1.35) * (0.6 if b["row"] == 0 else 1.0)
	b["crumble_to"] = clampf(0.2 + d * 0.5, 0.2, 0.6)
	var u := _u()
	for i in 7:
		_debris.append({"p": Vector2(float(b["cx"]), float(b["base"]) - float(b["h"]) * randf()),
			"v": Vector2(away * randf_range(120, 420), randf_range(-260, -40)) * u * 1.6,
			"r": randf() * TAU, "spin": randf_range(-8, 8), "s": randf_range(3.0, 9.0) * u})


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	if _buildings.is_empty():
		return
	var shake := 0.0
	if t < 0.6:
		shake = (0.6 - t) * 6.0
	if t > SHOCK_HITS_VIEWER:
		shake += maxf(0.0, 1.0 - (t - SHOCK_HITS_VIEWER) / 1.6) * 22.0
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	draw_set_transform(off, 0.0, Vector2.ONE)
	_draw_sky()
	_draw_cloud_back()
	_draw_buildings(0)
	_draw_base_surge()
	_draw_buildings(1)
	_draw_cloud_front()
	_draw_slope()
	_draw_buildings(2)
	_draw_debris()
	_draw_foreground()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlays()
	_draw_text()


func _sky_colors() -> Array:
	var dusk_top := Color(0.1, 0.12, 0.24)
	var dusk_low := Color(0.78, 0.45, 0.4)
	var hot_top := Color(0.35, 0.12, 0.06)
	var hot_low := Color(1.0, 0.62, 0.25)
	var ash_top := Color(0.1, 0.07, 0.07)
	var ash_low := Color(0.5, 0.27, 0.15)
	if t < 0.2:
		return [dusk_top, dusk_low]
	if t < 3.0:
		var k := clampf((t - 0.2) / 1.0, 0.0, 1.0)
		return [dusk_top.lerp(hot_top, k), dusk_low.lerp(hot_low, k)]
	var k2 := clampf((t - 3.0) / 5.0, 0.0, 1.0)
	return [hot_top.lerp(ash_top, k2), hot_low.lerp(ash_low, k2)]


func _draw_sky() -> void:
	var cols := _sky_colors()
	var top: Color = cols[0]
	var low: Color = cols[1]
	var gy := _ground_y()
	draw_polygon(PackedVector2Array([Vector2(-40, -40), Vector2(size.x + 40, -40), Vector2(size.x + 40, gy), Vector2(-40, gy)]),
		PackedColorArray([top, top, low, low]))
	# stars fade as the sky burns
	if t < 1.5:
		for i in 30:
			var p := Vector2(fmod(i * 131.7, size.x), fmod(i * 47.3, gy * 0.6))
			draw_circle(p, 1.2, Color(1, 1, 1, 0.5 * (1.0 - t / 1.5)))
	# distant hills
	var u := _u()
	var hills := PackedVector2Array()
	hills.append(Vector2(-40, gy))
	for i in 25:
		var x := -40.0 + i * (size.x + 80.0) / 24.0
		hills.append(Vector2(x, gy - 40.0 * u - sin(i * 1.7) * 18.0 * u - sin(i * 0.6) * 22.0 * u))
	hills.append(Vector2(size.x + 40, gy))
	draw_colored_polygon(hills, low.darkened(0.55))
	draw_rect(Rect2(Vector2(-40, gy), Vector2(size.x + 80, size.y - gy + 40)), low.darkened(0.75))


func _fireball() -> Dictionary:
	var u := _u()
	var gy := _ground_y()
	var ch := _cloud_h()
	var rise := ch * (1.0 - exp(-t * 0.45))
	var r := ch * 0.32 * (1.0 - exp(-t * 5.0)) + ch * 0.035 * minf(t, 9.0)
	return {"c": Vector2(size.x * 0.5, gy - 30.0 * u - rise), "r": r}


## How far the cloud has cooled from incandescent to smoke, 0..1.
func _age() -> float:
	return clampf((t - 0.4) / 5.0, 0.0, 1.0)


func _smoke(age: float, glow: float) -> Color:
	var hot := Color(1.0, 0.62, 0.2)
	var warm := Color(0.72, 0.3, 0.14)
	var cold := Color(0.33, 0.26, 0.23)
	var base := hot.lerp(warm, clampf(age * 2.0, 0.0, 1.0)) if age < 0.5 else warm.lerp(cold, (age - 0.5) * 2.0)
	return base.lerp(Color(1.0, 0.5, 0.15), clampf(glow, 0.0, 1.0))


## One puff of the cloud: a shadow, the body and a lit top-left edge.
func _billow(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p + Vector2(r * 0.12, r * 0.14), r, col.darkened(0.3))
	draw_circle(p, r * 0.94, col)
	draw_circle(p + Vector2(-r * 0.22, -r * 0.24), r * 0.55, col.lightened(0.12))


func _draw_cloud_back() -> void:
	if t < 0.12:
		return
	var fb := _fireball()
	var c: Vector2 = fb["c"]
	var r: float = fb["r"]
	var u := _u()
	var gy := _ground_y()
	var age := _age()
	# the glow on the ground where the town's heart was
	var gk := clampf(1.0 - t / 9.0, 0.25, 1.0)
	_ellipse_fill(Vector2(size.x * 0.5, gy), 120.0 * u, 18.0 * u, Color(1.0, 0.55, 0.2, 0.55 * gk))
	# the stem rising into the cap
	if t > 0.8:
		var grow := clampf((t - 0.8) / 1.2, 0.0, 1.0)
		var top_y := c.y + r * 0.35
		var bot_y := gy - 4.0 * u
		var top_w := r * 0.32
		var bot_w := (30.0 + 18.0 * grow) * u
		var stem := PackedVector2Array([Vector2(c.x - top_w, top_y), Vector2(c.x + top_w, top_y),
			Vector2(c.x + bot_w, bot_y), Vector2(c.x - bot_w, bot_y)])
		var top_col := _smoke(age, 0.0)
		var bot_col := _smoke(age * 0.6, 0.6 * (1.0 - age))
		draw_polygon(stem, PackedColorArray([top_col, top_col, bot_col, bot_col]))
		var n := 10
		for i in n:
			var k := 0.1 + 0.85 * fmod(float(i) / n + t * 0.1, 1.0)
			var y := lerpf(bot_y, top_y, k)
			var w := lerpf(bot_w, top_w, k)
			_billow(Vector2(c.x + sin(k * 11.0 + i) * w * 0.25, y), w * 0.7 * grow, _smoke(age, (1.0 - k) * 0.5 * (1.0 - age)))
	_draw_cap(c, r, true)


func _draw_cap(c: Vector2, r: float, back: bool) -> void:
	var age := _age()
	if t < 1.6:
		# the fireball, swelling and rising, then rolling over into the cap
		var fade := clampf((1.6 - t) / 0.5, 0.0, 1.0)
		if back and fade > 0.0:
			draw_circle(c, r * 1.5, Color(1.0, 0.7, 0.3, 0.22 * fade))
			draw_circle(c, r, Color(1.0, 0.55, 0.15, fade))
			draw_circle(c + Vector2(-r * 0.15, -r * 0.15), r * 0.72, Color(1.0, 0.85, 0.45, fade))
			draw_circle(c + Vector2(-r * 0.2, -r * 0.2), r * 0.4, Color(1.0, 1.0, 0.9, fade))
		if t < 1.0:
			return
	var form := clampf((t - 1.0) / 0.8, 0.0, 1.0)
	var spread := clampf((t - 1.0) / 3.5, 0.0, 1.0)
	var rx := r * (1.05 + spread * 0.6)
	var ry := r * (0.62 - spread * 0.12)
	var roll := t * 0.55
	var n := 30
	if back:
		_ellipse_fill(c, rx * 0.95, ry * 0.9, _smoke(age, 0.0).darkened(0.15))
	for i in n:
		var a := TAU * i / n + roll
		var lower := sin(a) > 0.0
		if lower == back:
			continue
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		var br := r * (0.36 + 0.07 * sin(a * 3.0 + t * 0.7)) * form
		_billow(p, br, _smoke(age, (0.55 if lower else 0.0) * (1.0 - age) + (0.15 if lower else 0.0)))
	if not back:
		# the domed top and the glowing, churning underside
		for k in 5:
			var p2 := c + Vector2((k - 2) * rx * 0.32, -ry * (0.55 + 0.12 * sin(k * 2.0 + t)))
			_billow(p2, r * 0.42 * form, _smoke(age, 0.0))
		_ellipse_fill(c + Vector2(0, ry * 0.55), rx * 0.6, ry * 0.3, Color(1.0, 0.5, 0.15, 0.5 * (1.0 - age) + 0.12))
		# a condensation ring around the stem
		if t > 1.4 and t < 4.0:
			var k3 := (t - 1.4) / 2.6
			var ring_c := Vector2(c.x, lerpf(c.y + r * 1.1, c.y + r * 1.8, k3))
			var rr := r * (0.7 + k3 * 1.3)
			_ellipse_ring(ring_c, rr, rr * 0.2, Color(1, 1, 1, 0.5 * (1.0 - k3)), maxf(2.0, r * 0.1))


func _draw_cloud_front() -> void:
	if t < 1.0:
		return
	var fb := _fireball()
	_draw_cap(fb["c"], fb["r"], false)


func _ellipse_fill(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _ellipse_ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)


func _draw_base_surge() -> void:
	if t < 0.3:
		return
	var u := _u()
	var gy := _ground_y()
	var rx := _shock_radius() * 0.75
	var dust := Color(0.45, 0.32, 0.25, clampf(0.75 - (t - 0.3) * 0.05, 0.25, 0.75))
	var n := 18
	for i in n:
		var k := float(i) / (n - 1)
		var x := size.x * 0.5 + (k * 2.0 - 1.0) * rx
		var h := 26.0 * u * (1.0 - absf(k * 2.0 - 1.0) * 0.6) * (1.0 + 0.3 * sin(t * 2.0 + i))
		draw_circle(Vector2(x, gy - h * 0.3), h, dust)
	# the shockwave front itself, a pale shimmering wall racing outward
	var front := _shock_radius()
	if front < size.x:
		for side in [-1.0, 1.0]:
			var x2: float = size.x * 0.5 + side * front
			draw_rect(Rect2(Vector2(x2 - 3.0 * u, gy - 140.0 * u), Vector2(6.0 * u, 140.0 * u)), Color(1, 0.95, 0.85, 0.18))


func _draw_buildings(row: int) -> void:
	var u := _u()
	var cols := _sky_colors()
	var low: Color = cols[1]
	var body: Color = [Color(0.13, 0.13, 0.19), Color(0.09, 0.08, 0.12), Color(0.06, 0.05, 0.08)][row]
	# the flash lights up the faces turned toward it
	var lit := clampf(1.0 - absf(t - 0.6) / 2.5, 0.0, 1.0)
	for b in _buildings:
		if int(b["row"]) != row:
			continue
		var w: float = b["w"]
		var h: float = float(b["h"]) * float(b["crumble"])
		var base: float = b["base"]
		var x: float = b["x"]
		var away := signf(float(b["cx"]) - size.x * 0.5)
		var pivot := Vector2(x + (w if away > 0.0 else 0.0), base)
		var dist := absf(float(b["cx"]) - size.x * 0.5) / (size.x * 0.5)
		var col := body.lerp(low, 0.25 * (1.0 - dist) * lit)
		draw_set_transform(pivot, float(b["rot"]) * 0.6, Vector2.ONE)
		var lx := x - pivot.x
		match String(b["kind"]):
			"house":
				draw_rect(Rect2(Vector2(lx, -h), Vector2(w, h)), col)
				if not b["hit"]:
					draw_colored_polygon(PackedVector2Array([Vector2(lx - 4.0 * u, -h), Vector2(lx + w * 0.5, -h - 26.0 * u), Vector2(lx + w + 4.0 * u, -h)]), col.darkened(0.2))
			"spire":
				draw_rect(Rect2(Vector2(lx + w * 0.2, -h), Vector2(w * 0.6, h)), col)
				if not b["hit"]:
					draw_colored_polygon(PackedVector2Array([Vector2(lx + w * 0.2, -h), Vector2(lx + w * 0.5, -h - 90.0 * u), Vector2(lx + w * 0.8, -h)]), col)
					draw_rect(Rect2(Vector2(lx + w * 0.48, -h - 108.0 * u), Vector2(2.0 * u + 1.0, 18.0 * u)), col)
			"tower":
				for leg in [0.2, 0.8]:
					draw_line(Vector2(lx + w * leg, 0), Vector2(lx + w * 0.5 + (leg - 0.5) * w * 0.4, -h * 0.75), col, 3.0 * u + 1.0)
				draw_rect(Rect2(Vector2(lx + w * 0.15, -h - 10.0 * u), Vector2(w * 0.7, h * 0.3 + 10.0 * u)), col)
			"shop":
				draw_rect(Rect2(Vector2(lx, -h), Vector2(w, h)), col)
				if not b["hit"] or t < 2.0:
					var sign_r := Rect2(Vector2(lx + w * 0.08, -h - 18.0 * u), Vector2(w * 0.84, 16.0 * u))
					draw_rect(sign_r, Color(0.9, 0.55, 0.2) if t < 0.2 else Color(0.3, 0.15, 0.1))
					var fs := int(maxf(8.0, 11.0 * u))
					draw_string(ThemeDB.fallback_font, sign_r.position + Vector2(4.0 * u, 12.5 * u), "GAMBIT GOODS & GAS", HORIZONTAL_ALIGNMENT_CENTER, sign_r.size.x - 8.0 * u, fs, Color(0.15, 0.08, 0.05))
			_:
				draw_rect(Rect2(Vector2(lx, -h), Vector2(w, h)), col)
		# windows: lit before, dark after (or burning)
		var wr := RandomNumberGenerator.new()
		wr.seed = int(b["seed"])
		var cols_n := maxi(1, int(w / (14.0 * u)))
		var rows_n := maxi(1, int(h / (16.0 * u)))
		for wy in rows_n:
			for wx in cols_n:
				if wr.randf() < 0.45:
					continue
				var win := Rect2(Vector2(lx + 5.0 * u + wx * 14.0 * u, -h + 6.0 * u + wy * 16.0 * u), Vector2(6.0 * u, 7.0 * u))
				if win.end.x > lx + w - 2.0 or win.end.y > -2.0:
					continue
				var wc := Color(1.0, 0.85, 0.45, 0.85) if not b["hit"] else Color(1.0, 0.45, 0.1, 0.8 * float(b["fire"]) * (0.6 + 0.4 * sin(t * 9.0 + wx + wy)))
				draw_rect(win, wc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# flames on the rubble
		if b["hit"] and float(b["fire"]) > 0.05:
			var f: float = b["fire"]
			for k in 3:
				var fx := x + w * (0.2 + 0.3 * k)
				var fh := (10.0 + 14.0 * sin(t * 7.0 + k + float(b["cx"]))) * u * f
				draw_colored_polygon(PackedVector2Array([Vector2(fx - 6.0 * u, base), Vector2(fx, base - 12.0 * u - fh), Vector2(fx + 6.0 * u, base)]),
					Color(1.0, 0.5 + 0.2 * sin(t * 11.0 + k), 0.1, 0.8 * f))


## The ground between the town and the viewer's hill, scorched after the wave.
func _draw_slope() -> void:
	var gy := _ground_y()
	var hy := _hill_y()
	var cols := _sky_colors()
	var low: Color = cols[1]
	draw_polygon(PackedVector2Array([Vector2(-40, gy), Vector2(size.x + 40, gy), Vector2(size.x + 40, hy + 60.0 * _u()), Vector2(-40, hy + 60.0 * _u())]),
		PackedColorArray([low.darkened(0.7), low.darkened(0.7), low.darkened(0.85), low.darkened(0.85)]))


func _draw_debris() -> void:
	for d in _debris:
		var s: float = d["s"]
		draw_set_transform(d["p"], d["r"], Vector2.ONE)
		draw_rect(Rect2(Vector2(-s, -s * 0.5), Vector2(s * 2.0, s)), Color(0.12, 0.1, 0.1))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The hill the viewer stands on, with a fence and a tree that take the wave last.
func _draw_foreground() -> void:
	var u := _u()
	var hit := t > SHOCK_HITS_VIEWER
	var bend := clampf((t - SHOCK_HITS_VIEWER) * 1.5, 0.0, 1.0) * 0.5 if hit else 0.0
	var hy := _hill_y()
	var hill := PackedVector2Array([Vector2(-40, size.y + 40), Vector2(-40, hy + 20.0 * u), Vector2(size.x * 0.3, hy + 40.0 * u),
		Vector2(size.x * 0.65, hy + 26.0 * u), Vector2(size.x + 40, hy + 50.0 * u), Vector2(size.x + 40, size.y + 40)])
	draw_colored_polygon(hill, Color(0.05, 0.04, 0.05))
	var tree := Vector2(size.x * 0.12, hy + 30.0 * u)
	draw_set_transform(tree, bend, Vector2.ONE)
	draw_line(Vector2.ZERO, Vector2(0, -120.0 * u), Color(0.04, 0.03, 0.04), 8.0 * u + 1.0)
	if not hit or t < SHOCK_HITS_VIEWER + 0.4:
		for k in 5:
			draw_circle(Vector2(sin(k * 2.1) * 30.0 * u, -110.0 * u - k * 12.0 * u), 26.0 * u, Color(0.04, 0.03, 0.04))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 9:
		var fx := size.x * 0.55 + k * 30.0 * u
		var fy := hy + 30.0 * u + k * 2.0 * u
		var lean := bend * 1.4 if k % 2 == 0 else bend
		draw_line(Vector2(fx, fy), Vector2(fx + sin(lean) * 30.0 * u, fy - cos(lean) * 30.0 * u), Color(0.04, 0.03, 0.04), 3.0 * u + 1.0)


func _draw_overlays() -> void:
	# the flash
	if t < 1.4:
		var a := 1.0 if t < 0.15 else clampf(1.0 - (t - 0.15) / 1.25, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.98, 0.9, a))
	# the wave reaching us: a wall of dust
	if t > SHOCK_HITS_VIEWER:
		var k := clampf(1.0 - (t - SHOCK_HITS_VIEWER) / 2.2, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.38, 0.28, 0.75 * k))
	# ash and embers
	for a2 in _ash:
		var c := Color(0.75, 0.72, 0.7, 0.8) if not a2["ember"] else Color(1.0, 0.5, 0.15, 0.6 + 0.4 * sin(t * 8.0 + a2["s"]))
		draw_circle(a2["p"], a2["s"], c)
	# a creeping vignette as the light dies
	if t > 5.0:
		var k2 := clampf((t - 5.0) / 3.0, 0.0, 1.0)
		for i in 6:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.06 * k2), false, minf(size.x, size.y) * 0.08 * (i + 1))


func _draw_text() -> void:
	if t < TEXT_AT:
		return
	var font := ThemeDB.fallback_font
	var u := clampf(minf(size.x, size.y) / 600.0, 0.7, 1.6)
	var cy := size.y * 0.22
	var k1 := clampf((t - TEXT_AT) / 0.8, 0.0, 1.0)
	var name := town.to_upper()
	var fs := int(46.0 * u)
	var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > size.x * 0.9:
		fs = int(fs * size.x * 0.9 / tw)
		tw = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2((size.x - tw) * 0.5, cy)
	var band_h := 190.0 * u
	var bk := clampf((t - TEXT_AT) / 1.0, 0.0, 1.0) * 0.55
	draw_rect(Rect2(Vector2(0, cy - fs * 1.3), Vector2(size.x, fs * 1.3 + band_h)), Color(0.02, 0.01, 0.01, bk))
	draw_string_outline(font, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, 0.8 * k1))
	draw_string(font, p, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, k1))
	var k2 := clampf((t - TEXT_AT - 0.8) / 0.5, 0.0, 1.0)
	if k2 > 0.0:
		var y := cy - fs * 0.33
		draw_line(Vector2(p.x - 10, y), Vector2(p.x - 10 + (tw + 20) * k2, y + 4), UI.RED, maxf(3.0, fs * 0.08))
	var k3 := clampf((t - TEXT_AT - 1.4) / 0.8, 0.0, 1.0)
	if k3 > 0.0:
		_center_text("is gone.", cy + 48.0 * u, int(30 * u), Color(0.95, 0.9, 0.85, k3))
	var k4 := clampf((t - TEXT_AT - 2.2) / 0.8, 0.0, 1.0)
	if k4 > 0.0:
		_center_text("The board, the shop, the graveyard. All of it.", cy + 88.0 * u, int(18 * u), Color(0.85, 0.8, 0.75, k4))
		_center_text("Only you are left.", cy + 114.0 * u, int(18 * u), Color(0.85, 0.8, 0.75, k4))
		if caption != "":
			_center_text(caption, cy + 144.0 * u, int(15 * u), Color(0.7, 0.62, 0.55, k4))
	if t >= CONTINUE_AT:
		var blink := 0.55 + 0.45 * sin(t * 3.0)
		_center_text("Tap to crawl out of the basement", size.y - 40.0 * u, int(18 * u), Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, blink))


func _center_text(s: String, y: float, fs: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := (size.x - minf(w, size.x - 24.0)) * 0.5
	draw_string_outline(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, fs, 6, Color(0, 0, 0, 0.75 * c.a))
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, fs, c)
