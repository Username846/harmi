extends Control
## Scene manager: title -> chessboard <-> encounters (labyrinths and duels).

var bg: Control
var layer: Control
var fade: ColorRect
var card: Control
var title_screen: TitleScreen
var chess: ChessScreen
var encounter: Control
var dbg: Dictionary = {}


func _ready() -> void:
	theme = UI.build_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg = Control.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(_draw_bg)
	add_child(bg)
	layer = Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	card = Control.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	fade = ColorRect.new()
	fade.color = Color(0.02, 0.015, 0.02)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	add_child(fade)
	resized.connect(func(): bg.queue_redraw())
	dbg = _debug_params()
	if dbg.has("screen"):
		_debug_screen()
		return
	if dbg.has("lab") or dbg.has("fight"):
		_debug_encounter()
		return
	if dbg.has("fen"):
		await _start_game(dbg.get("ai", "1") == "1", 1)
		chess.load_position(String(dbg["fen"]).uri_decode().replace("_", " "))
		return
	show_title()


## Testing shortcut: ?lab=trench or ?fight=5 (foe piece type) jumps straight
## into an encounter. Also accepts the same as user args (-- lab=trench).
func _debug_params() -> Dictionary:
	var q := ""
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.location.search", true)
		if v is String:
			q = v.trim_prefix("?")
	for a in OS.get_cmdline_user_args():
		q += "&" + a.trim_prefix("--")
	var out := {}
	for part in q.split("&", false):
		var kv := part.split("=")
		if kv.size() == 2:
			out[kv[0]] = kv[1]
	return out


func _debug_encounter() -> void:
	Game.new_game()
	var info := {"hero_type": int(dbg.get("hero", "2")), "hero_color": 0, "hero_id": 1, "hero_mood": float(dbg.get("hmood", "72")),
		"foe_type": 1, "foe_color": 1, "foe_id": 24, "foe_mood": float(dbg.get("fmood", "72")), "kind": "puzzle", "lab": dbg.get("lab", "")}
	if dbg.has("fight"):
		info["kind"] = "final" if int(dbg["fight"]) == 6 else "fight"
		info["foe_type"] = int(dbg["fight"])
		encounter = BattleScreen.new()
		encounter.setup(info)
	else:
		info["foe_type"] = {"tower": 4, "undercroft": 4, "chapel": 3, "scriptorium": 3}.get(dbg["lab"], 1)
		if dbg.has("room"):
			info["start_room"] = dbg["room"]
		encounter = AdventureScreen.new()
		encounter.setup(info)
	encounter.finished.connect(func(_r):
		encounter.queue_free()
		encounter = null
		show_title())
	layer.add_child(encounter)


const SCREEN_SCRIPTS := {
	"race": "res://scripts/race/race_screen.gd",
	"date": "res://scripts/date/date_screen.gd",
	"cards": "res://scripts/cards/card_duel_screen.gd",
}


## Testing shortcut for the side screens: ?screen=race (or date, cards) with
## optional &hero=2&foe=4&hmood=72&fmood=30&diff=1&own=1&money=50&items=nitrous,roses
func _debug_screen() -> void:
	Game.new_game()
	if dbg.has("money"):
		Game.add_money(int(dbg["money"]))
	if dbg.has("items"):
		for id in String(dbg["items"]).split(",", false):
			Game.add_item(id)
	var own: bool = dbg.get("own", "0") == "1"
	var info := {
		"kind": dbg["screen"], "difficulty": int(dbg.get("diff", "1")),
		"hero_type": int(dbg.get("hero", "2")), "hero_color": 0, "hero_id": 1, "hero_mood": float(dbg.get("hmood", "72")),
		"foe_type": int(dbg.get("foe", "4")), "foe_color": 1, "foe_id": 56, "foe_mood": float(dbg.get("fmood", "72")),
		"date_type": int(dbg.get("foe", "4")), "date_color": 0 if own else 1, "date_id": 0 if own else 56,
		"date_mood": float(dbg.get("fmood", "40")), "own": own,
		"player_color": 0, "wager_type": int(dbg.get("foe", "4")),
	}
	Game.set_mood(info["date_id"], info["date_mood"])
	var script: GDScript = load(SCREEN_SCRIPTS.get(dbg["screen"], SCREEN_SCRIPTS["race"]))
	encounter = script.new()
	encounter.call("setup", info)
	encounter.connect("finished", func(r: String):
		print("screen finished: ", r)
		encounter.queue_free()
		encounter = null
		show_title())
	layer.add_child(encounter)


