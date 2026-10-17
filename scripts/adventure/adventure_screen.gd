class_name AdventureScreen
extends Control
## The labyrinth inside a captured piece: picture box, command verbs,
## inventory and message log.

signal finished(result: String)

const LABS := {
	"trench": preload("res://scripts/adventure/labs/lab_trench.gd"),
	"well": preload("res://scripts/adventure/labs/lab_well.gd"),
	"barracks": preload("res://scripts/adventure/labs/lab_barracks.gd"),
	"tower": preload("res://scripts/adventure/labs/lab_tower.gd"),
	"undercroft": preload("res://scripts/adventure/labs/lab_undercroft.gd"),
	"chapel": preload("res://scripts/adventure/labs/lab_chapel.gd"),
	"scriptorium": preload("res://scripts/adventure/labs/lab_scriptorium.gd"),
}
const VERBS := ["open", "inspect", "punch", "use", "go"]

var info: Dictionary = {}
var lab: Labyrinth
var picture: PictureView
var verb_bar: HBoxContainer
var verb_buttons: Dictionary = {}
var panel: PanelContainer
var header: Label
var log_box: RichTextLabel
var inv_grid: GridContainer
var inv_label: Label
var verb := ""
var held := ""
var done := false


func setup(i: Dictionary) -> void:
	info = i
	var script: GDScript = LABS.get(i["lab"], LABS["trench"])
	lab = script.new()
	lab.id = i["lab"]
	lab.setup(Game.piece_title(i["hero_type"], i["hero_color"]), Game.piece_title(i["foe_type"], i["foe_color"]), i["foe_color"] == 0)
	if i.has("start_room") and lab.rooms.has(i["start_room"]):
		# testing shortcut: start elsewhere, with a light source and every way open
		lab.current = i["start_room"]
		Game.add_item("torch_lit")
		for rid in lab.rooms:
			lab.rooms[rid]["visited"] = true
			for d in lab.rooms[rid]["exits"]:
				lab.rooms[rid]["exits"][d]["hidden"] = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture = PictureView.new()
	picture.lab = lab
	picture.gloom = Game.gloom_for(float(info.get("foe_mood", Game.START_MOOD)))
	picture.clicked.connect(_on_picture_clicked)
	add_child(picture)

	verb_bar = HBoxContainer.new()
	verb_bar.add_theme_constant_override("separation", 6)
	add_child(verb_bar)
	for v in VERBS:
		var b := UI.button(v.to_upper(), _on_verb.bind(v), 54)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		verb_bar.add_child(b)
		verb_buttons[v] = b

	panel = PanelContainer.new()
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	header = UI.label(lab.title, 24, UI.GOLD)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(header)
	head.add_child(BeybladeButton.new(52.0))
	var row := HBoxContainer.new()
	vb.add_child(row)
	var hint_btn := UI.button("Hint", _on_hint, 46)
	hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint_btn)
	var retreat := UI.button("Retreat", _on_retreat, 46)
	retreat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(retreat)
	var help := UI.button("?", func(): Help.show(self), 46)
	help.custom_minimum_size.x = 50
	row.add_child(help)
	log_box = UI.rich(17)
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.custom_minimum_size = Vector2(0, 90)
	vb.add_child(log_box)
	inv_label = UI.label("Satchel", 16, UI.DIM)
	vb.add_child(inv_label)
	inv_grid = GridContainer.new()
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(inv_grid)

	Game.inventory_changed.connect(_refresh_inventory)
	resized.connect(_relayout)
	panel.minimum_size_changed.connect(_queue_relayout)
	_log("[i]%s[/i]" % lab.fmt(lab.intro))
	if picture.gloom > 0.05:
		var fm := float(info.get("foe_mood", Game.START_MOOD))
		var how := "dim" if picture.gloom < 0.35 else ("dark" if picture.gloom < 0.7 else "almost pitch black")
		_log("[color=#8f96b8]The %s is %s, so its labyrinth is %s. Your light follows your pointer (or your last tap).%s[/color]" % [lab.foe, Game.mood_name(fm).to_lower(), how, " Your headlamp helps." if Game.has_item("headlamp") else ""])
	_log("[b][color=#e0aa4a]%s[/color][/b]" % lab.rooms[lab.current]["name"])
	_log(lab.describe_room(lab.current))
	_log("[color=#a9a39f]Choose a command below, then tap something in the picture. Tap doorways and arrows to move.[/color]")
	_update_prompt()
	_relayout()
	_refresh_inventory()


func _exit_tree() -> void:
	if Game.inventory_changed.is_connected(_refresh_inventory):
		Game.inventory_changed.disconnect(_refresh_inventory)


func _relayout() -> void:
	var w := size.x
	var h := size.y
	var m := 12.0
	var chrome := PictureView.TITLE_H + PictureView.STATUS_H
	var verbs_h := 54.0
	if w >= h * 1.15:
		var rw := clampf(w * 0.36, 290.0, 440.0)
		var avail_w := w - rw - m * 3.0
		var avail_h := h - m * 3.0 - verbs_h
		var pw := minf(avail_w, (avail_h - chrome) * 4.0 / 3.0)
		var ph := pw * 0.75 + chrome
		var px := m + (avail_w - pw) * 0.5
		picture.position = Vector2(px, m)
		picture.size = Vector2(pw, ph)
		verb_bar.position = Vector2(px, m * 2.0 + ph)
		verb_bar.size = Vector2(pw, verbs_h)
		panel.position = Vector2(w - rw - m, m)
		panel.size = Vector2(rw, h - m * 2.0)
		_set_columns(rw - 28.0)
	else:
		var pw2 := w - m * 2.0
		var ph2 := minf(pw2 * 0.75 + chrome, h * 0.5)
		pw2 = minf(pw2, (ph2 - chrome) * 4.0 / 3.0)
		var px2 := (w - pw2) * 0.5
		picture.position = Vector2(px2, m)
		picture.size = Vector2(pw2, ph2)
		verb_bar.position = Vector2(m, m * 2.0 + ph2)
		verb_bar.size = Vector2(w - m * 2.0, verbs_h)
		var top := m * 3.0 + ph2 + verbs_h
		panel.position = Vector2(m, top)
		panel.size = Vector2(w - m * 2.0, h - top - m)
		_set_columns(w - m * 2.0 - 28.0)


