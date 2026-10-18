class_name SurvivalSim
extends RefCounted
## Pure rules for surviving the ruins after the bomb under the chessboard
## went off. No nodes and no Game: seedable and testable headless.
##
## Days have three action slots (Morning, Afternoon, Evening), then Night.
## Stats run 0-100. The player wins when the Rescue meter reaches 100 and
## dies when Health reaches 0. Every action method returns true if it
## happened; reason_*() say why something can't be done. Log lines pile up
## in pop_log() as {"text", "kind"} (kind: info, good, bad, find, rescue,
## event, night, morning, warn).

const SLOT_NAMES := ["Morning", "Afternoon", "Evening"]
const SLOTS_PER_DAY := 3

# --- difficulty tables: [easy, normal, hard] ----------------------------------
const DRAIN_FOOD := [5.0, 6.5, 7.0] ## per action slot
const DRAIN_WATER := [6.0, 7.0, 7.5]
const NIGHT_FOOD := [8.0, 10.0, 11.0]
const NIGHT_WATER := [10.0, 12.0, 12.5]
const STARVE_HP := [5.0, 7.0, 8.0] ## per slot with food at 0
const THIRST_HP := [7.0, 9.0, 10.0] ## per slot with water at 0
const RAD_HP_K := [0.12, 0.2, 0.22] ## health lost per slot per point of radiation over 50
const RAD_SAFE := 50.0
const RAD_DECAY := [3.0, 1.5, 1.0] ## radiation the body sheds each night
const NIGHT_HEAL := [6.0, 3.0, 3.0] ## when fed, watered and under the rad line
const REST_HEAL := [14.0, 12.0, 10.0]
const DOZE_HEAL := 3.0 ## per slot slept away by going to bed early
const HARM := [0.7, 1.2, 1.3] ## scales injuries and radiation from events
const RESCUE_MULT := [1.25, 1.0, 0.85]
const PASSIVE := 3.0 ## rescue per day from search teams sweeping the area
const SOS_DAILY := 5.0 ## extra rescue per day once SOS is painted
const SOS_NOW := 4.0
const FIRE_NOW := 7.0
const FIRE_NIGHT := 5.0
const BROADCAST := 12.0
const MIRROR := 6.0
const FLARE_HELI := 22.0
const FLARE_EMPTY := 3.0
const TOWER_FIRST := 20.0
const TOWER_AGAIN := 10.0
const VOICE := 3.0
const RADIO_CHARGE := [4, 3, 3] ## broadcasts per battery
const CLEAR_CHANCE := [0.42, 0.34, 0.26]
const ASH_CHANCE := [0.10, 0.16, 0.22]
const ASH_DOSE := 3.0
const HELI_CHANCE := [0.42, 0.34, 0.26]
const FINDS_MIN := [2, 2, 2]
const FINDS_EXTRA := [0.6, 0.35, 0.15] ## chance of one more find per visit
const POOL_K := [1.3, 1.0, 0.8] ## scales the food, water and medicine in loot piles
const EVENT_BASE := [0.22, 0.35, 0.38] ## + 0.08 per danger level
const HIDE_CHANCE := [0.65, 0.45, 0.35] ## looters miss you
const RENEW_N := [2, 2, 2]

const SCALED := ["food", "water", "dirty_water", "bandage", "first_aid", "rad_pills", "tablets"]

const ITEMS := {
	"food": {"name": "Canned Food", "desc": "Beans, probably. The label burned off. +30 food."},
	"water": {"name": "Bottled Water", "desc": "Sealed and clean. +30 water."},
	"dirty_water": {"name": "Dirty Water", "desc": "Grey and gritty. +25 water, but +10 radiation. Purify it first if you can."},
	"tablets": {"name": "Purification Tablets", "desc": "Drop them in, wait. Turns up to 3 Dirty Water into clean water at once. Doesn't use a turn."},
	"rad_pills": {"name": "Rad Pills", "desc": "Potassium iodide and hope. -30 radiation."},
	"bandage": {"name": "Bandage", "desc": "+20 health."},
	"first_aid": {"name": "First Aid Kit", "desc": "Gauze, splints, antiseptic. +45 health."},
	"battery": {"name": "Battery", "desc": "A chunky 12-volt. Powers a home-built radio for a few broadcasts, or the Radio Station's transmitter once."},
	"radio_part": {"name": "Radio Parts", "desc": "Valves, a tuner, a coil. With 3 of these and a battery you can build a radio at your shelter."},
	"fuel": {"name": "Fuel Can", "desc": "Half a can of petrol. Light a signal fire at your shelter, or run the Radio Station's generator."},
	"flare": {"name": "Flare", "desc": "Fire it from your shelter on a day you hear a helicopter. Wasted on an empty sky."},
	"paint": {"name": "Paint Can", "desc": "Bright orange. Paint SOS on your roof so search planes can spot you."},
	"mirror": {"name": "Signal Mirror", "desc": "Flash it at the sky from your shelter on a clear day. It never runs out."},
	"beyblade": {"name": "Slightly Melted Beyblade", "desc": "It still spins. Sort of. It is not going to help."},
	"pawn": {"name": "Glowing Chess Pawn", "desc": "A pawn from the board, glowing a soft green. It made it to the other side after all."},
	"gourd": {"name": "Decorative Gourd", "desc": "It survived. Of course it survived. Edible in an emergency, if you're starving."},
}
const ITEM_ORDER := ["food", "water", "dirty_water", "tablets", "bandage", "first_aid", "rad_pills",
	"battery", "radio_part", "fuel", "paint", "flare", "mirror", "pawn", "beyblade", "gourd"]
