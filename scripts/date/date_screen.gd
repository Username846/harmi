class_name DateScreen
extends Control
## Take a chess piece on a date to lift its mood: pick a venue, get through
## three rounds of small talk, then see how its mood changed.
##
## setup(info) is called before add_child. info keys: date_type (1 pawn ..
## 6 king), date_color (0 white, 1 black), date_id (piece id for the Game mood
## calls), date_mood (0-100), own (true = one of the player's pieces).
## Emits finished("done") once the date has happened (the player's turn is
## used and the mood has changed, exactly once) or finished("cancel") when
## the player backs out at the venue selection (nothing is spent).

signal finished(result: String)

const LOG_DATE := "#e0aa4a"
const LOG_YOU := "#8fc3ff"
const LOG_NOTE := "#a9a39f"

var info: Dictionary = {}
var date_type := 1
var date_color := 1
var date_id := 0
var start_mood := 50.0
var own := true
var date_name := ""

var rng := RandomNumberGenerator.new()
var scene: DateScene
var panel: PanelContainer
var header: Label
var sub: Label
var body: VBoxContainer
var footer: HBoxContainer
var mood_bar: DateMoodBar
var wallet_label: Label
var go_button: Button
var log_box: RichTextLabel
var reply_box: VBoxContainer

var stage := "venue" # venue -> date -> result -> gone
var venue_id := "park"
var venue_cards: Dictionary = {}
var base := 0
var bonus := 0
var prompts: Array = []
var round_i := 0
var scores: Array = []
var busy := false
var applied := false
var _next: Callable = Callable()
var _relayout_queued := false


func setup(i: Dictionary) -> void:
	info = i
	date_type = clampi(int(i.get("date_type", 1)), 1, 6)
	date_color = int(i.get("date_color", 1))
	date_id = int(i.get("date_id", 0))
	own = bool(i.get("own", true))
	if i.has("date_mood"):
		start_mood = clampf(float(i["date_mood"]), 0.0, 100.0)
	else:
		start_mood = Game.mood_of(date_id)
	date_name = Game.piece_title(date_type, date_color)
	rng.randomize()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if date_name == "":
		setup(info)
	scene = DateScene.new()
	scene.piece_type = date_type
	scene.piece_white = date_color == 0
	scene.mood_shown = start_mood
	scene.mood_target = start_mood
	scene.title = "A Date with the " + date_name
	scene.tapped.connect(_on_scene_tapped)
	add_child(scene)

	panel = PanelContainer.new()
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	header = UI.label("", 24, UI.GOLD)
	vb.add_child(header)
	sub = UI.label("", 16, UI.DIM)
	vb.add_child(sub)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	vb.add_child(body)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	vb.add_child(footer)

	resized.connect(_relayout)
	panel.minimum_size_changed.connect(_queue_relayout)
	Game.money_changed.connect(_refresh_venues)
	_show_venues()
	_relayout()


func _exit_tree() -> void:
	if Game.money_changed.is_connected(_refresh_venues):
		Game.money_changed.disconnect(_refresh_venues)


func _unhandled_input(event: InputEvent) -> void:
	if stage == "venue" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel()


# --- layout ----------------------------------------------------------------------

func _relayout() -> void:
	if panel == null:
		return
	var w := size.x
	var h := size.y
	var m := 12.0
	var inset := DateScene.INSET
	if w >= h * 1.15:
		var pw := clampf(w * 0.38, 300.0, 460.0)
		scene.position = Vector2(m - inset, m - inset)
		scene.size = Vector2(w - pw - m * 3.0 + inset * 2.0, h - m * 2.0 + inset * 2.0)
		panel.position = Vector2(w - pw - m, m)
		panel.size = Vector2(pw, h - m * 2.0)
	else:
		var pmin := panel.get_combined_minimum_size().y
		var ph := minf(w * 0.95, h * 0.5)
		ph = maxf(minf(ph, h - pmin - m * 3.0), 230.0)
		scene.position = Vector2(m - inset, m - inset)
		scene.size = Vector2(w - m * 2.0 + inset * 2.0, ph + inset * 2.0)
		var top := m * 2.0 + ph
		panel.position = Vector2(m, top)
		panel.size = Vector2(w - m * 2.0, maxf(h - top - m, 0.0))


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


# --- small helpers -------------------------------------------------------------------

func _clear(c: Node) -> void:
	for ch in c.get_children():
		if ch is CanvasItem:
			ch.visible = false
		ch.queue_free()


