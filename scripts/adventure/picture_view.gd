class_name PictureView
extends Control
## The framed "picture in a box": draws the current room and reports taps.

signal clicked(kind: String, id: String)

const TITLE_H := 30.0
const STATUS_H := 30.0

var lab: Labyrinth
var prompt := ""
var hover_kind := ""
var hover_id := ""
var flash_kind := ""
var flash_id := ""
var flash_t := 0.0
var crumble := -1.0
var _t := 0.0
var _ash: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func pic_rect() -> Rect2:
	return Rect2(Vector2(0, TITLE_H), Vector2(size.x, size.y - TITLE_H - STATUS_H))


func _process(delta: float) -> void:
	_t += delta
	if flash_t > 0.0:
		flash_t -= delta
	if crumble >= 0.0:
		crumble += delta
		var r := pic_rect()
		for i in 6:
			_ash.append({"p": Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y)),
				"v": Vector2(randf_range(-10, 30), randf_range(-40, -10)), "life": randf_range(0.8, 2.0), "age": 0.0})
		for a in _ash:
			a["age"] += delta
			a["p"] += a["v"] * delta
		_ash = _ash.filter(func(a): return a["age"] < a["life"])
	queue_redraw()


func _to_norm(p: Vector2) -> Vector2:
	var r := pic_rect()
	return (p - r.position) / r.size


func _hit(p: Vector2) -> Dictionary:
	if lab == null:
		return {}
	var r := pic_rect()
	if not r.has_point(p):
		return {}
	var n := _to_norm(p)
	var objs := lab.room_objects(lab.current)
	for i in range(objs.size() - 1, -1, -1):
		var o: Dictionary = objs[i]
		if o.get("passthrough_open", false) and o["st"].get("open", false):
			continue
		var rr: Rect2 = o["rect"]
		if rr.grow(0.012).has_point(n):
			return {"kind": "obj", "id": o["id"]}
	var exits := lab.visible_exits(lab.current)
	for d in exits:
		var er: Rect2 = RoomArt.EXIT_RECTS[d]
		if er.has_point(n):
			return {"kind": "exit", "id": d}
	return {"kind": "none", "id": ""}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit(event.position)
		hover_kind = h.get("kind", "")
		hover_id = h.get("id", "")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var h := _hit(event.position)
		if h.is_empty():
			return
		flash_kind = h["kind"]
		flash_id = h["id"]
		flash_t = 0.35
		clicked.emit(h["kind"], h["id"])
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_kind = ""
		hover_id = ""


func label_for(kind: String, id: String) -> String:
	if kind == "obj":
		return lab.objects[id]["name"]
	if kind == "exit":
		var ex: Dictionary = lab.rooms[lab.current]["exits"][id]
		var dest: Dictionary = lab.rooms[ex["to"]]
		var where: String = dest["name"] if dest["visited"] else "???"
		var word := {"north": "North", "south": "Back", "east": "East", "west": "West", "up": "Up", "down": "Down"}
		return "%s: %s" % [word.get(id, id), where]
	return ""


