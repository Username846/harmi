class_name BeybladeButton
extends Control
## The volume control is a Beyblade in its little stadium. Tap it to get the
## rip cord; the top spins as fast as the music is loud.

var _t := 0.0
var _press_pos := Vector2.ZERO


func _init(px: float = 60.0) -> void:
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Music volume: tap to pull the rip cord"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		var host: Node = get_tree().current_scene
		if host == null:
			host = get_tree().root
		host.add_child(RipcordPanel.new(get_global_transform() * (size * 0.5)))


func _draw() -> void:
	var s := size
	var c := Vector2(s.x * 0.5, s.y * 0.5)
	var r := minf(s.x, s.y) * 0.5
	# the stadium bowl
	var bowl := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		bowl.append(c + Vector2(cos(a) * r * 0.96, sin(a) * r * 0.5 + r * 0.22))
	draw_colored_polygon(bowl, Color(0.16, 0.13, 0.15))
	var rim := bowl.duplicate()
	rim.append(bowl[0])
	draw_polyline(rim, UI.BORDER, 2.0, true)
	if Music.broken:
		# a snapped-off stub where the top used to be
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, r * 0.3), c + Vector2(r * 0.2, r * 0.32), c + Vector2(r * 0.05, r * 0.05), c + Vector2(-r * 0.1, r * 0.12)]), Color(0.5, 0.5, 0.55))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, s.y - 3), "snapped", HORIZONTAL_ALIGNMENT_CENTER, s.x, 12, UI.RED)
		return
	var e := Music.energy()
	var wob := Music.wobble()
	var tilt := sin(_t * 9.0) * 0.3 * wob
	var drift := Vector2(sin(_t * 2.3) * r * 0.08 * e, 0)
	BeybladeArt.draw_top(self, c + drift + Vector2(0, -r * 0.12), r * 0.78, Music.angle, tilt, false, clampf(e * 1.3, 0.0, 1.0))
	# volume pips
	for i in 5:
		var on := e > (i + 0.5) / 5.0
		var p := Vector2(c.x - r * 0.48 + i * r * 0.24, s.y - 4)
		draw_rect(Rect2(p - Vector2(r * 0.08, 3 + i), Vector2(r * 0.16, 3 + i)), UI.GOLD if on else Color(0.3, 0.26, 0.24))
