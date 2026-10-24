class_name GraveyardPanel
extends Modal
## The graveyard: your captured pieces rest under little tombstones. It has
## three states, driven by Game:
##   "yugi"     Yugi Moto is there, ready to duel for one of your pieces in a
##              children's card game, or to duel FOR REALS (a shadow game).
##   "ruined"   Yugi lost a shadow game and is gone. The place falls apart and
##              you can repair its six sections (Game.GRAVE_SECTIONS).
##   "restored" Every section is mended; whoever finished it is the Gravekeeper
##              and may raise a fallen piece for free every few turns.
## can_duel / reason gate the turn-using actions (duels and raising); repairs
## cost no turn and are always allowed.

signal duel_requested(index: int)
signal reals_requested(index: int)
signal repaired(section_id: String)
signal keeper_crowned
signal raise_requested(index: int)

const LINES := [
	"It's time to duel!",
	"Want your %s back? Beat me in a children's card game!",
	"I believe in the heart of the cards!",
	"My grandpa runs a game shop, you know.",
	"A graveyard is no place to stop shuffling!",
]
## Where each section sits in the drawing (fractions of the scene), for sparkles.
const SECTION_SPOTS := {
	"gate": Vector2(0.08, 0.6), "stones": Vector2(0.4, 0.7), "flowers": Vector2(0.45, 0.92),
	"crypt": Vector2(0.64, 0.62), "lanterns": Vector2(0.53, 0.45), "shed": Vector2(0.9, 0.6),
}

var color := 0
var selected := -1
var allowed := true
var why := ""
var state := ""
var content: VBoxContainer
var scene: Control
var info: Label
var status: Label
var duel_btn: Button
var reals_btn: Button
var raise_btn: Button
var split: BoxContainer
var list_scroll: ScrollContainer
var list_box: VBoxContainer
var section_buttons: Dictionary = {} # section id -> Button
var section_costs: Dictionary = {} # section id -> Label
var section_names: Dictionary = {} # section id -> Label
var line := ""
var _t := 0.0
var _tombs: Array = [] # Rect2 per graveyard entry, in scene coordinates
var _sparks: Array = []
var _celebrate := 0.0
var _fitting := false
var _trees: Array = [] # per tree: Array of [from, to, width] in tree units


func _init(side_color: int, can_duel: bool, reason: String) -> void:
	super("The Graveyard", 660.0)
	color = side_color
	allowed = can_duel
	why = reason
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	body.add_child(content)
	var graves: Array = Game.graveyard[color]
	if not graves.is_empty():
		selected = graves.size() - 1
	line = LINES[randi() % LINES.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	for k in 2:
		var segs: Array = []
		_grow_tree(segs, Vector2.ZERO, -PI * 0.5 + (0.08 if k == 0 else -0.1), 0.32, 0.06, 5, rng)
		_trees.append(segs)
	_build()


func _state_now() -> String:
	if not Game.yugi_banished:
		return "yugi"
	if not Game.graveyard_restored():
		return "ruined"
	return "restored"


func _title_label() -> Label:
	var first := body.get_child(0)
	return first as Label


func _build() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	section_buttons.clear()
	section_costs.clear()
	section_names.clear()
	duel_btn = null
	reals_btn = null
	raise_btn = null
	split = null
	list_scroll = null
	list_box = null
	status = null
	state = _state_now()
	scene = Control.new()
	scene.custom_minimum_size = Vector2(0, 250)
	scene.clip_contents = true
	scene.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.draw.connect(_draw_scene)
	scene.gui_input.connect(_on_scene_input)
	var tl := _title_label()
	match state:
		"yugi":
			max_width = 660.0
			if tl:
				tl.text = "The Graveyard"
			_build_yugi()
		"ruined":
			max_width = 960.0
			if tl:
				tl.text = "The Ruined Graveyard"
			_build_ruined()
		_:
			max_width = 660.0
			if tl:
				tl.text = "The Gravekeeper's Garden"
			_build_restored()
	if is_inside_tree():
		_layout()


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	return row


func _wide(b: Button) -> Button:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _build_yugi() -> void:
	content.add_child(scene)
	info = UI.label("", 17, UI.DIM)
	info.custom_minimum_size = Vector2(0, 48)
	content.add_child(info)
	var row := _row()
	duel_btn = _wide(UI.button("Duel Yugi", _on_duel))
	row.add_child(duel_btn)
	reals_btn = _wide(UI.button("Duel For Reals", _on_reals))
	reals_btn.add_theme_color_override("font_color", Color(0.82, 0.62, 1.0))
	row.add_child(reals_btn)
	var row2 := _row()
	row2.add_child(_wide(UI.button("Leave", close)))
	_refresh()


func _build_ruined() -> void:
	split = BoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	content.add_child(split)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	left.add_child(scene)
	info = UI.label("Yugi is gone, dragged into the Shadow Realm, and nobody can duel for the dead any more. The graveyard is falling apart. Its despair will seep into everyone's mood until someone restores the place.", 15, UI.DIM)
	left.add_child(info)
	status = UI.label("", 15, UI.GOLD)
	left.add_child(status)
	list_scroll = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(list_scroll)
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 8)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_box)
	for sec in Game.GRAVE_SECTIONS:
		var sid: String = sec["id"]
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UI.panel_style(Color(0.13, 0.11, 0.13), Color(0.32, 0.27, 0.24), 1, 6))
		list_box.add_child(pc)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		pc.add_child(hb)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)
		var nm := UI.label(String(sec["name"]), 17, UI.GOLD)
		vb.add_child(nm)
		section_names[sid] = nm
		vb.add_child(UI.label(String(sec["desc"]), 15, UI.DIM))
		var cost := UI.label("Cost: " + Game.section_cost_text(sec), 15, UI.TEXT)
		vb.add_child(cost)
		section_costs[sid] = cost
		var b := UI.button("Repair", func(): _on_repair(sid), 48)
		b.custom_minimum_size = Vector2(118, 48)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(b)
		section_buttons[sid] = b
	var row := _row()
	row.add_child(_wide(UI.button("Leave", close)))
	_refresh_ruined()


func _build_restored() -> void:
	content.add_child(scene)
	info = UI.label("", 17, UI.DIM)
	info.custom_minimum_size = Vector2(0, 48)
	content.add_child(info)
	var row := _row()
	raise_btn = _wide(UI.button("Raise this piece (free)", _on_raise))
	row.add_child(raise_btn)
	var row2 := _row()
	row2.add_child(_wide(UI.button("Leave", close)))
	_refresh()


