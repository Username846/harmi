class_name ChessScreen
extends Control
## The chessboard: turn flow, AI, action menu, inventory, and every way off the
## board - captures (labyrinths and duels), odd jobs, pink slip races, dates,
## the shop, the graveyard and whatever the Beyblade knocks over.

signal encounter_requested(info: Dictionary)
signal quit_to_title

const PINK := Color(1.0, 0.45, 0.75)
const SHORT_REASON := {"is away on a job": "away", "is knocked over": "knocked over", "has no car": "no car"}

var rules := ChessRules.new()
var ai := ChessAI.new()
var board: BoardView
var side_panel: PanelContainer
var status_label: Label
var sub_label: Label
var wallet_label: Label
var log_box: RichTextLabel
var tray: Control
var buttons: GridContainer
var inv_btn: Button
var shop_btn: Button
var grave_btn: Button
var beyblade: BeybladeButton
var overlay_layer: Control

var state := "idle" # idle, moving, picking, busy, encounter, over
var move_targets: Dictionary = {}
var pending: Dictionary = {}
var pick: Dictionary = {} # {"kind": "race"/"sniper", "from": square}
var double_move := [false, false]
var turn_no := 0
var _upkept := -1
var _menu: Control = null
var _gen := 0 # bumped on every new game so stale coroutines can bail out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board = BoardView.new()
	board.rules = rules
	board.tapped.connect(_on_board_tapped)
	add_child(board)

	side_panel = PanelContainer.new()
	add_child(side_panel)
	var vb := VBoxContainer.new()
	side_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	head.add_child(titles)
	status_label = UI.label("", 26, UI.GOLD)
	titles.add_child(status_label)
	sub_label = UI.label("", 17, UI.DIM)
	titles.add_child(sub_label)
	beyblade = BeybladeButton.new(64.0)
	head.add_child(beyblade)
	wallet_label = UI.label("", 18, UI.GREEN)
	vb.add_child(wallet_label)
	buttons = GridContainer.new()
	buttons.columns = 2
	vb.add_child(buttons)
	inv_btn = _panel_button("Inventory", _show_inventory)
	shop_btn = _panel_button("Shop", _show_shop)
	grave_btn = _panel_button("Graveyard", _show_graveyard)
	_panel_button("Menu", _show_menu)
	tray = Control.new()
	tray.custom_minimum_size = Vector2(0, 84)
	tray.draw.connect(_draw_tray)
	vb.add_child(tray)
	log_box = UI.rich(17)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.custom_minimum_size = Vector2(0, 80)
	vb.add_child(log_box)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)

	Game.inventory_changed.connect(_refresh_hud)
	Game.money_changed.connect(_refresh_hud)
	Music.snapped.connect(_on_beyblade_snapped)
	resized.connect(_on_resized)
	side_panel.minimum_size_changed.connect(_queue_relayout)
	new_game()


