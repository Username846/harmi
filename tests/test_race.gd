extends SceneTree
## Pink slip race balance check: drives RaceSim with scripted drivers.
## Run: godot --headless --path . -s tests/test_race.gd

const DT := 1.0 / 60.0
const N := 60

## react: seconds after green to tap GO; shift: rpm to shift at (-1 = never,
## let the box auto-shift on the limiter); jitter: sigma of the shift rpm;
## jump: tap GO during the ambers; nos: use the nitrous in top gear.
const POLICIES := {
	"perfect": {"react": 0.18, "shift": 0.835, "jitter": 0.0},
	"good": {"react": 0.25, "shift": 0.84, "jitter": 0.03},
	"average": {"react": 0.32, "shift": 0.82, "jitter": 0.06},
	"sloppy": {"react": 0.45, "shift": 0.68, "jitter": 0.04},
	"lazy": {"react": 0.55, "shift": -1.0, "jitter": 0.0},
	"jumper": {"react": 0.2, "shift": 0.84, "jitter": 0.03, "jump": true},
}

var fails := 0


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	_sanity()
	_table()
	_checks()
	print("race tests done in %d ms, failures: %d" % [Time.get_ticks_msec() - t0, fails])
	quit(1 if fails > 0 else 0)


func race(hero_t: int, foe_t: int, hmood: float, fmood: float, diff: int, pol: Dictionary, seed_value: int, nos: bool = false) -> RaceSim:
	var sim := RaceSim.new(hero_t, foe_t, hmood, fmood, diff, nos, seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13
	var react: float = pol["react"]
	var shift_at: float = pol["shift"]
	var jitter: float = pol.get("jitter", 0.0)
	var jump: bool = pol.get("jump", false)
	var target := shift_at + rng.randfn(0.0, jitter)
	var tapped := false
	sim.start_tree()
	var t := 0.0
	while not sim.finished() and t < 90.0:
		sim.step(DT)
		t += DT
		if not tapped and ((jump and sim.clock > 0.3) or sim.race_time() >= react):
			sim.press_go()
			tapped = true
		if sim.hero.launched and shift_at > 0.0 and sim.hero.gear < RaceSim.GEARS and sim.hero.rpm >= target:
			if sim.press_shift() != "":
				target = shift_at + rng.randfn(0.0, jitter)
		if nos and sim.hero.gear == RaceSim.GEARS and sim.can_nos():
			sim.press_nos()
		sim.pop_events()
	return sim


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		fails += 1


## win rate and mean times for one matchup
func _cell(hero_t: int, foe_t: int, hmood: float, fmood: float, diff: int, pol_name: String, nos: bool = false) -> Dictionary:
	var wins := 0
	var ht := 0.0
	var ft := 0.0
	var worst := 0.0
	for s in N:
		var sim := race(hero_t, foe_t, hmood, fmood, diff, POLICIES[pol_name], s + 1, nos)
		if sim.hero_won():
			wins += 1
		ht += sim.hero.finish
		ft += sim.foe.finish
		worst = maxf(worst, maxf(sim.hero.finish, sim.foe.finish))
	return {"win": float(wins) / N, "hero": ht / N, "foe": ft / N, "worst": worst}


func _sanity() -> void:
	print("--- sanity")
	var sim := race(2, 4, 72.0, 72.0, 1, POLICIES["perfect"], 42)
	print("  knight vs rook, perfect driving: %.2f s vs %.2f s, reaction %.3f, shifts %s / rival %s" % [
		sim.hero.finish, sim.foe.finish, sim.hero.reaction, sim.hero.shifts, sim.foe.shifts])
	_check(sim.finished(), "race finishes")
	_check(sim.hero.shifts == ["perfect", "perfect", "perfect"], "scripted perfect shifts register as perfect")
	_check(sim.hero.gear == 4 and sim.foe.gear == 4, "both cars reach top gear")
	var idle := RaceSim.new(3, 3, 50.0, 50.0, 1, false, 7)
	idle.run_to_end()
	print("  no input at all: %.2f s (auto launch + limiter auto shifts %s)" % [idle.hero.finish, idle.hero.shifts])
	_check(idle.hero.done() and idle.hero.finish < 25.0, "a player who does nothing still finishes in < 25 s")
	var jump := race(2, 4, 72.0, 72.0, 1, POLICIES["jumper"], 42)
	_check(jump.hero.false_start and jump.hero.finish > sim.hero.finish + 0.5, "false start costs time (%.2f vs %.2f)" % [jump.hero.finish, sim.hero.finish])
	var with_nos := race(2, 4, 72.0, 72.0, 1, POLICIES["perfect"], 42, true)
	_check(with_nos.hero.nos_used and with_nos.hero.finish < sim.hero.finish - 0.1, "nitrous helps (%.2f vs %.2f)" % [with_nos.hero.finish, sim.hero.finish])
	var no_nos := RaceSim.new(2, 4, 72.0, 72.0, 1, false, 1)
	no_nos.start_tree()
	_check(not no_nos.press_nos(), "no NOS without a bottle")
	var happy := RaceSim.new(1, 1, 100.0, 50.0, 1, false, 1)
	var sad := RaceSim.new(1, 1, 0.0, 50.0, 1, false, 1)
	_check(absf(happy.hero.power / RaceSim.power_of(1) - 1.06) < 0.001 and absf(sad.hero.power / RaceSim.power_of(1) - 0.94) < 0.001, "hero mood nudges power by +-6%")
	_check(RaceSim.shift_quality(0.6) == "early" and RaceSim.shift_quality(0.84) == "perfect" and RaceSim.shift_quality(0.95) == "late" and RaceSim.shift_quality(1.0) == "redline", "shift quality zones")


func _table() -> void:
	print("--- win rates (%d races each), hero mood 72, rival mood 72" % N)
	for diff in 3:
		print("difficulty %d" % diff)
		for pol_name in ["perfect", "good", "average", "sloppy", "lazy"]:
			var line := "  %-8s" % pol_name
			for pair in [[1, 5], [5, 1], [2, 4], [3, 3], [4, 2]]:
				var c := _cell(pair[0], pair[1], 72.0, 72.0, diff, pol_name)
				line += "  %s v %s: %3d%% (%.2f/%.2f)" % [_short(pair[0]), _short(pair[1]), int(round(c["win"] * 100.0)), c["hero"], c["foe"]]
			print(line)
	print("--- rival mood effect (good pawn vs queen, normal)")
	for fm in [100.0, 72.0, 45.0, 20.0, 0.0]:
		var c2 := _cell(1, 5, 72.0, fm, 1, "good")
		print("  rival mood %3d: win %3d%%  rival avg %.2f s" % [int(fm), int(round(c2["win"] * 100.0)), c2["foe"]])


func _short(t: int) -> String:
	return ["", "P", "N", "B", "R", "Q"][t]


func _checks() -> void:
	print("--- balance checks")
	var a := _cell(1, 5, 72.0, 72.0, 1, "perfect")
	_check(a["win"] >= 0.9, "perfect pawn beats normal queen (%d%%)" % int(a["win"] * 100.0))
	var b := _cell(1, 5, 50.0, 72.0, 1, "good")
	_check(b["win"] >= 0.6, "good pawn usually beats normal queen (%d%%)" % int(b["win"] * 100.0))
	var c := _cell(5, 1, 72.0, 72.0, 1, "sloppy")
	_check(c["win"] <= 0.35, "sloppy queen usually loses to normal pawn (%d%%)" % int(c["win"] * 100.0))
	var d := _cell(1, 5, 72.0, 100.0, 2, "good")
	_check(d["win"] < 0.85 and d["win"] > 0.05, "hard elated queen is a real fight for a good pawn (%d%%)" % int(d["win"] * 100.0))
	var e := _cell(3, 3, 72.0, 72.0, 0, "average")
	_check(e["win"] > 0.5, "average driving wins on easy (%d%%)" % int(e["win"] * 100.0))
	var gl := _cell(1, 5, 72.0, 10.0, 1, "average")
	var hp := _cell(1, 5, 72.0, 95.0, 1, "average")
	_check(gl["win"] > hp["win"], "gloomy rivals drive worse (%d%% vs %d%%)" % [int(gl["win"] * 100.0), int(hp["win"] * 100.0)])
	var sane := true
	var lo := 99.0
	var hi := 0.0
	for diff in 3:
		for pol_name in POLICIES.keys():
			for t in range(1, 6):
				var sim := race(t, 6 - t, 72.0, 50.0, diff, POLICIES[pol_name], diff * 31 + t)
				lo = minf(lo, minf(sim.hero.finish, sim.foe.finish))
				hi = maxf(hi, maxf(sim.hero.finish, sim.foe.finish))
				if not sim.finished():
					sane = false
	_check(sane and lo > 7.0 and hi < 22.0, "all races finish in a sane time (%.2f .. %.2f s)" % [lo, hi])
	var won := 0
	var lost := 0
	for s in 40:
		var sim2 := race(2, 4, 72.0, 72.0, 1, POLICIES["average"], 500 + s)
		if sim2.hero_won():
			won += 1
		else:
			lost += 1
	_check(won > 0 and lost > 0, "both outcomes reachable with average driving (%d won / %d lost)" % [won, lost])
