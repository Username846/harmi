class_name SurvivalMap
extends Control
## The ruined town in three-quarter view under a scorched sky: broken roads,
## burnt-out blocks, the crater where the chessboard was, and a tappable
## marker for every place. A framed picture of the selected place sits in
## the top-left corner. Also plays the night fade and the rescue helicopter.

signal picked(id: String)

const HORIZON := 0.2
const TITLE_H := 26.0
const GLYPH_COL := {
	"shelter": Color(0.95, 0.75, 0.35), "store": Color(0.95, 0.5, 0.25), "pharmacy": Color(0.4, 0.9, 0.45),
	"hardware": Color(0.95, 0.65, 0.2), "school": Color(0.85, 0.55, 0.4), "fire_station": Color(1.0, 0.5, 0.2),
	"police": Color(0.45, 0.6, 1.0), "water_tower": Color(0.6, 0.75, 0.85), "radio_station": Color(0.95, 0.35, 0.3),
	"ground_zero": Color(0.98, 0.85, 0.25)}
const ROADS := [
	[Vector2(0.0, 0.63), Vector2(0.4, 0.61), Vector2(1.0, 0.64)],
	[Vector2(0.0, 0.91), Vector2(0.5, 0.92), Vector2(1.0, 0.9)],
	[Vector2(0.0, 0.4), Vector2(0.55, 0.38), Vector2(1.0, 0.4)],
	[Vector2(0.21, 0.22), Vector2(0.22, 0.6), Vector2(0.2, 1.0)],
	[Vector2(0.43, 0.22), Vector2(0.44, 1.0)],
	[Vector2(0.7, 0.4), Vector2(0.72, 1.0)],
	[Vector2(0.72, 0.4), Vector2(0.8, 0.3), Vector2(0.86, 0.25)],
]

var sim: SurvivalSim
var selected := "shelter"
var hover := ""
var show_inset := true
var night_k := 0.0
var night_text := ""
var dead_k := 0.0
var heli_t := -1.0 ## rescue helicopter animation time (-1 = none)
var _t := 0.0
var _ash: Array = []
var _blocks: Array = []
var _tiles: Array = []
var _skyline: Array = []
var _floaters: Array = []
var _flash_id := ""
var _flash_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 90:
		_ash.append({"x": rng.randf(), "y": rng.randf(), "vx": rng.randf_range(0.004, 0.02), "vy": rng.randf_range(0.012, 0.035),
			"s": rng.randf_range(1.2, 2.8), "a": rng.randf_range(0.25, 0.7), "ph": rng.randf() * TAU})
	# burnt-out blocks, kept clear of the markers and the crater
	var gz: Vector2 = SurvivalSim.LOCS["ground_zero"]["pos"]
	var tries := 0
	while _blocks.size() < 46 and tries < 800:
		tries += 1
		var p := Vector2(rng.randf_range(0.02, 0.98), rng.randf_range(HORIZON + 0.05, 0.98))
		var ok := true
		for id in SurvivalSim.LOC_ORDER:
			var lp: Vector2 = SurvivalSim.LOCS[id]["pos"]
			if absf(lp.x - p.x) < 0.075 and p.y - lp.y < 0.13 and p.y - lp.y > -0.06:
				ok = false
				break
		if ((p - gz) * Vector2(1.0, 1.5)).length() < 0.2:
			ok = false
		for road in ROADS:
			for k in range(road.size() - 1):
				var a: Vector2 = road[k]
				var b: Vector2 = road[k + 1]
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.03:
					ok = false
		if not ok:
			continue
		_blocks.append({"p": p, "w": rng.randf_range(0.03, 0.06), "d": rng.randf_range(0.02, 0.04), "h": rng.randf_range(0.02, 0.07),
			"broken": rng.randf() < 0.6, "seed": rng.randi_range(0, 999), "shade": rng.randf_range(-0.04, 0.05)})
	_blocks.sort_custom(func(a, b): return float(a["p"].y) < float(b["p"].y))
	for i in 26:
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.15, 2.1)
		_tiles.append({"a": a, "d": d, "rot": rng.randf() * TAU, "light": i % 2 == 0, "s": rng.randf_range(0.7, 1.15)})
	var x := 0.0
	while x < 1.0:
		var w := rng.randf_range(0.025, 0.07)
		_skyline.append({"x": x, "w": w, "h": rng.randf_range(0.02, 0.09), "cut": rng.randf_range(-0.03, 0.03)})
		x += w + rng.randf_range(0.0, 0.02)


