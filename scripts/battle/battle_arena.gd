class_name BattleArena
extends Control
## Draws the duel: towering pieces, health/mana bars, floating numbers and hit
## effects. A plain duel shows two pieces with big bars in the corners; a team
## battle shows up to four pieces a side in staggered rows (heroes bottom-left,
## foes top-right), each with a compact bar under its feet.
##
## Every fighter dictionary carries its own display state: "slot" (0 = leader),
## "is_hero", "off" (lunge offset), "flash", "fade", "dhp"/"dmp" (shown values).

signal picked(f: Dictionary)

var heroes: Array = []
var foes: Array = []
var active: Dictionary = {} # whose turn it is (team battles only)
var target: Dictionary = {} # who is being hit
var hover: Dictionary = {} # target under the pointer while picking
var pick_list: Array = [] # tappable fighters while choosing a target
var shake := 0.0
var floaters: Array = []
var sparks: Array = []
var _t := 0.0
var bg_color := Color(0.25, 0.08, 0.1)
var gloom := 0.0 # how dark the foe's mood makes the arena

const BAR_H := 40.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func team() -> bool:
	return heroes.size() > 1 or foes.size() > 1


func all_fighters() -> Array:
	return heroes + foes


func reset_display() -> void:
	for f in all_fighters():
		f["dhp"] = float(f["hp"])
		f["dmp"] = float(f["mp"])
		f["off"] = Vector2.ZERO
		f["flash"] = 0.0
		f["fade"] = 1.0
	active = {}
	target = {}
	hover = {}
	pick_list = []


func set_pick(list: Array) -> void:
	pick_list = list
	hover = {}
	mouse_filter = Control.MOUSE_FILTER_STOP if not list.is_empty() else Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	for f in all_fighters():
		f["dhp"] = move_toward(float(f.get("dhp", f["hp"])), float(f["hp"]), delta * maxf(30.0, float(f["max_hp"]) * 0.9))
		f["dmp"] = move_toward(float(f.get("dmp", f["mp"])), float(f["mp"]), delta * 40.0)
		f["flash"] = maxf(0.0, float(f.get("flash", 0.0)) - delta * 3.0)
	shake = maxf(0.0, shake - delta * 2.5)
	for fl in floaters:
		fl["t"] += delta
		fl["p"] += Vector2(0, -38.0) * delta
	floaters = floaters.filter(func(fl): return fl["t"] < 1.3)
	for s in sparks:
		s["t"] += delta
		s["v"] += Vector2(0, 160.0) * delta * s.get("grav", 1.0)
		s["p"] += s["v"] * delta
	sparks = sparks.filter(func(s): return s["t"] < s["life"])
	queue_redraw()


func piece_scale() -> float:
	return minf(size.y * 0.34, size.x * 0.25)


# --- layout -------------------------------------------------------------------

const LEAD_K := [1.0, 0.8, 0.72, 0.64]


## A tall arena (portrait screens) lets each side spread over most of the width.
func tall() -> bool:
	return size.y > size.x * 0.9


func _spacing(is_hero: bool) -> float:
	var list: Array = heroes if is_hero else foes
	return size.x * (0.72 if tall() else 0.47) / maxi(1, list.size())


## How much the compact bars and their text grow when there is room.
func bar_k(is_hero: bool) -> float:
	return clampf(_bar_width_for(is_hero) / (75.0 if tall() else 85.0), 1.0, 1.3)


func bar_h(is_hero: bool) -> float:
	return BAR_H * bar_k(is_hero)


func _bar_width_for(is_hero: bool) -> float:
	return clampf(_spacing(is_hero) * 0.94, 60.0, 150.0)