func _btn(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _log(t: String) -> void:
	if log_box:
		log_box.append_text(t + "\n")


func _esc(t: String) -> String:
	return t.replace("[", "[lb]")


func _say(text: String) -> void:
	scene.say(text)
	_log("[color=%s]%s:[/color] %s" % [LOG_DATE, date_name, _esc(text)])


func _log_you(text: String) -> void:
	_log("[color=%s]You:[/color] %s" % [LOG_YOU, _esc(text)])


func _note(text: String) -> void:
	_log("[color=%s][i]%s[/i][/color]" % [LOG_NOTE, _esc(text)])


func _set_continue(text: String, cb: Callable) -> void:
	_next = cb
	_clear(footer)
	footer.add_child(_btn(text, _on_continue))


func _on_continue() -> void:
	if busy or not _next.is_valid():
		return
	var cb := _next
	_next = Callable()
	_clear(footer)
	cb.call()


func _on_scene_tapped() -> void:
	if stage == "date" and _next.is_valid():
		_on_continue()


# --- 1. venue selection ------------------------------------------------------------

func _show_venues() -> void:
	stage = "venue"
	header.text = "A Date with the " + date_name
	if own:
		sub.text = "One of yours. Happy pieces fight harder."
	else:
		sub.text = "An enemy piece. Your side will have questions."
	_clear(body)
	mood_bar = DateMoodBar.new()
	mood_bar.set_values(start_mood, start_mood, false)
	body.add_child(mood_bar)
	wallet_label = UI.label("", 17, UI.GOLD)
	body.add_child(wallet_label)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	venue_cards.clear()
	for v in DateData.VENUES:
		var vd: Dictionary = v
		var card := _venue_card(vd)
		list.add_child(card)
		venue_cards[String(vd["id"])] = card
	_clear(footer)
	footer.add_child(_btn("Never mind", _on_cancel))
	go_button = _btn("Let's go!", _on_go)
	footer.add_child(go_button)
	scene.say(DateData.greeting(start_mood, own, date_type))
	_select_venue("park", false)


func _venue_card(v: Dictionary) -> DateChoice:
	var card := DateChoice.new()
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	var name_l := UI.label(String(v["name"]), 18, UI.TEXT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var price: int = v["price"]
	var price_l := UI.label("Free" if price == 0 else "$%d" % price, 18, UI.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	price_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(price_l)
	var desc := UI.label(String(v["desc"]), 15, UI.DIM)
	desc.visible = false
	vb.add_child(desc)
	card.set_meta("desc", desc)
	card.set_meta("price_label", price_l)
	card.set_meta("price", price)
	card.chosen.connect(_select_venue.bind(String(v["id"]), true))
	return card


func _select_venue(id: String, react: bool = true) -> void:
	if stage != "venue":
		return
	venue_id = id
	scene.venue = id
	for vid in venue_cards:
		var c: DateChoice = venue_cards[vid]
		c.selected = vid == id
		var d: Label = c.get_meta("desc")
		d.visible = vid == id
	if react:
		# a little tell: hearts if it likes the idea, a sweat drop if not
		var b := DateData.pref_bonus(date_type, id, start_mood)
		if b > 0:
			scene.love(clampi(b / 2, 2, 5))
		elif b < 0:
			scene.worry()
	_refresh_venues()


func _refresh_venues() -> void:
	if stage != "venue" or go_button == null:
		return
	var money: int = Game.money
	wallet_label.text = "Your purse: $%d. The date uses your turn." % money
	for vid in venue_cards:
		var c: DateChoice = venue_cards[vid]
		var price: int = c.get_meta("price")
		var short := price > money
		c.disabled = short
		var pl: Label = c.get_meta("price_label")
		pl.add_theme_color_override("font_color", UI.RED if short else UI.GOLD)
	var v := DateData.venue(venue_id)
	var p: int = v["price"]
	go_button.disabled = p > money
	go_button.text = "Let's go! (free)" if p == 0 else "Let's go! ($%d)" % p


func _on_cancel() -> void:
	if stage != "venue" or busy:
		return
	stage = "gone"
	finished.emit("cancel")


func _on_go() -> void:
	if stage != "venue" or busy:
		return
	var v := DateData.venue(venue_id)
	if v.is_empty():
		return
	if not Game.spend(int(v["price"])):
		_refresh_venues()
		return
	_start_date(v)


# --- 2. the date ---------------------------------------------------------------------

func _start_date(v: Dictionary) -> void:
	stage = "date"
	base = int(v["base"])
	bonus = DateData.pref_bonus(date_type, venue_id, start_mood)
	prompts = DateData.pick_prompts(date_type, rng)
	round_i = 0
	scores.clear()
	scene.title = String(v["name"])
	header.text = String(v["name"])
	sub.text = "On a date with the %s." % date_name
	_clear(body)
	log_box = UI.rich(17)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.custom_minimum_size = Vector2(0, 72)
	body.add_child(log_box)
	reply_box = VBoxContainer.new()
	reply_box.add_theme_constant_override("separation", 8)
	body.add_child(reply_box)
	var price: int = v["price"]
	if price > 0:
		_note("You pay $%d. Your purse: $%d." % [price, Game.money])
	_say(DateData.opener(start_mood, own, rng, date_type))
	_set_continue("Continue", _venue_beat)


func _venue_beat() -> void:
	_say(DateData.pref_line(date_type, venue_id))
	if venue_id == "cruise" and start_mood < DateData.GLOOMY_BELOW:
		_note(DateData.GLOOMY_CRUISE_LINE)
	if bonus > 0:
		scene.love(clampi(bonus, 3, 10))
		if bonus >= 8:
			scene.hop()
	elif bonus < 0:
		scene.worry()
		if bonus <= -8:
			scene.rain()
	_update_projection()
	_set_continue("Start talking", _ask)


func _ask() -> void:
	if round_i >= prompts.size():
		_finish()
		return
	var p: Dictionary = prompts[round_i]
	sub.text = "Round %d of %d. What do you say?" % [round_i + 1, prompts.size()]
	_say(String(p["q"]))
	_clear(reply_box)
	for rep in DateData.shuffled_replies(p, rng):
		var ra: Array = rep
		var card := DateChoice.text_card(String(ra[0]), 17)
		card.chosen.connect(_on_reply.bind(ra))
		reply_box.add_child(card)


func _on_reply(rep: Array) -> void:
	if busy or stage != "date":
		return
	busy = true
	var text: String = rep[0]
	var sc: int = rep[1]
	var reaction: String = rep[2]
	_clear(reply_box)
	scores.append(sc)
	_log_you(text)
	scene.say_you(text)
	await get_tree().create_timer(1.1).timeout
	if not is_inside_tree():
		return
	_say(reaction)
	scene.react(sc)
	_update_projection()
	round_i += 1
	busy = false
	if round_i >= prompts.size():
		_set_continue("How did it go?", _finish)
	else:
		_set_continue("Continue", _ask)


func _score_sum() -> int:
	var sum := 0
	for s in scores:
		sum += int(s)
	return sum


## Where the mood is heading if the date ended right now.
func _projected() -> float:
	return clampf(start_mood + DateData.compute_delta(base, bonus, _score_sum()), 0.0, 100.0)


func _update_projection() -> void:
	var before := scene.mood_target
	var now := _projected()
	scene.mood_target = now
	var d := int(round(now - before))
	if d != 0:
		scene.float_text("%+d" % d, UI.GREEN if d > 0 else UI.RED)


# --- 3. the result ---------------------------------------------------------------------

func _finish() -> void:
	if applied:
		return
	applied = true
	stage = "result"
	var sum := _score_sum()
	var great := 0
	var fine := 0
	var awkward := 0
	for s in scores:
		var si: int = s
		if si >= 2:
			great += 1
		elif si == 1:
			fine += 1
		else:
			awkward += 1
	var delta := DateData.compute_delta(base, bonus, sum)
	var before := Game.mood_of(date_id)
	var after := Game.change_mood(date_id, float(delta))
	scene.mood_target = after
	var close := DateData.closer(date_type, delta, own, rng)
	scene.say(close)
	if delta >= 30:
		scene.love(18)
		scene.hop()
	elif delta >= 15:
		scene.love(9)
	elif delta > 0:
		scene.love(3)
	else:
		scene.rain()

	header.text = "How It Went"
	sub.text = "Your date with the %s is over." % date_name
	_clear(body)
	log_box = null
	reply_box = null
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	body.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)
	var bar := DateMoodBar.new()
	bar.set_values(before, after, true)
	vb.add_child(bar)
	var v := DateData.venue(venue_id)
	vb.add_child(_row(String(v["name"]), base))
	var fit := "It didn't mind the venue"
	if bonus >= 5:
		fit = "It loved the venue"
	elif bonus > 0:
		fit = "It liked the venue"
	elif bonus <= -5:
		fit = "It hated the venue"
	elif bonus < 0:
		fit = "It wasn't keen on the venue"
	vb.add_child(_row(fit, bonus))
	vb.add_child(_row("Small talk: %d great, %d fine, %d awkward" % [great, fine, awkward], DateData.REPLY_WEIGHT * sum))
	var raw := base + bonus + DateData.REPLY_WEIGHT * sum
	vb.add_child(_row("Mood change" + (" (capped)" if raw != delta else ""), delta, true))
	var mb := int(round(Game.mood_mult(before) * 100.0))
	var ma := int(round(Game.mood_mult(after) * 100.0))
	vb.add_child(UI.label("In duels it now fights at %d%% strength (was %d%%)." % [ma, mb], 16, UI.DIM))
	if not own and delta > 0:
		vb.add_child(UI.label("A cheerful enemy fights harder too. Love is complicated.", 15, UI.DIM))
	vb.add_child(UI.label("\"%s\"" % close, 17, UI.TEXT))
	_clear(footer)
	footer.add_child(_btn("Back to the Board", _on_done))


func _row(label_text: String, value: int, strong: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UI.label(label_text, 17 if strong else 16, UI.GOLD if strong else UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var col := UI.DIM
	if value > 0:
		col = UI.GREEN
	elif value < 0:
		col = UI.RED
	var vl := UI.label("%+d" % value, 17 if strong else 16, col, HORIZONTAL_ALIGNMENT_RIGHT)
	vl.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(vl)
	return row


func _on_done() -> void:
	if stage != "result":
		return
	stage = "gone"
	finished.emit("done")