# --- layout ---------------------------------------------------------------------------

func _layout() -> void:
	if split:
		split.vertical = not (size.x >= 820.0 and size.x > size.y * 1.2)
	if scene:
		var h := 250.0
		if state == "ruined":
			h = clampf(size.y * 0.27, 140.0, 250.0) if split.vertical else clampf(size.y * 0.45, 180.0, 260.0)
		elif size.y < 560.0:
			h = clampf(size.y - 330.0, 150.0, 250.0)
		scene.custom_minimum_size = Vector2(0, h)
	if list_scroll:
		list_scroll.custom_minimum_size = Vector2(0 if split.vertical else 420.0, list_scroll.custom_minimum_size.y)
	super._layout()


## Sizes the repair list so the whole panel fits the screen (it scrolls inside).
func _fit(w: float) -> void:
	if list_scroll and is_instance_valid(list_scroll) and not _fitting:
		_fitting = true
		var limit := size.y - 24.0
		list_scroll.custom_minimum_size.y = 0.0
		var base := panel.get_combined_minimum_size().y
		var split_h := split.get_combined_minimum_size().y
		var other := base - split_h
		var want := list_box.get_combined_minimum_size().y
		var room := limit - other
		if split.vertical:
			room -= split.get_child(0).get_combined_minimum_size().y + 12.0
		list_scroll.custom_minimum_size.y = clampf(room, minf(want, 140.0), want)
		_fitting = false
	super._fit(w)


func _process(delta: float) -> void:
	_t += delta
	_celebrate = maxf(0.0, _celebrate - delta)
	for sp in _sparks:
		sp["t"] = float(sp["t"]) + delta
		sp["v"] = (sp["v"] as Vector2) + Vector2(0, 60.0) * delta * float(sp["g"])
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
	_sparks = _sparks.filter(func(sp): return float(sp["t"]) < float(sp["life"]))
	if _celebrate > 0.0 and randf() < 0.5 and scene:
		_burst(Vector2(randf() * scene.size.x, randf() * scene.size.y * 0.6), [UI.GOLD, Color(1.0, 0.6, 0.8), Color(0.6, 1.0, 0.7)][randi() % 3], 6)
	if scene:
		scene.queue_redraw()


# --- state: Yugi is here ------------------------------------------------------------------

func _entry_name(i: int) -> String:
	var e: Dictionary = Game.graveyard[color][i]
	return Game.piece_title(int(e["type"]), color)


func _refresh() -> void:
	if state == "restored":
		_refresh_restored()
		return
	if state != "yugi":
		return
	var graves: Array = Game.graveyard[color]
	reals_btn.text = "Duel For Reals"
	if graves.is_empty():
		info.text = "Nobody of yours rests here yet. Yugi shuffles his deck, a little bored."
		duel_btn.disabled = true
		reals_btn.disabled = true
		duel_btn.text = "Duel Yugi"
		return
	if selected < 0:
		info.text = "Tap a tombstone to choose who to play for."
		duel_btn.disabled = true
		reals_btn.disabled = true
		return
	var nm := _entry_name(selected)
	if not allowed:
		info.text = "Here lies your %s. %s" % [Game.PIECE_NAMES[int(graves[selected]["type"])], why]
		duel_btn.disabled = true
		reals_btn.disabled = true
		duel_btn.text = "Can't duel now"
		return
	info.text = "Win the card duel and the %s returns to the board. Win or lose, the duel uses your turn. Or duel for reals, if you dare." % nm
	duel_btn.disabled = false
	reals_btn.disabled = false
	duel_btn.text = "Duel for the %s" % Game.PIECE_NAMES[int(graves[selected]["type"])]


func _on_duel() -> void:
	if selected < 0 or not allowed:
		return
	var i := selected
	close()
	duel_requested.emit(i)


func _on_reals() -> void:
	if selected < 0 or not allowed or state != "yugi":
		return
	var pname: String = Game.PIECE_NAMES[int(Game.graveyard[color][selected]["type"])]
	var m := Modal.new("Duel For Reals?", 520.0)
	m.add_text("This is a shadow game. You both start with 12,000 LP, and Yugi plays at his very best, whatever the difficulty.")
	m.add_text("Win, and your %s rises while Yugi is dragged into the Shadow Realm forever. Nobody will duel for the dead again." % pname, 17, UI.DIM)
	m.add_text("Lose, run out of time or forfeit, and YOU are sent to the Shadow Realm. That is game over.", 17, UI.EMBER)
	m.add_buttons([["Duel for reals", func():
		m.close()
		_start_reals()], ["Back out", m.close]])
	m.panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.08, 0.04, 0.11, 0.98), Color(0.5, 0.26, 0.7)))
	add_child(m)


func _start_reals() -> void:
	if selected < 0 or not allowed:
		return
	var i := selected
	close()
	reals_requested.emit(i)


# --- state: ruined ------------------------------------------------------------------------

func _refresh_ruined() -> void:
	if state != "ruined":
		return
	var n := Game.grave_repairs.size()
	status.text = "Repaired %d of %d. You have $%d. Repairs cost no turn." % [n, Game.GRAVE_SECTIONS.size(), Game.money]
	for sec in Game.GRAVE_SECTIONS:
		var sid: String = sec["id"]
		var b: Button = section_buttons[sid]
		var cost: Label = section_costs[sid]
		var nm: Label = section_names[sid]
		nm.text = String(sec["name"]) + ("  (repaired)" if Game.grave_repairs.has(sid) else "")
		nm.add_theme_color_override("font_color", UI.GREEN if Game.grave_repairs.has(sid) else UI.GOLD)
		if Game.grave_repairs.has(sid):
			b.text = "Done"
			b.disabled = true
			cost.text = "Mended. It looks lovely."
			cost.add_theme_color_override("font_color", UI.GREEN)
		else:
			var ok := Game.can_repair(sid)
			b.text = "Repair"
			b.disabled = not ok
			cost.text = ("Cost: " if ok else "Need: ") + Game.section_cost_text(sec)
			cost.add_theme_color_override("font_color", UI.TEXT if ok else Color(0.85, 0.55, 0.45))


