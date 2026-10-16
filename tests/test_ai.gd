extends SceneTree
## Times the AI. Run: godot --headless --path . -s tests/test_ai.gd

func _init() -> void:
	var fens := [
		"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq -",
		"r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP3PPP/R2QKB1R b KQ -",
		"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R b KQkq -",
	]
	var ai := ChessAI.new()
	for d in 3:
		for f in fens:
			var b := ChessRules.new()
			b.load_fen(f)
			var t0 := Time.get_ticks_msec()
			var m := ai.choose_move(b, d)
			print("difficulty ", d, " ", Time.get_ticks_msec() - t0, " ms, nodes ", ai.nodes, " move ", b.san(m))
	# mate-in-one must be found at every level
	for d in 3:
		var b2 := ChessRules.new()
		b2.load_fen("r5k1/8/8/8/8/8/5PPP/6K1 b - -")
		var m2 := ai.choose_move(b2, d)
		print("mate test d", d, ": ", b2.san(m2))
	quit()
