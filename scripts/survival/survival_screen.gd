class_name SurvivalScreen
extends Control
## After the bomb under the chessboard: survive in the ruins of the town until
## the authorities find you. Scavenge for food and water, keep radiation down
## and signal for rescue.
##
## setup(info) is called before add_child. info keys: town (String, the
## town's name), difficulty (0 easy, 1 normal, 2 hard), optional seed (int).
## Emits finished("rescued") or finished("died") when the player leaves the
## end modal (exactly once).

signal finished(result: String)

const LOG_COL := {"info": "#ebdfc7", "good": "#8fd07a", "bad": "#ee6a50", "find": "#e8b45a", "rescue": "#8fb8ff",
	"event": "#ee9050", "night": "#a8a3cc", "morning": "#f0d890", "warn": "#e8c060"}
const STAT_COL := {"health": Color(0.86, 0.28, 0.26), "food": Color(0.9, 0.62, 0.22), "water": Color(0.35, 0.6, 0.98),
	"rad": Color(0.6, 0.95, 0.3)}
const ACTION_HELP := {
	"rest": "Rest on the camp bed. +health.",
	"purify": "Filter and boil up to 2 Dirty Water into clean water.",
	"build_radio": "3 Radio Parts + a Battery make a working radio.",
	"broadcast": "Call for help on the emergency band. Once a day.",
	"fire": "Burn a Fuel Can. Smoke by day, a beacon by night. Looters may see it too.",
	"paint": "Paint SOS on the roof. Search planes spot it every day from now on.",
	"mirror": "Flash the Signal Mirror at the sky. Clear days only.",
	"flare": "Fire a Flare. Huge if a helicopter is searching today.",
}

var info: Dictionary = {}
var town := "Ashenford"
var difficulty := 1
var seed_value := -1
var sim: SurvivalSim

var map: SurvivalMap
var log_panel: PanelContainer
var log_box: RichTextLabel
var panel: PanelContainer
var scroll: ScrollContainer
var vb: VBoxContainer
var wx_icon: Control
var day_label: Label
var time_label: Label
var sleep_btn: Button
var heli_label: Label
var rescue_bar: Control
var stats_box: Control
var loc_title: Label
var loc_desc: Label
var loc_info: RichTextLabel
var actions: GridContainer
var hint: Label
var supplies_panel: PanelContainer
var inv_scroll: ScrollContainer
var inv_grid: GridContainer
var inv_caption: Label

var busy := false
var ended := false
var _emitted := false
var _rescue_shown := 0.0
var _flash: Dictionary = {}
var _t := 0.0
var _relayout_queued := false
var _cols := 2
var _inv_cols := 6
var _slot_px := 56.0
var _hint_t := 0.0


func setup(i: Dictionary) -> void:
	info = i
	town = String(i.get("town", "Ashenford"))
	if town.strip_edges() == "":
		town = "Ashenford"
	difficulty = clampi(int(i.get("difficulty", 1)), 0, 2)
	var dbg := _debug_params()
	seed_value = int(i.get("seed", int(dbg.get("seed", "-1"))))
	sim = SurvivalSim.new(difficulty, seed_value, town)
	if dbg.has("rescue"):
		sim.rescue = clampf(float(dbg["rescue"]), 0.0, 99.0)
	_rescue_shown = sim.rescue


## Testing aids in the page URL (or as user args): &seed=N fixes the dice,
## &rescue=N starts the Rescue meter at N%.
static func _debug_params() -> Dictionary:
	var q := ""
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.location.search", true)
		if v is String:
			q = v
	for a in OS.get_cmdline_user_args():
		q += "&" + a.trim_prefix("--")
	var out := {}
	for part in q.trim_prefix("?").split("&", false):
		var kv := part.split("=")
		if kv.size() == 2 and kv[0] in ["seed", "rescue"]:
			out[kv[0]] = kv[1]
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if sim == null:
		setup(info)
	map = SurvivalMap.new()
	map.sim = sim
	map.picked.connect(select)
	add_child(map)

	log_panel = PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.07, 0.055, 0.06, 0.97), UI.BORDER, 2, 8))
	add_child(log_panel)
	log_box = UI.rich(16)
	log_box.scroll_following = true
	log_panel.add_child(log_box)

	panel = PanelContainer.new()
	add_child(panel)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 7)
	scroll.add_child(vb)
	_build_panel()

	resized.connect(_relayout)
	panel.minimum_size_changed.connect(_queue_relayout)
	_relayout()
	_flush_log()
	_refresh()
	_show_intro()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)


