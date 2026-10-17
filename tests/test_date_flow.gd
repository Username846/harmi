extends Node
## Plays scripted dates through DateScreen (with the Game autoload loaded).
## Run: godot --headless --path . res://tests/date_flow.tscn

var fails := 0
var finished_once := false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	# watchdog: never hang, whatever happens below
	get_tree().create_timer(40.0).timeout.connect(func():
		print("DATE FLOW TESTS FAILED (timeout)")
		get_tree().quit(1))
	await _run()
	_done()


func _done() -> void:
	if finished_once:
		return
	finished_once = true
	print("DATE FLOW TESTS ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _reply(p: Dictionary, score: int) -> Array:
	for rep in p["a"]:
		var r: Array = rep
		if int(r[1]) == score:
			return r
	return []


func _run() -> void:
	# A perfect dinner date with a gloomy enemy rook.
	Game.new_game()
	Game.add_money(40)
	var money0: int = Game.money
	Game.set_mood(56, 30.0)
	var results: Array = []
	var s := DateScreen.new()
	s.setup({"date_type": 4, "date_color": 1, "date_id": 56, "date_mood": 30.0, "own": false})
	s.finished.connect(func(r: String): results.append(r))
	add_child(s)
	await get_tree().process_frame
	_check(s.stage == "venue", "starts at venue selection")
	_check(s.venue_cards.size() == 4, "four venue cards")
	s._select_venue("dinner", true)
	s._on_go()
	_check(Game.money == money0 - 15, "dinner costs $15")
	_check(s.stage == "date", "the date starts")
	s._on_continue() # opener -> venue reaction
	s._on_continue() # venue reaction -> round 1
	for i in DateData.ROUNDS:
		await get_tree().process_frame
		var offered := 0
		for c in s.reply_box.get_children():
			if not c.is_queued_for_deletion():
				offered += 1
		_check(offered == 3, "three replies offered in round %d (got %d)" % [i + 1, offered])
		_check(Game.mood_of(56) == 30.0, "mood untouched until the end")
		await s._on_reply(_reply(s.prompts[i], 2))
		s._on_continue()
	_check(s.stage == "result", "reaches the summary")
	var expected := clampf(30.0 + DateData.compute_delta(16, DateData.pref_bonus(4, "dinner", 30.0), 6), 0.0, 100.0)
	_check(is_equal_approx(Game.mood_of(56), expected), "mood %s should be %s" % [Game.mood_of(56), expected])
	s._finish()
	_check(is_equal_approx(Game.mood_of(56), expected), "mood changes exactly once")
	_check(results.is_empty(), "no result before Back to the Board")
	s._on_done()
	s._on_done()
	_check(results == ["done"], "finished('done') once, got " + str(results))
	s.queue_free()

	# Backing out spends nothing and leaves the mood alone.
	Game.set_mood(3, 50.0)
	var money1: int = Game.money
	results.clear()
	var s2 := DateScreen.new()
	s2.setup({"date_type": 1, "date_color": 0, "date_id": 3, "date_mood": 50.0, "own": true})
	s2.finished.connect(func(r: String): results.append(r))
	add_child(s2)
	await get_tree().process_frame
	s2._select_venue("bowling", true)
	s2._on_cancel()
	_check(results == ["cancel"], "cancel result, got " + str(results))
	_check(Game.money == money1 and Game.mood_of(3) == 50.0, "cancel spends nothing")
	s2.queue_free()

	# Can't afford dinner: the card is disabled and Go does nothing.
	Game.wallets[Game.active_side] = 5
	Game.set_mood(4, 50.0)
	var s3 := DateScreen.new()
	s3.setup({"date_type": 5, "date_color": 0, "date_id": 4, "date_mood": 50.0, "own": true})
	add_child(s3)
	await get_tree().process_frame
	var dinner_card: DateChoice = s3.venue_cards["dinner"]
	_check(dinner_card.disabled, "unaffordable venue is disabled")
	s3.venue_id = "dinner"
	s3._on_go()
	_check(s3.stage == "venue" and Game.money == 5, "can't go on a date you can't pay for")
	# a terrible picnic with a queen: mood drops, but only so far
	s3._select_venue("park", true)
	s3._on_go()
	s3._on_continue()
	s3._on_continue()
	for i in DateData.ROUNDS:
		await s3._on_reply(_reply(s3.prompts[i], -1))
		s3._on_continue()
	var exp2 := 50.0 + DateData.compute_delta(4, DateData.pref_bonus(5, "park", 50.0), -3)
	_check(is_equal_approx(Game.mood_of(4), exp2), "bad date mood %s should be %s" % [Game.mood_of(4), exp2])
	_check(Game.mood_of(4) >= 50.0 + DateData.MIN_DELTA, "bad date is clamped")
	s3.queue_free()