func _on_repair(sid: String) -> void:
	if state != "ruined" or not Game.can_repair(sid):
		return
	if not Game.repair(sid):
		return
	if scene:
		var spot: Vector2 = SECTION_SPOTS.get(sid, Vector2(0.5, 0.5))
		_burst(spot * scene.size, UI.GOLD, 26)
		_burst(spot * scene.size, Color(0.7, 1.0, 0.75), 14)
	repaired.emit(sid)
	if Game.graveyard_restored():
		_crown()
		return
	_refresh_ruined()


func _crown() -> void:
	_build()
	_celebrate = 3.0
	if Game.gravekeeper == Game.active_side:
		keeper_crowned.emit()
		var m := Modal.new("You are the new Gravekeeper.", 480.0)
		m.add_text("The gate stands straight, the lanterns burn and the flowers bloom. The despair lifts from the board.")
		m.add_text("As keeper you may raise one fallen piece for free, every %d turns. The soil needs its rest in between." % Game.KEEPER_COOLDOWN, 17, UI.DIM)
		m.add_buttons([["Wonderful", m.close]])
		add_child(m)


# --- state: restored ----------------------------------------------------------------------

func _refresh_restored() -> void:
	var graves: Array = Game.graveyard[color]
	raise_btn.text = "Raise this piece (free)"
	raise_btn.disabled = true
	var mine := Game.gravekeeper == Game.active_side
	if not mine:
		info.text = "The %s side keeps this graveyard now. It is peaceful and beautiful, but raising the dead is not yours to do." % Game.color_name(Game.gravekeeper)
		raise_btn.text = "Not your graveyard"
		return
	if graves.is_empty():
		info.text = "You keep a peaceful, beautiful graveyard, and nobody of yours rests in it."
		return
	if selected < 0:
		info.text = "Tap a tombstone to choose who to raise."
		return
	var pn: String = Game.PIECE_NAMES[int(graves[selected]["type"])]
	if Game.keeper_cooldown > 0:
		var n := Game.keeper_cooldown
		info.text = "Here lies your %s, under fresh flowers. The soil needs %d more turn%s before it gives anyone back." % [pn, n, "" if n == 1 else "s"]
		raise_btn.text = "The soil needs %d more turn%s" % [n, "" if n == 1 else "s"]
		return
	if not allowed:
		info.text = "Here lies your %s. %s" % [pn, why]
		raise_btn.text = "Can't raise now"
		return
	info.text = "As Gravekeeper you may raise your %s for free. It uses your turn, and then the soil rests." % pn
	raise_btn.disabled = false


func _on_raise() -> void:
	if state != "restored" or selected < 0 or not allowed:
		return
	if Game.gravekeeper != Game.active_side or Game.keeper_cooldown > 0:
		return
	var i := selected
	close()
	raise_requested.emit(i)


# --- input --------------------------------------------------------------------------------

func _on_scene_input(event: InputEvent) -> void:
	if state == "ruined":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _tombs.size():
			var r: Rect2 = _tombs[i]
			if r.grow(4).has_point(event.position):
				selected = i
				if state == "yugi":
					line = LINES[1] % Game.PIECE_NAMES[int(Game.graveyard[color][i]["type"])]
				_refresh()
				return


func _burst(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(30.0, 120.0), "c": col, "t": 0.0,
			"life": randf_range(0.5, 1.2), "r": randf_range(1.5, 3.5), "g": 1.0})


# --- drawing ------------------------------------------------------------------------------

func _draw_scene() -> void:
	if state == "yugi":
		_draw_yugi_scene()
	else:
		_draw_grounds()
	for sp in _sparks:
		var c: Color = sp["c"]
		c.a = 1.0 - float(sp["t"]) / float(sp["life"])
		scene.draw_circle(sp["p"], float(sp["r"]), c)


func _draw_yugi_scene() -> void:
	var s := scene.size
	var font := ThemeDB.fallback_font
	# night sky, moon and a low fog over the ground
	var bands := 12
	for i in bands:
		var k := float(i) / bands
		scene.draw_rect(Rect2(Vector2(0, s.y * k), Vector2(s.x, s.y / bands + 1)), Color(0.07, 0.06, 0.14).lerp(Color(0.2, 0.13, 0.2), k))
	scene.draw_circle(Vector2(s.x * 0.12, s.y * 0.18), s.y * 0.09, Color(0.95, 0.92, 0.8))
	scene.draw_circle(Vector2(s.x * 0.12 + s.y * 0.035, s.y * 0.16), s.y * 0.08, Color(0.08, 0.07, 0.15))
	for i in 18:
		var star := Vector2(fmod(i * 97.3, s.x), fmod(i * 41.7, s.y * 0.45))
		scene.draw_circle(star, 1.2, Color(1, 1, 1, 0.4 + 0.3 * sin(_t * 2.0 + i)))
	var ground_y := s.y * 0.8
	scene.draw_rect(Rect2(Vector2(0, ground_y), Vector2(s.x, s.y - ground_y)), Color(0.12, 0.1, 0.1))
	# Yugi stands at the right
	var yw := minf(s.x * 0.3, s.y * 0.75)
	var yrect := Rect2(Vector2(s.x - yw - 6, s.y - yw * 1.25 - 4), Vector2(yw, yw * 1.25))
	if yrect.position.y < 4:
		yrect = Rect2(Vector2(s.x - yw - 6, 4), Vector2(yw, s.y - 8))
	_place_tombs(12.0, yrect.position.x - 16, ground_y)
	_draw_tombs(false)
	_low_mist(s, ground_y, 0.05)
	YugiArt.draw(scene, yrect, _t, "smug")
	# speech bubble
	var fs := 15
	var bw := minf(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20, s.x * 0.6)
	var bpos := Vector2(maxf(6, yrect.position.x - bw + yw * 0.3), 8)
	var bubble := Rect2(bpos, Vector2(bw, 30))
	scene.draw_rect(bubble, Color(0.96, 0.94, 0.88))
	# a short tail pointing down toward Yugi
	var mouth := YugiArt.mouth_point(yrect)
	var tail_x := clampf(mouth.x - 60.0, bubble.position.x + 10.0, bubble.end.x - 26.0)
	var tip := Vector2(tail_x + 8.0, bubble.end.y).lerp(mouth, 0.35)
	scene.draw_colored_polygon(PackedVector2Array([Vector2(tail_x, bubble.end.y), Vector2(tail_x + 16.0, bubble.end.y), tip]), Color(0.96, 0.94, 0.88))
	scene.draw_string(font, bpos + Vector2(10, 21), line, HORIZONTAL_ALIGNMENT_LEFT, bw - 16, fs, Color(0.12, 0.08, 0.1))


