class_name BattleScreen
extends Control
## Turn-based duel between the capturing piece and its victim. When the info
## carries "hero_party"/"foe_party" (allies of each side), it becomes a team
## battle: every living hero acts in turn (the player picks an action and a
## target), then every living foe acts with the AI.

signal finished(result: String)
signal fighter_acted(f: Dictionary) # emitted as each fighter starts its action

const BG := {1: Color(0.24, 0.17, 0.1), 2: Color(0.12, 0.17, 0.26), 3: Color(0.22, 0.2, 0.28),
	4: Color(0.2, 0.2, 0.22), 5: Color(0.3, 0.07, 0.12), 6: Color(0.18, 0.06, 0.22)}
const MAX_ALLIES := 3
const ALLY_HP := 0.85 # allies of the hero are a little weaker than the leader
const ALLY_ATK := 0.92
const NUMERALS := ["", " II", " III", " IV"]

var info: Dictionary = {}
var arena: BattleArena
var cmd_panel: PanelContainer
var cmd_box: VBoxContainer
var log_box: RichTextLabel
var title_lbl: Label
var heroes: Array = [] # leader first
var foes: Array = [] # leader first
var hero: Dictionary = {} # the hero leader
var foe: Dictionary = {} # the foe leader
var actor: Dictionary = {} # the hero whose command is being chosen
var snap: Dictionary = {}
var busy := false
var is_final := false
var over := false
var result := "" # "won", "lost" or "retreat" once decided
var _acted: Array = [] # heroes that already acted this round
var _pending: Dictionary = {} # an action waiting for its target


func setup(i: Dictionary) -> void:
	info = i
	is_final = i["kind"] == "final"
	snap = Game.snapshot()
	_make_fighters()


func is_team() -> bool:
	return heroes.size() > 1 or foes.size() > 1


static func _party(raw) -> Array:
	if raw is Array:
		var a: Array = raw
		return a.slice(0, MAX_ALLIES)
	return []