func _process(delta: float) -> void:
	_t += delta
	_rescue_shown = move_toward(_rescue_shown, sim.rescue, delta * 30.0)
	for k in _flash.keys():
		_flash[k] = maxf(0.0, float(_flash[k]) - delta * 1.2)
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			hint.text = ""
	rescue_bar.queue_redraw()
	stats_box.queue_redraw()
	wx_icon.queue_redraw()


# --- building the panel ---------------------------------------------------------------

func _build_panel() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	wx_icon = Control.new()
	wx_icon.custom_minimum_size = Vector2(48, 48)
	wx_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wx_icon.draw.connect(_draw_weather)
	head.add_child(wx_icon)
	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", 0)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	day_label = UI.label("DAY 1", 24, UI.GOLD)
	day_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tb.add_child(day_label)
	time_label = UI.label("", 16, UI.DIM)
	tb.add_child(time_label)
	sleep_btn = UI.button("Sleep", sleep_now, 50)
	sleep_btn.custom_minimum_size = Vector2(118, 50)
	sleep_btn.tooltip_text = "Sleep in your shelter until morning. Any slots left today pass while you rest."
	head.add_child(sleep_btn)

	heli_label = UI.label("", 16, Color(1.0, 0.82, 0.45))
	heli_label.visible = false
	vb.add_child(heli_label)

	rescue_bar = Control.new()
	rescue_bar.custom_minimum_size = Vector2(0, 60)
	rescue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rescue_bar.draw.connect(_draw_rescue)
	vb.add_child(rescue_bar)

	stats_box = Control.new()
	stats_box.custom_minimum_size = Vector2(0, 74)
	stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.draw.connect(_draw_stats)
	vb.add_child(stats_box)

	vb.add_child(_rule())
	loc_title = UI.label("", 21, UI.GOLD)
	vb.add_child(loc_title)
	loc_desc = UI.label("", 15, UI.DIM)
	vb.add_child(loc_desc)
	loc_info = RichTextLabel.new()
	loc_info.bbcode_enabled = true
	loc_info.fit_content = true
	loc_info.scroll_active = false
	loc_info.selection_enabled = false
	loc_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loc_info.add_theme_font_size_override("normal_font_size", 15)
	vb.add_child(loc_info)
	actions = GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	vb.add_child(actions)
	hint = UI.label("", 15, UI.EMBER)
	vb.add_child(hint)


	# supplies get their own panel, placed by _relayout
	supplies_panel = PanelContainer.new()
	supplies_panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.09, 0.075, 0.085, 0.97), UI.BORDER, 2, 8))
	add_child(supplies_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	supplies_panel.add_child(sv)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 10)
	sv.add_child(ih)
	var sl := UI.label("SUPPLIES", 16, UI.GOLD)
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	ih.add_child(sl)
	inv_caption = UI.label("", 15, UI.DIM)
	inv_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	inv_caption.clip_text = true
	inv_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inv_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ih.add_child(inv_caption)
	inv_scroll = ScrollContainer.new()
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inv_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sv.add_child(inv_scroll)
	inv_grid = GridContainer.new()
	inv_grid.columns = 6
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	inv_scroll.add_child(inv_grid)