## Where a fighter stands (base centre, without its lunge offset) and how big
## it is drawn: [Vector2, float].
func _place(f: Dictionary) -> Array:
	var is_hero: bool = f["is_hero"]
	var ps := piece_scale()
	if not team():
		if is_hero:
			return [Vector2(size.x * 0.26, size.y * 0.84), ps]
		return [Vector2(size.x * 0.72, size.y * 0.76), ps * 0.92]
	var list: Array = heroes if is_hero else foes
	var n := list.size()
	var slot: int = f["slot"]
	var lead_col := int((n - 1) / 2.0)
	var col := lead_col
	if slot > 0:
		var others: Array = []
		for c in n:
			if c != lead_col:
				others.append(c)
		col = others[slot - 1]
	var is_tall := tall()
	var spacing := _spacing(is_hero)
	var x: float
	if is_hero:
		x = size.x * 0.025 + (col + 0.5) * spacing
	else:
		x = size.x * 0.975 - (col + 0.5) * spacing
	var back := absi(col - lead_col) % 2 == 1
	var lead_k: float = LEAD_K[n - 1]
	if is_tall:
		lead_k = minf(1.0, lead_k * 1.2)
	var lead_s := minf(ps * lead_k, spacing / 0.66)
	var s := lead_s if slot == 0 else lead_s * 0.8
	if not is_hero:
		s *= 0.92
	var stagger := size.y * 0.085
	var y: float
	if is_hero:
		y = size.y - bar_h(true) - lead_s * 0.1 - 6.0
	else:
		y = maxf(size.y * (0.43 if is_tall else 0.6), lead_s * 1.8 * 0.92 + stagger + 4.0)
	if back:
		y -= stagger
	return [Vector2(x, y), s]


func base(f: Dictionary) -> Vector2:
	return _place(f)[0]


func pos(f: Dictionary) -> Vector2:
	return base(f) + Vector2(f.get("off", Vector2.ZERO))


func scale_of(f: Dictionary) -> float:
	return _place(f)[1]


func center(f: Dictionary) -> Vector2:
	return pos(f) - Vector2(0, scale_of(f) * PieceArt.height(f["type"]) * 0.55)


func _bar_rect(f: Dictionary) -> Rect2:
	var p := base(f)
	var bw := _bar_width_for(f["is_hero"])
	return Rect2(p.x - bw * 0.5, p.y + scale_of(f) * 0.1 + 2.0, bw, bar_h(f["is_hero"]) - 4.0)


## The tappable fighter under a point, front pieces first.
func fighter_at(p: Vector2) -> Dictionary:
	var order := _draw_order()
	order.reverse()
	for f in order:
		if not _has(pick_list, f):
			continue
		var r := PieceArt.bounds(f["type"], base(f).x, base(f).y, scale_of(f)).grow(6.0)
		if r.has_point(p) or (team() and _bar_rect(f).has_point(p)):
			return f
	return {}


func _gui_input(event: InputEvent) -> void:
	if pick_list.is_empty():
		return
	if event is InputEventMouseMotion:
		hover = fighter_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var f := fighter_at(event.position)
		if not f.is_empty():
			accept_event()
			picked.emit(f)


static func _has(list: Array, f: Dictionary) -> bool:
	for x in list:
		if is_same(x, f):
			return true
	return false


func _draw_order() -> Array:
	var order := all_fighters()
	order.sort_custom(func(a, b): return base(a).y < base(b).y)
	return order


# --- effects ------------------------------------------------------------------

func float_text(text: String, at: Vector2, color: Color) -> void:
	floaters.append({"text": text, "p": at, "c": color, "t": 0.0})


func burst(at: Vector2, color: Color, n: int = 24, speed: float = 220.0) -> void:
	for i in n:
		var a := randf() * TAU
		sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed), "c": color,
			"t": 0.0, "life": randf_range(0.4, 0.9), "r": randf_range(2.0, 4.5), "grav": 1.0})


func rise(at: Vector2, color: Color, n: int = 20) -> void:
	for i in n:
		sparks.append({"p": at + Vector2(randf_range(-30, 30), randf_range(-10, 30)), "v": Vector2(randf_range(-15, 15), randf_range(-90, -40)),
			"c": color, "t": 0.0, "life": randf_range(0.6, 1.2), "r": randf_range(2.0, 4.0), "grav": -0.1})


# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	if heroes.is_empty() or foes.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 10.0
	# backdrop
	var top := bg_color.darkened(0.6)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), Vector2(r.end.x, r.end.y), Vector2(0, r.end.y)]),
		PackedColorArray([top, top, bg_color, bg_color]))
	for i in 7:
		var x := fmod(i * 0.17 + _t * 0.01 * (1 + i % 3), 1.0)
		draw_circle(Vector2(x * size.x, size.y * (0.15 + 0.08 * (i % 4))), size.x * 0.12, Color(1, 1, 1, 0.012))
	# floor
	var fl := PackedVector2Array([Vector2(0, size.y * 0.68), Vector2(size.x, size.y * 0.62), Vector2(size.x, size.y), Vector2(0, size.y)])
	draw_polygon(fl, PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.75)]))
	# a giant ghostly chessboard floor
	for i in 9:
		var y := lerpf(size.y * 0.66, size.y, pow(i / 8.0, 1.6))
		draw_line(Vector2(0, y), Vector2(size.x, y - size.y * 0.04 * (1.0 - i / 8.0)), Color(1, 1, 1, 0.05), 1.0)
	var is_team := team()
	# rings on the floor under the active fighter, the target and pickable foes
	for f in all_fighters():
		var ring := Color(0, 0, 0, 0)
		var wide := 2.0
		if is_same(f, target) or is_same(f, hover):
			ring = Color(1.0, 0.3, 0.22, 0.85)
			wide = 4.0
		elif is_team and is_same(f, active):
			ring = Color(UI.GOLD, 0.9)
			wide = 4.0
		elif _has(pick_list, f):
			ring = Color(1.0, 0.35, 0.25, 0.4 + 0.25 * sin(_t * 6.0))
		if ring.a > 0.0:
			var b := base(f) + sh
			var s := scale_of(f)
			_ellipse(b, Vector2(s * 0.46, s * 0.13), Color(ring, ring.a * 0.25), true, 0.0)
			_ellipse(b, Vector2(s * 0.46, s * 0.13), ring, false, wide)
	# pieces, back to front
	for f in _draw_order():
		_draw_fighter(f, sh)
	for sp in sparks:
		var c: Color = sp["c"]
		c.a = 1.0 - sp["t"] / sp["life"]
		draw_circle(sp["p"], sp["r"], c)
	if gloom > 0.01:
		# a gloomy foe's arena closes in: dark edges and drifting rain
		var rings := 8
		for i in rings:
			var k := float(i) / rings
			var inset := minf(size.x, size.y) * 0.5 * (1.0 - k)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.03, gloom * 0.07), false, inset)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.06, gloom * 0.3))
		for i in int(40 * gloom):
			var x := fmod(i * 73.1 + _t * 40.0, size.x)
			var y := fmod(i * 41.7 + _t * 380.0, size.y)
			draw_line(Vector2(x, y), Vector2(x - 3, y + 12), Color(0.6, 0.7, 0.9, 0.25 * gloom), 1.0)
	# bars
	if is_team:
		for f in all_fighters():
			_compact_bar(f)
		# markers over the heads of the active fighter and the target
		if not active.is_empty():
			_marker(active, UI.GOLD)
		var tg: Dictionary = target if not target.is_empty() else hover
		if not tg.is_empty():
			_marker(tg, Color(1.0, 0.32, 0.24))
	else:
		var bw := clampf(size.x * 0.4, 180.0, 340.0)
		var foe: Dictionary = foes[0]
		var hero: Dictionary = heroes[0]
		_bars(Rect2(14, 12, bw, 0), foe, foe["dhp"], foe["dmp"])
		_bars(Rect2(size.x - bw - 14, size.y - 80, bw, 0), hero, hero["dhp"], hero["dmp"])
	# floating numbers
	var font := ThemeDB.fallback_font
	for f in floaters:
		var a := 1.0 - clampf((f["t"] - 0.7) / 0.6, 0.0, 1.0)
		var c2: Color = f["c"]
		c2.a = a
		var fs := 30 if not is_team else 24
		var tw := font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = f["p"] - Vector2(tw * 0.5, 0)
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)


