class_name Labyrinth
extends RefCounted
## Base class for a captured piece's inner labyrinth (picture-in-a-box adventure).
## Subclasses build rooms/objects in build() and react to verbs in on_action().
## Verbs: "open", "inspect", "punch", "use", "go".

const OPPOSITE := {"north": "south", "south": "north", "east": "west", "west": "east", "up": "down", "down": "up"}
const LIGHTS := ["lantern_lit", "torch_lit", "candle_lit"]

var id := ""
var title := ""
var intro := ""
var hero := "White Knight"
var foe := "Black Pawn"
var foe_white := false
var rooms: Dictionary = {}
var objects: Dictionary = {}
var obj_order: Array = []
var current := ""
var solved := false
var flags: Dictionary = {}
var _out: Array = []


func setup(hero_name: String, foe_name: String, foe_is_white: bool) -> void:
	hero = hero_name
	foe = foe_name
	foe_white = foe_is_white
	build()
	if current == "" and not rooms.is_empty():
		current = rooms.keys()[0]
	rooms[current]["visited"] = true
	rooms[current]["seen"] = is_lit(current)


## Override: create rooms, objects and the starting room.
func build() -> void:
	pass


## Override: handle a verb on an object. Return true if handled.
func on_action(_verb: String, _o: Dictionary, _item: String) -> bool:
	return false


## Override: handle a verb on an exit. Return true if handled.
func on_exit_action(_verb: String, _dir: String, _item: String) -> bool:
	return false


## Override: combine or use inventory items. Return true if handled.
func on_item_action(_verb: String, _item: String, _other: String) -> bool:
	return false


## Override: called after entering a room.
func on_enter(_room: String) -> void:
	pass


## Override: context-sensitive hint.
func hint() -> String:
	return "Inspect everything. Things that won't open can sometimes be punched."


# --- building ---------------------------------------------------------------

func add_room(rid: String, rname: String, grid: Vector2i, theme: String, desc: String, dark: bool = false) -> Dictionary:
	var r := {"id": rid, "name": rname, "grid": grid, "theme": theme, "desc": desc, "dark": dark,
		"dark_desc": "It is pitch black. You can't see a thing.", "exits": {}, "visited": false}
	rooms[rid] = r
	return r


func link(a: String, dir: String, b: String, kind: String = "door", locked: bool = false, lock_msg: String = "", hidden: bool = false) -> void:
	rooms[a]["exits"][dir] = {"to": b, "kind": kind, "locked": locked, "lock_msg": lock_msg, "hidden": hidden}
	var back: String = OPPOSITE[dir]
	var back_kind := kind
	if kind == "stairs_up":
		back_kind = "stairs_down"
	elif kind == "hatch":
		back_kind = "ladder_up"
	elif kind == "rope_down":
		back_kind = "rope_up"
	rooms[b]["exits"][back] = {"to": a, "kind": back_kind, "locked": locked, "lock_msg": lock_msg, "hidden": hidden}


func add_obj(oid: String, room: String, oname: String, art: String, rect: Rect2, desc: String, extra: Dictionary = {}) -> Dictionary:
	var o := {"id": oid, "room": room, "name": oname, "art": art, "rect": rect, "desc": desc,
		"hidden": false, "pickup": "", "st": {}, "color": Color(0.5, 0.4, 0.3)}
	for k in extra:
		o[k] = extra[k]
	objects[oid] = o
	obj_order.append(oid)
	return o


func add_pickup(oid: String, room: String, item_id: String, rect: Rect2, desc: String) -> Dictionary:
	return add_obj(oid, room, Game.item_name(item_id), "item", rect, desc, {"pickup": item_id})


# --- helpers for subclasses -------------------------------------------------

func fmt(text: String) -> String:
	return text.replace("{foe}", foe).replace("{hero}", hero)


func say(text: String) -> void:
	_out.append(fmt(text))


func give(item_id: String, text: String = "") -> void:
	if text != "":
		say(text)
	Game.add_item(item_id)
	say("[color=#e0aa4a](%s added to your satchel.)[/color]" % Game.item_name(item_id))


func take(item_id: String) -> void:
	Game.remove_item(item_id)


func has(item_id: String) -> bool:
	return Game.has_item(item_id)


func obj(oid: String) -> Dictionary:
	return objects[oid]


func st(oid: String, key: String, default: Variant = false) -> Variant:
	return objects[oid]["st"].get(key, default)


func set_st(oid: String, key: String, value: Variant) -> void:
	objects[oid]["st"][key] = value


func reveal(oid: String) -> void:
	objects[oid]["hidden"] = false


func hide_obj(oid: String) -> void:
	objects[oid]["hidden"] = true


func unlock(room: String, dir: String) -> void:
	var ex: Dictionary = rooms[room]["exits"][dir]
	ex["locked"] = false
	ex["hidden"] = false
	var other: Dictionary = rooms[ex["to"]]["exits"][OPPOSITE[dir]]
	other["locked"] = false
	other["hidden"] = false