const CONSUMABLE := ["food", "water", "dirty_water", "tablets", "bandage", "first_aid", "rad_pills"]

## pos: where the marker sits on the town map (0..1). slots: action slots a
## trip takes (there and back). rad: radiation dose per visit. danger 0..2.
const LOCS := {
	"shelter": {"name": "Your Shelter", "slots": 0, "rad": 0, "danger": 0, "pos": Vector2(0.14, 0.82), "pool": {},
		"desc": "A basement under a collapsed house on the edge of %s. Thick walls, one hatch, a camp stove. Home."},
	"store": {"name": "Gambit Goods & Gas", "slots": 1, "rad": 3, "danger": 1, "pos": Vector2(0.33, 0.69),
		"pool": {"food": 4, "water": 4, "dirty_water": 1, "gourd": 1, "battery": 1},
		"desc": "The corner store from the board game, or what's left of it. The pumps have melted, but the shelves might not be empty."},
	"pharmacy": {"name": "Pharmacy", "slots": 1, "rad": 4, "danger": 1, "pos": Vector2(0.54, 0.80),
		"pool": {"bandage": 2, "first_aid": 1, "rad_pills": 2, "tablets": 2, "water": 1},
		"desc": "The green cross still hangs by one bolt. Bandages, rad pills and purification tablets, if nobody beat you to them."},
	"hardware": {"name": "Hardware Store", "slots": 1, "rad": 4, "danger": 1, "pos": Vector2(0.11, 0.52),
		"pool": {"fuel": 2, "paint": 1, "battery": 2, "radio_part": 1, "food": 1},
		"desc": "Aisle 7 is now a crater, but fuel cans, paint, batteries and a box of radio spares were kept out back."},
	"school": {"name": "%s Elementary", "slots": 1, "rad": 3, "danger": 0, "pos": Vector2(0.31, 0.47),
		"pool": {"battery": 1, "mirror": 1, "radio_part": 1, "food": 2, "water": 1, "beyblade": 1},
		"desc": "Half a gym and a science lab full of odds and ends. The lost-and-found survived, naturally."},
	"fire_station": {"name": "Fire Station", "slots": 1, "rad": 5, "danger": 1, "pos": Vector2(0.80, 0.74),
		"pool": {"flare": 2, "first_aid": 1, "fuel": 1, "water": 2, "bandage": 1},
		"desc": "The engine never made it out of the bay. Flares, medical kits and fuel in the lockers."},
	"police": {"name": "Police Station", "slots": 2, "rad": 6, "danger": 2, "pos": Vector2(0.88, 0.50),
		"pool": {"radio_part": 2, "flare": 1, "food": 1, "battery": 1, "rad_pills": 1},
		"desc": "The dispatch room's radios are smashed, but the parts inside might not be. Looters like it here too."},
	"water_tower": {"name": "Water Tower", "slots": 1, "rad": 8, "danger": 0, "pos": Vector2(0.48, 0.33), "renew": "dirty_water",
		"pool": {"tablets": 1, "water": 1},
		"desc": "Bent, leaning, still half full. The water is dirty but there's always more of it."},
	"radio_station": {"name": "Radio Station", "slots": 2, "rad": 14, "danger": 1, "pos": Vector2(0.86, 0.23),
		"pool": {"radio_part": 1, "battery": 1, "food": 1},
		"desc": "The radio station on the hill, its big transmitter still standing. Feed its generator a battery or a fuel can and you can broadcast to the whole region."},
	"ground_zero": {"name": "Ground Zero", "slots": 2, "rad": 26, "danger": 2, "pos": Vector2(0.62, 0.53),
		"pool": {"radio_part": 1, "pawn": 1, "first_aid": 1, "rad_pills": 1, "food": 1, "water": 1},
		"desc": "The crater where the chessboard used to be. Glassy, silent, burning hot with radiation. Scattered tiles, and things the blast didn't want."},
}
const LOC_ORDER := ["shelter", "store", "pharmacy", "hardware", "school", "fire_station", "police", "water_tower", "radio_station", "ground_zero"]

