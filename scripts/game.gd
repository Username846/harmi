extends Node
## Global game state: inventory, item database, settings and encounter bookkeeping.
## Registered as the "Game" autoload.

signal inventory_changed
signal money_changed
signal pieces_changed

const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const PIECE_NAMES := ["", "Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
const PIECE_VALUES := [0, 1, 3, 3, 5, 9, 10]
const START_MONEY := 20
const START_MOOD := 72.0

## Item database.
## use: contexts where the item can be used directly ("battle", "board").
## scope: "global" items persist across the whole game, "puzzle" items vanish
## when you leave the labyrinth they belong to.
const ITEMS := {
	"potion": {"name": "Health Draught", "icon": "flask", "color": Color(0.86, 0.18, 0.2), "use": ["battle"], "scope": "global",
		"desc": "A thick red tonic. In a fight it restores 40 health."},
	"ether": {"name": "Mana Tincture", "icon": "flask", "color": Color(0.25, 0.45, 0.95), "use": ["battle"], "scope": "global",
		"desc": "Blue and fizzing. In a fight it restores 25 mana."},
	"ash": {"name": "Pinch of Ash", "icon": "ash", "color": Color(0.55, 0.53, 0.52), "use": ["battle"], "scope": "global",
		"desc": "All that remains of a fallen piece. Thrown in a fight, it blinds the foe so its next attack misses."},
	"whetstone": {"name": "Whetstone", "icon": "stone", "color": Color(0.6, 0.62, 0.66), "use": ["board"], "scope": "global",
		"desc": "Use it on one of your pieces from the board. That piece gains +4 attack in its next fight."},
	"ward": {"name": "Ward Charm", "icon": "charm", "color": Color(0.85, 0.7, 0.3), "use": ["board"], "scope": "global",
		"desc": "Use it on one of your pieces from the board. That piece gains +25 max health in its next fight."},
	# --- shop goods ----------------------------------------------------------
	"double_move": {"name": "Double Move Upgrade", "icon": "espresso", "color": Color(0.45, 0.28, 0.16), "use": ["turn"], "scope": "global",
		"desc": "A double-shot espresso for your entire army. Use it from the Inventory on your turn: you move twice. (Not if your first move gives check.)"},
	"sniper": {"name": "Sniper Rifle", "icon": "rifle", "color": Color(0.3, 0.34, 0.3), "use": ["board"], "scope": "global",
		"desc": "One bullet. Use it on one of your pieces, then pick an enemy (not the king) in a clear straight line from it. No labyrinth, no duel - just ash. Uses your turn."},
	"driveby": {"name": "Drive-By Hotline", "icon": "phone", "color": Color(0.85, 0.3, 0.55), "use": ["turn"], "scope": "global",
		"desc": "The number for the pieces from the chessboard next door. Use it from the Inventory on your turn: they cruise along the top or bottom edge of the board and take out up to three enemy pieces (never the king) in the nearest two ranks. Uses your turn."},
	"used_car": {"name": "Used Car", "icon": "car", "color": Color(0.35, 0.6, 0.85), "use": ["board"], "scope": "global",
		"desc": "A pair of keys and a pink slip. Give it to a piece that lost its car so it can move again."},
	"nitrous": {"name": "Nitrous Bottle", "icon": "nitrous", "color": Color(0.3, 0.55, 0.95), "use": ["race"], "scope": "global",
		"desc": "A blue bottle of go-faster. In a pink slip race, tap NOS for a burst of speed."},
	"roses": {"name": "Bouquet of Roses", "icon": "roses", "color": Color(0.85, 0.15, 0.25), "use": ["board"], "scope": "global",
		"desc": "Give it to one of your pieces to lift its mood. Doesn't use your turn."},
	"headlamp": {"name": "Headlamp", "icon": "headlamp", "color": Color(0.95, 0.85, 0.4), "use": [], "scope": "global", "unique": true,
		"desc": "Strapped to your forehead at all times. The labyrinths of gloomy pieces are much less dark."},
	"booster": {"name": "Booster Pack", "icon": "booster", "color": Color(0.6, 0.3, 0.8), "use": [], "scope": "global", "instant": true,
		"desc": "Two random cards for the children's card game in the graveyard. Opened the moment you buy it."},
	"beyblade": {"name": "Spare Beyblade", "icon": "beyblade", "color": Color(0.3, 0.6, 0.9), "use": [], "scope": "global",
		"desc": "If your Beyblade volume control snaps off, this replaces it automatically."},
	"gourd": {"name": "Decorative Gourd", "icon": "gourd", "color": Color(0.9, 0.6, 0.2), "use": [], "scope": "global",
		"desc": "It is a gourd. It does nothing. It is, however, decorative."},
	"spoon": {"name": "Commemorative Spoon", "icon": "spoon", "color": Color(0.8, 0.82, 0.86), "use": [], "scope": "global",
		"desc": "Commemorates the Third Annual Chess Club Bake Sale. Nobody remembers the first two."},
	"pet_rock": {"name": "Pet Rock", "icon": "rock", "color": Color(0.55, 0.52, 0.5), "use": [], "scope": "global",
		"desc": "Very low maintenance. Very loyal. Refuses to fight, race, date or do odd jobs."},
	# --- labyrinth items ---------------------------------------------------
	"matches": {"name": "Tin of Matches", "icon": "matches", "color": Color(0.8, 0.3, 0.2), "scope": "puzzle",
		"desc": "A dented tin. A few dry matches rattle inside."},
	"lantern": {"name": "Trench Lantern", "icon": "lantern", "color": Color(0.45, 0.42, 0.38), "scope": "puzzle",
		"desc": "A soot-blackened lantern. The wick is dry and unlit."},
	"lantern_lit": {"name": "Lit Lantern", "icon": "lantern_lit", "color": Color(1.0, 0.75, 0.3), "scope": "puzzle",
		"desc": "The lantern burns with a steady orange flame."},
	"rusty_key": {"name": "Rusty Key", "icon": "key", "color": Color(0.62, 0.38, 0.22), "scope": "puzzle",
		"desc": "A small key, crusted orange with rust."},
	"rope": {"name": "Coil of Rope", "icon": "rope", "color": Color(0.72, 0.6, 0.4), "scope": "puzzle",
		"desc": "Thirty feet of sturdy hemp rope."},
	"oil": {"name": "Oil Can", "icon": "oilcan", "color": Color(0.4, 0.5, 0.35), "scope": "puzzle",
		"desc": "A little tin can with a long spout. Still half full of oil."},
	"coin": {"name": "Tarnished Coin", "icon": "coin", "color": Color(0.85, 0.7, 0.3), "scope": "puzzle",
		"desc": "An old coin. One side shows a crown, the other a skull."},
	"brass_key": {"name": "Brass Key", "icon": "key", "color": Color(0.9, 0.75, 0.3), "scope": "puzzle",
		"desc": "A polished brass key stamped with the word ARMORY."},
	"crank": {"name": "Winch Crank", "icon": "crank", "color": Color(0.5, 0.5, 0.55), "scope": "puzzle",
		"desc": "An iron crank handle with a square socket."},
	"hammer": {"name": "Bell Hammer", "icon": "hammer", "color": Color(0.55, 0.45, 0.35), "scope": "puzzle",
		"desc": "A short hammer with a bronze head, made for striking bells."},
	"flint": {"name": "Flint & Steel", "icon": "flint", "color": Color(0.6, 0.6, 0.6), "scope": "puzzle",
		"desc": "Strike them together to make sparks."},
	"torch": {"name": "Unlit Torch", "icon": "torch", "color": Color(0.5, 0.35, 0.2), "scope": "puzzle",
		"desc": "A wooden torch wrapped in pitch-soaked rags."},
	"torch_lit": {"name": "Burning Torch", "icon": "torch_lit", "color": Color(1.0, 0.6, 0.2), "scope": "puzzle",
		"desc": "The torch crackles and spits, pushing the dark back."},
	"iron_key": {"name": "Iron Key", "icon": "key", "color": Color(0.5, 0.52, 0.58), "scope": "puzzle",
		"desc": "A heavy iron key, big enough to open a cell."},
	"candle": {"name": "Wax Candle", "icon": "candle", "color": Color(0.95, 0.9, 0.75), "scope": "puzzle",
		"desc": "A tall white candle. Unlit."},
	"candle_lit": {"name": "Lit Candle", "icon": "candle_lit", "color": Color(1.0, 0.85, 0.4), "scope": "puzzle",
		"desc": "A tall candle with a small, brave flame."},
	"ribbon": {"name": "Silk Bookmark", "icon": "ribbon", "color": Color(0.7, 0.15, 0.25), "scope": "puzzle",
		"desc": "A red silk ribbon embroidered with three numbers."},
	"lens": {"name": "Reading Lens", "icon": "lens", "color": Color(0.6, 0.8, 0.95), "scope": "puzzle",
		"desc": "A round magnifying glass in a brass frame."},
	"silver_key": {"name": "Silver Key", "icon": "key", "color": Color(0.82, 0.84, 0.9), "scope": "puzzle",
		"desc": "A slender silver key engraved with a bishop's mitre."},
	"whistle": {"name": "Drill Whistle", "icon": "whistle", "color": Color(0.75, 0.75, 0.8), "scope": "puzzle",
		"desc": "A sergeant's tin whistle. It makes a terribly loud shriek."},
}

# Each side keeps its own satchel, wallet and card deck (they only differ in
# two-player games). `active_side` is the side whose turn it is; the
# inventory/item_order/money accessors below always refer to that side.
## What the shop sells, in display order, with prices.
const SHOP := [
	["double_move", 40], ["sniper", 35], ["driveby", 55], ["used_car", 20],
	["nitrous", 12], ["roses", 8], ["headlamp", 15], ["booster", 10],
	["beyblade", 4], ["potion", 6], ["ether", 5], ["whetstone", 10],
	["ward", 10], ["gourd", 3], ["spoon", 2], ["pet_rock", 5],
]

var active_side := 0
var _invs: Array = [{}, {}]
var _orders: Array = [[], []]
var wallets: Array = [0, 0]
var decks: Array = [[], []] # extra card ids from booster packs
var graveyard: Array = [[], []] # [{"type": t, "id": pid}, ...] per colour
var pieces: Dictionary = {} # piece id -> {"mood", "car", "away", "job", "pay", "toppled"}
var piece_buffs: Dictionary = {}
var vs_ai := true
var difficulty := 1
var counters: Dictionary = {}
var stats: Dictionary = {}
var next_piece_id := 200
# --- the graveyard after Yugi (see GRAVE_SECTIONS) ---
var yugi_banished := false # Yugi lost a duel "for reals" and is in the shadow realm
var grave_repairs: Dictionary = {} # section id -> true once repaired
var gravekeeper := -1 # colour of the side that restored the graveyard, or -1
var keeper_cooldown := 0 # the keeper's turns until the next free raising

var inventory: Dictionary:
	get:
		return _invs[active_side]
	set(v):
		_invs[active_side] = v

var item_order: Array:
	get:
		return _orders[active_side]
	set(v):
		_orders[active_side] = v

var money: int:
	get:
		return int(wallets[active_side])


func _ready() -> void:
	randomize()
	new_game()


func new_game() -> void:
	_invs = [{}, {}]
	_orders = [[], []]
	wallets = [START_MONEY, START_MONEY]
	decks = [[], []]
	graveyard = [[], []]
	pieces.clear()
	piece_buffs.clear()
	counters.clear()
	next_piece_id = 200
	yugi_banished = false
	grave_repairs = {}
	gravekeeper = -1
	keeper_cooldown = 0
	stats = {"puzzles": 0, "fights": 0, "captures": 0, "lost": 0, "earned": 0}
	for side in 2:
		active_side = side
		add_item("potion", 2)
		add_item("ether", 1)
		add_item("whetstone", 1)
	active_side = 0
	inventory_changed.emit()
	money_changed.emit()
	pieces_changed.emit()


# --- inventory --------------------------------------------------------------

func add_item(id: String, n: int = 1) -> void:
	if not ITEMS.has(id):
		push_warning("Unknown item: " + id)
		return
	inventory[id] = int(inventory.get(id, 0)) + n
	if not item_order.has(id):
		item_order.append(id)
	inventory_changed.emit()


func remove_item(id: String, n: int = 1) -> bool:
	var have: int = int(inventory.get(id, 0))
	if have < n:
		return false
	have -= n
	if have <= 0:
		inventory.erase(id)
		item_order.erase(id)
	else:
		inventory[id] = have
	inventory_changed.emit()
	return true


func has_item(id: String) -> bool:
	return int(inventory.get(id, 0)) > 0


func count(id: String) -> int:
	return int(inventory.get(id, 0))


func item_ids() -> Array:
	var out: Array = []
	for id in item_order:
		if has_item(id):
			out.append(id)
	return out


func items_usable_in(context: String) -> Array:
	var out: Array = []
	for id in item_ids():
		var uses: Array = ITEMS[id].get("use", [])
		if uses.has(context):
			out.append(id)
	return out


func item_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id


func item_desc(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["desc"]
	return ""


func clear_puzzle_items() -> void:
	for id in item_ids():
		if ITEMS[id].get("scope", "global") == "puzzle":
			inventory.erase(id)
			item_order.erase(id)
	inventory_changed.emit()


func snapshot() -> Dictionary:
	return {"inv": inventory.duplicate(true), "order": item_order.duplicate()}


func restore(snap: Dictionary) -> void:
	inventory = snap["inv"].duplicate(true)
	item_order = snap["order"].duplicate()
	inventory_changed.emit()


# --- money --------------------------------------------------------------------

func add_money(n: int, side: int = -1) -> void:
	var s := active_side if side < 0 else side
	wallets[s] = int(wallets[s]) + n
	if n > 0:
		stats["earned"] = int(stats.get("earned", 0)) + n
	money_changed.emit()


## Pays from the active side's wallet. Returns false (and spends nothing) if short.
func spend(n: int) -> bool:
	if money < n:
		return false
	wallets[active_side] = money - n
	money_changed.emit()
	return true


# --- piece life: moods, cars, odd jobs, knock-overs -----------------------------

func piece(pid: int) -> Dictionary:
	if not pieces.has(pid):
		pieces[pid] = {"mood": START_MOOD, "car": true, "away": 0, "job": "", "pay": 0, "toppled": 0}
	return pieces[pid]


func mood_of(pid: int) -> float:
	return float(piece(pid)["mood"])


func set_mood(pid: int, m: float) -> void:
	piece(pid)["mood"] = clampf(m, 0.0, 100.0)
	pieces_changed.emit()


## Changes a piece's mood and returns the new value.
func change_mood(pid: int, delta: float) -> float:
	var p := piece(pid)
	p["mood"] = clampf(float(p["mood"]) + delta, 0.0, 100.0)
	pieces_changed.emit()
	return float(p["mood"])


func has_car(pid: int) -> bool:
	return bool(piece(pid)["car"])


func set_car(pid: int, v: bool) -> void:
	piece(pid)["car"] = v
	pieces_changed.emit()


## Why a piece can't move right now ("" if it can).
func immobile_reason(pid: int) -> String:
	var p := piece(pid)
	if int(p["away"]) > 0:
		return "is away on a job"
	if int(p["toppled"]) > 0:
		return "is knocked over"
	if not bool(p["car"]):
		return "has no car"
	return ""


func can_move_piece(pid: int) -> bool:
	return immobile_reason(pid) == ""


static func mood_name(m: float) -> String:
	if m >= 85.0:
		return "Elated"
	if m >= 65.0:
		return "Content"
	if m >= 45.0:
		return "Uneasy"
	if m >= 25.0:
		return "Gloomy"
	if m >= 10.0:
		return "Despairing"
	return "Hollow"


static func mood_color(m: float) -> Color:
	if m >= 65.0:
		return Color(0.95, 0.75, 0.35).lerp(Color(1.0, 0.55, 0.7), clampf((m - 65.0) / 35.0, 0.0, 1.0))
	if m >= 25.0:
		return Color(0.55, 0.62, 0.75).lerp(Color(0.95, 0.75, 0.35), (m - 25.0) / 40.0)
	return Color(0.32, 0.3, 0.42).lerp(Color(0.55, 0.62, 0.75), m / 25.0)


## Duel strength from mood: 0.85x when hollow, 1.15x when elated.
static func mood_mult(m: float) -> float:
	return 0.85 + 0.3 * clampf(m, 0.0, 100.0) / 100.0


## How dark a piece's labyrinth is (0 = normal, 1 = nearly black).
func gloom_for(m: float) -> float:
	var g := clampf((70.0 - m) / 62.0, 0.0, 1.0)
	if has_item("headlamp"):
		g *= 0.45
	return g


# --- graveyard ----------------------------------------------------------------

func bury(color: int, t: int, pid: int) -> void:
	graveyard[color].append({"type": t, "id": pid})


## The ruined graveyard's sections, repaired with money and items after Yugi is banished.
const GRAVE_SECTIONS := [
	{"id": "gate", "name": "The Rusted Gate", "desc": "Hanging off one hinge and screaming in the wind.", "money": 15, "items": {"whetstone": 1}},
	{"id": "stones", "name": "The Shattered Headstones", "desc": "Cracked in half. Somebody's name is just '...ight'.", "money": 20, "items": {"ash": 2, "pet_rock": 1}},
	{"id": "flowers", "name": "The Dead Flower Beds", "desc": "Nothing grows here but despair and one stubborn weed.", "money": 5, "items": {"roses": 1}},
	{"id": "crypt", "name": "The Flooded Crypt", "desc": "Ankle-deep black water. Something is floating in it.", "money": 10, "items": {"spoon": 1}},
	{"id": "lanterns", "name": "The Broken Lanterns", "desc": "Every lantern smashed. It is very, very dark.", "money": 15, "items": {"ash": 1}},
	{"id": "shed", "name": "The Keeper's Shed", "desc": "Yugi's old card table, a cold kettle and an empty chair.", "money": 30, "items": {"gourd": 1}},
]
const KEEPER_COOLDOWN := 5


func section_cost_text(sec: Dictionary) -> String:
	var parts: Array = ["$%d" % int(sec["money"])]
	var items: Dictionary = sec["items"]
	for id in items:
		parts.append("%d x %s" % [int(items[id]), item_name(id)])
	return ", ".join(parts)


## Can the active side afford this section's repair right now?
func can_repair(sec_id: String) -> bool:
	var sec := _section(sec_id)
	if sec.is_empty() or grave_repairs.has(sec_id) or not yugi_banished:
		return false
	if money < int(sec["money"]):
		return false
	var items: Dictionary = sec["items"]
	for id in items:
		if count(id) < int(items[id]):
			return false
	return true


## Pays for and repairs a section. Returns true when it worked; crowns the
## active side as gravekeeper when it was the last one.
func repair(sec_id: String) -> bool:
	if not can_repair(sec_id):
		return false
	var sec := _section(sec_id)
	spend(int(sec["money"]))
	var items: Dictionary = sec["items"]
	for id in items:
		remove_item(id, int(items[id]))
	grave_repairs[sec_id] = true
	if graveyard_restored() and gravekeeper < 0:
		gravekeeper = active_side
		keeper_cooldown = 0
	return true


func graveyard_restored() -> bool:
	return grave_repairs.size() >= GRAVE_SECTIONS.size()


func _section(sec_id: String) -> Dictionary:
	for sec in GRAVE_SECTIONS:
		if sec["id"] == sec_id:
			return sec
	return {}


func new_piece_id() -> int:
	next_piece_id += 1
	return next_piece_id


func add_cards(ids: Array) -> void:
	for id in ids:
		decks[active_side].append(id)


# --- piece buffs (from board items) -------------------------------------------

func add_buff(piece_id: int, item_id: String) -> void:
	if not piece_buffs.has(piece_id):
		piece_buffs[piece_id] = []
	piece_buffs[piece_id].append(item_id)


func buffs_of(piece_id: int) -> Array:
	return piece_buffs.get(piece_id, [])


func consume_buffs(piece_id: int) -> Array:
	var b: Array = piece_buffs.get(piece_id, [])
	piece_buffs.erase(piece_id)
	return b


# --- encounters -------------------------------------------------------------

const PAWN_SEQUENCE := ["trench", "well", "fight", "barracks", "trench", "fight", "well", "barracks"]
const ROOK_SEQUENCE := ["tower", "undercroft"]
const BISHOP_SEQUENCE := ["chapel", "scriptorium"]


## Picks what lies inside a captured piece. Returns {"kind": "puzzle"/"fight", "lab": id}.
func encounter_for(victim_type: int) -> Dictionary:
	var key := str(victim_type)
	var n: int = int(counters.get(key, 0))
	counters[key] = n + 1
	match victim_type:
		PAWN:
			var p: String = PAWN_SEQUENCE[n % PAWN_SEQUENCE.size()]
			if p == "fight":
				return {"kind": "fight", "lab": ""}
			return {"kind": "puzzle", "lab": p}
		ROOK:
			return {"kind": "puzzle", "lab": ROOK_SEQUENCE[n % ROOK_SEQUENCE.size()]}
		BISHOP:
			return {"kind": "puzzle", "lab": BISHOP_SEQUENCE[n % BISHOP_SEQUENCE.size()]}
	return {"kind": "fight", "lab": ""}


## Preview without consuming the counter (used by Inspect on the board).
func peek_encounter(victim_type: int) -> Dictionary:
	var key := str(victim_type)
	var saved: int = int(counters.get(key, 0))
	var e := encounter_for(victim_type)
	counters[key] = saved
	return e


const LAB_TITLES := {
	"trench": "The Trench",
	"well": "The Drowned Well",
	"barracks": "The Barracks",
	"tower": "The Bell Tower",
	"undercroft": "The Undercroft",
	"chapel": "The Ashen Chapel",
	"scriptorium": "The Scriptorium",
}


func encounter_title(e: Dictionary) -> String:
	if e["kind"] == "fight":
		return "A Duel"
	return LAB_TITLES.get(e["lab"], "A Labyrinth")


static func color_name(c: int) -> String:
	return "White" if c == 0 else "Black"


static func piece_title(t: int, c: int) -> String:
	return color_name(c) + " " + PIECE_NAMES[t]
