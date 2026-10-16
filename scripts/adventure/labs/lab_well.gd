extends Labyrinth
## Pawn labyrinth: a drowned village well and the ferryman who guards the heart.


func build() -> void:
	title = "The Drowned Well"
	intro = "A village you have never seen, yet the {foe} remembers every stone of it."
	add_room("square", "Village Square", Vector2i(1, 0), "village",
		"A silent village square at dusk. An old stone well stands in the middle; its winch has no rope. Every window is shuttered. A notice is nailed to the wall, and a cottage door stands to the west.")
	add_room("cottage", "Abandoned Cottage", Vector2i(0, 0), "cottage",
		"A one-room cottage. A cold hearth, a neatly made bed and a tall pine cupboard.")
	add_room("bottom", "Bottom of the Well", Vector2i(1, 1), "wellshaft",
		"You stand ankle-deep in black water. A circle of sky glows far above. A rusted grate is set into the east wall.")
	add_room("cellar", "Drowned Cellar", Vector2i(2, 1), "cellar",
		"A flooded cellar. A stone statue of a hooded ferryman stands against the back wall, one palm held out.")
	link("square", "west", "cottage", "door")
	link("square", "down", "bottom", "rope_down", true, "The drop is far too deep to jump.", true)
	link("bottom", "east", "cellar", "grate", true, "The grate is rusted shut.")
	current = "square"
	flags["paid"] = false

	add_obj("well", "square", "Stone Well", "well", Rect2(0.36, 0.36, 0.28, 0.42),
		"A deep stone well. The winch above it has no rope. Far below, water glints.")
	add_obj("notice", "square", "Notice", "notice", Rect2(0.66, 0.22, 0.11, 0.18),
		"A weathered notice: 'THE FERRYMAN TAKES HIS TOLL IN COIN. PAY, AND PASS.'")
	add_obj("cupboard", "cottage", "Cupboard", "cabinet", Rect2(0.6, 0.18, 0.17, 0.46),
		"A tall pine cupboard with creaky doors.", {"color": Color(0.55, 0.4, 0.25)})
	add_obj("hearth", "cottage", "Hearth", "hearth", Rect2(0.24, 0.3, 0.26, 0.33),
		"A cold hearth full of old ash. One of the bricks above it is loose.")
	add_obj("bed", "cottage", "Bed", "cot", Rect2(0.06, 0.64, 0.32, 0.2),
		"The blanket is folded with military neatness.")
	add_pickup("coin", "bottom", "coin", Rect2(0.3, 0.8, 0.08, 0.08),
		"Something glints beneath the water: a tarnished coin!")
	add_pickup("ether_pick", "bottom", "ether", Rect2(0.14, 0.52, 0.08, 0.1),
		"A little blue bottle wedged between the stones: a Mana Tincture.")
	add_obj("statue", "cellar", "Ferryman Statue", "statue", Rect2(0.36, 0.16, 0.24, 0.6),
		"A hooded ferryman carved in stone. His palm is open, waiting.")
	add_obj("jar", "cellar", "Sealed Jar", "jar", Rect2(0.64, 0.36, 0.1, 0.16),
		"A clay jar sealed with wax. Inside, the {foe}'s heart glows like a coal.", {"hidden": true})
	add_obj("heart", "cellar", "Pawn's Heart", "heart", Rect2(0.62, 0.3, 0.14, 0.18),
		"The {foe}'s heart flutters in the air like a moth made of embers.", {"hidden": true})


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	match o["id"]:
		"well":
			if verb == "use" and item == "rope":
				take("rope")
				set_st("well", "roped", true)
				unlock("square", "down")
				say("You tie the rope to the winch and let it uncoil into the dark. You could climb down now.")
				return true
			if verb == "go":
				if st("well", "roped"):
					go("down")
				else:
					say("Without a rope, that's a one-way trip.")
				return true
			if verb == "inspect" and st("well", "roped"):
				say("Your rope hangs from the winch down into the well. Tap the rope arrow to climb down.")
				return true
			if verb == "open":
				say("It's a well. It's as open as it gets.")
				return true
			if verb == "punch":
				say("You punch the well. The well wins.")
				return true
		"cupboard":
			if verb == "open":
				if st("cupboard", "open"):
					say("Just empty shelves now.")
				else:
					set_st("cupboard", "open", true)
					give("rope", "The doors creak open. On the top shelf: a coil of sturdy rope.")
				return true
		"hearth":
			if verb == "punch":
				if st("hearth", "broken"):
					say("The hole where the brick was is empty now.")
				else:
					set_st("hearth", "broken", true)
					give("oil", "You knock the loose brick out of the chimney breast. Hidden behind it: an oil can!")
				return true
			if verb == "open":
				say("The hearth is cold and empty. That loose brick, though...")
				return true
		"bed":
			if verb == "punch":
				say("You fluff the pillow. Violently. Nothing inside.")
				return true
		"statue":
			if verb == "use" and item == "coin":
				take("coin")
				flags["paid"] = true
				set_st("statue", "turned", true)
				reveal("jar")
				say("You lay the coin in the stone palm. The fingers close around it... and with a grinding sound the ferryman turns aside, revealing a shelf with a sealed jar.")
				return true
			if verb == "punch":
				say("Stone. Very solid stone. Ow.")
				return true
			if verb == "open":
				say("The ferryman does not open. He waits for payment.")
				return true
		"jar":
			if verb == "open" or verb == "punch":
				hide_obj("jar")
				reveal("heart")
				if verb == "punch":
					say("The jar shatters! The heart flutters free in a puff of sparks.")
				else:
					say("You pry off the wax seal. The heart rises out of the jar like a moth.")
				return true
		"heart":
			if verb == "punch" or verb == "use":
				complete("You close your fist around the ember-moth. It crumbles, the water drains away, and the village dissolves into drifting ash.")
				return true
	return false


func on_exit_action(verb: String, dir: String, item: String) -> bool:
	if current == "bottom" and dir == "east" and rooms["bottom"]["exits"]["east"]["locked"]:
		if verb == "use" and item == "oil":
			flags["oiled"] = true
			say("You oil the hinges of the grate. The rust drinks it greedily.")
			return true
		if verb == "open":
			if flags.get("oiled", false):
				unlock("bottom", "east")
				say("With a long screech, the oiled grate swings open.")
			else:
				say("It's rusted solid. The hinges are caked with orange crust.")
			return true
		if verb == "punch":
			say("You punch the grate. It rings dully and doesn't move.")
			return true
	return false


func hint() -> String:
	if not st("well", "roped"):
		if not has("rope"):
			return "The well's winch has no rope. Look inside the cottage cupboard to the west."
		return "USE the rope on the well."
	if not rooms["bottom"]["visited"]:
		return "Climb down: tap the rope arrow by the well (or use GO on the well)."
	if rooms["bottom"]["exits"]["east"]["locked"]:
		if not flags.get("oiled", false):
			if not has("oil"):
				return "The grate is rusted. Something in the cottage hearth is loose - try PUNCHING it."
			return "USE the oil can on the rusted grate."
		return "Now OPEN the grate."
	if not flags["paid"]:
		if not has("coin"):
			return "The ferryman wants a coin. Something glints in the water at the bottom of the well."
		return "USE the coin on the ferryman statue."
	if not objects["jar"]["hidden"]:
		return "OPEN (or PUNCH) the sealed jar."
	return "PUNCH the heart."
