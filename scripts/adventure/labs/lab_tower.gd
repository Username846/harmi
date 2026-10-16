extends Labyrinth
## Rook labyrinth: climb the bell tower and ring the bell the right number of times.

var rings_needed := 3
var rings := 0


func build() -> void:
	title = "The Bell Tower"
	intro = "A rook is a tower, and a tower remembers every siege. You stand at the {foe}'s gate."
	rings_needed = randi_range(2, 4)
	add_room("gate", "Tower Gate", Vector2i(1, 2), "castle",
		"The rook's tower rises into storm clouds. An iron portcullis bars the way in. A winch box is bolted to the wall beside it, and a guardhouse door stands to the west.")
	add_room("guard", "Guardhouse", Vector2i(0, 2), "stone",
		"A cramped guardroom: a table with an open logbook, an iron-bound chest, and a dusty suit of armor in the corner.")
	add_room("stair", "Spiral Stair", Vector2i(1, 1), "tower",
		"Stone steps wind upward into the dark. Wind whistles through an arrow slit. One stone in the wall juts out.")
	add_room("top", "Battlements", Vector2i(1, 0), "battlement",
		"The top of the tower, open to the storm. A great bronze bell hangs from a beam. Beside it an iron cage holds a heavy stone heart.")
	link("gate", "west", "guard", "door")
	link("gate", "north", "stair", "portcullis", true, "The portcullis is down. It must be raised from the winch.")
	link("stair", "up", "top", "stairs_up")
	current = "gate"

	add_obj("winch", "gate", "Winch Box", "winchbox", Rect2(0.64, 0.36, 0.12, 0.2),
		"A winch box. The crank handle is missing; there's just a square socket.")
	add_obj("armor", "guard", "Suit of Armor", "armor", Rect2(0.64, 0.16, 0.15, 0.6),
		"A suit of armor. Something is jammed in its gauntlet.")
	add_obj("table", "guard", "Table", "table", Rect2(0.2, 0.58, 0.34, 0.2),
		"A scarred guard table.")
	add_obj("logbook", "guard", "Logbook", "book", Rect2(0.3, 0.53, 0.13, 0.07),
		"The guard log, last entry: 'The great bell must be struck exactly %s times to open the cage. No more, no less.'" % _num_word(rings_needed))
	add_obj("chest", "guard", "Iron-bound Chest", "chest", Rect2(0.08, 0.68, 0.2, 0.15),
		"An iron-bound chest. It isn't locked.", {"color": Color(0.45, 0.28, 0.18)})
	add_obj("slit", "stair", "Arrow Slit", "slit", Rect2(0.3, 0.2, 0.06, 0.26),
		"Through the slit you see the chessboard far below, impossibly large. Your own piece is a speck, waiting for you.")
	add_obj("stone", "stair", "Jutting Stone", "stone_block", Rect2(0.46, 0.5, 0.11, 0.08),
		"One stone sticks out of the wall a little. It wobbles.")
	add_obj("bell", "top", "Great Bell", "bell", Rect2(0.16, 0.12, 0.24, 0.38),
		"A great bronze bell. Its clapper is missing.")
	add_obj("heart", "top", "Rook's Heart", "heart", Rect2(0.59, 0.4, 0.12, 0.16),
		"A heavy heart of grey stone, grinding slowly like a millwheel: the {foe}'s heart.")
	add_obj("cage", "top", "Iron Cage", "cage", Rect2(0.54, 0.28, 0.22, 0.4),
		"An iron cage with no lock and no door you can see. Chains run from its top to the bell beam. Inside, a stone heart grinds slowly.", {"passthrough_open": true})


static func _num_word(n: int) -> String:
	return ["zero", "one", "two", "three", "four", "five"][n]


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	match o["id"]:
		"winch":
			if verb == "use" and item == "crank":
				take("crank")
				set_st("winch", "cranked", true)
				unlock("gate", "north")
				say("You fit the crank into the socket and heave. Chains rattle and the portcullis rises with a groan!")
				return true
			if verb == "open":
				say("Inside the box, gears wait for a crank to turn them.")
				return true
			if verb == "use" and item == "":
				say("There's no handle to turn. Just a square socket.")
				return true
		"armor":
			if verb == "punch":
				if st("armor", "fallen"):
					say("It's a heap of tin now.")
				else:
					set_st("armor", "fallen", true)
					give("crank", "The armor collapses in a clattering heap! A winch crank rolls out of the gauntlet.")
				return true
			if verb == "open":
				say("You lift the visor. Nobody home. Whatever is wedged in the gauntlet is stuck fast.")
				return true
		"chest":
			if verb == "open":
				if st("chest", "open"):
					say("The chest is empty.")
				else:
					set_st("chest", "open", true)
					give("potion", "The lid creaks up. Inside: a Health Draught.")
				return true
		"logbook":
			if verb == "open":
				say(o["desc"])
				return true
		"stone":
			if verb == "punch":
				if st("stone", "out"):
					say("The hollow is empty.")
				else:
					set_st("stone", "out", true)
					give("hammer", "You punch the stone and it tumbles into the wall. In the hollow behind it: a bell hammer.")
				return true
			if verb == "open":
				say("You can't get a grip on it. A good punch might knock it loose.")
				return true
		"bell":
			if verb == "use" and item == "hammer":
				_ring()
				return true
			if verb == "punch":
				say("You punch the bell. It makes a pathetic 'tonk'. You need something harder.")
				return true
		"cage":
			if verb == "open":
				if st("cage", "open"):
					say("It's already open.")
				else:
					say("There's no lock and no handle. The chains to the bell beam must work it somehow.")
				return true
			if verb == "punch":
				say("The bars don't budge.")
				return true
		"heart":
			if not st("cage", "open"):
				if verb != "inspect":
					say("The cage bars are in the way.")
					return true
			elif verb == "punch" or verb == "use":
				complete("You strike the stone heart. It splits along a hairline crack, and the whole tower crumbles beneath you into ash and wind.")
				return true
	return false


func _ring() -> void:
	if st("cage", "open"):
		say("BONNNG. The cage is already open.")
		return
	rings += 1
	if rings == rings_needed:
		set_st("cage", "open", true)
		say("BONNNG! (%d) The chains snap taut and the cage swings open!" % rings)
	elif rings > rings_needed:
		rings = 0
		say("BONNNG! The chains rattle angrily. Whatever you were counting, you'll have to start again.")
	else:
		say("BONNNG! (%d) The cage shudders." % rings)


func hint() -> String:
	if rooms["gate"]["exits"]["north"]["locked"]:
		if not has("crank"):
			return "The winch is missing its crank. Something is jammed in the gauntlet of the armor in the guardhouse. PUNCH it."
		return "USE the crank on the winch box."
	if not st("cage", "open"):
		if not has("hammer"):
			return "The bell needs a hammer. On the spiral stair one stone juts out. PUNCH it."
		return "USE the hammer on the bell exactly as many times as the guardhouse logbook says (%s)." % _num_word(rings_needed)
	return "PUNCH the stone heart."