const SHELTER_ACTIONS := ["rest", "purify", "build_radio", "broadcast", "fire", "paint", "mirror", "flare"]
const ACTION_NAMES := {"rest": "Rest", "purify": "Purify Water", "build_radio": "Build Radio", "broadcast": "Broadcast",
	"fire": "Signal Fire", "paint": "Paint SOS", "mirror": "Flash Mirror", "flare": "Fire Flare",
	"scavenge": "Scavenge", "tower_broadcast": "Use the Transmitter"}

const WEATHER_NAMES := {"clear": "Clear skies", "haze": "Brown haze", "overcast": "Overcast", "ash": "Ash fall"}

var rng := RandomNumberGenerator.new()
var difficulty := 1
var town := "Ashenford"
var day := 1
var slot := 0
var health := 100.0
var food := 70.0
var water := 70.0
var rad := 10.0
var rescue := 0.0
var inv: Dictionary = {}
var pools: Dictionary = {} ## loc id -> {item id: count}
var visits: Dictionary = {}
var weather := "haze"
var heli_today := false
var heli_promised := false
var fire_lit := false
var sos_painted := false
var radio_built := false
var radio_charge := 0
var broadcast_day := 0
var mirror_day := 0
var tower_day := 0
var tower_uses := 0
var flare_day := 0
var pending: Dictionary = {} ## a survivor's trade offer waiting for an answer
var night_due := false
var over := false
var result := "" ## "rescued" or "died"
var cause := ""
var stats: Dictionary = {}
var last_night: Array = [] ## the lines of the most recent night, for a summary
var _log: Array = []
var _night_lines: Array = []
var _in_night := false


func _init(diff: int = 1, seed_value: int = -1, town_name: String = "Ashenford") -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	difficulty = clampi(diff, 0, 2)
	town = town_name if town_name != "" else "Ashenford"
	stats = {"trips": 0, "found": 0, "broadcasts": 0, "signals": 0, "meals": 0, "drinks": 0, "events": 0, "peak_rad": rad, "rescue_by": {}}
	for id in LOC_ORDER:
		visits[id] = 0
		var p: Dictionary = {}
		var base: Dictionary = LOCS[id]["pool"]
		for item in base:
			var n: int = int(base[item])
			if SCALED.has(item):
				n = int(round(n * float(POOL_K[difficulty])))
			if n > 0:
				p[item] = n
		pools[id] = p
	inv = {"food": 1, "water": 1, "bandage": 1}
	weather = "haze"
	_say("The flash. The roar. Then nothing. %s is gone." % town, "event")
	_say("You wake in a basement on Day 1. Find food and water, and let the authorities know you're alive.", "info")


# --- small helpers -------------------------------------------------------------------

func _say(text: String, kind: String = "info") -> void:
	_log.append({"text": text, "kind": kind})
	if _in_night:
		_night_lines.append({"text": text, "kind": kind})


func pop_log() -> Array:
	var out := _log
	_log = []
	return out


func count(id: String) -> int:
	return int(inv.get(id, 0))


func has(id: String, n: int = 1) -> bool:
	return count(id) >= n


func add_item(id: String, n: int = 1) -> void:
	inv[id] = count(id) + n


func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	inv[id] = count(id) - n
	if int(inv[id]) <= 0:
		inv.erase(id)
	return true


func item_ids() -> Array:
	var out: Array = []
	for id in ITEM_ORDER:
		if count(id) > 0:
			out.append(id)
	return out


static func item_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id


func loc_name(id: String) -> String:
	var n: String = LOCS[id]["name"]
	return n % town if n.contains("%s") else n


func loc_desc(id: String) -> String:
	var d: String = LOCS[id]["desc"]
	return d % town if d.contains("%s") else d


func slot_name() -> String:
	return SLOT_NAMES[clampi(slot, 0, 2)]


func time_text() -> String:
	return "Day %d - %s" % [day, slot_name()]


func weather_name() -> String:
	return WEATHER_NAMES.get(weather, "Haze")


func slots_left() -> int:
	return SLOTS_PER_DAY - slot


func loot_left(id: String) -> int:
	var n := 0
	var p: Dictionary = pools.get(id, {})
	for k in p:
		n += int(p[k])
	return n


func picked_over(id: String) -> bool:
	return id != "shelter" and loot_left(id) == 0 and not LOCS[id].has("renew")


func rad_label(id: String) -> String:
	var r: int = int(LOCS[id]["rad"])
	if r <= 0:
		return "None"
	if r <= 4:
		return "Low"
	if r <= 8:
		return "Moderate"
	if r <= 15:
		return "High"
	return "Lethal"


static func danger_label(d: int) -> String:
	return ["Quiet", "Risky", "Dangerous"][clampi(d, 0, 2)]


func can_broadcast_radio() -> bool:
	return radio_built and (radio_charge > 0 or has("battery"))


