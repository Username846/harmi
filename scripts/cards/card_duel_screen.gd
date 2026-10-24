class_name CardDuelScreen
extends Control
## The graveyard card duel: a spiky-haired kid called Yugi Moto challenges you
## to "a children's card game". Win and one of your captured pieces rises from
## the grave. Call setup(info) before add_child; emits finished("won"/"lost").
##
## info: player_color (0 white / 1 black), wager_type (1 pawn .. 5 queen),
## difficulty (0 easy, 1 normal, 2 hard), for_reals (a shadow game: 12,000 LP,
## the hardest Yugi, a dark arena, and the loser goes to the Shadow Realm).
##
## The rules live in CardGame. This screen keeps a "view" copy of the table
## that it updates event by event while animating, then re-syncs with the engine.

signal finished(result: String)

const ME := 0
const YUGI := 1
const PIECE_NAMES := ["", "Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
const FELT_TOP := Color(0.13, 0.08, 0.15)
const FELT_BOTTOM := Color(0.15, 0.1, 0.08)
const BUBBLE := Color(0.98, 0.95, 0.87)

var info: Dictionary = {}
var game: CardGame
var player_white := true
var wager := 4
var difficulty := 1
var for_reals := false

# side panel
var panel: PanelContainer
var prompt_label: Label
var info_label: Label
var log_box: RichTextLabel
var rows: Array = []
var btn_cast: Button
var btn_direct: Button
var btn_end: Button
var btn_rules: Button
var btn_forfeit: Button
var _landscape := -1

# play mat layout (see _compute_layout)
var mat := Rect2()
var lay: Dictionary = {}

# what the table looks like right now (lags the engine while animating)
var view: Dictionary = {}
var sel_hand := -1
var sel_zone := -1
var hover_hand := -1
var busy := false
var yugi_busy := false
var over := false
var _emitted := false
var _info_default := "Tap any card to read it."

# effects
var t := 0.0
var disp_lp: Array = [4000.0, 4000.0]
var yugi_expr := "smug"
var bubble_text := ""
var bubble_time := 0.0
var bubble_age := 0.0
var floaters: Array = []
var sparks: Array = []
var flyers: Array = []
var ghosts: Array = []
var zone_off: Array = [[Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]]
var zone_flash: Array = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
var hidden_hand: Array = [{}, {}]
var shake := 0.0
var portrait_flash := 0.0
var heart_glow := 0.0
var swords_fx: Array = [0.0, 0.0]
var banner := ""
var banner_time := 0.0
var doom := "" # for reals: "yugi" or "player" while the shadows take the loser
var doom_t := 0.0
var drone: AudioStreamPlayer
var _shk := Vector2.ZERO
var _doom_layer: Control # drawn above the side panel while the player is swallowed


func setup(i: Dictionary) -> void:
	info = i
	player_white = int(i.get("player_color", 0)) == 0
	wager = clampi(int(i.get("wager_type", 4)), 1, 6)
	difficulty = clampi(int(i.get("difficulty", 1)), 0, 2)
	for_reals = bool(i.get("for_reals", false))
	if for_reals:
		difficulty = 2 # Yugi plays at his very best when it's for real
		yugi_expr = "determined"
	var deck: Array = CardData.base_deck() + _booster_cards()
	game = CardGame.new(deck, CardData.yugi_deck(difficulty), -1, difficulty)
	if for_reals:
		game.make_for_reals()
	disp_lp = [float(game.start_lp), float(game.start_lp)]


## Extra cards the player bought in booster packs (Game.decks[Game.active_side]).
func _booster_cards() -> Array:
	var out: Array = []
	for id in Game.decks[Game.active_side]:
		if CardData.has(String(id)):
			out.append(String(id))
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if game == null:
		setup(info)
	if for_reals and not game.for_reals:
		game.make_for_reals() # a test may swap in its own CardGame after setup
	disp_lp = [float(game.start_lp), float(game.start_lp)]
	_empty_view()
	_build_panel()
	if for_reals:
		panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.07, 0.035, 0.1, 0.97), Color(0.5, 0.26, 0.7)))
		drone = ShadowArt.play_drone(self, "duel", -13.0)
	resized.connect(_relayout)
	panel.minimum_size_changed.connect(_queue_relayout)
	_relayout()
	_intro()


func _exit_tree() -> void:
	if drone:
		drone.stop()


func _wager_name() -> String:
	return PIECE_NAMES[wager]


# --- panel ---------------------------------------------------------------------------

func _build_panel() -> void:
	panel = PanelContainer.new()
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	prompt_label = UI.label("", 17, UI.GOLD)
	vb.add_child(prompt_label)
	info_label = UI.label(_info_default, 15, UI.TEXT)
	vb.add_child(info_label)
	btn_cast = _mk_button("Cast", _on_cast)
	btn_direct = _mk_button("Attack Directly", _on_direct)
	btn_end = _mk_button("End Turn", _on_end_turn)
	btn_rules = _mk_button("Rules", _show_rules)
	btn_forfeit = _mk_button("Forfeit", _on_forfeit)
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vb.add_child(row)
		rows.append(row)
	log_box = UI.rich(15)
	log_box.custom_minimum_size = Vector2(0, 56)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(log_box)


func _mk_button(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb, 50)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	return b


## Landscape: [Cast][Attack Directly] / [End Turn] / [Rules][Forfeit]
## (a narrow side panel swaps End Turn and Attack Directly so the long label fits).
## Portrait:  [Cast][Attack Directly][End Turn] / [Rules][Forfeit].
func _arrange_buttons(landscape: bool, narrow: bool = false) -> void:
	for b in [btn_cast, btn_direct, btn_end, btn_rules, btn_forfeit]:
		if b.get_parent():
			b.get_parent().remove_child(b)
	var layout: Array = [[btn_cast, btn_direct, btn_end], [btn_rules, btn_forfeit], []]
	if landscape:
		layout = [[btn_cast, btn_end], [btn_direct], [btn_rules, btn_forfeit]] if narrow else [[btn_cast, btn_direct], [btn_end], [btn_rules, btn_forfeit]]
	for i in 3:
		var row: HBoxContainer = rows[i]
		for b in layout[i]:
			row.add_child(b)
		row.visible = not layout[i].is_empty()
	# fixed heights so the buttons never jump when the text changes
	var font := ThemeDB.fallback_font
	prompt_label.max_lines_visible = 3 if landscape else 2
	prompt_label.custom_minimum_size = Vector2(0, ceilf(font.get_height(17) * prompt_label.max_lines_visible) + 2.0)
	info_label.max_lines_visible = 5 if landscape else 3
	info_label.custom_minimum_size = Vector2(0, ceilf(font.get_height(15) * info_label.max_lines_visible) + 2.0)


func _relayout() -> void:
	if panel == null:
		return
	var w := size.x
	var h := size.y
	var m := 12.0
	var landscape := w >= h * 1.15
	if not landscape and w >= h * 0.8:
		# near-square: use whichever arrangement gives bigger cards
		var pw0 := clampf(w * 0.3, 280.0, 380.0)
		_compute_layout(Rect2(m, m, w - pw0 - m * 3.0, h - m * 2.0))
		var cw_land: float = lay["cw"]
		_compute_layout(Rect2(m, m, w - m * 2.0, h - m * 3.0 - 300.0))
		landscape = cw_land > float(lay["cw"]) * 1.1
	var pw := clampf(w * 0.3, 280.0, 380.0)
	var mode := (2 if pw < 310.0 else 1) if landscape else 0
	if mode != _landscape:
		_landscape = mode
		_arrange_buttons(landscape, mode == 2)
	if landscape:
		panel.position = Vector2(w - pw - m, m)
		panel.size = Vector2(pw, h - m * 2.0)
		var r := Rect2(m, m, w - pw - m * 3.0, h - m * 2.0)
		var used := _compute_layout(r)
		r.position.y += maxf(0.0, (r.size.y - used) * 0.5)
		_compute_layout(r)
		mat = r
	else:
		var pmin := panel.get_combined_minimum_size().y
		var r2 := Rect2(m, m, w - m * 2.0, maxf(200.0, h - m * 3.0 - pmin))
		var used2 := _compute_layout(r2)
		r2.size.y = used2
		mat = r2
		panel.position = Vector2(m, mat.end.y + m)
		panel.size = Vector2(w - m * 2.0, maxf(pmin, h - mat.end.y - m * 2.0))
	queue_redraw()


var _relayout_queued := false


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