func _place_tombs(x0: float, area_w: float, ground_y: float) -> void:
	_tombs.clear()
	var n: int = Game.graveyard[color].size()
	if n == 0 or area_w <= 10.0:
		return
	var rows := 1 if n <= 7 else 2
	var per_row := int(ceil(float(n) / rows))
	var tw := minf(area_w / per_row * 0.82, 70.0)
	var th := tw * 1.35
	for i in n:
		var row := i / per_row
		var col := i % per_row
		var x := x0 + col * (area_w / per_row) + (area_w / per_row - tw) * 0.5
		var y := ground_y - th + 6 - (rows - 1 - row) * th * 0.62
		_tombs.append(Rect2(Vector2(x, y), Vector2(tw, th)))


func _draw_tombs(flowers: bool) -> void:
	var graves: Array = Game.graveyard[color]
	for i in _tombs.size():
		var r: Rect2 = _tombs[i]
		_draw_tomb(r, int(graves[i]["type"]), i == selected)
		if flowers:
			for k in 3:
				var fx := r.position.x + r.size.x * (0.2 + k * 0.3)
				var fy := r.end.y + 2.0
				scene.draw_line(Vector2(fx, fy), Vector2(fx, fy - 7), Color(0.3, 0.6, 0.3), 1.5)
				scene.draw_circle(Vector2(fx, fy - 8), 2.6, [Color(1, 0.55, 0.7), Color(1, 0.85, 0.4), Color(0.75, 0.6, 1)][(i + k) % 3])


func _low_mist(s: Vector2, ground_y: float, alpha: float, layers: int = 5) -> void:
	var bounds := Rect2(Vector2.ZERO, s)
	for i in layers:
		var mx := fmod(_t * 10.0 + i * s.x / 4.0, s.x + 200.0) - 200.0
		var my := ground_y - 4.0 + (i % 3) * 7.0 - (i / 3) * 18.0
		for band in [Rect2(Vector2(mx, my), Vector2(200, 5)), Rect2(Vector2(mx + 30, my + 3), Vector2(130, 4))]:
			var clipped: Rect2 = band.intersection(bounds)
			if clipped.has_area():
				scene.draw_rect(clipped, Color(0.75, 0.75, 0.85, alpha))


func _draw_tomb(r: Rect2, t: int, sel: bool) -> void:
	var stone := Color(0.42, 0.41, 0.44) if not sel else Color(0.58, 0.55, 0.5)
	if sel:
		scene.draw_circle(r.get_center(), r.size.x * 0.8, Color(1.0, 0.8, 0.4, 0.12 + 0.05 * sin(_t * 3.0)))
	var top := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		top.append(Vector2(r.get_center().x + cos(a) * r.size.x * 0.5, r.position.y + r.size.x * 0.5 + sin(a) * r.size.x * 0.5))
	top.append(r.end)
	top.append(Vector2(r.position.x, r.end.y))
	scene.draw_colored_polygon(top, stone)
	var closed := top.duplicate()
	closed.append(top[0])
	scene.draw_polyline(closed, Color(0.1, 0.09, 0.1), 2.0, true)
	var ps := r.size.x * 0.42
	PieceArt.draw_piece(scene, t, color == 0, r.get_center().x, r.end.y - r.size.y * 0.12, ps, Color(0.35, 0.33, 0.36, 0.9), false)
	scene.draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 10, r.end.y + 16), Game.PIECE_NAMES[t], HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20, 15, UI.GOLD if sel else UI.DIM)


# --- the ruined / restored grounds ------------------------------------------------------------

func _fixed(id: String) -> bool:
	return Game.grave_repairs.has(id)


## How mended the place is, 0..1 (drives the palette and the fog).
func _progress() -> float:
	return float(Game.grave_repairs.size()) / float(Game.GRAVE_SECTIONS.size())


func _grow_tree(segs: Array, from: Vector2, ang: float, length: float, width: float, depth: int, rng: RandomNumberGenerator) -> void:
	var to := from + Vector2.from_angle(ang) * length
	segs.append([from, to, width])
	if depth <= 0:
		return
	var kids := 2 if depth > 1 else 3
	for k in kids:
		var spread := rng.randf_range(0.35, 0.75) * (1.0 if k % 2 == 0 else -1.0)
		_grow_tree(segs, to, ang + spread + rng.randf_range(-0.15, 0.15), length * rng.randf_range(0.62, 0.78), width * 0.68, depth - 1, rng)


func _draw_tree(segs: Array, base: Vector2, h: float, bloom: float) -> void:
	var bark := Color(0.06, 0.05, 0.06).lerp(Color(0.24, 0.17, 0.12), bloom)
	var tips: Array = []
	for sg in segs:
		var a: Vector2 = base + (sg[0] as Vector2) * h
		var b: Vector2 = base + (sg[1] as Vector2) * h
		scene.draw_line(a, b, bark, maxf(1.0, float(sg[2]) * h), true)
		if float(sg[2]) < 0.015:
			tips.append(b)
	if bloom <= 0.0:
		return
	for i in tips.size():
		var p: Vector2 = tips[i]
		var sway := Vector2(sin(_t * 1.2 + i) * 1.5, 0)
		scene.draw_circle(p + sway, h * 0.07 * bloom, Color(0.22, 0.42, 0.24, 0.85))
		if bloom >= 1.0 and i % 3 == 0:
			scene.draw_circle(p + sway + Vector2(2, -2), h * 0.025, Color(1.0, 0.7, 0.8))