func _clamp_stats() -> void:
	health = clampf(health, 0.0, 100.0)
	food = clampf(food, 0.0, 100.0)
	water = clampf(water, 0.0, 100.0)
	rad = clampf(rad, 0.0, 100.0)
	rescue = clampf(rescue, 0.0, 100.0)
	stats["peak_rad"] = maxf(float(stats["peak_rad"]), rad)


func _dose(amount: float) -> void:
	rad += amount
	_clamp_stats()


func _hurt(amount: float, why: String) -> void:
	if over:
		return
	health -= amount
	_clamp_stats()
	if health <= 0.0:
		_die(why)


func _die(why: String) -> void:
	if over:
		return
	over = true
	result = "died"
	cause = why
	_say("You collapse. %s" % _cause_text(why), "bad")


func death_text() -> String:
	return _cause_text(cause)


func _cause_text(why: String) -> String:
	match why:
		"thirst":
			return "Thirst got you before the rescuers did."
		"hunger":
			return "Starvation. Your body simply ran out of anything to burn."
		"radiation":
			return "Radiation sickness. The ruins of %s claim one more." % town
		"dogs":
			return "The dogs were hungrier than you."
		_:
			return "Your wounds were too much."


func _gain_rescue(amount: float, why: String, src: String) -> void:
	if over:
		return
	var a: float = amount * float(RESCUE_MULT[difficulty])
	var by: Dictionary = stats["rescue_by"]
	by[src] = float(by.get(src, 0.0)) + minf(a, 100.0 - rescue)
	rescue += a
	_clamp_stats()
	_say("%s (+%d%% rescue)" % [why, int(round(a))], "rescue")


func _check_rescue() -> void:
	if over:
		return
	if rescue >= 100.0:
		over = true
		result = "rescued"
		_say("Rotors overhead, a searchlight, a voice through a megaphone. They found you!", "rescue")


## Time passes: n action slots. Applies hunger, thirst and radiation per slot.
func _pass_slots(n: int, dozing: bool = false) -> void:
	var d := difficulty
	for i in n:
		if over:
			return
		food -= float(DRAIN_FOOD[d])
		water -= float(DRAIN_WATER[d])
		_clamp_stats()
		_tick_harm(1.0)
		if over:
			return
		if dozing and food > 0.0 and water > 0.0 and rad < RAD_SAFE:
			health = minf(100.0, health + DOZE_HEAL)
		slot += 1
	if slot >= SLOTS_PER_DAY:
		if pending.is_empty():
			_night()
		else:
			night_due = true


func _tick_harm(k: float) -> void:
	var d := difficulty
	if water <= 0.0:
		_hurt(float(THIRST_HP[d]) * k, "thirst")
	if food <= 0.0:
		_hurt(float(STARVE_HP[d]) * k, "hunger")
	if rad > RAD_SAFE:
		_hurt((rad - RAD_SAFE) * float(RAD_HP_K[d]) * k, "radiation")


# --- reasons (empty string = allowed) ------------------------------------------------

func reason_scavenge(id: String) -> String:
	if over:
		return "It's over."
	if id == "shelter" or not LOCS.has(id):
		return "Nothing to scavenge here."
	if slot >= SLOTS_PER_DAY:
		return "It's night."
	var need: int = int(LOCS[id]["slots"])
	if slot + need > SLOTS_PER_DAY:
		return "Too far to get there and back before dark."
	return ""


func reason_action(action: String) -> String:
	if over:
		return "It's over."
	if slot >= SLOTS_PER_DAY:
		return "It's night."
	match action:
		"rest":
			if health >= 100.0:
				return "You're already in good shape."
		"purify":
			if not has("dirty_water"):
				return "You have no dirty water."
		"build_radio":
			if radio_built:
				return "Your radio is already built."
			if not has("radio_part", 3):
				return "Needs 3 Radio Parts (you have %d)." % count("radio_part")
			if not has("battery"):
				return "Needs a Battery to power it."
		"broadcast":
			if not radio_built:
				return "Build a radio first (3 Radio Parts + a Battery)."
			if broadcast_day == day:
				return "The emergency band only opens once a day."
			if radio_charge <= 0 and not has("battery"):
				return "The radio's battery is flat. Find another Battery."
		"fire":
			if fire_lit:
				return "Your signal fire is already burning."
			if not has("fuel"):
				return "Needs a Fuel Can."
		"paint":
			if sos_painted:
				return "SOS is already painted on your roof."
			if not has("paint"):
				return "Needs a Paint Can."
		"mirror":
			if not has("mirror"):
				return "Needs a Signal Mirror."
			if weather != "clear":
				return "Only works in clear weather."
			if mirror_day == day:
				return "You've flashed it today already."
		"flare":
			if not has("flare"):
				return "Needs a Flare."
		"tower_broadcast":
			var need: int = int(LOCS["radio_station"]["slots"])
			if slot + need > SLOTS_PER_DAY:
				return "Too far to get there and back before dark."
			if tower_day == day:
				return "You've already broadcast from the tower today."
			if not has("battery") and not has("fuel"):
				return "The generator needs a Battery or a Fuel Can."
		_:
			return "Unknown action."
	return ""