## Lays out the play mat inside R and returns the height it needs. Two shapes:
## "side" puts Yugi's portrait left of his zones, "stacked" gives it a row of
## its own on top (tall phone screens). Whichever allows bigger cards wins.
func _compute_layout(R: Rect2) -> float:
	var band := 30.0
	var mid := 34.0
	var cw_side := minf(R.size.x / 5.35, (R.size.y - 2.0 * band - mid - 8.0) / (3.14 * 1.4))
	var cw_stack := minf(R.size.x / 3.92, (R.size.y - band - mid - 8.0) / (4.04 * 1.4))
	var stacked := cw_stack > cw_side * 1.06
	var cw := clampf(cw_stack if stacked else cw_side, 34.0, 160.0)
	var ch := cw * 1.4
	var g := maxf(6.0, cw * 0.1)
	var dw := cw * 0.62
	var dh := dw * 1.4
	var lift := ch * 0.14
	var zones_w := 3.0 * cw + 2.0 * g
	var L := {"cw": cw, "ch": ch, "g": g, "dw": dw, "dh": dh, "lift": lift, "stacked": stacked, "band": band}
	var y := R.position.y
	var x0: float
	var zx: float
	var total: float
	if not stacked:
		var pw := ch * 0.95
		total = pw + g + zones_w + g + dw
		x0 = R.position.x + (R.size.x - total) * 0.5
		zx = x0 + pw + g
		L["portrait"] = Rect2(x0, y, pw, band + ch)
		L["ylp"] = Rect2(zx, y + 3.0, zones_w + g + dw, band - 8.0)
		L["yhand"] = Rect2(x0, y + band + ch + mid * 0.5, pw, dh * 0.8)
		L["bubble"] = Rect2(x0 + pw * 0.92, y + band + 2.0, minf(330.0, R.end.x - x0 - pw * 0.92 - 4.0), ch)
		y += band
	else:
		var ph := ch * 0.9
		total = zones_w + g + dw
		x0 = R.position.x + (R.size.x - total) * 0.5
		zx = x0
		var pw2 := ph * 0.82
		L["portrait"] = Rect2(x0, y, pw2, ph)
		L["ylp"] = Rect2(x0 + pw2 + g, y + 3.0, total - pw2 - g, band - 8.0)
		L["yhand"] = Rect2(x0 + pw2 + g, y + ph - dh * 0.8 - 4.0, total - pw2 - g, dh * 0.8)
		L["bubble"] = Rect2(x0 + pw2 + 4.0, y + band, total - pw2 - 4.0, ph - band)
		y += ph
	var yz: Array = []
	for i in 3:
		yz.append(Rect2(zx + i * (cw + g), y, cw, ch))
	L["ydeck"] = Rect2(zx + zones_w + g, y + (ch - dh) * 0.3, dw, dh)
	y += ch
	L["mid"] = Rect2(zx, y, zones_w + g + dw, mid)
	y += mid
	var pz: Array = []
	for i in 3:
		pz.append(Rect2(zx + i * (cw + g), y, cw, ch))
	L["pdeck"] = Rect2(zx + zones_w + g, y + (ch - dh) * 0.3, dw, dh)
	y += ch
	L["plp"] = Rect2(x0, y + 5.0, total, band - 8.0)
	y += band
	L["hand"] = Rect2(R.position.x, y, R.size.x, ch + lift)
	y += ch + lift + 6.0
	L["zones"] = [pz, yz]
	L["mat"] = Rect2(R.position.x, R.position.y, R.size.x, y - R.position.y)
	lay = L
	return y - R.position.y


# --- view model ------------------------------------------------------------------------

func _empty_view() -> void:
	view = {"fields": [[null, null, null], [null, null, null]], "hands": [[], []], "lp": [game.start_lp, game.start_lp],
		"deck": [game.decks[0].size(), game.decks[1].size()], "grave": [0, 0]}


func _sync_view() -> void:
	var fields: Array = [[], []]
	for s in 2:
		for z in CardGame.ZONES:
			var m = game.fields[s][z]
			fields[s].append(null if m == null else (m as Dictionary).duplicate())
	view = {"fields": fields, "hands": [game.hands[0].duplicate(), game.hands[1].duplicate()], "lp": [int(game.lp[0]), int(game.lp[1])],
		"deck": [game.decks[0].size(), game.decks[1].size()], "grave": [game.graves[0].size(), game.graves[1].size()]}
	hidden_hand = [{}, {}]
	if sel_hand >= view["hands"][ME].size():
		sel_hand = -1


func _vfield(side: int, zone: int) -> Dictionary:
	var m = view["fields"][side][zone]
	if m == null:
		return {}
	return m


func _vhand(side: int) -> Array:
	return view["hands"][side]


# --- geometry helpers ----------------------------------------------------------------------

func _zone_rect(side: int, zone: int) -> Rect2:
	var r: Rect2 = lay["zones"][side][zone]
	return Rect2(r.position + zone_off[side][zone], r.size)


func _deck_rect(side: int) -> Rect2:
	return lay["pdeck"] if side == ME else lay["ydeck"]


func _lp_rect(side: int) -> Rect2:
	return lay["plp"] if side == ME else lay["ylp"]


func _hand_rects(side: int) -> Array:
	var n: int = _vhand(side).size()
	var out: Array = []
	if n == 0:
		return out
	if side == ME:
		var area: Rect2 = lay["hand"]
		var cw: float = lay["cw"]
		var ch: float = lay["ch"]
		var lift: float = lay["lift"]
		var step: float = cw + float(lay["g"]) * 0.6
		if n > 1:
			step = minf(step, (area.size.x - cw) / float(n - 1))
		var total := cw + step * (n - 1)
		var x0 := area.position.x + (area.size.x - total) * 0.5
		for i in n:
			var y := area.position.y + lift
			if i == sel_hand:
				y -= lift
			elif i == hover_hand and not busy:
				y -= lift * 0.3
			out.append(Rect2(x0 + i * step, y, cw, ch))
	else:
		var area2: Rect2 = lay["yhand"]
		var bh := area2.size.y
		var bw := bh / CardArt.ASPECT
		var step2 := bw * 0.5
		if n > 1:
			step2 = minf(step2, (area2.size.x - bw) / float(n - 1))
		var total2 := bw + step2 * (n - 1)
		var x2 := area2.position.x + (area2.size.x - total2) * 0.5
		for i in n:
			out.append(Rect2(x2 + i * step2, area2.position.y, bw, bh))
	return out


func _portrait_rect() -> Rect2:
	return lay["portrait"]


# --- intro and turn flow ----------------------------------------------------------------------

func _intro() -> void:
	busy = true
	_refresh_ui()
	game.start()
	view["deck"] = [game.decks[0].size() + game.hands[0].size(), game.decks[1].size() + game.hands[1].size()]
	if for_reals:
		_log("[color=#b07cff][b]The sky goes black. Purple mist pours between the graves.[/b][/color]")
		_log("Yugi's golden puzzle pendant blazes. This is a shadow game for your %s: %d LP each, and the loser goes to the Shadow Realm." % [_wager_name(), game.start_lp])
		_say("This time... it's for real.", "determined", 2.6)
		await _wait(1.4)
		await _play_events()
		if not is_inside_tree():
			return
		_say("The loser goes to the Shadow Realm!", "determined", 3.6)
		busy = false
		_refresh_ui()
		# testing hook: ?screen=cards&reals=1&doom=won (or lost) jumps to the ending
		var doom_test := ShadowRealmScreen._url_param("doom")
		if doom_test == "won" or doom_test == "lost":
			await _wait(1.0)
			game._set_winner(ME if doom_test == "won" else YUGI, "lp")
			game.take_events()
			await _game_over()
		return
	_log("[color=#e0aa4a][b]A spiky-haired kid blocks the graveyard path.[/b][/color]")
	_log("Yugi Moto challenges you to a children's card game. Win, and your %s rises from the grave!" % _wager_name())
	_say("It's time to duel!", "determined", 2.0)
	await _wait(1.0)
	await _play_events()
	if not is_inside_tree():
		return
	_say("Win, and your %s rises from the grave! Lose, and it stays in my collection." % _wager_name(), "smug", 3.6)
	busy = false
	_refresh_ui()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _after_player_action() -> void:
	busy = false
	if game.is_over():
		await _game_over()
		return
	_refresh_ui()


func _do_summon(hi: int, zone: int) -> void:
	if busy or over:
		return
	var id := game.hand_card(ME, hi)
	if not game.summon(ME, hi, zone):
		return
	busy = true
	sel_hand = -1
	sel_zone = -1
	_set_info(CardData.describe(id))
	_refresh_ui()
	await _play_events()
	await _after_player_action()


func _do_cast(hi: int, tside: int, tzone: int) -> void:
	if busy or over:
		return
	if not game.cast(ME, hi, tside, tzone):
		return
	busy = true
	sel_hand = -1
	sel_zone = -1
	_refresh_ui()
	await _play_events()
	await _after_player_action()


func _do_attack(zone: int, target: int) -> void:
	if busy or over:
		return
	if not game.attack(ME, zone, target):
		return
	busy = true
	sel_zone = -1
	sel_hand = -1
	_refresh_ui()
	await _play_events()
	if game.is_over():
		await _after_player_action()
		return
	# keep the attacker selected if it may swing again (Double Move, Beyblade)
	if game.can_attack(ME, zone):
		sel_zone = zone
	await _after_player_action()


func _on_end_turn() -> void:
	if busy or over or game.current != ME:
		return
	busy = true
	yugi_busy = true
	sel_hand = -1
	sel_zone = -1
	_set_info(_info_default)
	_refresh_ui()
	game.end_turn()
	await _play_events()
	if game.is_over():
		await _game_over()
		return
	await _yugi_turn()
	if not is_inside_tree():
		return
	yugi_busy = false
	if game.is_over():
		await _game_over()
		return
	busy = false
	_refresh_ui()


func _yugi_turn() -> void:
	await _wait(0.45)
	var guard := 0
	while is_inside_tree() and not game.is_over() and game.current == YUGI and guard < 30:
		guard += 1
		var act := game.ai_action(YUGI)
		if String(act["type"]) == "end":
			break
		if not game.do_action(YUGI, act):
			break
		await _play_events()
		await _wait(0.3)
	if not is_inside_tree() or game.is_over():
		return
	await _wait(0.25)
	game.end_turn()
	await _play_events()


func _game_over() -> void:
	if over:
		return
	over = true
	busy = true
	sel_hand = -1
	sel_zone = -1
	_refresh_ui()
	var won := game.winner == ME
	var timeout := game.win_reason == "time"
	var piece := _wager_name()
	if for_reals:
		await _reals_ending(won, timeout, false)
		return
	if won:
		_log("[color=#6cc060][b]Yugi is out of Life Points. You win the duel![/b][/color]")
		_say("Impossible... you beat me fair and square!", "shocked", 2.2)
		await _wait(1.8)
		_say("Here, take your %s back. You earned it!" % piece, "happy", 6.0)
	else:
		if timeout:
			var tie := int(view["lp"][ME]) == int(view["lp"][YUGI])
			_log("[color=#e2643a][b]Time is up after %d turns.[/b][/color]" % game.max_turns)
			_say("Time's up! %sThe heart of the cards has spoken!" % ("A tie goes to me! " if tie else ""), "happy", 6.0)
		else:
			_log("[color=#e2643a][b]Your Life Points hit zero. Yugi wins the duel.[/b][/color]")
			_say("Yes! The heart of the cards never lies!", "happy", 6.0)
	await _wait(1.6)
	if not is_inside_tree():
		return
	var m := Modal.new("You win!" if won else "Yugi wins!", 460.0)
	m.sticky = true
	if won:
		m.add_text("Yugi hands back your %s. It climbs out of the graveyard, shaking off the dust." % piece)
		m.add_buttons([["Take back your %s" % piece, func():
			m.close()
			_finish("won")]])
	else:
		var why := "Time ran out and Yugi was ahead%s." % (" (ties go to Yugi)" if int(view["lp"][ME]) == int(view["lp"][YUGI]) else "") if timeout else "Your Life Points ran out."
		m.add_text("%s Your %s stays buried in the graveyard... for now." % [why, piece])
		m.add_buttons([["Leave the graveyard", func():
			m.close()
			_finish("lost")]])
	add_child(m)