func _make_fighters() -> void:
	var hero_t: int = info["hero_type"]
	var foe_t: int = info["foe_type"]
	hero = BattleData.make_fighter(hero_t, info["hero_color"], true, foe_t, Game.buffs_of(info["hero_id"]), float(info.get("hero_mood", Game.START_MOOD)))
	foe = BattleData.make_fighter(foe_t, info["foe_color"], false, hero_t, [], float(info.get("foe_mood", Game.START_MOOD)))
	if is_final:
		foe["name"] = Game.piece_title(foe_t, info["foe_color"]) + " (Final)"
	hero["id"] = int(info["hero_id"])
	foe["id"] = int(info.get("foe_id", -1))
	heroes = [hero]
	foes = [foe]
	for e in _party(info.get("hero_party")):
		var ed: Dictionary = e
		var b: Array = ed.get("buffs", [])
		var f := BattleData.make_fighter(int(ed.get("type", 1)), int(ed.get("color", info["hero_color"])), true, foe_t, b, float(ed.get("mood", Game.START_MOOD)))
		f["max_hp"] = int(round(float(f["max_hp"]) * ALLY_HP))
		f["atk"] = int(round(float(f["atk"]) * ALLY_ATK))
		f["mag"] = int(round(float(f["mag"]) * ALLY_ATK))
		f["id"] = int(ed.get("id", -1))
		heroes.append(f)
	for e in _party(info.get("foe_party")):
		var ed: Dictionary = e
		var b: Array = ed.get("buffs", [])
		# the foe's allies are softened against a weaker capturing piece like the
		# foe leader is, but never boosted above their own level, and, like the
		# hero's allies, sit a little below a leader
		var ft := int(ed.get("type", 1))
		var rate_t := hero_t if float(Game.PIECE_VALUES[hero_t]) < float(Game.PIECE_VALUES[ft]) else ft
		var f := BattleData.make_fighter(ft, int(ed.get("color", info["foe_color"])), false, rate_t, b, float(ed.get("mood", Game.START_MOOD)))
		f["max_hp"] = int(round(float(f["max_hp"]) * ALLY_HP))
		f["atk"] = int(round(float(f["atk"]) * ALLY_ATK))
		f["mag"] = int(round(float(f["mag"]) * ALLY_ATK))
		f["id"] = int(ed.get("id", -1))
		foes.append(f)
	# a side that is outnumbered fights with its back to the wall
	var d := foes.size() - heroes.size()
	for f in (heroes if d > 0 else foes if d < 0 else []):
		var k := float(absi(d))
		var hp_k := 1.0 + (0.3 if d > 0 else 0.12) * k
		f["max_hp"] = int(round(float(f["max_hp"]) * hp_k))
		if d > 0:
			f["atk"] = int(round(float(f["atk"]) * (1.0 + 0.08 * k)))
			f["mag"] = int(round(float(f["mag"]) * (1.0 + 0.08 * k)))
			f["max_mp"] = int(round(float(f["max_mp"]) * (1.0 + 0.15 * k)))
	for side in 2:
		var list: Array = heroes if side == 0 else foes
		var seen := {}
		for n in list.size():
			var f: Dictionary = list[n]
			f["is_hero"] = side == 0
			f["slot"] = n
			f["leader"] = n == 0
			var nm: String = f["name"]
			var times: int = seen.get(nm, 0)
			seen[nm] = times + 1
			var suffix: String = NUMERALS[mini(times, NUMERALS.size() - 1)]
			f["name"] = nm + suffix
			f["short"] = String(Game.PIECE_NAMES[f["type"]]) + suffix
			f["hp"] = f["max_hp"]
			f["mp"] = f["max_mp"]
			f["off"] = Vector2.ZERO
			f["fade"] = 1.0
			f["flash"] = 0.0
			f["dhp"] = float(f["hp"])
			f["dmp"] = float(f["mp"])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena = BattleArena.new()
	arena.heroes = heroes
	arena.foes = foes
	arena.bg_color = BG.get(info["foe_type"], Color(0.2, 0.1, 0.1))
	arena.gloom = Game.gloom_for(float(info.get("foe_mood", Game.START_MOOD)))
	arena.reset_display()
	arena.picked.connect(_on_picked)
	add_child(arena)
	cmd_panel = PanelContainer.new()
	add_child(cmd_panel)
	var vb := VBoxContainer.new()
	cmd_panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	title_lbl = UI.label(_title(), 22, UI.GOLD)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_lbl.clip_text = true
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_lbl)
	head.add_child(BeybladeButton.new(48.0))
	log_box = UI.rich(17)
	log_box.custom_minimum_size = Vector2(0, 96)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(log_box)
	cmd_box = VBoxContainer.new()
	vb.add_child(cmd_box)
	resized.connect(_relayout)
	cmd_panel.minimum_size_changed.connect(_queue_relayout)
	_relayout()
	_intro()
	_start_round()


func _title() -> String:
	if is_team():
		return "Final Battle" if is_final else "Team Battle"
	return "Final Duel" if is_final else "Duel"


func _names(list: Array) -> String:
	var out: Array = []
	for f in list:
		out.append(String(f["name"]))
	return ", ".join(out)


func _intro() -> void:
	if is_team():
		_log("[color=#e0aa4a][b]Team battle! %d vs %d[/b][/color]" % [heroes.size(), foes.size()])
	_log("[color=#e0aa4a]The %s turns to face you![/color]" % foe["name"])
	if is_team():
		if foes.size() > 1:
			_log("At its side: %s." % _names(foes.slice(1)))
		if heroes.size() > 1:
			_log("At your side: %s." % _names(heroes.slice(1)))
		if foes.size() > heroes.size():
			_log("[color=#e0aa4a]Outnumbered, your pieces fight with their backs to the wall.[/color]")
	var buffs := Game.buffs_of(info["hero_id"])
	if not buffs.is_empty():
		var names := []
		for b in buffs:
			names.append(Game.item_name(b))
		_log("Your %s is blessed by: %s." % [hero["name"], ", ".join(names)])
	var hm: float = hero["mood"]
	var fm: float = foe["mood"]
	if hm < 45.0:
		_log("[color=#8f96b8]Your %s is %s and fights half-heartedly.[/color]" % [hero["name"], Game.mood_name(hm).to_lower()])
	elif hm >= 85.0:
		_log("[color=#e0aa4a]Your %s is elated and hits harder![/color]" % hero["name"])
	if fm < 45.0:
		_log("[color=#8f96b8]The %s is %s. Its despair hangs over the arena, but saps its strength.[/color]" % [foe["name"], Game.mood_name(fm).to_lower()])