# --- actions ------------------------------------------------------------------------

func scavenge(id: String) -> bool:
	if reason_scavenge(id) != "":
		return false
	_clear_pending()
	var L: Dictionary = LOCS[id]
	var lname := loc_name(id)
	visits[id] = int(visits[id]) + 1
	stats["trips"] = int(stats["trips"]) + 1
	_say("You pick your way to %s." % lname, "info")
	var dose: float = float(L["rad"])
	if weather == "ash":
		dose += ASH_DOSE
	if dose > 0.0:
		_dose(dose)
	var danger: int = int(L["danger"])
	var ev := ""
	if rng.randf() < float(EVENT_BASE[difficulty]) + 0.08 * danger:
		ev = _roll_event(id)
	var finds := 0
	if over:
		return true
	if ev != "dogs":
		finds = int(FINDS_MIN[difficulty])
		if rng.randf() < float(FINDS_EXTRA[difficulty]):
			finds += 1
	else:
		finds = 1 if rng.randf() < 0.5 else 0
	var got: Array = []
	var p: Dictionary = pools[id]
	for i in finds:
		var item := _draw_from(p)
		if item == "":
			break
		got.append(item)
	if L.has("renew"):
		var rid: String = L["renew"]
		var n: int = int(RENEW_N[difficulty]) + (1 if rng.randf() < 0.5 else 0)
		for i in n:
			got.append(rid)
	if ev == "stash":
		for i in 2:
			got.append(["food", "water", "water", "bandage", "rad_pills", "battery", "flare", "tablets", "food"][rng.randi_range(0, 8)])
	for item in got:
		add_item(item)
	stats["found"] = int(stats["found"]) + got.size()
	if got.is_empty():
		if loot_left(id) == 0 and not L.has("renew"):
			_say("%s is picked over. Nothing left but ash." % lname, "warn")
		else:
			_say("You come back empty-handed.", "warn")
	else:
		_say("Found: %s." % _list_items(got), "find")
	if not over:
		_pass_slots(int(L["slots"]))
	_check_rescue()
	return true


func _list_items(got: Array) -> String:
	var counts := {}
	var order: Array = []
	for g in got:
		if not counts.has(g):
			counts[g] = 0
			order.append(g)
		counts[g] = int(counts[g]) + 1
	var parts := PackedStringArray()
	for g in order:
		var n: int = counts[g]
		parts.append(("%d x %s" % [n, item_name(g)]) if n > 1 else item_name(g))
	return ", ".join(parts)


func _draw_from(p: Dictionary) -> String:
	var total := 0
	for k in p:
		total += int(p[k])
	if total <= 0:
		return ""
	var pick := rng.randi_range(1, total)
	for k in p:
		pick -= int(p[k])
		if pick <= 0:
			p[k] = int(p[k]) - 1
			if int(p[k]) <= 0:
				p.erase(k)
			return k
	return ""


func _roll_event(id: String) -> String:
	var L: Dictionary = LOCS[id]
	var danger: int = int(L["danger"])
	var r: float = float(L["rad"])
	var h: float = float(HARM[difficulty])
	var weights := {
		"dogs": 1.5 + 2.0 * danger,
		"floor": 2.0,
		"hotspot": 1.0 + r / 6.0,
		"survivor": 2.0,
		"stash": [2.5, 1.6, 1.2][difficulty],
	}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var pick := rng.randf() * total
	var ev := "floor"
	for k in weights:
		pick -= float(weights[k])
		if pick <= 0.0:
			ev = k
			break
	stats["events"] = int(stats["events"]) + 1
	match ev:
		"dogs":
			var dmg := (10.0 + 6.0 * danger) * h * rng.randf_range(0.8, 1.2)
			_say("A pack of feral dogs! You fight them off and run, bitten and bleeding. (-%d health)" % int(round(dmg)), "bad")
			_hurt(dmg, "dogs")
		"floor":
			var dmg2 := 9.0 * h * rng.randf_range(0.8, 1.2)
			_say("The floor gives way under you. You drop a storey onto rubble. (-%d health)" % int(round(dmg2)), "bad")
			_hurt(dmg2, "wounds")
		"hotspot":
			var dose := 10.0 * h * rng.randf_range(0.8, 1.2)
			_say("Your skin prickles. A radiation hotspot! You back away, too late. (+%d radiation)" % int(round(dose)), "bad")
			_dose(dose)
		"survivor":
			_offer_trade()
		"stash":
			_say("Behind a loose panel: someone's hidden stash!", "good")
	return ev