## The end of a shadow game: the loser is dragged into the Shadow Realm.
func _reals_ending(won: bool, timeout: bool, forfeit: bool) -> void:
	var piece := _wager_name()
	if won:
		_log("[color=#6cc060][b]Yugi is out of Life Points. You win the shadow game![/b][/color]")
		_say("Impossible... it can't end like this...", "shocked", 2.2)
		await _wait(1.6)
		if not is_inside_tree():
			return
		_log("[color=#b07cff][b]The shadows rise around Yugi and drag him down.[/b][/color]")
		_say("No! The heart of the cards... has abandoned me!", "shocked", 4.5)
		doom = "yugi"
	else:
		if forfeit:
			_log("[color=#e2643a][b]You turn to run. There is no running from a shadow game.[/b][/color]")
			_say("You can't walk away from a shadow game!", "determined", 4.0)
		elif timeout:
			_log("[color=#e2643a][b]Time is up after %d turns, and Yugi is ahead.[/b][/color]" % game.max_turns)
			_say("Time's up! The shadows have made their choice!", "determined", 4.0)
		else:
			_log("[color=#e2643a][b]Your Life Points hit zero.[/b][/color]")
			_say("The shadows have made their choice!", "determined", 4.0)
		await _wait(1.2)
		if not is_inside_tree():
			return
		_log("[color=#b07cff][b]The ground opens beneath you.[/b][/color]")
		doom = "player"
		_doom_layer = Control.new()
		_doom_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_doom_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_doom_layer.draw.connect(func(): _draw_player_doom(_doom_layer))
		add_child(_doom_layer)
	doom_t = 0.0
	shake = 0.6
	await _wait(3.6)
	if not is_inside_tree():
		return
	var m := Modal.new("Yugi is gone!" if won else "Swallowed by the shadows", 460.0)
	m.sticky = true
	if won:
		m.add_text("Yugi has been sent to the Shadow Realm. His cards scatter in the wind, and the graveyard falls silent.")
		m.add_text("Your %s climbs out of the grave. Nobody will ever duel for the dead again." % piece, 17, UI.DIM)
		m.add_buttons([["Take back your %s" % piece, func():
			m.close()
			_finish("won")]])
	else:
		m.add_text("You have lost a shadow game. The darkness closes over you, and the chessboard fades far, far away.")
		m.add_buttons([["Into the Shadow Realm", func():
			m.close()
			_finish("lost")]])
	add_child(m)


func _finish(result: String) -> void:
	if _emitted:
		return
	_emitted = true
	finished.emit(result)


# --- event playback -----------------------------------------------------------------------

func _play_events() -> void:
	var evs := game.take_events()
	for ev in evs:
		if not is_inside_tree():
			return
		await _play_event(ev)
	_sync_view()


func _cname(id: String) -> String:
	return CardData.card_name(id)


func _who(side: int) -> String:
	return "Your" if side == ME else "Yugi's"


func _play_event(ev: Dictionary) -> void:
	var s: int = int(ev.get("side", 0))
	match String(ev["t"]):
		"turn":
			var mine := s == ME
			banner = "YOUR TURN" if mine else "YUGI'S TURN"
			banner_time = 1.3
			_log("[color=#8f877a]-- Turn %d of %d: %s --[/color]" % [int(ev["turn"]), game.max_turns, "you" if mine else "Yugi"])
			if bool(ev.get("locked", false)):
				_log("[color=#7fa6ff]Swords of light pin %s monsters: no attacks this turn.[/color]" % ("your" if mine else "Yugi's"))
			elif not mine and int(ev["turn"]) > 2 and randf() < 0.3:
				var taunts: Array = ["The shadows are hungry!", "My turn! I draw... from the darkness!", "Can you feel the Shadow Realm calling?"] if for_reals else ["My turn! I draw!", "Here I come!", "Don't count me out yet!"]
				_say(String(taunts[randi() % 3]), "determined", 1.6)
			await _wait(0.3 if int(ev["turn"]) > 1 else 0.05)
		"draw":
			await _anim_draw(ev)
		"nodraw":
			_log("%s deck is empty, so no card is drawn." % _who(s))
		"recycle":
			view["deck"][s] = int(view["deck"][s]) + int(ev["count"])
			view["grave"][s] = 0
			_rise(_deck_rect(s).get_center(), ShadowArt.PURPLE, 24)
			_log("[color=#b07cff]The shadows push %d fallen cards back into %s deck.[/color]" % [int(ev["count"]), "your" if s == ME else "Yugi's"])
			await _wait(0.5)
		"summon":
			await _anim_summon(ev)
		"spell":
			await _anim_spell(ev)
		"promote":
			var pm := _vfield(s, int(ev["zone"]))
			if not pm.is_empty():
				pm["id"] = "queen"
				pm["atk"] = CardData.atk("queen")
			var pc := _zone_rect(s, int(ev["zone"])).get_center()
			zone_flash[s][int(ev["zone"])] = 1.0
			_rise(pc, UI.GOLD, 30)
			_log("The Pawn is promoted to a [b]Queen[/b] (2500 ATK)!")
			_say("A Queen?! From a Pawn?! That's not even fair!", "shocked", 2.4)
			await _wait(0.6)
		"destroy":
			await _anim_destroy(ev)
		"damage":
			await _anim_damage(ev)
		"heal":
			view["lp"][s] = int(ev["lp"])
			_float("+%d" % int(ev["amount"]), _lp_rect(s).get_center(), UI.GREEN)
			_rise(_lp_rect(s).get_center(), UI.GREEN, 18)
			_log("%s %d LP." % ["You gain" if s == ME else "Yugi gains", int(ev["amount"])])
			await _wait(0.4)
		"swords":
			swords_fx[s] = 2.0
			_log("[color=#7fa6ff]Swords of light fall around %s monsters: no attacks next turn![/color]" % ("your" if s == ME else "Yugi's"))
			await _wait(0.8)
		"rerun":
			_vhand(s).append(String(ev["id"]))
			var idx := _vhand(s).size() - 1
			hidden_hand[s][idx] = true
			await _fly(String(ev["id"]), _deck_rect(s), _hand_rects(s)[idx], 0.35, s == ME, false)
			hidden_hand[s].erase(idx)
			_log("%s %s returns from the graveyard to the hand." % [_who(s), _cname(String(ev["id"]))])
		"double":
			var dz := int(ev["zone"])
			zone_flash[s][dz] = 1.0
			_float("x2", _zone_rect(s, dz).get_center(), UI.GOLD)
			_log("%s %s may attack one more time this turn." % [_who(s), _cname(String(_vfield(s, dz).get("id", "")))])
			await _wait(0.4)
		"steal":
			var from := int(ev["from"])
			var to := int(ev["zone"])
			var sm := _vfield(1 - s, from)
			view["fields"][1 - s][from] = null
			await _fly(String(ev["id"]), _zone_rect(1 - s, from), _zone_rect(s, to), 0.4, true, false)
			view["fields"][s][to] = sm
			zone_flash[s][to] = 1.0
			_log("Pink slip! %s now races for %s." % [_cname(String(ev["id"])), "you" if s == ME else "Yugi"])
			if s == ME:
				_say("Hey! Give that back!", "shocked", 2.0)
			await _wait(0.3)
		"discard":
			var di := int(ev["hand"])
			var rects := _hand_rects(s)
			var dr: Rect2 = rects[di] if di < rects.size() else _deck_rect(s)
			if di < _vhand(s).size():
				_vhand(s).remove_at(di)
			ghosts.append({"id": String(ev["id"]), "rect": dr, "t": 0.0, "hold": 0.4, "dur": 0.4, "face": true})
			_log("%s discards %s." % ["You" if s == ME else "Yugi", _cname(String(ev["id"]))])
			if s == YUGI:
				_say("My %s! Every move is a bad move..." % _cname(String(ev["id"])), "shocked", 2.2)
			await _wait(0.6)
		"heart":
			heart_glow = 2.5
			_say("I believe in the heart of the cards!", "determined", 3.0)
			_log("[color=#e0aa4a][b]Yugi believes in the heart of the cards![/b] His next draw will be the best monster left in his deck.[/color]")
			await _wait(1.2)
		"attack":
			await _anim_attack(ev)


func _anim_draw(ev: Dictionary) -> void:
	var s := int(ev["side"])
	var id := String(ev["id"])
	var fast := bool(ev.get("opening", false))
	view["deck"][s] = maxi(0, int(view["deck"][s]) - 1)
	_vhand(s).append(id)
	var idx := _vhand(s).size() - 1
	hidden_hand[s][idx] = true
	if bool(ev.get("heart", false)):
		heart_glow = 2.0
		_say("Heart of the cards... guide my draw!", "determined", 2.2)
		_log("[color=#e0aa4a]The heart of the cards answers Yugi.[/color]")
		await _wait(0.6)
	await _fly(id, _deck_rect(s), _hand_rects(s)[idx], 0.12 if fast else 0.3, s == ME, false)
	hidden_hand[s].erase(idx)
	if s == ME and not fast:
		_log("You draw %s." % _cname(id))


