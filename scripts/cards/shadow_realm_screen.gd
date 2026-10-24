class_name ShadowRealmScreen
extends Control
## Game over: you lost a shadow game and were sent to the Shadow Realm. A
## swirling purple-green void full of broken chess pieces and torn cards, your
## silhouette drifting through it, slow text, then New Game / Main Menu.
## Call setup(info) before add_child; info may hold "piece" (the piece you
## played for: a type 1..6 or a name). Emits finished("new_game" / "menu").

signal finished(choice: String)

const LINES := [
	"You have been sent to the Shadow Realm.",
	"There is no board here. No turns. No moves.",
	"Only the mist, and the cards, and the long, long dark.",
]

var info: Dictionary = {}
var piece_name := ""
var t := 0.0
var drone: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _debris: Array = [] # floating broken pieces and torn cards
var _motes: Array = []
var _text_box: VBoxContainer
var _labels: Array = []
var _modal_shown := false
var _emitted := false
var _skip := 0.0 # tapping hurries the text along
var _debug_gp := "" # testing hook: ?screen=shadow&gp=yugi|ruined|restored shows the graveyard panel


func setup(i: Dictionary) -> void:
	info = i
	var p = i.get("piece", null)
	if p is int or p is float:
		var pt := clampi(int(p), 1, 6)
		piece_name = Game.PIECE_NAMES[pt]
	elif p is String and String(p) != "":
		piece_name = String(p)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_gp = _url_param("gp")
	if _debug_gp != "":
		_debug_panel.call_deferred()
		return
	_rng.seed = 6661
	var ids: Array = CardData.all_ids()
	for k in 16:
		var card := k % 3 == 0
		_debris.append({
			"card": card, "id": String(ids[_rng.randi() % ids.size()]), "type": _rng.randi_range(1, 6), "white": _rng.randf() < 0.5,
			"orbit": _rng.randf_range(0.18, 0.62), "ang": _rng.randf() * TAU, "spd": _rng.randf_range(0.04, 0.12) * (1.0 if k % 2 == 0 else -1.0),
			"spin": _rng.randf_range(-0.6, 0.6), "size": _rng.randf_range(0.07, 0.13), "depth": _rng.randf_range(0.4, 1.0),
			"back": _rng.randf() < 0.4, "crack": _rng.randf_range(0.35, 0.65),
		})
	for k in 70:
		_motes.append({"p": Vector2(_rng.randf(), _rng.randf()), "v": _rng.randf_range(0.004, 0.02), "r": _rng.randf_range(1.0, 2.6), "g": _rng.randf() < 0.35})
	_text_box = VBoxContainer.new()
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.add_theme_constant_override("separation", 14)
	add_child(_text_box)
	var lines: Array = LINES.duplicate()
	if piece_name != "":
		lines.insert(1, "You played for your %s, and you lost everything." % piece_name)
	for k in lines.size():
		var l := UI.label(String(lines[k]), 30 if k == 0 else 19, Color(0.82, 0.68, 1.0) if k == 0 else Color(0.7, 0.85, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		l.modulate.a = 0.0
		_text_box.add_child(l)
		_labels.append(l)
	resized.connect(_place_text)
	_place_text()
	drone = ShadowArt.play_drone(self, "realm", -11.0)


func _exit_tree() -> void:
	if drone:
		drone.stop()


func _place_text() -> void:
	if _text_box == null:
		return
	var w := minf(size.x - 32.0, 760.0)
	_text_box.size = Vector2(w, 0)
	_text_box.position = Vector2((size.x - w) * 0.5, size.y * 0.1)


## When each line starts to fade in (seconds).
func _line_start(k: int) -> float:
	return 1.2 + k * 2.6


func _process(delta: float) -> void:
	if _debug_gp != "":
		return
	t += delta * (1.0 + _skip)
	_skip = maxf(0.0, _skip - delta * 2.0)
	_text_box.size = Vector2(_text_box.size.x, 0.0) # shrink back to the wrapped text
	for k in _labels.size():
		var l: Label = _labels[k]
		var a := clampf((t - _line_start(k)) / 1.6, 0.0, 1.0)
		if _modal_shown and k > 0:
			a = minf(l.modulate.a, 1.0) - delta * 1.5 # only the title stays above the menu
		l.modulate.a = clampf(a, 0.0, 1.0)
	if not _modal_shown and t > _line_start(_labels.size() - 1) + 2.4:
		_show_modal()
	for m in _motes:
		var p: Vector2 = m["p"]
		p.y -= float(m["v"]) * delta
		p.x += sin(t * 0.3 + p.y * 6.0) * 0.002 * delta
		if p.y < -0.02:
			p.y = 1.02
		m["p"] = p
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not _modal_shown:
			_skip = 6.0


func _show_modal() -> void:
	_modal_shown = true
	var m := Modal.new("Game Over", 440.0)
	m.sticky = true
	m.add_text("Your soul drifts in the Shadow Realm. Perhaps another commander, on another board, will fare better.", 17, UI.DIM)
	var row := m.add_buttons([["New Game", func(): _finish("new_game")], ["Main Menu", func(): _finish("menu")]])
	row.add_theme_constant_override("separation", 12)
	add_child(m)
	move_child(_text_box, get_child_count() - 1) # the title stays bright above the dimmer
	m.panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.06, 0.03, 0.09, 0.96), Color(0.5, 0.26, 0.7)))


