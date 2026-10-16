extends Labyrinth
## Pawn labyrinth: the front-line trench the pawn never escaped.


func build() -> void:
	title = "The Trench"
	intro = "Mud. Rain. The smell of wet canvas. You are inside the {foe}'s memory of the front line."
	add_room("dugout", "Muddy Dugout", Vector2i(0, 2), "dugout",
		"A cramped dugout shored up with rotten timber. Rain drips through the roof. A cot, a footlocker, and a poster on the wall.")
	add_room("bend", "Trench Bend", Vector2i(1, 2), "trench",
		"The trench zig-zags here under a bruised sky. Sandbags are heaped along the parapet; one has split at the seams. A periscope pokes over the top. Passages lead north and east.")
	add_room("nook", "Supply Nook", Vector2i(2, 2), "dugout",
		"A niche dug into the trench wall, stacked with supplies. A crate and a canvas satchel.")
	add_room("tunnel", "Collapsed Tunnel", Vector2i(1, 1), "tunnel",
		"A low tunnel burrowing toward the enemy line. Rotten planks are nailed across the passage ahead. Cold air seeps between them.")
	var heart_room := add_room("heart", "The Heart of the Pawn", Vector2i(1, 0), "heart",
		"A hollow beneath no-man's-land. An iron helmet is padlocked to a post, and from inside it comes a steady thump... thump...", true)
	heart_room["dark_desc"] = "It's pitch black. Something breathes in the dark, slow and patient. You need a light."
	link("dugout", "east", "bend", "passage")
	link("bend", "east", "nook", "door")
	link("bend", "north", "tunnel", "passage")
	link("tunnel", "north", "heart", "passage", true, "Rotten planks block the passage.")
	current = "dugout"

	add_obj("cot", "dugout", "Cot", "cot", Rect2(0.06, 0.64, 0.34, 0.2),
		"A sagging cot. The {foe} once slept here, dreaming of the eighth rank.")
	add_obj("locker", "dugout", "Footlocker", "chest", Rect2(0.52, 0.68, 0.26, 0.17),
		"A battered army footlocker stenciled with a pawn insignia.", {"color": Color(0.33, 0.36, 0.22)})
	add_obj("poster", "dugout", "Poster", "poster", Rect2(0.3, 0.2, 0.16, 0.24),
		"A recruitment poster: 'MARCH FORWARD. NEVER BACK.' Underneath, someone has scrawled: 'the key is in the sand.'")
	add_obj("sandbags", "bend", "Sandbags", "sandbags", Rect2(0.2, 0.42, 0.2, 0.22),
		"Heavy sacks of sand. One has split along the seam, and something metal glints inside it.")
	add_obj("periscope", "bend", "Periscope", "periscope", Rect2(0.64, 0.12, 0.07, 0.42),
		"You peer through the periscope and see the chessboard, vast as a country. Your own piece stands frozen mid-lunge.")
	add_obj("crate", "nook", "Supply Crate", "crate", Rect2(0.3, 0.5, 0.28, 0.32),
		"A supply crate stamped 'LIGHT - FRAGILE'. The lid is nailed shut.")
	add_obj("satchel", "nook", "Medic's Satchel", "satchel", Rect2(0.64, 0.7, 0.16, 0.14),
		"A canvas satchel with a faded red cross.")
	add_obj("planks", "tunnel", "Rotten Planks", "planks", Rect2(0.38, 0.24, 0.24, 0.4),
		"Rotten planks nailed across a narrow passage. They sag and creak.")
	add_obj("helmet_bones", "tunnel", "Old Helmet", "skull", Rect2(0.14, 0.78, 0.12, 0.09),
		"A pawn's helmet, half-buried in the mud. Empty, thankfully.")
	add_obj("helmet", "heart", "Padlocked Helmet", "helmet", Rect2(0.4, 0.26, 0.2, 0.46),
		"An iron helmet padlocked to a post. Inside it, something beats: thump... thump...")
	add_obj("heart", "heart", "Pawn's Heart", "heart", Rect2(0.43, 0.28, 0.14, 0.18),
		"The pawn's heart: small, stubborn, grey as a cinder. It only ever wanted to move forward.", {"hidden": true})


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	match o["id"]:
		"locker":
			if verb == "open":
				if st("locker", "open"):
					say("The footlocker is empty now.")
				else:
					set_st("locker", "open", true)
					give("matches", "You flip the latches. Inside, wrapped in oilcloth: a tin of dry matches.")
				return true
			if verb == "punch":
				say("You dent the lid. It's not locked, you know. You could just open it.")
				return true
		"cot":
			if verb == "open":
				say("It's a cot. There's nothing to open.")
				return true
			if verb == "punch":
				say("You punch the thin mattress. A cloud of dust. Nothing else.")
				return true
		"sandbags":
			if verb == "punch":
				if st("sandbags", "broken"):
					say("The sack is already empty, just a sad burlap skin.")
				else:
					set_st("sandbags", "broken", true)
					give("rusty_key", "You punch the split sandbag. The rotten burlap gives way and sand pours out... along with a rusty key!")
				return true
			if verb == "open":
				say("The stitching is too tight to pick open. The burlap is very rotten, though.")
				return true
			if verb == "inspect" and st("sandbags", "broken"):
				say("A heap of spilled sand and an empty sack.")
				return true
		"periscope":
			if verb == "use":
				say(o["desc"])
				return true
		"crate":
			if verb == "open":
				if st("crate", "broken"):
					say("It's in pieces already.")
				else:
					say("The lid is nailed down tight. You'd need a crowbar. Or a fist.")
				return true
			if verb == "punch":
				if st("crate", "broken"):
					say("You've already smashed it.")
				else:
					set_st("crate", "broken", true)
					give("lantern", "CRACK! The slats splinter. Nestled in the straw: a soot-blackened lantern.")
				return true
			if verb == "inspect" and st("crate", "broken"):
				say("Splinters and straw.")
				return true
		"satchel":
			if verb == "open":
				if st("satchel", "open"):
					say("The satchel is empty.")
				else:
					set_st("satchel", "open", true)
					give("potion", "You unbuckle the satchel and find a Health Draught.")
				return true
		"planks":
			if verb == "punch":
				hide_obj("planks")
				unlock("tunnel", "north")
				say("You throw your whole weight into it. The rotten planks burst apart! The passage north is open.")
				return true
			if verb == "open":
				say("There's no handle. They're nailed in place.")
				return true
			if verb == "use" and item == "":
				say("You tug at them. They sag, but hold. They look rotten enough to break.")
				return true
		"helmet":
			if verb == "use" and item == "rusty_key":
				take("rusty_key")
				set_st("helmet", "unlocked", true)
				say("The rusty key grinds in the padlock... CLICK. The padlock falls into the mud.")
				return true
			if verb == "open":
				if not st("helmet", "unlocked"):
					say("It's padlocked to the post. The padlock is crusted with rust.")
				else:
					hide_obj("helmet")
					reveal("heart")
					say("You lift the helmet away. The {foe}'s heart hangs there on a wire: a small grey ember, beating.")
				return true
			if verb == "punch":
				say("CLANG! Your hand rings like a bell. The padlock holds.")
				return true
		"heart":
			if verb == "punch" or verb == "use":
				complete("You strike the heart. It cracks like a cinder, and with a long sigh the whole trench slumps into ash.")
				return true
			if verb == "open":
				say("There is nothing to open. There is only the heart.")
				return true
	return false