func _anim_summon(ev: Dictionary) -> void:
	var s := int(ev["side"])
	var z := int(ev["zone"])
	var id := String(ev["id"])
	var hi := int(ev["hand"])
	var rects := _hand_rects(s)
	var from: Rect2 = rects[hi] if hi < rects.size() else _deck_rect(s)
	if hi < _vhand(s).size():
		_vhand(s).remove_at(hi)
	if s == YUGI:
		_yugi_summon_line(id)
	await _fly(id, from, lay["zones"][s][z], 0.32, true, s == YUGI)
	view["fields"][s][z] = {"id": id, "base": id, "atk": CardData.atk(id), "owner": s}
	zone_flash[s][z] = 1.0
	_burst(_zone_rect(s, z).get_center(), UI.GOLD if s == ME else Color(0.8, 0.5, 1.0), 16, 160.0)
	_log("%s %s %s (%d ATK)." % ["You" if s == ME else "Yugi", "summon" if s == ME else "summons", _cname(id), CardData.atk(id)])
	if s == ME:
		match id:
			"queen":
				_say("Your Queen?! Okay... okay. Stay calm, Yugi.", "shocked", 2.2)
			"elongated_dragon":
				_say("That neck... it just keeps going!", "shocked", 2.2)
			"beyblade":
				_say("Let it rip? That's a completely different show!", "shocked", 2.4)
			"king":
				_say("You put your King in danger? Bold!", "smug", 2.0)
	await _wait(0.2)


func _yugi_summon_line(id: String) -> void:
	match id:
		"sorcerer":
			_say("Behold! My Spiky-Haired Sorcerer!", "determined", 2.4)
		"fuzzball":
			_say("Go, Fuzzball! Believe in yourself!", "happy", 2.0)
		"skull":
			_say("I summon the Rented Skull Demon! ...He charges by the hour.", "smug", 2.6)
		_:
			var lines := ["I summon %s!", "Come forth, %s!", "I play %s in attack mode! ...It's the only mode."]
			_say(lines[randi() % lines.size()] % _cname(id), "smug", 2.0)


func _anim_spell(ev: Dictionary) -> void:
	var s := int(ev["side"])
	var id := String(ev["id"])
	var hi := int(ev["hand"])
	var rects := _hand_rects(s)
	var from: Rect2 = rects[hi] if hi < rects.size() else _deck_rect(s)
	if hi < _vhand(s).size():
		_vhand(s).remove_at(hi)
	var cw: float = float(lay["cw"]) * 1.25
	var mid: Rect2 = lay["mid"]
	var big := Rect2(Vector2(mid.position.x + mid.size.x * 0.5 - cw * 0.5, mid.get_center().y - cw * 0.7), Vector2(cw, cw * 1.4))
	if s == YUGI:
		_yugi_spell_line(id)
	else:
		_player_spell_line(id)
	await _fly(id, from, big, 0.3, true, s == YUGI)
	ghosts.append({"id": id, "rect": big, "t": 0.0, "hold": 0.55, "dur": 0.35, "face": true, "glow": true})
	_log("%s %s [b]%s[/b]: %s" % ["You" if s == ME else "Yugi", "cast" if s == ME else "casts", _cname(id), CardData.card_text(id)])
	await _wait(0.6)
	view["grave"][s] = int(view["grave"][s]) + 1
	var tz := int(ev.get("tzone", -1))
	var ts := int(ev.get("tside", -1))
	if tz >= 0 and ts >= 0:
		_burst(_zone_rect(ts, tz).get_center(), Color(0.6, 1.0, 0.9), 22, 200.0)


func _yugi_spell_line(id: String) -> void:
	match id:
		"pot_generosity":
			_say("Pot of Generosity! I draw two cards!", "happy", 2.2)
		"swords_shine":
			_say("Swords of Revealing Shine! Your army can't attack next turn!", "determined", 2.6)
		"monster_rerun":
			_say("Monster Re-run! My best monster comes back for an encore!", "smug", 2.4)
		_:
			_say("I activate %s!" % _cname(id), "smug", 2.0)


func _player_spell_line(id: String) -> void:
	match id:
		"checkmate":
			_say("Checkmate?! This is a CARD game!", "shocked", 2.2)
		"en_passant":
			_say("En passant? Is that even a real rule?", "shocked", 2.2)
		"fifty_move":
			_say("Fifty moves? We only just started!", "smug", 2.0)
		"driveby":
			_say("That is NOT in the rulebook!", "shocked", 2.0)
		"sniper":
			_say("Where did that come from?!", "shocked", 2.0)
		"zugzwang":
			_say("Zug-what now?", "shocked", 1.8)
		"double_move":
			_say("Twice?! Is that legal?", "shocked", 1.8)


func _anim_destroy(ev: Dictionary) -> void:
	var s := int(ev["side"])
	var z := int(ev["zone"])
	var m := _vfield(s, z)
	var id := String(m.get("id", ev["id"]))
	var r: Rect2 = lay["zones"][s][z]
	view["fields"][s][z] = null
	zone_off[s][z] = Vector2.ZERO
	ghosts.append({"id": id, "atk": int(m.get("atk", CardData.atk(id))), "rect": r, "t": 0.0, "hold": 0.08, "dur": 0.5, "face": true, "red": true, "side": s})
	_burst(r.get_center(), UI.EMBER, 30, 240.0)
	_burst(r.get_center(), Color(0.55, 0.52, 0.5), 20, 120.0)
	view["grave"][s] = int(view["grave"][s]) + 1
	_log("%s %s is destroyed." % [_who(s), _cname(id)])
	if s == YUGI and game.current == ME:
		_say("No! My %s!" % _cname(id), "shocked", 2.0)
	elif s == ME and game.current == YUGI:
		_say("Your %s was no match for me!" % _cname(id), "smug", 2.0)
	await _wait(0.35)


func _anim_damage(ev: Dictionary) -> void:
	var s := int(ev["side"])
	var amt := int(ev["amount"])
	view["lp"][s] = int(ev["lp"])
	var at := _lp_rect(s).get_center()
	_float("-%d" % amt, at + Vector2(0, -18), Color(1, 0.4, 0.3) if s == ME else Color(1, 0.9, 0.4))
	shake = 0.55 if amt >= 1000 else 0.3
	if s == YUGI:
		portrait_flash = 1.0
		_burst(_portrait_rect().get_center(), Color(1, 0.5, 0.3), 14, 160.0)
		_log("Yugi takes [color=#e0aa4a]%d[/color] damage (%d LP left)." % [amt, int(ev["lp"])])
		if int(ev["lp"]) > 0 and bubble_time <= 0.3:
			if amt >= 1000:
				_say(["Aaargh!", "Ow, ow, ow!", "That one hurt!"][randi() % 3], "shocked", 1.6)
			else:
				_say("Just a scratch!", "smug", 1.4)
	else:
		_log("You take [color=#e2643a]%d[/color] damage (%d LP left)." % [amt, int(ev["lp"])])
		if int(ev["lp"]) > 0 and bubble_time <= 0.3 and amt >= 800:
			_say(["Direct hit!", "Ha! Feel the heart of the cards!", "How do you like that?"][randi() % 3], "happy", 1.6)
	await _wait(0.4)


func _anim_attack(ev: Dictionary) -> void:
	var s := int(ev["side"])
	var z := int(ev["zone"])
	var target := int(ev["target"])
	var am := _vfield(s, z)
	var aname := _cname(String(am.get("id", "")))
	var from: Vector2 = (lay["zones"][s][z] as Rect2).get_center()
	var to: Vector2
	if target >= 0:
		to = (lay["zones"][1 - s][target] as Rect2).get_center()
		var dm := _vfield(1 - s, target)
		_log("%s %s (%d) attacks %s (%d)!" % [_who(s), aname, int(ev["atk"]), _cname(String(dm.get("id", ""))), int(ev["def"])])
	else:
		to = _portrait_rect().get_center() if s == ME else _lp_rect(ME).get_center()
		_log("%s %s attacks %s directly for %d!" % [_who(s), aname, "Yugi" if s == ME else "you", int(ev["atk"])])
	var vec := (to - from) * 0.72
	var tw := create_tween()
	tw.tween_method(func(v: Vector2): zone_off[s][z] = v, Vector2.ZERO, Vector2(0, 14 if s == ME else -14), 0.1)
	tw.tween_method(func(v: Vector2): zone_off[s][z] = v, Vector2(0, 14 if s == ME else -14), vec, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_burst(from + vec, Color(1, 0.9, 0.6), 24, 260.0)
	shake = maxf(shake, 0.35)
	if target >= 0:
		zone_flash[1 - s][target] = 1.0
	var tw2 := create_tween()
	tw2.tween_method(func(v: Vector2): zone_off[s][z] = v, vec, Vector2.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw2.finished


# --- effects helpers ------------------------------------------------------------------------

func _fly(id: String, from: Rect2, to: Rect2, dur: float, face: bool, flip: bool) -> void:
	var f := {"id": id, "from": from, "to": to, "t": 0.0, "dur": dur, "face": face, "flip": flip}
	flyers.append(f)
	await _wait(dur)
	flyers.erase(f)


func _float(text: String, at: Vector2, color: Color) -> void:
	floaters.append({"text": text, "p": at, "c": color, "t": 0.0})


func _burst(at: Vector2, color: Color, n: int = 20, speed: float = 220.0) -> void:
	for i in n:
		var a := randf() * TAU
		sparks.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed), "c": color,
			"t": 0.0, "life": randf_range(0.35, 0.8), "r": randf_range(2.0, 4.5), "grav": 1.0})


func _rise(at: Vector2, color: Color, n: int = 20) -> void:
	for i in n:
		sparks.append({"p": at + Vector2(randf_range(-30, 30), randf_range(-10, 30)), "v": Vector2(randf_range(-15, 15), randf_range(-90, -40)),
			"c": color, "t": 0.0, "life": randf_range(0.6, 1.2), "r": randf_range(2.0, 4.0), "grav": -0.1})


func _say(text: String, expr: String, dur: float = 2.2) -> void:
	bubble_text = text
	bubble_time = dur
	bubble_age = 0.0
	yugi_expr = expr


func _log(text: String) -> void:
	if log_box:
		log_box.append_text(text + "\n")


func _set_info(text: String) -> void:
	if info_label:
		info_label.text = text


