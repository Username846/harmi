extends Node
## Scene test for the graveyard after Yugi: opens GraveyardPanel in each of its
## three states, repairs every section through the panel's own buttons, checks
## the signals (repaired, keeper_crowned, raise_requested, reals_requested),
## the layout at desktop and phone sizes, and that repairs ignore can_duel.
## Run: godot --headless --path . res://tests/grave_restore.tscn

const SIZES := [Vector2i(1067, 600), Vector2i(600, 1300), Vector2i(600, 600)]

var failures := 0
var host: Control


func _ready() -> void:
	# watchdog: never hang the test run
	get_tree().create_timer(60.0).timeout.connect(func():
		print("  FAIL: watchdog timeout")
		print("GRAVE RESTORE TESTS FAILED (timeout)")
		get_tree().quit(1))
	host = Control.new()
	host.theme = UI.build_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child.call_deferred(host)
	_run.call_deferred()


func _fail(msg: String) -> void:
	failures += 1
	print("  FAIL: ", msg)


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false)


func _button(root: Node, text: String) -> Button:
	for b in _buttons(root):
		if (b as Button).text == text:
			return b
	return null


func _setup_ruined() -> void:
	Game.new_game()
	Game.yugi_banished = true
	Game.add_money(500)
	for id in ["whetstone", "ash", "ash", "ash", "pet_rock", "roses", "spoon", "gourd"]:
		Game.add_item(id)
	for t in [1, 2, 4]:
		Game.bury(0, t, Game.new_piece_id())


func _open(can_duel: bool, reason: String = "") -> GraveyardPanel:
	var gp := GraveyardPanel.new(0, can_duel, reason)
	host.add_child(gp)
	await _frames(4)
	await get_tree().create_timer(0.25).timeout
	return gp


func _check_fit(gp: GraveyardPanel, label: String) -> void:
	var vp := get_viewport().get_visible_rect()
	var r := gp.panel.get_global_rect()
	if r.position.y < -1.0 or r.end.y > vp.size.y + 1.0 or r.position.x < -1.0 or r.end.x > vp.size.x + 1.0:
		_fail("%s: panel %s does not fit the screen %s" % [label, str(r), str(vp.size)])
	for b in _buttons(gp):
		var btn: Button = b
		if btn.is_visible_in_tree() and btn.size.y < 47.5:
			_fail("%s: button '%s' is only %.0f px tall" % [label, btn.text, btn.size.y])
	for l in gp.find_children("*", "Label", true, false):
		var lab: Label = l
		var fs := lab.get_theme_font_size("font_size")
		if lab.is_visible_in_tree() and fs < 15:
			_fail("%s: label '%s' uses %d px text" % [label, lab.text.left(30), fs])