func _draw_fighter(f: Dictionary, sh: Vector2) -> void:
	var b := pos(f) + sh
	var s := scale_of(f)
	var fade: float = f.get("fade", 1.0)
	var white: bool = f["color"] == 0
	if fade <= 0.001:
		return
	PieceArt.draw_piece(self, f["type"], white, b.x, b.y, s, Color(1, 1, 1, fade))
	var flash: float = f.get("flash", 0.0)
	if flash > 0.0:
		var fc := Color(1, 0.3, 0.2, flash * 0.7) if f["is_hero"] else Color(1, 1, 1, flash * 0.8 * fade)
		for shp in PieceArt.build(f["type"], white, b.x, b.y, s):
			if shp["c"].a >= 0.9:
				draw_colored_polygon(shp["p"], fc)
	var c := center(f) + sh
	if f.get("guard", false) and f["hp"] > 0:
		draw_arc(c, s * (0.75 if f["is_hero"] else 0.7), 0, TAU, 40, Color(0.5, 0.75, 1.0, 0.45 + 0.2 * sin(_t * 5.0)), 4.0, true)
	if f.get("blind", false) and f["hp"] > 0:
		for i in 6:
			var a := _t * 2.0 + i
			draw_circle(c + Vector2(cos(a), sin(a) * 0.4) * s * 0.4 - Vector2(0, s * 0.4), maxf(2.5, s * 0.035), Color(0.6, 0.58, 0.56, 0.7))


func _ellipse(c: Vector2, radii: Vector2, color: Color, filled: bool, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	if filled:
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(pts, color, width, true)


## A bobbing arrow over a fighter's head.
func _marker(f: Dictionary, color: Color) -> void:
	if f["hp"] <= 0:
		return
	var s := scale_of(f)
	var tip := pos(f) - Vector2(0, s * PieceArt.height(f["type"]) + 6.0 + 4.0 * sin(_t * 5.0))
	var w := clampf(s * 0.13, 8.0, 14.0)
	var pts := PackedVector2Array([tip, tip + Vector2(-w, -w * 1.3), tip + Vector2(w, -w * 1.3)])
	draw_colored_polygon(pts, color)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.8), 1.5, true)


