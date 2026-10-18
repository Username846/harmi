extends Node
## Plays the survival screen through its public methods and its buttons:
## a few days of scavenging, eating, building and broadcasting, then both
## endings (rescue and death, with Try Again).
## Run: godot --headless --path . res://tests/survival_flow.tscn

var fails := 0
var done := false
var holder: Control
var results: Array = []


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func():
		print("SURVIVAL FLOW TESTS FAILED (timeout)")
		get_tree().quit(1))
	holder = Control.new()
	holder.theme = UI.build_theme()
	holder.size = Vector2(1067, 600)
	add_child(holder)
	await _run()
	_done()


func _done() -> void:
	if done:
		return
	done = true
	print("SURVIVAL FLOW TESTS ", "PASSED" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _button(root: Node, text: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b.text == text and b.is_visible_in_tree() and not b.is_queued_for_deletion():
			return b
	return null


func _press(root: Node, text: String) -> bool:
	var b := _button(root, text)
	if b == null:
		print("    (no button '%s')" % text)
		return false
	b.pressed.emit()
	return true


func _frames(n: int = 2) -> void:
	for i in n:
		await get_tree().process_frame


func _wait_idle(s: SurvivalScreen, limit: float = 6.0) -> void:
	var t := 0.0
	while s.busy and t < limit:
		await get_tree().create_timer(0.1).timeout
		t += 0.1


func _clear_trade(s: SurvivalScreen) -> void:
	if not s.sim.pending.is_empty():
		_check(_button(s, "No Thanks") != null, "a trade offer shows its modal")
		_press(s, "No Thanks")
		await _frames()


func _new_screen(seed_value: int) -> SurvivalScreen:
	var s := SurvivalScreen.new()
	s.setup({"town": "Springfield", "difficulty": 1, "seed": seed_value})
	s.finished.connect(func(r: String): results.append(r))
	holder.add_child(s)
	await _frames(3)
	return s


func _run() -> void:
	print("survival flow")
	var s := await _new_screen(3)
	_check(_button(s, "Climb Out") != null, "opening modal is shown")
	_check(s.log_box.get_parsed_text().contains("Springfield is gone"), "log opens with the town's fate")
	_press(s, "Climb Out")
	await _frames()
	_check(s.sim.day == 1 and s.sim.slot == 0, "starts on day 1, morning")
	_check(s.map.position.x < s.panel.position.x, "landscape: map left of the panel")
	_check(_button(s, "Broadcast") != null and _button(s, "Paint SOS") != null, "shelter actions are listed")

	# scavenge the corner store by tapping its marker, then the button
	var store_pos := s.map.loc_pos("store")
	_check(s.map.hit(store_pos) == "store", "the store marker is tappable")
	s.map.picked.emit("store")
	await _frames()
	_check(s.loc_title.text == "Gambit Goods & Gas", "panel shows the selected place")
	_check(_press(s, "Scavenge (1 slot)"), "scavenge button")
	await _frames()
	await _clear_trade(s)
	_check(s.sim.slot == 1 and s.sim.visits["store"] == 1, "scavenging used a slot")

	# eat something: no slot used
	var f0 := s.sim.food
	var slot0 := s.sim.slot
	_check(s.use_item("food"), "eat the starting can")
	_check(s.sim.food > f0 and s.sim.slot == slot0, "eating raises food without using time")

	# a too-far trip in the evening is refused with a hint
	s.select("shelter")
	s.sim.add_item("radio_part", 3)
	s.sim.add_item("battery", 2)
	await _frames()
	_check(s.act("build_radio"), "build the radio")
	_check(s.sim.radio_built, "radio built")
	s.select("ground_zero")
	await _frames()
	_check(not s.scavenge("ground_zero"), "ground zero refused in the evening")
	_check(s.hint.text != "", "and the panel says why")
	s.select("shelter")
	await _frames()
	var r0 := s.sim.rescue
	_check(_press(s, "Broadcast"), "broadcast button")
	await _frames()
	_check(s.sim.rescue > r0, "broadcast raises the rescue meter")
	_check(s.sim.day == 2 or s.sim.over, "the evening action brings the night")
	await _wait_idle(s)
	await _frames()
	_check(_button(s, "Get Up") != null, "night summary modal")
	_press(s, "Get Up")
	await _frames()

	# a couple more days: scavenge, then sleep early
	for d in 2:
		if s.sim.over:
			break
		s.scavenge("school" if d == 0 else "pharmacy")
		await _frames()
		await _clear_trade(s)
		var day0 := s.sim.day
		_press(s, "End Day")
		await _frames()
		await _clear_trade(s)
		_check(s.sim.day == day0 + 1 or s.sim.over, "End Day moves on to day %d" % (day0 + 1))
		await _wait_idle(s)
		_press(s, "Get Up")
		await _frames()

	# portrait layout
	holder.size = Vector2(600, 1300)
	await _frames(3)
	_check(s.panel.position.y > s.map.position.y + s.map.size.y, "portrait: panel below the map")
	_check(s.panel.position.y + s.panel.size.y <= 1300.5, "portrait: panel fits the screen")
	holder.size = Vector2(1067, 600)
	await _frames(2)

	# rescue: a flare on a helicopter day tips the meter over
	s.select("shelter")
	s.sim.rescue = 95.0
	s.sim.heli_today = true
	s.sim.add_item("flare")
	s.sim.slot = 0
	await _frames()
	_check(s.act("flare"), "fire the flare")
	_check(s.sim.over and s.sim.result == "rescued", "rescued")
	await get_tree().create_timer(5.0).timeout
	_check(_button(s, "Main Menu") != null, "rescue modal")
	_check(results.is_empty(), "nothing emitted before Main Menu")
	_press(s, "Main Menu")
	await _frames()
	_check(results == ["rescued"], "finished('rescued'), got " + str(results))
	s.queue_free()
	await _frames()

	# death, try again, death, main menu
	results.clear()
	var s2 := await _new_screen(8)
	_press(s2, "Climb Out")
	await _frames()
	s2.sim.health = 1.0
	s2.sim.water = 0.0
	s2.sleep_now()
	await _frames()
	_check(s2.sim.over and s2.sim.result == "died", "dies of thirst")
	await get_tree().create_timer(1.8).timeout
	_check(_button(s2, "Try Again") != null, "death modal")
	_press(s2, "Try Again")
	await _frames()
	_check(not s2.sim.over and s2.sim.day == 1 and not s2.ended, "Try Again restarts in place")
	_check(results.is_empty(), "Try Again doesn't emit")
	s2.sim.health = 1.0
	s2.sim.food = 0.0
	s2.sim.water = 0.0
	s2.scavenge("ground_zero")
	await _frames()
	await _clear_trade(s2)
	_check(s2.sim.over and s2.sim.result == "died", "dies again")
	await get_tree().create_timer(1.8).timeout
	_press(s2, "Main Menu")
	await _frames()
	_check(results == ["died"], "finished('died'), got " + str(results))
	s2.queue_free()
	await _frames()
