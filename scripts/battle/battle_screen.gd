class_name BattleScreen
extends Control
## Turn-based duel between the capturing piece and its victim.

signal finished(result: String)

const BG := {1: Color(0.24, 0.17, 0.1), 2: Color(0.12, 0.17, 0.26), 3: Color(0.22, 0.2, 0.28),
	4: Color(0.2, 0.2, 0.22), 5: Color(0.3, 0.07, 0.12), 6: Color(0.18, 0.06, 0.22)}

var info: Dictionary = {}
var arena: BattleArena
var cmd_panel: PanelContainer
var cmd_box: VBoxContainer
var log_box: RichTextLabel
var hero: Dictionary = {}
var foe: Dictionary = {}
var snap: Dictionary = {}
var busy := false
var is_final := false
var over := false


func setup(i: Dictionary) -> void:
	info = i
	is_final = i["kind"] == "final"
	snap = Game.snapshot()
	_make_fighters()


func _make_fighters() -> void:
	hero = BattleData.make_fighter(info["hero_type"], info["hero_color"], true, info["foe_type"], Game.buffs_of(info["hero_id"]))
	foe = BattleData.make_fighter(info["foe_type"], info["foe_color"], false, info["hero_type"])
	if is_final:
		foe["name"] = Game.piece_title(info["foe_type"], info["foe_color"]) + " (Final)"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena = BattleArena.new()
	arena.hero = hero
	arena.foe = foe
	arena.bg_color = BG.get(info["foe_type"], Color(0.2, 0.1, 0.1))
	arena.reset_display()
	add_child(arena)
	cmd_panel = PanelContainer.new()
	add_child(cmd_panel)
	var vb := VBoxContainer.new()
	cmd_panel.add_child(vb)
	log_box = UI.rich(17)
	log_box.custom_minimum_size = Vector2(0, 96)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(log_box)
	cmd_box = VBoxContainer.new()
	vb.add_child(cmd_box)
	resized.connect(_relayout)
	cmd_panel.minimum_size_changed.connect(_queue_relayout)
	_relayout()
	var buffs := Game.buffs_of(info["hero_id"])
	_log("[color=#e0aa4a]The %s turns to face you![/color]" % foe["name"])
	if not buffs.is_empty():
		var names := []
		for b in buffs:
			names.append(Game.item_name(b))
		_log("Your %s is blessed by: %s." % [hero["name"], ", ".join(names)])
	_show_main_commands()


func _relayout() -> void:
	var w := size.x
	var h := size.y
	var m := 12.0
	if w >= h * 1.15:
		var cw := clampf(w * 0.34, 280.0, 400.0)
		arena.position = Vector2(m, m)
		arena.size = Vector2(w - cw - m * 3.0, h - m * 2.0)
		cmd_panel.position = Vector2(w - cw - m, m)
		cmd_panel.size = Vector2(cw, h - m * 2.0)
	else:
		var ah := minf(w * 0.95, h * 0.56)
		arena.position = Vector2(m, m)
		arena.size = Vector2(w - m * 2.0, ah)
		cmd_panel.position = Vector2(m, ah + m * 2.0)
		cmd_panel.size = Vector2(w - m * 2.0, h - ah - m * 3.0)


var _relayout_queued := false


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


func _log(t: String) -> void:
	log_box.append_text(t + "\n")


func _clear_cmds() -> void:
	for c in cmd_box.get_children():
		c.queue_free()


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	cmd_box.add_child(g)
	return g


