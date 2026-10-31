class_name AppStore
extends Control
## The phone's app store, opened from the home screen: every app from every
## ad, shelved by category (with counts), searchable, each with a GET button. Downloads never seem to go
## through (each app keeps failing with the same error), except Anti Virus,
## which installs, scans and cleans out the invaders.

const BG := Color(0.96, 0.96, 0.97)
const INK := Color(0.1, 0.1, 0.12)
const GREY := Color(0.45, 0.45, 0.5)
const BLUE := Color(0.15, 0.5, 0.95)
const LOAD := 1.4
const DOWNLOAD := 4.2

var _list: VBoxContainer
var _search: LineEdit
var _tabs: HFlowContainer
var _cat := "All"
var _errors := {} # app name -> the error it keeps giving
var _dlg: Control
var _dlg_info := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var back := _flat_button("< Back", Color(0, 0, 0, 0), BLUE)
	back.pressed.connect(queue_free)
	head.add_child(back)
	var title := Label.new()
	title.text = "App Store"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(back.get_combined_minimum_size().x, 0)
	head.add_child(spacer)
	_search = LineEdit.new()
	_search.placeholder_text = "Search apps and games"
	_search.custom_minimum_size = Vector2(0, 46)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.89, 0.89, 0.91)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	_search.add_theme_stylebox_override("normal", sb)
	_search.add_theme_stylebox_override("focus", sb)
	_search.add_theme_color_override("font_color", INK)
	_search.add_theme_color_override("font_placeholder_color", GREY)
	_search.text_changed.connect(func(_t: String): _fill())
	col.add_child(_search)
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	col.add_child(_tabs)
	_make_tabs()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_fill()


func _flat_button(text: String, bg: Color, fg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(76, 40)
	for state in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg.lightened(0.1) if state == "hover" and bg.a > 0.0 else bg
		s.set_corner_radius_all(20)
		s.content_margin_left = 14
		s.content_margin_right = 14
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_font_size_override("font_size", 17)
	return b


static func rating(a: Dictionary) -> float:
	return 4.1 + fposmod(float(String(a.get("name", "")).hash()) * 0.0001, 0.85)


static func megabytes(a: Dictionary) -> int:
	return 40 + absi(String(a.get("name", "")).hash()) % 420


## One tab per shelf, each saying how many apps are on it.
func _make_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	var counts := AdData.category_counts()
	var specs: Array = [["All", AdData.apps().size()]]
	for c in AdData.CATEGORIES:
		specs.append([c, counts[c]])
	for spec in specs:
		var on: bool = spec[0] == _cat
		var b := _flat_button("%s · %d" % [spec[0], spec[1]], BLUE if on else Color(0.89, 0.9, 0.93), Color(1, 1, 1) if on else INK)
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			_cat = String(spec[0])
			_make_tabs()
			_fill())
		_tabs.add_child(b)


func _matches(a: Dictionary, q: String) -> bool:
	return q == "" or String(a["name"]).to_lower().contains(q) or String(a["dev"]).to_lower().contains(q)


func _header(text: String) -> void:
	var h := Label.new()
	h.text = text
	h.add_theme_font_size_override("font_size", 20)
	h.add_theme_color_override("font_color", INK)
	_list.add_child(h)


func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var q := _search.text.strip_edges().to_lower()
	var counts := AdData.category_counts()
	var shown := 0
	for cat in AdData.CATEGORIES:
		if _cat != "All" and cat != _cat:
			continue
		var apps: Array = AdData.apps().filter(func(a): return AdData.category(a) == cat and _matches(a, q))
		if apps.is_empty():
			continue
		_header("%s  —  %d apps" % [cat, counts[cat]])
		for a in apps:
			_list.add_child(_row(a))
			shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "No results for \"%s\"" % _search.text
		none.add_theme_color_override("font_color", GREY)
		_list.add_child(none)


