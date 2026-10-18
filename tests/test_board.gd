extends Node
## Board-action checks that need the Game and Music autoloads.
## Run: godot --headless --path . res://tests/board.tscn

var ok := true


func _check(cond: bool, what: String) -> void:
	if not cond:
		ok = false
		print("FAIL ", what)


func _ready() -> void:
	Game.vs_ai = false
	Game.new_game()
	var cs := ChessScreen.new()
	add_child(cs)
	var r := cs.rules
	# the hidden bomb sits on an empty middle square and stays quiet for the other checks
	if ResourceLoader.exists("res://scripts/survival/survival_screen.gd"):
		_check(cs.bomb_sq >= 16 and cs.bomb_sq < 48 and r.board[cs.bomb_sq] == 0, "bomb hidden on an empty middle square")
	cs.bomb_sq = -1
	# revival: home square first, never giving check, pawns never on the back rank
	r.remove_piece(ChessRules.square_from_name("e2"))
	_check(cs._revive_square(ChessRules.WHITE, ChessRules.PAWN) == ChessRules.square_from_name("e2"), "pawn revives on its home square")
	_check(cs._revive_square(ChessRules.WHITE, ChessRules.KNIGHT) == ChessRules.square_from_name("e2"), "knight revives on the nearest empty square")
	r.load_fen("4k3/8/8/8/8/8/8/4K3 w - -")
	var q := cs._revive_square(ChessRules.WHITE, ChessRules.QUEEN)
	_check(q == ChessRules.square_from_name("d1"), "queen revives on d1, got %s" % ChessRules.square_name(q))
	r.load_fen("3k4/8/8/8/8/8/8/4K3 w - -")
	q = cs._revive_square(ChessRules.WHITE, ChessRules.QUEEN)
	var c := r.copy()
	c.place_piece(q, ChessRules.QUEEN, 900)
	_check(q >= 0 and not c.in_check(ChessRules.BLACK), "revived queen must not give check")
	# drive-by: up to three enemy pieces in the two ranks along the edge, never the king
	r.setup_start()
	var tg := cs._drive_by_targets(true)
	_check(tg.size() == 3, "drive-by hits three pieces")
	for s in tg:
		_check((s >> 3) >= 6 and (r.board[s] & 7) != ChessRules.KING and ChessRules.color_of(r.board[s]) == ChessRules.BLACK, "drive-by target %s" % ChessRules.square_name(s))
	_check(cs._drive_by_targets(false).is_empty(), "nothing of Black's along the bottom edge")
	# sniper: clear straight lines only, never the king, never exposing your own king
	var snipe := cs._sniper_targets(ChessRules.square_from_name("e2"))
	_check(snipe.size() == 1 and snipe.has(ChessRules.square_from_name("e7")), "e2 pawn can only snipe e7")
	r.load_fen("4k3/8/8/8/4q3/8/4R3/4K3 w - -")
	snipe = cs._sniper_targets(ChessRules.square_from_name("e2"))
	_check(snipe.has(ChessRules.square_from_name("e4")), "rook may snipe the queen it shields against")
	r.load_fen("4k3/4r3/8/8/4b3/8/8/4K3 w - -")
	r.place_piece(ChessRules.square_from_name("a4"), ChessRules.ROOK, 500)
	snipe = cs._sniper_targets(ChessRules.square_from_name("a4"))
	_check(not snipe.has(ChessRules.square_from_name("e4")), "sniping a blocker that exposes your king is not allowed")
	# immobile pieces keep still unless nothing else can move
	r.load_fen("4k3/8/8/8/8/8/3P4/R3K3 w - -")
	Game.piece(r.ids[ChessRules.square_from_name("a1")])["car"] = false
	Game.piece(r.ids[ChessRules.square_from_name("e1")])["toppled"] = 1
	for m in cs._usable_moves():
		_check(m["from"] == ChessRules.square_from_name("d2"), "only the d2 pawn may move")
	Game.piece(r.ids[ChessRules.square_from_name("d2")])["away"] = 1
	_check(not cs._usable_moves().is_empty(), "everyone pitches in when nothing else can move")
	# a Beyblade knock shoves a piece onto an empty square, or knocks it flat
	r.load_fen("4k3/8/8/8/8/2N5/8/4K3 w - -")
	var kid := r.ids[ChessRules.square_from_name("c3")]
	cs._knock(ChessRules.square_from_name("c3"), Vector2i(1, 0))
	_check(r.find_id(kid) == ChessRules.square_from_name("d3"), "knight knocked to d3")
	cs._knock(ChessRules.square_from_name("e1"), Vector2i(0, 1))
	_check(r.king_square(ChessRules.WHITE) == ChessRules.square_from_name("e1") and int(Game.piece(r.ids[4])["toppled"]) == 1, "kings fall over instead of sliding")
	# witnesses: comrades nearby take a fall harder
	r.setup_start()
	var near := r.ids[ChessRules.square_from_name("e2")]
	var far := r.ids[ChessRules.square_from_name("a1")]
	var before_near := Game.mood_of(near)
	var before_far := Game.mood_of(far)
	cs._witness(ChessRules.WHITE, ChessRules.square_from_name("e1"), 6.0)
	_check(Game.mood_of(near) < Game.mood_of(far) and Game.mood_of(far) < before_far and before_near == before_far, "witness moods")
	# race results: the loser loses its car, the winner's side gets the pink slip, the turn passes
	r.setup_start()
	cs.state = "encounter"
	var hero := r.ids[ChessRules.square_from_name("e2")]
	var foe := r.ids[ChessRules.square_from_name("e7")]
	Game.set_car(hero, true)
	Game.set_car(foe, true)
	Game.active_side = ChessRules.WHITE
	var cars := Game.count("used_car")
	cs.pending = {"kind": "race", "hero_id": hero, "foe_id": foe}
	cs.resolve_encounter("won")
	_check(not Game.has_car(foe) and Game.has_car(hero), "race won: the foe loses its car")
	_check(int(Game._invs[ChessRules.WHITE].get("used_car", 0)) == cars + 1, "race won: the pink slip becomes a Used Car in White's satchel")
	_check(r.side == ChessRules.BLACK, "the race used White's turn")
	r.setup_start()
	cs.state = "encounter"
	cs.pending = {"kind": "race", "hero_id": hero, "foe_id": foe}
	Game.set_car(foe, true)
	cs.resolve_encounter("lost")
	_check(not Game.has_car(hero) and Game.has_car(foe), "race lost: your piece loses its car")
	r.setup_start()
	_check(cs._moves_from(ChessRules.square_from_name("e2")).is_empty(), "a carless pawn can't move")
	# a cancelled date keeps the turn, a finished one passes it
	r.setup_start()
	cs.state = "encounter"
	cs.pending = {"kind": "date", "date_id": hero}
	cs.resolve_encounter("cancel")
	_check(r.side == ChessRules.WHITE, "cancelled date keeps the turn")
	cs.state = "encounter"
	cs.pending = {"kind": "date", "date_id": hero}
	cs.resolve_encounter("done")
	_check(r.side == ChessRules.BLACK, "a date uses the turn")
	# a won card duel brings the piece back from the graveyard
	r.setup_start()
	var kn := ChessRules.square_from_name("b1")
	Game.graveyard[ChessRules.WHITE].clear()
	Game.bury(ChessRules.WHITE, ChessRules.KNIGHT, r.ids[kn])
	r.remove_piece(kn)
	cs.state = "encounter"
	cs.pending = {"kind": "cards", "index": 0, "color": ChessRules.WHITE}
	cs.resolve_encounter("won")
	_check(r.board[kn] == ChessRules.KNIGHT and Game.graveyard[ChessRules.WHITE].is_empty(), "won card duel revives the knight on b1")
	# odd jobs pay something and finish
	for i in 50:
		var o := OddJobs.outcome(ChessRules.KNIGHT, 50.0, i % 2 == 0)
		_check(int(o["pay"]) >= 0 and float(o["mood"]) > -30.0, "job outcome sane")
	await get_tree().create_timer(1.6).timeout
	_check(r.side == ChessRules.BLACK, "the card duel used White's turn")
	# stepping on the bomb ends the chess game
	var boom := {}
	cs.nuked.connect(func(info: Dictionary): boom.merge(info))
	r.setup_start()
	cs.state = "idle"
	cs.bomb_sq = ChessRules.square_from_name("e4")
	cs._turn_done(ChessRules.WHITE)
	_check(boom.is_empty() and cs.state != "nuked", "nothing happens while the square is empty")
	for m in r.legal_moves():
		if m["from"] == ChessRules.square_from_name("e2") and m["to"] == ChessRules.square_from_name("e4"):
			r.play(m)
	cs._turn_done(ChessRules.WHITE)
	_check(cs.state == "nuked", "a piece on the bomb square sets it off")
	await get_tree().create_timer(2.3).timeout
	_check(String(boom.get("square", "")) == "e4" and String(boom.get("piece", "")) == "White Pawn", "nuked signal names the square and piece: %s" % str(boom))
	print("BOARD TESTS PASSED" if ok else "BOARD TESTS FAILED")
	get_tree().quit(0 if ok else 1)
