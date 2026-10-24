extends SceneTree
## Simulates hundreds of graveyard card duels headless: a greedy bot plays the
## player's chess deck (with and without booster cards) against Yugi's AI at
## every difficulty. Checks that every duel terminates, that cards are never
## created or lost, and prints win rates.
## Run: godot --headless --path . -s tests/test_cards.gd

const GAMES := 400

var failures := 0


func _init() -> void:
	_check_data()
	_check_rules()
	var rates := {}
	for diff in 3:
		for boosted in [false, true]:
			var wins := 0
			var timeouts := 0
			var turns := 0
			var hearts := 0
			for i in GAMES:
				seed(1000 + i)
				var deck := CardData.base_deck()
				if boosted:
					deck += CardData.booster() + CardData.booster()
				var g := CardGame.new(deck, CardData.yugi_deck(diff), 7919 * i + diff, diff)
				g.start()
				var res := _play(g)
				if res < 0:
					continue
				if g.winner == CardGame.PLAYER:
					wins += 1
				if g.win_reason == "time":
					timeouts += 1
				if g.heart_used:
					hearts += 1
				turns += g.turn
			var rate := 100.0 * wins / GAMES
			rates["%d%s" % [diff, "b" if boosted else ""]] = rate
			print("difficulty %d %-8s bot wins %5.1f%%  avg turns %4.1f  time-outs %3d  heart %3d" % [
				diff, "boosted" if boosted else "base", rate, float(turns) / GAMES, timeouts, hearts])
	_check_reals()
	# sanity on the tuning: normal sits in the target band, easy <= normal <= hard for Yugi
	if rates["1"] < 40.0 or rates["1"] > 70.0:
		_fail("normal win rate %.1f%% outside 40-70%%" % rates["1"])
	if rates["0"] < rates["2"]:
		_fail("easy Yugi is harder than hard Yugi")
	if rates["1b"] < rates["1"]:
		_fail("booster cards made the player weaker")
	print("CARD TESTS ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures > 0 else 0)


## "For reals": 12,000 LP, the hardest Yugi and a recycling deck. Every duel
## must end, and most should end on Life Points rather than the clock.
func _check_reals() -> void:
	var g0 := CardGame.new(CardData.base_deck(), CardData.yugi_deck(2), 5, 0)
	g0.make_for_reals()
	g0.start()
	if g0.lp != [CardGame.REALS_LP, CardGame.REALS_LP] or g0.difficulty != 2 or g0.max_turns != CardGame.REALS_TURNS:
		_fail("make_for_reals did not set LP / difficulty / turn cap")
	for boosted in [false, true]:
		var wins := 0
		var timeouts := 0
		var turns := 0
		var longest := 0
		var n := 300
		for i in n:
			seed(5000 + i)
			var deck := CardData.base_deck()
			if boosted:
				deck += CardData.booster() + CardData.booster()
			var g := CardGame.new(deck, CardData.yugi_deck(2), 104729 * i + 3, 2)
			g.make_for_reals()
			g.start()
			var res := _play(g)
			if res < 0:
				continue
			if not g.is_over():
				_fail("for-reals duel %d did not finish" % i)
			if g.winner == CardGame.PLAYER:
				wins += 1
			if g.win_reason == "time":
				timeouts += 1
			turns += g.turn
			longest = maxi(longest, g.turn)
		print("for reals %-8s bot wins %5.1f%%  avg turns %4.1f  longest %d  time-outs %d" % [
			"boosted" if boosted else "base", 100.0 * wins / n, float(turns) / n, longest, timeouts])
		if timeouts > n / 10:
			_fail("too many for-reals duels ran out the clock (%d)" % timeouts)


func _fail(msg: String) -> void:
	failures += 1
	print("  FAIL: ", msg)


func _check_data() -> void:
	if CardData.base_deck().size() != 20:
		_fail("base deck has %d cards" % CardData.base_deck().size())
	for diff in 3:
		if CardData.yugi_deck(diff).size() != 20:
			_fail("Yugi deck has %d cards" % CardData.yugi_deck(diff).size())
	for id in CardData.base_deck() + CardData.yugi_deck(2) + CardData.yugi_deck(0) + CardData.BOOSTER_POOL:
		if not CardData.has(id):
			_fail("unknown card " + str(id))
	for id in CardData.all_ids():
		if CardData.card_name(id) == "" or CardData.card_text(id) == "":
			_fail("card without name/text: " + str(id))
		if CardData.is_monster(id) and CardData.atk(id) <= 0:
			_fail("monster without ATK: " + str(id))
	for i in 50:
		var b := CardData.booster()
		if b.size() != 2 or not CardData.has(b[0]) or not CardData.has(b[1]):
			_fail("bad booster " + str(b))


## A few hand-built positions for the trickier rules.
func _check_rules() -> void:
	var g := CardGame.new(CardData.base_deck(), CardData.yugi_deck(), 1, 1)
	g.start()
	if g.hands[0].size() != 4 or g.hands[1].size() != 4:
		_fail("opening hands should be 4 (player skips the first draw)")
	# no attacks on turn 1
	g.hands[0][0] = "rook"
	g.summon(0, 0, 0)
	if g.can_attack(0, 0):
		_fail("attack allowed on duel turn 1")
	if g.summon(0, 0, 1) and CardData.is_monster(g.hands[0][0]):
		_fail("second summon in one turn allowed")
	g.end_turn()
	if g.hands[1].size() != 5:
		_fail("Yugi should draw on his first turn")
	# battle: higher ATK destroys lower and deals the difference
	g.hands[1].append("mummy_sandal")
	g.summon(1, g.hands[1].size() - 1, 0)
	g.attack(1, 0, 0) # 1600 into the 1700 rook
	if g.lp[1] != 3900 or g.has_monster(1, 0) or not g.has_monster(0, 0):
		_fail("battle damage wrong: LP %s" % str(g.lp))
	g.end_turn()
	# direct attack, and Heart of the Cards
	g.lp[1] = 2500
	g.attack(0, 0, -1)
	if not g.heart_used or not g.heart_pending:
		_fail("heart of the cards did not trigger")
	g.end_turn()
	var drawn: String = g.hands[1][g.hands[1].size() - 1]
	var best := 0
	for id in CardData.yugi_deck():
		if CardData.is_monster(id):
			best = maxi(best, CardData.atk(id))
	if CardData.atk(drawn) < best and not g.graves[1].has("sorcerer"):
		_fail("heart draw was %s, not the best monster" % drawn)
	# swords of revealing shine
	g.hands[1].append("swords_shine")
	if not g.cast(1, g.hands[1].size() - 1):
		_fail("could not cast swords")
	g.end_turn()
	if g.can_attack(0, 0):
		_fail("swords did not stop the attack")
	# promotion
	g.hands[0].append("pawn")
	g.summon(0, g.hands[0].size() - 1, 1)
	g.hands[0].append("promotion")
	if not g.cast(0, g.hands[0].size() - 1, 0, 1) or int(g.monster(0, 1)["atk"]) != 2500:
		_fail("promotion failed")
	# turn cap: ties go to Yugi
	var t := CardGame.new(CardData.base_deck(), CardData.yugi_deck(), 2, 1)
	t.start()
	t.turn = CardGame.MAX_TURNS
	t.lp = [3000, 3000]
	t.end_turn()
	if t.winner != CardGame.YUGI or t.win_reason != "time":
		_fail("tie at the turn cap should go to Yugi")


func _play(g: CardGame) -> int:
	var count0 := _cards_owned(g, 0)
	var count1 := _cards_owned(g, 1)
	var guard := 0
	while not g.is_over():
		guard += 1
		if guard > 200:
			_fail("duel did not terminate")
			return -1
		if g.current == CardGame.PLAYER:
			_greedy_turn(g)
		else:
			var steps := 0
			while not g.is_over():
				steps += 1
				var act := g.ai_action(CardGame.YUGI)
				if String(act["type"]) == "end" or steps > 30:
					if steps > 30:
						_fail("Yugi's turn did not end")
					break
				if not g.do_action(CardGame.YUGI, act):
					_fail("Yugi chose an illegal action " + str(act))
					break
		if not g.is_over():
			g.end_turn()
		g.take_events()
		if _cards_owned(g, 0) != count0 or _cards_owned(g, 1) != count1:
			_fail("cards created or lost")
			return -1
		for s in 2:
			if g.monster_count(s) > CardGame.ZONES or int(g.lp[s]) < 0:
				_fail("invalid state")
				return -1
	return g.winner


func _cards_owned(g: CardGame, side: int) -> int:
	var n: int = g.decks[side].size() + g.hands[side].size() + g.graves[side].size()
	for s in 2:
		for m in g.fields[s]:
			if m != null and int(m["owner"]) == side:
				n += 1
	return n


# --- the greedy player bot ---------------------------------------------------------

func _greedy_turn(g: CardGame) -> void:
	var guard := 0
	while not g.is_over() and guard < 40:
		guard += 1
		if not _greedy_step(g):
			return


func _find(g: CardGame, id: String) -> int:
	return g.hands[0].find(id)


func _greedy_step(g: CardGame) -> bool:
	var opp_count := g.monster_count(1)
	# 1. summon: the strongest monster, or a Pawn to promote at once
	if not g.summoned and g.free_zone(0) >= 0:
		var pick := -1
		var promo := _find(g, "promotion")
		if promo >= 0 and not g.spelled and g.spell_targets(0, "promotion").is_empty():
			pick = _find(g, "pawn")
		if pick < 0:
			for i in g.hands[0].size():
				if CardData.is_monster(g.hands[0][i]) and (pick < 0 or CardData.atk(g.hands[0][i]) > CardData.atk(g.hands[0][pick])):
					pick = i
		if pick >= 0:
			return g.summon(0, pick)
	# 2. one spell
	if not g.spelled:
		for id in ["promotion", "driveby", "checkmate", "pink_slip", "en_passant", "sniper", "double_move", "zugzwang"]:
			var hi := _find(g, id)
			if hi < 0 or not g.castable(0, hi):
				continue
			if id == "checkmate":
				var top := 0
				for m in g.fields[1]:
					if m != null:
						top = maxi(top, int(m["atk"]))
				if top < 1300 and opp_count < 2:
					continue
			if not g.spell_needs_target(id):
				return g.cast(0, hi)
			var ts := g.spell_targets(0, id)
			var best: Dictionary = ts[0]
			for t in ts:
				if int(g.monster(int(t["side"]), int(t["zone"]))["atk"]) > int(g.monster(int(best["side"]), int(best["zone"]))["atk"]):
					best = t
			return g.cast(0, hi, int(best["side"]), int(best["zone"]))
	# 3. attacks: strongest first, into the strongest monster it beats
	var order: Array = []
	for z in CardGame.ZONES:
		if g.can_attack(0, z):
			order.append(z)
	order.sort_custom(func(a, b): return int(g.fields[0][a]["atk"]) > int(g.fields[0][b]["atk"]))
	for z in order:
		var a := int(g.fields[0][z]["atk"])
		if g.monster_count(1) == 0:
			return g.attack(0, z, -1)
		var tgt := -1
		for t in CardGame.ZONES:
			var m = g.fields[1][t]
			if m != null and (int(m["atk"]) < a or (int(m["atk"]) == a and a >= 1300)):
				if tgt < 0 or int(m["atk"]) > int(g.fields[1][tgt]["atk"]):
					tgt = t
		if tgt >= 0:
			return g.attack(0, z, tgt)
	# 4. heal with whatever spell slot is left
	if not g.spelled:
		var fm := _find(g, "fifty_move")
		if fm >= 0:
			return g.cast(0, fm)
	return false