func _process(delta: float) -> void:
	t += delta
	if view.is_empty():
		return
	for s in 2:
		var target := float(view["lp"][s])
		disp_lp[s] = move_toward(disp_lp[s], target, delta * maxf(1500.0, absf(disp_lp[s] - target) * 3.0))
		for z in 3:
			zone_flash[s][z] = maxf(0.0, zone_flash[s][z] - delta * 2.5)
		swords_fx[s] = maxf(0.0, swords_fx[s] - delta)
	bubble_age += delta
	if bubble_time > 0.0:
		bubble_time -= delta
		if bubble_time <= 0.0 and not over:
			yugi_expr = "determined" if for_reals or int(view["lp"][YUGI]) < game.heart_lp else "smug"
	shake = maxf(0.0, shake - delta * 2.2)
	if doom != "":
		doom_t += delta
		if _doom_layer:
			_doom_layer.queue_redraw()
	portrait_flash = maxf(0.0, portrait_flash - delta * 2.5)
	heart_glow = maxf(0.0, heart_glow - delta)
	banner_time = maxf(0.0, banner_time - delta)
	for f in flyers:
		f["t"] = float(f["t"]) + delta
	for g in ghosts:
		g["t"] = float(g["t"]) + delta
	ghosts = ghosts.filter(func(g): return float(g["t"]) < float(g["hold"]) + float(g["dur"]))
	for fl in floaters:
		fl["t"] = float(fl["t"]) + delta
		fl["p"] = (fl["p"] as Vector2) + Vector2(0, -34.0) * delta
	floaters = floaters.filter(func(fl): return float(fl["t"]) < 1.3)
	for sp in sparks:
		sp["t"] = float(sp["t"]) + delta
		sp["v"] = (sp["v"] as Vector2) + Vector2(0, 160.0) * delta * float(sp["grav"])
		sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * delta
	sparks = sparks.filter(func(sp): return float(sp["t"]) < float(sp["life"]))
	queue_redraw()


# --- input ---------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit(event.position)
		var hh := int(h["index"]) if String(h["kind"]) == "hand" else -1
		if hh != hover_hand:
			hover_hand = hh
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_tap(event.position)


func _hit(p: Vector2) -> Dictionary:
	if lay.is_empty():
		return {"kind": "none", "index": -1}
	var rects := _hand_rects(ME)
	if sel_hand >= 0 and sel_hand < rects.size() and (rects[sel_hand] as Rect2).has_point(p):
		return {"kind": "hand", "index": sel_hand}
	for i in range(rects.size() - 1, -1, -1):
		if (rects[i] as Rect2).has_point(p):
			return {"kind": "hand", "index": i}
	for s in 2:
		for z in 3:
			if (lay["zones"][s][z] as Rect2).grow(4.0).has_point(p):
				return {"kind": "zone", "side": s, "index": z}
	if _portrait_rect().has_point(p):
		return {"kind": "yugi", "index": -1}
	if _deck_rect(ME).grow(6.0).has_point(p):
		return {"kind": "deck", "side": ME, "index": -1}
	if _deck_rect(YUGI).grow(6.0).has_point(p):
		return {"kind": "deck", "side": YUGI, "index": -1}
	if (lay["yhand"] as Rect2).grow(6.0).has_point(p):
		return {"kind": "yhand", "index": -1}
	return {"kind": "none", "index": -1}


func _tap(p: Vector2) -> void:
	if bubble_time > 0.4 and bubble_age > 0.6:
		bubble_time = 0.4 # a tap hurries Yugi along
	if over:
		return
	var h := _hit(p)
	var kind := String(h["kind"])
	var my_turn := not busy and game.current == ME
	match kind:
		"hand":
			var hi := int(h["index"])
			if my_turn:
				_tap_hand(hi)
			else:
				_set_info(CardData.describe(String(_vhand(ME)[hi])))
		"zone":
			var s := int(h["side"])
			var z := int(h["index"])
			if my_turn:
				_tap_zone(s, z)
			else:
				_inspect_zone(s, z)
		"yugi":
			if my_turn and sel_zone >= 0 and game.can_attack_target(ME, sel_zone, -1):
				_do_attack(sel_zone, -1)
				return
			_set_info("Yugi Moto: %d LP, %d cards in hand, %d in his deck. He believes in the heart of the cards." % [
				int(view["lp"][YUGI]), _vhand(YUGI).size(), int(view["deck"][YUGI])])
		"deck":
			var ds := int(h["side"])
			_set_info("%s deck: %d cards left. Graveyard: %d cards." % ["Your" if ds == ME else "Yugi's", int(view["deck"][ds]), int(view["grave"][ds])])
		"yhand":
			_set_info("Yugi is holding %d cards. No peeking." % _vhand(YUGI).size())
		_:
			if my_turn and (sel_hand >= 0 or sel_zone >= 0):
				sel_hand = -1
				sel_zone = -1
				_set_info(_info_default)
	_refresh_ui()


func _tap_hand(hi: int) -> void:
	var id := String(_vhand(ME)[hi])
	if sel_hand == hi:
		# second tap plays the card
		if CardData.is_monster(id):
			if game.can_summon(ME, hi):
				_do_summon(hi, game.free_zone(ME))
		elif game.castable(ME, hi):
			_cast_selected()
		return
	sel_hand = hi
	sel_zone = -1
	_set_info(CardData.describe(id))


func _tap_zone(s: int, z: int) -> void:
	var m := _vfield(s, z)
	if sel_hand >= 0:
		var id := String(_vhand(ME)[sel_hand])
		if CardData.is_monster(id) and s == ME and m.is_empty() and game.can_summon(ME, sel_hand, z):
			_do_summon(sel_hand, z)
			return
		if CardData.is_spell(id) and game.spell_needs_target(id) and game.can_cast(ME, sel_hand, s, z):
			_do_cast(sel_hand, s, z)
			return
	if s == ME:
		if m.is_empty():
			sel_hand = -1
			sel_zone = -1
			_set_info(_info_default)
			return
		if sel_zone == z:
			sel_zone = -1
		else:
			sel_zone = z
			sel_hand = -1
		_inspect_zone(s, z)
	else:
		if not m.is_empty() and sel_zone >= 0 and game.can_attack_target(ME, sel_zone, z):
			_do_attack(sel_zone, z)
			return
		if m.is_empty() and sel_zone >= 0 and game.can_attack_target(ME, sel_zone, -1):
			# Yugi's side is empty: any tap on it goes straight for him
			_do_attack(sel_zone, -1)
			return
		_inspect_zone(s, z)


func _inspect_zone(s: int, z: int) -> void:
	var m := _vfield(s, z)
	if m.is_empty():
		_set_info("An empty zone on %s side." % ("your" if s == ME else "Yugi's"))
		return
	var id := String(m["id"])
	var extra := ""
	if String(m.get("base", id)) != id:
		extra = " (promoted from a %s)" % _cname(String(m["base"]))
	_set_info(CardData.describe(id) + extra)


func _cast_selected() -> void:
	if sel_hand < 0:
		return
	var id := String(_vhand(ME)[sel_hand])
	if not game.castable(ME, sel_hand):
		return
	if not game.spell_needs_target(id):
		_do_cast(sel_hand, -1, -1)
		return
	var targets := game.spell_targets(ME, id)
	if targets.size() == 1:
		_do_cast(sel_hand, int(targets[0]["side"]), int(targets[0]["zone"]))


func _on_cast() -> void:
	if busy or over or game.current != ME:
		return
	_cast_selected()
	_refresh_ui()


func _direct_attacker() -> int:
	if busy or over or game.current != ME:
		return -1
	if sel_zone >= 0 and game.can_attack_target(ME, sel_zone, -1):
		return sel_zone
	var best := -1
	for z in 3:
		if game.can_attack_target(ME, z, -1) and (best < 0 or int(game.monster(ME, z)["atk"]) > int(game.monster(ME, best)["atk"])):
			best = z
	return best


func _on_direct() -> void:
	var z := _direct_attacker()
	if z >= 0:
		_do_attack(z, -1)


