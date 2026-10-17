extends Node
## Drives the real RaceScreen (UI, buttons, modals) through whole races:
## a good driver with nitrous, then one who jumps the light and never shifts.
## Run: godot --headless --fixed-fps 60 --path . res://tests/race_smoke.tscn

const RUNS := [
	{"name": "good driver", "hero": 1, "foe": 5, "jump": false, "shift": true, "nos": true, "expect": "won"},
	{"name": "jumps the light, never shifts", "hero": 5, "foe": 1, "jump": true, "shift": false, "nos": false, "expect": "lost"},
]

var holder: Control
var scr: RaceScreen
var run := 0
var t := 0.0
var tapped := false
var failures := 0


func _ready() -> void:
	holder = Control.new()
	holder.theme = UI.build_theme()
	holder.size = Vector2(1067, 600)
	add_child(holder)
	_begin()


func _begin() -> void:
	var cfg: Dictionary = RUNS[run]
	Game.new_game()
	if cfg["nos"]:
		Game.add_item("nitrous")
	scr = RaceScreen.new()
	scr.setup({"hero_type": cfg["hero"], "hero_color": 0, "hero_id": 1, "hero_mood": 80.0,
		"foe_type": cfg["foe"], "foe_color": 1, "foe_id": 56, "foe_mood": 50.0, "difficulty": 1})
	scr.finished.connect(_on_finished)
	holder.add_child(scr)
	t = 0.0
	tapped = false


func _button(root: Node, text: String) -> Button:
	for c in root.find_children("*", "Button", true, false):
		var b := c as Button
		if b.text == text and b.is_visible_in_tree():
			return b
	return null


func _process(delta: float) -> void:
	if scr == null:
		return
	t += delta
	var cfg: Dictionary = RUNS[run]
	var sim := scr.sim
	if t > 60.0:
		print("FAIL timeout in run ", cfg["name"])
		get_tree().quit(1)
		return
	if scr.phase == "intro" and t > 0.5:
		var b := _button(scr, "Light the Tree")
		if b:
			b.pressed.emit()
	if scr.phase == "run":
		var jump: bool = cfg["jump"]
		if not tapped and ((jump and sim.clock > 0.4) or (sim.is_green() and sim.race_time() > 0.2)):
			scr.main_btn.pressed.emit()
			tapped = true
		if cfg["shift"] and sim.hero.launched and sim.hero.gear < RaceSim.GEARS and sim.hero.rpm >= 0.84 and not scr.main_btn.disabled:
			scr.main_btn.pressed.emit()
		if cfg["nos"] and sim.hero.gear == RaceSim.GEARS and scr.nos_btn.visible and not scr.nos_btn.disabled:
			scr.nos_btn.pressed.emit()
	var ret := _button(scr, "Return to the Board")
	if ret:
		ret.pressed.emit()


func _on_finished(r: String) -> void:
	var cfg: Dictionary = RUNS[run]
	var sim := scr.sim
	print("%s: %s  (%.2f s vs %.2f s, shifts %s, nos used %s, nitrous left %d)" % [cfg["name"], r, sim.hero.finish, sim.foe.finish, sim.hero.shifts, sim.hero.nos_used, Game.count("nitrous")])
	if r != cfg["expect"]:
		print("  FAIL expected ", cfg["expect"])
		failures += 1
	if cfg["nos"] and (not sim.hero.nos_used or Game.has_item("nitrous")):
		print("  FAIL nitrous should be used up")
		failures += 1
	scr.queue_free()
	scr = null
	run += 1
	if run >= RUNS.size():
		print("RACE SMOKE ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
		get_tree().quit(1 if failures > 0 else 0)
		return
	await get_tree().process_frame
	_begin()