var _relayout_queued := false


func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	await get_tree().process_frame
	_relayout_queued = false
	_relayout()


func _set_columns(width: float) -> void:
	inv_grid.columns = maxi(3, int((width + 6.0) / 66.0))


func _log(text: String) -> void:
	log_box.append_text(text + "\n")


func _refresh_inventory() -> void:
	if inv_grid == null:
		return
	for c in inv_grid.get_children():
		c.queue_free()
	# puzzle items first, then everything else
	var ids: Array = []
	for id in Game.item_ids():
		if Game.ITEMS[id].get("scope", "global") == "puzzle":
			ids.append(id)
	for id in Game.item_ids():
		if not ids.has(id):
			ids.append(id)
	if held != "" and not Game.has_item(held):
		held = ""
		_update_prompt()
	for id in ids:
		var slot := ItemSlot.new(id, 60.0)
		slot.selected = id == held
		slot.pressed.connect(_on_item.bind(id))
		inv_grid.add_child(slot)
	inv_label.text = "Satchel (%d)" % ids.size()


func _on_verb(v: String) -> void:
	if done:
		return
	if verb == v:
		verb = ""
	else:
		verb = v
	if verb != "use":
		held = ""
	for k in verb_buttons:
		verb_buttons[k].button_pressed = k == verb
	_refresh_inventory()
	_update_prompt()


func _update_prompt() -> void:
	var p := ""
	match verb:
		"":
			p = "Choose a command, then tap the picture."
		"use":
			if held != "":
				p = "USE %s on... (tap a target, or the item again)" % Game.item_name(held)
			else:
				p = "USE what? Tap an item in your satchel or something in the picture."
		"go":
			p = "GO where? Tap a doorway or arrow."
		_:
			p = "%s what?" % verb.to_upper()
	picture.prompt = p


func _target_name(kind: String, id: String) -> String:
	if kind == "obj":
		return String(lab.objects[id]["name"])
	if kind == "exit":
		return {"north": "north", "south": "back", "east": "east", "west": "west", "up": "up", "down": "down"}.get(id, id)
	if kind == "item":
		return Game.item_name(id)
	return ""


func _on_picture_clicked(kind: String, id: String) -> void:
	if done:
		return
	if kind == "none":
		if held != "":
			held = ""
			_refresh_inventory()
			_update_prompt()
		return
	var v := verb
	if v == "":
		v = "go" if kind == "exit" else "inspect"
	var item := held if v == "use" else ""
	var echo := "> %s %s" % [v.to_upper(), _target_name(kind, id)]
	if item != "":
		echo = "> USE %s on %s" % [Game.item_name(item), _target_name(kind, id)]
	_log("[color=#8f877d]%s[/color]" % echo)
	var lines := lab.act(v, kind, id, item)
	for l in lines:
		_log(l)
	if item != "":
		held = ""
		_refresh_inventory()
	_update_prompt()
	if lab.solved:
		_on_solved()


func _on_item(id: String) -> void:
	if done:
		return
	var lines: Array = []
	if verb == "use":
		if held == "":
			held = id
			_refresh_inventory()
			_update_prompt()
			return
		if held == id:
			_log("[color=#8f877d]> USE %s[/color]" % Game.item_name(id))
			lines = lab.act("use", "item", id, "")
		else:
			_log("[color=#8f877d]> USE %s on %s[/color]" % [Game.item_name(held), Game.item_name(id)])
			lines = lab.act("use", "item", id, held)
		held = ""
	else:
		var v := verb if verb != "" and verb != "go" else "inspect"
		_log("[color=#8f877d]> %s %s[/color]" % [v.to_upper(), Game.item_name(id)])
		lines = lab.act(v, "item", id, "")
	for l in lines:
		_log(l)
	_refresh_inventory()
	_update_prompt()
	if lab.solved:
		_on_solved()


func _on_hint() -> void:
	if done:
		return
	_log("[color=#6fb3d9]Hint: %s[/color]" % lab.hint())


func _on_retreat() -> void:
	if done:
		return
	var m := Modal.new("Retreat?", 440.0)
	m.add_text("Flee the labyrinth? Your capture will be called off and you can choose another move. Items found here will be lost.")
	m.add_buttons([["Retreat", func():
		m.close()
		done = true
		finished.emit("retreat")], ["Stay", m.close]])
	add_child(m)


func _on_solved() -> void:
	done = true
	Game.stats["puzzles"] += 1
	picture.crumble = 0.0
	picture.prompt = "The labyrinth crumbles..."
	await get_tree().create_timer(1.6).timeout
	var m := Modal.new("The %s is Undone" % lab.foe, 460.0)
	m.sticky = true
	m.add_text("Its heart is broken and its labyrinth is ash. Return to the board to finish the capture.")
	m.add_buttons([["Return to the Board", func():
		m.close()
		finished.emit("won")]])
	add_child(m)
