class_name DateMoodBar
extends Control
## The mood meter in the date panel: "Mood: Gloomy (31)" over a bar, or, with
## a starting value, an animated "Mood: Gloomy (31) -> Content (68)".

var value := 50.0
var target := 50.0
var from := -1.0
var speed := 22.0
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 56)


## Shows `to`; with animate, the bar fills from `f` to `to` and the caption
## shows both.
func set_values(f: float, to: float, animate: bool) -> void:
	target = to
	if animate:
		from = f
		value = f
	else:
		from = -1.0
		value = to


func _process(delta: float) -> void:
	_t += delta
	value = move_toward(value, target, delta * speed)
	queue_redraw()


func _caption(m: float) -> String:
	return "%s (%d)" % [Game.mood_name(m), int(round(m))]


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var fs := 20
	var prefix := "Mood: "
	var parts: Array = []
	if from < 0.0:
		parts = [[prefix, UI.DIM], [_caption(value), Game.mood_color(value)]]
	else:
		parts = [[prefix, UI.DIM], [_caption(from), Game.mood_color(from)], ["->", UI.TEXT], [_caption(value), Game.mood_color(value)]]
	var total := _measure(parts, fs)
	while total > size.x and fs > 15:
		fs -= 1
		total = _measure(parts, fs)
	if total > size.x:
		parts.remove_at(0)
		total = _measure(parts, fs)
	var x := 0.0
	var base_y := font.get_ascent(fs) + 2.0
	for p in parts:
		var txt: String = p[0]
		var col: Color = p[1]
		if txt == "->":
			var aw := fs * 1.6
			var y := base_y - fs * 0.32
			draw_line(Vector2(x + fs * 0.3, y), Vector2(x + aw - fs * 0.35, y), col, 2.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(x + aw - fs * 0.25, y), Vector2(x + aw - fs * 0.6, y - fs * 0.26), Vector2(x + aw - fs * 0.6, y + fs * 0.26)]), col)
			x += aw
			continue
		draw_string_outline(font, Vector2(x, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(x, base_y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# the bar
	var bar := Rect2(0, font.get_height(fs) + 8.0, size.x, 20.0)
	draw_rect(bar, Color(0.06, 0.05, 0.06))
	var k := clampf(value / 100.0, 0.0, 1.0)
	var col2 := Game.mood_color(value)
	if from >= 0.0 and target > from:
		var kf := clampf(from / 100.0, 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * kf, bar.size.y)), Game.mood_color(from).darkened(0.25))
		if k > kf:
			var gain := Rect2(bar.position + Vector2(bar.size.x * kf, 0), Vector2(bar.size.x * (k - kf), bar.size.y))
			draw_rect(gain, col2.lightened(0.1 + 0.08 * sin(_t * 6.0)))
	elif from >= 0.0 and target < from:
		var kf2 := clampf(from / 100.0, 0.0, 1.0)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col2)
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * k, 0), Vector2(bar.size.x * (kf2 - k), bar.size.y)), Color(0.6, 0.12, 0.12, 0.6))
	else:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col2)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y * 0.4)), Color(1, 1, 1, 0.15))
	for th in [25.0, 45.0, 65.0, 85.0]:
		var tx: float = bar.size.x * th / 100.0
		draw_line(Vector2(tx, bar.position.y + 2), Vector2(tx, bar.end.y - 2), Color(0, 0, 0, 0.4), 1.0)
	draw_rect(bar, UI.BORDER, false, 2.0)


func _measure(parts: Array, fs: int) -> float:
	var font := ThemeDB.fallback_font
	var w := 0.0
	for p in parts:
		var txt: String = p[0]
		if txt == "->":
			w += fs * 1.6
		else:
			w += font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w