func _cmd(g: Container, text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := UI.button(text, cb, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	g.add_child(b)
	return b


func _show_main_commands() -> void:
	_clear_cmds()
	if over:
		return
	var g := _grid()
	_cmd(g, "Strike", func(): _act({"type": "strike"}))
	_cmd(g, "Skills", _show_skills)
	_cmd(g, "Guard", func(): _act({"type": "guard"}))
	var items := Game.items_usable_in("battle")
	_cmd(g, "Items (%d)" % items.size(), _show_items, items.is_empty())
	if not is_final:
		var r := UI.button("Retreat", _on_retreat, 46)
		cmd_box.add_child(r)


func _show_skills() -> void:
	_clear_cmds()
	for sk in hero["skills"]:
		var b := UI.button("%s  (%d MP)" % [sk["name"], sk["cost"]], func(): _act({"type": "skill", "skill": sk}), 56)
		b.disabled = hero["mp"] < sk["cost"]
		b.tooltip_text = sk["desc"]
		cmd_box.add_child(b)
		var d := UI.label(sk["desc"], 15, UI.DIM)
		cmd_box.add_child(d)
	cmd_box.add_child(UI.button("Back", _show_main_commands, 46))


func _show_items() -> void:
	_clear_cmds()
	for id in Game.items_usable_in("battle"):
		var b := UI.button("%s  x%d" % [Game.item_name(id), Game.count(id)], func(): _act({"type": "item", "item": id}), 56)
		b.tooltip_text = Game.item_desc(id)
		cmd_box.add_child(b)
	cmd_box.add_child(UI.button("Back", _show_main_commands, 46))


func _act(action: Dictionary) -> void:
	if busy or over:
		return
	busy = true
	_clear_cmds()
	await _perform(hero, foe, action, true)
	if foe["hp"] <= 0:
		await _victory()
		return
	await get_tree().create_timer(0.45).timeout
	await _perform(foe, hero, _enemy_choice(), false)
	if hero["hp"] <= 0:
		await _defeat()
		return
	busy = false
	_show_main_commands()


func _enemy_choice() -> Dictionary:
	var skills: Array = foe["skills"]
	var hp_k: float = float(foe["hp"]) / float(foe["max_hp"])
	var affordable := skills.filter(func(s): return foe["mp"] >= s["cost"])
	for s in affordable:
		if s["kind"] == "heal" and hp_k < 0.35 and randf() < 0.6:
			return {"type": "skill", "skill": s}
	var attacks := affordable.filter(func(s): return s["kind"] == "phys" or s["kind"] == "magic")
	if not attacks.is_empty() and randf() < 0.42:
		return {"type": "skill", "skill": attacks[randi() % attacks.size()]}
	for s in affordable:
		if (s["kind"] == "buff_atk" and foe.get("atk_up", 0) == 0) or (s["kind"] == "buff_def" and foe.get("def_up", 0) == 0):
			if randf() < 0.25:
				return {"type": "skill", "skill": s}
	if randf() < 0.1:
		return {"type": "guard"}
	return {"type": "strike"}


func _damage(a: Dictionary, d: Dictionary, power: float, magic: bool, pierce: bool) -> Dictionary:
	var stat: float = float(a["mag"] if magic else a["atk"])
	var raw := stat * power * randf_range(0.88, 1.12) - float(d["def"]) * (0.35 if magic else 0.6)
	var dmg := maxi(1, int(round(raw)))
	var crit := false
	if not magic and randf() < 0.08:
		dmg = int(round(dmg * 1.5))
		crit = true
	if d.get("guard", false) and not pierce:
		dmg = int(ceil(dmg * 0.5))
	return {"dmg": dmg, "crit": crit}


func _lunge(is_hero: bool, magic: bool) -> void:
	var tw := create_tween()
	if magic:
		var p := "hero_off" if is_hero else "foe_off"
		tw.tween_property(arena, p, Vector2(0, -14), 0.18)
		tw.tween_property(arena, p, Vector2.ZERO, 0.18)
	else:
		var dist := (arena.foe_base() - arena.hero_base()) * 0.55
		if is_hero:
			tw.tween_property(arena, "hero_off", dist, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(arena, "foe_off", -dist, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


func _return(is_hero: bool) -> void:
	var tw := create_tween()
	tw.tween_property(arena, "hero_off" if is_hero else "foe_off", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _hit_fx(target_is_hero: bool, dmg: int, crit: bool, magic: bool, color: Color) -> void:
	var c := arena.hero_center() if target_is_hero else arena.foe_center()
	arena.float_text(("%d!" % dmg) if crit else str(dmg), c - Vector2(0, 40), Color(1, 0.85, 0.3) if crit else Color(1, 1, 1))
	arena.burst(c, color, 30 if magic else 18)
	arena.shake = 0.6 if crit else 0.35
	if target_is_hero:
		arena.hero_flash = 1.0
	else:
		arena.foe_flash = 1.0


func _perform(a: Dictionary, d: Dictionary, action: Dictionary, a_is_hero: bool) -> void:
	a["guard"] = false
	var aname: String = "Your " + String(a["name"]) if a_is_hero else "The " + String(a["name"])
	match String(action["type"]):
		"strike":
			_log("%s strikes!" % aname)
			await _attack(a, d, 1.0, false, false, a_is_hero, Color(1, 0.9, 0.7))
		"guard":
			a["guard"] = true
			a["mp"] = mini(a["max_mp"], a["mp"] + 4)
			_log("%s braces behind its guard. (+4 MP)" % aname)
			arena.rise(arena.hero_center() if a_is_hero else arena.foe_center(), Color(0.5, 0.75, 1.0), 14)
			await get_tree().create_timer(0.5).timeout
		"skill":
			var sk: Dictionary = action["skill"]
			a["mp"] -= int(sk["cost"])
			_log("%s uses [b]%s[/b]!" % [aname, sk["name"]])
			match String(sk["kind"]):
				"phys":
					await _attack(a, d, float(sk["power"]), false, sk.get("pierce", false), a_is_hero, Color(1, 0.6, 0.3))
				"magic":
					await _attack(a, d, float(sk["power"]), true, false, a_is_hero, Color(0.7, 0.5, 1.0) if a["color"] == 1 else Color(1, 0.9, 0.5))
				"heal":
					var amt := int(round(float(a["max_hp"]) * float(sk["power"])))
					a["hp"] = mini(a["max_hp"], a["hp"] + amt)
					if sk.has("def"):
						a["def"] += int(sk["def"])
						a["def_up"] = a.get("def_up", 0) + 1
					var c := arena.hero_center() if a_is_hero else arena.foe_center()
					arena.float_text("+%d" % amt, c - Vector2(0, 40), UI.GREEN)
					arena.rise(c, UI.GREEN, 24)
					_log("%s recovers %d health." % [aname, amt])
					await get_tree().create_timer(0.6).timeout
				"buff_atk":
					a["atk"] += int(sk["power"])
					a["atk_up"] = a.get("atk_up", 0) + 1
					arena.rise(arena.hero_center() if a_is_hero else arena.foe_center(), UI.EMBER, 24)
					_log("%s's attack rises!" % aname)
					await get_tree().create_timer(0.6).timeout
				"buff_def":
					a["def"] += int(sk["power"])
					a["def_up"] = a.get("def_up", 0) + 1
					arena.rise(arena.hero_center() if a_is_hero else arena.foe_center(), Color(0.6, 0.7, 0.9), 24)
					_log("%s's defense rises!" % aname)
					await get_tree().create_timer(0.6).timeout
		"item":
			var id: String = action["item"]
			Game.remove_item(id)
			var c2 := arena.hero_center()
			match id:
				"potion":
					var amt2 := mini(40, a["max_hp"] - a["hp"])
					a["hp"] += amt2
					arena.float_text("+%d" % amt2, c2 - Vector2(0, 40), UI.GREEN)
					arena.rise(c2, UI.GREEN, 24)
					_log("You drink a Health Draught. (+%d HP)" % amt2)
				"ether":
					var amt3 := mini(25, a["max_mp"] - a["mp"])
					a["mp"] += amt3
					arena.float_text("+%d MP" % amt3, c2 - Vector2(0, 40), UI.BLUE)
					arena.rise(c2, UI.BLUE, 24)
					_log("You drink a Mana Tincture. (+%d MP)" % amt3)
				"ash":
					d["blind"] = true
					arena.burst(arena.foe_center(), Color(0.6, 0.58, 0.56), 40, 160.0)
					_log("You hurl a pinch of ash into the %s's eyes! Its next attack will miss." % d["name"])
			await get_tree().create_timer(0.6).timeout


func _attack(a: Dictionary, d: Dictionary, power: float, magic: bool, pierce: bool, a_is_hero: bool, color: Color) -> void:
	await _lunge(a_is_hero, magic)
	if magic:
		# a bolt of light flies across
		var from := arena.hero_center() if a_is_hero else arena.foe_center()
		var to := arena.foe_center() if a_is_hero else arena.hero_center()
		for i in 10:
			arena.sparks.append({"p": from.lerp(to, i / 10.0), "v": Vector2.ZERO, "c": color, "t": 0.0, "life": 0.25 + i * 0.03, "r": 6.0, "grav": 0.0})
		await get_tree().create_timer(0.2).timeout
	if a.get("blind", false):
		a["blind"] = false
		_log("...but it is blinded by ash and misses!")
		arena.float_text("MISS", (arena.foe_center() if a_is_hero else arena.hero_center()) - Vector2(0, 40), Color(0.7, 0.7, 0.7))
	else:
		var res := _damage(a, d, power, magic, pierce)
		d["hp"] = maxi(0, d["hp"] - int(res["dmg"]))
		_hit_fx(not a_is_hero, res["dmg"], res["crit"], magic, color)
		if res["crit"]:
			_log("[color=#e0aa4a]A crushing blow![/color] %d damage." % res["dmg"])
		else:
			_log("%d damage." % res["dmg"])
	if not magic:
		await _return(a_is_hero)
	else:
		await get_tree().create_timer(0.25).timeout


func _victory() -> void:
	over = true
	Game.stats["fights"] += 1
	Game.consume_buffs(info["hero_id"])
	_log("[color=#e0aa4a][b]The %s falls![/b][/color]" % foe["name"])
	var tw := create_tween()
	tw.tween_property(arena, "foe_fade", 0.0, 1.4)
	arena.rise(arena.foe_center(), Color(0.55, 0.52, 0.5), 60)
	await tw.finished
	var m := Modal.new("Victory", 440.0)
	m.sticky = true
	m.add_text("The %s is beaten. Return to the board to finish the capture." % foe["name"] if not is_final else "The enemy king kneels. Return to the board and watch it crumble.")
	m.add_buttons([["Return to the Board", func():
		m.close()
		finished.emit("won")]])
	add_child(m)


func _defeat() -> void:
	over = true
	_log("[color=#e2643a][b]Your %s is beaten down...[/b][/color]" % hero["name"])
	var tw := create_tween()
	tw.tween_property(arena, "hero_fade", 0.25, 1.0)
	await tw.finished
	var m := Modal.new("Defeated", 440.0)
	m.sticky = true
	m.add_text("Your piece is driven back, but this is a dream inside a capture. Try the duel again with your items restored%s." % ("" if is_final else ", or retreat and call off the capture"))
	var specs := [["Try Again", func():
		m.close()
		_retry()]]
	if not is_final:
		specs.append(["Retreat", func():
			m.close()
			Game.restore(snap)
			finished.emit("retreat")])
	m.add_buttons(specs)
	add_child(m)


func _retry() -> void:
	Game.restore(snap)
	_make_fighters()
	arena.hero = hero
	arena.foe = foe
	arena.hero_fade = 1.0
	arena.foe_fade = 1.0
	arena.reset_display()
	over = false
	busy = false
	log_box.clear()
	_log("[color=#e0aa4a]You steel yourself and face the %s again.[/color]" % foe["name"])
	_show_main_commands()


func _on_retreat() -> void:
	if busy:
		return
	var m := Modal.new("Retreat?", 440.0)
	m.add_text("Abandon the duel? The capture will be called off and you may choose another move.")
	m.add_buttons([["Retreat", func():
		m.close()
		over = true
		Game.restore(snap)
		finished.emit("retreat")], ["Fight on", m.close]])
	add_child(m)
