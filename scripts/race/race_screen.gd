class_name RaceScreen
extends Control
## Pink slip drag race between the player's piece and an enemy piece. The
## loser signs over its car. Emits finished("won") or finished("lost").
## setup() must be called before the screen enters the tree.

signal finished(result: String)

const SHIFT_TEXT := {"perfect": "PERFECT SHIFT!", "good": "Good shift", "early": "Too early!",
	"late": "Late - bogging", "redline": "REDLINE - bogged!"}
const SHIFT_HINT := {"perfect": "Perfect shift! The engine sings.", "good": "Good shift. The gold sweet spot is better.",
	"early": "Too early - the engine lugs. Wait for the green band.", "late": "Late - the engine bogged. Shift a touch sooner.",
	"redline": "You sat on the limiter and bogged down!"}
const SHIFT_COL := {"perfect": UI.GOLD, "good": UI.GREEN, "early": Color(0.6, 0.72, 0.95), "late": UI.EMBER, "redline": UI.RED}

var info: Dictionary = {}
var sim: RaceSim
var view: RaceView
var panel: PanelContainer
var box: BoxContainer
var tach: Control
var side: VBoxContainer
var title_label: Label
var status: Label
var main_btn: Button
var nos_btn: Button
var hero_type := 2
var foe_type := 4
var hero_white := true
var foe_white := false
var hero_mood := 72.0
var foe_mood := 72.0
var hero_name := "Your piece"
var foe_name := "the rival"
var has_nos := false
var phase := "intro" # intro -> run -> over
var result := ""
var _decided_t := 0.0
var _over_t := 0.0
var _result_shown := false
var _btn_mode := ""
var _nos_mode := ""
var _t := 0.0
var _relayout_queued := false


