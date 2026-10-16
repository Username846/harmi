extends Labyrinth
## Bishop labyrinth: light the three lamps in the order shown in the stained glass.

const COLORS := ["red", "blue", "gold"]
const EMBLEMS := {"red": "a red lion", "blue": "a blue fish", "gold": "a gold sun"}
var order: Array = []
var lit_order: Array = []


func build() -> void:
	title = "The Ashen Chapel"
	intro = "Incense and old stone. The {foe} prays here still, to something that never answers."
	order = COLORS.duplicate()
	order.shuffle()
	add_room("nave", "The Nave", Vector2i(1, 1), "chapel",
		"A narrow chapel with ash-grey pews. A stained-glass window glows on the wall, votive candles flicker in a rack, and an iron poor box sits by the pews. An arch leads north to the sanctum; a door leads west.")
	add_room("vestry", "Vestry", Vector2i(0, 1), "wood",
		"Robes hang from pegs. A cabinet for church supplies stands against the wall.")
	add_room("sanctum", "Sanctum", Vector2i(1, 0), "chapel",
		"An altar of black stone. Before it stand three unlit lamps: one of red glass, one of blue, one of gold.")
	add_room("crypt", "Crypt", Vector2i(2, 0), "heart",
		"A low crypt beneath the altar. On a stone reliquary rests the {foe}'s heart, hidden away.")
	link("nave", "west", "vestry", "door")
	link("nave", "north", "sanctum", "arch")
	link("sanctum", "down", "crypt", "stairs_down", true, "", true)
	current = "nave"

	add_obj("window", "nave", "Stained Glass", "stained", Rect2(0.24, 0.17, 0.13, 0.32),
		"Three panes of stained glass, from top to bottom: %s, %s, and %s." % [EMBLEMS[order[0]], EMBLEMS[order[1]], EMBLEMS[order[2]]],
		{"colors": order})
	add_obj("votive", "nave", "Votive Rack", "votive", Rect2(0.64, 0.46, 0.14, 0.16),
		"A rack of votive candles, all burning with small steady flames.")
	add_obj("pews", "nave", "Pews", "pews", Rect2(0.3, 0.68, 0.4, 0.2),
		"Ash-grey pews. Nobody sits in them.")
	add_obj("poorbox", "nave", "Poor Box", "chest", Rect2(0.76, 0.7, 0.14, 0.13),
		"An iron poor box for offerings.", {"color": Color(0.3, 0.3, 0.34)})
	add_obj("cabinet", "vestry", "Supply Cabinet", "cabinet", Rect2(0.56, 0.18, 0.18, 0.46),
		"A cabinet for church supplies.", {"color": Color(0.42, 0.3, 0.2)})
	add_obj("robes", "vestry", "Robes", "robes", Rect2(0.22, 0.18, 0.2, 0.42),
		"Bishop's robes, far too long for anyone but a bishop.")
	add_obj("altar", "sanctum", "Altar", "altar", Rect2(0.36, 0.3, 0.28, 0.2),
		"A slab of black stone carved with diagonal lines. It looks like it could slide.")
	add_obj("lamp_red", "sanctum", "Red Lamp", "lamp", Rect2(0.2, 0.52, 0.1, 0.26),
		"A lamp of red glass. Unlit.", {"color": Color(0.85, 0.2, 0.2)})
	add_obj("lamp_blue", "sanctum", "Blue Lamp", "lamp", Rect2(0.45, 0.56, 0.1, 0.26),
		"A lamp of blue glass. Unlit.", {"color": Color(0.25, 0.4, 0.95)})
	add_obj("lamp_gold", "sanctum", "Gold Lamp", "lamp", Rect2(0.7, 0.52, 0.1, 0.26),
		"A lamp of gold glass. Unlit.", {"color": Color(0.95, 0.75, 0.25)})
	add_obj("reliquary", "crypt", "Reliquary", "reliquary", Rect2(0.36, 0.44, 0.28, 0.24),
		"A stone reliquary carved with diagonal lines. Light leaks from under its lid.")
	add_obj("heart", "crypt", "Bishop's Heart", "heart", Rect2(0.43, 0.24, 0.14, 0.18),
		"A pale flame shaped like a mitre, burning without wax: the {foe}'s heart.", {"hidden": true})