func _draw_grounds() -> void:
	var s := scene.size
	var p := _progress()
	var restored := state == "restored"
	var ground_y := s.y * 0.8
	# sky: dead grey-black, warming toward a violet dusk as the place heals
	var sky_top := Color(0.04, 0.04, 0.06).lerp(Color(0.12, 0.1, 0.26), p)
	var sky_bot := Color(0.17, 0.16, 0.18).lerp(Color(0.5, 0.3, 0.34), p)
	scene.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, ground_y), Vector2(0, ground_y)]),
		PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))
	var moon := Vector2(s.x * 0.36, s.y * 0.16)
	scene.draw_circle(moon, s.y * 0.07, Color(0.75, 0.75, 0.7, 0.35 + 0.6 * p))
	if p < 1.0:
		# clouds smothering the moon
		for i in 3:
			var cx := moon.x + (i - 1) * s.y * 0.09 + sin(_t * 0.2 + i) * 6.0
			scene.draw_set_transform(Vector2(cx, moon.y + s.y * 0.02), 0.0, Vector2(1.0, 0.35))
			scene.draw_circle(Vector2.ZERO, s.y * 0.1, Color(0.12, 0.11, 0.12, 0.85 * (1.0 - p)))
		scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var stars := int(4 + 18 * p)
	for i in stars:
		var star := Vector2(fmod(i * 97.3 + 13.0, s.x), fmod(i * 41.7, s.y * 0.45))
		scene.draw_circle(star, 1.2, Color(1, 1, 1, (0.3 + 0.3 * sin(_t * 2.0 + i)) * (0.3 + 0.7 * p)))
	# a far hill
	var hill := PackedVector2Array([Vector2(0, ground_y)])
	for i in 13:
		var x := s.x * i / 12.0
		hill.append(Vector2(x, ground_y - s.y * (0.1 + 0.05 * sin(i * 1.3))))
	hill.append(Vector2(s.x, ground_y))
	scene.draw_colored_polygon(hill, Color(0.06, 0.06, 0.07).lerp(Color(0.16, 0.14, 0.2), p))
	# trees: dead until the flowers come back
	var bloom := 0.0
	if _fixed("flowers"):
		bloom = 1.0 if restored else 0.6
	_draw_tree(_trees[0], Vector2(s.x * 0.21, ground_y + 2), s.y * 0.62, bloom)
	_draw_tree(_trees[1], Vector2(s.x * 0.95, ground_y + 2), s.y * 0.55, bloom)
	_draw_crypt(Rect2(s.x * 0.57, ground_y - s.y * 0.3, s.x * 0.14, s.y * 0.3), ground_y)
	_draw_headstones(s, ground_y)
	# ground
	scene.draw_rect(Rect2(Vector2(0, ground_y), Vector2(s.x, s.y - ground_y)), Color(0.08, 0.07, 0.07).lerp(Color(0.13, 0.2, 0.13), p))
	if not restored:
		for i in 4:
			scene.draw_set_transform(Vector2(s.x * (0.15 + i * 0.22), ground_y + s.y * (0.06 + 0.04 * (i % 2))), 0.0, Vector2(1.0, 0.25))
			scene.draw_circle(Vector2.ZERO, s.x * 0.04, Color(0.03, 0.03, 0.05, 0.8))
		scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		for i in 40:
			var gx := fmod(i * 37.7, s.x)
			var gy := ground_y + fmod(i * 13.3, s.y - ground_y)
			scene.draw_line(Vector2(gx, gy), Vector2(gx + sin(_t + i) * 1.5, gy - 5), Color(0.25, 0.45, 0.25), 1.5)
	_draw_lanterns(s, ground_y)
	_draw_shed(Rect2(s.x * 0.83, ground_y - s.y * 0.34, s.x * 0.15, s.y * 0.34))
	_draw_table(Vector2(s.x * 0.74, ground_y + s.y * 0.1), s)
	_draw_gate(s, ground_y)
	if restored:
		_place_tombs(s.x * 0.25, s.x * 0.42, ground_y + s.y * 0.06)
		_draw_tombs(true)
		_draw_keeper(Vector2(s.x * 0.69, ground_y + s.y * 0.12), s.y * 0.3)
	else:
		_tombs.clear()
	if not restored:
		_draw_flower_beds(s)
	# fog: thick and grey while ruined, thinning as it heals
	if not restored:
		var fog := 0.09 * (1.0 - p) + 0.03
		ShadowArt.mist(scene, Rect2(Vector2.ZERO, s), _t, Color(0.62, 0.62, 0.7, fog), 10, 0.6, 1.0)
		ShadowArt.mist(scene, Rect2(Vector2.ZERO, s), _t * 0.6, Color(0.55, 0.55, 0.62, fog * 0.6), 5, 0.3, 0.55)
		scene.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.02, 0.15 * (1.0 - p)))
	else:
		ShadowArt.mist(scene, Rect2(Vector2.ZERO, s), _t, Color(0.85, 0.8, 0.9, 0.035), 5, 0.75, 1.0)
		for i in 12:
			var ff := Vector2(fmod(i * 71.3 + sin(_t * 0.5 + i) * 20.0, s.x), s.y * (0.45 + 0.35 * fmod(i * 0.37, 1.0)) + cos(_t * 0.7 + i) * 8.0)
			scene.draw_circle(ff, 2.0, Color(1.0, 0.95, 0.5, 0.4 + 0.4 * sin(_t * 3.0 + i)))
	if _celebrate > 0.0:
		var font := ThemeDB.fallback_font
		var txt := "THE NEW GRAVEKEEPER"
		var fs := int(clampf(s.x * 0.05, 16.0, 30.0))
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a := clampf(_celebrate, 0.0, 1.0)
		scene.draw_string_outline(font, Vector2((s.x - tw) * 0.5, s.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a))
		scene.draw_string(font, Vector2((s.x - tw) * 0.5, s.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.GOLD, a))


