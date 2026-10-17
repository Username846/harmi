class_name GraveyardPanel
extends Modal
## The graveyard: your captured pieces rest under little tombstones, and Yugi
## Moto is always there, ready to duel for one of them in a children's card game.

signal duel_requested(index: int)

const LINES := [
	"It's time to duel!",
	"Want your %s back? Beat me in a children's card game!",
	"I believe in the heart of the cards!",
	"My grandpa runs a game shop, you know.",
	"A graveyard is no place to stop shuffling!",
]

var color := 0
var selected := -1
var allowed := true
var why := ""
var scene: Control
var info: Label
var duel_btn: Button
var line := ""
var _t := 0.0
var _tombs: Array = [] # Rect2 per graveyard entry, in scene coordinates


func _init(side_color: int, can_duel: bool, reason: String) -> void:
	super("The Graveyard", 660.0)
	color = side_color
	allowed = can_duel
	why = reason
	scene = Control.new()
	scene.custom_minimum_size = Vector2(0, 250)
	scene.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.draw.connect(_draw_scene)
	scene.gui_input.connect(_on_scene_input)
	add(scene)
	info = add_text("", 17, UI.DIM)
	info.custom_minimum_size = Vector2(0, 48)
	var row := HBoxContainer.new()
	body.add_child(row)
	duel_btn = UI.button("Duel Yugi", _on_duel)
	duel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(duel_btn)
	var leave := UI.button("Leave", close)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(leave)
	var graves: Array = Game.graveyard[color]
	if not graves.is_empty():
		selected = graves.size() - 1
	line = LINES[randi() % LINES.size()]
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	scene.queue_redraw()


func _entry_name(i: int) -> String:
	var e: Dictionary = Game.graveyard[color][i]
	return Game.piece_title(int(e["type"]), color)


func _refresh() -> void:
	var graves: Array = Game.graveyard[color]
	if graves.is_empty():
		info.text = "Nobody of yours rests here yet. Yugi shuffles his deck, a little bored."
		duel_btn.disabled = true
		duel_btn.text = "Duel Yugi"
		return
	if selected < 0:
		info.text = "Tap a tombstone to choose who to play for."
		duel_btn.disabled = true
		return
	var nm := _entry_name(selected)
	if not allowed:
		info.text = "Here lies your %s. %s" % [Game.PIECE_NAMES[int(graves[selected]["type"])], why]
		duel_btn.disabled = true
		duel_btn.text = "Can't duel now"
		return
	info.text = "Win the card duel and the %s returns to the board. Win or lose, the duel uses your turn." % nm
	duel_btn.disabled = false
	duel_btn.text = "Duel for the %s" % Game.PIECE_NAMES[int(graves[selected]["type"])]


func _on_duel() -> void:
	if selected < 0 or not allowed:
		return
	var i := selected
	close()
	duel_requested.emit(i)


func _on_scene_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in _tombs.size():
			var r: Rect2 = _tombs[i]
			if r.grow(4).has_point(event.position):
				selected = i
				line = LINES[1] % Game.PIECE_NAMES[int(Game.graveyard[color][i]["type"])]
				_refresh()
				return


func _draw_scene() -> void:
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
	# tombstones on the left
	_tombs.clear()
	var graves: Array = Game.graveyard[color]
	var area_w := yrect.position.x - 16
	var n := graves.size()
	if n > 0:
		var rows := 1 if n <= 7 else 2
		var per_row := int(ceil(float(n) / rows))
		var tw := minf(area_w / per_row * 0.82, 70.0)
		var th := tw * 1.35
		for i in n:
			var row := i / per_row
			var col := i % per_row
			var x := 12 + col * (area_w / per_row) + (area_w / per_row - tw) * 0.5
			var y := ground_y - th + 6 - (rows - 1 - row) * th * 0.62
			var r := Rect2(Vector2(x, y), Vector2(tw, th))
			_tombs.append(r)
			_draw_tomb(r, int(graves[i]["type"]), i == selected)
	# mist
	for i in 6:
		var mx := fmod(_t * 12.0 + i * s.x / 5.0, s.x + 160) - 80
		scene.draw_circle(Vector2(mx, ground_y + 6 + (i % 2) * 8), 46, Color(0.75, 0.75, 0.85, 0.06))
	YugiArt.draw(scene, yrect, _t, "smug")
	# speech bubble
	var fs := 15
	var bw := minf(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20, s.x * 0.6)
	var bpos := Vector2(maxf(6, yrect.position.x - bw + yw * 0.3), 8)
	var bubble := Rect2(bpos, Vector2(bw, 30))
	scene.draw_rect(bubble, Color(0.96, 0.94, 0.88))
	scene.draw_colored_polygon(PackedVector2Array([bubble.end - Vector2(34, 0), bubble.end - Vector2(18, 0), Vector2(yrect.position.x + yw * 0.4, yrect.position.y + yw * 0.15)]), Color(0.96, 0.94, 0.88))
	scene.draw_string(font, bpos + Vector2(10, 21), line, HORIZONTAL_ALIGNMENT_LEFT, bw - 16, fs, Color(0.12, 0.08, 0.1))


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
	scene.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y + 14), Game.PIECE_NAMES[t], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, UI.GOLD if sel else UI.DIM)