func _finish(choice: String) -> void:
	if _emitted:
		return
	_emitted = true
	if drone:
		drone.create_tween().tween_property(drone, "volume_db", -40.0, 0.4)
	finished.emit(choice)


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if _debug_gp != "":
		draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
		return
	var s := size
	var c := s * Vector2(0.5, 0.56)
	var big := s.length()
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color(0.07, 0.02, 0.1), Color(0.03, 0.06, 0.06), Color(0.01, 0.03, 0.02), Color(0.05, 0.01, 0.07)]))
	# two vortices turning against each other: purple outside, green inside
	ShadowArt.vortex(self, c, big * 0.62, t * 0.18, 0.55, 0.15, 8)
	ShadowArt.vortex(self, c, big * 0.36, -t * 0.32, 0.65, 0.9, 6)
	# drifting motes
	for m in _motes:
		var p: Vector2 = (m["p"] as Vector2) * s
		var col := ShadowArt.GREEN if bool(m["g"]) else Color(0.7, 0.5, 1.0)
		draw_circle(p, float(m["r"]), Color(col, 0.25 + 0.2 * sin(t * 1.7 + p.x)))
	# far debris first, then the drifting soul, then near debris
	for d in _debris:
		if bool(d["back"]):
			_draw_debris(d, c)
	_draw_soul(c)
	for d in _debris:
		if not bool(d["back"]):
			_draw_debris(d, c)
	ShadowArt.mist(self, Rect2(Vector2.ZERO, s), t, Color(0.5, 0.35, 0.7, 0.06), 10, 0.65, 1.0)
	ShadowArt.mist(self, Rect2(Vector2.ZERO, s), t * 0.8, Color(0.3, 0.8, 0.5, 0.04), 7, 0.0, 0.35)
	# vignette
	for i in 6:
		var k := float(i) / 6.0
		draw_arc(c, big * (0.55 + k * 0.12), 0.0, TAU, 48, Color(0, 0, 0, 0.12), big * 0.08, false)


