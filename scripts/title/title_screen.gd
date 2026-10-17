class_name TitleScreen
extends Control
## Title screen with drifting embers and a procession of elongated pieces.

signal start_requested(vs_ai: bool, difficulty: int)

var _t := 0.0
var _embers: Array = []
var column: VBoxContainer
var diff_buttons: Array = []
var difficulty := 1
var art: Control
var beyblade: BeybladeButton
var music_hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art = Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.draw.connect(_draw_art)
	add_child(art)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := UI.label("ASHEN GAMBIT", 54, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.02))
	column.add_child(title)
	column.add_child(UI.label("Chess of long shadows. Every capture is a descent.", 19, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	column.add_child(sp)
	column.add_child(UI.button("Play vs Computer", func(): start_requested.emit(true, difficulty), 60))
	var drow := HBoxContainer.new()
	column.add_child(drow)
	for i in 3:
		var b := UI.button(["Easy", "Normal", "Hard"][i], _set_diff.bind(i), 46)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drow.add_child(b)
		diff_buttons.append(b)
	_set_diff(1)
	column.add_child(UI.button("Two Players (same device)", func(): start_requested.emit(false, difficulty), 60))
	column.add_child(UI.button("How to Play", func(): Help.show(self), 52))
	beyblade = BeybladeButton.new(70.0)
	add_child(beyblade)
	music_hint = UI.label("Music: tap the Beyblade", 14, UI.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	music_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	music_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(music_hint)
	resized.connect(_layout)
	column.minimum_size_changed.connect(_layout_deferred)
	_layout()
	_layout_deferred()
	for i in 40:
		_embers.append(_new_ember(true))


func _set_diff(i: int) -> void:
	difficulty = i
	for j in diff_buttons.size():
		diff_buttons[j].button_pressed = j == i


func _layout() -> void:
	var w := minf(460.0, size.x - 32.0)
	column.custom_minimum_size = Vector2(w, 0)
	column.size = Vector2(w, 0)
	var h := column.get_combined_minimum_size().y
	var s := clampf(minf(size.x / 9.5, size.y / 7.5), 36.0, 92.0)
	var avail := size.y - s * 1.95
	var y := maxf(12.0, (avail - h) * 0.5)
	column.position = Vector2((size.x - w) * 0.5, y)
	if beyblade:
		beyblade.size = beyblade.custom_minimum_size
		beyblade.position = Vector2(size.x - beyblade.size.x - 12, 10)
		music_hint.size = Vector2(220, 20)
		music_hint.position = Vector2(size.x - 232, beyblade.position.y + beyblade.size.y + 2)


func _layout_deferred() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_layout()


func _new_ember(anywhere: bool) -> Dictionary:
	return {
		"p": Vector2(randf() * maxf(size.x, 600.0), (randf() if anywhere else 1.05) * maxf(size.y, 600.0)),
		"v": Vector2(randf_range(-8, 14), randf_range(-40, -14)),
		"r": randf_range(1.0, 2.8),
		"ph": randf() * TAU,
	}


func _process(delta: float) -> void:
	_t += delta
	for i in _embers.size():
		var e: Dictionary = _embers[i]
		e["p"] += (e["v"] + Vector2(sin(_t + e["ph"]) * 10.0, 0)) * delta
		if e["p"].y < -10:
			_embers[i] = _new_ember(false)
	art.queue_redraw()


func _draw_art() -> void:
	var w := size.x
	var h := size.y
	# a procession of pieces along the bottom, fading into ash on the right
	var s := clampf(minf(w / 9.5, h / 7.5), 36.0, 92.0)
	var types := [4, 2, 3, 5, 6, 3, 2, 4]
	var base_y := h - s * 0.4
	var total := s * 0.95 * types.size()
	var x0 := (w - total) * 0.5 + s * 0.45
	for i in types.size():
		var white := i % 2 == 0
		var bob := sin(_t * 1.3 + i) * s * 0.02
		var fade_k := 1.0
		if i >= types.size() - 2:
			fade_k = 0.55 + 0.25 * sin(_t * 2.0 + i)
		PieceArt.draw_piece(art, types[i], white, x0 + i * s * 0.95, base_y + bob, s, Color(1, 1, 1, fade_k))
	for e in _embers:
		var flick := 0.6 + 0.4 * sin(_t * 5.0 + e["ph"])
		art.draw_circle(e["p"], e["r"] * 2.4, Color(1.0, 0.45, 0.15, 0.08 * flick))
		art.draw_circle(e["p"], e["r"], Color(1.0, 0.6, 0.25, 0.7 * flick))
