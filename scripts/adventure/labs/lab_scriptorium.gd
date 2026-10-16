extends Labyrinth
## Bishop labyrinth: a library, a hidden code and a three-dial lock.

var code: Array = []


func build() -> void:
	title = "The Scriptorium"
	intro = "Ink and vellum. The {foe} spent its long diagonals copying the same prayer, over and over."
	for i in 3:
		code.append(randi_range(1, 9))
	add_room("library", "Library", Vector2i(0, 1), "library",
		"Shelves of books climb into darkness. A lectern holds an open book. A heavy door to the north has a silver keyhole, and the copying room lies east.")
	add_room("copy", "Copying Room", Vector2i(1, 1), "wood",
		"Writing desks spattered with ink. In the corner stands a cabinet with three brass number dials.")
	add_room("cell", "The Bishop's Cell", Vector2i(0, 0), "heart",
		"A bare cell. Above a prayer stool hangs a glowing mitre of light: the {foe}'s heart.")
	link("library", "east", "copy", "door")
	link("library", "north", "cell", "door", true, "The door is locked. Its keyhole is silver.")
	current = "library"

	add_obj("shelf", "library", "Bookshelf", "bookshelf", Rect2(0.21, 0.15, 0.17, 0.47),
		"Hundreds of books. One is shelved upside-down: 'On the Virtue of Diagonals'.")
	add_obj("lectern", "library", "Lectern", "lectern", Rect2(0.6, 0.4, 0.13, 0.36),
		"The open book reads: 'The cabinet of the copyists is locked by three numbers. The librarian keeps them marked in silk, stitched too small for tired eyes.'")
	add_obj("desk", "copy", "Writing Desk", "desk", Rect2(0.22, 0.58, 0.32, 0.22),
		"A writing desk crusted with ink. It has a drawer.")
	add_obj("cabinet", "copy", "Dial Cabinet", "cabinet", Rect2(0.54, 0.16, 0.26, 0.5),
		"A sturdy cabinet locked by three brass dials.", {"color": Color(0.36, 0.25, 0.17)})
	for i in 3:
		add_obj("dial%d" % i, "copy", "Dial %d" % (i + 1), "dial", Rect2(0.565 + i * 0.08, 0.3, 0.07, 0.09),
			"A brass dial numbered 0 to 9. USE or PUNCH it to turn it.", {"st": {"value": 0}})
	add_obj("stool", "cell", "Prayer Stool", "stool", Rect2(0.42, 0.64, 0.16, 0.14),
		"A worn prayer stool. The wood is polished by endless kneeling.")
	add_obj("heart", "cell", "Bishop's Heart", "heart", Rect2(0.42, 0.24, 0.16, 0.2),
		"A mitre of pale light, humming a single endless note: the {foe}'s heart.")


func _dials() -> Array:
	return [st("dial0", "value", 0), st("dial1", "value", 0), st("dial2", "value", 0)]


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	var oid: String = o["id"]
	if oid.begins_with("dial"):
		if verb == "use" or verb == "punch" or verb == "open":
			var v: int = (int(st(oid, "value", 0)) + 1) % 10
			set_st(oid, "value", v)
			say("Click. The dials read %d - %d - %d." % _dials())
			return true
		if verb == "inspect":
			say("The dials read %d - %d - %d." % _dials())
			return true
	match oid:
		"shelf":
			if verb == "open" or verb == "punch":
				if st("shelf", "searched"):
					say("Just books, books and more books.")
				else:
					set_st("shelf", "searched", true)
					if verb == "punch":
						give("ribbon", "You thump the shelf. The upside-down book tumbles out and falls open, and a silk bookmark slips from its pages.")
					else:
						give("ribbon", "You pull out the upside-down book. A silk bookmark slips from its pages.")
				return true
		"lectern":
			if verb == "punch":
				say("The lectern wobbles. The book stays open at the same page.")
				return true
			if verb == "open":
				say(o["desc"])
				return true
		"desk":
			if verb == "open":
				if st("desk", "open"):
					say("Dried quills and ink blots.")
				else:
					set_st("desk", "open", true)
					give("lens", "In the drawer, among dried quills: a reading lens.")
				return true
		"cabinet":
			if verb == "open":
				if st("cabinet", "open"):
					say("The cabinet is open and empty.")
				elif _dials() == code:
					set_st("cabinet", "open", true)
					give("silver_key", "The dials click into place and the cabinet swings open. Inside lies a slender silver key.")
				else:
					say("Locked. The dials read %d - %d - %d." % _dials())
				return true
			if verb == "punch":
				say("Thick oak. The dials rattle but don't turn.")
				return true
		"heart":
			if verb == "punch" or verb == "use":
				complete("You strike the mitre of light. The single endless note breaks off, and every book in the scriptorium crumbles into ash.")
				return true
	return false


func on_exit_action(verb: String, dir: String, item: String) -> bool:
	if current == "library" and dir == "north" and rooms["library"]["exits"]["north"]["locked"]:
		if verb == "use" and item == "silver_key":
			take("silver_key")
			unlock("library", "north")
			say("The silver key turns without a sound. The door opens on a soft light.")
			return true
	return false


func on_item_action(verb: String, item: String, other: String) -> bool:
	var pair := [item, other]
	if verb == "use" and pair.has("lens") and pair.has("ribbon"):
		flags["read"] = true
		say("Through the lens, the tiny stitches resolve into numbers: %d - %d - %d." % code)
		return true
	if verb == "inspect" and item == "ribbon":
		if flags.get("read", false):
			say("A red silk bookmark. Through the lens you read: %d - %d - %d." % code)
		else:
			say("A red silk bookmark embroidered with three numbers, but the stitching is far too tiny to read.")
		return true
	return false


func hint() -> String:
	if rooms["library"]["exits"]["north"]["locked"]:
		if not st("cabinet", "open"):
			if not has("ribbon"):
				return "One book on the library shelf is upside-down. OPEN the shelf (or PUNCH it)."
			if not flags.get("read", false):
				if not has("lens"):
					return "The ribbon's numbers are too small to read. Check the writing desk's drawer in the copying room."
				return "USE the reading lens on the silk bookmark."
			return "Turn the cabinet dials (USE each) to %d - %d - %d, then OPEN the cabinet." % code
		return "USE the silver key on the locked north door of the library."
	return "PUNCH the mitre of light."
