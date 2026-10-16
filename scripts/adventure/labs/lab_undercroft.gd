extends Labyrinth
## Rook labyrinth: a dungeon beneath the tower, a dark storeroom and a locked cell.


func build() -> void:
	title = "The Undercroft"
	intro = "Beneath every tower is a dungeon. The {foe} kept its heart locked in the deepest one."
	add_room("cells", "Cell Block", Vector2i(1, 1), "dungeon",
		"Damp cells line a stone corridor. A skeleton slumps against the wall. An unlit torch sits in a bracket. The cell door to the north is locked, and something glows red behind it.")
	add_room("office", "Warden's Office", Vector2i(2, 1), "wood",
		"A cramped office: a heavy desk, a tall wardrobe, and a portrait of a stern rook.")
	var store := add_room("store", "Storeroom", Vector2i(0, 1), "dungeon",
		"A storeroom full of grain barrels and sacks. Rats scatter from your light.", true)
	store["dark_desc"] = "It is pitch black. You hear water dripping, and tiny claws."
	add_room("pit", "The Oubliette", Vector2i(1, 0), "heart",
		"A deep pit-cell of mortar and stone. Set into the far wall, the {foe}'s heart: a block of red-hot mortar that pulses like a forge.")
	link("cells", "east", "office", "door")
	link("cells", "west", "store", "passage")
	link("cells", "north", "pit", "cell", true, "The cell door is locked with a heavy iron lock. Through the bars, a reddish glow pulses.")
	current = "cells"

	add_obj("skeleton", "cells", "Skeleton", "skeleton", Rect2(0.2, 0.52, 0.17, 0.32),
		"A long-dead guard. In its bony hand is a scrap of paper: 'The warden hid the cell key where the light can't reach.'")
	add_pickup("torch", "cells", "torch", Rect2(0.64, 0.24, 0.07, 0.14),
		"An unlit torch in an iron bracket.")
	add_obj("desk", "office", "Desk", "desk", Rect2(0.22, 0.54, 0.36, 0.26),
		"The warden's desk. One drawer is slightly open.")
	add_obj("wardrobe", "office", "Wardrobe", "cabinet", Rect2(0.64, 0.17, 0.16, 0.47),
		"A tall wardrobe smelling of mothballs.", {"color": Color(0.35, 0.24, 0.16)})
	add_obj("painting", "office", "Portrait", "painting", Rect2(0.34, 0.18, 0.17, 0.2),
		"A portrait of a rook, glaring. The brass plate reads: 'LIGHT REVEALS ALL.'")
	add_obj("sacks", "store", "Grain Sacks", "sacks", Rect2(0.2, 0.6, 0.26, 0.22),
		"Lumpy sacks of grain, nibbled by rats.")
	add_obj("barrel", "store", "Grain Barrel", "barrel", Rect2(0.58, 0.46, 0.15, 0.32),
		"A grain barrel. When you nudge it, something metal rattles inside.")
	add_obj("chains", "pit", "Chains", "chains", Rect2(0.16, 0.18, 0.16, 0.36),
		"Rusted shackles. Whoever wore them is long gone.")
	add_obj("heart", "pit", "Rook's Heart", "heart", Rect2(0.42, 0.28, 0.16, 0.2),
		"A block of mortar glowing red-hot, pulsing like a forge: the {foe}'s heart.")


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	match o["id"]:
		"skeleton":
			if verb == "punch":
				say("The skeleton collapses into a pile of bones. Rude. The note flutters to the floor; you've already read it.")
				return true
			if verb == "open":
				say("You pry open the bony fingers and read the note: 'The warden hid the cell key where the light can't reach.'")
				return true
		"desk":
			if verb == "open":
				if st("desk", "open"):
					say("The drawer is empty now.")
				else:
					set_st("desk", "open", true)
					give("flint", "You slide the drawer open. Inside: flint and steel.")
				return true
			if verb == "punch":
				say("The desk is solid oak. You hurt your hand.")
				return true
		"wardrobe":
			if verb == "open":
				if st("wardrobe", "open"):
					say("Just musty uniforms.")
				else:
					set_st("wardrobe", "open", true)
					give("ether", "Musty uniforms... and in a pocket, a Mana Tincture!")
				return true
		"painting":
			if verb == "punch":
				say("You punch the painting. The rook glares harder.")
				return true
		"barrel":
			if verb == "punch":
				if st("barrel", "broken"):
					say("Staves and spilled grain.")
				else:
					set_st("barrel", "broken", true)
					give("iron_key", "The barrel bursts! Grain pours across the floor, and in it lies a heavy iron key.")
				return true
			if verb == "open":
				say("The lid is stuck fast. It's an old barrel, though. Brittle.")
				return true
		"sacks":
			if verb == "punch" or verb == "open":
				say("Grain. Just grain. A rat glares at you.")
				return true
		"heart":
			if verb == "punch" or verb == "use":
				complete("You strike the glowing mortar. It cracks, crumbles, and the whole Undercroft caves in around you as ash.")
				return true
	return false


func on_exit_action(verb: String, dir: String, item: String) -> bool:
	if current == "cells" and dir == "north" and rooms["cells"]["exits"]["north"]["locked"]:
		if verb == "use" and item == "iron_key":
			take("iron_key")
			unlock("cells", "north")
			say("The iron key turns with a CLUNK. The cell door swings open on a red glow.")
			return true
		if verb == "punch":
			say("The bars ring. Your knuckles ring louder.")
			return true
	return false


func on_item_action(verb: String, item: String, other: String) -> bool:
	var pair := [item, other]
	if verb == "use" and pair.has("flint") and pair.has("torch"):
		take("torch")
		give("torch_lit", "You strike the flint against the steel. Sparks catch in the pitch, and the torch roars into flame.")
		return true
	if verb == "use" and item == "torch" and other == "":
		say("The torch needs a spark.")
		return true
	if verb == "use" and item == "flint" and other == "":
		say("Sparks fly and die. You need something to light.")
		return true
	return false


func on_enter(room: String) -> void:
	if room == "store" and not is_lit("store"):
		say("You'll need a light to search in here.")


func hint() -> String:
	if rooms["cells"]["exits"]["north"]["locked"]:
		if not has("iron_key"):
			if not has("torch_lit"):
				if not has("torch"):
					return "The skeleton's note says the key is where the light can't reach. Take the torch from its bracket in the cell block."
				if not has("flint"):
					return "Your torch needs a spark. The warden's desk drawer is open a crack. OPEN it."
				return "USE the flint on the torch."
			return "Take your burning torch west into the dark storeroom and search it. Brittle barrels break when PUNCHED."
		return "USE the iron key on the locked cell door north of the cell block."
	return "PUNCH the glowing heart in the oubliette."
