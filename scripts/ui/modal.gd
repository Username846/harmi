class_name Modal
extends Control
## A dimmed full-screen overlay holding a centered panel. Tapping outside
## closes it unless `sticky` is set.

signal closed

var panel: PanelContainer
var body: VBoxContainer
var sticky := false
var max_width := 520.0


func _init(title: String = "", width: float = 520.0) -> void:
	max_width = width
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	if title != "":
		var l := UI.label(title, 26, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		body.add_child(l)
	resized.connect(_layout)
	panel.minimum_size_changed.connect(_on_min_changed)


func _ready() -> void:
	_layout()
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween().set_parallel()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.15)


func _layout() -> void:
	if panel == null:
		return
	var w := minf(max_width, size.x - 24.0)
	panel.custom_minimum_size = Vector2(w, 0)
	_fit(w)
	# wrapped labels only know their height once they have a width
	await get_tree().process_frame
	if is_instance_valid(panel):
		_fit(w)


func _fit(w: float) -> void:
	var h := minf(panel.get_combined_minimum_size().y, size.y - 24.0)
	panel.size = Vector2(w, h)
	panel.position = ((size - panel.size) * 0.5).floor()
	panel.pivot_offset = panel.size * 0.5


func _gui_input(event: InputEvent) -> void:
	if sticky:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(event.global_position):
			close()


func _on_min_changed() -> void:
	if is_inside_tree() and panel.custom_minimum_size.x > 0.0:
		_fit(panel.custom_minimum_size.x)


func add(c: Control) -> Control:
	body.add_child(c)
	return c


func add_text(text: String, size_px: int = UI.FONT_SIZE, color: Color = UI.TEXT) -> Label:
	var l := UI.label(text, size_px, color)
	body.add_child(l)
	return l


func add_buttons(specs: Array) -> HBoxContainer:
	## specs: [[text, callable], ...]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for s in specs:
		var b := UI.button(s[0], s[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	body.add_child(row)
	return row


func close() -> void:
	closed.emit()
	queue_free()
