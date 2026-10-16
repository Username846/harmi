class_name BattleArena
extends Control
## Draws the duel: two towering pieces, health/mana bars, floating numbers
## and hit effects.

var hero: Dictionary = {}
var foe: Dictionary = {}
var hero_off := Vector2.ZERO
var foe_off := Vector2.ZERO
var hero_flash := 0.0
var foe_flash := 0.0
var foe_fade := 1.0
var hero_fade := 1.0
var shake := 0.0
var disp := {"hero_hp": 0.0, "hero_mp": 0.0, "foe_hp": 0.0, "foe_mp": 0.0}
var floaters: Array = []
var sparks: Array = []
var _t := 0.0
var bg_color := Color(0.25, 0.08, 0.1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset_display() -> void:
	disp["hero_hp"] = float(hero["hp"])
	disp["hero_mp"] = float(hero["mp"])
	disp["foe_hp"] = float(foe["hp"])
	disp["foe_mp"] = float(foe["mp"])


func _process(delta: float) -> void:
	_t += delta
	for k in ["hero", "foe"]:
		var f: Dictionary = hero if k == "hero" else foe
		disp[k + "_hp"] = move_toward(disp[k + "_hp"], float(f["hp"]), delta * maxf(30.0, float(f["max_hp"]) * 0.9))
		disp[k + "_mp"] = move_toward(disp[k + "_mp"], float(f["mp"]), delta * 40.0)
	hero_flash = maxf(0.0, hero_flash - delta * 3.0)
	foe_flash = maxf(0.0, foe_flash - delta * 3.0)
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


func hero_base() -> Vector2:
	return Vector2(size.x * 0.26, size.y * 0.84) + hero_off


func foe_base() -> Vector2:
	return Vector2(size.x * 0.72, size.y * 0.76) + foe_off


func hero_center() -> Vector2:
	return hero_base() - Vector2(0, piece_scale() * PieceArt.height(hero["type"]) * 0.55)


func foe_center() -> Vector2:
	return foe_base() - Vector2(0, piece_scale() * PieceArt.height(foe["type"]) * 0.55)


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


func _draw() -> void:
	if hero.is_empty():
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
	var s := piece_scale()
	# foe (behind) then hero (in front)
	var fb := foe_base() + sh
	PieceArt.draw_piece(self, foe["type"], foe["color"] == 0, fb.x, fb.y, s * 0.92, Color(1, 1, 1, foe_fade))
	if foe_flash > 0.0:
		var shapes := PieceArt.build(foe["type"], foe["color"] == 0, fb.x, fb.y, s * 0.92)
		for shp in shapes:
			if shp["c"].a >= 0.9:
				draw_colored_polygon(shp["p"], Color(1, 1, 1, foe_flash * 0.8 * foe_fade))
	var hb := hero_base() + sh
	PieceArt.draw_piece(self, hero["type"], hero["color"] == 0, hb.x, hb.y, s, Color(1, 1, 1, hero_fade))
	if hero_flash > 0.0:
		var shapes2 := PieceArt.build(hero["type"], hero["color"] == 0, hb.x, hb.y, s)
		for shp in shapes2:
			if shp["c"].a >= 0.9:
				draw_colored_polygon(shp["p"], Color(1, 0.3, 0.2, hero_flash * 0.7))
	if hero.get("guard", false):
		draw_arc(hero_center(), s * 0.75, 0, TAU, 40, Color(0.5, 0.75, 1.0, 0.45 + 0.2 * sin(_t * 5.0)), 4.0, true)
	if foe.get("guard", false):
		draw_arc(foe_center(), s * 0.7, 0, TAU, 40, Color(0.5, 0.75, 1.0, 0.45 + 0.2 * sin(_t * 5.0)), 4.0, true)
	if foe.get("blind", false):
		for i in 6:
			var a := _t * 2.0 + i
			draw_circle(foe_center() + Vector2(cos(a), sin(a) * 0.4) * s * 0.4 - Vector2(0, s * 0.4), 4.0, Color(0.6, 0.58, 0.56, 0.7))
	for sp in sparks:
		var c: Color = sp["c"]
		c.a = 1.0 - sp["t"] / sp["life"]
		draw_circle(sp["p"], sp["r"], c)
	# bars
	var bw := clampf(size.x * 0.4, 180.0, 340.0)
	_bars(Rect2(14, 12, bw, 0), foe, disp["foe_hp"], disp["foe_mp"])
	_bars(Rect2(size.x - bw - 14, size.y - 80, bw, 0), hero, disp["hero_hp"], disp["hero_mp"])
	# floating numbers
	var font := ThemeDB.fallback_font
	for f in floaters:
		var a := 1.0 - clampf((f["t"] - 0.7) / 0.6, 0.0, 1.0)
		var c2: Color = f["c"]
		c2.a = a
		var fs := 30
		var tw := font.get_string_size(f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = f["p"] - Vector2(tw * 0.5, 0)
		draw_string_outline(font, p, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a))
		draw_string(font, p, f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)


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
