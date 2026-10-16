class_name UI
extends RefCounted
## Shared palette, theme and small widget helpers.

const BG := Color(0.055, 0.045, 0.06)
const PANEL := Color(0.11, 0.09, 0.115, 0.97)
const PANEL_LIGHT := Color(0.16, 0.13, 0.15)
const BORDER := Color(0.52, 0.41, 0.29)
const TEXT := Color(0.92, 0.87, 0.78)
const DIM := Color(0.64, 0.59, 0.53)
const GOLD := Color(0.88, 0.67, 0.29)
const EMBER := Color(0.89, 0.40, 0.22)
const RED := Color(0.82, 0.24, 0.22)
const BLUE := Color(0.32, 0.52, 0.95)
const GREEN := Color(0.42, 0.75, 0.38)

const FONT_SIZE := 19


static func _box(bg: Color, border: Color, bw: int = 2, radius: int = 6, margin: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.6
	sb.content_margin_bottom = margin * 0.6
	sb.anti_aliasing = true
	return sb


static func build_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = FONT_SIZE
	# Buttons
	th.set_stylebox("normal", "Button", _box(Color(0.17, 0.135, 0.15), BORDER))
	th.set_stylebox("hover", "Button", _box(Color(0.24, 0.185, 0.19), GOLD))
	th.set_stylebox("pressed", "Button", _box(Color(0.33, 0.22, 0.16), GOLD))
	th.set_stylebox("hover_pressed", "Button", _box(Color(0.36, 0.24, 0.17), GOLD))
	th.set_stylebox("disabled", "Button", _box(Color(0.10, 0.085, 0.095), Color(0.28, 0.24, 0.22)))
	var focus := StyleBoxEmpty.new()
	th.set_stylebox("focus", "Button", focus)
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.7))
	th.set_color("font_hover_pressed_color", "Button", Color(1, 0.9, 0.7))
	th.set_color("font_disabled_color", "Button", Color(0.45, 0.41, 0.38))
	th.set_color("font_focus_color", "Button", TEXT)
	# Panels
	th.set_stylebox("panel", "PanelContainer", _box(PANEL, BORDER, 2, 8, 14))
	th.set_stylebox("panel", "Panel", _box(PANEL, BORDER, 2, 8, 14))
	# Labels
	th.set_color("font_color", "Label", TEXT)
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	# Scrollbars - chunky for touch
	var grab := _box(Color(0.45, 0.36, 0.27), Color(0.45, 0.36, 0.27), 0, 4, 0)
	var track := _box(Color(0.08, 0.065, 0.075), Color(0.08, 0.065, 0.075), 0, 4, 0)
	for sb_type in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("grabber", sb_type, grab)
		th.set_stylebox("grabber_highlight", sb_type, _box(GOLD, GOLD, 0, 4, 0))
		th.set_stylebox("grabber_pressed", sb_type, _box(GOLD, GOLD, 0, 4, 0))
		th.set_stylebox("scroll", sb_type, track)
	th.set_constant("separation", "VBoxContainer", 8)
	th.set_constant("separation", "HBoxContainer", 8)
	th.set_constant("h_separation", "GridContainer", 8)
	th.set_constant("v_separation", "GridContainer", 8)
	return th


static func button(text: String, cb: Callable = Callable(), min_h: float = 52.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func label(text: String, size: int = FONT_SIZE, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(size: int = FONT_SIZE) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_following = true
	r.selection_enabled = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func panel_style(bg: Color = PANEL, border: Color = BORDER, bw: int = 2, radius: int = 8) -> StyleBoxFlat:
	return _box(bg, border, bw, radius, 12)


## Draws a framed "window" with a title bar, the frame style used for the picture box.
static func draw_frame(ci: CanvasItem, r: Rect2, title: String, title_h: float) -> void:
	ci.draw_rect(r.grow(6), Color(0.03, 0.025, 0.03))
	ci.draw_rect(r.grow(4), Color(0.42, 0.33, 0.24))
	ci.draw_rect(r.grow(2), Color(0.20, 0.155, 0.12))
	draw_title_bar(ci, r, title, title_h)


static func draw_title_bar(ci: CanvasItem, r: Rect2, title: String, title_h: float) -> void:
	var font := ThemeDB.fallback_font
	var bar := Rect2(r.position, Vector2(r.size.x, title_h))
	ci.draw_rect(bar, Color(0.84, 0.78, 0.66))
	# pinstripes like an old window title bar
	var y := bar.position.y + 5.0
	while y < bar.end.y - 4.0:
		ci.draw_line(Vector2(bar.position.x + 6, y), Vector2(bar.end.x - 6, y), Color(0.55, 0.47, 0.38), 1.0)
		y += 3.0
	var fs := int(title_h * 0.62)
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tx := bar.position.x + (bar.size.x - tw) * 0.5
	ci.draw_rect(Rect2(tx - 10, bar.position.y + 2, tw + 20, title_h - 4), Color(0.84, 0.78, 0.66))
	ci.draw_string(font, Vector2(tx, bar.position.y + title_h * 0.74), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.12, 0.09, 0.08))
