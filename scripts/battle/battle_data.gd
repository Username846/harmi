class_name BattleData
extends RefCounted
## Fighter stats and skills for duels.

const STATS := {
	1: {"hp": 46, "mp": 14, "atk": 9, "def": 4, "mag": 6},
	2: {"hp": 72, "mp": 22, "atk": 13, "def": 6, "mag": 7},
	3: {"hp": 62, "mp": 38, "atk": 9, "def": 5, "mag": 14},
	4: {"hp": 92, "mp": 18, "atk": 14, "def": 9, "mag": 6},
	5: {"hp": 108, "mp": 46, "atk": 15, "def": 8, "mag": 15},
	6: {"hp": 140, "mp": 50, "atk": 14, "def": 10, "mag": 14},
}

const SKILLS := {
	1: [
		{"name": "Bayonet Lunge", "cost": 6, "kind": "phys", "power": 1.6, "desc": "A desperate thrust for 1.6x damage."},
		{"name": "Dream of Promotion", "cost": 8, "kind": "buff_atk", "power": 5, "desc": "+5 attack for the rest of the fight."},
	],
	2: [
		{"name": "L-Strike", "cost": 8, "kind": "phys", "power": 1.8, "pierce": true, "desc": "Leaps over any guard for 1.8x damage."},
		{"name": "Rally", "cost": 7, "kind": "heal", "power": 0.3, "desc": "Restores 30% of max health."},
	],
	3: [
		{"name": "Diagonal Smite", "cost": 8, "kind": "magic", "power": 2.0, "desc": "Holy fire along the diagonal: 2x magic damage."},
		{"name": "Benediction", "cost": 10, "kind": "heal", "power": 0.4, "desc": "Restores 40% of max health."},
	],
	4: [
		{"name": "Battering Ram", "cost": 8, "kind": "phys", "power": 2.0, "desc": "Crashes straight through for 2x damage."},
		{"name": "Fortify", "cost": 6, "kind": "buff_def", "power": 6, "desc": "+6 defense for the rest of the fight."},
	],
	5: [
		{"name": "Royal Decree", "cost": 10, "kind": "magic", "power": 2.2, "desc": "An order the world obeys: 2.2x magic damage."},
		{"name": "Sweeping Gambit", "cost": 8, "kind": "phys", "power": 1.7, "desc": "Strikes from every direction for 1.7x damage."},
	],
	6: [
		{"name": "Castle", "cost": 10, "kind": "heal", "power": 0.35, "def": 4, "desc": "Heals 35% of max health and gains +4 defense."},
		{"name": "Last Stand", "cost": 16, "kind": "phys", "power": 2.6, "desc": "Everything on one blow: 2.6x damage."},
	],
}

const MOVES_DESC := {
	1: "Marches one square forward (two on its first step) and captures diagonally. Reaching the far rank promotes it.",
	2: "Leaps in an L: two squares one way, then one to the side. Jumps over anything in its path.",
	3: "Glides any distance along a diagonal.",
	4: "Charges any distance along ranks and files. Can castle with its king.",
	5: "Moves any distance in any straight line.",
	6: "Steps one square in any direction and must never be left in check.",
}


## Builds a fighter. Heroes get a bonus; foes scale with the matchup so a pawn
## that takes a queen faces a hard but winnable duel.
## mood (0-100) scales attack and magic: a hollow piece hits about 20% softer
## than an ordinary one, an elated piece a little harder.
static func make_fighter(t: int, color: int, is_hero: bool, other_t: int, buffs: Array = [], mood: float = Game.START_MOOD) -> Dictionary:
	var base: Dictionary = STATS[t]
	var mult_hp := 1.0
	var mult_atk := 1.0
	if is_hero:
		mult_hp = 1.25
		mult_atk = 1.12
	else:
		var hv: float = Game.PIECE_VALUES[other_t]
		var fv: float = Game.PIECE_VALUES[t]
		var k := clampf(0.55 + 0.45 * hv / fv, 0.62, 1.1)
		mult_hp = k
		mult_atk = k
	var spirit := Game.mood_mult(mood) / Game.mood_mult(Game.START_MOOD)
	mult_atk *= spirit
	var f := {
		"type": t,
		"color": color,
		"name": Game.piece_title(t, color),
		"max_hp": int(round(base["hp"] * mult_hp)),
		"max_mp": int(round(base["mp"] * (1.0 if is_hero else maxf(mult_hp, 0.8)))),
		"atk": int(round(base["atk"] * mult_atk)),
		"def": int(round(base["def"] * (spirit if is_hero else mult_atk))),
		"mag": int(round(base["mag"] * mult_atk)),
		"skills": SKILLS[t],
		"guard": false,
		"blind": false,
		"mood": mood,
	}
	for b in buffs:
		if b == "whetstone":
			f["atk"] += 4
		elif b == "ward":
			f["max_hp"] += 25
	f["hp"] = f["max_hp"]
	f["mp"] = f["max_mp"]
	return f