func on_item_action(verb: String, item: String, other: String) -> bool:
	var pair := [item, other]
	if verb == "use" and pair.has("matches") and pair.has("lantern"):
		take("lantern")
		take("matches")
		give("lantern_lit", "You strike a match and touch it to the wick. The lantern catches with a warm orange glow.")
		return true
	if verb == "use" and other == "" and item == "matches":
		say("You strike a match. It flares and dies. You should light something with it.")
		return true
	if verb == "use" and other == "" and item == "lantern":
		say("The lantern needs a flame.")
		return true
	return false


func on_enter(room: String) -> void:
	if room == "heart" and is_lit("heart") and not flags.get("lit_msg", false):
		flags["lit_msg"] = true
		say("Your lantern pushes back the dark.")


func hint() -> String:
	if not has("lantern") and not has("lantern_lit"):
		return "One crate in the supply nook is marked 'LIGHT - FRAGILE'. Crates that won't open can be PUNCHED."
	if has("lantern") and not has("matches"):
		return "A lantern needs a flame. Soldiers keep their matches dry in their footlockers. OPEN the one in the dugout."
	if has("lantern"):
		return "USE the matches on the lantern: pick USE, tap the matches, then tap the lantern."
	if not objects["planks"]["hidden"]:
		return "The planks in the collapsed tunnel are rotten. PUNCH them."
	if not st("helmet", "unlocked") and not has("rusty_key"):
		return "The poster in the dugout says the key is in the sand. PUNCH the split sandbag at the trench bend."
	if not st("helmet", "unlocked"):
		return "USE the rusty key on the padlocked helmet in the heart of the labyrinth (north of the tunnel)."
	if objects["heart"]["hidden"]:
		return "The padlock is gone. OPEN the helmet."
	return "PUNCH the heart."