func _show_rules() -> void:
	var m := Modal.new("The Rules", 560.0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, clampf(size.y - 190.0, 180.0, 440.0))
	var stakes := ""
	if for_reals:
		stakes = """THIS TIME IT'S FOR REAL. This is a shadow game.
- You both start with %d LP, and Yugi plays at his very best.
- When a deck runs dry, the shadows shuffle its graveyard back in.
- Win and your %s rises, and Yugi is dragged into the Shadow Realm forever. Nobody will duel for the dead again.
- Lose, run out of time, or forfeit, and YOU are sent to the Shadow Realm. That is game over.

""" % [game.start_lp, _wager_name()]
	var l := UI.label(stakes + """It's a children's card game. Probably.

- You both start with %d LP and a 20-card deck (plus any booster cards you bought). You open with 4 cards and draw 1 at the start of each turn. You go first and skip that first draw.
- Each turn you may summon one monster into one of your 3 zones and cast one spell. Then each of your monsters may attack once, even on the turn it arrives. Nobody may attack on the very first turn of the duel.
- Battle: the higher ATK destroys the lower, and the difference is taken from the loser's LP. Equal ATK: both are destroyed. If Yugi has no monsters, you may attack him directly for full ATK.
- Reduce Yugi to 0 LP to win. After %d turns the higher LP wins, and ties go to Yugi.
- Beware: once per duel, when Yugi drops below %d LP, he believes in the heart of the cards.

How to play: tap a card in your hand to read it, then tap it again (or an empty zone of yours) to play it. Spells with a target: tap the target. To attack, tap one of your monsters, then an enemy monster, or Yugi himself when his side is empty.""" % [game.start_lp, game.max_turns, game.heart_lp], 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	m.add(sc)
	m.add_buttons([["Got it", m.close]])
	add_child(m)


func _on_forfeit() -> void:
	if over:
		return
	var m := Modal.new("Forfeit?", 440.0)
	if for_reals:
		m.add_text("This is a shadow game. Forfeiting counts as a loss: you will be sent to the Shadow Realm, and that is game over.", UI.FONT_SIZE, UI.EMBER)
		m.add_buttons([["Forfeit anyway", func():
			m.close()
			_forfeit_reals()], ["Keep dueling", m.close]])
		add_child(m)
		return
	m.add_text("Walk away from the duel? Yugi wins, and your %s stays in the graveyard." % _wager_name())
	m.add_buttons([["Forfeit", func():
		m.close()
		over = true
		_finish("lost")], ["Keep dueling", m.close]])
	add_child(m)


func _forfeit_reals() -> void:
	if over:
		return
	over = true
	busy = true
	sel_hand = -1
	sel_zone = -1
	_refresh_ui()
	await _reals_ending(false, false, true)


# --- prompt and buttons ---------------------------------------------------------------------------

func _refresh_ui() -> void:
	if panel == null:
		return
	var my_turn := not busy and not over and game.current == ME
	btn_end.disabled = not my_turn
	btn_forfeit.disabled = over or busy
	var sel_id := String(_vhand(ME)[sel_hand]) if sel_hand >= 0 and sel_hand < _vhand(ME).size() else ""
	btn_cast.disabled = not (my_turn and sel_id != "" and CardData.is_spell(sel_id) and game.castable(ME, sel_hand))
	btn_direct.disabled = _direct_attacker() < 0
	var idle := my_turn and not _has_moves()
	btn_end.add_theme_color_override("font_color", UI.GOLD if idle else UI.TEXT)
	prompt_label.text = _prompt_text()


func _has_moves() -> bool:
	for i in _vhand(ME).size():
		if game.can_summon(ME, i) or (CardData.is_spell(String(_vhand(ME)[i])) and game.castable(ME, i)):
			return true
	for z in 3:
		if game.can_attack(ME, z) and not game.attack_targets(ME, z).is_empty():
			# only count attacks that don't lose
			var a := int(game.monster(ME, z)["atk"])
			for tz in game.attack_targets(ME, z):
				if int(tz) < 0 or int(game.monster(YUGI, int(tz))["atk"]) <= a:
					return true
	return false


func _prompt_text() -> String:
	if over:
		return "The duel is over."
	if busy:
		return "Yugi's turn... (tap any card to read it)" if yugi_busy else "..."
	if game.current != ME:
		return "Yugi's turn..."
	if sel_hand >= 0 and sel_hand < _vhand(ME).size():
		var id := String(_vhand(ME)[sel_hand])
		var nm := _cname(id)
		if CardData.is_monster(id):
			if game.can_summon(ME, sel_hand):
				return "Tap an empty zone of yours (or the card again) to summon %s." % nm
			if game.summoned:
				return "You already summoned a monster this turn."
			return "Your zones are full."
		var why := game.why_not_cast(ME, sel_hand)
		if why != "":
			return why
		if game.spell_needs_target(id):
			match CardData.target_mode(id):
				"own_pawn":
					return "Tap one of your Pawns to promote it."
				"own_monster":
					return "Tap one of your monsters to give it an extra attack."
				"enemy_low":
					return "Tap an enemy monster with 1000 ATK or less."
				"enemy_steal":
					return "Tap an enemy monster with 1600 ATK or less to take it."
			return "Tap a target."
		return "Tap Cast (or the card again) to cast %s." % nm
	if sel_zone >= 0:
		var m := game.monster(ME, sel_zone)
		if m.is_empty():
			return "Tap a card."
		var nm2 := _cname(String(m["id"]))
		if game.turn == 1:
			return "Nobody may attack on the first turn of the duel."
		if game.attacks_locked:
			return "Swords of light: your monsters can't attack this turn."
		if not game.can_attack(ME, sel_zone):
			return "Your %s has already attacked this turn." % nm2
		if game.monster_count(YUGI) == 0:
			return "Yugi is wide open! Tap him (or Attack Directly) to hit him for %d." % int(m["atk"])
		return "Tap an enemy monster for your %s (%d) to attack." % [nm2, int(m["atk"])]
	if game.turn == 1:
		return "Your first turn: tap a monster in your hand to summon it. (No attacks on the first turn.)"
	var opts: Array = []
	var can_sum := false
	var can_spell := false
	for i in _vhand(ME).size():
		if game.can_summon(ME, i):
			can_sum = true
		if CardData.is_spell(String(_vhand(ME)[i])) and game.castable(ME, i):
			can_spell = true
	if can_sum:
		opts.append("summon a monster")
	if can_spell:
		opts.append("cast a spell")
	var can_atk := false
	for z in 3:
		if game.can_attack(ME, z):
			can_atk = true
	if can_atk:
		opts.append("attack (tap your monster)")
	if opts.is_empty():
		return "Nothing left to do: tap End Turn."
	return "Your turn: %s, or End Turn." % ", ".join(opts)


# --- drawing --------------------------------------------------------------------------------------

func _card_opts(_side: int, m: Dictionary = {}) -> Dictionary:
	var o := {"white": player_white, "t": t}
	if not m.is_empty():
		o["atk"] = int(m.get("atk", 0))
	return o


func _draw_card_xf(r: Rect2, id: String, face: bool, rot: float, sc: Vector2, opts: Dictionary = {}) -> void:
	var c := r.get_center()
	draw_set_transform(c, rot, sc)
	var local := Rect2(-r.size * 0.5, r.size)
	if face:
		CardArt.draw_card(self, local, id, opts)
	else:
		CardArt.draw_back(self, local, t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _outline(r: Rect2, col: Color, w: float = 3.0) -> void:
	CardArt.line_rrect(self, r.grow(3.0), float(lay["cw"]) * 0.07, col, w)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	if for_reals:
		_draw_shadow_arena()
	if lay.is_empty() or view.is_empty():
		return
	var shk := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 7.0
	_shk = shk
	if shk != Vector2.ZERO:
		draw_set_transform(shk, 0.0, Vector2.ONE)
	_draw_mat()
	_draw_portrait()
	_draw_lp(ME)
	_draw_lp(YUGI)
	_draw_decks()
	_draw_yugi_hand()
	_draw_mid()
	_draw_fields()
	_draw_swords()
	_draw_hand()
	_draw_ghosts()
	_draw_flyers()
	if shk != Vector2.ZERO:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_sparks()
	_draw_bubble()


## The shadow game's arena: a purple-black void, a slow vortex behind the
## table and mist creeping along the floor.
func _draw_shadow_arena() -> void:
	var s := size
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color(0.1, 0.03, 0.14), Color(0.08, 0.02, 0.12), Color(0.02, 0.01, 0.03), Color(0.03, 0.01, 0.04)]))
	var c := mat.get_center() if mat.has_area() else s * 0.5
	ShadowArt.vortex(self, c, s.length() * 0.55, t * 0.25, 0.45, 0.25, 7)
	for i in 26:
		var p := Vector2(fmod(i * 173.3 + t * (4.0 + i % 5), s.x), fposmod(i * 91.7 - t * (6.0 + i % 3) * 2.0, s.y))
		draw_circle(p, 1.5 + (i % 3), Color(ShadowArt.GREEN if i % 4 == 0 else ShadowArt.PURPLE, 0.25 + 0.2 * sin(t * 2.0 + i)))
	ShadowArt.mist(self, Rect2(Vector2.ZERO, s), t, Color(0.55, 0.35, 0.75, 0.05), 10, 0.7, 1.0)
	ShadowArt.mist(self, Rect2(Vector2.ZERO, s), t * 0.7, Color(0.35, 0.75, 0.5, 0.03), 6, 0.0, 0.25)


## The loser of a shadow game is swallowed: the screen goes dark and a
## vortex opens under the player's side of the table.
func _draw_player_doom(ci: CanvasItem) -> void:
	var k := clampf(doom_t / 3.2, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var hand: Rect2 = lay["hand"]
	var c := Vector2(mat.get_center().x, hand.get_center().y - hand.size.y * 0.2)
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(ShadowArt.VOID, 0.82 * e))
	var big := size.length()
	ShadowArt.vortex(ci, c, big * (0.08 + 0.5 * e), t * 1.6, minf(1.0, k * 3.0), 0.8, 7)
	for i in 8:
		var a := TAU * i / 8.0 + 0.3
		var from := c + Vector2.from_angle(a) * big * 0.7
		ShadowArt.tendril(ci, from, c + Vector2.from_angle(a + 0.6) * big * 0.05, t, big * 0.02, Color(0.06, 0.02, 0.09, 0.9), clampf(k * 1.6 - i * 0.05, 0.0, 1.0), i * 1.7)
	# the player's silhouette, pulled spinning into the eye
	var sk := clampf((doom_t - 0.6) / 2.4, 0.0, 1.0)
	var orbit := Vector2.from_angle(-PI * 0.5 + sk * 9.0) * size.y * 0.22 * (1.0 - sk)
	var p := c + orbit
	var h := minf(size.x, size.y) * 0.22 * (1.0 - sk * 0.92)
	if sk < 1.0:
		ShadowArt.silhouette(ci, p, h, sk * sk * 14.0, Color(0.02, 0.01, 0.03, 1.0 - sk * 0.4), Color(ShadowArt.GREEN, 0.7 * (1.0 - sk)), t)
	if doom_t > 1.0:
		var font := ThemeDB.fallback_font
		var txt := "SWALLOWED BY THE SHADOWS"
		var fs := int(clampf(size.x * 0.045, 20.0, 40.0))
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a2 := clampf(doom_t - 1.0, 0.0, 1.0)
		var tp := Vector2((size.x - tw) * 0.5, size.y * 0.16)
		ci.draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, a2))
		ci.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.55, 1.0, a2))


func _draw_mat() -> void:
	var m: Rect2 = lay["mat"]
	var r := m.grow(6.0)
	CardArt.fill_rrect(self, r, 14.0, Color(0.03, 0.025, 0.03))
	var mid: Rect2 = lay["mid"]
	var split := mid.get_center().y
	var top := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, split - r.position.y - 3))
	var bot := Rect2(Vector2(r.position.x + 3, split), Vector2(r.size.x - 6, r.end.y - split - 3))
	CardArt.fill_rrect(self, top, 12.0, Color(0.1, 0.035, 0.14) if for_reals else FELT_TOP)
	CardArt.fill_rrect(self, bot, 12.0, Color(0.06, 0.03, 0.09) if for_reals else FELT_BOTTOM)
	# a faint chessboard watermark across the felt
	var sq := float(lay["cw"]) * 0.5
	var rows := int(r.size.y / sq) + 1
	var cols := int(r.size.x / sq) + 1
	for yy in rows:
		for xx in cols:
			if (xx + yy) % 2 == 0:
				var cell := Rect2(r.position.x + xx * sq, r.position.y + yy * sq, sq, sq).intersection(r.grow(-4.0))
				if cell.size.x > 0.0 and cell.size.y > 0.0:
					draw_rect(cell, Color(1, 1, 1, 0.018))
	if for_reals:
		CardArt.line_rrect(self, r.grow(3.0), 16.0, Color(ShadowArt.PURPLE, 0.25 + 0.15 * sin(t * 1.5)), 5.0)
		CardArt.line_rrect(self, r, 14.0, Color(0.6, 0.35, 0.85, 0.9), 2.0)
		draw_line(Vector2(r.position.x + 10, split), Vector2(r.end.x - 10, split), Color(ShadowArt.GREEN, 0.3), 1.5)
		return
	CardArt.line_rrect(self, r, 14.0, Color(UI.BORDER, 0.8), 2.0)
	draw_line(Vector2(r.position.x + 10, split), Vector2(r.end.x - 10, split), Color(UI.GOLD, 0.25), 1.5)