func _process(delta: float) -> void:
	_t += delta
	for a in _ash:
		a["x"] = fposmod(float(a["x"]) + float(a["vx"]) * delta + sin(_t * 0.8 + float(a["ph"])) * 0.0006, 1.0)
		a["y"] = fposmod(float(a["y"]) + float(a["vy"]) * delta, 1.0)
	for f in _floaters:
		f["age"] = float(f["age"]) + delta
	_floaters = _floaters.filter(func(f): return float(f["age"]) < 2.0)
	if _flash_t > 0.0:
		_flash_t -= delta
	if heli_t >= 0.0:
		heli_t += delta
	queue_redraw()


# --- geometry ---------------------------------------------------------------------------

func N(p: Vector2) -> Vector2:
	return p * size


func marker_radius() -> float:
	return clampf(minf(size.x, size.y) * 0.034, 15.0, 23.0)


func loc_pos(id: String) -> Vector2:
	return N(SurvivalSim.LOCS[id]["pos"])


func inset_rect() -> Rect2:
	## the picture area of the inset (the frame and title bar sit around it)
	var w := clampf(size.x * 0.34, 150.0, 250.0)
	var h := w * 0.6
	var max_h := size.y * 0.42 - TITLE_H - 16.0
	if h > max_h:
		h = maxf(70.0, max_h)
		w = h / 0.6
	return Rect2(Vector2(14, 14 + TITLE_H), Vector2(w, h))


func _inset_full() -> Rect2:
	var r := inset_rect()
	return Rect2(r.position - Vector2(0, TITLE_H), r.size + Vector2(0, TITLE_H)).grow(6)