func on_action(verb: String, o: Dictionary, item: String) -> bool:
	var oid: String = o["id"]
	if oid.begins_with("lamp_"):
		var color := oid.substr(5)
		if verb == "use" and item == "candle_lit":
			_light(color)
			return true
		if verb == "use" and item == "candle":
			say("Your candle isn't lit.")
			return true
		if verb == "use" and item == "":
			say("You need a flame to light it.")
			return true
		if verb == "inspect":
			say("A lamp of %s glass. %s" % [color, "It burns brightly." if lit_order.has(color) else "Unlit."])
			return true
		if verb == "punch":
			say("You'd rather not break the only lamps in here.")
			return true
	match oid:
		"votive":
			if verb == "use" and item == "candle":
				take("candle")
				give("candle_lit", "You touch your candle to a votive flame. It catches.")
				return true
			if verb == "punch":
				say("Hot wax everywhere. Ow. Ow.")
				return true
		"poorbox":
			if verb == "open":
				if st("poorbox", "open"):
					say("Empty.")
				else:
					set_st("poorbox", "open", true)
					give("ward", "It isn't even locked. Inside, someone left an offering: a Ward Charm.")
				return true
			if verb == "punch":
				say("Iron. Your knuckles object strongly.")
				return true
		"cabinet":
			if verb == "open":
				if st("cabinet", "open"):
					say("Just more candles than you could ever need.")
				else:
					set_st("cabinet", "open", true)
					give("candle", "Inside, bundles of fresh candles. You take one.")
				return true
		"robes":
			if verb == "punch":
				say("The robes swing. A moth flutters out.")
				return true
			if verb == "open":
				say("You search the pockets: lint, and a prayer for a quick death.")
				return true
		"altar":
			if verb == "punch" or verb == "open" or verb == "use":
				if st("altar", "moved"):
					say("The altar has already slid aside.")
				else:
					say("It won't move by force. Perhaps the lamps have something to do with it.")
				return true
		"reliquary":
			if verb == "open" or verb == "punch":
				if st("reliquary", "open"):
					say("It's open.")
				else:
					set_st("reliquary", "open", true)
					reveal("heart")
					say("You lift the heavy lid. A pale flame rises out of the reliquary and hangs in the air.")
				return true
		"heart":
			if verb == "punch" or verb == "use":
				complete("You snuff the flame with your fist. Every candle in the chapel goes out at once, and the dark crumbles into ash.")
				return true
	return false


func _light(color: String) -> void:
	if lit_order.has(color):
		say("That lamp is already lit.")
		return
	lit_order.append(color)
	set_st("lamp_" + color, "lit", true)
	if order[lit_order.size() - 1] != color:
		for c in COLORS:
			set_st("lamp_" + c, "lit", false)
		lit_order.clear()
		say("The %s lamp flares... then all the flames gutter and die. The order must be wrong." % color)
		return
	if lit_order.size() == 3:
		set_st("altar", "moved", true)
		unlock("sanctum", "down")
		say("The %s lamp blazes. All three burn together, and with a deep grinding the altar slides aside, revealing steps down!" % color)
	else:
		say("The %s lamp catches and burns steadily." % color)


func hint() -> String:
	if not st("altar", "moved"):
		if not has("candle") and not has("candle_lit"):
			return "The lamps in the sanctum need a flame. Look in the vestry cabinet for a candle."
		if has("candle"):
			return "USE your candle on the votive rack in the nave to light it."
		return "Light the sanctum lamps (USE the lit candle on each) in the order of the stained-glass panes, top to bottom: %s, %s, %s." % order
	if objects["heart"]["hidden"]:
		return "Go down beneath the altar and OPEN the reliquary."
	return "PUNCH the heart-flame."