func _draw_debris(d: Dictionary, c: Vector2) -> void:
	var s := size
	var u := minf(s.x, s.y)
	var a := float(d["ang"]) + t * float(d["spd"])
	var orbit := float(d["orbit"])
	var p := c + Vector2(cos(a) * s.x * orbit * 0.85, sin(a) * s.y * orbit * 0.55) + Vector2(0, sin(t * 0.7 + a * 3.0) * u * 0.02)
	var depth := float(d["depth"])
	var sz := u * float(d["size"]) * (0.55 + 0.45 * depth)
	var rot := t * float(d["spin"]) + a
	var fade := Color(1, 1, 1, 0.45 + 0.5 * depth)
	if bool(d["card"]):
		var r := Rect2(Vector2(-sz * 0.5, -sz * 0.7), Vector2(sz, sz * 1.4))
		draw_set_transform(p, rot, Vector2.ONE)
		if int(d["type"]) % 2 == 0:
			CardArt.draw_back(self, r, t)
		else:
			CardArt.draw_card(self, r, String(d["id"]), {"t": t, "white": bool(d["white"])})
		# a torn-off corner, the void showing through
		var cy := float(d["crack"])
		var tear := PackedVector2Array([Vector2(r.end.x + 2, r.position.y + r.size.y * cy), Vector2(r.end.x - sz * 0.3, r.position.y + r.size.y * (cy + 0.06)),
			Vector2(r.end.x - sz * 0.18, r.position.y + r.size.y * (cy + 0.14)), Vector2(r.end.x - sz * 0.42, r.end.y + 2), Vector2(r.end.x + 2, r.end.y + 2)])
		draw_colored_polygon(tear, Color(0.03, 0.02, 0.05))
		draw_polyline(tear, Color(ShadowArt.GREEN, 0.35), 1.0, true)
		draw_rect(Rect2(r.position, r.size), Color(0.05, 0.0, 0.1, 1.0 - fade.a), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# a broken chess piece: the top half floats off its base along a jagged crack
	var ty := int(d["type"])
	var white := bool(d["white"])
	var h := PieceArt.height(ty) * sz
	var by := h * 0.5
	var cut_y := by - h * float(d["crack"])
	var drift := sz * (0.14 + 0.06 * sin(t * 1.1 + a))
	var jag := PackedVector2Array()
	var n := 7
	for j in n + 1:
		var x := lerpf(-sz * 0.6, sz * 0.6, float(j) / n)
		jag.append(Vector2(x, cut_y + (sz * 0.05 if j % 2 == 0 else -sz * 0.05)))
	var lower := jag.duplicate()
	lower.append(Vector2(sz * 0.6, by + sz))
	lower.append(Vector2(-sz * 0.6, by + sz))
	var upper := jag.duplicate()
	upper.append(Vector2(sz * 0.6, -by - sz))
	upper.append(Vector2(-sz * 0.6, -by - sz))
	upper.reverse()
	var shapes := PieceArt.build(ty, white, 0.0, by, sz)
	var mod := Color(0.75, 0.7, 0.9, fade.a)
	var line := PieceArt.line_color(white)
	var crack_line := jag.slice(2, 6)
	draw_set_transform(p, rot, Vector2.ONE)
	_draw_clipped(shapes, lower, line, maxf(1.0, sz * 0.028), mod)
	draw_polyline(crack_line, Color(ShadowArt.GREEN, 0.5 * fade.a), maxf(1.0, sz * 0.025), true)
	draw_set_transform(p + Vector2.from_angle(rot - PI * 0.5) * drift, rot + 0.25 * sin(t * 0.5 + a), Vector2.ONE)
	_draw_clipped(shapes, upper, line, maxf(1.0, sz * 0.028), mod)
	draw_polyline(crack_line, Color(ShadowArt.GREEN, 0.5 * fade.a), maxf(1.0, sz * 0.025), true)
	draw_set_transform(p, rot, Vector2.ONE)
	# shards spinning off the break
	for k in 3:
		var sp := Vector2(sin(t * 0.8 + k * 2.0 + a) * sz * 0.5, cut_y - drift * 0.5 + cos(t * 0.6 + k) * sz * 0.2)
		var sh := PackedVector2Array([sp, sp + Vector2(sz * 0.07, sz * 0.03), sp + Vector2(sz * 0.02, sz * 0.09)])
		draw_colored_polygon(sh, Color(0.8, 0.75, 0.9, 0.6 * fade.a) if white else Color(0.45, 0.4, 0.5, 0.7 * fade.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws a piece's shapes clipped to one polygon (one half of the break).
func _draw_clipped(shapes: Array, clip: PackedVector2Array, line: Color, width: float, mod: Color) -> void:
	for sh in shapes:
		var pts: PackedVector2Array = sh["p"]
		if pts.size() < 3:
			continue
		var col: Color = sh["c"]
		for poly in Geometry2D.intersect_polygons(pts, clip):
			if poly.size() < 3:
				continue
			if col.a > 0.0:
				CardArt.safe_poly(self, poly, col * mod)
			if sh["line"]:
				var closed: PackedVector2Array = poly.duplicate()
				closed.append(poly[0])
				draw_polyline(closed, line * mod, width, true)



## You, drifting: a dark figure with a faint green rim, tumbling slowly across.
func _draw_soul(c: Vector2) -> void:
	var s := size
	var u := minf(s.x, s.y)
	var p := c + Vector2(sin(t * 0.13) * s.x * 0.22, cos(t * 0.17) * s.y * 0.08 + s.y * 0.12)
	var rot := sin(t * 0.21) * 0.9 + t * 0.05
	for i in 3:
		draw_circle(p, u * (0.16 - i * 0.04), Color(ShadowArt.GREEN, 0.03))
	ShadowArt.silhouette(self, p, u * 0.2, rot, Color(0.02, 0.01, 0.03, 0.95), Color(ShadowArt.GREEN, 0.45 + 0.15 * sin(t * 1.4)), t * 0.4)


# --- testing hook --------------------------------------------------------------------------

static func _url_param(key: String) -> String:
	var q := ""
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.location.search", true)
		if v is String:
			q = String(v).trim_prefix("?")
	for a in OS.get_cmdline_user_args():
		q += "&" + a.trim_prefix("--")
	for part in q.split("&", false):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] == key:
			return kv[1]
	return ""


## ?screen=shadow&gp=ruined&fix=gate,stones&money=200&items=roses,ash shows the
## graveyard panel in a given state (main applies money and items first).
func _debug_panel() -> void:
	for t0 in [2, 4, 1, 3]:
		Game.bury(0, t0, Game.new_piece_id())
	if _debug_gp != "yugi":
		Game.yugi_banished = true
	for id in _url_param("fix").split(",", false):
		Game.grave_repairs[id] = true
	if _debug_gp == "restored":
		for sec in Game.GRAVE_SECTIONS:
			Game.grave_repairs[String(sec["id"])] = true
		Game.gravekeeper = 0
		Game.keeper_cooldown = int(_url_param("cool")) if _url_param("cool") != "" else 0
	var gp := GraveyardPanel.new(0, _url_param("busy") != "1", "Wait for your turn.")
	for sig in ["duel_requested", "reals_requested", "raise_requested", "repaired"]:
		gp.connect(sig, func(v): print("graveyard panel: ", sig, " ", v))
	gp.keeper_crowned.connect(func(): print("graveyard panel: keeper_crowned"))
	gp.closed.connect(func(): get_tree().create_timer(0.6).timeout.connect(_debug_panel_again))
	add_child(gp)


func _debug_panel_again() -> void:
	if not is_inside_tree():
		return
	var gp := GraveyardPanel.new(0, true, "")
	gp.closed.connect(func(): get_tree().create_timer(0.6).timeout.connect(_debug_panel_again))
	add_child(gp)