func _compact_bar(f: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var r := _bar_rect(f)
	var k := bar_k(f["is_hero"])
	var down: bool = f["hp"] <= 0
	var border := Color(0.52, 0.41, 0.29, 0.9)
	var bwid := 1.5
	if is_same(f, target) or is_same(f, hover):
		border = Color(1.0, 0.32, 0.24)
		bwid = 3.0
	elif is_same(f, active):
		border = UI.GOLD
		bwid = 3.0
	var box := r.grow_individual(3, 1, 3, 1)
	draw_rect(box, Color(0.05, 0.04, 0.05, 0.55 if down else 0.82))
	draw_rect(box, border, false, bwid)
	var name_c := UI.GOLD if f.get("leader", false) else UI.TEXT
	if down:
		name_c = UI.DIM
	var fs := int(round(14.0 * k))
	var x0 := r.position.x + 2.0
	var ny := r.position.y + 13.0 * k
	if f.get("leader", false):
		# a small crown marks the leader
		var cw := 10.0 * k
		var ch := 9.0 * k
		draw_colored_polygon(PackedVector2Array([Vector2(x0, ny), Vector2(x0, ny - ch * 0.9), Vector2(x0 + cw * 0.25, ny - ch * 0.45),
			Vector2(x0 + cw * 0.5, ny - ch), Vector2(x0 + cw * 0.75, ny - ch * 0.45), Vector2(x0 + cw, ny - ch * 0.9), Vector2(x0 + cw, ny)]), name_c)
		x0 += cw + 3.0
	var nm: String = f.get("short", f["name"])
	draw_string(font, Vector2(x0, ny), nm, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x0 - 1.0, fs, name_c)
	var hp_k := clampf(float(f["dhp"]) / float(f["max_hp"]), 0.0, 1.0)
	var mp_k := clampf(float(f["dmp"]) / maxf(1.0, float(f["max_mp"])), 0.0, 1.0)
	var hb := Rect2(r.position + Vector2(0, 17.0 * k), Vector2(r.size.x, 11.0 * k))
	draw_rect(hb, Color(0.15, 0.05, 0.05))
	var hc := Color(0.35, 0.8, 0.35).lerp(Color(0.9, 0.2, 0.15), 1.0 - hp_k) if hp_k < 0.999 else Color(0.35, 0.8, 0.35)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp_k, hb.size.y)), hc)
	draw_rect(hb, Color(0, 0, 0, 0.8), false, 1.0)
	var txt := "DOWN" if down else "%d" % int(ceil(float(f["dhp"])))
	var tfs := int(round(11.0 * k))
	var ty := hb.position.y + hb.size.y * 0.5 + tfs * 0.36
	draw_string_outline(font, Vector2(hb.position.x + 3, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, hb.size.x - 4.0, tfs, 3, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(hb.position.x + 3, ty), txt, HORIZONTAL_ALIGNMENT_LEFT, hb.size.x - 4.0, tfs, Color(1, 1, 1))
	var tags := ""
	if not down:
		if f.get("guard", false):
			tags += "G"
		if f.get("blind", false):
			tags += " B"
		if f.get("atk_up", 0) > 0:
			tags += " A+"
		if f.get("def_up", 0) > 0:
			tags += " D+"
	tags = tags.strip_edges()
	if tags != "":
		draw_string_outline(font, Vector2(hb.position.x, ty), tags, HORIZONTAL_ALIGNMENT_RIGHT, hb.size.x - 3.0, tfs, 3, Color(0, 0, 0, 0.9))
		draw_string(font, Vector2(hb.position.x, ty), tags, HORIZONTAL_ALIGNMENT_RIGHT, hb.size.x - 3.0, tfs, UI.GOLD)
	var mb := Rect2(r.position + Vector2(0, 30.0 * k), Vector2(r.size.x, 5.0 * k))
	draw_rect(mb, Color(0.05, 0.06, 0.15))
	draw_rect(Rect2(mb.position, Vector2(mb.size.x * mp_k, mb.size.y)), UI.BLUE)


func _bars(r: Rect2, f: Dictionary, hp: float, mp: float) -> void:
	var font := ThemeDB.fallback_font
	var box := Rect2(r.position - Vector2(10, 8), Vector2(r.size.x + 20, 76))
	draw_rect(box, Color(0.05, 0.04, 0.05, 0.78))
	draw_rect(box, Color(0.52, 0.41, 0.29, 0.9), false, 2.0)
	draw_string(font, r.position + Vector2(0, 16), f["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.7, 17, UI.TEXT)
	var hp_k := clampf(hp / float(f["max_hp"]), 0.0, 1.0)
	var mp_k := clampf(mp / maxf(1.0, float(f["max_mp"])), 0.0, 1.0)
	var hb := Rect2(r.position + Vector2(0, 24), Vector2(r.size.x, 16))
	draw_rect(hb, Color(0.15, 0.05, 0.05))
	var hc := Color(0.35, 0.8, 0.35).lerp(Color(0.9, 0.2, 0.15), 1.0 - hp_k) if hp_k < 0.999 else Color(0.35, 0.8, 0.35)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp_k, hb.size.y)), hc)
	draw_rect(Rect2(hb.position, Vector2(hb.size.x * hp_k, hb.size.y * 0.4)), Color(1, 1, 1, 0.18))
	draw_rect(hb, Color(0, 0, 0, 0.8), false, 1.5)
	var hp_txt := "HP %d / %d" % [int(ceil(hp)), f["max_hp"]]
	draw_string(font, hb.position + Vector2(6, 13), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
	var mb := Rect2(r.position + Vector2(0, 46), Vector2(r.size.x, 12))
	draw_rect(mb, Color(0.05, 0.06, 0.15))
	draw_rect(Rect2(mb.position, Vector2(mb.size.x * mp_k, mb.size.y)), UI.BLUE)
	draw_rect(mb, Color(0, 0, 0, 0.8), false, 1.5)
	draw_string(font, mb.position + Vector2(6, 11), "MP %d / %d" % [int(ceil(mp)), f["max_mp"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.95, 1))
	var tags := []
	if f.get("guard", false):
		tags.append("GUARD")
	if f.get("blind", false):
		tags.append("BLIND")
	if f.get("atk_up", 0) > 0:
		tags.append("ATK+")
	if f.get("def_up", 0) > 0:
		tags.append("DEF+")
	if not tags.is_empty():
		draw_string(font, r.position + Vector2(0, 16), " ".join(tags), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x, 13, UI.GOLD)
