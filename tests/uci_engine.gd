extends SceneTree
## The game's chess AI as a UCI engine, for strength testing against other engines:
##   godot --headless --path . -s tests/uci_engine.gd -- level=0
## (tools/ai_match.py drives it.)

var level := 1


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level = int(a.substr(6))
	var ai := ChessAI.new()
	var b := ChessRules.new()
	b.setup_start()
	while true:
		var line := OS.read_string_from_stdin(1 << 20).strip_edges()
		if line == "":
			continue
		if line == "uci":
			print("id name Ashen Gambit level %d" % level)
			print("uciok")
		elif line == "isready":
			print("readyok")
		elif line == "ucinewgame":
			b.setup_start()
		elif line.begins_with("position"):
			b = _position(line)
		elif line.begins_with("go"):
			var m := ai.choose_move(b, level)
			print("bestmove " + _uci(m))
		elif line == "quit":
			break
	quit()


func _position(line: String) -> ChessRules:
	var b := ChessRules.new()
	var parts := line.split(" moves ")
	if parts[0].contains("fen"):
		b.load_fen(parts[0].split("fen ")[1])
	else:
		b.setup_start()
	if parts.size() > 1:
		for u in parts[1].split(" ", false):
			var found := false
			for m in b.legal_moves():
				if _uci(m) == u:
					b.play(m)
					found = true
					break
			if not found:
				printerr("uci_engine: no legal move " + u)
	return b


func _uci(m: Dictionary) -> String:
	var s := ChessRules.square_name(m["from"]) + ChessRules.square_name(m["to"])
	if m["promo"] != 0:
		s += "nbrq"[[2, 3, 4, 5].find(m["promo"])]
	return s
