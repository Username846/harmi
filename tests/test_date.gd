extends SceneTree
## Validates the date minigame data: dialogue, venue preferences, delta math.
## Pure DateData only (autoloads aren't compiled in -s mode); the screen flow
## is covered by tests/date_flow.tscn.
## Run: godot --headless --path . -s tests/test_date.gd

var fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)


func _check_prompt(p: Dictionary, where: String) -> void:
	_check(p.has("q") and String(p.get("q", "")).length() > 5, where + ": missing the date's line")
	var a: Array = p.get("a", [])
	_check(a.size() == 3, where + ": needs exactly 3 replies")
	var seen: Array = []
	for rep in a:
		var r: Array = rep
		_check(r.size() == 3, where + ": reply must be [text, score, reaction]")
		if r.size() != 3:
			continue
		_check(r[0] is String and String(r[0]).length() > 2, where + ": reply text")
		_check(r[1] is int, where + ": reply score must be an int")
		_check(r[2] is String and String(r[2]).length() > 2, where + ": reaction text")
		seen.append(r[1])
	seen.sort()
	_check(seen == [-1, 1, 2], where + ": scores must be one each of +2, +1 and -1, got " + str(seen))


func _init() -> void:
	_data_tests()
	_done()


func _data_tests() -> void:
	# dialogue
	for t in range(1, 7):
		var ps: Array = DateData.PROMPTS.get(t, [])
		_check(ps.size() >= 4, "type %d needs at least 4 prompts (has %d)" % [t, ps.size()])
		for i in ps.size():
			_check_prompt(ps[i], "type %d prompt %d" % [t, i])
		var prefs: Dictionary = DateData.PREFS.get(t, {})
		for v in DateData.VENUES:
			_check(prefs.has(v["id"]), "type %d has no preference for %s" % [t, v["id"]])
			_check(DateData.pref_line(t, v["id"]).length() > 5, "type %d has no arrival line for %s" % [t, v["id"]])
		_check(DateData.CLOSE_GREAT.has(t) and DateData.CLOSE_BAD.has(t), "type %d closing lines" % t)
	_check(DateData.GENERIC.size() >= 5, "need at least 5 generic prompts")
	for i in DateData.GENERIC.size():
		_check_prompt(DateData.GENERIC[i], "generic prompt %d" % i)

	# venues and prices
	var prices := {}
	for v in DateData.VENUES:
		prices[v["id"]] = v["price"]
		_check(int(v["base"]) > 0, "venue %s needs a positive base boost" % v["id"])
	_check(prices == {"park": 0, "bowling": 6, "dinner": 15, "cruise": 9}, "venue prices: " + str(prices))
	_check(DateData.venue("dinner")["base"] > DateData.venue("park")["base"], "dinner beats a picnic")

	# preferences
	_check(DateData.pref_bonus(6, "cruise", 80.0) < 0, "kings feel unsafe on boats")
	_check(DateData.pref_bonus(3, "cruise", 80.0) > 0, "bishops adore the ash cruise")
	_check(DateData.pref_bonus(4, "dinner", 80.0) > 0, "rooks like the castle restaurant")
	_check(DateData.pref_bonus(2, "park", 80.0) > 0, "knights like the park")
	_check(DateData.pref_bonus(5, "dinner", 80.0) > 0, "queens expect dinner")
	for v in DateData.VENUES:
		_check(DateData.pref_bonus(1, v["id"], 80.0) > 0, "pawns are delighted by anything (%s)" % v["id"])
	_check(DateData.pref_bonus(4, "cruise", 30.0) == DateData.pref_bonus(4, "cruise", 80.0) + DateData.GLOOMY_CRUISE_BONUS,
		"gloomy pieces adore the cruise")
	_check(DateData.pref_bonus(4, "dinner", 30.0) == DateData.pref_bonus(4, "dinner", 80.0), "gloom only matters on the cruise")

	# delta math
	_check(DateData.compute_delta(4, 0, 0) == 4, "plain picnic")
	_check(DateData.compute_delta(9, 3, 2) == 24, "9 + 3 + 6*2")
	_check(DateData.compute_delta(16, 9, 6) == DateData.MAX_DELTA, "clamps high")
	_check(DateData.compute_delta(0, -10, -3) == DateData.MIN_DELTA, "clamps low")
	_check(DateData.MIN_DELTA == -10 and DateData.MAX_DELTA == 45, "clamp range")
	for t in range(1, 7):
		for v in DateData.VENUES:
			for mood in [10.0, 80.0]:
				var b := DateData.pref_bonus(t, v["id"], mood)
				for sum in range(-3, 7):
					var d := DateData.compute_delta(int(v["base"]), b, sum)
					_check(d >= DateData.MIN_DELTA and d <= DateData.MAX_DELTA, "delta in range")
				_check(DateData.compute_delta(int(v["base"]), b, 6) > 0, "a perfect date always helps (type %d at %s)" % [t, v["id"]])

	# prompt picking
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for t in range(1, 7):
		var typed: Array = DateData.PROMPTS[t]
		for n in 25:
			var picked := DateData.pick_prompts(t, rng)
			_check(picked.size() == DateData.ROUNDS, "three rounds")
			_check(typed.has(picked[0]) and typed.has(picked[2]), "two typed prompts")
			_check(DateData.GENERIC.has(picked[1]), "one generic prompt")
			_check(picked[0] != picked[2], "typed prompts differ")
			var reps := DateData.shuffled_replies(picked[0], rng)
			var sc: Array = []
			for r in reps:
				sc.append(r[1])
			sc.sort()
			_check(sc == [-1, 1, 2], "shuffle keeps all replies")

	# openers and closers
	for m in [5.0, 30.0, 55.0, 90.0]:
		var o := DateData.opener(m, false, rng)
		_check(o.begins_with("Aren't we... on opposite sides of the board?"), "enemy opener: " + o)
		_check(DateData.greeting(m, true).length() > 5 and DateData.greeting(m, false).length() > 5, "greetings")
	_check(DateData.OPENERS["hollow"].has(DateData.opener(10.0, true, rng)), "hollow pieces open sadly")
	_check(DateData.OPENERS["gloomy"].has(DateData.opener(30.0, true, rng)), "gloomy pieces open sadly")
	_check(DateData.OPENERS["happy"].has(DateData.opener(90.0, true, rng)), "happy pieces open happily")
	for t in range(1, 7):
		for d in [-10, 0, 8, 20, 45]:
			_check(DateData.closer(t, d, true, rng).length() > 5 and DateData.closer(t, d, false, rng).length() > 5, "closers")
	_check(DateData.closer(6, 45, true, rng) == DateData.CLOSE_GREAT[6], "great date closer")
	_check(DateData.closer(6, -5, true, rng) == DateData.CLOSE_BAD[6], "bad date closer")


func _done() -> void:
	print("DATE TESTS ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	quit(1 if fails > 0 else 0)
