class_name RipcordPanel
extends Modal
## "Let it rip!" The rip cord is the volume slider: drag it out and let go.
## Harder pulls play louder and longer. Too hard and the Beyblade snaps off.

var from_global := Vector2.ZERO
var cord: RipcordSlider
var readout: Label


func _init(origin: Vector2 = Vector2.ZERO) -> void:
	super("Let It Rip!", 520.0)
	from_global = origin
	if Music.broken:
		add_text("Your Beyblade snapped off its launcher. The music stays quiet until you fit a Spare Beyblade (the shop sells them for $4).")
		add_buttons([["OK", close]])
		return
	add_text("Drag the rip cord out and let go. The harder you pull, the louder the music and the longer it spins before dying down. Don't pull too hard.", 17, UI.DIM)
	cord = RipcordSlider.new()
	cord.custom_minimum_size = Vector2(0, 150)
	cord.changed.connect(_on_changed)
	cord.released.connect(_on_released)
	add(cord)
	readout = add_text("", 18, UI.GOLD)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_on_changed(0.0)
	var specs: Array = []
	if Music.spinning:
		specs.append(["Catch it (silence)", func():
			Music.catch_top()
			close()])
	specs.append(["Close", close])
	add_buttons(specs)


func _on_changed(v: float) -> void:
	if v >= Music.BREAK_AT:
		readout.text = "Pull: %d%%  -  TOO HARD!" % int(round(v * 100.0))
		readout.add_theme_color_override("font_color", UI.RED)
	elif v < 0.02:
		readout.text = "Pull: 0%  -  drag the handle to the right"
		readout.add_theme_color_override("font_color", UI.DIM)
	else:
		var secs := Music.duration_for(v)
		var span := "%d s" % int(secs) if secs < 90.0 else "%.1f min" % (secs / 60.0)
		readout.text = "Pull: %d%%  -  spins for about %s" % [int(round(v * 100.0)), span]
		readout.add_theme_color_override("font_color", UI.GOLD)


func _on_released(v: float) -> void:
	if v < 0.03:
		return
	close()
	Music.launch(v, from_global)


## The cord itself: a toothed strip pulled out of the launcher.
class RipcordSlider:
	extends Control

	signal changed(value: float)
	signal released(value: float)

	var value := 0.0
	var dragging := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _track() -> Vector2:
		return Vector2(size.x * 0.28, size.x - 26.0)

	func _set_from(x: float) -> void:
		var tr := _track()
		value = clampf((x - tr.x) / (tr.y - tr.x), 0.0, 1.0)
		changed.emit(value)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				_set_from(event.position.x)
			elif dragging:
				dragging = false
				released.emit(value)
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			_set_from(event.position.x)
			accept_event()

	func _draw() -> void:
		var tr := _track()
		var cy := size.y * 0.36
		var hx := lerpf(tr.x, tr.y, value)
		# power meter underneath
		var my := size.y * 0.78
		var mh := 16.0
		var n := 40
		for i in n:
			var k0 := float(i) / n
			var x0 := lerpf(tr.x, tr.y, k0)
			var x1 := lerpf(tr.x, tr.y, k0 + 1.0 / n)
			var col := UI.GREEN.lerp(UI.GOLD, clampf(k0 / 0.6, 0.0, 1.0))
			if k0 > 0.6:
				col = UI.GOLD.lerp(UI.EMBER, (k0 - 0.6) / 0.32)
			if k0 >= Music.BREAK_AT:
				col = UI.RED if int(_t * 6.0) % 2 == 0 else UI.RED.darkened(0.4)
			if k0 > value:
				col = col.darkened(0.65)
			draw_rect(Rect2(Vector2(x0, my), Vector2(x1 - x0 + 0.5, mh)), col)
		var bx := lerpf(tr.x, tr.y, Music.BREAK_AT)
		draw_line(Vector2(bx, my - 6), Vector2(bx, my + mh + 6), Color(1, 1, 1, 0.8), 2.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(bx - 4, my + mh + 20), "TOO HARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.RED)
		# the launcher with the top hanging underneath, ready to rip
		var lr := Rect2(Vector2(10, cy - 26), Vector2(tr.x - 18, 52))
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * value * 3.0 if dragging else Vector2.ZERO
		var top_r := minf(lr.size.x * 0.3, 30.0)
		BeybladeArt.draw_top(self, Vector2(lr.get_center().x, lr.end.y + top_r * 0.35) + shake, top_r, _t * 0.5, 0.0, false)
		draw_rect(lr, Color(0.75, 0.18, 0.2))
		draw_rect(Rect2(lr.position + Vector2(4, 4), Vector2(lr.size.x - 8, lr.size.y * 0.35)), Color(0.9, 0.35, 0.3))
		draw_rect(lr, Color(0.08, 0.05, 0.06), false, 2.0)
		draw_rect(Rect2(Vector2(lr.position.x + lr.size.x * 0.25, lr.position.y - 16), Vector2(lr.size.x * 0.22, 16)), Color(0.2, 0.2, 0.24))
		# the cord: a strip of teeth from the launcher to the handle
		var x := lr.end.x
		draw_rect(Rect2(Vector2(x, cy - 7), Vector2(hx - x, 14)), Color(0.85, 0.85, 0.88))
		var tooth := 9.0
		while x + tooth < hx:
			var top := PackedVector2Array([Vector2(x, cy - 7), Vector2(x + tooth * 0.5, cy - 12), Vector2(x + tooth, cy - 7)])
			draw_colored_polygon(top, Color(0.7, 0.7, 0.74))
			x += tooth
		draw_line(Vector2(lr.end.x, cy + 7), Vector2(hx, cy + 7), Color(0.4, 0.4, 0.45), 2.0)
		# the T-handle
		var hcol := UI.GOLD if not dragging else UI.EMBER
		draw_rect(Rect2(Vector2(hx - 2, cy - 4), Vector2(16, 8)), hcol.darkened(0.3))
		draw_rect(Rect2(Vector2(hx + 12, cy - 30), Vector2(14, 60)), hcol)
		draw_rect(Rect2(Vector2(hx + 12, cy - 30), Vector2(14, 60)), Color(0.1, 0.07, 0.05), false, 2.0)
		if value < 0.02 and not dragging:
			var bob := sin(_t * 4.0) * 6.0
			draw_string(font, Vector2(hx + 34 + bob, cy + 6), "pull  >>", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.DIM)
