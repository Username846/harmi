extends Node
## Draws every fake ad (each scene at several moments, the banner and the end
## card) and checks the ad bag and the RAM maths.
## Run: godot --headless --path . res://tests/ads.tscn

var ok := true
var drawn := 0


func _check(cond: bool, what: String) -> void:
	if not cond:
		ok = false
		print("FAIL ", what)


func _ready() -> void:
	var canvas := Control.new()
	canvas.size = Vector2(720, 1280)
	add_child(canvas)
	canvas.draw.connect(func():
		for a in AdData.ADS:
			for sc in a["scenes"]:
				_check(AdScenes.IDS.has(sc[0]), "%s uses unknown scene %s" % [a["name"], sc[0]])
				for tt in [0.0, 0.7, 1.9, 3.3, 5.1, 8.8]:
					AdScenes.draw(canvas, String(sc[0]), Rect2(Vector2.ZERO, canvas.size), tt, a)
					drawn += 1)
	canvas.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	_check(drawn > 0, "the scenes were drawn")
	_check(AdData.ADS.size() >= 50, "at least fifty ads")
	var names := {}
	for a in AdData.ADS:
		var d := float(a["dur"])
		_check(d >= 5.0 and d <= 15.0, "%s lasts 5-15 s" % a["name"])
		_check(not names.has(a["name"]), "ad %s is unique" % a["name"])
		names[a["name"]] = true
	# every ad comes round once before any repeats
	Game.new_game()
	var seen := {}
	for i in AdData.ADS.size():
		seen[Game.next_ad()["name"]] = true
	_check(seen.size() == AdData.ADS.size(), "the ad bag shows every ad once")
	# the player: banner, end card, close pays out
	for a in [AdData.ADS[0], AdData.ADS[18], AdData.ADS[AdData.ADS.size() - 1]]:
		var p := AdPlayer.new()
		p.setup(a)
		p.size = Vector2(1280, 720)
		var paid := [-1]
		p.finished.connect(func(r: int): paid[0] = r)
		add_child(p)
		for tt in [0.5, p.dur - 1.0, p.dur + 0.2]:
			p.t = tt
			p.queue_redraw()
			await get_tree().process_frame
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = p._close_rect().get_center()
		p._gui_input(ev)
		_check(paid[0] == AdPlayer.reward_for(a) and paid[0] >= 4, "closing %s pays %d" % [a["name"], paid[0]])
	# the close button doesn't work before the countdown ends
	var early := AdPlayer.new()
	early.setup(AdData.ADS[1])
	early.size = Vector2(1280, 720)
	var paid_early := [false]
	early.finished.connect(func(_r: int): paid_early[0] = true)
	add_child(early)
	early.t = 2.0
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = true
	ev2.position = early._close_rect().get_center()
	early._gui_input(ev2)
	_check(not paid_early[0], "no early escape")
	early.queue_free()
	# RAM halves the out-of-memory chance
	_check(is_equal_approx(Game.oom_chance(), 0.3), "30% to start")
	Game.ram_sticks = 2
	_check(is_equal_approx(Game.oom_chance(), 0.075), "two sticks: 7.5%")
	print("drew %d scene frames" % drawn)
	print("AD TESTS PASSED" if ok else "AD TESTS FAILED")
	get_tree().quit(0 if ok else 1)
