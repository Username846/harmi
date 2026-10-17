class_name CardData
extends RefCounted
## Card database for the graveyard card duel ("a children's card game").
## Every card is an original parody: chess pieces for the player, odd little
## monsters for Yugi Moto, and a booster pool of stronger toys.
##
## Fields: name, kind ("monster"/"spell"), atk (monsters), text, set
## ("chess", "yugi", "booster"), color (art background hint), art (key for
## CardArt), piece (chess piece type for the player's piece monsters),
## target (spells: what the caster has to tap, see CardGame.spell_targets),
## attacks (monsters that may attack more than once per turn).

const CARDS := {
	# --- the player's chess pieces --------------------------------------------
	"pawn": {"name": "Pawn", "kind": "monster", "atk": 600, "set": "chess", "piece": 1, "art": "piece",
		"color": Color(0.36, 0.30, 0.22), "text": "The humble front line. Small, brave, and secretly hoping for a promotion."},
	"knight": {"name": "Knight", "kind": "monster", "atk": 1300, "set": "chess", "piece": 2, "art": "piece",
		"color": Color(0.20, 0.27, 0.38), "text": "Jumps over things in an L. Nobody knows why. Not even the knight."},
	"bishop": {"name": "Bishop", "kind": "monster", "atk": 1300, "set": "chess", "piece": 3, "art": "piece",
		"color": Color(0.30, 0.24, 0.38), "text": "Only ever moves diagonally. Considers this a moral stance."},
	"rook": {"name": "Rook", "kind": "monster", "atk": 1700, "set": "chess", "piece": 4, "art": "piece",
		"color": Color(0.28, 0.29, 0.32), "text": "A castle tower that walks. Stubborn, square and very hard to knock over."},
	"queen": {"name": "Queen", "kind": "monster", "atk": 2500, "set": "chess", "piece": 5, "art": "piece",
		"color": Color(0.42, 0.13, 0.20), "text": "Goes anywhere, hits anything. The reason the other side keeps losing."},
	"king": {"name": "King", "kind": "monster", "atk": 1000, "set": "chess", "piece": 6, "art": "piece",
		"color": Color(0.36, 0.12, 0.38), "text": "Moves one square at a time and complains about it. Surprisingly decent in a pinch."},
	# --- the player's spells ---------------------------------------------------
	"promotion": {"name": "Promotion", "kind": "spell", "set": "chess", "art": "promotion", "target": "own_pawn",
		"color": Color(0.70, 0.55, 0.20), "text": "One of your Pawn monsters becomes a 2500 ATK Queen."},
	"checkmate": {"name": "Checkmate", "kind": "spell", "set": "chess", "art": "checkmate", "target": "none",
		"color": Color(0.55, 0.12, 0.12), "text": "Destroy the opponent's monster with the highest ATK."},
	"en_passant": {"name": "En Passant", "kind": "spell", "set": "chess", "art": "en_passant", "target": "enemy_low",
		"color": Color(0.20, 0.45, 0.40), "text": "Destroy one opponent monster with 1000 ATK or less. (Yes, it's a real rule. Look it up.)"},
	"fifty_move": {"name": "Fifty-Move Rule", "kind": "spell", "set": "chess", "art": "fifty_move", "target": "none",
		"color": Color(0.30, 0.38, 0.55), "text": "Nothing has happened for ages. Gain 1000 LP."},
	# --- Yugi's monsters ---------------------------------------------------------
	"sorcerer": {"name": "Spiky-Haired Sorcerer", "kind": "monster", "atk": 2500, "set": "yugi", "art": "sorcerer",
		"color": Color(0.26, 0.14, 0.42), "text": "A master of the dark arts and of hair gel. Yugi's favourite card, obviously."},
	"skull": {"name": "Rented Skull Demon", "kind": "monster", "atk": 2100, "set": "yugi", "art": "skull",
		"color": Color(0.30, 0.10, 0.12), "text": "Summoned at great expense. Hourly rates apply."},
	"mummy_sandal": {"name": "Mummy's Sandal", "kind": "monster", "atk": 1600, "set": "yugi", "art": "sandal",
		"color": Color(0.55, 0.45, 0.25), "text": "Wrapped in ancient bandages. Still smells faintly of the desert."},
	"gazelle": {"name": "Gazelle, Sort Of", "kind": "monster", "atk": 1500, "set": "yugi", "art": "gazelle",
		"color": Color(0.50, 0.40, 0.18), "text": "Mostly gazelle. The rest is a matter of opinion."},
	"hedge_guardian": {"name": "Celtic Hedge Guardian", "kind": "monster", "atk": 1400, "set": "yugi", "art": "hedge",
		"color": Color(0.18, 0.40, 0.20), "text": "An elf who guards a hedge. The hedge has never been safer."},
	"pebble_soldier": {"name": "Giant Soldier of Pebble", "kind": "monster", "atk": 1300, "set": "yugi", "art": "pebble",
		"color": Color(0.40, 0.40, 0.42), "text": "Giant, by pebble standards."},
	"winged_teapot": {"name": "Winged Teapot", "kind": "monster", "atk": 1200, "set": "yugi", "art": "teapot",
		"color": Color(0.30, 0.45, 0.60), "text": "Flies at a gentle simmer and spits scalding tea."},
	"beaver_warrior": {"name": "Beaver Warrior", "kind": "monster", "atk": 1200, "set": "yugi", "art": "beaver",
		"color": Color(0.42, 0.28, 0.16), "text": "Builds dams. Breaks shields. Gnaws through both."},
	"fuzzball": {"name": "Fuzzball", "kind": "monster", "atk": 300, "set": "yugi", "art": "fuzzball",
		"color": Color(0.48, 0.32, 0.22), "text": "A ball of fluff with enormous eyes. It believes in you."},
	# --- Yugi's spells -------------------------------------------------------------
	"pot_generosity": {"name": "Pot of Generosity", "kind": "spell", "set": "yugi", "art": "pot", "target": "none",
		"color": Color(0.20, 0.42, 0.30), "text": "Draw 2 cards. The pot grins at you. Never trust the pot."},
	"swords_shine": {"name": "Swords of Revealing Shine", "kind": "spell", "set": "yugi", "art": "swords", "target": "none",
		"color": Color(0.22, 0.30, 0.55), "text": "Swords of light rain down: your opponent cannot attack on their next turn."},
	"monster_rerun": {"name": "Monster Re-run", "kind": "spell", "set": "yugi", "art": "rerun", "target": "none",
		"color": Color(0.38, 0.18, 0.40), "text": "Return your strongest destroyed monster from the graveyard to your hand."},
	# --- booster pool (the shop sells these two at a time) -----------------------------
	"elongated_dragon": {"name": "Elongated Dragon", "kind": "monster", "atk": 2800, "set": "booster", "art": "dragon",
		"color": Color(0.16, 0.30, 0.40), "text": "Its neck is longer than a queen is tall. Unbeatable at limbo, terrible with doorways."},
	"beyblade": {"name": "Beyblade", "kind": "monster", "atk": 1500, "set": "booster", "art": "beyblade", "attacks": 2,
		"color": Color(0.18, 0.28, 0.50), "text": "Let it rip! This monster may attack twice each turn."},
	"driveby": {"name": "Drive-By", "kind": "spell", "set": "booster", "art": "driveby", "target": "none",
		"color": Color(0.50, 0.16, 0.36), "text": "The pieces from the board next door roll up: destroy 2 random opponent monsters."},
	"sniper": {"name": "Sniper Shot", "kind": "spell", "set": "booster", "art": "sniper", "target": "none",
		"color": Color(0.24, 0.30, 0.22), "text": "One bullet, no questions. Deal 800 damage to your opponent."},
	"double_move": {"name": "Double Move", "kind": "spell", "set": "booster", "art": "double_move", "target": "own_monster",
		"color": Color(0.40, 0.25, 0.15), "text": "A double espresso for one of your monsters: it may attack one more time this turn."},
	"pink_slip": {"name": "Pink Slip", "kind": "spell", "set": "booster", "art": "pink_slip", "target": "enemy_steal",
		"color": Color(0.62, 0.30, 0.45), "text": "Race for keeps! Take control of an opponent monster with 1600 ATK or less. It can attack from your next turn."},
	"zugzwang": {"name": "Zugzwang", "kind": "spell", "set": "booster", "art": "zugzwang", "target": "none",
		"color": Color(0.35, 0.33, 0.20), "text": "Every move is a bad move: your opponent discards a random card from their hand."},
}

