class_name CardGame
extends RefCounted
## Rules engine for the graveyard card duel, plus Yugi's AI. Pure logic: it
## knows nothing about Game or the UI, so it can be simulated headless.
##
## Side 0 is the player (goes first), side 1 is Yugi. Every action appends
## event dictionaries to `events` (key "t" = type) that the screen replays as
## animations; take_events() hands them over and clears the list.
##
## A monster on the field is {"id", "base", "atk", "attacks", "owner", "uid"}:
## id is what it is now (a promoted Pawn becomes "queen"), base is the card
## that goes to the graveyard, attacks is how many attacks it has left.

const START_LP := 4000
const OPENING_HAND := 4
const ZONES := 3
const MAX_TURNS := 30
const HEART_LP := 1500
const PLAYER := 0
const YUGI := 1
const EN_PASSANT_MAX := 1000
const PINK_SLIP_MAX := 1600
## "For reals" (a shadow game): bigger life totals, a longer clock, the
## hardest Yugi, and a deck that never runs dry (see make_for_reals).
const REALS_LP := 12000
const REALS_TURNS := 60
const REALS_HEART_LP := 4500

## How often Yugi fumbles, per difficulty (easy, normal, hard). Each chance is
## rolled once per turn, so a bad decision sticks.
const SLOP := [
	{"random_summon": 0.5, "skip_attack": 0.3, "forget_pot": 0.4, "swords_doubt": 0.6, "blunder": 0.25, "swords_need": 1000, "rerun_gain": 600},
	{"random_summon": 0.2, "skip_attack": 0.1, "forget_pot": 0.0, "swords_doubt": 0.3, "blunder": 0.0, "swords_need": 1200, "rerun_gain": 100},
	{"random_summon": 0.0, "skip_attack": 0.0, "forget_pot": 0.0, "swords_doubt": 0.0, "blunder": 0.0, "swords_need": 700, "rerun_gain": 100},
]

var start_lp := START_LP
var max_turns := MAX_TURNS
var heart_lp := HEART_LP
var for_reals := false
var lp: Array = [START_LP, START_LP]
var decks: Array = [[], []]
var hands: Array = [[], []]
var fields: Array = [[null, null, null], [null, null, null]]
var graves: Array = [[], []]
var turn := 0
var current := PLAYER
var summoned := false
var spelled := false
var attacks_locked := false # Swords of Revealing Shine hit the side whose turn it is
var no_attack_next: Array = [false, false]
var heart_used := false
var heart_pending := false
var winner := -1
var win_reason := ""
var difficulty := 1
var rng := RandomNumberGenerator.new()
var events: Array = []
var _uid := 0
var _memo: Dictionary = {} # per-turn AI decisions (so sloppy choices stick)