func _rule() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.52, 0.41, 0.29, 0.45)
	c.custom_minimum_size = Vector2(0, 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# --- layout -------------------------------------------------------------------------------

func _relayout() -> void:
	if panel == null:
		return
	var w := size.x
	var h := size.y
	var m := 12.0
	var pw := 0.0
	var sw := 0.0
	if w >= h * 1.15:
		# map top-left, supplies and log under it, the panel on the right
		pw = clampf(w * 0.4, 360.0, 470.0)
		var lw := w - pw - m * 3.0
		var sh := clampf(h * 0.28, 150.0, 220.0)
		sw = clampf(lw * 0.52, 250.0, 430.0)
		map.position = Vector2(m, m)
		map.size = Vector2(lw, h - m * 3.0 - sh)
		supplies_panel.position = Vector2(m, h - m - sh)
		supplies_panel.size = Vector2(sw, sh)
		log_panel.position = Vector2(m * 2.0 + sw, h - m - sh)
		log_panel.size = Vector2(lw - sw - m, sh)
		panel.position = Vector2(w - pw - m, m)
		panel.size = Vector2(pw, h - m * 2.0)
	else:
		# a column: map, log, supplies, panel
		pw = w - m * 2.0
		sw = pw
		var short := h < 1000.0
		var map_h := clampf(minf(w * 0.8, h * (0.36 if short else 0.37)), 200.0, 640.0)
		var log_h := clampf(h * 0.1, 64.0 if short else 90.0, 140.0)
		var rows := 1 if short else 2
		var sh := 46.0 + rows * 56.0 + (rows - 1) * 6.0
		map.position = Vector2(m, m)
		map.size = Vector2(pw, map_h)
		log_panel.position = Vector2(m, map_h + m * 2.0)
		log_panel.size = Vector2(pw, log_h)
		supplies_panel.position = Vector2(m, map_h + log_h + m * 3.0)
		supplies_panel.size = Vector2(pw, sh)
		var top := map_h + log_h + sh + m * 4.0
		panel.position = Vector2(m, top)
		panel.size = Vector2(pw, maxf(h - top - m, 120.0))
	var inner := pw - 28.0 - 14.0 # panel margins and room for the scrollbar
	var cols := clampi(int(inner / 128.0), 2, 4)
	if cols != _cols:
		_cols = cols
		actions.columns = cols if map.selected == "shelter" else mini(cols, 2)
	var slot := 50.0 if w >= h * 1.15 else 56.0
	if slot != _slot_px:
		_slot_px = slot
		_refresh_inventory()
	var icols := clampi(int((sw - 24.0 - 14.0 + 6.0) / (slot + 6.0)), 3, 12)
	if icols != _inv_cols:
		_inv_cols = icols
		inv_grid.columns = icols


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


# --- refreshing ----------------------------------------------------------------------------

func _refresh() -> void:
	day_label.text = "DAY %d" % sim.day
	time_label.text = "%s  -  %s" % [sim.slot_name() if sim.slot < SurvivalSim.SLOTS_PER_DAY else "Night", sim.weather_name()]
	sleep_btn.text = "Sleep" if sim.slot >= 2 else "End Day"
	sleep_btn.disabled = ended
	heli_label.visible = sim.heli_today and not sim.over
	if sim.heli_today:
		heli_label.text = "Rotors to the east! A helicopter is searching today." + (" Fire a flare!" if sim.has("flare") else " Find a flare!")
	map.queue_redraw()
	_refresh_location()
	_refresh_inventory()


func _refresh_location() -> void:
	var id := map.selected
	var L: Dictionary = SurvivalSim.LOCS[id]
	loc_title.text = sim.loc_name(id)
	loc_desc.text = sim.loc_desc(id)
	if id == "shelter":
		var bits := PackedStringArray()
		bits.append("Tap a place on the map to go scavenging.")
		if sim.radio_built:
			bits.append("Radio: %s." % ("%d broadcast%s left on its battery" % [sim.radio_charge, "" if sim.radio_charge == 1 else "s"] if sim.radio_charge > 0 else "battery flat"))
		if sim.sos_painted:
			bits.append("SOS painted.")
		if sim.fire_lit:
			bits.append("Signal fire burning.")
		loc_info.text = "[color=#a9a39f]%s[/color]" % " ".join(bits)
	else:
		var slots: int = int(L["slots"])
		var rl := sim.rad_label(id)
		var rc := "#8fd07a" if rl == "Low" else ("#e8c060" if rl == "Moderate" else "#ee6a50")
		var dl := SurvivalSim.danger_label(int(L["danger"]))
		var dc := "#8fd07a" if int(L["danger"]) == 0 else ("#e8c060" if int(L["danger"]) == 1 else "#ee6a50")
		var left := sim.loot_left(id)
		var loot := "plenty"
		var lc := "#8fd07a"
		if L.has("renew"):
			loot = "dirty water, always" if left == 0 else "dirty water and more"
		elif left == 0:
			loot = "picked over"
			lc = "#ee6a50"
		elif left <= 2:
			loot = "almost gone"
			lc = "#e8c060"
		elif left <= 4:
			loot = "some left"
		loc_info.text = "Trip: [color=#e0aa4a]%d slot%s[/color]   Radiation: [color=%s]%s[/color]   Danger: [color=%s]%s[/color]   Loot: [color=%s]%s[/color]" % [
			slots, "" if slots == 1 else "s", rc, rl, dc, dl, lc, loot]
	_build_actions()


func _build_actions() -> void:
	for c in actions.get_children():
		c.queue_free()
	var id := map.selected
	actions.columns = _cols if id == "shelter" else mini(_cols, 2)
	if id == "shelter":
		for a in SurvivalSim.SHELTER_ACTIONS:
			_add_action(a, SurvivalSim.ACTION_NAMES[a], func(): act(a), sim.reason_action(a), _highlight(a))
	else:
		var slots: int = int(SurvivalSim.LOCS[id]["slots"])
		_add_action("scavenge", "Scavenge (%d slot%s)" % [slots, "" if slots == 1 else "s"], func(): scavenge(id), sim.reason_scavenge(id), true)
		if id == "radio_station":
			_add_action("tower_broadcast", "Transmit (2 slots)", func(): act("tower_broadcast"), sim.reason_action("tower_broadcast"), false)
		_add_action("home", "Shelter", func(): select("shelter"), "", false)


func _highlight(a: String) -> bool:
	if sim.reason_action(a) != "":
		return false
	match a:
		"flare":
			return sim.heli_today
		"mirror", "build_radio", "broadcast", "paint":
			return true
	return false


func _add_action(key: String, text: String, cb: Callable, reason: String, glow: bool) -> void:
	var b := UI.button(text, func(): _on_action_button(key, cb, reason), 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.tooltip_text = reason if reason != "" else String(ACTION_HELP.get(key, ""))
	b.set_meta("action", key)
	if reason != "":
		b.modulate = Color(1, 1, 1, 0.5)
	elif glow:
		var sb := UI.panel_style(Color(0.3, 0.2, 0.08), UI.GOLD, 2, 6)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
	actions.add_child(b)


func _on_action_button(key: String, cb: Callable, reason: String) -> void:
	if busy or ended:
		return
	# re-check: the state may have moved on since the buttons were built
	var why := reason
	if key == "scavenge":
		why = sim.reason_scavenge(map.selected)
	elif key != "home":
		why = sim.reason_action(key)
	if why != "":
		_set_hint(why)
		return
	cb.call()


func _set_hint(text: String, col: Color = UI.EMBER) -> void:
	hint.text = text
	hint.add_theme_color_override("font_color", col)
	_hint_t = 5.0


func _refresh_inventory() -> void:
	for c in inv_grid.get_children():
		c.queue_free()
	var ids := sim.item_ids()
	for id in ids:
		var s := SurvivalItemSlot.new(id, sim.count(id), _slot_px)
		s.pressed.connect(func(): use_item(id))
		s.mouse_entered.connect(func(): inv_caption.text = SurvivalSim.item_name(id))
		s.mouse_exited.connect(func(): inv_caption.text = _inv_hint())
		inv_grid.add_child(s)
	inv_caption.text = _inv_hint()


func _inv_hint() -> String:
	if sim.item_ids().is_empty():
		return "Nothing. Go scavenging."
	return "tap to use"


# --- log ------------------------------------------------------------------------------------

func _flush_log() -> Array:
	var lines := sim.pop_log()
	for l in lines:
		var d: Dictionary = l
		var col: String = LOG_COL.get(String(d["kind"]), "#ebdfc7")
		var txt := String(d["text"]).replace("[", "[lb]")
		if String(d["kind"]) == "night" and txt.begins_with("Night "):
			log_box.append_text("[color=%s][b]%s[/b][/color]\n" % [col, txt])
		elif String(d["kind"]) == "morning":
			log_box.append_text("[color=%s][b]%s[/b][/color]\n" % [col, txt])
		else:
			log_box.append_text("[color=%s]%s[/color]\n" % [col, txt])
	return lines


# --- public actions (buttons, map and tests call these) ------------------------------------

func select(id: String) -> void:
	if not SurvivalSim.LOCS.has(id):
		return
	map.selected = id
	hint.text = ""
	_refresh_location()


func scavenge(id: String) -> bool:
	if busy or ended or sim.over:
		return false
	if map.selected != id:
		select(id)
	var why := sim.reason_scavenge(id)
	if why != "":
		_set_hint(why)
		return false
	var before := _snap()
	var day0 := sim.day
	sim.scavenge(id)
	var got := 0
	for k in sim.inv:
		got += maxi(0, sim.count(k) - int(before["inv"].get(k, 0)))
	if got > 0:
		map.float_text(id, "+%d item%s" % [got, "" if got == 1 else "s"], UI.GOLD)
	else:
		map.float_text(id, "nothing", UI.DIM)
	_after(day0, before)
	return true


func act(action: String) -> bool:
	if busy or ended or sim.over:
		return false
	var why := sim.reason_action(action)
	if why != "":
		_set_hint(why)
		return false
	var before := _snap()
	var day0 := sim.day
	sim.do_action(action)
	if action == "tower_broadcast":
		map.float_text("radio_station", "On the air!", Color(0.6, 0.75, 1.0))
	elif sim.rescue > float(before["rescue"]):
		map.float_text("shelter", "+%d%% rescue" % int(round(sim.rescue - float(before["rescue"]))), Color(0.6, 0.75, 1.0))
	_after(day0, before)
	return true


func use_item(id: String) -> bool:
	if busy or ended or sim.over or not sim.has(id):
		return false
	var before := _snap()
	var used := sim.use_item(id)
	var lines := _flush_log()
	if not lines.is_empty():
		var d: Dictionary = lines[lines.size() - 1]
		_set_hint(String(d["text"]), UI.GREEN if used else UI.DIM)
	_pulse(before)
	_refresh()
	return used


func sleep_now() -> void:
	if busy or ended or sim.over:
		return
	var before := _snap()
	var day0 := sim.day
	sim.sleep()
	_after(day0, before)


func answer_trade(accept: bool) -> void:
	if sim.pending.is_empty():
		return
	var before := _snap()
	var day0 := sim.day
	sim.answer_trade(accept)
	_after(day0, before)


## Starts over in place with a new seed (from the death modal).
func restart() -> void:
	sim = SurvivalSim.new(difficulty, -1, town)
	map.sim = sim
	map.selected = "shelter"
	map.dead_k = 0.0
	map.heli_t = -1.0
	map.night_k = 0.0
	ended = false
	busy = false
	_rescue_shown = 0.0
	log_box.clear()
	hint.text = ""
	_flush_log()
	_refresh()


# --- after an action ------------------------------------------------------------------------

func _snap() -> Dictionary:
	return {"health": sim.health, "food": sim.food, "water": sim.water, "rad": sim.rad, "rescue": sim.rescue, "inv": sim.inv.duplicate()}


func _pulse(before: Dictionary) -> void:
	for k in ["health", "food", "water", "rad"]:
		if absf(float(sim.get(k)) - float(before[k])) >= 1.0:
			_flash[k] = 1.0
	if sim.rescue > float(before["rescue"]) + 0.5:
		_flash["rescue"] = 1.0


func _after(day0: int, before: Dictionary) -> void:
	var lines := _flush_log()
	_pulse(before)
	_refresh()
	if not sim.pending.is_empty():
		_show_trade()
		return
	if sim.over:
		_end()
		return
	if sim.day != day0:
		hint.text = ""
		_night(lines)


func _night(lines: Array) -> void:
	busy = true
	map.night_text = "NIGHT %d" % (sim.day - 1)
	var tw := create_tween()
	tw.tween_property(map, "night_k", 1.0, 0.5)
	tw.tween_interval(0.45)
	tw.tween_property(map, "night_k", 0.0, 0.7)
	await tw.finished
	busy = false
	if ended or not is_inside_tree():
		return
	# the summary shows everything from nightfall onwards
	var start := -1
	for i in lines.size():
		var d: Dictionary = lines[i]
		if String(d["kind"]) == "night" and String(d["text"]).begins_with("Night "):
			start = i
			break
	if start < 0:
		return
	var m := Modal.new("Night %d" % (sim.day - 1), 500.0)
	for i in range(start + 1, lines.size()):
		var d: Dictionary = lines[i]
		var col := Color.html(String(LOG_COL.get(String(d["kind"]), "#ebdfc7")))
		var l := m.add_text(String(d["text"]), 17 if String(d["kind"]) != "morning" else 19, col)
		if String(d["kind"]) == "morning":
			l.add_theme_constant_override("outline_size", 0)
	m.add_buttons([["Get Up", m.close]])
	add_child(m)


func _end() -> void:
	if ended:
		return
	ended = true
	busy = true
	sleep_btn.disabled = true
	if sim.result == "rescued":
		map.selected = "shelter"
		map.heli_t = 0.0
		await get_tree().create_timer(4.6).timeout
		if is_inside_tree():
			_show_rescued()
	else:
		var tw := create_tween()
		tw.tween_property(map, "dead_k", 1.0, 1.4)
		await tw.finished
		if is_inside_tree():
			_show_died()


# --- modals -----------------------------------------------------------------------------------

func _show_intro() -> void:
	var m := Modal.new("After the Flash", 520.0)
	m.sticky = true
	m.add_text("The flash. The roar. Then nothing. %s is gone." % town, 21, UI.TEXT)
	m.add_text("You wake in a basement on Day 1, Morning, with one can of food, one bottle of water and a bandage.", 17, UI.TEXT)
	m.add_text("Find food and water: they run down every few hours, and faster at night. Mind the radiation.", 16, UI.DIM)
	m.add_text("Let the authorities know you're alive: paint SOS, light signal fires, build a radio, fire flares at helicopters. When the Rescue meter fills, they come for you.", 16, UI.DIM)
	m.add_text("Each day has three slots: Morning, Afternoon, Evening. Far places take two. Eating, drinking and first aid take no time.", 16, UI.DIM)
	m.add_buttons([["Climb Out", m.close]])
	add_child(m)


func _show_trade() -> void:
	var p := sim.pending
	var m := Modal.new("A Survivor", 480.0)
	m.sticky = true
	m.add_text(sim.trade_text(), 18, UI.TEXT)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 76)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func():
		var c := pic.size * 0.5
		var s := 64.0
		SurvivalArt.draw_item(pic, String(p["give"]), Rect2(c - Vector2(s * 1.9, s * 0.5), Vector2(s, s)), _t)
		SurvivalArt.draw_item(pic, String(p["get"]), Rect2(c + Vector2(s * 0.9, -s * 0.5), Vector2(s, s)), _t)
		var col := UI.GOLD
		pic.draw_line(c + Vector2(-s * 0.6, -8), c + Vector2(s * 0.6, -8), col, 3.0)
		pic.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.6, -15), c + Vector2(s * 0.8, -8), c + Vector2(s * 0.6, -1)]), col)
		pic.draw_line(c + Vector2(s * 0.6, 8), c + Vector2(-s * 0.6, 8), col, 3.0)
		pic.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, 1), c + Vector2(-s * 0.8, 8), c + Vector2(-s * 0.6, 15)]), col)
		if int(p["get_n"]) > 1:
			var font := ThemeDB.fallback_font
			pic.draw_string_outline(font, c + Vector2(s * 1.6, s * 0.5), "x%d" % int(p["get_n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0))
			pic.draw_string(font, c + Vector2(s * 1.6, s * 0.5), "x%d" % int(p["get_n"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.TEXT))
	m.add(pic)
	m.add_buttons([["Trade", func():
		m.close()
		answer_trade(true)], ["No Thanks", func():
		m.close()
		answer_trade(false)]])
	add_child(m)


func _show_rescued() -> void:
	var m := Modal.new("Rescued!", 500.0)
	m.sticky = true
	m.add_text("A helicopter lifts you out of what's left of %s. You survived %d day%s in the ruins." % [town, sim.day, "" if sim.day == 1 else "s"], 19, UI.TEXT)
	m.add_text(_summary(), 16, UI.DIM)
	var best := _top_sources()
	if best != "":
		m.add_text(best, 16, Color(0.6, 0.75, 1.0))
	m.add_buttons([["Main Menu", func():
		m.close()
		_finish("rescued")]])
	add_child(m)


func _show_died() -> void:
	var m := Modal.new("You Died", 500.0)
	m.sticky = true
	m.add_text(sim.death_text(), 19, UI.TEXT)
	m.add_text("You lasted %d day%s in the ruins of %s. Rescue was %d%% of the way to you." % [sim.day, "" if sim.day == 1 else "s", town, int(sim.rescue)], 16, UI.DIM)
	m.add_text(_summary(), 16, UI.DIM)
	m.add_buttons([["Try Again", func():
		m.close()
		restart()], ["Main Menu", func():
		m.close()
		_finish("died")]])
	add_child(m)


func _summary() -> String:
	var st := sim.stats
	return "Trips outside: %d.  Items found: %d.  Broadcasts: %d.  Signals: %d.  Peak radiation: %d." % [
		int(st["trips"]), int(st["found"]), int(st["broadcasts"]), int(st["signals"]), int(round(float(st["peak_rad"])))]


func _top_sources() -> String:
	var by: Dictionary = sim.stats["rescue_by"]
	var names := {"search": "search teams", "sos": "your SOS", "fire": "signal fires", "radio": "your radio", "mirror": "the mirror",
		"flare": "flares", "tower": "the big transmitter"}
	var keys := by.keys()
	keys.sort_custom(func(a, b): return float(by[a]) > float(by[b]))
	var parts := PackedStringArray()
	for i in mini(3, keys.size()):
		parts.append("%s %d%%" % [names.get(keys[i], keys[i]), int(round(float(by[keys[i]])))])
	if parts.is_empty():
		return ""
	return "What got you found: " + ", ".join(parts) + "."


func _finish(result: String) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(result)


# --- drawn widgets ------------------------------------------------------------------------------

func _draw_rescue() -> void:
	var c := rescue_bar
	var w := c.size.x
	var font := ThemeDB.fallback_font
	var flash: float = float(_flash.get("rescue", 0.0))
	c.draw_string(font, Vector2(0, 19), "RESCUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, UI.GOLD)
	var pct := "%d%%" % int(floor(_rescue_shown))
	var fs := 26
	var tw := font.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pc := Color(0.6, 0.78, 1.0).lerp(Color(1, 1, 1), flash)
	c.draw_string(font, Vector2(w - tw, 22), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pc)
	if w - tw > 240.0:
		c.draw_string(font, Vector2(82, 19), "until they find you", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UI.DIM.r, UI.DIM.g, UI.DIM.b, 0.85))
	var bar := Rect2(0, 30, w, 24)
	c.draw_rect(bar, Color(0.06, 0.05, 0.06))
	var k := clampf(_rescue_shown / 100.0, 0.0, 1.0)
	if k > 0.0:
		var fr := Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y))
		SurvivalArt.grad(c, fr, Color(0.45, 0.65, 1.0), Color(0.22, 0.38, 0.8))
		# a light sweeping along the fill
		var sx := fposmod(_t * 0.35, 1.0) * fr.size.x
		c.draw_rect(Rect2(fr.position + Vector2(sx, 0), Vector2(minf(18.0, fr.size.x - sx), fr.size.y)), Color(1, 1, 1, 0.12))
		if flash > 0.0:
			c.draw_rect(fr, Color(1, 1, 1, 0.35 * flash))
	for i in range(1, 4):
		var x := bar.size.x * i / 4.0
		c.draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.5), 1.0)
	c.draw_rect(bar, Color(0.52, 0.41, 0.29), false, 2.0)
	# the helicopter waiting at the far end
	SurvivalArt.draw_helicopter(c, Vector2(w - 24, bar.get_center().y + 1), 30.0, _t, -1.0, Color(0.72, 0.74, 0.66))