func _draw_crypt(r: Rect2, ground_y: float) -> void:
	var fixed := _fixed("crypt")
	var stone := Color(0.22, 0.21, 0.23) if not fixed else Color(0.48, 0.45, 0.47)
	var body := Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * 0.7))
	scene.draw_rect(body, stone)
	scene.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 4, body.position.y), Vector2(r.get_center().x, r.position.y),
		Vector2(r.end.x + 4, body.position.y)]), stone.darkened(0.15))
	for k in 2:
		var cx := r.position.x + r.size.x * (0.15 + 0.7 * k)
		scene.draw_rect(Rect2(cx - 3, body.position.y + 2, 6, body.size.y - 2), stone.lightened(0.1))
	var door := Rect2(r.get_center().x - r.size.x * 0.17, body.end.y - body.size.y * 0.62, r.size.x * 0.34, body.size.y * 0.62)
	scene.draw_rect(door, Color(0.03, 0.03, 0.04) if not fixed else Color(0.3, 0.2, 0.14))
	if fixed:
		scene.draw_circle(door.get_center() + Vector2(door.size.x * 0.25, 0), 2.0, UI.GOLD)
		scene.draw_arc(Vector2(r.get_center().x, body.position.y + body.size.y * 0.18), r.size.x * 0.1, 0.0, TAU, 16, Color(0.35, 0.6, 0.35), 3.0)
		# dry steps
		for k in 2:
			scene.draw_rect(Rect2(door.position.x - 6 - k * 5, ground_y - 3 + k * 4, door.size.x + 12 + k * 10, 4), stone.darkened(0.1 * k))
	else:
		# black water spilling out of the door, something bobbing in it
		var pool := Vector2(r.get_center().x, ground_y + 6)
		scene.draw_set_transform(pool, 0.0, Vector2(1.0, 0.22))
		scene.draw_circle(Vector2.ZERO, r.size.x * 0.75, Color(0.02, 0.03, 0.06, 0.95))
		for k in 3:
			var rr := r.size.x * (0.2 + 0.22 * k) + fmod(_t * 6.0, 10.0)
			scene.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 24, Color(0.4, 0.45, 0.6, 0.25), 2.0)
		scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bob := pool + Vector2(r.size.x * 0.25, -1.0 + sin(_t * 2.0) * 1.5)
		scene.draw_line(bob, bob + Vector2(10, -2), Color(0.75, 0.77, 0.8), 1.5)
		scene.draw_circle(bob, 2.4, Color(0.75, 0.77, 0.8))
		# a crack down the front
		scene.draw_polyline(PackedVector2Array([Vector2(r.position.x + r.size.x * 0.8, body.position.y), Vector2(r.position.x + r.size.x * 0.72, body.position.y + body.size.y * 0.3),
			Vector2(r.position.x + r.size.x * 0.84, body.position.y + body.size.y * 0.55)]), Color(0.05, 0.05, 0.06), 1.5)


func _draw_headstones(s: Vector2, ground_y: float) -> void:
	var fixed := _fixed("stones")
	for i in 4:
		var x := s.x * (0.3 + i * 0.075)
		var w := s.x * 0.04
		var h := s.y * (0.14 + 0.02 * (i % 2))
		var base := Vector2(x, ground_y - s.y * 0.06)
		var stone := Color(0.24, 0.23, 0.25) if not fixed else Color(0.52, 0.5, 0.53)
		if fixed:
			scene.draw_rect(Rect2(base.x - w * 0.5, base.y - h, w, h), stone)
			scene.draw_circle(Vector2(base.x, base.y - h), w * 0.5, stone)
			scene.draw_line(Vector2(base.x, base.y - h * 0.85), Vector2(base.x, base.y - h * 0.45), stone.darkened(0.35), 1.5)
			scene.draw_line(Vector2(base.x - w * 0.2, base.y - h * 0.72), Vector2(base.x + w * 0.2, base.y - h * 0.72), stone.darkened(0.35), 1.5)
		elif i % 2 == 0:
			# snapped in half: a stump and the top lying in the grass
			scene.draw_colored_polygon(PackedVector2Array([Vector2(base.x - w * 0.5, base.y), Vector2(base.x - w * 0.5, base.y - h * 0.45),
				Vector2(base.x - w * 0.1, base.y - h * 0.55), Vector2(base.x + w * 0.2, base.y - h * 0.4), Vector2(base.x + w * 0.5, base.y - h * 0.5),
				Vector2(base.x + w * 0.5, base.y)]), stone)
			scene.draw_set_transform(base + Vector2(w * 1.1, -w * 0.25), 1.35, Vector2.ONE)
			scene.draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h * 0.5), stone.darkened(0.1))
			scene.draw_circle(Vector2(0, -h * 0.5), w * 0.5, stone.darkened(0.1))
			scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			# toppled over, cracked
			scene.draw_set_transform(base, -0.5, Vector2.ONE)
			scene.draw_rect(Rect2(-w * 0.5, -h, w, h), stone)
			scene.draw_circle(Vector2(0, -h), w * 0.5, stone)
			scene.draw_polyline(PackedVector2Array([Vector2(-w * 0.3, -h * 0.9), Vector2(w * 0.1, -h * 0.6), Vector2(-w * 0.1, -h * 0.3)]), Color(0.05, 0.05, 0.06), 1.5)
			scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_lanterns(s: Vector2, ground_y: float) -> void:
	var lit := _fixed("lanterns")
	for i in 3:
		var x: float = s.x * [0.26, 0.53, 0.79][i]
		var top := Vector2(x, ground_y - s.y * 0.42)
		var post := Color(0.12, 0.11, 0.12) if not lit else Color(0.2, 0.17, 0.16)
		scene.draw_line(Vector2(x, ground_y + 4), top, post, 3.0)
		scene.draw_line(top, top + Vector2(s.x * 0.03, 0), post, 2.5)
		var hang := top + Vector2(s.x * 0.03, 4)
		var lw := s.x * 0.022
		if lit:
			var fl := 0.85 + 0.15 * sin(_t * 9.0 + i * 2.0)
			for k in 4:
				scene.draw_circle(hang + Vector2(0, lw), lw * (3.2 - k * 0.6) * fl, Color(1.0, 0.75, 0.35, 0.07))
			scene.draw_rect(Rect2(hang.x - lw * 0.5, hang.y, lw, lw * 1.5), Color(1.0, 0.82, 0.45))
			scene.draw_rect(Rect2(hang.x - lw * 0.5, hang.y, lw, lw * 1.5), Color(0.2, 0.15, 0.1), false, 1.5)
			scene.draw_circle(hang + Vector2(0, lw * 0.8), lw * 0.25 * fl, Color(1, 1, 0.8))
		elif i == 1:
			# this one lies smashed at the foot of its post
			var g := Vector2(x + 8, ground_y + 2)
			scene.draw_set_transform(g, 1.2, Vector2.ONE)
			scene.draw_rect(Rect2(-lw * 0.5, -lw * 1.5, lw, lw * 1.5), Color(0.15, 0.14, 0.15))
			scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in 4:
				scene.draw_line(g + Vector2(k * 4 - 6, 2), g + Vector2(k * 4 - 3, 0), Color(0.5, 0.55, 0.6, 0.6), 1.0)
		else:
			# dangling at an angle, glass broken out
			scene.draw_set_transform(hang, 0.4 + sin(_t * 1.5 + i) * 0.08, Vector2.ONE)
			scene.draw_rect(Rect2(-lw * 0.5, 0, lw, lw * 1.5), Color(0.08, 0.08, 0.09))
			scene.draw_polyline(PackedVector2Array([Vector2(-lw * 0.5, 0), Vector2(0, lw * 0.6), Vector2(-lw * 0.2, lw * 1.0), Vector2(lw * 0.5, lw * 1.5)]), Color(0.45, 0.5, 0.55, 0.7), 1.0)
			scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shed(r: Rect2) -> void:
	var fixed := _fixed("shed")
	var wood := Color(0.17, 0.12, 0.1) if not fixed else Color(0.42, 0.28, 0.18)
	var body := Rect2(r.position + Vector2(0, r.size.y * 0.3), Vector2(r.size.x, r.size.y * 0.7))
	scene.draw_rect(body, wood)
	var planks := 5
	for k in planks:
		var px := body.position.x + body.size.x * k / planks
		scene.draw_line(Vector2(px, body.position.y), Vector2(px, body.end.y), wood.darkened(0.3), 1.0)
	var roof := Color(0.1, 0.08, 0.08) if not fixed else Color(0.45, 0.18, 0.15)
	if fixed:
		scene.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 5, body.position.y), Vector2(r.get_center().x, r.position.y),
			Vector2(r.end.x + 5, body.position.y)]), roof)
		# chimney with a little smoke
		var ch := Rect2(r.position.x + r.size.x * 0.68, r.position.y + r.size.y * 0.06, r.size.x * 0.12, r.size.y * 0.2)
		scene.draw_rect(ch, Color(0.35, 0.25, 0.22))
		for k in 3:
			var ph := fmod(_t * 0.5 + k / 3.0, 1.0)
			scene.draw_circle(Vector2(ch.get_center().x + sin(_t + k) * 4.0, ch.position.y - ph * r.size.y * 0.4), 3.0 + ph * 5.0, Color(0.8, 0.8, 0.85, 0.3 * (1.0 - ph)))
	else:
		# caved-in roof
		scene.draw_colored_polygon(PackedVector2Array([Vector2(r.position.x - 5, body.position.y), Vector2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.1),
			Vector2(r.get_center().x, r.position.y + r.size.y * 0.26), Vector2(r.position.x + r.size.x * 0.75, r.position.y + r.size.y * 0.08),
			Vector2(r.end.x + 5, body.position.y)]), roof)
		# a missing board
		scene.draw_rect(Rect2(body.position.x + body.size.x * 0.6, body.position.y + body.size.y * 0.35, body.size.x / planks, body.size.y * 0.5), Color(0.02, 0.02, 0.02))
	var win := Rect2(body.position.x + body.size.x * 0.15, body.position.y + body.size.y * 0.2, body.size.x * 0.32, body.size.y * 0.3)
	if fixed:
		for k in 3:
			scene.draw_circle(win.get_center(), win.size.x * (1.4 - k * 0.3), Color(1.0, 0.75, 0.35, 0.08))
		scene.draw_rect(win, Color(1.0, 0.78, 0.4))
	else:
		scene.draw_rect(win, Color(0.03, 0.03, 0.04))
		scene.draw_polyline(PackedVector2Array([win.position, win.get_center() + Vector2(2, -1), Vector2(win.end.x, win.position.y + 3)]), Color(0.5, 0.55, 0.6, 0.6), 1.0)
	scene.draw_line(Vector2(win.get_center().x, win.position.y), Vector2(win.get_center().x, win.end.y), wood.darkened(0.4), 1.5)
	scene.draw_line(Vector2(win.position.x, win.get_center().y), Vector2(win.end.x, win.get_center().y), wood.darkened(0.4), 1.5)
	var door := Rect2(body.position.x + body.size.x * 0.58, body.end.y - body.size.y * 0.6, body.size.x * 0.3, body.size.y * 0.6)
	scene.draw_rect(door, wood.darkened(0.35))


