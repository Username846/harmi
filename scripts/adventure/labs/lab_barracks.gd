extends Labyrinth
## Pawn labyrinth: the barracks, a lever drill and a drum that beats by itself.

var sequence: Array = []
var entered: Array = []


func build() -> void:
	title = "The Barracks"
	intro = "Boots, bunks, and the endless drill. The {foe} lived its whole life by orders."
	for i in 4:
		sequence.append("LEFT" if randf() < 0.5 else "RIGHT")
	if not sequence.has("LEFT"):
		sequence[1] = "LEFT"
	if not sequence.has("RIGHT"):
		sequence[2] = "RIGHT"
	add_room("mess", "Mess Hall", Vector2i(0, 1), "barracks",
		"Long tables, overturned benches, a cold stew pot. A notice board hangs on the wall, a barrel sits in the corner. A locked door leads north; the bunk room is east.")
	add_room("bunks", "Bunk Room", Vector2i(1, 1), "barracks",
		"Rows of narrow bunks, all perfectly made. The sergeant's bunk has a suspiciously lumpy pillow. A footlocker sits at its foot.")
	add_room("armory", "Armory", Vector2i(0, 0), "stone",
		"Empty weapon racks line the walls. Two great levers stand on either side of an iron vault door.")
	add_room("vault", "The Vault", Vector2i(1, 0), "heart",
		"A small, hot vault. On a pedestal a war drum beats by itself: boom... boom... It is the {foe}'s heart.")
	link("mess", "east", "bunks", "door")
	link("mess", "north", "armory", "door", true, "The armory door is locked. The keyhole is polished brass.")
	link("armory", "north", "vault", "vault", true, "The vault door is sealed. Behind it, something ticks... or beats.")
	current = "mess"

	add_obj("notice", "mess", "Notice Board", "notice", Rect2(0.25, 0.2, 0.13, 0.22),
		"DRILL ORDERS - LEVERS: %s. Below, in pencil: 'Sarge keeps the armory key somewhere soft.'" % ", ".join(sequence))
	add_obj("table", "mess", "Mess Table", "table", Rect2(0.3, 0.6, 0.34, 0.2),
		"Tin plates, tin cups. Someone has carved NEVER BACKWARD into the wood.")
	add_obj("barrel", "mess", "Barrel", "barrel", Rect2(0.68, 0.5, 0.13, 0.28),
		"A barrel of pickled herring. The lid is hammered on.")
	add_obj("bunk", "bunks", "Sergeant's Bunk", "bunk", Rect2(0.52, 0.42, 0.34, 0.36),
		"The sergeant's bunk, made so tight you could bounce a coin off it.")
	add_obj("pillow", "bunks", "Lumpy Pillow", "pillow", Rect2(0.7, 0.5, 0.14, 0.08),
		"A lumpy pillow. Something hard is inside it.")
	add_obj("locker", "bunks", "Footlocker", "chest", Rect2(0.24, 0.68, 0.22, 0.15),
		"The sergeant's footlocker.", {"color": Color(0.4, 0.3, 0.2)})
	add_obj("lever_l", "armory", "Left Lever", "lever", Rect2(0.24, 0.4, 0.1, 0.3),
		"A great iron lever on the left of the vault door.")
	add_obj("lever_r", "armory", "Right Lever", "lever", Rect2(0.66, 0.4, 0.1, 0.3),
		"A great iron lever on the right of the vault door.")
	add_obj("drum", "vault", "War Drum", "drum", Rect2(0.38, 0.4, 0.24, 0.3),
		"A war drum, beating on its own. Boom... boom... This is the pawn's heart.")


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	match o["id"]:
		"barrel":
			if verb == "punch":
				if st("barrel", "broken"):
					say("Just staves and fish now.")
				else:
					set_st("barrel", "broken", true)
					give("whetstone", "The staves burst. Pickled herring floods across the floor... and a Whetstone clatters out with it!")
				return true
			if verb == "open":
				say("The lid is hammered on tight. It smells strongly of fish.")
				return true
		"pillow":
			if verb == "punch" or verb == "open":
				if st("pillow", "empty"):
					say("Just feathers now.")
				else:
					set_st("pillow", "empty", true)
					if verb == "punch":
						give("brass_key", "You punch the pillow. Feathers explode everywhere, and a brass key drops out!")
					else:
						give("brass_key", "You unbutton the pillowcase. Inside is a brass key!")
				return true
		"locker":
			if verb == "open":
				if st("locker", "open"):
					say("Empty, save for a sock.")
				else:
					set_st("locker", "open", true)
					give("whistle", "Inside the footlocker: neatly folded socks and a tin drill whistle.")
				return true
		"lever_l", "lever_r":
			if verb == "use" or verb == "punch" or verb == "open":
				_pull("LEFT" if o["id"] == "lever_l" else "RIGHT")
				return true
		"drum":
			if verb == "punch":
				complete("You punch straight through the drumskin. The beating stops. Silence spreads, and the barracks crumble into ash.")
				return true
			if verb == "use" and item == "whistle":
				complete("You blow the whistle: the drill is over. The drum falls silent, and the {foe} finally lays down its arms. Everything turns to ash.")
				return true
			if verb == "open":
				say("It's a drum. Opening it would be... punching it, really.")
				return true
	return false


func _pull(side: String) -> void:
	entered.append(side)
	var i := entered.size() - 1
	if sequence[i] != side:
		entered.clear()
		set_st("lever_l", "down", false)
		set_st("lever_r", "down", false)
		say("You pull the %s lever. CLANG! Both levers snap back up. The sequence resets." % side.to_lower())
		return
	set_st("lever_l" if side == "LEFT" else "lever_r", "down", not st("lever_l" if side == "LEFT" else "lever_r", "down"))
	if entered.size() == sequence.size():
		entered.clear()
		unlock("armory", "north")
		say("You pull the %s lever. Deep in the wall, bolts slide back one after another. The vault door swings open!" % side.to_lower())
	else:
		say("You pull the %s lever. Something clicks inside the vault door. (%d of %d)" % [side.to_lower(), entered.size(), sequence.size()])


func on_exit_action(verb: String, dir: String, item: String) -> bool:
	if current == "mess" and dir == "north" and rooms["mess"]["exits"]["north"]["locked"]:
		if verb == "use" and item == "brass_key":
			take("brass_key")
			unlock("mess", "north")
			say("The brass key turns smoothly. The armory door swings open.")
			return true
	return false


func on_item_action(verb: String, item: String, other: String) -> bool:
	if verb == "use" and item == "whistle" and other == "":
		say("You blow the whistle. Somewhere a drill sergeant barks: '%s!'" % ", ".join(sequence))
		return true
	return false


func hint() -> String:
	if rooms["mess"]["exits"]["north"]["locked"]:
		if not has("brass_key"):
			return "The notice says the sergeant keeps the key somewhere soft. Check the sergeant's bunk in the bunk room."
		return "USE the brass key on the locked north door of the mess hall."
	if rooms["armory"]["exits"]["north"]["locked"]:
		return "Pull the levers (USE them) in the order from the drill orders on the mess hall notice board: %s." % ", ".join(sequence)
	return "PUNCH the war drum. (Or blow the sergeant's whistle at it.)"
