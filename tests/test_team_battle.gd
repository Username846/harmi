extends Node
## Drives the real BattleScreen through a 1v1 duel, a 3v2, a 1v3 and a 4v4
## team battle until someone wins, picking targets both through the target
## handler and with taps on the arena. Checks that downed fighters never act.
## Run: godot --headless --path . res://tests/team_battle.tscn

const RUNS := [
	{"name": "1v1", "hero": 4, "foe": 1, "party": [], "foes": []},
	{"name": "3v2", "hero": 2, "foe": 3, "party": [1, 3], "foes": [1]},
	{"name": "1v3", "hero": 2, "foe": 1, "party": [], "foes": [1, 3], "focus": true},
	{"name": "4v4", "hero": 5, "foe": 4, "party": [1, 2, 3, 4], "foes": [1, 2, 3]},
]
const WATCHDOG := 240.0

var holder: Control
var scr: BattleScreen
var run := 0
var failures := 0
var elapsed := 0.0
var acts := 0
var inputs := 0
var tried_again := false
var ended := false
var finished_with := ""
var taps := 0


func _ready() -> void:
	Engine.time_scale = 12.0
	holder = Control.new()
	holder.theme = UI.build_theme()
	holder.size = Vector2(1067, 600)
	add_child(holder)
	_begin()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL [%s]: %s" % [RUNS[run]["name"], msg])


func _begin() -> void:
	var cfg: Dictionary = RUNS[run]
	Game.new_game()
	Game.add_item("potion")
	Game.add_item("ash")
	var info := {"kind": "fight", "hero_type": cfg["hero"], "hero_color": 0, "hero_id": 1, "hero_mood": 72.0,
		"foe_type": cfg["foe"], "foe_color": 1, "foe_id": 56, "foe_mood": 72.0}
	for key in ["party", "foes"]:
		var members: Array = []
		var k := 0
		for t in cfg[key]:
			k += 1
			members.append({"type": t, "color": 0 if key == "party" else 1, "id": (300 if key == "party" else 400) + k, "mood": 72.0, "buffs": []})
		if not members.is_empty():
			info["hero_party" if key == "party" else "foe_party"] = members
	scr = BattleScreen.new()
	scr.setup(info)
	scr.fighter_acted.connect(_on_acted)
	scr.finished.connect(func(r):
		finished_with = r)
	holder.add_child(scr)
	acts = 0
	inputs = 0
	tried_again = false
	ended = false
	finished_with = ""
	var party: Array = cfg["party"]
	var foes: Array = cfg["foes"]
	var exp_h := 1 + mini(3, party.size())
	var exp_f := 1 + mini(3, foes.size())
	_check(scr.heroes.size() == exp_h and scr.foes.size() == exp_f, "party sizes %d/%d" % [scr.heroes.size(), scr.foes.size()])
	_check(scr.hero["leader"] and scr.foe["leader"], "leaders marked")
	for i in range(1, scr.heroes.size()):
		_check(not scr.heroes[i]["leader"], "ally not leader")
		_check(int(scr.heroes[i]["max_hp"]) > 0, "ally has health")
	_check(scr.is_team() == (exp_h + exp_f > 2), "team mode")


func _on_acted(f: Dictionary) -> void:
	acts += 1
	_check(int(f["hp"]) > 0, "downed %s acted" % f["name"])
	if f["is_hero"]:
		_check(is_same(f, scr.actor), "hero acting out of turn")


func _button(text: String) -> Button:
	for c in holder.find_children("*", "Button", true, false):
		var b := c as Button
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func _process(delta: float) -> void:
	elapsed += delta / Engine.time_scale
	if elapsed > WATCHDOG:
		print("FAIL: watchdog timeout in run ", RUNS[mini(run, RUNS.size() - 1)]["name"])
		get_tree().quit(1)
		return
	if scr == null or ended:
		return
	if finished_with != "":
		_end_run()
		return
	if scr.over:
		# wait for the victory / defeat modal, then answer it
		if scr.result == "won":
			var b := _button("Return to the Board")
			if b:
				b.pressed.emit()
		elif scr.result == "lost":
			var again := _button("Try Again")
			var ret := _button("Retreat")
			if again and ret:
				if not tried_again:
					tried_again = true
					print("  [%s] lost, trying again" % RUNS[run]["name"])
					again.pressed.emit()
				else:
					ret.pressed.emit()
		return
	if scr.busy:
		return
	if not scr._pending.is_empty():
		_pick_target()
		return
	_choose_action()


func _choose_action() -> void:
	inputs += 1
	var a: Dictionary = scr.actor
	_check(int(a["hp"]) > 0, "dead actor was offered commands")
	var r := randf()
	if inputs == 1 or r < 0.5:
		scr._choose({"type": "strike"})
		return
	if r < 0.8:
		for sk in a["skills"]:
			if a["mp"] >= sk["cost"]:
				scr._choose({"type": "skill", "skill": sk})
				return
	if r < 0.88 and Game.count("potion") > 0:
		scr._choose({"type": "item", "item": "potion"})
		return
	if r < 0.92 and Game.count("ash") > 0:
		scr._choose({"type": "item", "item": "ash"})
		return
	scr._choose({"type": "guard"})


func _pick_target() -> void:
	var pool: Array = scr.arena.pick_list
	_check(not pool.is_empty(), "targeting without targets")
	for f in pool:
		_check(int(f["hp"]) > 0, "downed fighter offered as target")
	var f: Dictionary = pool[randi() % pool.size()]
	if RUNS[run].get("focus", false):
		# a sensible player finishes off the weakest enemy first
		for g in pool:
			if int(g["hp"]) < int(f["hp"]):
				f = g
	taps += 1
	if taps % 2 == 0:
		# tap it in the arena like a player would
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = scr.arena.center(f)
		scr.arena._gui_input(ev)
		if not scr._pending.is_empty():
			_check(false, "tap on %s did not pick" % f["name"])
			scr._on_picked(f)
	else:
		scr._on_picked(f)


func _end_run() -> void:
	ended = true
	var cfg: Dictionary = RUNS[run]
	var txt := scr.log_box.get_parsed_text()
	if scr.is_team():
		if not tried_again:
			_check(txt.contains("Team battle! %d vs %d" % [scr.heroes.size(), scr.foes.size()]), "banner missing")
		_check(txt.contains(" strikes the ") or tried_again, "log does not name the target")
	else:
		_check(not txt.contains("Team battle"), "1v1 shows team banner")
	if finished_with == "won":
		_check(BattleScreen._alive(scr.foes).is_empty(), "won with foes standing")
	elif finished_with == "retreat":
		_check(BattleScreen._alive(scr.heroes).is_empty(), "lost with heroes standing")
	else:
		_check(false, "unexpected result " + finished_with)
	for f in scr.heroes + scr.foes:
		if int(f["hp"]) <= 0:
			_check(float(f["fade"]) < 0.3, "%s downed but not faded" % f["name"])
	print("run %s: %s after %d actions (%d/%d heroes alive, %d/%d foes alive)%s" % [cfg["name"], finished_with, acts,
		BattleScreen._alive(scr.heroes).size(), scr.heroes.size(), BattleScreen._alive(scr.foes).size(), scr.foes.size(),
		" (after a retry)" if tried_again else ""])
	scr.queue_free()
	scr = null
	run += 1
	if run >= RUNS.size():
		print("team battle tests done, failures: ", failures)
		get_tree().quit(1 if failures > 0 else 0)
		return
	await get_tree().process_frame
	_begin()