func _exit_tree() -> void:
	for pair in [[Game.inventory_changed, _refresh_hud], [Game.money_changed, _refresh_hud], [Music.snapped, _on_beyblade_snapped]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _panel_button(text: String, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(b)
	return b


func new_game() -> void:
	_gen += 1
	_close_menu()
	for c in board.get_children():
		if c is AshEffect:
			c.queue_free()
	rules.setup_start()
	board.hidden_ids.clear()
	board.offsets.clear()
	board.ash_marks.clear()
	board.alpha_of.clear()
	board.last_from = -1
	board.last_to = -1
	board.selected = -1
	board.targets = {}
	pending = {}
	pick = {}
	double_move = [false, false]
	turn_no = 0
	_upkept = -1
	# every new game comes with a fresh Beyblade
	if Music.broken:
		Music.repair()
	Music.pending_crash = false
	log_box.clear()
	_log("[color=#e0aa4a]A new game begins.[/color] Tap one of your pieces to act.")
	if Game.vs_ai:
		_log("You command White. The machine commands Black.")
	_log("[color=#a9a39f]Tip: tap the Beyblade (top right of this panel) and pull its rip cord for music.[/color]")
	_relayout()
	_refresh_hud()
	_start_turn()


## Testing helper: start from a FEN position.
func load_position(fen: String) -> void:
	rules.load_fen(fen)
	# keep ids distinct per colour so buffs/encounters behave
	for s in 64:
		if rules.board[s] != 0:
			rules.ids[s] = s + (100 if (rules.board[s] & 8) else 0)
	board.last_from = -1
	board.last_to = -1
	_log("[color=#a9a39f](Loaded test position.)[/color]")
	_start_turn()


func _relayout() -> void:
	if board == null:
		return
	var w := size.x
	var h := size.y
	var m := 12.0
	if w >= h * 1.15:
		var pw := clampf(w * 0.36, 280.0, 440.0)
		board.position = Vector2(m, m)
		board.size = Vector2(w - pw - m * 3.0, h - m * 2.0)
		side_panel.position = Vector2(w - pw - m, m)
		side_panel.size = Vector2(pw, h - m * 2.0)
		buttons.columns = 2
	else:
		var bh := minf(BoardView.needed_height(w - m * 2.0), h * 0.6)
		board.position = Vector2(m, m)
		board.size = Vector2(w - m * 2.0, bh)
		side_panel.position = Vector2(m, bh + m * 2.0)
		side_panel.size = Vector2(w - m * 2.0, h - bh - m * 3.0)
		buttons.columns = 4 if w - m * 2.0 >= 470.0 else 2


func _on_resized() -> void:
	_close_menu()
	_relayout()


func _alive(g: int) -> bool:
	return g == _gen and is_inside_tree()


var _relayout_queued := false


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


func _is_human(color: int) -> bool:
	return not Game.vs_ai or color == ChessRules.WHITE


## The side whose wallet and satchel the panel shows.
func _human_side() -> int:
	return rules.side if not Game.vs_ai else ChessRules.WHITE


func _log(text: String) -> void:
	log_box.append_text(text + "\n")


func _refresh_hud() -> void:
	if inv_btn == null:
		return
	inv_btn.text = "Inventory (%d)" % Game.item_ids().size()
	var dead: int = Game.graveyard[Game.active_side].size()
	grave_btn.text = "Graveyard (%d)" % dead if dead > 0 else "Graveyard"
	if Game.vs_ai:
		wallet_label.text = "Wallet: $%d" % Game.money
	else:
		wallet_label.text = "%s's wallet: $%d" % [Game.color_name(Game.active_side), Game.money]
	if double_move[Game.active_side]:
		wallet_label.text += "   Double move ready!"
	tray.queue_redraw()


func _title(s: int) -> String:
	var code := rules.board[s]
	return Game.piece_title(code & 7, ChessRules.color_of(code))


# --- turn flow ----------------------------------------------------------------

func _start_turn() -> void:
	board.selected = -1
	board.targets = {}
	move_targets = {}
	pick = {}
	board.check_sq = rules.king_square(rules.side) if rules.in_check(rules.side) else -1
	if _check_game_end():
		return
	var mover := rules.side
	if _is_human(mover):
		Game.active_side = _human_side()
	if _upkept != turn_no:
		_upkept = turn_no
		_upkeep(mover)
	_refresh_hud()
	if Music.pending_crash and is_visible_in_tree():
		_crash_beyblade()
		return
	var who := Game.color_name(mover)
	if _is_human(mover):
		state = "idle"
		board.interactive = true
		status_label.text = ("Check! " if board.check_sq >= 0 else "") + "%s to move" % who
		sub_label.text = "Tap a piece to open its action menu."
	else:
		state = "busy"
		board.interactive = false
		status_label.text = ("Check! " if board.check_sq >= 0 else "") + "%s is thinking..." % who
		sub_label.text = ""
		var g := _gen
		await get_tree().create_timer(0.45).timeout
		if not _alive(g) or state != "busy":
			return
		await get_tree().process_frame
		if not _alive(g) or state != "busy":
			return
		var m := ai.choose_move(rules, Game.difficulty, _banned(mover))
		if m.is_empty():
			return
		if not Game.can_move_piece(rules.ids[m["from"]]):
			_log("[color=#a9a39f]With nothing else able to move, the %s does what it must.[/color]" % _title(m["from"]))
		await _play_move(m, false)
		if _alive(g):
			_turn_done(mover)


## Start of a side's turn: pieces come back from their odd jobs.
func _upkeep(color: int) -> void:
	for s in 64:
		var code := rules.board[s]
		if code == 0 or ChessRules.color_of(code) != color:
			continue
		var pid := rules.ids[s]
		var p := Game.piece(pid)
		if int(p["away"]) <= 0:
			continue
		p["away"] = int(p["away"]) - 1
		if int(p["away"]) > 0:
			continue
		var o := OddJobs.outcome(code & 7, float(p["mood"]), bool(p.get("really", false)))
		Game.add_money(int(o["pay"]), color)
		Game.change_mood(pid, float(o["mood"]))
		if String(o["item"]) != "":
			var keep := Game.active_side
			Game.active_side = color
			Game.add_item(String(o["item"]))
			Game.active_side = keep
		var how := ", " + String(o["text"]) if String(o["text"]) != "" else ""
		_log("[color=#6fc06a]The %s is back from %s%s. +$%d[/color]" % [_title(s), "the job" if String(p["job"]) == "" else "a job: " + String(p["job"]), how, int(o["pay"])])
		p["job"] = ""


## Called after every completed turn (a move or an off-board action).
func _turn_done(mover: int) -> void:
	for s in 64:
		var code := rules.board[s]
		if code == 0 or ChessRules.color_of(code) != mover:
			continue
		var p := Game.piece(rules.ids[s])
		if int(p["toppled"]) > 0:
			p["toppled"] = int(p["toppled"]) - 1
			if int(p["toppled"]) == 0:
				_log("[color=#a9a39f]The %s dusts itself off and stands back up.[/color]" % _title(s))
	turn_no += 1
	if double_move[mover] and rules.side != mover and rules.status() == "ongoing":
		double_move[mover] = false
		if rules.in_check(rules.side):
			_log("[color=#a9a39f]Your double move fizzles: no second move while giving check.[/color]")
		else:
			rules.pass_turn()
			_upkept = turn_no
			_log("[color=#e0aa4a]Double move! %s goes again.[/color]" % Game.color_name(mover))
	_start_turn()


## Ends the human's turn without a chess move (odd jobs, races, dates, shots).
func _pass_after_action() -> void:
	var mover := rules.side
	board.selected = -1
	rules.pass_turn()
	board.last_from = -1
	board.last_to = -1
	_turn_done(mover)


## Squares whose pieces can't move this turn (no car, away, knocked over).
func _banned(color: int) -> Dictionary:
	var out := {}
	for s in 64:
		var code := rules.board[s]
		if code != 0 and ChessRules.color_of(code) == color and not Game.can_move_piece(rules.ids[s]):
			out[s] = true
	return out


## Legal moves the side to move may actually make. If every mobile piece is
## stuck, the immobile ones pitch in after all.
func _usable_moves() -> Array:
	var legal := rules.legal_moves()
	var banned := _banned(rules.side)
	var free := legal.filter(func(m): return not banned.has(m["from"]))
	return legal if free.is_empty() else free


func _moves_from(s: int) -> Array:
	return _usable_moves().filter(func(m): return m["from"] == s)


func _check_game_end() -> bool:
	var st := rules.status()
	if st == "ongoing":
		return false
	state = "over"
	board.interactive = false
	if st == "checkmate":
		var loser := rules.side
		var winner := 1 - loser
		_log("[color=#e2643a][b]Checkmate![/b][/color]")
		if _is_human(winner):
			status_label.text = "Checkmate!"
			sub_label.text = "The %s King must be faced in person." % Game.color_name(loser)
			_begin_final_duel(winner, loser)
		else:
			status_label.text = "Checkmate. You lose."
			sub_label.text = ""
			_defeat_sequence(winner, loser)
	else:
		var why := {"stalemate": "Stalemate.", "fifty": "Draw by the fifty-move rule.",
			"repetition": "Draw by threefold repetition.", "material": "Draw: neither side can deliver mate."}
		status_label.text = "Draw"
		sub_label.text = why.get(st, "Draw.")
		_log(why.get(st, "Draw."))
		_show_end("Draw", why.get(st, "Draw."))
	return true


func _defeat_sequence(winner: int, loser: int) -> void:
	var g := _gen
	await get_tree().create_timer(0.6).timeout
	if not _alive(g):
		return
	var ks := rules.king_square(loser)
	_on_piece_fallen(rules.board[ks], rules.ids[ks], ks)
	board.check_sq = -1
	var fx := board.disintegrate(ks, 2.4)
	await fx.finished
	if not _alive(g):
		return
	_show_end("Defeat", "Your king crumbles into ash. The %s pieces win." % Game.color_name(winner))


func _begin_final_duel(winner: int, loser: int) -> void:
	var g := _gen
	await get_tree().create_timer(0.9).timeout
	if not _alive(g):
		return
	var hero_sq := board.last_to if board.last_to >= 0 and rules.board[board.last_to] != 0 else rules.king_square(winner)
	var ks := rules.king_square(loser)
	pending = {"kind": "final", "foe_sq": ks}
	state = "encounter"
	encounter_requested.emit({
		"kind": "final", "lab": "",
		"hero_type": rules.board[hero_sq] & 7, "hero_color": winner, "hero_id": rules.ids[hero_sq], "hero_mood": Game.mood_of(rules.ids[hero_sq]),
		"foe_type": ChessRules.KING, "foe_color": loser, "foe_id": rules.ids[ks], "foe_mood": Game.mood_of(rules.ids[ks]),
		"foe_screen_pos": board.get_global_transform() * board.square_center(ks),
	})


func _play_move(m: Dictionary, _human: bool, from_frac: float = 0.0) -> void:
	var from: int = m["from"]
	var to: int = m["to"]
	var pid := rules.ids[from]
	var cap := rules.capture_square(m)
	var tweens: Array = []
	var g := _gen
	if m["flag"] == ChessRules.FLAG_CASTLE_K or m["flag"] == ChessRules.FLAG_CASTLE_Q:
		var rook_from: int = to + 1 if m["flag"] == ChessRules.FLAG_CASTLE_K else to - 2
		var rook_to: int = to - 1 if m["flag"] == ChessRules.FLAG_CASTLE_K else to + 1
		var rid := rules.ids[rook_from]
		var tr := board.slide(rid, rook_from, rook_to, 0.0, 1.0, 0.4)
		tweens.append(tr)
	if cap >= 0 and not board.hidden_ids.has(rules.ids[cap]):
		var t1 := board.slide(pid, from, to, from_frac, 0.6, 0.25)
		await t1.finished
		if not _alive(g):
			return
		_on_piece_fallen(rules.board[cap], rules.ids[cap], cap)
		board.disintegrate(cap, 1.3)
		var t2 := board.slide(pid, from, to, 0.6, 1.0, 0.2)
		await t2.finished
	else:
		var t3 := board.slide(pid, from, to, from_frac, 1.0, 0.32)
		await t3.finished
	for tw in tweens:
		if tw.is_running():
			await tw.finished
	if not _alive(g):
		return
	var san := rules.san(m)
	var mover := rules.side
	var num := rules.fullmove
	rules.play(m)
	board.offsets.clear()
	board.on_top_id = -1
	board.last_from = from
	board.last_to = to
	var prefix := "%d. " % num if mover == ChessRules.WHITE else "%d... " % num
	_log("%s[b]%s[/b]" % [prefix, san])
	if m["promo"] != 0:
		_log("The pawn is promoted to a %s!" % Game.PIECE_NAMES[m["promo"]])


## A piece leaves the board for good (captured, sniped, driven-by): it goes to
## the graveyard and its comrades take it hard.
func _on_piece_fallen(code: int, pid: int, s: int) -> void:
	var color := ChessRules.color_of(code)
	Game.bury(color, code & 7, pid)
	if (code & 7) != ChessRules.KING:
		_witness(color, s, 6.0)
	if _is_human(color):
		Game.stats["lost"] = int(Game.stats.get("lost", 0)) + 1
	_refresh_hud()


## Everyone on `color`'s side who saw a comrade fall feels worse; those
## standing close by feel it most.
func _witness(color: int, at: int, amount: float) -> void:
	for s in 64:
		var code := rules.board[s]
		if code == 0 or s == at or ChessRules.color_of(code) != color:
			continue
		var d := maxi(absi((s & 7) - (at & 7)), absi((s >> 3) - (at >> 3)))
		Game.change_mood(rules.ids[s], -amount * (1.8 if d <= 2 else 1.0))


## Removes a piece off-turn with the ash effect (sniper, drive-by).
func _kill_piece(s: int) -> void:
	var code := rules.board[s]
	if code == 0:
		return
	_on_piece_fallen(code, rules.ids[s], s)
	board.disintegrate(s, 1.5)
	rules.remove_piece(s)
	if _is_human(1 - ChessRules.color_of(code)):
		Game.add_item("ash")


# --- input --------------------------------------------------------------------

func _on_board_tapped(sq_plain: int, sq_piece: int) -> void:
	if state == "moving" or state == "picking":
		var targets := move_targets if state == "moving" else board.targets
		var hit := -1
		if targets.has(sq_plain):
			hit = sq_plain
		elif sq_piece >= 0 and targets.has(sq_piece):
			hit = sq_piece
		if hit >= 0:
			if state == "moving":
				_choose_target(hit)
			else:
				_on_pick(hit)
			return
		var s := _pick(sq_plain, sq_piece)
		_cancel_move()
		if s >= 0:
			_open_menu(s)
		return
	if state != "idle":
		return
	var s2 := _pick(sq_plain, sq_piece)
	if s2 >= 0:
		_open_menu(s2)


## The occupied square under the finger wins; otherwise a tall piece whose
## silhouette reaches into the tapped (empty) square.
func _pick(sq_plain: int, sq_piece: int) -> int:
	if sq_plain >= 0 and rules.board[sq_plain] != 0:
		return sq_plain
	if sq_piece >= 0 and rules.board[sq_piece] != 0:
		return sq_piece
	return -1


func _cancel_move() -> void:
	state = "idle"
	board.selected = -1
	board.targets = {}
	board.target_color = Color(0.95, 0.25, 0.15)
	move_targets = {}
	pick = {}
	sub_label.text = "Tap a piece to open its action menu."


func _menu_button(vb: VBoxContainer, text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := UI.button(text, cb, 46)
	b.disabled = disabled
	vb.add_child(b)
	return b


func _open_menu(s: int) -> void:
	_close_menu()
	board.selected = s
	var code := rules.board[s]
	var color := ChessRules.color_of(code)
	var t := code & 7
	var pid := rules.ids[s]
	var my_turn := _is_human(rules.side) and state == "idle"
	var mine := my_turn and color == rules.side
	var enemy := my_turn and color != rules.side
	var checked := rules.in_check(rules.side)

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.gui_input.connect(_on_menu_layer_input)
	overlay_layer.add_child(layer)
	_menu = layer
	var panel := PanelContainer.new()
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	panel.add_child(vb)
	var title := UI.label(Game.piece_title(t, color), 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(title)
	var mood := Game.mood_of(pid)
	var ml := UI.label(Game.mood_name(mood), 15, Game.mood_color(mood), HORIZONTAL_ALIGNMENT_CENTER)
	ml.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(ml)
	if mine:
		var reason := Game.immobile_reason(pid)
		var moves := _moves_from(s)
		var mv_text := "Move"
		if moves.is_empty():
			mv_text = "Move (%s)" % SHORT_REASON.get(reason, "blocked") if reason != "" else "Move (blocked)"
		_menu_button(vb, mv_text, _on_menu_move.bind(s), moves.is_empty())
		var away := int(Game.piece(pid)["away"]) > 0
		var toppled := int(Game.piece(pid)["toppled"]) > 0
		var busy_why := "in check" if checked else ("away" if away else ("knocked over" if toppled else ""))
		_menu_button(vb, "Odd Jobs" if busy_why == "" else "Odd Jobs (%s)" % busy_why, _on_menu_jobs.bind(s), busy_why != "")
		if t != ChessRules.KING:
			var race_why := busy_why
			if race_why == "" and not Game.has_car(pid):
				race_why = "no car"
			if race_why == "" and _race_targets(color).is_empty():
				race_why = "no rivals"
			_menu_button(vb, "Pink Slip Race" if race_why == "" else "Pink Slip Race (%s)" % race_why, _on_menu_race.bind(s), race_why != "")
		var date_why := "in check" if checked else ("away" if away else "")
		_menu_button(vb, "Date" if date_why == "" else "Date (%s)" % date_why, _on_menu_date.bind(s), date_why != "")
		var usable := Game.items_usable_in("board")
		_menu_button(vb, "Use Item" if not usable.is_empty() else "Use Item (none)", _on_menu_use.bind(s), usable.is_empty())
	_menu_button(vb, "Inspect", _on_menu_inspect.bind(s))
	if enemy:
		_menu_button(vb, "Ask on a Date" if not checked else "Ask on a Date (in check)", _on_menu_date.bind(s), checked)
	_menu_button(vb, "Cancel", _on_menu_cancel)
	panel.custom_minimum_size = Vector2(220, 0)
	panel.reset_size()
	# place next to the piece, inside the screen
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	var anchor := board.get_global_transform() * board.square_rect(s).get_center() - get_global_transform().origin
	var ps := panel.size
	var pos := anchor + Vector2(board.sq * 0.7, -ps.y * 0.5)
	if pos.x + ps.x > size.x - 8:
		pos.x = anchor.x - board.sq * 0.7 - ps.x
	pos.x = clampf(pos.x, 8, size.x - ps.x - 8)
	pos.y = clampf(pos.y, 8, size.y - ps.y - 8)
	panel.position = pos
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)


func _on_menu_layer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# tapping outside the menu closes it and passes the tap through to the board
		var gp: Vector2 = event.global_position
		_close_menu()
		board.selected = -1
		var local := board.get_global_transform().affine_inverse() * gp
		if Rect2(Vector2.ZERO, board.size).has_point(local):
			var target := _pick(board.square_at(local), board.piece_square_at(local))
			if target >= 0:
				_open_menu(target)


func _close_menu() -> void:
	if _menu and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null


func _on_menu_cancel() -> void:
	_close_menu()
	board.selected = -1


func _on_menu_move(s: int) -> void:
	_close_menu()
	board.selected = s
	move_targets = {}
	var tg := {}
	for m in _moves_from(s):
		move_targets[m["to"]] = true
		tg[m["to"]] = rules.capture_square(m) >= 0
	board.target_color = Color(0.95, 0.25, 0.15)
	board.targets = tg
	state = "moving"
	sub_label.text = "Tap a gold dot to move, a red square to capture. Tap elsewhere to cancel."


func _on_menu_inspect(s: int) -> void:
	_close_menu()
	board.selected = -1
	var code := rules.board[s]
	var t := code & 7
	var color := ChessRules.color_of(code)
	var pid := rules.ids[s]
	var life := Game.piece(pid)
	var m := Modal.new(Game.piece_title(t, color), 580.0)
	var row := HBoxContainer.new()
	m.add(row)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(110, 210)
	portrait.draw.connect(func():
		var sz := portrait.size
		var s2 := minf(sz.x / 0.8, sz.y / 2.0)
		PieceArt.draw_piece(portrait, t, color == 0, sz.x * 0.5, sz.y - 10, s2))
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var mood := float(life["mood"])
	var mood_row := HBoxContainer.new()
	info.add_child(mood_row)
	mood_row.add_child(UI.label("Mood: %s (%d)" % [Game.mood_name(mood), int(mood)], 18, Game.mood_color(mood)))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(90, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func():
		var r := Rect2(Vector2(0, 4), Vector2(bar.size.x, 12))
		bar.draw_rect(r, Color(0.12, 0.1, 0.11))
		bar.draw_rect(Rect2(r.position, Vector2(r.size.x * mood / 100.0, r.size.y)), Game.mood_color(mood))
		bar.draw_rect(r, UI.BORDER, false, 1.0))
	mood_row.add_child(bar)
	info.add_child(UI.label(BattleData.MOVES_DESC[t], 17))
	var st: Dictionary = BattleData.STATS[t]
	info.add_child(UI.label("Duel stats  HP %d  MP %d  ATK %d  DEF %d  MAG %d" % [st["hp"], st["mp"], st["atk"], st["def"], st["mag"]], 15, UI.DIM))
	var notes: Array = []
	if not bool(life["car"]):
		notes.append("Lost its car in a pink slip race, so it can't move. A Used Car from the shop fixes that.")
	if int(life["away"]) > 0:
		notes.append("Away on a job: %s. Back in %d turn%s." % [life["job"], int(life["away"]), "" if int(life["away"]) == 1 else "s"])
	if int(life["toppled"]) > 0:
		notes.append("Knocked flat by a Beyblade. It gets back up after its next turn.")
	if mood < 45.0:
		notes.append("Gloomy pieces fight worse%s." % (", and their labyrinths are darker" if t != ChessRules.KING else ""))
	for n in notes:
		info.add_child(UI.label(n, 16, UI.EMBER))
	var buffs := Game.buffs_of(pid)
	if not buffs.is_empty():
		var names := []
		for b in buffs:
			names.append(Game.item_name(b))
		info.add_child(UI.label("Blessed by: " + ", ".join(names), 16, UI.GOLD))
	if _is_human(1 - color) and t != ChessRules.KING:
		var e := Game.peek_encounter(t)
		var kind := "a labyrinth to explore" if e["kind"] == "puzzle" else "a duel to the end"
		info.add_child(UI.label("If you capture it: %s - %s." % [Game.encounter_title(e), kind], 16, UI.EMBER))
	elif t == ChessRules.KING and _is_human(1 - color):
		info.add_child(UI.label("Checkmate this king to face it in a final duel.", 16, UI.EMBER))
	m.add_buttons([["Close", m.close]])
	add_child(m)


# --- odd jobs ---------------------------------------------------------------------

func _on_menu_jobs(s: int) -> void:
	_close_menu()
	var code := rules.board[s]
	var t := code & 7
	var mood := Game.mood_of(rules.ids[s])
	var odd := OddJobs.estimate(t, mood, false)
	var really := OddJobs.estimate(t, mood, true)
	var m := Modal.new("Odd Jobs", 500.0)
	m.add_text("Send the %s off to earn money. It can't move while it's away, and sending it uses your turn. Happier pieces earn more." % _title(s), 17, UI.DIM)
	m.add_text("Odd Job: back next turn, pays about $%d-%d." % [odd.x, odd.y])
	var b1 := UI.button("Take an Odd Job", func():
		m.close()
		_send_on_job(s, false))
	m.add(b1)
	m.add_text("Really Odd Job: away for two turns, pays about $%d-%d... usually. Things happen on really odd jobs." % [really.x, really.y])
	var b2 := UI.button("Take a Really Odd Job", func():
		m.close()
		_send_on_job(s, true))
	m.add(b2)
	m.add_buttons([["Never mind", func():
		m.close()
		board.selected = -1]])
	m.closed.connect(func(): board.selected = -1)
	add_child(m)


func _send_on_job(s: int, really: bool) -> void:
	if state != "idle":
		return
	var p := Game.piece(rules.ids[s])
	p["away"] = 2 if really else 1
	p["really"] = really
	p["job"] = OddJobs.pick(really)
	_log("[color=#6fc06a]The %s heads off to %s.[/color]" % [_title(s), p["job"]])
	_pass_after_action()


# --- pink slip races --------------------------------------------------------------

## Enemy pieces that still have a car to bet.
func _race_targets(color: int) -> Dictionary:
	var out := {}
	for s in 64:
		var code := rules.board[s]
		if code == 0 or ChessRules.color_of(code) == color or (code & 7) == ChessRules.KING:
			continue
		if Game.has_car(rules.ids[s]):
			out[s] = true
	return out


func _on_menu_race(s: int) -> void:
	_close_menu()
	var tg := _race_targets(ChessRules.color_of(rules.board[s]))
	if tg.is_empty():
		return
	pick = {"kind": "race", "from": s}
	state = "picking"
	board.selected = s
	board.target_color = PINK
	board.targets = tg
	sub_label.text = "Tap an enemy piece to challenge it to a pink slip race. Tap elsewhere to cancel."


func _on_pick(s: int) -> void:
	var kind: String = pick.get("kind", "")
	var from: int = pick.get("from", -1)
	board.targets = {}
	board.target_color = Color(0.95, 0.25, 0.15)
	pick = {}
	match kind:
		"race":
			_start_race(from, s)
		"sniper":
			_fire_sniper(from, s)
		_:
			_cancel_move()


func _start_race(hs: int, fs: int) -> void:
	state = "encounter"
	board.interactive = false
	var hc := rules.board[hs]
	var fc := rules.board[fs]
	pending = {"kind": "race", "hero_id": rules.ids[hs], "foe_id": rules.ids[fs]}
	_log("The %s challenges the %s to a pink slip race!" % [_title(hs), _title(fs)])
	encounter_requested.emit({
		"kind": "race", "difficulty": Game.difficulty,
		"hero_type": hc & 7, "hero_color": ChessRules.color_of(hc), "hero_id": rules.ids[hs], "hero_mood": Game.mood_of(rules.ids[hs]),
		"foe_type": fc & 7, "foe_color": ChessRules.color_of(fc), "foe_id": rules.ids[fs], "foe_mood": Game.mood_of(rules.ids[fs]),
		"foe_screen_pos": board.get_global_transform() * board.square_center(fs),
	})


func _resolve_race(p: Dictionary, result: String) -> void:
	var won := result == "won"
	var loser_id: int = p["foe_id"] if won else p["hero_id"]
	var winner_id: int = p["hero_id"] if won else p["foe_id"]
	var ls := rules.find_id(loser_id)
	var ws := rules.find_id(winner_id)
	if ls < 0 or ws < 0:
		_start_turn()
		return
	Game.set_car(loser_id, false)
	Game.change_mood(winner_id, 10.0)
	Game.change_mood(loser_id, -12.0)
	_witness(ChessRules.color_of(rules.board[ls]), ls, 5.0)
	if won:
		Game.add_item("used_car")
		_log("[color=#ff73bf]The %s wins the race and the %s's pink slip! The %s can't move without a car. (+1 Used Car)[/color]" % [_title(ws), _title(ls), _title(ls)])
	else:
		_log("[color=#ff73bf]The %s loses the race and signs over its pink slip. It can't move without a car.[/color]" % _title(ls))
	_pass_after_action()


# --- dates ------------------------------------------------------------------------

func _on_menu_date(s: int) -> void:
	_close_menu()
	if state != "idle":
		return
	var code := rules.board[s]
	var color := ChessRules.color_of(code)
	state = "encounter"
	board.interactive = false
	pending = {"kind": "date", "date_id": rules.ids[s]}
	encounter_requested.emit({
		"kind": "date", "own": color == rules.side,
		"date_type": code & 7, "date_color": color, "date_id": rules.ids[s], "date_mood": Game.mood_of(rules.ids[s]),
		"foe_type": code & 7, "foe_color": color,
		"foe_screen_pos": board.get_global_transform() * board.square_center(s),
	})


func _resolve_date(p: Dictionary, result: String) -> void:
	var s := rules.find_id(int(p["date_id"]))
	if result != "done" or s < 0:
		_start_turn()
		return
	var mood := Game.mood_of(int(p["date_id"]))
	_log("[color=#ff73bf]You take the %s on a date. It is now %s.[/color]" % [_title(s), Game.mood_name(mood).to_lower()])
	_pass_after_action()


# --- items --------------------------------------------------------------------------

func _on_menu_use(s: int) -> void:
	_close_menu()
	var pid := rules.ids[s]
	var inv := InventoryPanel.new("board", "Use on the " + _title(s), true)
	inv.item_used.connect(func(id: String): _use_board_item(s, pid, id))
	inv.closed.connect(func(): board.selected = -1)
	add_child(inv)


func _use_board_item(s: int, pid: int, id: String) -> void:
	board.selected = -1
	if rules.ids[s] != pid or state != "idle":
		return
	var name := _title(s)
	match id:
		"whetstone", "ward":
			if Game.remove_item(id):
				Game.add_buff(pid, id)
				_log("The %s is blessed by the %s." % [name, Game.item_name(id)])
		"roses":
			if Game.remove_item(id):
				var m := Game.change_mood(pid, 30.0)
				_log("[color=#ff73bf]You give the %s a bouquet of roses. It is now %s.[/color]" % [name, Game.mood_name(m).to_lower()])
		"used_car":
			if Game.has_car(pid):
				_notice("The %s already has a car." % name)
			elif Game.remove_item(id):
				Game.set_car(pid, true)
				Game.change_mood(pid, 8.0)
				_log("[color=#6fb3d9]The %s gets behind the wheel of a used car. It can move again![/color]" % name)
		"sniper":
			if int(Game.piece(pid)["away"]) > 0:
				_notice("The %s is away on a job." % name)
				return
			var tg := _sniper_targets(s)
			if tg.is_empty():
				_notice("The %s has no clear shot. It needs an enemy (not the king) in a straight, unblocked line - and the shot must not leave your king in check." % name)
				return
			pick = {"kind": "sniper", "from": s}
			state = "picking"
			board.selected = s
			board.target_color = Color(1.0, 0.15, 0.1)
			board.targets = tg
			sub_label.text = "Tap a target in the crosshairs. Tap elsewhere to lower the rifle."


func _notice(text: String) -> void:
	var m := Modal.new("", 420.0)
	m.add_text(text)
	m.add_buttons([["OK", m.close]])
	add_child(m)


## Enemy pieces (not the king) at the end of a clear straight line from s whose
## removal doesn't leave our own king in check.
func _sniper_targets(s: int) -> Dictionary:
	var out := {}
	var color := ChessRules.color_of(rules.board[s])
	for d in ChessRules.DIAG_DIRS + ChessRules.ORTHO_DIRS:
		var f: int = (s & 7) + d.x
		var r: int = (s >> 3) + d.y
		while f >= 0 and f < 8 and r >= 0 and r < 8:
			var t := r * 8 + f
			var code := rules.board[t]
			if code != 0:
				if ChessRules.color_of(code) != color and (code & 7) != ChessRules.KING and _safe_without([t], color):
					out[t] = true
				break
			f += d.x
			r += d.y
	return out


## True if `color`'s king is not in check once the given squares are emptied.
func _safe_without(squares: Array, color: int) -> bool:
	var c := rules.copy()
	for t in squares:
		c.remove_piece(t)
	return not c.in_check(color)


func _fire_sniper(from: int, to: int) -> void:
	if not Game.remove_item("sniper"):
		_cancel_move()
		return
	state = "busy"
	board.interactive = false
	board.selected = from
	var g := _gen
	_log("[color=#e2643a]The %s takes aim at the %s...[/color]" % [_title(from), _title(to)])
	await board.fx.snipe(from, to)
	if not _alive(g):
		return
	_log("[color=#a9a39f]One shot. The %s crumbles into ash. No labyrinth, no duel.[/color]" % _title(to))
	_kill_piece(to)
	await get_tree().create_timer(1.6).timeout
	if _alive(g):
		_pass_after_action()


## Items used from the Inventory on your turn (double move, drive-by).
func _use_turn_item(id: String) -> void:
	if state != "idle" or not _is_human(rules.side):
		return
	match id:
		"double_move":
			if double_move[rules.side]:
				_notice("Your army is already buzzing. One double move at a time.")
				return
			if Game.remove_item(id):
				double_move[rules.side] = true
				_log("[color=#e0aa4a]Your whole army downs a double espresso. You move twice this turn![/color]")
				_refresh_hud()
		"driveby":
			_ask_drive_by()


## Up to three enemy pieces (never the king) in the two ranks nearest an edge.
func _drive_by_targets(along_top: bool) -> Array:
	var color := rules.side
	var cands: Array = []
	for s in 64:
		var code := rules.board[s]
		var r := s >> 3
		if code == 0 or ChessRules.color_of(code) == color or (code & 7) == ChessRules.KING:
			continue
		if (along_top and r >= 6) or (not along_top and r <= 1):
			cands.append(s)
	cands.shuffle()
	var chosen: Array = []
	for s in cands:
		if chosen.size() >= 3:
			break
		if _safe_without(chosen + [s], color):
			chosen.append(s)
	if not chosen.is_empty() and not _safe_without(chosen, color):
		return []
	if chosen.is_empty() and rules.in_check(color):
		return []
	return chosen


func _ask_drive_by() -> void:
	var m := Modal.new("Drive-By Hotline", 460.0)
	m.add_text("\"Yo. Which side of the board you want us to roll up on?\"")
	m.add_text("They hit up to three enemy pieces (never the king) in the two ranks along that edge. It uses your turn.", 16, UI.DIM)
	var top := _drive_by_targets(true)
	var bottom := _drive_by_targets(false)
	var checked := rules.in_check(rules.side)
	var vb := VBoxContainer.new()
	m.add(vb)
	var b1 := UI.button("Along the top edge (ranks 7-8)", func():
		m.close()
		_drive_by(true, top))
	b1.disabled = checked and top.is_empty()
	vb.add_child(b1)
	var b2 := UI.button("Along the bottom edge (ranks 1-2)", func():
		m.close()
		_drive_by(false, bottom))
	b2.disabled = checked and bottom.is_empty()
	vb.add_child(b2)
	if checked:
		m.add_text("You're in check: they'll only come if they can get you out of it.", 15, UI.EMBER)
	m.add_buttons([["Hang up", m.close]])
	add_child(m)


func _drive_by(along_top: bool, targets: Array) -> void:
	if state != "idle" or not Game.remove_item("driveby"):
		return
	state = "busy"
	board.interactive = false
	var g := _gen
	_log("[color=#ff73bf]You make a call. Somewhere nearby, hydraulics hiss...[/color]")
	await board.fx.drive_by(along_top, targets, func(s: int):
		_log("[color=#a9a39f]The %s is taken out by the neighbours.[/color]" % _title(s))
		_kill_piece(s))
	if not _alive(g):
		return
	if targets.is_empty():
		_log("They cruise past, wave, and leave. Nothing to hit on that side.")
	await get_tree().create_timer(1.2).timeout
	if _alive(g):
		_pass_after_action()


# --- moving and capturing ------------------------------------------------------------

func _choose_target(to: int) -> void:
	var from := board.selected
	var options: Array = []
	for m in _moves_from(from):
		if m["to"] == to:
			options.append(m)
	if options.is_empty():
		_cancel_move()
		return
	if options.size() > 1:
		_ask_promotion(options)
		return
	_execute_human(options[0])


func _ask_promotion(options: Array) -> void:
	var color := rules.side
	var m := Modal.new("Promote your pawn", 520.0)
	m.sticky = true
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add(row)
	for opt in options:
		var t: int = opt["promo"]
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 150)
		b.focus_mode = Control.FOCUS_NONE
		b.draw.connect(func():
			PieceArt.draw_piece(b, t, color == 0, b.size.x * 0.5, b.size.y - 30, 76.0)
			b.draw_string(ThemeDB.fallback_font, Vector2(8, b.size.y - 8), Game.PIECE_NAMES[t], HORIZONTAL_ALIGNMENT_CENTER, b.size.x - 16, 16, UI.TEXT))
		b.pressed.connect(func():
			m.close()
			_execute_human(opt))
		row.add_child(b)
	m.add_buttons([["Cancel", func():
		m.close()
		_cancel_move()]])
	add_child(m)


func _execute_human(m: Dictionary) -> void:
	state = "busy"
	board.interactive = false
	board.targets = {}
	move_targets = {}
	var mover := rules.side
	var cap := rules.capture_square(m)
	if cap < 0:
		board.selected = -1
		var g := _gen
		await _play_move(m, true)
		if _alive(g):
			_turn_done(mover)
		return
	# Capture: the attacker lunges, then the world shifts into the captured piece.
	var from: int = m["from"]
	var hero_code := rules.board[from]
	var foe_code := rules.board[cap]
	var e := Game.encounter_for(foe_code & 7)
	board.selected = -1
	pending = {"kind": e["kind"], "move": m, "cap": cap, "foe_code": foe_code, "foe_id": rules.ids[cap], "hero_id": rules.ids[from]}
	var tw := board.slide(rules.ids[from], from, m["to"], 0.0, 0.5, 0.4)
	await tw.finished
	_log("%s strikes the %s..." % [Game.piece_title(hero_code & 7, ChessRules.color_of(hero_code)), Game.piece_title(foe_code & 7, ChessRules.color_of(foe_code))])
	state = "encounter"
	status_label.text = "Entering " + Game.encounter_title(e)
	encounter_requested.emit({
		"kind": e["kind"], "lab": e["lab"],
		"hero_type": hero_code & 7, "hero_color": ChessRules.color_of(hero_code), "hero_id": rules.ids[from], "hero_mood": Game.mood_of(rules.ids[from]),
		"foe_type": foe_code & 7, "foe_color": ChessRules.color_of(foe_code), "foe_id": rules.ids[cap], "foe_mood": Game.mood_of(rules.ids[cap]),
		"foe_screen_pos": board.get_global_transform() * board.square_center(cap),
	})


## Called by Main when an encounter ends. result: "won"/"retreat" for captures,
## "won"/"lost" for races and card duels, "done"/"cancel" for dates.
func resolve_encounter(result: String) -> void:
	var p := pending
	pending = {}
	if p.is_empty():
		_start_turn()
		return
	match String(p["kind"]):
		"final":
			await get_tree().create_timer(0.5).timeout
			board.check_sq = -1
			var fx := board.disintegrate(p["foe_sq"], 2.6)
			_on_piece_fallen(rules.board[p["foe_sq"]], rules.ids[p["foe_sq"]], p["foe_sq"])
			Game.add_item("ash")
			await fx.finished
			_show_end("Victory", "The enemy king crumbles into ash. The board is yours.")
			return
		"race":
			_resolve_race(p, result)
			return
		"date":
			_resolve_date(p, result)
			return
		"cards":
			_resolve_cards(p, result)
			return
	var m: Dictionary = p["move"]
	var from: int = m["from"]
	var pid := rules.ids[from]
	var mover := rules.side
	if result == "retreat":
		var back := board.slide(pid, from, m["to"], 0.5, 0.0, 0.35)
		await back.finished
		board.clear_offset(pid)
		_log("You retreat. The capture is called off.")
		_start_turn()
		return
	var g := _gen
	await get_tree().create_timer(0.45).timeout
	if not _alive(g):
		return
	var cap: int = p["cap"]
	var foe_t: int = p["foe_code"] & 7
	_on_piece_fallen(p["foe_code"], int(p["foe_id"]), cap)
	board.disintegrate(cap, 2.6)
	Game.add_item("ash")
	Game.stats["captures"] += 1
	var bounty: int = 2 + Game.PIECE_VALUES[foe_t] * 2
	Game.add_money(bounty)
	Game.change_mood(pid, 6.0)
	_log("[color=#a9a39f]The %s crumbles into ash. (+1 Pinch of Ash, +$%d sifted from the ashes)[/color]" % [Game.piece_title(foe_t, ChessRules.color_of(p["foe_code"])), bounty])
	await get_tree().create_timer(2.3).timeout
	if not _alive(g):
		return
	await _play_move(m, true, 0.5)
	if _alive(g):
		_turn_done(mover)


# --- graveyard --------------------------------------------------------------------

func _show_graveyard() -> void:
	if state == "encounter":
		return
	var color := _human_side()
	var why := ""
	if not (_is_human(rules.side) and state == "idle"):
		why = "Wait for your turn to duel."
	elif rules.in_check(rules.side):
		why = "You're in check - deal with that first."
	var allowed := why == ""
	var gp := GraveyardPanel.new(color, allowed, why)
	gp.duel_requested.connect(_on_grave_duel)
	add_child(gp)


func _on_grave_duel(index: int) -> void:
	if state != "idle":
		return
	var color := rules.side
	var entry: Dictionary = Game.graveyard[color][index]
	var t: int = entry["type"]
	if _revive_square(color, t) < 0:
		_notice("There's no room on your side of the board for the %s right now." % Game.PIECE_NAMES[t])
		return
	state = "encounter"
	board.interactive = false
	pending = {"kind": "cards", "index": index, "color": color}
	_log("You challenge Yugi Moto to a children's card game for your %s." % Game.PIECE_NAMES[t])
	encounter_requested.emit({
		"kind": "cards", "player_color": color, "wager_type": t, "difficulty": Game.difficulty,
		"foe_type": t, "foe_color": color,
		"foe_screen_pos": board.get_global_transform() * (board.origin + Vector2(board.sq * 4.0, board.sq * 4.0)),
	})


func _resolve_cards(p: Dictionary, result: String) -> void:
	var color: int = p["color"]
	var index: int = p["index"]
	var graves: Array = Game.graveyard[color]
	if result != "won" or index >= graves.size():
		var fee := mini(5, int(Game.wallets[color]))
		if fee > 0:
			Game.add_money(-fee, color)
		_log("[color=#a9a39f]Yugi wins the duel%s. Your piece stays in the ground.[/color]" % (" and keeps $%d for his booster fund" % fee if fee > 0 else ""))
		_pass_after_action()
		return
	var entry: Dictionary = graves[index]
	var t: int = entry["type"]
	var s := _revive_square(color, t)
	if s < 0:
		_log("Yugi hands back your %s, but there is no room for it. It waits in the graveyard." % Game.PIECE_NAMES[t])
		_pass_after_action()
		return
	graves.remove_at(index)
	var pid := Game.new_piece_id()
	rules.place_piece(s, t | (ChessRules.BLACK_BIT if color == ChessRules.BLACK else 0), pid)
	Game.set_mood(pid, 64.0)
	board.alpha_of[pid] = 0.0
	var tw := create_tween()
	tw.tween_method(func(a: float): board.alpha_of[pid] = a, 0.0, 1.0, 1.2)
	tw.tween_callback(func(): board.alpha_of.erase(pid))
	board.fx.burst(board.square_center(s), UI.GOLD, 40, board.sq * 2.5)
	_log("[color=#e0aa4a]You win! Your %s rises from the graveyard on %s.[/color]" % [Game.PIECE_NAMES[t], ChessRules.square_name(s)])
	_refresh_hud()
	var g := _gen
	await get_tree().create_timer(1.3).timeout
	if _alive(g):
		_pass_after_action()


## Where a revived piece of type t may stand: its home squares first, then the
## nearest empty square on its own side. It must not give check on arrival.
func _revive_square(color: int, t: int) -> int:
	var homes := {1: [8, 9, 10, 11, 12, 13, 14, 15], 2: [1, 6], 3: [2, 5], 4: [0, 7], 5: [3], 6: [4]}
	var order: Array = []
	for s in homes.get(t, []):
		order.append(s)
	for r in [0, 1, 2, 3]:
		for f in [3, 4, 2, 5, 1, 6, 0, 7]:
			order.append(r * 8 + f)
	var code := t | (ChessRules.BLACK_BIT if color == ChessRules.BLACK else 0)
	for s0 in order:
		var s: int = s0 if color == ChessRules.WHITE else (s0 ^ 56)
		var r: int = s >> 3
		if rules.board[s] != 0:
			continue
		if t == ChessRules.PAWN and (r == 0 or r == 7):
			continue
		var c := rules.copy()
		c.place_piece(s, code, 999)
		if c.in_check(1 - color):
			continue
		return s
	return -1


# --- the Beyblade crash ---------------------------------------------------------------

func _on_beyblade_snapped(_from: Vector2) -> void:
	# crash right away if nothing is moving; otherwise at the start of the next turn
	if is_visible_in_tree() and (state == "idle" or state == "moving" or state == "picking"):
		_cancel_move()
		_crash_beyblade()


## The snapped-off Beyblade lands on the board and caroms around, knocking
## pieces onto neighbouring squares or flat on their backs.
func _crash_beyblade() -> void:
	if not Music.pending_crash:
		return
	Music.pending_crash = false
	_close_menu()
	state = "crash"
	board.interactive = false
	board.selected = -1
	board.targets = {}
	var g := _gen
	var from_global := Music.crash_from
	if from_global == Vector2.ZERO:
		from_global = get_global_transform() * Vector2(size.x * 0.5, 0)
	var start := board.get_global_transform().affine_inverse() * from_global
	_log("[color=#e2643a]You pulled too hard! The Beyblade snaps off and crashes onto the board![/color]")
	var hits := await board.fx.beyblade_crash(start, func(s: int, dir: Vector2i): _knock(s, dir))
	if not _alive(g):
		return
	if hits == 0:
		_log("It skids across the board without touching a single piece.")
	if Game.has_item("beyblade") and Game.remove_item("beyblade"):
		Music.repair()
		_log("[color=#6fb3d9]You snap your Spare Beyblade onto the launcher.[/color]")
	else:
		_log("[color=#a9a39f]The volume control is gone. The shop sells Spare Beyblades.[/color]")
	_start_turn()


## A Beyblade hit on square s while travelling in direction dir: the piece
## either skids onto the next square (if that's safe) or falls flat.
func _knock(s: int, dir: Vector2i) -> void:
	var code := rules.board[s]
	if code == 0:
		return
	var pid := rules.ids[s]
	var t := code & 7
	var f := (s & 7) + dir.x
	var r := (s >> 3) + dir.y
	var moved := false
	if t != ChessRules.KING and f >= 0 and f < 8 and r >= 0 and r < 8:
		var to := r * 8 + f
		var pawn_ok := t != ChessRules.PAWN or (r != 0 and r != 7)
		if rules.board[to] == 0 and pawn_ok:
			var c := rules.copy()
			c.relocate(s, to)
			if not c.in_check(0) and not c.in_check(1):
				rules.relocate(s, to)
				var delta := board.piece_base(s) - board.piece_base(to)
				board.offsets[pid] = delta
				var tw := create_tween()
				tw.tween_method(func(k: float): board.offsets[pid] = delta * (1.0 - k), 0.0, 1.0, 0.22)
				tw.tween_callback(func(): board.offsets.erase(pid))
				_log("[color=#a9a39f]The %s is knocked to %s![/color]" % [Game.piece_title(t, ChessRules.color_of(code)), ChessRules.square_name(to)])
				moved = true
	if not moved:
		Game.piece(pid)["toppled"] = 1
		_log("[color=#a9a39f]The %s is knocked flat and loses its next turn![/color]" % Game.piece_title(t, ChessRules.color_of(code)))
	Game.change_mood(pid, -8.0)


# --- panels -------------------------------------------------------------------

func _show_inventory() -> void:
	if state == "encounter":
		return
	var ctx := "turn" if state == "idle" and _is_human(rules.side) else "view"
	var inv := InventoryPanel.new(ctx, "Inventory")
	inv.item_used.connect(_use_turn_item)
	add_child(inv)


func _show_shop() -> void:
	if state == "encounter":
		return
	var shop := ShopPanel.new()
	shop.bought.connect(func(id: String, note: String):
		_log("[color=#6fc06a]Bought: %s.%s[/color]" % [Game.item_name(id), " " + note if note != "" else ""]))
	add_child(shop)


func _show_menu() -> void:
	if state == "encounter":
		return
	var m := Modal.new("Menu", 420.0)
	var vb := VBoxContainer.new()
	m.add(vb)
	vb.add_child(UI.button("Resume", m.close))
	vb.add_child(UI.button("How to Play", func():
		m.close()
		Help.show(self)))
	vb.add_child(UI.button("Restart Game", func():
		m.close()
		_confirm("Restart and lose this game?", func():
			Game.new_game()
			new_game())))
	vb.add_child(UI.button("Main Menu", func():
		m.close()
		_confirm("Leave this game?", func(): quit_to_title.emit())))
	add_child(m)


func _confirm(text: String, yes: Callable) -> void:
	var m := Modal.new("Are you sure?", 420.0)
	m.add_text(text)
	m.add_buttons([["Yes", func():
		m.close()
		yes.call()], ["No", m.close]])
	add_child(m)


func _show_end(title: String, text: String) -> void:
	var m := Modal.new(title, 480.0)
	m.sticky = true
	m.add_text(text)
	m.add_text("Pieces you descended into: %d   Labyrinths solved: %d   Duels won: %d   Money earned: $%d" % [Game.stats["captures"], Game.stats["puzzles"], Game.stats["fights"], int(Game.stats.get("earned", 0))], 16, UI.DIM)
	m.add_buttons([["New Game", func():
		m.close()
		Game.new_game()
		new_game()], ["Main Menu", func():
		m.close()
		quit_to_title.emit()]])
	add_child(m)


func _draw_tray() -> void:
	var font := ThemeDB.fallback_font
	var w := tray.size.x
	var s := clampf(w / 20.0, 14.0, 24.0)
	tray.draw_string(font, Vector2(0, 15), "Graveyard", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.DIM)
	tray.draw_string(font, Vector2(0, 15), "Ash in satchel: %d" % Game.count("ash"), HORIZONTAL_ALIGNMENT_RIGHT, w, 15, UI.DIM)
	for row in 2:
		# row 0: black pieces that fell, row 1: white pieces
		var color := 1 - row
		var list: Array = []
		for e in Game.graveyard[color]:
			list.append(int(e["type"]))
		list.sort()
		list.reverse()
		var y := 20.0 + (row + 1) * s * 1.42
		for i in list.size():
			var x := s * 0.5 + i * s * 0.62
			if x > w - s * 0.3:
				break
			PieceArt.draw_piece(tray, list[i], color == 0, x, y, s, Color(1, 1, 1, 0.75), false)