func _draw_portrait() -> void:
	var pr := _portrait_rect()
	CardArt.fill_rrect(self, pr, 10.0, Color(0.2, 0.12, 0.24))
	var ptop := Color(0.16, 0.05, 0.22) if for_reals else Color(0.32, 0.16, 0.36)
	var pbot := Color(0.02, 0.01, 0.03) if for_reals else Color(0.1, 0.06, 0.12)
	draw_polygon(PackedVector2Array([pr.position, Vector2(pr.end.x, pr.position.y), pr.end, Vector2(pr.position.x, pr.end.y)]),
		PackedColorArray([ptop, ptop, pbot, pbot]))
	if heart_glow > 0.0:
		var a := clampf(heart_glow, 0.0, 1.0)
		for i in 4:
			draw_circle(pr.get_center(), pr.size.x * (0.6 - i * 0.1), Color(1.0, 0.8, 0.3, 0.08 * a))
	var inner := pr.grow(-4.0)
	if for_reals:
		_draw_reals_yugi(pr, inner)
	else:
		YugiArt.draw(self, inner, t, yugi_expr)
	if portrait_flash > 0.0:
		CardArt.fill_rrect(self, pr, 10.0, Color(1, 0.25, 0.2, portrait_flash * 0.35))
	var border := Color(UI.GOLD, 0.9)
	var direct_ok := not busy and not over and game.current == ME and sel_zone >= 0 and game.can_attack_target(ME, sel_zone, -1)
	if direct_ok:
		border = Color(1.0, 0.35, 0.25, 0.6 + 0.4 * sin(t * 6.0))
	CardArt.line_rrect(self, pr, 10.0, border, 3.0 if direct_ok else 2.0)
	var font := ThemeDB.fallback_font
	var fs := 15
	var label := "YUGI MOTO"
	if direct_ok:
		label = "ATTACK!"
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw + 10.0 > pr.size.x:
		label = "YUGI" if not direct_ok else label
		tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lp := Vector2(pr.get_center().x - tw * 0.5, pr.end.y - 6.0)
	draw_rect(Rect2(lp.x - 6, lp.y - fs, tw + 12, fs + 6), Color(0, 0, 0, 0.6))
	draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.5, 0.4) if direct_ok else UI.GOLD)