func _relayout() -> void:
	var w := size.x
	var h := size.y
	var m := 12.0
	if w >= h * 1.15:
		btn_h = 56.0
		log_box.custom_minimum_size = Vector2(0, 96)
		var cw := clampf(w * 0.34, 280.0, 400.0)
		arena.position = Vector2(m, m)
		arena.size = Vector2(w - cw - m * 3.0, h - m * 2.0)
		cmd_panel.position = Vector2(w - cw - m, m)
		cmd_panel.size = Vector2(cw, h - m * 2.0)
	else:
		# short portrait screens get a tighter command panel, and the arena
		# gives way when a menu needs more room than usual
		var compact := h < 800.0
		btn_h = 48.0 if compact else 56.0
		log_box.custom_minimum_size = Vector2(0, 44 if compact else 96)
		var min_h := cmd_panel.get_combined_minimum_size().y
		var ah := minf(w * (1.1 if is_team() else 0.95), h * 0.56)
		ah = maxf(minf(ah, h - min_h - m * 3.0), h * 0.36)
		arena.position = Vector2(m, m)
		arena.size = Vector2(w - m * 2.0, ah)
		cmd_panel.position = Vector2(m, ah + m * 2.0)
		cmd_panel.size = Vector2(w - m * 2.0, h - ah - m * 3.0)


