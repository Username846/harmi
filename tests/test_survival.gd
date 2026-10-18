extends SceneTree
## Survival balance check: drives SurvivalSim with scripted players (see
## survival_bots.gd): careful, careless and passive, across seeds and difficulties.
## Run: godot --headless --path . -s tests/test_survival.gd

const N := 300

var fails := 0
var bots = preload("res://tests/survival_bots.gd").new()


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	_sanity()
	_table()
	print("survival tests done in %d ms, failures: %d" % [Time.get_ticks_msec() - t0, fails])
	quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


# --- checks ------------------------------------------------------------------------------

func _sanity() -> void:
	print("sanity")
	var s := SurvivalSim.new(1, 5, "Springfield")
	_check(s.day == 1 and s.slot == 0 and s.health == 100.0, "starts on Day 1 morning at full health")
	_check(s.count("food") == 1 and s.count("water") == 1 and s.count("bandage") == 1, "starts with a can, a bottle and a bandage")
	var opening: Array = s.pop_log()
	_check(not opening.is_empty() and String(opening[0]["text"]).contains("Springfield is gone"), "opening names the town")
	_check(s.reason_scavenge("ground_zero") == "", "can reach Ground Zero in the morning")
	_check(s.loc_name("school") == "Springfield Elementary", "school is named after the town")
	_check(s.reason_action("broadcast") != "", "can't broadcast without a radio")
	var f0 := s.food
	s.use_item("food")
	_check(s.food == minf(100.0, f0 + 30.0) and s.slot == 0, "eating uses no slot")
	s.scavenge("store")
	_check(s.slot == 1, "a near trip takes one slot")
	s.scavenge("police")
	_check(s.slot == 0 and s.day == 2 or s.over or not s.pending.is_empty() or s.night_due, "a far trip in the afternoon brings the night")
	if s.night_due:
		s.answer_trade(false)
	_check(s.day == 2 or s.over, "night passed, now day 2")
	var s2 := SurvivalSim.new(1, 9)
	s2.slot = 2
	_check(s2.reason_scavenge("ground_zero") != "", "far trips refused in the evening")
	_check(s2.reason_scavenge("store") == "", "near trips allowed in the evening")
	# radio: build and broadcast
	var s3 := SurvivalSim.new(1, 11)
	s3.add_item("radio_part", 3)
	s3.add_item("battery")
	_check(s3.reason_action("build_radio") == "", "can build a radio with 3 parts and a battery")
	s3.do_action("build_radio")
	_check(s3.radio_built and s3.count("radio_part") == 0 and s3.count("battery") == 0, "building uses the parts and battery")
	var r0 := s3.rescue
	s3.do_action("broadcast")
	_check(s3.rescue > r0 and s3.slot == 2, "broadcast raises rescue and uses a slot")
	_check(s3.reason_action("broadcast") != "", "one broadcast a day")
	# dirty water and tablets
	var s4 := SurvivalSim.new(1, 12)
	s4.add_item("dirty_water", 4)
	s4.add_item("tablets")
	s4.use_item("tablets")
	_check(s4.count("dirty_water") == 1 and s4.count("water") == 4, "tablets purify 3 dirty water")
	var rad0 := s4.rad
	s4.use_item("dirty_water")
	_check(s4.rad > rad0, "dirty water is radioactive")
	# flare on a helicopter day
	var s5 := SurvivalSim.new(1, 13)
	s5.add_item("flare", 2)
	s5.heli_today = true
	s5.do_action("flare")
	var heli_gain := s5.rescue
	s5.heli_today = false
	s5.do_action("flare")
	_check(heli_gain >= 20.0 and s5.rescue - heli_gain < 5.0, "flares matter on helicopter days (%.0f vs %.0f)" % [heli_gain, s5.rescue - heli_gain])
	# loot runs out
	var s6 := SurvivalSim.new(1, 14)
	for i in 12:
		s6.slot = 0
		s6.health = 100.0
		s6.rad = 0.0
		s6.scavenge("pharmacy")
		if not s6.pending.is_empty():
			s6.answer_trade(false)
		if s6.over:
			break
	_check(s6.picked_over("pharmacy"), "the pharmacy gets picked over")
	_check(not s6.picked_over("water_tower"), "the water tower never runs dry")
	# determinism
	var a: SurvivalSim = bots.play("careful", 1, 77)
	var b: SurvivalSim = bots.play("careful", 1, 77)
	_check(a.result == b.result and a.day == b.day and is_equal_approx(a.rescue, b.rescue), "same seed, same game")


func _table() -> void:
	print("\n%-9s %-6s %8s %8s %8s %8s %8s" % ["player", "diff", "rescued", "resc.day", "died", "die.day", "maxday"])
	var res := {}
	for kind in ["careful", "careless", "passive"]:
		for diff in 3:
			var rescued := 0
			var died := 0
			var rday := 0.0
			var dday := 0.0
			var maxday := 0
			var ended := true
			var causes := {}
			for i in N:
				var s: SurvivalSim = bots.play(kind, diff, 1000 + i)
				if not s.over:
					ended = false
				maxday = maxi(maxday, s.day)
				if s.result == "rescued":
					rescued += 1
					rday += s.day
				elif s.result == "died":
					died += 1
					dday += s.day
					causes[s.cause] = int(causes.get(s.cause, 0)) + 1
			var r := {"rescue": float(rescued) / N, "rday": rday / maxf(1.0, rescued), "died": float(died) / N,
				"dday": dday / maxf(1.0, died), "ended": ended, "maxday": maxday}
			res[kind + str(diff)] = r
			print("%-9s %-6s %7.0f%% %8.1f %7.0f%% %8.1f %8d   %s" % [kind, ["easy", "normal", "hard"][diff], r["rescue"] * 100.0,
				r["rday"], r["died"] * 100.0, r["dday"], maxday, str(causes)])
	print("")
	for k in res:
		_check(bool(res[k]["ended"]), "%s: every game ends" % k)
	var c1: Dictionary = res["careful1"]
	_check(c1["rescue"] >= 0.6 and c1["rescue"] <= 0.9, "careful player rescued 60-90%% on normal (%.0f%%)" % (c1["rescue"] * 100.0))
	_check(c1["rday"] >= 6.0 and c1["rday"] <= 9.0, "careful rescue around day 6-9 on normal (%.1f)" % c1["rday"])
	_check(float(res["careful0"]["rescue"]) >= c1["rescue"], "easy is kinder than normal")
	_check(float(res["careful2"]["rescue"]) <= c1["rescue"], "hard is harsher than normal")
	_check(float(res["careful2"]["rescue"]) >= 0.3, "hard is still winnable (%.0f%%)" % (float(res["careful2"]["rescue"]) * 100.0))
	var x1: Dictionary = res["careless1"]
	_check(x1["died"] >= 0.85, "careless player usually dies on normal (%.0f%%)" % (x1["died"] * 100.0))
	_check(x1["dday"] >= 3.0 and x1["dday"] <= 5.5, "careless player dies around day 3-5 (%.1f)" % x1["dday"])
	for diff in 3:
		_check(float(res["passive" + str(diff)]["rescue"]) == 0.0, "waiting it out never wins (%s)" % ["easy", "normal", "hard"][diff])