func _draw_lp(side: int) -> void:
	var r := _lp_rect(side)
	var font := ThemeDB.fallback_font
	var v: float = disp_lp[side]
	var k := clampf(v / float(game.start_lp), 0.0, 1.0)
	CardArt.fill_rrect(self, r, 5.0, Color(0.05, 0.03, 0.04, 0.9))
	var col := Color(0.35, 0.8, 0.35).lerp(Color(0.9, 0.25, 0.15), 1.0 - k)
	if k > 0.0:
		CardArt.fill_rrect(self, Rect2(r.position, Vector2(maxf(r.size.x * k, 8.0), r.size.y)), 5.0, col.darkened(0.25))
		draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(maxf(r.size.x * k - 6.0, 2.0), r.size.y * 0.35)), Color(1, 1, 1, 0.15))
	CardArt.line_rrect(self, r, 5.0, Color(UI.BORDER, 0.9), 1.5)
	var fs := 15
	var who := "YOU" if side == ME else "YUGI"
	var txt := "%s   %d LP" % [who, int(round(v))]
	var y := r.get_center().y + fs * 0.36
	draw_string_outline(font, Vector2(r.position.x + 8, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(r.position.x + 8, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.97, 0.9))
	var hand_txt := ("Hand %d" % _vhand(side).size()) if side == YUGI else ""
	if game.turn > 0 and game.current == side and not over:
		CardArt.line_rrect(self, r.grow(2.0), 6.0, Color(UI.GOLD, 0.5 + 0.3 * sin(t * 3.0)), 2.0)
	var main_w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if hand_txt != "" and main_w + font.get_string_size(hand_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0 < r.size.x:
		var tw := font.get_string_size(hand_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, Vector2(r.end.x - tw - 8, y), hand_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(r.end.x - tw - 8, y), hand_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD)


func _draw_decks() -> void:
	var font := ThemeDB.fallback_font
	for side in 2:
		var r := _deck_rect(side)
		var n := int(view["deck"][side])
		var layers := mini(3, n)
		for i in layers:
			CardArt.draw_back(self, Rect2(r.position - Vector2(i, i) * 2.0, r.size), t)
		if n == 0:
			CardArt.line_rrect(self, r, r.size.x * 0.06, Color(1, 1, 1, 0.15), 1.5)
		var txt := str(n)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var c := r.get_center() - Vector2(2, 2)
		draw_circle(c, 15.0, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(c.x - tw * 0.5, c.y + 7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 0.85))
		var g := "Grave %d" % int(view["grave"][side])
		var gw := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var gy := r.end.y + 15.0 if r.end.y + 15.0 < (lay["zones"][side][0] as Rect2).end.y + 2.0 else r.position.y - 6.0
		draw_string(font, Vector2(r.get_center().x - gw * 0.5, gy), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
		var dl := "DECK"
		var dlw := font.get_string_size(dl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(r.get_center().x - dlw * 0.5, r.position.y - 8.0), dl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)


func _draw_yugi_hand() -> void:
	var rects := _hand_rects(YUGI)
	for i in rects.size():
		if hidden_hand[YUGI].has(i):
			continue
		var r: Rect2 = rects[i]
		_draw_card_xf(r, "", false, (i - rects.size() * 0.5) * 0.04, Vector2.ONE)


func _draw_mid() -> void:
	var mid: Rect2 = lay["mid"]
	var font := ThemeDB.fallback_font
	var fs := 15
	var txt := "Turn %d / %d" % [maxi(1, game.turn), game.max_turns]
	draw_string(font, Vector2(mid.position.x + 4, mid.get_center().y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.DIM)
	var status := ""
	if over:
		status = "Duel over"
	elif game.current == ME:
		status = "Your turn"
		if game.attacks_locked:
			status = "No attacks this turn"
	else:
		status = "Yugi's turn"
	var col := UI.GOLD if game.current == ME else Color(0.85, 0.6, 1.0)
	var sw := font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(mid.end.x - sw - 4, mid.get_center().y + fs * 0.36), status, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if banner_time > 0.0:
		var a := clampf(banner_time / 0.4, 0.0, 1.0) * clampf((1.3 - banner_time) / 0.15 + 0.2, 0.0, 1.0)
		var bs := int(clampf(float(lay["cw"]) * 0.26, 20.0, 34.0))
		var bw := font.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
		var c := mid.get_center()
		draw_rect(Rect2(c.x - bw * 0.5 - 16, c.y - bs * 0.75, bw + 32, bs * 1.5), Color(0, 0, 0, 0.6 * a))
		draw_string_outline(font, Vector2(c.x - bw * 0.5, c.y + bs * 0.36), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, 6, Color(0, 0, 0, a))
		draw_string(font, Vector2(c.x - bw * 0.5, c.y + bs * 0.36), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(col, a))


func _draw_fields() -> void:
	var font := ThemeDB.fallback_font
	var cw: float = lay["cw"]
	var my_turn := not busy and not over and game.current == ME
	var sel_id := String(_vhand(ME)[sel_hand]) if sel_hand >= 0 and sel_hand < _vhand(ME).size() else ""
	var pulse := 0.55 + 0.45 * sin(t * 5.0)
	for s in 2:
		for z in 3:
			var base: Rect2 = lay["zones"][s][z]
			var r := _zone_rect(s, z)
			var m := _vfield(s, z)
			# empty slot
			CardArt.fill_rrect(self, base, cw * 0.06, Color(0, 0, 0, 0.25))
			CardArt.line_rrect(self, base, cw * 0.06, Color(1, 1, 1, 0.12), 1.5)
			if m.is_empty():
				if my_turn and sel_id != "" and s == ME and CardData.is_monster(sel_id) and game.can_summon(ME, sel_hand, z):
					_outline(base, Color(UI.GOLD, pulse), 3.0)
					var c := base.get_center()
					draw_line(c - Vector2(cw * 0.12, 0), c + Vector2(cw * 0.12, 0), Color(UI.GOLD, pulse), 3.0)
					draw_line(c - Vector2(0, cw * 0.12), c + Vector2(0, cw * 0.12), Color(UI.GOLD, pulse), 3.0)
				continue
			if s == ME and z == sel_zone:
				r.position.y -= 8.0
			_draw_card_xf(r, String(m["id"]), true, 0.0, Vector2.ONE, _card_opts(s, m))
			if zone_flash[s][z] > 0.0:
				CardArt.fill_rrect(self, r, cw * 0.06, Color(1, 1, 0.85, zone_flash[s][z] * 0.45))
			if not my_turn:
				continue
			# highlights
			if s == ME and z == sel_zone:
				_outline(r, UI.GOLD, 4.0)
			elif s == ME and sel_zone < 0 and sel_hand < 0 and game.can_attack(ME, z) and game.turn > 1:
				_outline(r, Color(UI.EMBER, 0.35 + 0.35 * pulse), 2.5)
			if sel_id != "" and CardData.is_spell(sel_id) and game.can_cast(ME, sel_hand, s, z):
				_outline(r, Color(0.5, 1.0, 0.9, pulse), 3.5)
			if s == YUGI and sel_zone >= 0 and game.can_attack_target(ME, sel_zone, z):
				var a := int(game.monster(ME, sel_zone)["atk"])
				var d := int(m["atk"])
				var col := Color(0.4, 1.0, 0.4) if a > d else (Color(1.0, 0.85, 0.3) if a == d else Color(1.0, 0.35, 0.3))
				_outline(r, Color(col, pulse), 3.5)
				var tag := "WIN" if a > d else ("TRADE" if a == d else "LOSE")
				var fs := 14
				var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var p := Vector2(r.get_center().x - tw * 0.5, r.position.y - 6.0)
				draw_rect(Rect2(p.x - 5, p.y - fs, tw + 10, fs + 5), Color(0, 0, 0, 0.75))
				draw_string(font, p, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_swords() -> void:
	for s in 2:
		if swords_fx[s] <= 0.0:
			continue
		var k: float = 2.0 - float(swords_fx[s])
		for z in 3:
			var r: Rect2 = lay["zones"][s][z]
			var x := r.get_center().x
			var fall := clampf(k / 0.5, 0.0, 1.0)
			var y1 := lerpf(r.position.y - r.size.y * 0.8, r.position.y + r.size.y * 0.1, fall)
			var a := clampf(float(swords_fx[s]), 0.0, 1.0)
			draw_line(Vector2(x, y1), Vector2(x, y1 + r.size.y * 0.8), Color(0.85, 0.95, 1.0, a), 6.0, true)
			draw_line(Vector2(x - 14, y1 + r.size.y * 0.12), Vector2(x + 14, y1 + r.size.y * 0.12), Color(1.0, 0.85, 0.35, a), 4.0, true)
			draw_circle(Vector2(x, y1 + r.size.y * 0.8), 9.0, Color(0.7, 0.85, 1.0, 0.35 * a))


func _draw_hand() -> void:
	var rects := _hand_rects(ME)
	var hand := _vhand(ME)
	var my_turn := not busy and not over and game.current == ME
	var order: Array = []
	for i in rects.size():
		if i != sel_hand:
			order.append(i)
	if sel_hand >= 0 and sel_hand < rects.size():
		order.append(sel_hand)
	for i in order:
		if hidden_hand[ME].has(i):
			continue
		var r: Rect2 = rects[i]
		var id := String(hand[i])
		var o := _card_opts(ME)
		if my_turn:
			var playable := game.can_summon(ME, i) if CardData.is_monster(id) else game.castable(ME, i)
			o["dim"] = not playable and i != sel_hand
		CardArt.draw_card(self, r, id, o)
		if i == sel_hand:
			_outline(r, UI.GOLD, 4.0)


func _draw_ghosts() -> void:
	for g in ghosts:
		var gt := float(g["t"])
		var hold := float(g["hold"])
		var k := clampf((gt - hold) / float(g["dur"]), 0.0, 1.0)
		var r: Rect2 = g["rect"]
		var sc := 1.0 - k * k
		if sc <= 0.02:
			continue
		var rot := k * (1.4 if bool(g.get("red", false)) else 0.0)
		if bool(g.get("glow", false)):
			draw_circle(r.get_center(), r.size.y * 0.62 * (1.0 + 0.1 * sin(t * 8.0)), Color(0.6, 1.0, 0.9, 0.12 * sc))
		var opts := {"white": player_white, "t": t}
		if g.has("atk"):
			opts["atk"] = int(g["atk"])
		_draw_card_xf(r, String(g["id"]), bool(g["face"]), rot, Vector2(sc, sc), opts)
		if bool(g.get("red", false)):
			var c := r.get_center()
			draw_set_transform(c, rot, Vector2(sc, sc))
			CardArt.fill_rrect(self, Rect2(-r.size * 0.5, r.size), r.size.x * 0.06, Color(1, 0.2, 0.1, 0.25 + 0.5 * k))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_flyers() -> void:
	for f in flyers:
		var k := clampf(float(f["t"]) / float(f["dur"]), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var a: Rect2 = f["from"]
		var b: Rect2 = f["to"]
		var r := Rect2(a.position.lerp(b.position, e), a.size.lerp(b.size, e))
		var face := bool(f["face"])
		var sx := 1.0
		if bool(f["flip"]):
			sx = absf(cos(e * PI))
			face = e >= 0.5
		_draw_card_xf(r, String(f["id"]), face and String(f["id"]) != "", 0.0, Vector2(maxf(sx, 0.05), 1.0), {"white": player_white, "t": t})


func _draw_sparks() -> void:
	for sp in sparks:
		var c: Color = sp["c"]
		c.a = 1.0 - float(sp["t"]) / float(sp["life"])
		draw_circle(sp["p"], float(sp["r"]), c)
	var font := ThemeDB.fallback_font
	for f in floaters:
		var a := 1.0 - clampf((float(f["t"]) - 0.7) / 0.6, 0.0, 1.0)
		var c2: Color = f["c"]
		c2.a = a
		var fs := 30
		var text := String(f["text"])
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = (f["p"] as Vector2) - Vector2(tw * 0.5, 0)
		draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a))
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c2)


func _draw_bubble() -> void:
	if bubble_time <= 0.0 or bubble_text == "":
		return
	var a := clampf(bubble_time / 0.3, 0.0, 1.0) * clampf(bubble_age / 0.12, 0.0, 1.0)
	var area: Rect2 = lay["bubble"]
	var font := ThemeDB.fallback_font
	var fs := 16
	var pad := 10.0
	var maxw := maxf(120.0, area.size.x)
	var ts := font.get_multiline_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, maxw - pad * 2.0, fs)
	var bw := minf(maxw, ts.x + pad * 2.0 + 2.0)
	var bh := ts.y + pad * 1.6
	var pop := 1.0 + 0.08 * clampf(1.0 - bubble_age / 0.15, 0.0, 1.0)
	var r := Rect2(area.position + Vector2(14.0, 0.0), Vector2(bw, bh))
	if r.end.x > size.x - 4.0:
		r.position.x = size.x - 4.0 - r.size.x
	var mouth := YugiArt.mouth_point(_portrait_rect().grow(-4.0))
	var base_y := clampf(mouth.y, r.position.y + 10.0, r.end.y - 10.0)
	var tail := PackedVector2Array([Vector2(r.position.x + 2.0, base_y - 9.0), Vector2(r.position.x + 2.0, base_y + 9.0),
		Vector2(r.position.x, base_y).lerp(mouth, 0.55)])
	draw_set_transform(r.position * (1.0 - pop), 0.0, Vector2(pop, pop))
	CardArt.fill_rrect(self, Rect2(r.position + Vector2(3, 4), r.size), 12.0, Color(0, 0, 0, 0.35 * a))
	draw_colored_polygon(tail, Color(BUBBLE, a))
	CardArt.fill_rrect(self, r, 12.0, Color(BUBBLE, a))
	CardArt.line_rrect(self, r, 12.0, Color(0.25, 0.15, 0.1, a), 2.0)
	draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), Color(0.25, 0.15, 0.1, a), 2.0, true)
	draw_multiline_string(font, r.position + Vector2(pad, pad * 0.8 + fs * 0.95), bubble_text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0, fs, -1, Color(0.12, 0.07, 0.06, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Yugi in a shadow game: mist at his feet, the pendant blazing, and at the end
## the vortex that swallows him.
func _draw_reals_yugi(pr: Rect2, inner: Rect2) -> void:
	var c := pr.get_center()
	var f := YugiArt.figure_rect(inner)
	var pend := f.position + Vector2(0.5, 1.03) * f.size.x
	var k := clampf(doom_t / 3.0, 0.0, 1.0) if doom == "yugi" else 0.0
	var e := k * k
	if doom == "yugi":
		ShadowArt.vortex(self, c + Vector2(0, pr.size.y * 0.15), pr.size.x * (0.25 + 0.45 * minf(1.0, k * 2.0)), t * 2.0, minf(1.0, k * 4.0), 0.7, 6)
	# eerie shadow halo behind him
	for i in 3:
		draw_circle(c + Vector2(0, -pr.size.y * 0.05), pr.size.x * (0.48 - i * 0.08), Color(ShadowArt.PURPLE, 0.06))
	var off := Vector2(0, pr.size.y * 0.2 * k)
	var sc := 1.0 - k * 0.97
	if sc > 0.03:
		var local := Rect2(inner.position - c, inner.size)
		draw_set_transform(c + off + _shk, e * 6.0 + sin(t * 30.0) * 0.04 * k, Vector2(sc, sc))
		YugiArt.draw(self, local, t, yugi_expr)
		# the pendant's golden blaze
		var lp := pend - c
		var pulse := 0.6 + 0.4 * sin(t * 4.0)
		for i in 4:
			draw_circle(lp, f.size.x * (0.2 - i * 0.04) * (0.9 + 0.2 * pulse), Color(1.0, 0.82, 0.3, 0.07 + 0.04 * i))
		for i in 8:
			var a := TAU * i / 8.0 + t * 0.6
			draw_line(lp + Vector2.from_angle(a) * f.size.x * 0.07, lp + Vector2.from_angle(a) * f.size.x * (0.16 + 0.05 * pulse), Color(1.0, 0.9, 0.5, 0.4), maxf(1.0, f.size.x * 0.01), true)
		draw_set_transform(_shk, 0.0, Vector2.ONE)
	# mist curling around his shoulders
	ShadowArt.mist(self, pr, t, Color(0.55, 0.35, 0.8, 0.07), 4, 0.8, 0.98)
	draw_set_transform(_shk, 0.0, Vector2.ONE)
	if doom == "yugi":
		for i in 6:
			var from := Vector2(pr.position.x + pr.size.x * (0.1 + i * 0.16), pr.end.y)
			ShadowArt.tendril(self, from, c + off + Vector2((i - 2.5) * pr.size.x * 0.06, -pr.size.y * 0.1 * (1.0 - e)), t, pr.size.x * 0.06,
				Color(0.04, 0.01, 0.07, 0.95), clampf(k * 2.2 - i * 0.08, 0.0, 1.0), i * 2.1)