## Yugi's old card table: a few cards left where they fell and an empty chair.
func _draw_table(c: Vector2, s: Vector2) -> void:
	var w := s.x * 0.09
	var h := s.y * 0.11
	var wood := Color(0.2, 0.15, 0.12) if state != "restored" else Color(0.38, 0.26, 0.17)
	scene.draw_rect(Rect2(c.x - w * 0.5, c.y - h, w, 4), wood.lightened(0.1))
	scene.draw_line(Vector2(c.x - w * 0.4, c.y - h + 4), Vector2(c.x - w * 0.4, c.y), wood, 2.0)
	scene.draw_line(Vector2(c.x + w * 0.4, c.y - h + 4), Vector2(c.x + w * 0.4, c.y), wood, 2.0)
	for k in 3:
		scene.draw_set_transform(Vector2(c.x - w * 0.25 + k * w * 0.22, c.y - h - 1), -0.3 + k * 0.35, Vector2.ONE)
		scene.draw_rect(Rect2(-3, -2, 7, 3), Color(0.55, 0.25, 0.3) if k != 1 else Color(0.85, 0.8, 0.7))
	scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state != "restored":
		# a card face-down in the mud, and the chair knocked over
		scene.draw_set_transform(c + Vector2(w * 0.8, 1), 0.2, Vector2.ONE)
		scene.draw_rect(Rect2(-4, -2, 8, 4), Color(0.4, 0.2, 0.25))
		scene.draw_set_transform(c + Vector2(-w * 0.85, -2), 1.4, Vector2.ONE)
	else:
		scene.draw_set_transform(c + Vector2(-w * 0.85, 0), 0.0, Vector2.ONE)
	var cw := w * 0.4
	scene.draw_line(Vector2(-cw * 0.5, 0), Vector2(-cw * 0.5, -h * 0.6), wood, 2.0)
	scene.draw_line(Vector2(cw * 0.5, 0), Vector2(cw * 0.5, -h * 0.6), wood, 2.0)
	scene.draw_line(Vector2(-cw * 0.5, -h * 0.6), Vector2(cw * 0.5, -h * 0.6), wood, 2.5)
	scene.draw_line(Vector2(-cw * 0.5, -h * 0.6), Vector2(-cw * 0.5, -h * 1.3), wood, 2.0)
	scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_gate(s: Vector2, ground_y: float) -> void:
	var fixed := _fixed("gate")
	var iron := Color(0.05, 0.045, 0.05) if not fixed else Color(0.18, 0.16, 0.18)
	var stone := Color(0.2, 0.19, 0.21) if not fixed else Color(0.5, 0.48, 0.5)
	var lx := s.x * 0.02
	var rx := s.x * 0.15
	var ph := s.y * 0.42
	var pw := s.x * 0.025
	# fence running off to the right of the gate
	for k in 4:
		var fx := rx + pw + k * s.x * 0.015
		var lean := 0.0 if fixed else (k % 2) * 0.25
		scene.draw_line(Vector2(fx, ground_y + 2), Vector2(fx + sin(lean) * s.y * 0.2, ground_y - s.y * 0.2 * cos(lean)), iron, 2.0)
	scene.draw_rect(Rect2(lx, ground_y - ph, pw, ph + 4), stone)
	scene.draw_rect(Rect2(rx, ground_y - ph, pw, ph + 4), stone)
	if not fixed:
		# a chunk missing from the right post's cap
		scene.draw_colored_polygon(PackedVector2Array([Vector2(rx - 1, ground_y - ph - 1), Vector2(rx + pw + 1, ground_y - ph - 1), Vector2(rx + pw + 1, ground_y - ph + 8), Vector2(rx + pw * 0.4, ground_y - ph + 3)]), Color(0.03, 0.03, 0.045))
	var gw := (rx - lx - pw) * 0.5
	var gx := lx + pw
	var gh := ph * 0.8
	if fixed:
		for k in 2:
			var x0 := gx + k * gw
			scene.draw_rect(Rect2(x0, ground_y - gh, gw, gh), iron, false, 2.0)
			for b in 4:
				var bx := x0 + gw * (b + 0.5) / 4.0
				scene.draw_line(Vector2(bx, ground_y - gh), Vector2(bx, ground_y), iron, 1.5)
				scene.draw_circle(Vector2(bx, ground_y - gh - 3), 1.8, iron)
		scene.draw_arc(Vector2((lx + rx + pw) * 0.5, ground_y - ph), (rx - lx) * 0.5, PI, TAU, 18, iron, 2.5)
	else:
		# the left leaf hangs from its top hinge, the right one lies in the mud
		scene.draw_set_transform(Vector2(gx, ground_y - gh), 0.55 + sin(_t * 1.1) * 0.05, Vector2.ONE)
		scene.draw_rect(Rect2(0, 0, gw, gh), iron, false, 2.0)
		for b in 4:
			var bx2 := gw * (b + 0.5) / 4.0
			scene.draw_line(Vector2(bx2, 0), Vector2(bx2, gh), iron, 1.5)
		scene.draw_set_transform(Vector2(gx + gw * 0.6, ground_y + 3), -0.12, Vector2(1.0, 0.3))
		scene.draw_rect(Rect2(0, -gh, gw * 1.2, gh), iron, false, 2.0)
		scene.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flower_beds(s: Vector2) -> void:
	var blooming := _fixed("flowers")
	var y := s.y * 0.97
	var n := 14
	for i in n:
		var x := s.x * (0.24 + 0.44 * i / float(n - 1))
		var sway := sin(_t * 1.6 + i) * 1.5
		if blooming:
			var h := s.y * (0.05 + 0.02 * (i % 3))
			scene.draw_line(Vector2(x, y), Vector2(x + sway, y - h), Color(0.3, 0.6, 0.3), 1.5)
			var col: Color = [Color(1.0, 0.45, 0.6), Color(1.0, 0.85, 0.35), Color(0.7, 0.55, 1.0), Color(1.0, 0.6, 0.3)][i % 4]
			for k in 5:
				scene.draw_circle(Vector2(x + sway, y - h) + Vector2.from_angle(TAU * k / 5.0 + _t * 0.3) * 2.5, 2.2, col)
			scene.draw_circle(Vector2(x + sway, y - h), 1.6, Color(1, 0.95, 0.6))
		elif i == 9:
			# the one stubborn weed
			scene.draw_line(Vector2(x, y), Vector2(x + sway, y - s.y * 0.07), Color(0.35, 0.55, 0.2), 1.5)
			scene.draw_line(Vector2(x + sway * 0.5, y - s.y * 0.035), Vector2(x + 5, y - s.y * 0.05), Color(0.35, 0.55, 0.2), 1.5)
		else:
			# a dead stalk, drooping
			var top := Vector2(x + 2, y - s.y * 0.04)
			scene.draw_line(Vector2(x, y), top, Color(0.25, 0.2, 0.14), 1.2)
			scene.draw_line(top, top + Vector2(3, 3), Color(0.25, 0.2, 0.14), 1.2)
			scene.draw_circle(top + Vector2(3, 3), 1.4, Color(0.22, 0.16, 0.12))


