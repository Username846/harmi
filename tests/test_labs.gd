extends Node
## Plays every labyrinth start to finish to prove each is solvable.
## Run: godot --headless --path . res://tests/labs.tscn

var failures := 0


func _ready() -> void:
	for id in AdventureScreen.LABS:
		for run in 3:
			_solve(id)
	print("LAB TESTS ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _do(lab: Labyrinth, verb: String, kind: String, target: String, item: String = "") -> void:
	var h := lab.hint()
	if h == "":
		failures += 1
		print("  empty hint in ", lab.id)
	var lines := lab.act(verb, kind, target, item)
	if OS.is_stdout_verbose():
		print("  > ", verb, " ", target, " ", item, " -> ", lines)


func _solve(id: String) -> void:
	Game.new_game()
	var lab: Labyrinth = AdventureScreen.LABS[id].new()
	lab.id = id
	lab.setup("White Knight", "Black Pawn", false)
	match id:
		"trench":
			_do(lab, "open", "obj", "locker")
			_do(lab, "go", "exit", "east")
			_do(lab, "punch", "obj", "sandbags")
			_do(lab, "go", "exit", "east")
			_do(lab, "punch", "obj", "crate")
			_do(lab, "open", "obj", "satchel")
			_do(lab, "use", "item", "matches", "lantern")
			_do(lab, "go", "exit", "west")
			_do(lab, "go", "exit", "north")
			_do(lab, "punch", "obj", "planks")
			_do(lab, "go", "exit", "north")
			_do(lab, "use", "obj", "helmet", "rusty_key")
			_do(lab, "open", "obj", "helmet")
			_do(lab, "punch", "obj", "heart")
		"well":
			_do(lab, "go", "exit", "west")
			_do(lab, "open", "obj", "cupboard")
			_do(lab, "punch", "obj", "hearth")
			_do(lab, "go", "exit", "east")
			_do(lab, "use", "obj", "well", "rope")
			_do(lab, "go", "exit", "down")
			_do(lab, "inspect", "obj", "coin")
			_do(lab, "use", "exit", "east", "oil")
			_do(lab, "open", "exit", "east")
			_do(lab, "go", "exit", "east")
			_do(lab, "use", "obj", "statue", "coin")
			_do(lab, "open", "obj", "jar")
			_do(lab, "punch", "obj", "heart")
		"barracks":
			_do(lab, "go", "exit", "east")
			_do(lab, "punch", "obj", "pillow")
			_do(lab, "open", "obj", "locker")
			_do(lab, "go", "exit", "west")
			_do(lab, "use", "exit", "north", "brass_key")
			_do(lab, "go", "exit", "north")
			# a wrong pull first, to exercise the reset
			_do(lab, "use", "obj", "lever_r" if lab.sequence[0] == "LEFT" else "lever_l")
			for s in lab.sequence:
				_do(lab, "use", "obj", "lever_l" if s == "LEFT" else "lever_r")
			_do(lab, "go", "exit", "north")
			_do(lab, "punch", "obj", "drum")
		"tower":
			_do(lab, "go", "exit", "west")
			_do(lab, "punch", "obj", "armor")
			_do(lab, "open", "obj", "chest")
			_do(lab, "go", "exit", "east")
			_do(lab, "use", "obj", "winch", "crank")
			_do(lab, "go", "exit", "north")
			_do(lab, "punch", "obj", "stone")
			_do(lab, "go", "exit", "up")
			for i in lab.rings_needed:
				_do(lab, "use", "obj", "bell", "hammer")
			_do(lab, "punch", "obj", "heart")
		"undercroft":
			_do(lab, "inspect", "obj", "torch")
			_do(lab, "go", "exit", "east")
			_do(lab, "open", "obj", "desk")
			_do(lab, "go", "exit", "west")
			_do(lab, "use", "item", "flint", "torch")
			_do(lab, "go", "exit", "west")
			if lab.room_objects("store").is_empty():
				print("  store still dark!")
				failures += 1
			_do(lab, "punch", "obj", "barrel")
			_do(lab, "go", "exit", "east")
			_do(lab, "use", "exit", "north", "iron_key")
			_do(lab, "go", "exit", "north")
			_do(lab, "punch", "obj", "heart")
		"chapel":
			_do(lab, "go", "exit", "west")
			_do(lab, "open", "obj", "cabinet")
			_do(lab, "go", "exit", "east")
			_do(lab, "use", "obj", "votive", "candle")
			_do(lab, "go", "exit", "north")
			for c in lab.order:
				_do(lab, "use", "obj", "lamp_" + c, "candle_lit")
			_do(lab, "go", "exit", "down")
			_do(lab, "open", "obj", "reliquary")
			_do(lab, "punch", "obj", "heart")
		"scriptorium":
			_do(lab, "open", "obj", "shelf")
			_do(lab, "go", "exit", "east")
			_do(lab, "open", "obj", "desk")
			_do(lab, "use", "item", "ribbon", "lens")
			for i in 3:
				for k in lab.code[i]:
					_do(lab, "use", "obj", "dial%d" % i)
			_do(lab, "open", "obj", "cabinet")
			_do(lab, "go", "exit", "west")
			_do(lab, "use", "exit", "north", "silver_key")
			_do(lab, "go", "exit", "north")
			_do(lab, "punch", "obj", "heart")
	if lab.solved:
		print("ok   ", id, "  (ended in ", lab.current, ")")
	else:
		failures += 1
		print("FAIL ", id, " stuck in ", lab.current, "; hint: ", lab.hint())