const BOOSTER_POOL := ["elongated_dragon", "beyblade", "driveby", "sniper", "double_move", "pink_slip", "zugzwang"]

const PIECE_CARDS := ["", "pawn", "knight", "bishop", "rook", "queen", "king"]


static func has(id: String) -> bool:
	return CARDS.has(id)


static func info(id: String) -> Dictionary:
	if CARDS.has(id):
		return CARDS[id]
	return {}


static func card_name(id: String) -> String:
	if CARDS.has(id):
		return String(CARDS[id]["name"])
	return id


static func card_text(id: String) -> String:
	if CARDS.has(id):
		return String(CARDS[id]["text"])
	return ""


## One line for the info bar: "Rook - Monster, ATK 1700. A castle tower..."
static func describe(id: String) -> String:
	if not CARDS.has(id):
		return id
	if is_monster(id):
		return "%s  -  Monster, ATK %d.  %s" % [card_name(id), atk(id), card_text(id)]
	return "%s  -  Spell.  %s" % [card_name(id), card_text(id)]


static func is_monster(id: String) -> bool:
	return CARDS.has(id) and String(CARDS[id]["kind"]) == "monster"


static func is_spell(id: String) -> bool:
	return CARDS.has(id) and String(CARDS[id]["kind"]) == "spell"