## You, the Gravekeeper: a hooded figure holding a lantern, in your side's colours.
func _draw_keeper(base: Vector2, h: float) -> void:
	var keeper := Game.gravekeeper
	var cloak := Color(0.82, 0.78, 0.7) if keeper == 0 else Color(0.18, 0.15, 0.2)
	var edge := Color(0.2, 0.15, 0.12) if keeper == 0 else Color(0.75, 0.62, 0.45)
	var w := h * 0.36
	var robe := PackedVector2Array([Vector2(base.x - w * 0.5, base.y), Vector2(base.x - w * 0.22, base.y - h * 0.72), Vector2(base.x, base.y - h * 0.82),
		Vector2(base.x + w * 0.22, base.y - h * 0.72), Vector2(base.x + w * 0.5, base.y)])
	scene.draw_colored_polygon(robe, cloak)
	var closed := robe.duplicate()
	closed.append(robe[0])
	scene.draw_polyline(closed, edge, 1.5, true)
	var head := Vector2(base.x, base.y - h * 0.82)
	scene.draw_circle(head, w * 0.24, cloak)
	scene.draw_arc(head, w * 0.24, 0.0, TAU, 16, edge, 1.5)
	scene.draw_circle(head + Vector2(w * 0.04, w * 0.03), w * 0.13, Color(0.05, 0.04, 0.05))
	# lantern on an outstretched arm
	var hand := Vector2(base.x + w * 0.55, base.y - h * 0.5)
	scene.draw_line(Vector2(base.x + w * 0.15, base.y - h * 0.62), hand, cloak.darkened(0.2), 3.0)
	var fl := 0.85 + 0.15 * sin(_t * 8.0)
	for k in 3:
		scene.draw_circle(hand + Vector2(0, 8), w * (0.6 - k * 0.15) * fl, Color(1.0, 0.78, 0.35, 0.1))
	scene.draw_rect(Rect2(hand.x - 3, hand.y + 3, 6, 9), Color(1.0, 0.82, 0.45))
	scene.draw_rect(Rect2(hand.x - 3, hand.y + 3, 6, 9), Color(0.2, 0.15, 0.1), false, 1.0)