func _draw() -> void:
	if lab == null:
		return
	var room: Dictionary = lab.rooms[lab.current]
	var full := Rect2(Vector2.ZERO, size)
	UI.draw_frame(self, full, room["name"], TITLE_H)
	var r := pic_rect()
	var font := ThemeDB.fallback_font
	RoomArt.draw_room(self, r, room["theme"], _t)
	var lit := lab.is_lit(lab.current)
	var exits := lab.visible_exits(lab.current)
	for d in exits:
		var hl: bool = (hover_kind == "exit" and hover_id == d) or (flash_t > 0 and flash_kind == "exit" and flash_id == d)
		RoomArt.draw_exit(self, r, d, exits[d], hl, _t)
	for o in lab.room_objects(lab.current):
		var rr: Rect2 = o["rect"]
		var b := Rect2(r.position + rr.position * r.size, rr.size * r.size)
		ObjectArt.draw(self, o, b, _t, lab.foe_white)
		var is_hover: bool = hover_kind == "obj" and hover_id == o["id"]
		var is_flash: bool = flash_t > 0 and flash_kind == "obj" and flash_id == o["id"]
		if is_hover or is_flash:
			var a := 0.8 if is_hover else flash_t / 0.35
			draw_rect(b.grow(4), Color(1.0, 0.82, 0.4, a), false, 2.0)
	if not lit:
		draw_rect(r, Color(0, 0, 0, 0.93))
		for d in exits:
			if d == "south" or d == "east" or d == "west":
				RoomArt.draw_exit(self, r, d, exits[d], hover_kind == "exit" and hover_id == d, _t)
		var msg := "Too dark to see."
		var tw := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(font, r.get_center() - Vector2(tw * 0.5, 0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.55, 0.5, 0.8))
	RoomArt.vignette(self, r, 0.5)
	_draw_minimap(r)
	# hover label (mouse users)
	if hover_kind == "obj" or hover_kind == "exit":
		var txt := label_for(hover_kind, hover_id)
		var fs := 18
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(r.position.x + 10, r.position.y + 10)
		draw_rect(Rect2(p - Vector2(6, 2), Vector2(w + 12, fs + 10)), Color(0, 0, 0, 0.65))
		draw_string(font, p + Vector2(0, fs), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.9, 0.7))
	# crumbling into ash when solved
	if crumble >= 0.0:
		var k := clampf(crumble / 2.5, 0.0, 1.0)
		draw_rect(r, Color(0.35, 0.33, 0.32, k * 0.75))
		for a in _ash:
			var age: float = a["age"] / a["life"]
			var c := Color(1.0, 0.6, 0.25).lerp(Color(0.5, 0.48, 0.47), clampf(age * 2.5, 0, 1))
			c.a = 1.0 - age
			draw_rect(Rect2(a["p"], Vector2(3, 3)), c)
	UI.draw_title_bar(self, full, room["name"], TITLE_H)
	# status strip
	var sr := Rect2(Vector2(0, size.y - STATUS_H), Vector2(size.x, STATUS_H))
	draw_rect(sr, Color(0.84, 0.78, 0.66))
	draw_line(sr.position, Vector2(sr.end.x, sr.position.y), Color(0.42, 0.33, 0.24), 2.0)
	draw_string(font, Vector2(10, size.y - 9), prompt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 17, Color(0.12, 0.09, 0.08))


func _draw_minimap(r: Rect2) -> void:
	var minx := 999
	var maxx := -999
	var miny := 999
	var maxy := -999
	for rid in lab.rooms:
		var g: Vector2i = lab.rooms[rid]["grid"]
		minx = mini(minx, g.x)
		maxx = maxi(maxx, g.x)
		miny = mini(miny, g.y)
		maxy = maxi(maxy, g.y)
	var cell := clampf(r.size.x * 0.035, 12.0, 20.0)
	var gw := (maxx - minx + 1) * cell * 1.6
	var gh := (maxy - miny + 1) * cell * 1.6
	var origin := Vector2(r.end.x - gw - 10, r.position.y + 10)
	draw_rect(Rect2(origin - Vector2(6, 6), Vector2(gw + 12, gh + 12)), Color(0, 0, 0, 0.55))
	var known := {}
	for rid in lab.rooms:
		var room: Dictionary = lab.rooms[rid]
		if not room["visited"]:
			continue
		known[rid] = true
		for d in room["exits"]:
			var ex: Dictionary = room["exits"][d]
			if not ex["hidden"]:
				known[ex["to"]] = true
	var centers := {}
	for rid in known:
		var g: Vector2i = lab.rooms[rid]["grid"]
		centers[rid] = origin + Vector2((g.x - minx) * cell * 1.6 + cell * 0.8, (g.y - miny) * cell * 1.6 + cell * 0.8)
	for rid in known:
		if not lab.rooms[rid]["visited"]:
			continue
		for d in lab.rooms[rid]["exits"]:
			var ex: Dictionary = lab.rooms[rid]["exits"][d]
			if ex["hidden"] or not centers.has(ex["to"]):
				continue
			var c := Color(0.85, 0.3, 0.2, 0.8) if ex["locked"] else Color(0.8, 0.75, 0.65, 0.7)
			draw_line(centers[rid], centers[ex["to"]], c, 2.0)
	for rid in known:
		var c2: Vector2 = centers[rid]
		var rect := Rect2(c2 - Vector2(cell, cell) * 0.5, Vector2(cell, cell))
		if rid == lab.current:
			draw_rect(rect, UI.GOLD)
		elif lab.rooms[rid]["visited"]:
			draw_rect(rect, Color(0.6, 0.56, 0.5))
		else:
			draw_rect(rect, Color(0.3, 0.28, 0.26, 0.6))
			draw_rect(rect, Color(0.6, 0.56, 0.5, 0.6), false, 1.0)
