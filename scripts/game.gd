extends Node
## Global game state: inventory, item database, settings and encounter bookkeeping.
## Registered as the "Game" autoload.

signal inventory_changed

const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6

const PIECE_NAMES := ["", "Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
const PIECE_VALUES := [0, 1, 3, 3, 5, 9, 10]

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

var inventory: Dictionary = {}
var item_order: Array = []
var piece_buffs: Dictionary = {}
var vs_ai := true
var difficulty := 1
var counters: Dictionary = {}
var stats: Dictionary = {}


func _ready() -> void:
	randomize()
	new_game()


func new_game() -> void:
	inventory.clear()
	item_order.clear()
	piece_buffs.clear()
	counters.clear()
	stats = {"puzzles": 0, "fights": 0, "captures": 0, "lost": 0}
	add_item("potion", 2)
	add_item("ether", 1)
	add_item("whetstone", 1)
	inventory_changed.emit()


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