func _offer_trade() -> void:
	var who: String = ["a woman pushing a shopping cart", "a man in a bathrobe and a gas mask", "a kid with a cricket bat",
		"an old chess hustler from the park", "a mail carrier, still carrying the mail"][rng.randi_range(0, 4)]
	var wants: Array = []
	for id in ["gourd", "beyblade", "pawn", "paint", "fuel", "flare", "battery", "food", "water", "bandage"]:
		if has(id):
			wants.append(id)
	if wants.is_empty():
		var gift: String = "water" if rng.randf() < 0.5 else "food"
		add_item(gift)
		_say("You meet %s. They have nothing to trade, but share a %s and wish you luck." % [who, item_name(gift)], "good")
		return
	# the funny ones are irresistible to some people
	var give: String = wants[0] if ["gourd", "beyblade", "pawn"].has(wants[0]) and rng.randf() < 0.7 else wants[rng.randi_range(0, wants.size() - 1)]
	var offers: Array = [["food", 2], ["water", 2], ["rad_pills", 1], ["first_aid", 1], ["radio_part", 1], ["battery", 1], ["tablets", 1], ["flare", 1]]
	var o: Array = offers[rng.randi_range(0, offers.size() - 1)]
	while String(o[0]) == give:
		o = offers[rng.randi_range(0, offers.size() - 1)]
	pending = {"who": who, "give": give, "give_n": 1, "get": String(o[0]), "get_n": int(o[1])}
	_say("You meet %s. They offer %s for your %s." % [who, _n_items(pending["get"], pending["get_n"]), item_name(give)], "event")


func _n_items(id: String, n: int) -> String:
	return ("%d x %s" % [n, item_name(id)]) if n > 1 else item_name(id)


func trade_text() -> String:
	if pending.is_empty():
		return ""
	return "You meet %s. They offer %s for your %s." % [pending["who"], _n_items(pending["get"], pending["get_n"]), item_name(pending["give"])]


func answer_trade(accept: bool) -> void:
	if pending.is_empty():
		return
	var p := pending
	pending = {}
	if accept and remove_item(p["give"], int(p["give_n"])):
		add_item(p["get"], int(p["get_n"]))
		_say("Traded your %s for %s." % [item_name(p["give"]), _n_items(p["get"], p["get_n"])], "good")
	else:
		_say("You keep your %s. They shrug and drift off into the ash." % item_name(p["give"]), "info")
	if night_due:
		night_due = false
		_night()


func _clear_pending() -> void:
	if not pending.is_empty():
		answer_trade(false)


func do_action(action: String) -> bool:
	if action == "scavenge":
		return false
	if reason_action(action) != "":
		return false
	_clear_pending()
	var d := difficulty
	var slots := 1
	match action:
		"rest":
			var heal: float = float(REST_HEAL[d])
			health = minf(100.0, health + heal)
			_say("You rest on the camp bed and let your body mend. (+%d health)" % int(heal), "good")
		"purify":
			var n := mini(2, count("dirty_water"))
			remove_item("dirty_water", n)
			add_item("water", n)
			_say("You filter %s through sand and charcoal and boil it on the camp stove." % ("both bottles" if n == 2 else "the dirty water"), "good")
		"build_radio":
			remove_item("radio_part", 3)
			remove_item("battery")
			radio_built = true
			radio_charge = int(RADIO_CHARGE[d])
			_say("You solder, swear, and solder again. The radio crackles to life!", "good")
		"broadcast":
			if radio_charge <= 0:
				remove_item("battery")
				radio_charge = int(RADIO_CHARGE[d])
				_say("You wire a fresh battery into the radio.", "info")
			radio_charge -= 1
			broadcast_day = day
			stats["broadcasts"] = int(stats["broadcasts"]) + 1
			_gain_rescue(BROADCAST + rng.randf_range(-2.0, 2.0), "\"Mayday, mayday, survivor in %s...\" Someone answers through the static." % town, "radio")
			if radio_charge == 0:
				_say("The radio's battery is flat.", "warn")
		"fire":
			remove_item("fuel")
			fire_lit = true
			stats["signals"] = int(stats["signals"]) + 1
			_gain_rescue(FIRE_NOW, "You light a signal fire on the rubble. Black smoke climbs into the sky.", "fire")
		"paint":
			remove_item("paint")
			sos_painted = true
			stats["signals"] = int(stats["signals"]) + 1
			_gain_rescue(SOS_NOW, "You paint a huge orange SOS across what's left of the roof.", "sos")
		"mirror":
			mirror_day = day
			stats["signals"] = int(stats["signals"]) + 1
			_gain_rescue(MIRROR, "You flash the mirror at every glint in the sky. Something flashes back.", "mirror")
		"flare":
			remove_item("flare")
			flare_day = day
			stats["signals"] = int(stats["signals"]) + 1
			if heli_today:
				_gain_rescue(FLARE_HELI, "The flare arcs up, burning red. The helicopter banks toward you!", "flare")
			else:
				_gain_rescue(FLARE_EMPTY, "The flare fizzes into an empty sky. Maybe someone saw it.", "flare")
		"tower_broadcast":
			slots = int(LOCS["radio_station"]["slots"])
			visits["radio_station"] = int(visits["radio_station"]) + 1
			stats["trips"] = int(stats["trips"]) + 1
			var dose: float = float(LOCS["radio_station"]["rad"]) + (ASH_DOSE if weather == "ash" else 0.0)
			_dose(dose)
			if has("battery"):
				remove_item("battery")
				_say("You climb the hill to the Radio Station and wire a battery into the generator.", "info")
			else:
				remove_item("fuel")
				_say("You climb the hill to the Radio Station and pour a can of fuel into the generator.", "info")
			tower_day = day
			stats["broadcasts"] = int(stats["broadcasts"]) + 1
			var amt := TOWER_FIRST if tower_uses == 0 else TOWER_AGAIN
			tower_uses += 1
			_gain_rescue(amt, "The big transmitter hums. Your voice goes out over the whole region.", "tower")
	_check_rescue()
	if not over:
		_pass_slots(slots)
	_check_rescue()
	return true