func hit(p: Vector2) -> String:
	if show_inset and _inset_full().has_point(p):
		return ""
	var best := ""
	var best_d := marker_radius() * 1.9
	for id in SurvivalSim.LOC_ORDER:
		var c := loc_pos(id)
		var d := c.distance_to(p)
		# the name label under the marker counts too
		if absf(p.x - c.x) < 60.0 and p.y > c.y and p.y < c.y + marker_radius() * 2.4:
			d = minf(d, marker_radius() * 1.2)
		if d < best_d:
			best_d = d
			best = id
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = hit(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := hit(event.position)
		if id != "":
			_flash_id = id
			_flash_t = 0.35
			picked.emit(id)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = ""


func float_text(id: String, text: String, col: Color) -> void:
	_floaters.append({"id": id, "text": text, "col": col, "age": 0.0})


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if sim == null:
		return
	var full := Rect2(Vector2.ZERO, size)
	var weather := sim.weather
	SurvivalArt.sky(self, full, HORIZON, _t, weather)
	_draw_cloud()
	_draw_skyline()
	_draw_hill()
	SurvivalArt.ground(self, Rect2(0, 0, size.x, size.y), HORIZON, Color(0.22, 0.165, 0.13))
	_draw_ground_texture()
	_draw_roads()
	_draw_crater()
	_draw_blocks()
	_draw_route()
	_draw_markers()
	_draw_floaters()
	_draw_ash()
	_draw_time_tint()
	if heli_t >= 0.0:
		draw_rect(full, Color(0.02, 0.02, 0.06, 0.5 * clampf(heli_t / 0.8, 0.0, 1.0)))
		_draw_heli()
	elif show_inset:
		_draw_inset()
	if night_k > 0.001:
		draw_rect(full, Color(0.015, 0.015, 0.05, 0.9 * night_k))
		if night_text != "" and night_k > 0.3:
			var font := ThemeDB.fallback_font
			var fs := int(clampf(size.y * 0.09, 28.0, 56.0))
			var tw := font.get_string_size(night_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var a := clampf((night_k - 0.3) / 0.5, 0.0, 1.0)
			draw_string(font, Vector2((size.x - tw) * 0.5, size.y * 0.5), night_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.75, 0.95, a))
			for i in 30:
				var sp := Vector2(SurvivalArt.hash01(i, 81) * size.x, SurvivalArt.hash01(i, 82) * size.y * 0.4)
				draw_circle(sp, 1.2, Color(1, 1, 1, a * (0.3 + 0.5 * SurvivalArt.hash01(i, 83))))
	if dead_k > 0.001:
		draw_rect(full, Color(0.25, 0.02, 0.02, 0.55 * dead_k))
		draw_rect(full, Color(0, 0, 0, 0.35 * dead_k))
	# frame
	draw_rect(full, Color(0.42, 0.33, 0.24), false, 2.0)


func _draw_cloud() -> void:
	# the remains of the mushroom cloud over ground zero, sheared east by the wind
	var gz: Vector2 = SurvivalSim.LOCS["ground_zero"]["pos"]
	var cx := gz.x * size.x
	var base_y := HORIZON * size.y
	var s := minf(size.x, size.y)
	var cap_h := clampf(base_y * 0.42, 16.0, s * 0.11)
	var cap_y := maxf(base_y * 0.08, 6.0) + cap_h * 0.5
	var cap_w := s * 0.42
	var lean := s * 0.05 + sin(_t * 0.05) * s * 0.01
	# glow on the horizon where the town used to be
	draw_colored_polygon(SurvivalArt.ellipse(Vector2(cx, base_y), s * 0.22, s * 0.05, 24), Color(1.0, 0.45, 0.15, 0.16))
	# the stem, flaring into the cap
	var top := Vector2(cx + lean * 0.6, cap_y + cap_h * 0.35)
	var stem := PackedVector2Array([Vector2(cx - s * 0.05, base_y + 2), Vector2(cx - s * 0.022, lerpf(base_y, top.y, 0.55)), top + Vector2(-s * 0.05, 0),
		top + Vector2(s * 0.06, 0), Vector2(cx + s * 0.032, lerpf(base_y, top.y, 0.55)), Vector2(cx + s * 0.07, base_y + 2)])
	draw_polygon(stem, PackedColorArray([Color(0.82, 0.4, 0.16, 0.8), Color(0.5, 0.3, 0.22, 0.8), Color(0.42, 0.26, 0.21, 0.85),
		Color(0.42, 0.26, 0.21, 0.85), Color(0.5, 0.3, 0.22, 0.8), Color(0.82, 0.4, 0.16, 0.8)]))
	# the cap: a lumpy dome with a lit underside, its downwind edge torn into wisps
	var cc := Vector2(cx + lean, cap_y)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 40
	for i in n:
		var a := TAU * i / n
		var bump := 1.0 + 0.09 * sin(a * 7.0 + _t * 0.15) + 0.05 * sin(a * 13.0 - _t * 0.1)
		var ry := cap_h * (0.62 if sin(a) < 0.0 else 0.38)
		var stretch := 1.0 + 0.25 * maxf(0.0, cos(a))
		pts.append(cc + Vector2(cos(a) * cap_w * 0.5 * bump * stretch, sin(a) * ry * bump))
		var under := clampf(sin(a) * 1.4, 0.0, 1.0)
		cols.append(Color(0.34, 0.22, 0.2, 0.92).lerp(Color(0.88, 0.45, 0.2, 0.9), under))
	draw_polygon(pts, cols)
	for i in 4:
		var k := i / 3.0
		draw_circle(cc + Vector2(-cap_w * 0.22 + k * cap_w * 0.42, -cap_h * 0.12), cap_h * 0.2, Color(0.42, 0.29, 0.25, 0.5))
	for i in 5:
		var k := fposmod(_t * 0.02 + i * 0.2, 1.0)
		var p := cc + Vector2(cap_w * (0.55 + k * 0.5), cap_h * (-0.1 + 0.15 * sin(i * 2.0)))
		draw_circle(p, cap_h * (0.22 - k * 0.12), Color(0.36, 0.24, 0.21, 0.6 * (1.0 - k)))


func _draw_skyline() -> void:
	var hy := HORIZON * size.y
	for b in _skyline:
		var x0: float = float(b["x"]) * size.x
		var w: float = float(b["w"]) * size.x
		var h: float = float(b["h"]) * size.y
		var cut: float = float(b["cut"]) * size.y
		draw_colored_polygon(PackedVector2Array([Vector2(x0, hy + 1), Vector2(x0, hy - h), Vector2(x0 + w * 0.5, hy - h - cut), Vector2(x0 + w, hy - h + cut * 0.5), Vector2(x0 + w, hy + 1)]),
			Color(0.1, 0.07, 0.065))


func _draw_hill() -> void:
	var hy := HORIZON * size.y
	var pts := PackedVector2Array([Vector2(size.x * 0.68, hy + 2), Vector2(size.x * 0.78, hy - size.y * 0.045), Vector2(size.x * 0.88, hy - size.y * 0.07),
		Vector2(size.x * 0.96, hy - size.y * 0.05), Vector2(size.x, hy - size.y * 0.03), Vector2(size.x, hy + 2)])
	draw_colored_polygon(pts, Color(0.17, 0.12, 0.1))
	# the transmitter mast on top
	var foot := Vector2(size.x * 0.88, hy - size.y * 0.068)
	var top := Vector2(size.x * 0.88, hy - size.y * 0.19)
	var hw := size.x * 0.008
	draw_line(foot + Vector2(-hw, 0), top, Color(0.45, 0.2, 0.15), 1.5)
	draw_line(foot + Vector2(hw, 0), top, Color(0.45, 0.2, 0.15), 1.5)
	for i in 6:
		var k0 := i / 6.0
		var k1 := (i + 1) / 6.0
		draw_line((foot + Vector2(-hw, 0)).lerp(top, k0), (foot + Vector2(hw, 0)).lerp(top, k1), Color(0.55, 0.5, 0.45), 1.0)
	var blink := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(top, 2.5, Color(1.0, 0.2, 0.15, 0.4 + 0.6 * blink))
	draw_circle(top, 8.0, Color(1.0, 0.2, 0.15, 0.15 * blink))


func _draw_ground_texture() -> void:
	# scorch marks and blast streaks radiating from ground zero
	var gz := loc_pos("ground_zero")
	for i in 18:
		var a := TAU * i / 18.0 + SurvivalArt.hash01(i, 91) * 0.3
		var len := minf(size.x, size.y) * (0.25 + SurvivalArt.hash01(i, 92) * 0.35)
		var dir := Vector2(cos(a), sin(a) * 0.62)
		var p0 := gz + dir * minf(size.x, size.y) * 0.1
		var p1 := gz + dir * len
		if p1.y < HORIZON * size.y:
			p1.y = HORIZON * size.y + 4.0
		draw_line(p0, p1, Color(0.1, 0.07, 0.06, 0.28), 6.0 + SurvivalArt.hash01(i, 93) * 8.0)


func _draw_roads() -> void:
	var gz := loc_pos("ground_zero")
	var crater_r := minf(size.x, size.y) * 0.13
	var rw := clampf(minf(size.x, size.y) * 0.022, 6.0, 14.0)
	var seg_i := 0
	for road in ROADS:
		for k in range(road.size() - 1):
			var a := N(road[k])
			var b := N(road[k + 1])
			var n := maxi(1, int(a.distance_to(b) / 26.0))
			for j in n:
				seg_i += 1
				var p0 := a.lerp(b, float(j) / n)
				var p1 := a.lerp(b, float(j + 1) / n)
				var mid := (p0 + p1) * 0.5
				if ((mid - gz) * Vector2(1.0, 1.6)).length() < crater_r * 1.25:
					continue
				if SurvivalArt.hash01(seg_i, 101) < 0.12:
					continue # a chunk of road is just gone
				var off := Vector2(0, (SurvivalArt.hash01(seg_i, 102) - 0.5) * 3.0)
				draw_line(p0 + off, p1 + off, Color(0.1, 0.09, 0.085), rw + 3.0)
				draw_line(p0 + off, p1 + off, Color(0.16, 0.145, 0.135), rw)
				if j % 2 == 0:
					draw_line(p0.lerp(p1, 0.25) + off, p0.lerp(p1, 0.6) + off, Color(0.75, 0.62, 0.3, 0.35), 1.5)
				if SurvivalArt.hash01(seg_i, 103) < 0.25:
					var c := mid + off
					draw_line(c + Vector2(-rw * 0.4, -rw * 0.3), c + Vector2(rw * 0.1, rw * 0.1), Color(0.05, 0.04, 0.04), 1.2)
					draw_line(c + Vector2(rw * 0.1, rw * 0.1), c + Vector2(rw * 0.35, -rw * 0.2), Color(0.05, 0.04, 0.04), 1.2)


func _draw_crater() -> void:
	var gz := loc_pos("ground_zero")
	var rx := minf(size.x, size.y) * 0.13
	var ry := rx * 0.6
	var pulse := 0.5 + 0.5 * sin(_t * 1.6)
	draw_colored_polygon(SurvivalArt.ellipse(gz, rx * 1.5, ry * 1.5, 32), Color(0.12, 0.09, 0.07, 0.6))
	draw_colored_polygon(SurvivalArt.ellipse(gz, rx, ry, 32), Color(0.34, 0.26, 0.2))
	draw_colored_polygon(SurvivalArt.ellipse(gz + Vector2(0, ry * 0.08), rx * 0.82, ry * 0.78, 32), Color(0.07, 0.08, 0.06))
	draw_colored_polygon(SurvivalArt.ellipse(gz + Vector2(0, ry * 0.12), rx * 0.5, ry * 0.42, 24), Color(0.5, 0.95, 0.35, 0.12 + 0.1 * pulse))
	draw_colored_polygon(SurvivalArt.ellipse(gz + Vector2(0, ry * 0.12), rx * 0.2, ry * 0.16, 18), Color(0.8, 1.0, 0.6, 0.25 + 0.15 * pulse))
	var ts := clampf(rx * 0.17, 6.0, 14.0)
	for tile in _tiles:
		var a: float = tile["a"]
		var d: float = tile["d"]
		var p := gz + Vector2(cos(a) * rx * d, sin(a) * ry * d)
		if p.y < HORIZON * size.y + ts:
			continue
		SurvivalArt.chess_tile(self, p, ts * float(tile["s"]), float(tile["rot"]), bool(tile["light"]))


func _draw_blocks() -> void:
	for b in _blocks:
		var p := N(b["p"])
		var w: float = float(b["w"]) * size.x
		var d: float = float(b["d"]) * size.y
		var h: float = float(b["h"]) * size.y
		var shade: float = b["shade"]
		var front := Color(0.2 + shade, 0.15 + shade, 0.13 + shade)
		var top := front.lightened(0.18)
		var x0 := p.x - w * 0.5
		var y0 := p.y
		# shadow, front wall, roof
		draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w + h * 0.5, y0 + h * 0.25), Vector2(x0 + h * 0.5, y0 + h * 0.25)]), Color(0, 0, 0, 0.25))
		var seed_value: int = b["seed"]
		if bool(b["broken"]):
			var pts := PackedVector2Array([Vector2(x0, y0), Vector2(x0, y0 - h)])
			for k in 4:
				var fx := x0 + w * (k + 1) / 4.0
				pts.append(Vector2(fx, y0 - h * (0.35 + 0.65 * SurvivalArt.hash01(seed_value + k, 111))))
			pts.append(Vector2(x0 + w, y0))
			draw_colored_polygon(pts, front)
		else:
			draw_rect(Rect2(x0, y0 - h, w, h), front)
			draw_colored_polygon(PackedVector2Array([Vector2(x0, y0 - h), Vector2(x0 + w, y0 - h), Vector2(x0 + w + d * 0.3, y0 - h - d), Vector2(x0 + d * 0.3, y0 - h - d)]), top)
		# dead windows
		var cols := maxi(1, int(w / 8.0))
		var rows := maxi(1, int(h / 9.0))
		for i in cols:
			for j in rows:
				if SurvivalArt.hash01(seed_value * 13 + i * 7 + j, 113) < 0.55:
					var wx := x0 + 3.0 + i * (w - 6.0) / cols
					var wy := y0 - h + 4.0 + j * (h - 6.0) / rows
					if wy < y0 - 3.0:
						draw_rect(Rect2(wx, wy, 2.5, 3.0), Color(0.05, 0.04, 0.04) if SurvivalArt.hash01(seed_value + i + j, 117) < 0.9 else Color(1.0, 0.5, 0.15, 0.7))