func complete(text: String) -> void:
	say(text)
	solved = true


func is_lit(room: String) -> bool:
	if not rooms[room]["dark"]:
		return true
	for l in LIGHTS:
		if has(l):
			return true
	return false


func room_objects(room: String) -> Array:
	var out: Array = []
	if not is_lit(room):
		return out
	for oid in obj_order:
		var o: Dictionary = objects[oid]
		if o["room"] == room and not o["hidden"]:
			out.append(o)
	return out


func visible_exits(room: String) -> Dictionary:
	var out := {}
	var ex: Dictionary = rooms[room]["exits"]
	for d in ex:
		if not ex[d]["hidden"]:
			out[d] = ex[d]
	return out


func describe_room(room: String) -> String:
	var r: Dictionary = rooms[room]
	if not is_lit(room):
		return fmt(r["dark_desc"])
	return fmt(r["desc"])


# --- verbs ------------------------------------------------------------------

## Performs an action and returns the resulting lines of text.
func act(verb: String, kind: String, target: String, item: String = "") -> Array:
	_out.clear()
	match kind:
		"obj":
			_act_obj(verb, objects[target], item)
		"exit":
			_act_exit(verb, target, item)
		"item":
			_act_item(verb, target, item)
	return _out.duplicate()


func _act_obj(verb: String, o: Dictionary, item: String) -> void:
	if on_action(verb, o, item):
		return
	var n: String = o["name"]
	if o["pickup"] != "":
		match verb:
			"punch":
				say("You punch the %s. It skitters across the floor. You pick it up anyway." % n.to_lower())
			"inspect":
				say(o["desc"])
			"use":
				if item != "":
					say("You poke it with the %s, then decide to just pick it up." % Game.item_name(item).to_lower())
				else:
					say("You pick it up.")
			_:
				say("You pick it up.")
		hide_obj(o["id"])
		give(o["pickup"])
		return
	var lname := n.to_lower()
	match verb:
		"inspect":
			say(o["desc"])
		"open":
			say("The %s doesn't open." % lname)
		"punch":
			var lines := ["You punch the %s. Your knuckles complain.", "You hit the %s. Nothing happens, except pain.",
				"WHAM. The %s is unimpressed."]
			say(lines[randi() % lines.size()] % lname)
		"use":
			if item != "":
				say("Using the %s on the %s does nothing." % [Game.item_name(item).to_lower(), lname])
			else:
				say("You can't think of a way to use the %s." % lname)
		"go":
			say("You can't walk into the %s." % lname)


func _act_exit(verb: String, dir: String, item: String) -> void:
	if on_exit_action(verb, dir, item):
		return
	var ex: Dictionary = rooms[current]["exits"][dir]
	var dest: Dictionary = rooms[ex["to"]]
	var where: String = dest["name"] if dest["visited"] else "somewhere new"
	match verb:
		"go":
			go(dir)
		"inspect":
			if ex["locked"]:
				say(ex["lock_msg"] if ex["lock_msg"] != "" else "The way %s is blocked." % dir)
			else:
				say("A way %s, leading to %s." % [_dir_word(dir), where])
		"open":
			if ex["locked"]:
				say(ex["lock_msg"] if ex["lock_msg"] != "" else "It won't open.")
			else:
				say("It's open. Choose GO to pass through.")
		"punch":
			say("You punch the doorway. The doorway wins.")
		"use":
			if item != "":
				say("The %s doesn't help here." % Game.item_name(item).to_lower())
			else:
				go(dir)


func _act_item(verb: String, item: String, other: String) -> void:
	if on_item_action(verb, item, other):
		return
	var n := Game.item_name(item).to_lower()
	match verb:
		"inspect":
			say(Game.item_desc(item))
		"open":
			say("You fiddle with the %s. Nothing opens." % n)
		"punch":
			say("You punch your own %s. Why?" % n)
		"use":
			if other != "" and other != item:
				say("The %s and the %s don't go together." % [Game.item_name(other).to_lower(), n])
			elif item == "potion" or item == "ether":
				say("Better to save that for a fight.")
			elif item == "ash":
				say("You let a little ash run through your fingers. It's still warm.")
			else:
				say("You turn the %s over in your hands. Use it on something in the picture." % n)
		_:
			say("Nothing happens.")


func go(dir: String) -> void:
	var ex: Dictionary = rooms[current]["exits"].get(dir, {})
	if ex.is_empty():
		say("You can't go that way.")
		return
	if ex["locked"]:
		say(ex["lock_msg"] if ex["lock_msg"] != "" else "The way is blocked.")
		return
	current = ex["to"]
	var r: Dictionary = rooms[current]
	r["visited"] = true
	say("[b][color=#e0aa4a]%s[/color][/b]" % r["name"])
	if not is_lit(current):
		say(describe_room(current))
	elif not r.get("seen", false):
		r["seen"] = true
		say(describe_room(current))
	on_enter(current)


static func _dir_word(dir: String) -> String:
	match dir:
		"up": return "up"
		"down": return "down"
	return dir