## Eat, drink, patch up. Consumables don't use a slot. Returns true if it did something.
func use_item(id: String) -> bool:
	if over or not has(id):
		return false
	match id:
		"food":
			remove_item(id)
			food = minf(100.0, food + 30.0)
			stats["meals"] = int(stats["meals"]) + 1
			_say("You eat a can of something. (+30 food)", "good")
		"water":
			remove_item(id)
			water = minf(100.0, water + 30.0)
			stats["drinks"] = int(stats["drinks"]) + 1
			_say("You drink a bottle of clean water. (+30 water)", "good")
		"dirty_water":
			remove_item(id)
			water = minf(100.0, water + 25.0)
			var dose := 10.0 * float(HARM[difficulty])
			_dose(dose)
			stats["drinks"] = int(stats["drinks"]) + 1
			_say("You gulp down the dirty water. It tastes like pennies. (+25 water, +%d radiation)" % int(round(dose)), "warn")
		"tablets":
			if not has("dirty_water"):
				_say("Purification Tablets need Dirty Water to work on.", "info")
				return false
			var n := mini(3, count("dirty_water"))
			remove_item(id)
			remove_item("dirty_water", n)
			add_item("water", n)
			_say("The tablets fizz. %d x Dirty Water is now drinkable." % n, "good")
		"rad_pills":
			remove_item(id)
			rad = maxf(0.0, rad - 30.0)
			_say("You swallow the rad pills. (-30 radiation)", "good")
		"bandage":
			remove_item(id)
			health = minf(100.0, health + 20.0)
			_say("You bind your wounds. (+20 health)", "good")
		"first_aid":
			remove_item(id)
			health = minf(100.0, health + 45.0)
			_say("You clean and dress every cut. (+45 health)", "good")
		"gourd":
			if food >= 20.0:
				_say("It is decorative. You can't bring yourself to eat it. Not yet.", "info")
				return false
			remove_item(id)
			food = minf(100.0, food + 15.0)
			_say("You eat the Decorative Gourd. It was not decorative on the inside. (+15 food)", "good")
		"beyblade":
			_say("You give it a spin on the basement floor. It wobbles in a sad little circle. Let it rip, you suppose.", "info")
			return false
		"pawn":
			_say(["The pawn hums. Somewhere, a chess clock is still ticking.", "It glows a little brighter when you hold it. That's probably fine.",
				"You whisper 'e4'. Nothing happens. It was worth a try."][rng.randi_range(0, 2)], "info")
			return false
		_:
			var hint := {"battery": "Use it at your shelter to build or power a radio, or at the Radio Station.",
				"radio_part": "Collect 3, then Build Radio at your shelter (needs a Battery too).",
				"fuel": "Light a Signal Fire at your shelter, or power the Radio Station's generator.",
				"flare": "Fire Flare at your shelter on a day you hear a helicopter.",
				"paint": "Paint SOS at your shelter.",
				"mirror": "Flash Mirror at your shelter on a clear day."}
			_say(String(hint.get(id, "Not now.")), "info")
			return false
	_clamp_stats()
	return true


## Go to bed early (or at the end of the evening). Remaining slots pass as rest.
func sleep() -> bool:
	if over:
		return false
	if night_due:
		answer_trade(false) # declining runs the night that was waiting on it
		return true
	_clear_pending()
	if slot < SLOTS_PER_DAY:
		var skipped := SLOTS_PER_DAY - slot
		_say("You crawl into the basement and sleep%s." % (" early" if skipped > 1 else ""), "info")
		_pass_slots(skipped, true)
	return true


# --- night and morning ---------------------------------------------------------------