func _row(a: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 78)
	row.add_theme_constant_override("separation", 12)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func(): AdScenes.app_icon(icon, Rect2(Vector2.ZERO, icon.size), a))
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	for spec in [[String(a["name"]), 18, INK], [String(a["dev"]), 14, GREY], ["%.1f stars  ·  %d MB" % [rating(a), megabytes(a)], 13, GREY]]:
		var l := Label.new()
		l.text = spec[0]
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		l.clip_text = true
		info.add_child(l)
	var get_btn := _flat_button("GET", Color(0.89, 0.9, 0.93), BLUE)
	get_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	get_btn.pressed.connect(_get_app.bind(a))
	row.add_child(get_btn)
	return row


# --- installing -------------------------------------------------------------------

func _get_app(a: Dictionary) -> void:
	if _dlg != null:
		return
	var n := String(a["name"])
	if not _errors.has(n):
		_errors[n] = AdPlayer.STORE_ERRORS[randi() % AdPlayer.STORE_ERRORS.size()]
	_dlg_info = {"t": 0.0, "a": a, "av": n == AdData.ANTIVIRUS, "result": []}
	_dlg = Control.new()
	_dlg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
	_dlg.draw.connect(_draw_dialog.bind(_dlg))
	add_child(_dlg)


func _ready_at() -> float:
	return DOWNLOAD if _dlg_info.get("av", false) else LOAD


func _process(delta: float) -> void:
	if _dlg == null:
		return
	var before: float = _dlg_info["t"]
	_dlg_info["t"] = before + delta
	if before < _ready_at() and float(_dlg_info["t"]) >= _ready_at():
		var res: Array = AdPlayer.scan_result() if _dlg_info["av"] else _errors[String(_dlg_info["a"]["name"])]
		_dlg_info["result"] = res
		var ok := _flat_button("OK", BLUE, Color(1, 1, 1))
		ok.pressed.connect(_close_dialog)
		_dlg.add_child(ok)
		ok.position = _box().end - Vector2(110, 60)
	_dlg.queue_redraw()


func _close_dialog() -> void:
	if _dlg_info.get("av", false):
		Game.cure()
	_dlg.queue_free()
	_dlg = null


func _box() -> Rect2:
	var w := minf(size.x - 40.0, 460.0)
	return Rect2(Vector2((size.x - w) * 0.5, size.y * 0.5 - 110.0), Vector2(w, 220))


func _draw_dialog(dlg: Control) -> void:
	var t: float = _dlg_info["t"]
	var a: Dictionary = _dlg_info["a"]
	dlg.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var r := _box()
	AdScenes.box(dlg, r, Color(1, 1, 1), 18)
	var font := ThemeDB.fallback_font
	var pad := 24.0
	if t < LOAD:
		var c := r.get_center()
		dlg.draw_arc(c - Vector2(70, 0), 16, t * 7.0, t * 7.0 + PI * 1.4, 20, BLUE, 5.0, true)
		dlg.draw_string(font, c + Vector2(-40, 7), "Loading...", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
		return
	if t < _ready_at():
		var k := clampf((t - LOAD) / (DOWNLOAD - LOAD), 0.0, 1.0)
		dlg.draw_string(font, r.position + Vector2(pad, 46), "Installing " + String(a["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0, 21, INK)
		var bar := Rect2(r.position + Vector2(pad, 100), Vector2(r.size.x - pad * 2.0, 12))
		AdScenes.box(dlg, bar, Color(0.88, 0.89, 0.92), 6)
		AdScenes.box(dlg, Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), BLUE, 6)
		dlg.draw_string(font, bar.position + Vector2(0, 40), "%d of %d MB" % [int(k * megabytes(a)), megabytes(a)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GREY)
		return
	var res: Array = _dlg_info["result"]
	dlg.draw_string(font, r.position + Vector2(pad, 46), String(res[0]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0, 22, INK)
	dlg.draw_multiline_string(font, r.position + Vector2(pad, 84), String(res[1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0, 16, -1, GREY)
