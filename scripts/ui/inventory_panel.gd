class_name InventoryPanel
extends Modal
## Modal inventory. context: "view" (just browse), "board" or "battle"
## (shows a Use button for items usable in that context).

signal item_used(id: String)

var context := "view"
var filter_usable := false
var selected_id := ""
var grid: GridContainer
var desc: Label
var use_btn: Button
var empty_note: Label


func _init(ctx: String = "view", title: String = "Inventory", only_usable: bool = false) -> void:
	super(title, 600.0)
	context = ctx
	filter_usable = only_usable
	grid = GridContainer.new()
	grid.columns = 5
	body.add_child(grid)
	empty_note = add_text("Your satchel is empty.", UI.FONT_SIZE, UI.DIM)
	desc = add_text("Tap an item to examine it.", UI.FONT_SIZE, UI.DIM)
	desc.custom_minimum_size = Vector2(0, 74)
	var row := HBoxContainer.new()
	body.add_child(row)
	if context != "view":
		use_btn = UI.button("Use", _on_use)
		use_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use_btn.disabled = true
		row.add_child(use_btn)
	var close_btn := UI.button("Close", close)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(close_btn)
	_refresh()


func _refresh() -> void:
	for c in grid.get_children():
		c.queue_free()
	var ids: Array = Game.items_usable_in(context) if filter_usable else Game.item_ids()
	empty_note.visible = ids.is_empty()
	for id in ids:
		var slot := ItemSlot.new(id, 76.0)
		slot.pressed.connect(_select.bind(id))
		slot.selected = id == selected_id
		grid.add_child(slot)


func _select(id: String) -> void:
	selected_id = id
	var usable: bool = Game.ITEMS[id].get("use", []).has(context)
	var txt := "%s\n%s" % [Game.item_name(id), Game.item_desc(id)]
	var uses: Array = Game.ITEMS[id].get("use", [])
	if (context == "view" or context == "turn") and uses.has("board"):
		txt += "\n(Tap one of your pieces on the board and choose Use Item.)"
	elif context == "view" and uses.has("turn"):
		txt += "\n(Open the Inventory on your turn to use it.)"
	desc.text = txt
	desc.add_theme_color_override("font_color", UI.TEXT)
	if use_btn:
		use_btn.disabled = not usable
		use_btn.text = "Use " + Game.item_name(id) if usable else "Can't use here"
	for s in grid.get_children():
		s.selected = s.item_id == id
		s.queue_redraw()


func _on_use() -> void:
	if selected_id == "":
		return
	var id := selected_id
	close()
	item_used.emit(id)