func _night() -> void:
	if over:
		return
	_in_night = true
	_night_lines = []
	var d := difficulty
	_say("Night %d falls over %s." % [day, town], "night")
	food -= float(NIGHT_FOOD[d])
	water -= float(NIGHT_WATER[d])
	_clamp_stats()
	_tick_harm(1.5)
	if not over:
		_night_event()
	if not over:
		rad = maxf(0.0, rad - float(RAD_DECAY[d]))
		if food >= 25.0 and water >= 25.0 and rad < RAD_SAFE:
			health = minf(100.0, health + float(NIGHT_HEAL[d]))
		_gain_rescue(PASSIVE, "Search teams sweep the outskirts of %s." % town, "search")
		if sos_painted:
			_gain_rescue(SOS_DAILY, "A spotter plane circles over your SOS.", "sos")
		if fire_lit:
			_gain_rescue(FIRE_NIGHT, "Your signal fire burns all night, a beacon in the dark.", "fire")
		fire_lit = false
		_check_rescue()
	_in_night = false
	last_night = _night_lines
	if over:
		return
	day += 1
	slot = 0
	_morning()


func _night_event() -> void:
	var d := difficulty
	var h: float = float(HARM[d])
	var weights := {"quiet": 4.0, "storm": 2.0, "looters": 2.0, "rain": 2.0, "aftershock": 1.5, "voice": 1.5 if radio_built else 0.0}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var pick := rng.randf() * total
	var ev := "quiet"
	for k in weights:
		pick -= float(weights[k])
		if pick <= 0.0:
			ev = k
			break
	match ev:
		"quiet":
			_say(["A quiet night. Too quiet. You dream about chess.", "A quiet night. The wind moans through the rubble.",
				"A quiet night. Somewhere a car alarm finally gives up."][rng.randi_range(0, 2)], "night")
		"storm":
			if fire_lit:
				fire_lit = false
				_say("A storm rolls in. Rain hammers the hatch and drowns your signal fire.", "bad")
			else:
				_say("A storm rolls in. Thunder, or another building coming down. You can't tell.", "night")
		"looters":
			var hide: float = float(HIDE_CHANCE[d])
			if fire_lit:
				hide *= 0.3
			if rng.randf() < hide:
				_say("Footsteps and voices overhead: looters. You hold your breath. They move on.", "night")
			else:
				var took: Array = []
				for i in 1 + rng.randi_range(0, 1):
					if has("food"):
						remove_item("food")
						took.append("food")
					elif has("water"):
						remove_item("water")
						took.append("water")
				if took.is_empty():
					_say("Looters find your hatch%s, but there's nothing to take. They leave you be." % (" by the glow of your fire" if fire_lit else ""), "bad")
				else:
					_say("Looters find your hatch%s and take %s." % [" by the glow of your fire" if fire_lit else "", _list_items(took)], "bad")
		"rain":
			var dose := 8.0 * h
			_dose(dose)
			_say("Black rain. It seeps through the cracks and drips on your face all night. (+%d radiation)" % int(round(dose)), "bad")
		"aftershock":
			var dmg := 6.0 * h
			var broke := has("water") and rng.randf() < 0.35
			if broke:
				remove_item("water")
			_say("An aftershock! Dust and plaster rain down on you%s. (-%d health)" % [" and a bottle of water smashes" if broke else "", int(round(dmg))], "bad")
			_hurt(dmg, "wounds")
		"voice":
			heli_promised = true
			_say("Your radio crackles: \"...survivors in %s, a helicopter will sweep the area tomorrow...\"" % town, "good")
			_gain_rescue(VOICE, "They know someone's listening.", "radio")


func _morning() -> void:
	var d := difficulty
	var r := rng.randf()
	if r < float(CLEAR_CHANCE[d]):
		weather = "clear"
	elif r < float(CLEAR_CHANCE[d]) + float(ASH_CHANCE[d]):
		weather = "ash"
	elif rng.randf() < 0.5:
		weather = "overcast"
	else:
		weather = "haze"
	var was_heli := heli_today
	heli_today = false
	if heli_promised or (not was_heli and rng.randf() < float(HELI_CHANCE[d])):
		heli_today = true
	heli_promised = false
	var line := "Day %d. %s." % [day, weather_name()]
	match weather:
		"clear":
			line += " The ash has settled; you can see for miles. A good day for the mirror."
		"ash":
			line += " Grey flakes drift down. Every trip outside costs extra radiation."
	_say(line, "morning")
	if heli_today:
		_say("You hear rotors to the east... A helicopter is searching today. Fire a flare!", "rescue")
	if food < 25.0:
		_say("Your stomach cramps. Eat something.", "warn")
	if water < 25.0:
		_say("Your lips are cracked. Drink something.", "warn")
	if rad > RAD_SAFE:
		_say("You feel sick. Radiation is eating at you.", "warn")