func _draw_stats() -> void:
	var c := stats_box
	var font := ThemeDB.fallback_font
	var keys := ["health", "food", "water", "rad"]
	var names := {"health": "Health", "food": "Food", "water": "Water", "rad": "Radiation"}
	var gap := 14.0
	var cw := (c.size.x - gap) * 0.5
	for i in 4:
		var k: String = keys[i]
		var v: float = float(sim.get(k))
		var x := (i % 2) * (cw + gap)
		var y := (38.0 if i >= 2 else 0.0)
		var col: Color = STAT_COL[k]
		var low := (k != "rad" and v < 25.0) or (k == "rad" and v > SurvivalSim.RAD_SAFE)
		var blink := 0.5 + 0.5 * sin(_t * 7.0) if low else 0.0
		var lc := UI.TEXT.lerp(UI.RED, blink) if low else UI.TEXT
		c.draw_string(font, Vector2(x, y + 15), String(names[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, lc)
		var vs := str(int(round(v)))
		var tw := font.get_string_size(vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		c.draw_string(font, Vector2(x + cw - tw, y + 15), vs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col.lightened(0.25))
		var bar := Rect2(x, y + 20, cw, 12)
		c.draw_rect(bar, Color(0.06, 0.05, 0.06))
		var fr := Rect2(bar.position, Vector2(bar.size.x * clampf(v / 100.0, 0.0, 1.0), bar.size.y))
		var fc := col
		if k == "rad" and v > SurvivalSim.RAD_SAFE:
			fc = Color(0.95, 0.35, 0.2)
		SurvivalArt.grad(c, fr, fc.lightened(0.15), fc.darkened(0.25))
		var fl: float = float(_flash.get(k, 0.0))
		if fl > 0.0:
			c.draw_rect(bar, Color(1, 1, 1, 0.3 * fl))
		if k == "rad":
			var mx := bar.position.x + bar.size.x * SurvivalSim.RAD_SAFE / 100.0
			c.draw_line(Vector2(mx, bar.position.y - 3), Vector2(mx, bar.end.y + 3), Color(1.0, 0.85, 0.3), 2.0)
		c.draw_rect(bar, Color(0.52, 0.41, 0.29, 0.9), false, 1.0)


func _draw_weather() -> void:
	var c := wx_icon
	var ctr := c.size * 0.5
	var s := c.size.x * 0.5
	c.draw_circle(ctr, s, Color(0.12, 0.08, 0.07))
	var sun_col: Color = [Color(1.0, 0.8, 0.45), Color(1.0, 0.7, 0.3), Color(0.95, 0.45, 0.25)][clampi(sim.slot, 0, 2)]
	var sun_y: float = [0.1, -0.18, 0.2][clampi(sim.slot, 0, 2)]
	var sp := ctr + Vector2(-s * 0.12, s * sun_y)
	match sim.weather:
		"clear":
			for i in 8:
				var a := TAU * i / 8.0 + _t * 0.3
				c.draw_line(sp + Vector2(cos(a), sin(a)) * s * 0.42, sp + Vector2(cos(a), sin(a)) * s * 0.62, sun_col, 2.0)
			c.draw_circle(sp, s * 0.32, sun_col)
		"haze":
			c.draw_circle(sp, s * 0.32, Color(sun_col.r, sun_col.g, sun_col.b, 0.55))
			for i in 2:
				c.draw_line(ctr + Vector2(-s * 0.6, s * (0.25 + i * 0.22)), ctr + Vector2(s * 0.6, s * (0.25 + i * 0.22)), Color(0.6, 0.45, 0.35, 0.8), 3.0)
		_:
			c.draw_circle(sp + Vector2(-s * 0.15, -s * 0.15), s * 0.26, Color(sun_col.r, sun_col.g, sun_col.b, 0.4))
			var cc := Color(0.5, 0.46, 0.44) if sim.weather == "overcast" else Color(0.42, 0.4, 0.4)
			c.draw_circle(ctr + Vector2(-s * 0.25, s * 0.1), s * 0.3, cc)
			c.draw_circle(ctr + Vector2(s * 0.12, -s * 0.02), s * 0.38, cc)
			c.draw_circle(ctr + Vector2(s * 0.42, s * 0.14), s * 0.26, cc)
			c.draw_rect(Rect2(ctr + Vector2(-s * 0.5, s * 0.1), Vector2(s * 1.1, s * 0.28)), cc)
			if sim.weather == "ash":
				for i in 5:
					var k := fposmod(_t * 0.6 + i * 0.2, 1.0)
					c.draw_rect(Rect2(ctr + Vector2(-s * 0.4 + i * s * 0.2, s * (0.45 + k * 0.4)), Vector2(2.5, 2.5)), Color(0.85, 0.82, 0.8, 1.0 - k))
	c.draw_arc(ctr, s, 0, TAU, 28, Color(0.52, 0.41, 0.29), 2.0, true)
