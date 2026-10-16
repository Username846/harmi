class_name ChessScreen
extends Control
## The chessboard: turn flow, AI, action menu, inventory, and the hand-off to
## encounters whenever a human player captures.

signal encounter_requested(info: Dictionary)
signal quit_to_title

var rules := ChessRules.new()
var ai := ChessAI.new()
var board: BoardView
var side_panel: PanelContainer
var status_label: Label
var sub_label: Label
var log_box: RichTextLabel
var tray: Control
var inv_btn: Button
var overlay_layer: Control

var state := "idle" # idle, moving, busy, encounter, over
var move_targets: Dictionary = {}
var pending: Dictionary = {}
var fallen := [[], []] # piece types lost by White / Black
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
	status_label = UI.label("", 26, UI.GOLD)
	vb.add_child(status_label)
	sub_label = UI.label("", 17, UI.DIM)
	vb.add_child(sub_label)
	var row := HBoxContainer.new()
	vb.add_child(row)
	inv_btn = UI.button("Inventory", _show_inventory)
	inv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(inv_btn)
	var menu_btn := UI.button("Menu", _show_menu)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(menu_btn)
	tray = Control.new()
	tray.custom_minimum_size = Vector2(0, 92)
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

	Game.inventory_changed.connect(_update_inv_btn)
	resized.connect(_on_resized)
	side_panel.minimum_size_changed.connect(_queue_relayout)
	_update_inv_btn()
	new_game()


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
	board.last_from = -1
	board.last_to = -1
	board.selected = -1
	board.targets = {}
	fallen = [[], []]
	pending = {}
	log_box.clear()
	_log("[color=#e0aa4a]A new game begins.[/color] Tap one of your pieces to act.")
	if Game.vs_ai:
		_log("You command White. The machine commands Black.")
	_relayout()
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
	else:
		var bh := minf(BoardView.needed_height(w - m * 2.0), h * 0.64)
		board.position = Vector2(m, m)
		board.size = Vector2(w - m * 2.0, bh)
		side_panel.position = Vector2(m, bh + m * 2.0)
		side_panel.size = Vector2(w - m * 2.0, h - bh - m * 3.0)


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


func _log(text: String) -> void:
	log_box.append_text(text + "\n")


func _update_inv_btn() -> void:
	if inv_btn:
		inv_btn.text = "Inventory (%d)" % Game.item_ids().size()
	if tray:
		tray.queue_redraw()


# --- turn flow ----------------------------------------------------------------