func _draw_bg() -> void:
	var s := bg.size
	bg.draw_rect(Rect2(Vector2.ZERO, s), UI.BG)
	var c := s * Vector2(0.5, 0.38)
	var r := s.length() * 0.6
	var n := 40
	for i in range(6, 0, -1):
		var k := i / 6.0
		var pts := PackedVector2Array()
		for j in n:
			var a := TAU * j / n
			pts.append(c + Vector2(cos(a), sin(a) * 0.8) * r * k)
		bg.draw_colored_polygon(pts, Color(0.13, 0.07, 0.07, 0.10))


func _fade_to(a: float, dur: float = 0.35) -> void:
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", a, dur)
	await tw.finished
	if a <= 0.01:
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_title() -> void:
	if chess:
		chess.queue_free()
		chess = null
	if encounter:
		encounter.queue_free()
		encounter = null
	title_screen = TitleScreen.new()
	title_screen.start_requested.connect(_start_game)
	layer.add_child(title_screen)


func _start_game(vs_ai: bool, difficulty: int) -> void:
	Game.vs_ai = vs_ai
	Game.difficulty = difficulty
	Game.new_game()
	# testing shortcut: &money=200&items=sniper,driveby
	if dbg.has("money"):
		Game.add_money(int(dbg["money"]))
	if dbg.has("items"):
		for id in String(dbg["items"]).split(",", false):
			Game.add_item(id)
	await _fade_to(1.0)
	if title_screen:
		title_screen.queue_free()
		title_screen = null
	chess = ChessScreen.new()
	chess.encounter_requested.connect(_on_encounter_requested)
	chess.quit_to_title.connect(_quit_to_title)
	layer.add_child(chess)
	await _fade_to(0.0, 0.5)


func _quit_to_title() -> void:
	await _fade_to(1.0)
	show_title()
	await _fade_to(0.0)


func _on_encounter_requested(info: Dictionary) -> void:
	# The board lurches toward the captured piece, then the world shifts.
	var b := chess.board
	var focus: Vector2 = info["foe_screen_pos"]
	b.pivot_offset = b.get_global_transform().affine_inverse() * focus
	var tw := create_tween().set_parallel()
	tw.tween_property(b, "scale", Vector2(2.4, 2.4), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "rotation", 0.06, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(fade, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await tw.finished
	chess.visible = false
	b.scale = Vector2.ONE
	b.rotation = 0.0

	var foe := Game.piece_title(info["foe_type"], info["foe_color"])
	var heading: String
	var sub: String
	match String(info["kind"]):
		"puzzle":
			heading = "Within the " + foe
			sub = Game.LAB_TITLES.get(info["lab"], "A Labyrinth")
		"final":
			heading = "The Last Stand of the " + foe
			sub = "Final Duel"
		"race":
			heading = "%s vs %s" % [Game.piece_title(info["hero_type"], info["hero_color"]), foe]
			sub = "Pink Slip Race"
		"date":
			heading = "A Date with the " + foe
			sub = "Date Night"
		"cards":
			heading = "The Graveyard"
			sub = "It's Time to Duel"
		_:
			heading = "The " + foe + " Fights Back"
			sub = "A Duel"
	await _show_card(heading, sub)

	match String(info["kind"]):
		"puzzle":
			encounter = AdventureScreen.new()
		"race", "date", "cards":
			var script: GDScript = load(SCREEN_SCRIPTS[info["kind"]])
			encounter = script.new()
		_:
			encounter = BattleScreen.new()
	encounter.call("setup", info)
	encounter.connect("finished", _on_encounter_finished)
	layer.add_child(encounter)
	await _fade_to(0.0, 0.5)


func _show_card(heading: String, sub: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := UI.label(heading, 26, UI.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var l2 := UI.label(sub.to_upper(), 46, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	l2.add_theme_constant_override("outline_size", 6)
	box.add_child(l1)
	box.add_child(l2)
	box.modulate.a = 0.0
	# cards draw above the fade so they show on black
	move_child(card, get_child_count() - 1)
	card.add_child(box)
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.4)
	tw.tween_interval(1.1)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	await tw.finished
	box.queue_free()
	move_child(card, fade.get_index() - 1)


func _on_encounter_finished(result: String) -> void:
	await _fade_to(1.0, 0.5)
	if encounter:
		encounter.queue_free()
		encounter = null
	Game.clear_puzzle_items()
	chess.visible = true
	await _fade_to(0.0, 0.6)
	chess.resolve_encounter(result)