func setup(i: Dictionary) -> void:
	info = i
	hero_type = clampi(int(i.get("hero_type", 2)), 1, 6)
	foe_type = clampi(int(i.get("foe_type", 4)), 1, 6)
	hero_white = int(i.get("hero_color", 0)) == 0
	foe_white = int(i.get("foe_color", 1)) == 0
	hero_mood = float(i.get("hero_mood", 72.0))
	foe_mood = float(i.get("foe_mood", 72.0))
	hero_name = Game.piece_title(hero_type, 0 if hero_white else 1)
	foe_name = Game.piece_title(foe_type, 0 if foe_white else 1)
	has_nos = Game.has_item("nitrous")
	sim = RaceSim.new(hero_type, foe_type, hero_mood, foe_mood, int(i.get("difficulty", 1)), has_nos)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if sim == null:
		setup({})
	view = RaceView.new()
	view.sim = sim
	view.hero_type = hero_type
	view.foe_type = foe_type
	view.hero_white = hero_white
	view.foe_white = foe_white
	view.hero_label = "You: " + hero_name
	view.foe_label = foe_name
	add_child(view)
	panel = PanelContainer.new()
	add_child(panel)
	box = BoxContainer.new()
	box.vertical = true
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	tach = Control.new()
	tach.custom_minimum_size = Vector2(150, 150)
	tach.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tach.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tach.draw.connect(_draw_tach)
	box.add_child(tach)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.25
	side.alignment = BoxContainer.ALIGNMENT_END
	side.add_theme_constant_override("separation", 8)
	box.add_child(side)
	title_label = UI.label("PINK SLIP RACE", 15, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	side.add_child(title_label)
	status = UI.label("", 17, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	status.custom_minimum_size = Vector2(0, 46)
	status.max_lines_visible = 2
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	side.add_child(status)
	main_btn = UI.button("GO", _on_main, 96)
	main_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	main_btn.add_theme_font_size_override("font_size", 34)
	side.add_child(main_btn)
	nos_btn = UI.button("NOS", _on_nos, 64)
	nos_btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	nos_btn.add_theme_font_size_override("font_size", 24)
	nos_btn.visible = has_nos
	side.add_child(nos_btn)
	resized.connect(_relayout)
	panel.minimum_size_changed.connect(_queue_relayout)
	_relayout()
	_update_buttons()
	_set_status("Pink slips on the line.")
	_show_intro()


# --- layout ----------------------------------------------------------------------

func _relayout() -> void:
	if panel == null:
		return
	var w := size.x
	var h := size.y
	var m := 12.0
	if w >= h * 1.15:
		_set_vertical(true)
		_size_buttons(104.0, 70.0)
		var cw := clampf(w * 0.34, 290.0, 420.0)
		view.position = Vector2(m, m)
		view.size = Vector2(w - cw - m * 3.0, h - m * 2.0)
		panel.position = Vector2(w - cw - m, m)
		panel.size = Vector2(cw, h - m * 2.0)
	else:
		var vh := minf(w * 0.9, h * 0.5)
		var rest := h - vh - m * 3.0
		var tall := rest >= 440.0
		_set_vertical(tall)
		_size_buttons(110.0 if tall else 78.0, 72.0 if tall else 60.0)
		var pmin := panel.get_combined_minimum_size().y
		if rest < pmin:
			vh = maxf(200.0, h - pmin - m * 3.0)
			rest = h - vh - m * 3.0
		view.position = Vector2(m, m)
		view.size = Vector2(w - m * 2.0, vh)
		panel.position = Vector2(m, vh + m * 2.0)
		panel.size = Vector2(w - m * 2.0, rest)


func _set_vertical(v: bool) -> void:
	if box.vertical != v:
		box.vertical = v
	title_label.visible = v
	tach.custom_minimum_size = Vector2(150, 150) if v else Vector2(150, 0)


func _size_buttons(main_h: float, nos_h: float) -> void:
	if main_btn.custom_minimum_size.y != main_h:
		main_btn.custom_minimum_size = Vector2(0, main_h)
	if nos_btn.custom_minimum_size.y != nos_h:
		nos_btn.custom_minimum_size = Vector2(0, nos_h)


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


# --- intro / result -----------------------------------------------------------------

static func _a(word: String) -> String:
	return ("an " if "aeiou".contains(word.left(1)) else "a ") + word


func _show_intro() -> void:
	var m := Modal.new("Pink Slips on the Line", 500.0)
	m.sticky = true
	m.add_text("Your %s (%s) revs %s beside the %s (%s) in %s. Winner takes the loser's car." % [
		hero_name, Game.mood_name(hero_mood), _a(RaceArt.CAR_NAMES[hero_type]),
		foe_name, Game.mood_name(foe_mood), _a(RaceArt.CAR_NAMES[foe_type])])
	m.add_text("GO: tap the moment the tree turns green. Jump the light and you stall.", 17, UI.DIM)
	m.add_text("SHIFT: tap while the needle is in the green band. The gold sweet spot gives a burst of speed; too early lugs the engine, too late bogs it. Four gears.", 17, UI.DIM)
	if has_nos:
		m.add_text("NOS: your Nitrous Bottle gives one 2-second burst. It is used up when you fire it.", 17, Color(0.6, 0.75, 1.0))
	if foe_mood < 45.0:
		m.add_text("The %s looks gloomy. Its head may not be in the race." % foe_name, 16, UI.DIM)
	elif foe_mood >= 85.0:
		m.add_text("The %s is elated and hungry for your car." % foe_name, 16, UI.DIM)
	m.add_buttons([["Light the Tree", func():
		m.close()
		_start()]])
	add_child(m)


func _start() -> void:
	phase = "run"
	sim.start_tree()
	_set_status("Watch the tree. Tap GO on green!")


func _finish() -> void:
	phase = "over"
	_over_t = 0.0
	var won := sim.hero_won()
	result = "won" if won else "lost"
	view.set_banner("YOU WIN!" if won else "YOU LOSE", "%.2f s  vs  %.2f s" % [sim.hero.finish, sim.foe.finish], UI.GOLD if won else UI.EMBER)
	_set_status("You %.2f s, the %s %.2f s." % [sim.hero.finish, foe_name, sim.foe.finish])


func _show_result() -> void:
	_result_shown = true
	var won := result == "won"
	var m := Modal.new("Pink Slip Won!" if won else "Pink Slip Lost", 460.0)
	m.sticky = true
	if won:
		m.add_text("You win the %s's pink slip! It has no car and can't move." % foe_name)
	else:
		m.add_text("You signed over your pink slip. The %s drives off in your car, and your %s can't move without one." % [foe_name, hero_name])
	m.add_text("You %.2f s  -  %s %.2f s" % [sim.hero.finish, foe_name, sim.foe.finish], 17, UI.GOLD if won else UI.EMBER)
	var bits := PackedStringArray()
	if sim.hero.false_start:
		bits.append("False start")
	else:
		bits.append("Reaction %.3f s" % sim.hero.reaction)
	if not sim.hero.shifts.is_empty():
		bits.append("Shifts: " +", ".join(PackedStringArray(sim.hero.shifts)))
	m.add_text(". ".join(bits) + ".", 15, UI.DIM)
	m.add_buttons([["Return to the Board", func():
		m.close()
		finished.emit(result)]])
	add_child(m)


# --- input ---------------------------------------------------------------------------

func _on_main() -> void:
	if phase != "run":
		return
	if not sim.hero.launched and sim.hero.launch_at < 0.0:
		sim.press_go()
	else:
		sim.press_shift()
	_flush_events()


func _on_nos() -> void:
	if phase != "run":
		return
	if sim.press_nos():
		Game.remove_item("nitrous")
	_flush_events()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_SPACE or k.keycode == KEY_UP:
		_on_main()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_N:
		_on_nos()
		get_viewport().set_input_as_handled()


# --- frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	sim.step(delta)
	_flush_events()
	view.show_tree = phase == "run" and sim.tree_on and (not sim.hero.launched or sim.race_time() < 0.8)
	if phase == "run" and sim.decided():
		_decided_t += delta
		if not sim.finished() and _decided_t > 3.5:
			sim.run_to_end() # the straggler is a long way back; just finish it
			_flush_events()
		if sim.finished():
			_finish()
	elif phase == "over":
		_over_t += delta
		if _over_t > 2.2 and not _result_shown:
			_show_result()
	_update_buttons()
	tach.queue_redraw()


func _flush_events() -> void:
	for e in sim.pop_events():
		_on_event(e)


func _on_event(e: Dictionary) -> void:
	var kind: String = e["t"]
	var who: int = e.get("who", 0)
	match kind:
		"green":
			if not sim.hero.false_start:
				_set_status("GREEN! GO GO GO!")
		"false_start":
			view.on_stall(who)
			view.float_text(who, "FALSE START!", UI.RED, who == 0)
			if who == 0:
				_set_status("False start! You stalled it - restarting...")
			else:
				_set_status("The %s jumped the light and stalled!" % foe_name)
		"launch":
			view.on_launch(who)
			if who == 0:
				if sim.hero.false_start:
					_set_status("Engine's back! Shift in the green band.")
				else:
					var r := sim.hero.reaction
					var col := UI.GREEN if r < 0.25 else (UI.GOLD if r < 0.4 else UI.EMBER)
					view.float_text(0, "%.3f s" % r, col)
					_set_status("Reaction %.3f s. Shift in the green band!" % r)
		"froze":
			view.float_text(0, "Asleep at the light!", UI.DIM)
			_set_status("You froze at the light - the car rolls off on its own.")
		"shift":
			var q: String = e["q"]
			view.on_shift(who, q)
			if who == 0:
				view.float_text(0, SHIFT_TEXT[q], SHIFT_COL[q], q == "perfect")
				var hint: String = SHIFT_HINT[q]
				if sim.hero.gear >= RaceSim.GEARS:
					hint += " Top gear!"
					if sim.can_nos():
						hint += " Hit the NOS!"
				_set_status(hint)
			elif q == "late" or q == "redline":
				view.float_text(1, "bogged!", UI.EMBER)
		"limiter":
			if who == 0 and sim.hero.gear < RaceSim.GEARS:
				view.float_text(0, "SHIFT!", UI.RED)
		"nos":
			view.on_nos(0)
			view.float_text(0, "NOS!", RaceArt.NOS_BLUE.lightened(0.45), true)
			_set_status("Nitrous! Hold on to your crown.")
		"finish":
			if not sim.finished():
				var won := who == 0
				view.set_banner("YOU WIN!" if won else "YOU LOSE", "", UI.GOLD if won else UI.EMBER)
				if won:
					_set_status("You take the line first!")
				else:
					_set_status("The %s takes the line first..." % foe_name)


func _set_status(t: String) -> void:
	if status != null:
		status.text = t


# --- buttons -------------------------------------------------------------------------

static func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = true
	return sb


static func _paint(b: Button, bg: Color, border: Color, font_col: Color) -> void:
	b.add_theme_stylebox_override("normal", _style(bg, border))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.06), border.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _style(bg.lightened(0.22), border.lightened(0.3)))
	b.add_theme_stylebox_override("hover_pressed", _style(bg.lightened(0.22), border.lightened(0.3)))
	b.add_theme_stylebox_override("disabled", _style(bg.darkened(0.45), border.darkened(0.5)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, font_col)
	b.add_theme_color_override("font_disabled_color", font_col.darkened(0.5))


func _update_buttons() -> void:
	var c := sim.hero
	var mode := "intro"
	if phase == "over" or c.done():
		mode = "done"
	elif phase == "run":
		if not c.launched:
			if c.launch_at >= 0.0:
				mode = "stalled" if c.false_start else "go"
			else:
				mode = "go" if sim.is_green() else "wait"
		elif c.gear >= RaceSim.GEARS:
			mode = "top"
		else:
			mode = "shift"
	if mode != _btn_mode:
		_btn_mode = mode
		main_btn.disabled = mode in ["intro", "stalled", "top", "done"]
		match mode:
			"intro":
				main_btn.text = "GO"
				_paint(main_btn, Color(0.16, 0.13, 0.12), UI.BORDER, UI.TEXT)
			"wait":
				main_btn.text = "GO"
				_paint(main_btn, Color(0.2, 0.14, 0.07), RaceArt.AMBER, Color(1, 0.85, 0.6))
			"go":
				main_btn.text = "GO!"
				_paint(main_btn, Color(0.08, 0.42, 0.16), RaceArt.GO_GREEN, Color(0.95, 1, 0.95))
			"stalled":
				main_btn.text = "STALLED"
				_paint(main_btn, Color(0.4, 0.08, 0.06), UI.RED, Color(1, 0.8, 0.75))
			"shift":
				main_btn.text = "SHIFT"
				_paint(main_btn, Color(0.32, 0.21, 0.08), UI.GOLD, Color(1, 0.93, 0.75))
			"top":
				main_btn.text = "TOP GEAR"
				_paint(main_btn, Color(0.32, 0.21, 0.08), UI.GOLD, Color(1, 0.93, 0.75))
			"done":
				main_btn.text = "FINISHED"
				_paint(main_btn, Color(0.16, 0.13, 0.12), UI.BORDER, UI.TEXT)
	if not has_nos:
		return
	var nm := "wait"
	if c.nos_left > 0.0:
		nm = "burn"
	elif c.nos_used:
		nm = "used"
	elif sim.can_nos() and phase == "run":
		nm = "ready"
	if nm != _nos_mode:
		_nos_mode = nm
		nos_btn.disabled = nm != "ready"
		match nm:
			"wait":
				nos_btn.text = "NOS"
				_paint(nos_btn, Color(0.08, 0.12, 0.25), RaceArt.NOS_BLUE, Color(0.8, 0.88, 1))
			"ready":
				nos_btn.text = "NOS"
				_paint(nos_btn, Color(0.1, 0.2, 0.5), RaceArt.NOS_BLUE.lightened(0.3), Color(0.92, 0.96, 1))
			"burn":
				nos_btn.text = "NOS!!!"
				_paint(nos_btn, Color(0.3, 0.5, 1.0), Color(0.85, 0.95, 1), Color(1, 1, 1))
				nos_btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1))
			"used":
				nos_btn.text = "NOS USED"
				_paint(nos_btn, Color(0.08, 0.1, 0.18), Color(0.3, 0.35, 0.5), Color(0.6, 0.65, 0.8))


func _draw_tach() -> void:
	var c := sim.hero
	RaceArt.draw_tach(tach, Rect2(Vector2.ZERO, tach.size), {
		"rpm": c.rpm, "gear": c.gear if c.launched else 0, "kmh": c.speed * 3.6,
		"nos": c.nos_left > 0.0, "t": _t, "stalled": c.stalled})
