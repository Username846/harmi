extends SceneTree
## Run: godot --headless --path . -s tests/test_chess.gd

func _init() -> void:
	var ok := true
	var cases := [
		["rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -", [20, 400, 8902]],
		["r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -", [48, 2039, 97862]],
		["8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -", [14, 191, 2812, 43238]],
		["r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq -", [6, 264, 9467]],
		["rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ -", [44, 1486, 62379]],
	]
	var t0 := Time.get_ticks_msec()
	for c in cases:
		var b := ChessRules.new()
		b.load_fen(c[0])
		for d in range(c[1].size()):
			var n := b.perft(d + 1)
			var exp: int = c[1][d]
			if n != exp:
				ok = false
				print("FAIL ", c[0], " depth ", d + 1, ": got ", n, " expected ", exp)
	print("perft done in ", Time.get_ticks_msec() - t0, " ms")
	var g := ChessRules.new()
	g.setup_start()
	# Fool's mate
	for mv in [["f2", "f3"], ["e7", "e5"], ["g2", "g4"], ["d8", "h4"]]:
		var found := false
		for m in g.legal_moves():
			if m["from"] == ChessRules.square_from_name(mv[0]) and m["to"] == ChessRules.square_from_name(mv[1]):
				var s := g.san(m)
				g.play(m)
				found = true
				print(s)
				break
		if not found:
			ok = false
			print("FAIL move not found ", mv)
	if g.status() != "checkmate":
		ok = false
		print("FAIL expected checkmate, got ", g.status())
	print("ALL OK" if ok else "SOME FAILED")
	quit(0 if ok else 1)