func _init(player_deck: Array = [], yugi_deck: Array = [], seed_value: int = -1, diff: int = 1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	difficulty = clampi(diff, 0, 2)
	decks = [player_deck.duplicate(), yugi_deck.duplicate()]


## Turns this duel into a shadow game. Call before start().
func make_for_reals() -> void:
	for_reals = true
	start_lp = REALS_LP
	max_turns = REALS_TURNS
	heart_lp = REALS_HEART_LP
	lp = [REALS_LP, REALS_LP]
	difficulty = 2


## Shuffles, deals the opening hands and begins the player's first turn.
func start() -> void:
	for s in 2:
		_shuffle(decks[s])
	for i in OPENING_HAND:
		for s in 2:
			_draw(s, true)
	_begin_turn(PLAYER)


func take_events() -> Array:
	var out := events
	events = []
	return out


func is_over() -> bool:
	return winner >= 0


# --- queries ---------------------------------------------------------------------

func monster(side: int, zone: int) -> Dictionary:
	if zone < 0 or zone >= ZONES:
		return {}
	var m = fields[side][zone]
	if m == null:
		return {}
	return m


func has_monster(side: int, zone: int) -> bool:
	return zone >= 0 and zone < ZONES and fields[side][zone] != null


func monster_count(side: int) -> int:
	var n := 0
	for m in fields[side]:
		if m != null:
			n += 1
	return n


func free_zone(side: int) -> int:
	for z in ZONES:
		if fields[side][z] == null:
			return z
	return -1


func hand_card(side: int, hi: int) -> String:
	if hi < 0 or hi >= hands[side].size():
		return ""
	return String(hands[side][hi])


func attacks_allowed() -> bool:
	return winner < 0 and turn > 1 and not attacks_locked


func turns_left() -> int:
	return max_turns - turn


func can_summon(side: int, hi: int, zone: int = -1) -> bool:
	if winner >= 0 or side != current or summoned:
		return false
	if not CardData.is_monster(hand_card(side, hi)):
		return false
	if zone >= 0:
		return zone < ZONES and fields[side][zone] == null
	return free_zone(side) >= 0


func can_attack(side: int, zone: int) -> bool:
	if side != current or not attacks_allowed() or not has_monster(side, zone):
		return false
	return int(fields[side][zone]["attacks"]) > 0


## Enemy zones the monster may attack, or [-1] for a direct attack.
func attack_targets(side: int, zone: int) -> Array:
	if not can_attack(side, zone):
		return []
	var opp := 1 - side
	if monster_count(opp) == 0:
		return [-1]
	var out: Array = []
	for z in ZONES:
		if fields[opp][z] != null:
			out.append(z)
	return out


func can_attack_target(side: int, zone: int, target: int) -> bool:
	return attack_targets(side, zone).has(target)


## Valid targets for a spell, as [{"side": s, "zone": z}, ...]. Spells that need
## no target return [] - use can_cast to check them.
func spell_targets(side: int, id: String) -> Array:
	var opp := 1 - side
	var out: Array = []
	match CardData.target_mode(id):
		"own_pawn":
			for z in ZONES:
				var m = fields[side][z]
				if m != null and String(m["id"]) == "pawn":
					out.append({"side": side, "zone": z})
		"own_monster":
			if attacks_allowed():
				for z in ZONES:
					if fields[side][z] != null:
						out.append({"side": side, "zone": z})
		"enemy_low":
			for z in ZONES:
				var m2 = fields[opp][z]
				if m2 != null and int(m2["atk"]) <= EN_PASSANT_MAX:
					out.append({"side": opp, "zone": z})
		"enemy_steal":
			if free_zone(side) >= 0:
				for z in ZONES:
					var m3 = fields[opp][z]
					if m3 != null and int(m3["atk"]) <= PINK_SLIP_MAX:
						out.append({"side": opp, "zone": z})
	return out


func spell_needs_target(id: String) -> bool:
	return CardData.target_mode(id) != "none"


## Whether the spell in hand slot hi could be cast right now (with some target).
func castable(side: int, hi: int) -> bool:
	return why_not_cast(side, hi) == ""


## "" if castable, else a short reason for the prompt line.
func why_not_cast(side: int, hi: int) -> String:
	var id := hand_card(side, hi)
	if not CardData.is_spell(id):
		return "That is not a spell."
	if winner >= 0:
		return "The duel is over."
	if side != current:
		return "Wait for your turn."
	if spelled:
		return "You already cast a spell this turn."
	var opp := 1 - side
	match id:
		"checkmate", "driveby":
			if monster_count(opp) == 0:
				return "There is no enemy monster to destroy."
		"pot_generosity":
			if decks[side].is_empty():
				return "The deck is empty."
		"monster_rerun":
			if _best_grave_monster(side) < 0:
				return "No monster in the graveyard."
		"zugzwang":
			if hands[opp].is_empty():
				return "The opponent's hand is empty."
	if spell_needs_target(id) and spell_targets(side, id).is_empty():
		match CardData.target_mode(id):
			"own_pawn":
				return "You need a Pawn monster on the field."
			"own_monster":
				return "You need a monster that can attack this turn." if attacks_allowed() else "No attacks are allowed this turn."
			"enemy_low":
				return "No enemy monster has 1000 ATK or less."
			"enemy_steal":
				return "You need a free zone and an enemy monster with 1600 ATK or less." if free_zone(side) < 0 or monster_count(opp) == 0 else "No enemy monster has 1600 ATK or less."
		return "No valid target."
	return ""


func can_cast(side: int, hi: int, tside: int = -1, tzone: int = -1) -> bool:
	if not castable(side, hi):
		return false
	var id := hand_card(side, hi)
	if not spell_needs_target(id):
		return true
	for t in spell_targets(side, id):
		if int(t["side"]) == tside and int(t["zone"]) == tzone:
			return true
	return false


# --- actions -----------------------------------------------------------------------

func summon(side: int, hi: int, zone: int = -1) -> bool:
	if not can_summon(side, hi, zone):
		return false
	if zone < 0:
		zone = free_zone(side)
	var id := hand_card(side, hi)
	hands[side].remove_at(hi)
	_uid += 1
	var m := {"id": id, "base": id, "atk": CardData.atk(id), "owner": side, "uid": _uid,
		"attacks": CardData.attacks_per_turn(id)}
	fields[side][zone] = m
	summoned = true
	events.append({"t": "summon", "side": side, "zone": zone, "id": id, "hand": hi})
	return true


func cast(side: int, hi: int, tside: int = -1, tzone: int = -1) -> bool:
	if not can_cast(side, hi, tside, tzone):
		return false
	var id := hand_card(side, hi)
	var opp := 1 - side
	hands[side].remove_at(hi)
	graves[side].append(id)
	spelled = true
	events.append({"t": "spell", "side": side, "id": id, "hand": hi, "tside": tside, "tzone": tzone})
	match id:
		"promotion":
			var m: Dictionary = fields[tside][tzone]
			m["id"] = "queen"
			m["atk"] = CardData.atk("queen")
			events.append({"t": "promote", "side": tside, "zone": tzone})
		"checkmate":
			var best := -1
			for z in ZONES:
				if fields[opp][z] != null and (best < 0 or int(fields[opp][z]["atk"]) > int(fields[opp][best]["atk"])):
					best = z
			_destroy(opp, best)
		"en_passant":
			_destroy(tside, tzone)
		"fifty_move":
			_heal(side, 1000)
		"pot_generosity":
			_draw(side)
			_draw(side)
		"swords_shine":
			no_attack_next[opp] = true
			events.append({"t": "swords", "side": opp})
		"monster_rerun":
			var gi := _best_grave_monster(side)
			var back: String = graves[side][gi]
			graves[side].remove_at(gi)
			hands[side].append(back)
			events.append({"t": "rerun", "side": side, "id": back})
		"driveby":
			var zs: Array = []
			for z in ZONES:
				if fields[opp][z] != null:
					zs.append(z)
			_shuffle(zs)
			for k in mini(2, zs.size()):
				_destroy(opp, int(zs[k]))
		"sniper":
			_damage(opp, 800)
		"double_move":
			var dm: Dictionary = fields[tside][tzone]
			dm["attacks"] = int(dm["attacks"]) + 1
			events.append({"t": "double", "side": tside, "zone": tzone})
		"pink_slip":
			var to := free_zone(side)
			var sm: Dictionary = fields[tside][tzone]
			fields[tside][tzone] = null
			sm["attacks"] = 0
			fields[side][to] = sm
			events.append({"t": "steal", "side": side, "from": tzone, "zone": to, "id": sm["id"]})
		"zugzwang":
			var di := rng.randi_range(0, hands[opp].size() - 1)
			var lost: String = hands[opp][di]
			hands[opp].remove_at(di)
			graves[opp].append(lost)
			events.append({"t": "discard", "side": opp, "id": lost, "hand": di})
	return true


## target = enemy zone, or -1 for a direct attack.
func attack(side: int, zone: int, target: int) -> bool:
	if not can_attack_target(side, zone, target):
		return false
	var opp := 1 - side
	var a: Dictionary = fields[side][zone]
	a["attacks"] = int(a["attacks"]) - 1
	var aa := int(a["atk"])
	if target < 0:
		events.append({"t": "attack", "side": side, "zone": zone, "target": -1, "atk": aa, "def": 0})
		_damage(opp, aa)
		return true
	var d: Dictionary = fields[opp][target]
	var da := int(d["atk"])
	events.append({"t": "attack", "side": side, "zone": zone, "target": target, "atk": aa, "def": da})
	if aa > da:
		_destroy(opp, target)
		_damage(opp, aa - da)
	elif aa < da:
		_destroy(side, zone)
		_damage(side, da - aa)
	else:
		_destroy(opp, target)
		_destroy(side, zone)
	return true


func end_turn() -> void:
	if winner >= 0:
		return
	events.append({"t": "end", "side": current, "turn": turn})
	if turn >= max_turns:
		# time is up: higher LP wins, ties go to Yugi
		_set_winner(PLAYER if int(lp[PLAYER]) > int(lp[YUGI]) else YUGI, "time")
		return
	_begin_turn(1 - current)


# --- internals ---------------------------------------------------------------------

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func _begin_turn(side: int) -> void:
	turn += 1
	current = side
	summoned = false
	spelled = false
	_memo.clear()
	attacks_locked = bool(no_attack_next[side])
	no_attack_next[side] = false
	events.append({"t": "turn", "side": side, "turn": turn, "locked": attacks_locked})
	if turn > 1:
		_draw(side)
	for m in fields[side]:
		if m != null:
			m["attacks"] = CardData.attacks_per_turn(String(m["id"]))


func _draw(side: int, opening: bool = false) -> void:
	var deck: Array = decks[side]
	if deck.is_empty() and for_reals and not graves[side].is_empty():
		# in a shadow game the fallen cards crawl back into the deck
		var n: int = graves[side].size()
		deck.append_array(graves[side])
		graves[side].clear()
		_shuffle(deck)
		events.append({"t": "recycle", "side": side, "count": n})
	if deck.is_empty():
		events.append({"t": "nodraw", "side": side})
		return
	var heart := false
	if side == YUGI and heart_pending and not opening:
		heart_pending = false
		var bi := -1
		for i in deck.size():
			if CardData.is_monster(deck[i]) and (bi < 0 or CardData.atk(deck[i]) > CardData.atk(deck[bi])):
				bi = i
		if bi >= 0:
			var best: String = deck[bi]
			deck.remove_at(bi)
			deck.append(best)
			heart = true
	var id: String = deck.pop_back()
	hands[side].append(id)
	events.append({"t": "draw", "side": side, "id": id, "heart": heart, "opening": opening})


func _destroy(side: int, zone: int) -> void:
	var m = fields[side][zone]
	if m == null:
		return
	fields[side][zone] = null
	graves[int(m["owner"])].append(String(m["base"]))
	events.append({"t": "destroy", "side": side, "zone": zone, "id": m["id"], "atk": m["atk"]})


func _damage(side: int, amount: int) -> void:
	if amount <= 0 or winner >= 0:
		return
	lp[side] = maxi(0, int(lp[side]) - amount)
	events.append({"t": "damage", "side": side, "amount": amount, "lp": lp[side]})
	if int(lp[side]) <= 0:
		_set_winner(1 - side, "lp")
		return
	if side == YUGI and not heart_used and int(lp[side]) < heart_lp:
		heart_used = true
		heart_pending = true
		events.append({"t": "heart", "side": YUGI})


func _heal(side: int, amount: int) -> void:
	lp[side] = int(lp[side]) + amount
	events.append({"t": "heal", "side": side, "amount": amount, "lp": lp[side]})


func _set_winner(w: int, reason: String) -> void:
	if winner >= 0:
		return
	winner = w
	win_reason = reason
	events.append({"t": "win", "winner": w, "reason": reason})


func _best_grave_monster(side: int) -> int:
	var bi := -1
	var g: Array = graves[side]
	for i in g.size():
		if CardData.is_monster(g[i]) and (bi < 0 or CardData.atk(g[i]) > CardData.atk(g[bi])):
			bi = i
	return bi


func _best_hand_monster_atk(side: int) -> int:
	var best := 0
	for id in hands[side]:
		if CardData.is_monster(id):
			best = maxi(best, CardData.atk(id))
	return best


func _field_atks(side: int) -> Array:
	var out: Array = []
	for m in fields[side]:
		if m != null:
			out.append(int(m["atk"]))
	return out


## Rough damage the opponent could deal to `side` on their next turn with the
## monsters already on the field.
func threat_to(side: int) -> int:
	var opp := 1 - side
	var mine := _field_atks(side)
	var dmg := 0
	if mine.is_empty():
		for m in fields[opp]:
			if m != null:
				dmg += int(m["atk"]) * CardData.attacks_per_turn(String(m["id"]))
		return dmg
	mine.sort()
	var weakest: int = mine[0]
	for m in fields[opp]:
		if m != null and int(m["atk"]) > weakest:
			dmg += int(m["atk"]) - weakest
	return dmg


# --- AI -------------------------------------------------------------------------------
# Yugi plays one step at a time: the screen (or a test) calls ai_action(),
# performs it with do_action(), animates, and asks again until "end".

## The next step for `side`: {"type": "summon", "hand", "zone"} /
## {"type": "cast", "hand", "tside", "tzone"} / {"type": "attack", "zone", "target"} /
## {"type": "end"}.
func ai_action(side: int = YUGI) -> Dictionary:
	if winner >= 0 or side != current:
		return {"type": "end"}
	if not spelled:
		var pre := _ai_spell(side, "pre")
		if not pre.is_empty():
			return pre
	if not summoned:
		var s := _ai_summon(side)
		if not s.is_empty():
			return s
	if not spelled:
		var mid := _ai_spell(side, "attack")
		if not mid.is_empty():
			return mid
	var a := _ai_attack(side)
	if not a.is_empty():
		return a
	if not spelled:
		var post := _ai_spell(side, "end")
		if not post.is_empty():
			return post
	return {"type": "end"}


## Performs an action dictionary as returned by ai_action. Returns false if it was illegal.
func do_action(side: int, act: Dictionary) -> bool:
	match String(act.get("type", "end")):
		"summon":
			return summon(side, int(act["hand"]), int(act.get("zone", -1)))
		"cast":
			return cast(side, int(act["hand"]), int(act.get("tside", -1)), int(act.get("tzone", -1)))
		"attack":
			return attack(side, int(act["zone"]), int(act["target"]))
	end_turn()
	return true


func _slop(key: String) -> float:
	return float(SLOP[difficulty][key])


func _roll(key: String, p: float) -> bool:
	## A random decision that sticks for the rest of the turn.
	if p <= 0.0:
		return false
	if not _memo.has(key):
		_memo[key] = rng.randf() < p
	return bool(_memo[key])


func _ai_spell(side: int, phase: String) -> Dictionary:
	var best := {}
	var best_score := 0.0
	var hand: Array = hands[side]
	for i in hand.size():
		var id: String = hand[i]
		if not CardData.is_spell(id) or not castable(side, i):
			continue
		var plan := _ai_eval_spell(side, id, phase)
		var sc: float = plan.get("score", 0.0)
		if sc > best_score:
			best_score = sc
			best = {"type": "cast", "hand": i, "tside": int(plan.get("tside", -1)), "tzone": int(plan.get("tzone", -1))}
	return best


func _ai_eval_spell(side: int, id: String, phase: String) -> Dictionary:
	var opp := 1 - side
	var sharp := difficulty >= 2
	match id:
		"pot_generosity":
			if phase != "pre":
				return {}
			if sharp and hands[side].has("swords_shine") and threat_to(side) >= 1500:
				return {} # keep the spell slot for the swords
			if sharp and _rerun_gain(side) > 0:
				return {}
			if _roll("forget_pot", _slop("forget_pot")):
				return {}
			return {"score": 50.0}
		"monster_rerun":
			if phase != "pre" or summoned or free_zone(side) < 0:
				return {}
			var gain := _rerun_gain(side)
			if gain <= int(_slop("rerun_gain")):
				return {}
			return {"score": 40.0 + gain / 50.0}
		"swords_shine":
			if phase != "end":
				return {}
			var th := threat_to(side)
			if th >= int(_slop("swords_need")) or th >= int(lp[side]):
				if _roll("swords_doubt", _slop("swords_doubt")):
					return {}
				return {"score": 70.0}
			return {}
		# --- the player's cards (lets the AI play either side in tests) ---
		"promotion":
			if phase != "attack":
				return {}
			var t := spell_targets(side, id)
			return {"score": 80.0, "tside": t[0]["side"], "tzone": t[0]["zone"]}
		"checkmate":
			if phase != "attack":
				return {}
			var top := 0
			for v in _field_atks(opp):
				top = maxi(top, int(v))
			var mine := 0
			for v2 in _field_atks(side):
				mine = maxi(mine, int(v2))
			if top >= 1300 or top >= mine:
				return {"score": 60.0 + top / 100.0}
			return {}
		"en_passant":
			if phase != "attack":
				return {}
			var bt := {}
			for t2 in spell_targets(side, id):
				if bt.is_empty() or int(monster(opp, int(t2["zone"]))["atk"]) > int(monster(opp, int(bt["zone"]))["atk"]):
					bt = t2
			return {"score": 40.0 + int(monster(opp, int(bt["zone"]))["atk"]) / 50.0, "tside": bt["side"], "tzone": bt["zone"]}
		"fifty_move":
			if phase != "end":
				return {}
			return {"score": 20.0}
		"driveby":
			if phase != "attack":
				return {}
			return {"score": 40.0 + 15.0 * mini(2, monster_count(opp))}
		"sniper":
			if phase != "attack":
				return {}
			return {"score": 100.0 if int(lp[opp]) <= 800 else 45.0}
		"double_move":
			if phase != "attack":
				return {}
			var bz := -1
			for t3 in spell_targets(side, id):
				var z := int(t3["zone"])
				if bz < 0 or int(monster(side, z)["atk"]) > int(monster(side, bz)["atk"]):
					bz = z
			if bz >= 0:
				return {"score": 45.0, "tside": side, "tzone": bz}
			return {}
		"pink_slip":
			if phase != "attack":
				return {}
			var bs := {}
			for t4 in spell_targets(side, id):
				if bs.is_empty() or int(monster(opp, int(t4["zone"]))["atk"]) > int(monster(opp, int(bs["zone"]))["atk"]):
					bs = t4
			return {"score": 40.0 + int(monster(opp, int(bs["zone"]))["atk"]) / 50.0, "tside": bs["side"], "tzone": bs["zone"]}
		"zugzwang":
			if phase != "pre":
				return {}
			return {"score": 30.0}
	return {}


func _rerun_gain(side: int) -> int:
	var gi := _best_grave_monster(side)
	if gi < 0:
		return 0
	return CardData.atk(graves[side][gi]) - _best_hand_monster_atk(side)


func _ai_summon(side: int) -> Dictionary:
	var zone := free_zone(side)
	if zone < 0:
		return {}
	var mons: Array = []
	for i in hands[side].size():
		if CardData.is_monster(hands[side][i]):
			mons.append(i)
	if mons.is_empty():
		return {}
	var pick: int = mons[0]
	for i in mons:
		if CardData.atk(hands[side][i]) > CardData.atk(hands[side][pick]):
			pick = i
	if _roll("random_summon", _slop("random_summon")):
		pick = mons[rng.randi_range(0, mons.size() - 1)]
	return {"type": "summon", "hand": pick, "zone": zone}


func _ai_attack(side: int) -> Dictionary:
	if not attacks_allowed():
		return {}
	var opp := 1 - side
	var sloppy := difficulty == 0
	var sharp := difficulty >= 2
	var attackers: Array = []
	for z in ZONES:
		if can_attack(side, z) and not bool(_memo.get("hold%d" % z, false)):
			attackers.append(z)
	if attackers.is_empty():
		return {}
	var f: Array = fields[side]
	var g: Array = fields[opp]
	attackers.sort_custom(func(x, y): return int(f[x]["atk"]) > int(f[y]["atk"]))
	var targets: Array = []
	for z in ZONES:
		if g[z] != null:
			targets.append(z)
	if targets.is_empty():
		return {"type": "attack", "zone": attackers[0], "target": -1}
	targets.sort_custom(func(x, y): return int(g[x]["atk"]) > int(g[y]["atk"]))
	if sharp:
		# kill the most valuable target with the weakest monster that beats it
		for t in targets:
			for k in range(attackers.size() - 1, -1, -1):
				var a: int = attackers[k]
				if int(f[a]["atk"]) > int(g[t]["atk"]):
					return {"type": "attack", "zone": a, "target": t}
	else:
		for a in attackers:
			for t in targets:
				if int(f[a]["atk"]) > int(g[t]["atk"]):
					if _roll("skip%d" % a, _slop("skip_attack")):
						_memo["hold%d" % a] = true
						break
					return {"type": "attack", "zone": a, "target": t}
	# even trades
	for a in attackers:
		for t in targets:
			if int(f[a]["atk"]) == int(g[t]["atk"]):
				var worth := int(g[t]["atk"]) >= (1000 if sharp else 1400)
				if sloppy:
					worth = _roll("trade%d" % a, 0.5)
				if worth:
					return {"type": "attack", "zone": a, "target": t}
	# easy Yugi sometimes charges into a stronger monster
	if not _memo.has("blundered") and _roll("blunder", _slop("blunder")):
		_memo["blundered"] = true
		return {"type": "attack", "zone": attackers[0], "target": targets[0]}
	return {}