var _relayout_queued := false
var btn_h := 56.0 # command button height (48 on short portrait screens)


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
	var b := UI.button(text, cb, btn_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = disabled
	g.add_child(b)
	return b


# --- turn order ---------------------------------------------------------------

static func _alive(list: Array) -> Array:
	return list.filter(func(f): return int(f["hp"]) > 0)


static func _has(list: Array, f: Dictionary) -> bool:
	for x in list:
		if is_same(x, f):
			return true
	return false


func _start_round() -> void:
	_acted = []
	_begin_turn(_next_hero())


func _next_hero() -> Dictionary:
	for f in heroes:
		if int(f["hp"]) > 0 and not _has(_acted, f):
			return f
	return {}


func _begin_turn(f: Dictionary) -> void:
	if over or f.is_empty():
		return
	actor = f
	busy = false
	if is_team():
		arena.active = f
		title_lbl.text = "Your %s" % f["name"]
	_show_main_commands()


func _show_main_commands() -> void:
	_clear_cmds()
	_pending = {}
	arena.set_pick([])
	if over:
		return
	if is_team():
		title_lbl.text = "Your %s" % actor["name"]
	var g := _grid()
	_cmd(g, "Strike", func(): _choose({"type": "strike"}))
	_cmd(g, "Skills", _show_skills)
	_cmd(g, "Guard", func(): _choose({"type": "guard"}))
	var items := Game.items_usable_in("battle")
	_cmd(g, "Items (%d)" % items.size(), _show_items, items.is_empty())
	if not is_final:
		var r := UI.button("Retreat", _on_retreat, 48)
		cmd_box.add_child(r)


func _show_skills() -> void:
	_clear_cmds()
	for sk in actor["skills"]:
		var b := UI.button("%s  (%d MP)" % [sk["name"], sk["cost"]], func(): _choose({"type": "skill", "skill": sk}), btn_h)
		b.disabled = actor["mp"] < sk["cost"]
		b.tooltip_text = sk["desc"]
		cmd_box.add_child(b)
		var d := UI.label(sk["desc"], 15, UI.DIM)
		cmd_box.add_child(d)
	cmd_box.add_child(UI.button("Back", _show_main_commands, 48))


func _show_items() -> void:
	_clear_cmds()
	for id in Game.items_usable_in("battle"):
		var b := UI.button("%s  x%d" % [Game.item_name(id), Game.count(id)], func(): _choose({"type": "item", "item": id}), btn_h)
		b.tooltip_text = Game.item_desc(id)
		cmd_box.add_child(b)
	cmd_box.add_child(UI.button("Back", _show_main_commands, 48))


## Who an action is aimed at: "enemy", "ally" or "self".
static func target_kind(action: Dictionary) -> String:
	match String(action["type"]):
		"strike":
			return "enemy"
		"skill":
			var sk: Dictionary = action["skill"]
			return "enemy" if sk["kind"] == "phys" or sk["kind"] == "magic" else "self"
		"item":
			return "enemy" if action["item"] == "ash" else "ally"
	return "self"


## A command button was pressed: ask for a target when there is a choice.
func _choose(action: Dictionary) -> void:
	if busy or over:
		return
	var kind := target_kind(action)
	var pool: Array = []
	if kind == "enemy":
		pool = _alive(foes)
	elif kind == "ally":
		pool = _alive(heroes)
	if pool.size() <= 1:
		var t: Dictionary = pool[0] if pool.size() == 1 else actor
		_act(action, t)
		return
	_show_targets(action, pool, kind == "enemy")


func _show_targets(action: Dictionary, pool: Array, enemies: bool) -> void:
	_clear_cmds()
	_pending = action
	var what := "Strike"
	match String(action["type"]):
		"skill":
			what = String(action["skill"]["name"])
		"item":
			what = Game.item_name(action["item"])
	title_lbl.text = "%s: %s" % [what, "pick a target" if enemies else "pick an ally"]
	arena.set_pick(pool)
	var g := _grid()
	for f in pool:
		var tf: Dictionary = f
		var b := _cmd(g, "%s  %d/%d" % [tf["short"], tf["hp"], tf["max_hp"]], func(): _on_picked(tf))
		b.mouse_entered.connect(func(): arena.hover = tf)
		b.mouse_exited.connect(func():
			if is_same(arena.hover, tf):
				arena.hover = {})
	cmd_box.add_child(UI.button("Back", _show_main_commands, 48))


func _on_picked(f: Dictionary) -> void:
	if _pending.is_empty() or busy or over or not _has(arena.pick_list, f):
		return
	var action := _pending
	_pending = {}
	_act(action, f)


## The acting hero performs an action on a target, then the turn moves on.
func _act(action: Dictionary, target: Dictionary = {}) -> void:
	if busy or over:
		return
	busy = true
	_clear_cmds()
	arena.set_pick([])
	var a := actor
	if target.is_empty():
		var pool: Array = _alive(foes) if target_kind(action) == "enemy" else [a]
		target = pool[0]
	_acted.append(a)
	await _perform(a, target, action, true)
	if over:
		return
	if _alive(foes).is_empty():
		await _victory()
		return
	var nxt := _next_hero()
	if not nxt.is_empty():
		await get_tree().create_timer(0.2).timeout
		_begin_turn(nxt)
		return
	await _enemy_phase()


func _enemy_phase() -> void:
	arena.active = {}
	if is_team():
		title_lbl.text = "The enemy acts"
	await get_tree().create_timer(0.45).timeout
	for f in foes.duplicate():
		if over:
			return
		if int(f["hp"]) <= 0:
			continue
		var living := _alive(heroes)
		if living.is_empty():
			break
		if is_team():
			arena.active = f
		await _perform(f, enemy_target(f, living), _enemy_choice(f), false)
		if _alive(heroes).is_empty():
			arena.active = {}
			await _defeat()
			return
		if is_team():
			await get_tree().create_timer(0.3).timeout
	arena.active = {}
	if over:
		return
	_start_round()


func _enemy_choice(f: Dictionary) -> Dictionary:
	var skills: Array = f["skills"]
	var hp_k: float = float(f["hp"]) / float(f["max_hp"])
	var affordable := skills.filter(func(s): return f["mp"] >= s["cost"])
	for s in affordable:
		if s["kind"] == "heal" and hp_k < 0.35 and randf() < 0.6:
			return {"type": "skill", "skill": s}
	var attacks := affordable.filter(func(s): return s["kind"] == "phys" or s["kind"] == "magic")
	if not attacks.is_empty() and randf() < 0.42:
		return {"type": "skill", "skill": attacks[randi() % attacks.size()]}
	for s in affordable:
		if (s["kind"] == "buff_atk" and f.get("atk_up", 0) == 0) or (s["kind"] == "buff_def" and f.get("def_up", 0) == 0):
			if randf() < 0.25:
				return {"type": "skill", "skill": s}
	if randf() < 0.1:
		return {"type": "guard"}
	return {"type": "strike"}


## Foes mostly go for the weakest hero, sometimes for anyone.
static func enemy_target(_f: Dictionary, living: Array) -> Dictionary:
	if living.size() == 1 or randf() >= 0.55:
		return living[randi() % living.size()]
	var best: Dictionary = living[0]
	for h in living:
		if float(h["hp"]) / float(h["max_hp"]) < float(best["hp"]) / float(best["max_hp"]):
			best = h
	return best


# --- actions ------------------------------------------------------------------

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


func _tween_off(f: Dictionary, to: Vector2, dur: float, ease_in: bool) -> void:
	var tw := create_tween()
	var from: Vector2 = f["off"]
	tw.tween_method(func(v: Vector2): f["off"] = v, from, to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if ease_in else Tween.EASE_OUT)
	await tw.finished


func _lunge(a: Dictionary, d: Dictionary, magic: bool) -> void:
	if magic:
		await _tween_off(a, Vector2(0, -14), 0.18, false)
		await _tween_off(a, Vector2.ZERO, 0.18, true)
	else:
		await _tween_off(a, (arena.base(d) - arena.base(a)) * 0.55, 0.18, true)


func _return(a: Dictionary) -> void:
	await _tween_off(a, Vector2.ZERO, 0.22, false)


func _hit_fx(d: Dictionary, dmg: int, crit: bool, magic: bool, color: Color) -> void:
	var c := arena.center(d)
	arena.float_text(("%d!" % dmg) if crit else str(dmg), c - Vector2(0, 40), Color(1, 0.85, 0.3) if crit else Color(1, 1, 1))
	arena.burst(c, color, 30 if magic else 18)
	arena.shake = 0.6 if crit else 0.35
	d["flash"] = 1.0


func _who(f: Dictionary) -> String:
	return ("Your " if f["is_hero"] else "The ") + String(f["name"])


func _whom(f: Dictionary) -> String:
	return ("your " if f["is_hero"] else "the ") + String(f["name"])


func _perform(a: Dictionary, d: Dictionary, action: Dictionary, _a_is_hero: bool) -> void:
	fighter_acted.emit(a)
	a["guard"] = false
	var team := is_team()
	var aname := _who(a)
	var aimed := target_kind(action) == "enemy"
	if team and aimed:
		arena.target = d
	match String(action["type"]):
		"strike":
			_log("%s strikes %s!" % [aname, _whom(d)] if team else "%s strikes!" % aname)
			await _attack(a, d, 1.0, false, false, Color(1, 0.9, 0.7))
		"guard":
			a["guard"] = true
			a["mp"] = mini(a["max_mp"], a["mp"] + 4)
			_log("%s braces behind its guard. (+4 MP)" % aname)
			arena.rise(arena.center(a), Color(0.5, 0.75, 1.0), 14)
			await get_tree().create_timer(0.5).timeout
		"skill":
			var sk: Dictionary = action["skill"]
			a["mp"] -= int(sk["cost"])
			if team and aimed:
				_log("%s uses [b]%s[/b] on %s!" % [aname, sk["name"], _whom(d)])
			else:
				_log("%s uses [b]%s[/b]!" % [aname, sk["name"]])
			match String(sk["kind"]):
				"phys":
					await _attack(a, d, float(sk["power"]), false, sk.get("pierce", false), Color(1, 0.6, 0.3))
				"magic":
					await _attack(a, d, float(sk["power"]), true, false, Color(0.7, 0.5, 1.0) if a["color"] == 1 else Color(1, 0.9, 0.5))
				"heal":
					var amt := int(round(float(a["max_hp"]) * float(sk["power"])))
					a["hp"] = mini(a["max_hp"], a["hp"] + amt)
					if sk.has("def"):
						a["def"] += int(sk["def"])
						a["def_up"] = a.get("def_up", 0) + 1
					var c := arena.center(a)
					arena.float_text("+%d" % amt, c - Vector2(0, 40), UI.GREEN)
					arena.rise(c, UI.GREEN, 24)
					_log("%s recovers %d health." % [aname, amt])
					await get_tree().create_timer(0.6).timeout
				"buff_atk":
					a["atk"] += int(sk["power"])
					a["atk_up"] = a.get("atk_up", 0) + 1
					arena.rise(arena.center(a), UI.EMBER, 24)
					_log("%s's attack rises!" % aname)
					await get_tree().create_timer(0.6).timeout
				"buff_def":
					a["def"] += int(sk["power"])
					a["def_up"] = a.get("def_up", 0) + 1
					arena.rise(arena.center(a), Color(0.6, 0.7, 0.9), 24)
					_log("%s's defense rises!" % aname)
					await get_tree().create_timer(0.6).timeout
		"item":
			var id: String = action["item"]
			Game.remove_item(id)
			var who: Dictionary = d if (id != "ash" and not d.is_empty()) else a
			var c2 := arena.center(who)
			var giver := "You drink" if not team else ("%s drinks" % aname if is_same(who, a) else "%s hands %s" % [aname, _whom(who)])
			match id:
				"potion":
					var amt2 := mini(40, who["max_hp"] - who["hp"])
					who["hp"] += amt2
					arena.float_text("+%d" % amt2, c2 - Vector2(0, 40), UI.GREEN)
					arena.rise(c2, UI.GREEN, 24)
					_log("%s a Health Draught. (+%d HP)" % [giver, amt2])
				"ether":
					var amt3 := mini(25, who["max_mp"] - who["mp"])
					who["mp"] += amt3
					arena.float_text("+%d MP" % amt3, c2 - Vector2(0, 40), UI.BLUE)
					arena.rise(c2, UI.BLUE, 24)
					_log("%s a Mana Tincture. (+%d MP)" % [giver, amt3])
				"ash":
					d["blind"] = true
					arena.burst(arena.center(d), Color(0.6, 0.58, 0.56), 40, 160.0)
					_log("You hurl a pinch of ash into the %s's eyes! Its next attack will miss." % d["name"])
			await get_tree().create_timer(0.6).timeout
	arena.target = {}


func _attack(a: Dictionary, d: Dictionary, power: float, magic: bool, pierce: bool, color: Color) -> void:
	await _lunge(a, d, magic)
	if magic:
		# a bolt of light flies across
		var from := arena.center(a)
		var to := arena.center(d)
		for i in 10:
			arena.sparks.append({"p": from.lerp(to, i / 10.0), "v": Vector2.ZERO, "c": color, "t": 0.0, "life": 0.25 + i * 0.03, "r": 6.0, "grav": 0.0})
		await get_tree().create_timer(0.2).timeout
	if a.get("blind", false):
		a["blind"] = false
		_log("...but it is blinded by ash and misses!")
		arena.float_text("MISS", arena.center(d) - Vector2(0, 40), Color(0.7, 0.7, 0.7))
	else:
		var res := _damage(a, d, power, magic, pierce)
		d["hp"] = maxi(0, d["hp"] - int(res["dmg"]))
		_hit_fx(d, res["dmg"], res["crit"], magic, color)
		if res["crit"]:
			_log("[color=#e0aa4a]A crushing blow![/color] %d damage." % res["dmg"])
		else:
			_log("%d damage." % res["dmg"])
		if int(d["hp"]) <= 0:
			_down(d)
	if not magic:
		await _return(a)
	else:
		await get_tree().create_timer(0.25).timeout


## A fighter drops: it fades out and takes no further part.
func _down(f: Dictionary) -> void:
	f["guard"] = false
	f["blind"] = false
	var tw := create_tween()
	if f["is_hero"]:
		_log("[color=#e2643a][b]Your %s is beaten down...[/b][/color]" % f["name"])
		tw.tween_method(func(v: float): f["fade"] = v, float(f["fade"]), 0.25 if not is_team() else 0.15, 1.0)
	else:
		_log("[color=#e0aa4a][b]The %s falls![/b][/color]" % f["name"])
		arena.rise(arena.center(f), Color(0.55, 0.52, 0.5), 60 if not is_team() else 36)
		tw.tween_method(func(v: float): f["fade"] = v, float(f["fade"]), 0.0, 1.4)


func _victory() -> void:
	over = true
	result = "won"
	arena.active = {}
	Game.stats["fights"] += 1
	Game.consume_buffs(info["hero_id"])
	for i in range(1, heroes.size()):
		var f: Dictionary = heroes[i]
		if int(f["id"]) >= 0 and not Game.buffs_of(f["id"]).is_empty():
			Game.consume_buffs(f["id"])
	if is_team():
		title_lbl.text = "Victory"
		_log("[color=#e0aa4a][b]The enemy party is routed![/b][/color]")
	await get_tree().create_timer(1.4).timeout
	var m := Modal.new("Victory", 440.0)
	m.sticky = true
	var txt := "The %s is beaten. Return to the board to finish the capture." % foe["name"]
	if is_team():
		txt = "The %s and its allies are beaten. Return to the board to finish the capture." % foe["name"]
	m.add_text(txt if not is_final else "The enemy king kneels. Return to the board and watch it crumble.")
	m.add_buttons([["Return to the Board", func():
		m.close()
		finished.emit("won")]])
	add_child(m)


func _defeat() -> void:
	over = true
	result = "lost"
	if is_team():
		title_lbl.text = "Defeated"
	await get_tree().create_timer(1.0).timeout
	var m := Modal.new("Defeated", 440.0)
	m.sticky = true
	m.add_text("Your %s driven back, but this is a dream inside a capture. Try the %s again with your items restored%s." % [
		"pieces are" if heroes.size() > 1 else "piece is", "battle" if is_team() else "duel", "" if is_final else ", or retreat and call off the capture"])
	var specs := [["Try Again", func():
		m.close()
		_retry()]]
	if not is_final:
		specs.append(["Retreat", func():
			m.close()
			Game.restore(snap)
			result = "retreat"
			finished.emit("retreat")])
	m.add_buttons(specs)
	add_child(m)


func _retry() -> void:
	Game.restore(snap)
	_make_fighters()
	arena.heroes = heroes
	arena.foes = foes
	arena.reset_display()
	over = false
	busy = false
	result = ""
	title_lbl.text = _title()
	log_box.clear()
	_log("[color=#e0aa4a]You steel yourself and face the %s again.[/color]" % foe["name"])
	_start_round()


func _on_retreat() -> void:
	if busy:
		return
	var m := Modal.new("Retreat?", 440.0)
	m.add_text("Abandon the %s? The capture will be called off and you may choose another move." % ("battle" if is_team() else "duel"))
	m.add_buttons([["Retreat", func():
		m.close()
		over = true
		result = "retreat"
		Game.restore(snap)
		finished.emit("retreat")], ["Fight on", m.close]])
	add_child(m)