func _draw_route() -> void:
	if selected == "" or selected == "shelter":
		return
	var a := loc_pos("shelter")
	var b := loc_pos(selected)
	var col := Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.55 + 0.25 * sin(_t * 3.0))
	draw_dashed_line(a, b, col, 2.0, 8.0)


func _draw_markers() -> void:
	var font := ThemeDB.fallback_font
	var mr := marker_radius()
	var fs := int(clampf(mr * 0.85, 15.0, 18.0))
	for id in SurvivalSim.LOC_ORDER:
		var c := loc_pos(id)
		var L: Dictionary = SurvivalSim.LOCS[id]
		var picked := sim.picked_over(id)
		var is_sel: bool = id == selected
		var is_hover: bool = id == hover
		var radv: float = float(L["rad"])
		if radv >= 8.0:
			var pulse := 0.5 + 0.5 * sin(_t * 2.0 + c.x)
			draw_circle(c, mr * (1.6 + 0.2 * pulse), Color(0.5, 1.0, 0.3, clampf(radv / 60.0, 0.06, 0.25) * (0.6 + 0.4 * pulse)))
		if is_sel:
			var k := fposmod(_t * 0.8, 1.0)
			draw_arc(c, mr * (1.25 + k * 0.7), 0, TAU, 32, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, 0.8 * (1.0 - k)), 2.0, true)
		var flash: bool = _flash_t > 0.0 and _flash_id == id
		draw_circle(c + Vector2(2, 3), mr, Color(0, 0, 0, 0.45))
		draw_circle(c, mr, Color(0.13, 0.1, 0.09, 0.95) if not flash else Color(0.35, 0.26, 0.15))
		var ring := UI.GOLD if (is_sel or id == "shelter") else (Color(0.85, 0.75, 0.6) if is_hover else Color(0.52, 0.41, 0.29))
		draw_arc(c, mr, 0, TAU, 28, ring, 3.0 if is_sel else 2.0, true)
		var gc: Color = GLYPH_COL.get(id, UI.TEXT)
		if picked:
			gc = Color(0.45, 0.42, 0.4)
		SurvivalArt.draw_glyph(self, id, c, mr * 0.72, gc, _t)
		# trip length pips: one or two
		var slots: int = int(L["slots"])
		for i in slots:
			draw_circle(c + Vector2(mr * 0.78 + i * 7.0, -mr * 0.82), 3.0, UI.GOLD.darkened(0.15))
			draw_circle(c + Vector2(mr * 0.78 + i * 7.0, -mr * 0.82), 3.0, Color(0, 0, 0, 0.6), false, 1.0)
		var lbl := sim.loc_name(id)
		if id == "shelter":
			lbl = "YOUR SHELTER"
		var tw := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := Vector2(clampf(c.x - tw * 0.5, 4.0, size.x - tw - 4.0), c.y + mr + fs + 1.0)
		var lc := UI.GOLD if (is_sel or id == "shelter") else (Color(0.62, 0.58, 0.54) if picked else UI.TEXT)
		draw_string_outline(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85))
		draw_string(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
		if picked:
			draw_line(c + Vector2(-mr * 0.6, -mr * 0.6), c + Vector2(mr * 0.6, mr * 0.6), Color(0.85, 0.3, 0.25, 0.8), 2.0)
	# the shelter's state: smoke from a signal fire, SOS on the roof
	var sh := loc_pos("shelter")
	if sim.sos_painted:
		var sp := sh + Vector2(-mr * 3.2, -mr * 0.6)
		draw_string_outline(font, sp, "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, 4, Color(0, 0, 0, 0.8))
		draw_string(font, sp, "SOS", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, Color(1.0, 0.5, 0.15))
	if sim.fire_lit:
		var fp := sh + Vector2(mr * 1.7, mr * 0.5)
		SurvivalArt.smoke(self, fp - Vector2(0, mr * 0.6), mr * 1.3, _t, 9, Color(0.42, 0.38, 0.36))
		SurvivalArt.flame(self, fp, mr * 1.3, _t)
	if sim.radio_built:
		var top := sh + Vector2(-mr * 1.2, -mr * 2.2)
		draw_line(sh + Vector2(-mr * 0.9, -mr * 0.2), top, Color(0.7, 0.7, 0.7), 1.5)
		for i in 2:
			var k := fposmod(_t * 0.6 + i * 0.5, 1.0)
			draw_arc(top, 4.0 + k * 14.0, -PI * 0.9, -PI * 0.1, 10, Color(1, 0.85, 0.5, 0.6 * (1.0 - k)), 1.5, true)


func _draw_floaters() -> void:
	var font := ThemeDB.fallback_font
	for f in _floaters:
		var age: float = f["age"]
		var c := loc_pos(String(f["id"])) - Vector2(0, marker_radius() * 1.6 + age * 26.0)
		var txt: String = f["text"]
		var col: Color = f["col"]
		col.a = clampf(2.0 - age * 1.2, 0.0, 1.0)
		var fs := 18
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(clampf(c.x - tw * 0.5, 4.0, size.x - tw - 4.0), c.y)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, col.a * 0.85))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_ash() -> void:
	var heavy := sim.weather == "ash"
	var n := _ash.size() if heavy else int(_ash.size() * 0.55)
	for i in n:
		var a: Dictionary = _ash[i]
		var s: float = float(a["s"]) * (1.3 if heavy else 1.0)
		var c := Color(0.82, 0.78, 0.74, float(a["a"]) * (0.9 if heavy else 0.6))
		draw_rect(Rect2(Vector2(float(a["x"]) * size.x, float(a["y"]) * size.y), Vector2(s, s)), c)