func _run() -> void:
	# --- a) Yugi is present: normal and "for reals" duels -------------------------
	Game.new_game()
	Game.bury(0, 4, Game.new_piece_id())
	var gp := await _open(true)
	if gp.state != "yugi":
		_fail("expected the yugi state, got " + gp.state)
	var reals := _button(gp, "Duel For Reals")
	if reals == null or reals.disabled:
		_fail("no enabled 'Duel For Reals' button")
	var got_reals := [-1]
	gp.reals_requested.connect(func(i: int): got_reals[0] = i)
	reals.pressed.emit()
	await _frames(2)
	var confirm := _button(gp, "Duel for reals")
	if confirm == null:
		_fail("no confirm modal for the shadow game")
	else:
		confirm.pressed.emit()
		await _frames(2)
	if got_reals[0] != 0:
		_fail("reals_requested not emitted with index 0 (got %d)" % got_reals[0])
	if is_instance_valid(gp) and not gp.is_queued_for_deletion():
		_fail("panel did not close after a for-reals challenge")
	await _frames(2)

	# --- b) Ruined: repair everything through the buttons, even when can_duel is false
	for sz in SIZES:
		get_window().size = sz
		_setup_ruined()
		gp = await _open(false, "Wait for your turn to duel.")
		print("ruined panel at viewport %s: panel %s, split %s, list %s, rows %s" % [str(get_viewport().get_visible_rect().size), str(gp.panel.get_global_rect()), str(gp.split.get_global_rect()), str(gp.list_scroll.get_global_rect()), str(gp.list_box.get_combined_minimum_size())])
		if gp.state != "ruined":
			_fail("expected the ruined state, got " + gp.state)
		_check_fit(gp, "ruined %s" % str(sz))
		if gp.section_buttons.size() != Game.GRAVE_SECTIONS.size():
			_fail("expected %d repair buttons, got %d" % [Game.GRAVE_SECTIONS.size(), gp.section_buttons.size()])
		var fixed: Array = []
		var crowned := [0]
		gp.repaired.connect(func(id: String): fixed.append(id))
		gp.keeper_crowned.connect(func(): crowned[0] += 1)
		for sec in Game.GRAVE_SECTIONS:
			var sid: String = sec["id"]
			var b: Button = gp.section_buttons.get(sid)
			if b == null:
				_fail("missing button for " + sid)
				continue
			if b.disabled:
				_fail("repair button for %s disabled although affordable" % sid)
			b.pressed.emit()
			await _frames(2)
			if not Game.grave_repairs.has(sid):
				_fail("pressing Repair did not repair " + sid)
			if gp.state == "ruined" and not (gp.section_buttons[sid] as Button).disabled:
				_fail("repaired section %s still has an enabled button" % sid)
		if fixed.size() != Game.GRAVE_SECTIONS.size():
			_fail("repaired emitted %d times" % fixed.size())
		if crowned[0] != 1:
			_fail("keeper_crowned emitted %d times" % crowned[0])
		if Game.gravekeeper != 0 or not Game.graveyard_restored():
			_fail("game state not restored / keeper not crowned")
		if gp.state != "restored":
			_fail("panel did not switch to the restored state")
		var cele := _button(gp, "Wonderful")
		if cele == null:
			_fail("no gravekeeper celebration")
		else:
			cele.pressed.emit()
		await _frames(3)
		_check_fit(gp, "restored %s" % str(sz))
		gp.close()
		await _frames(2)

	# --- not enough money: the button stays disabled -------------------------------
	get_window().size = SIZES[0]
	Game.new_game()
	Game.yugi_banished = true
	Game.spend(Game.money)
	gp = await _open(true)
	for sec in Game.GRAVE_SECTIONS:
		var bb: Button = gp.section_buttons[String(sec["id"])]
		if not bb.disabled:
			_fail("repair of %s enabled without the means to pay" % String(sec["id"]))
	gp.close()
	await _frames(2)

	# --- c) Restored: raising, cooldown and someone else's graveyard ------------------
	_setup_ruined()
	for sec in Game.GRAVE_SECTIONS:
		Game.repair(String(sec["id"]))
	gp = await _open(true)
	var raise := _button(gp, "Raise this piece (free)")
	if raise == null or raise.disabled:
		_fail("no enabled raise button for the keeper")
	var got_raise := [-1]
	gp.raise_requested.connect(func(i: int): got_raise[0] = i)
	raise.pressed.emit()
	await _frames(2)
	if got_raise[0] != 2:
		_fail("raise_requested should carry the selected (last) tombstone, got %d" % got_raise[0])
	Game.keeper_cooldown = 3
	gp = await _open(true)
	if _button(gp, "The soil needs 3 more turns") == null:
		_fail("cooldown text missing")
	gp.close()
	Game.keeper_cooldown = 0
	gp = await _open(false, "Wait for your turn.")
	var rb := _button(gp, "Can't raise now")
	if rb == null or not rb.disabled:
		_fail("raising should be blocked when can_duel is false")
	gp.close()
	Game.gravekeeper = 1
	gp = await _open(true)
	if _button(gp, "Not your graveyard") == null:
		_fail("the other side's graveyard should say it is not yours")
	gp.close()
	await _frames(2)

	print("GRAVE RESTORE TESTS ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