static func atk(id: String) -> int:
	if CARDS.has(id):
		return int(CARDS[id].get("atk", 0))
	return 0


## Attacks per turn for a monster (Beyblade gets two).
static func attacks_per_turn(id: String) -> int:
	if CARDS.has(id):
		return int(CARDS[id].get("attacks", 1))
	return 1


static func target_mode(id: String) -> String:
	if CARDS.has(id):
		return String(CARDS[id].get("target", "none"))
	return "none"


## Chess piece type (1 pawn .. 6 king) for the player's piece monsters, else 0.
static func piece_type(id: String) -> int:
	if CARDS.has(id):
		return int(CARDS[id].get("piece", 0))
	return 0


static func card_set(id: String) -> String:
	if CARDS.has(id):
		return String(CARDS[id].get("set", ""))
	return ""


static func color(id: String) -> Color:
	if CARDS.has(id):
		return CARDS[id].get("color", Color(0.3, 0.3, 0.3))
	return Color(0.3, 0.3, 0.3)


static func art(id: String) -> String:
	if CARDS.has(id):
		return String(CARDS[id].get("art", ""))
	return ""


static func _repeat(id: String, n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(id)
	return out


## The player's 20-card deck of chess pieces and chess-rule spells.
static func base_deck() -> Array:
	var d: Array = []
	d += _repeat("pawn", 6)
	d += _repeat("knight", 3)
	d += _repeat("bishop", 3)
	d += _repeat("rook", 2)
	d += ["queen", "king", "promotion", "checkmate", "en_passant", "fifty_move"]
	return d


## Yugi's 20-card deck. On hard he swaps a Fuzzball for his Rented Skull Demon.
static func yugi_deck(difficulty: int = 1) -> Array:
	var d: Array = ["sorcerer", "gazelle"]
	d += _repeat("mummy_sandal", 2)
	d += _repeat("hedge_guardian", 2)
	d += _repeat("pebble_soldier", 2)
	d += _repeat("winged_teapot", 2)
	d += _repeat("beaver_warrior", 2)
	d += _repeat("fuzzball", 3)
	d.append("skull" if difficulty >= 2 else "fuzzball")
	d += _repeat("pot_generosity", 2)
	d += ["swords_shine", "monster_rerun"]
	return d


## A booster pack: two random card ids from the booster pool.
static func booster() -> Array:
	return [BOOSTER_POOL[randi() % BOOSTER_POOL.size()], BOOSTER_POOL[randi() % BOOSTER_POOL.size()]]


## Every card id in the game (used by tests and the card gallery).
static func all_ids() -> Array:
	return CARDS.keys()
