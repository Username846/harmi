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
				for tt in [0.0, 0.7, 1.9, 3.3, 5.1, 8.8, 13.4, 19.6]:
					AdScenes.draw(canvas, String(sc[0]), Rect2(Vector2.ZERO, canvas.size), tt, a)
					drawn += 1)
	canvas.queue_redraw()
	for i in 3:
		await get_tree().process_frame
	_check(drawn > 0, "the scenes were drawn")
	_check(AdData.ADS.size() >= 100, "at least a hundred ads")
	var names := {}
	for a in AdData.ADS:
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
		_check(is_equal_approx(p.dur, 10.0), "%s runs 10 s" % a["name"])
		_check(paid[0] == AdPlayer.reward_for(a) and paid[0] >= 6, "closing %s pays %d" % [a["name"], paid[0]])
	# the install button opens "the store": a spinner, then an error with an OK button
	var shop := AdPlayer.new()
	shop.setup(AdData.ADS[2])
	shop.size = Vector2(1280, 720)
	add_child(shop)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = shop._cta_rect().get_center()
	shop._gui_input(tap)
	_check(shop._store_t >= 0.0 and shop._store_err.size() == 2, "install opens the store")
	shop._store_t = AdPlayer.STORE_LOAD + 0.1
	shop.queue_redraw()
	await get_tree().process_frame
	tap.position = shop._close_rect().get_center()
	shop.t = 25.0
	shop._gui_input(tap)
	_check(is_instance_valid(shop) and not shop._done, "the store dialog blocks the close button")
	tap.position = shop._ok_rect().get_center()
	shop._gui_input(tap)
	_check(shop._store_t < 0.0, "OK dismisses the store error")
	shop.queue_free()
	# the same ad shows the same store error every time you tap install
	var same := AdPlayer.new()
	same.setup(AdData.ADS[5])
	same.size = Vector2(1280, 720)
	add_child(same)
	same.virus = false
	var first: Array = same._store_err
	for i in 3:
		tap.position = same._cta_rect().get_center()
		same._gui_input(tap)
		_check(same._store_err == first, "the same error each tap")
		same._store_t = AdPlayer.STORE_LOAD + 0.1
		tap.position = same._ok_rect().get_center()
		same._gui_input(tap)
	same.queue_free()
	# the 5%: a download, an "installation error", and Wormy moves in
	Game.cure()
	var bad := AdPlayer.new()
	bad.setup(AdData.ADS[7])
	bad.size = Vector2(1280, 720)
	add_child(bad)
	bad.virus = true
	tap.position = bad._cta_rect().get_center()
	bad._gui_input(tap)
	bad._store_t = 2.5
	bad.queue_redraw()
	await get_tree().process_frame
	tap.position = bad._ok_rect().get_center()
	bad._gui_input(tap)
	_check(not Game.infected and bad._store_t >= 0.0, "OK does nothing while it's still downloading")
	bad._store_t = AdPlayer.DOWNLOAD_END + 0.1
	bad.queue_redraw()
	await get_tree().process_frame
	bad._gui_input(tap)
	_check(Game.infected and Game.virus_from == String(AdData.ADS[7]["name"]), "the download infects the game")
	bad.queue_free()
	# the overlay runs: glitches, Wormy, a scam popup that closes
	var ov := VirusOverlay.new()
	ov.size = Vector2(1280, 720)
	add_child(ov)
	ov._glitch_at = 0.0
	ov._next_popup = 0.0
	for i in 20:
		await get_tree().process_frame
	_check(ov._popup != null and is_instance_valid(ov._popup), "a scam popup appears")
	var x := InputEventMouseButton.new()
	x.button_index = MOUSE_BUTTON_LEFT
	x.pressed = true
	x.position = Vector2(ov._popup.size.x - 15, 14)
	ov._popup.gui_input.emit(x)
	await get_tree().process_frame
	_check(not is_instance_valid(ov._popup), "the popup's X closes it")
	ov.queue_free()
	# corruption leaves BBCode intact
	var corrupted := Game.corrupt("[color=#aabbcc]Tests are so satisfying[/color]", 1.0)
	_check(corrupted.begins_with("[color=#aabbcc]") and corrupted.ends_with("[/color]") and corrupted.contains("5"), "corrupt keeps tags: " + corrupted)
	# the antivirus is only for sale while infected, and cures it
	var shop2 := ShopPanel.new()
	add_child(shop2)
	_check(not shop2._locked("antivirus"), "antivirus for sale while infected")
	Game.add_money(50)
	shop2._select("antivirus")
	shop2._on_buy()
	_check(not Game.infected and shop2._locked("antivirus"), "antivirus cures the game")
	shop2.queue_free()
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