func _draw_time_tint() -> void:
	var full := Rect2(Vector2.ZERO, size)
	match sim.slot:
		1:
			draw_rect(full, Color(0.35, 0.18, 0.0, 0.05))
		2:
			draw_rect(full, Color(0.18, 0.02, 0.12, 0.2))


func _draw_heli() -> void:
	var target := loc_pos("shelter")
	var k := clampf(heli_t / 3.2, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var start := Vector2(size.x + 120.0, size.y * 0.06)
	var hover_pos := target + Vector2(size.x * 0.05, -minf(size.y * 0.32, 170.0))
	var p := start.lerp(hover_pos, e) + Vector2(0, sin(heli_t * 2.2) * 4.0)
	var s := clampf(minf(size.x, size.y) * 0.22, 70.0, 150.0)
	# the light sweeps the ruins, then finds you
	var sweep := target + Vector2(sin(heli_t * 1.7) * size.x * 0.25 * (1.0 - k), cos(heli_t * 1.3) * size.y * 0.1 * (1.0 - k))
	var light_to := sweep.lerp(target, clampf((heli_t - 2.4) / 1.2, 0.0, 1.0))
	SurvivalArt.draw_searchlight(self, p + Vector2(0, s * 0.18), light_to, clampf(s * 0.45, 26.0, 60.0), clampf(heli_t / 0.6, 0.0, 1.0))
	SurvivalArt.draw_helicopter(self, p, s, heli_t, -1.0, Color(0.4, 0.45, 0.36))
	if heli_t > 3.4:
		var a := clampf((heli_t - 3.4) / 0.6, 0.0, 1.0)
		var font := ThemeDB.fallback_font
		var fs := int(clampf(size.y * 0.075, 26.0, 46.0))
		var txt := "RESCUED"
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2((size.x - tw) * 0.5, size.y * 0.5)
		draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, a * 0.8))
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, a))


func _draw_inset() -> void:
	var r := inset_rect()
	var full := Rect2(r.position - Vector2(0, TITLE_H), r.size + Vector2(0, TITLE_H))
	UI.draw_frame(self, full, sim.loc_name(selected), TITLE_H)
	draw_rect(r, Color(0, 0, 0))
	SurvivalArt.draw_location(self, r, selected, _t, {"weather": sim.weather, "sos": sim.sos_painted, "fire": sim.fire_lit,
		"radio": sim.radio_built, "picked": sim.picked_over(selected)})
