extends RefCounted
## Scripted survival players for the balance tests: careful, careless and passive.

const ITEM_VALUE := {"food": 3.0, "water": 3.0, "dirty_water": 1.0, "tablets": 1.5, "rad_pills": 3.0, "bandage": 1.5,
	"first_aid": 3.0, "battery": 2.5, "radio_part": 3.0, "fuel": 2.0, "flare": 2.5, "paint": 2.0, "mirror": 2.0,
	"beyblade": 0.1, "pawn": 0.1, "gourd": 0.5}
const MAX_DAYS := 60


## Eats, drinks and patches up when it should (free actions).
func _upkeep(s: SurvivalSim) -> void:
	var guard := 0
	while s.water < 45.0 and guard < 6:
		guard += 1
		if s.has("water"):
			s.use_item("water")
		elif s.has("tablets") and s.has("dirty_water"):
			s.use_item("tablets")
		elif s.has("dirty_water") and (s.water < 25.0 or s.rad < 25.0):
			s.use_item("dirty_water")
		else:
			break
	guard = 0
	while s.food < 45.0 and s.has("food") and guard < 4:
		guard += 1
		s.use_item("food")
	if s.food < 18.0 and s.has("gourd"):
		s.use_item("gourd")
	if s.rad > 38.0 and s.has("rad_pills"):
		s.use_item("rad_pills")
	if s.health < 40.0 and s.has("first_aid"):
		s.use_item("first_aid")
	elif s.health < 60.0 and s.has("bandage"):
		s.use_item("bandage")
	elif s.health < 50.0 and s.has("first_aid"):
		s.use_item("first_aid")


func _need(s: SurvivalSim, id: String) -> float:
	match id:
		"food":
			return 3.0 if s.food + s.count("food") * 30.0 < 130.0 else 0.8
		"water":
			return 3.0 if s.water + s.count("water") * 30.0 < 140.0 else 0.8
		"dirty_water":
			return 1.2 if s.water + (s.count("water") + s.count("dirty_water")) * 30.0 < 120.0 else 0.2
		"radio_part":
			return 7.0 if not s.radio_built and s.count("radio_part") < 3 else 0.0
		"battery":
			if not s.radio_built:
				return 3.0 if s.count("battery") < 1 else 1.2
			return 3.0 if s.radio_charge + s.count("battery") * 3 < 3 else 1.0
		"paint":
			return 3.0 if not s.sos_painted and not s.has("paint") else 0.0
		"mirror":
			return 2.5 if not s.has("mirror") else 0.0
		"flare":
			return 2.5 if s.count("flare") < 2 else 0.4
		"fuel":
			return 1.5
		"rad_pills":
			return 3.0 if s.count("rad_pills") < 2 else 1.0
		"first_aid":
			return 2.5
		"bandage":
			return 1.5
		"tablets":
			return 1.0
	return 0.0


func _loc_score(s: SurvivalSim, id: String) -> float:
	if s.reason_scavenge(id) != "":
		return -99.0
	var L: Dictionary = SurvivalSim.LOCS[id]
	var p: Dictionary = s.pools[id]
	var total := 0
	var val := 0.0
	for k in p:
		total += int(p[k])
		val += _need(s, k) * int(p[k])
	var expected := 0.0
	if total > 0:
		expected = val / total * minf(float(SurvivalSim.FINDS_MIN[s.difficulty]) + 0.4, float(total))
	if L.has("renew"):
		expected += _need(s, "dirty_water") * 2.0
	var dose: float = float(L["rad"]) + (SurvivalSim.ASH_DOSE if s.weather == "ash" else 0.0)
	var rad_cost := dose * (0.05 + s.rad / 300.0) * (2.0 if s.count("rad_pills") == 0 else 1.0)
	var slots: int = int(L["slots"])
	var danger_cost := float(L["danger"]) * (0.3 if s.health > 60.0 else 0.8)
	return (expected - rad_cost - danger_cost) / float(slots)


func careful(s: SurvivalSim) -> void:
	if not s.pending.is_empty():
		var p := s.pending
		var give_v: float = ITEM_VALUE.get(p["give"], 1.0) * int(p["give_n"])
		var get_v: float = ITEM_VALUE.get(p["get"], 1.0) * int(p["get_n"])
		s.answer_trade(get_v > give_v)
		return
	_upkeep(s)
	if s.over:
		return
	if s.slot >= SurvivalSim.SLOTS_PER_DAY:
		s.sleep()
		return
	if s.heli_today and s.has("flare") and s.flare_day != s.day:
		s.do_action("flare")
		return
	for a in ["build_radio", "broadcast", "paint", "mirror"]:
		if s.reason_action(a) == "":
			s.do_action(a)
			return
	if s.health < 45.0 and not s.has("bandage") and not s.has("first_aid"):
		s.do_action("rest")
		return
	if s.count("dirty_water") >= 2 and not s.has("tablets") and s.water + s.count("water") * 30.0 < 80.0:
		s.do_action("purify")
		return
	if s.reason_action("fire") == "" and (s.count("fuel") >= 2 or s.tower_uses > 0 or s.radio_built):
		s.do_action("fire")
		return
	# the big transmitter, when there's power to spare and the dose is bearable
	var spare := s.count("battery") + s.count("fuel") - (0 if s.radio_built else 1)
	if spare > 0 and s.reason_action("tower_broadcast") == "" and (s.rad < 30.0 or s.has("rad_pills")) and s.health > 45.0:
		s.do_action("tower_broadcast")
		return
	var best := ""
	var best_v := 0.6
	for id in SurvivalSim.LOC_ORDER:
		var v := _loc_score(s, id)
		if v > best_v:
			best_v = v
			best = id
	if best != "":
		s.scavenge(best)
		return
	if s.reason_action("fire") == "":
		s.do_action("fire")
		return
	if s.health < 90.0:
		s.do_action("rest")
		return
	s.sleep()


func careless(s: SurvivalSim, rng: RandomNumberGenerator) -> void:
	if not s.pending.is_empty():
		s.answer_trade(rng.randf() < 0.5)
		return
	if s.water < 15.0:
		if s.has("water"):
			s.use_item("water")
		elif s.has("dirty_water"):
			s.use_item("dirty_water")
	if s.food < 15.0 and s.has("food"):
		s.use_item("food")
	if s.slot >= SurvivalSim.SLOTS_PER_DAY:
		s.sleep()
		return
	var opts: Array = []
	for id in SurvivalSim.LOC_ORDER:
		if s.reason_scavenge(id) == "":
			opts.append(id)
	if opts.is_empty():
		s.sleep()
		return
	s.scavenge(opts[rng.randi_range(0, opts.size() - 1)])


func passive(s: SurvivalSim) -> void:
	if not s.pending.is_empty():
		s.answer_trade(false)
		return
	if s.water < 20.0 and s.has("water"):
		s.use_item("water")
	if s.food < 20.0 and s.has("food"):
		s.use_item("food")
	if s.health < 60.0 and s.has("bandage"):
		s.use_item("bandage")
	s.sleep()


func play(kind: String, diff: int, seed_value: int) -> SurvivalSim:
	var s := SurvivalSim.new(diff, seed_value, "Testville")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var steps := 0
	while not s.over and s.day <= MAX_DAYS and steps < 2000:
		steps += 1
		match kind:
			"careful":
				careful(s)
			"careless":
				careless(s, rng)
			_:
				passive(s)
		s.pop_log()
	return s