func _start_turn() -> void:
	board.selected = -1
	board.targets = {}
	move_targets = {}
	board.check_sq = rules.king_square(rules.side) if rules.in_check(rules.side) else -1
	if _check_game_end():
		return
	var who := Game.color_name(rules.side)
	if _is_human(rules.side):
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
		if not _alive(g):
			return
		await get_tree().process_frame
		if not _alive(g):
			return
		var m := ai.choose_move(rules, Game.difficulty)
		if m.is_empty():
			return
		await _play_move(m, false)
		if _alive(g):
			_start_turn()


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
	_add_fallen(rules.board[ks])
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
	var hero_sq := board.last_to if board.last_to >= 0 else rules.king_square(winner)
	var ks := rules.king_square(loser)
	pending = {"kind": "final", "foe_sq": ks}
	state = "encounter"
	encounter_requested.emit({
		"kind": "final", "lab": "",
		"hero_type": rules.board[hero_sq] & 7, "hero_color": winner, "hero_id": rules.ids[hero_sq],
		"foe_type": ChessRules.KING, "foe_color": loser, "foe_id": rules.ids[ks],
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
		_add_fallen(rules.board[cap])
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


func _add_fallen(code: int) -> void:
	fallen[(code >> 3) & 1].append(code & 7)
	tray.queue_redraw()


# --- input --------------------------------------------------------------------

func _on_board_tapped(sq_plain: int, sq_piece: int) -> void:
	if state == "moving":
		if move_targets.has(sq_plain):
			_choose_target(sq_plain)
			return
		if sq_piece >= 0 and move_targets.has(sq_piece):
			_choose_target(sq_piece)
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
	move_targets = {}
	sub_label.text = "Tap a piece to open its action menu."


func _open_menu(s: int) -> void:
	_close_menu()
	board.selected = s
	var code := rules.board[s]
	var color := ChessRules.color_of(code)
	var mine := color == rules.side and _is_human(color)
	var moves := rules.legal_moves_from(s) if mine else []

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.gui_input.connect(_on_menu_layer_input)
	overlay_layer.add_child(layer)
	_menu = layer
	var panel := PanelContainer.new()
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var title := UI.label(Game.piece_title(code & 7, color), 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(title)
	if mine:
		var mv := UI.button("Move" if not moves.is_empty() else "Move (blocked)", _on_menu_move.bind(s))
		mv.disabled = moves.is_empty()
		vb.add_child(mv)
	vb.add_child(UI.button("Inspect", _on_menu_inspect.bind(s)))
	if mine:
		var usable := Game.items_usable_in("board")
		var ub := UI.button("Use Item" if not usable.is_empty() else "Use Item (none)", _on_menu_use.bind(s))
		ub.disabled = usable.is_empty()
		vb.add_child(ub)
	vb.add_child(UI.button("Cancel", _on_menu_cancel))
	panel.custom_minimum_size = Vector2(210, 0)
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
	for m in rules.legal_moves_from(s):
		move_targets[m["to"]] = true
		tg[m["to"]] = rules.capture_square(m) >= 0
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
	var m := Modal.new(Game.piece_title(t, color), 560.0)
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
	var lbl := UI.label(BattleData.MOVES_DESC[t], 18)
	info.add_child(lbl)
	var st: Dictionary = BattleData.STATS[t]
	info.add_child(UI.label("Duel stats  HP %d  MP %d  ATK %d  DEF %d  MAG %d" % [st["hp"], st["mp"], st["atk"], st["def"], st["mag"]], 16, UI.DIM))
	var buffs := Game.buffs_of(pid)
	if not buffs.is_empty():
		var names := []
		for b in buffs:
			names.append(Game.item_name(b))
		info.add_child(UI.label("Blessed by: " + ", ".join(names), 17, UI.GOLD))
	if _is_human(1 - color) and t != ChessRules.KING:
		var e := Game.peek_encounter(t)
		var kind := "a labyrinth to explore" if e["kind"] == "puzzle" else "a duel to the end"
		info.add_child(UI.label("If you capture it: %s - %s." % [Game.encounter_title(e), kind], 17, UI.EMBER))
	elif t == ChessRules.KING and _is_human(1 - color):
		info.add_child(UI.label("Checkmate this king to face it in a final duel.", 17, UI.EMBER))
	m.add_buttons([["Close", m.close]])
	add_child(m)


func _on_menu_use(s: int) -> void:
	_close_menu()
	var pid := rules.ids[s]
	var code := rules.board[s]
	var inv := InventoryPanel.new("board", "Use on " + Game.piece_title(code & 7, ChessRules.color_of(code)), true)
	inv.item_used.connect(func(id: String):
		if Game.remove_item(id):
			Game.add_buff(pid, id)
			_log("%s is blessed by the %s." % [Game.piece_title(code & 7, ChessRules.color_of(code)), Game.item_name(id)])
		board.selected = -1)
	inv.closed.connect(func(): board.selected = -1)
	add_child(inv)


func _choose_target(to: int) -> void:
	var from := board.selected
	var options: Array = []
	for m in rules.legal_moves_from(from):
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
	var cap := rules.capture_square(m)
	if cap < 0:
		board.selected = -1
		await _play_move(m, true)
		_start_turn()
		return
	# Capture: the attacker lunges, then the world shifts into the captured piece.
	var from: int = m["from"]
	var hero_code := rules.board[from]
	var foe_code := rules.board[cap]
	var e := Game.encounter_for(foe_code & 7)
	board.selected = -1
	pending = {"kind": e["kind"], "move": m, "cap": cap, "foe_code": foe_code}
	var tw := board.slide(rules.ids[from], from, m["to"], 0.0, 0.5, 0.4)
	await tw.finished
	_log("%s strikes the %s..." % [Game.piece_title(hero_code & 7, ChessRules.color_of(hero_code)), Game.piece_title(foe_code & 7, ChessRules.color_of(foe_code))])
	state = "encounter"
	status_label.text = "Entering " + Game.encounter_title(e)
	encounter_requested.emit({
		"kind": e["kind"], "lab": e["lab"],
		"hero_type": hero_code & 7, "hero_color": ChessRules.color_of(hero_code), "hero_id": rules.ids[from],
		"foe_type": foe_code & 7, "foe_color": ChessRules.color_of(foe_code), "foe_id": rules.ids[cap],
		"foe_screen_pos": board.get_global_transform() * board.square_center(cap),
	})


## Called by Main when the encounter ends. result: "won" or "retreat".
func resolve_encounter(result: String) -> void:
	var p := pending
	pending = {}
	if p.is_empty():
		_start_turn()
		return
	if p["kind"] == "final":
		await get_tree().create_timer(0.5).timeout
		board.check_sq = -1
		var fx := board.disintegrate(p["foe_sq"], 2.6)
		_add_fallen(rules.board[p["foe_sq"]])
		Game.add_item("ash")
		await fx.finished
		_show_end("Victory", "The enemy king crumbles into ash. The board is yours.")
		return
	var m: Dictionary = p["move"]
	var from: int = m["from"]
	var pid := rules.ids[from]
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
	_add_fallen(p["foe_code"])
	board.disintegrate(cap, 2.6)
	Game.add_item("ash")
	Game.stats["captures"] += 1
	_log("[color=#a9a39f]The %s crumbles into ash. (+1 Pinch of Ash)[/color]" % Game.piece_title(p["foe_code"] & 7, ChessRules.color_of(p["foe_code"])))
	await get_tree().create_timer(2.3).timeout
	if not _alive(g):
		return
	await _play_move(m, true, 0.5)
	if _alive(g):
		_start_turn()


# --- panels -------------------------------------------------------------------

func _show_inventory() -> void:
	if state == "encounter":
		return
	add_child(InventoryPanel.new("view", "Inventory"))


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
	m.add_text("Pieces you descended into: %d   Labyrinths solved: %d   Duels won: %d" % [Game.stats["captures"], Game.stats["puzzles"], Game.stats["fights"]], 16, UI.DIM)
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
	var s := clampf(w / 20.0, 14.0, 26.0)
	tray.draw_string(font, Vector2(0, 16), "Turned to ash", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.DIM)
	var ash_n := Game.count("ash")
	tray.draw_string(font, Vector2(0, 16), "Ash in satchel: %d" % ash_n, HORIZONTAL_ALIGNMENT_RIGHT, w, 15, UI.DIM)
	for row in 2:
		# row 0: black pieces you took, row 1: your fallen white pieces
		var color := 1 - row
		var list: Array = fallen[color].duplicate()
		list.sort()
		list.reverse()
		var y := 24.0 + (row + 1) * s * 1.45
		for i in list.size():
			var x := s * 0.5 + i * s * 0.62
			if x > w - s * 0.3:
				break
			PieceArt.draw_piece(tray, list[i], color == 0, x, y, s, Color(1, 1, 1, 0.75), false)
