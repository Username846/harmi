class_name DateChoice
extends PanelContainer
## A big tappable card whose text wraps (venue choices and reply choices).
## Emits `chosen` on a tap or click. A drag (scrolling a list on a phone)
## doesn't count as a tap.

signal chosen

var disabled := false:
	set(v):
		disabled = v
		_restyle()
var selected := false:
	set(v):
		selected = v
		_restyle()
var _hover := false
var _down := false
var _down_pos := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(0, 52)
	mouse_entered.connect(func():
		_hover = true
		_restyle())
	mouse_exited.connect(func():
		_hover = false
		_down = false
		_restyle())
	_restyle()


## A card holding one wrapped line of text.
static func text_card(text: String, fs: int = 17) -> DateChoice:
	var c := DateChoice.new()
	var l := UI.label(text, fs, UI.TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	return c


func _restyle() -> void:
	var bg := Color(0.16, 0.125, 0.135)
	var border := UI.BORDER
	var bw := 2
	if disabled:
		bg = Color(0.09, 0.08, 0.085)
		border = Color(0.3, 0.26, 0.24)
	elif _down:
		bg = Color(0.32, 0.22, 0.15)
		border = UI.GOLD
	elif selected:
		bg = Color(0.27, 0.19, 0.14)
		border = UI.GOLD
		bw = 3
	elif _hover:
		bg = Color(0.22, 0.17, 0.165)
		border = UI.GOLD
	var sb := UI.panel_style(bg, border, bw, 8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	modulate.a = 0.6 if disabled else 1.0


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_down = true
		_down_pos = event.global_position
		_restyle()
	elif _down:
		_down = false
		_restyle()
		if disabled:
			return
		if event.global_position.distance_to(_down_pos) < 16.0 and get_global_rect().has_point(event.global_position):
			chosen.emit()
