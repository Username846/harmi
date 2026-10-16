class_name ItemSlot
extends Button
## A square button that shows an item icon and its count.

var item_id := ""
var selected := false
var _t := 0.0


func _init(id: String = "", px: float = 64.0) -> void:
	item_id = id
	custom_minimum_size = Vector2(px, px)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = Game.item_name(id) if id != "" else ""


func _process(delta: float) -> void:
	_t += delta
	var icon_id: String = Game.ITEMS.get(item_id, {}).get("icon", "")
	if icon_id.ends_with("_lit") or icon_id == "ash":
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selected:
		draw_rect(r.grow(-2), Color(0.88, 0.67, 0.29, 0.25))
		draw_rect(r.grow(-2), UI.GOLD, false, 3.0)
	if item_id == "":
		return
	var side := minf(size.x, size.y) * 0.78
	var ir := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	ItemArt.draw_icon(self, item_id, ir, _t)
	var n := Game.count(item_id)
	if n > 1:
		var font := ThemeDB.fallback_font
		var fs := int(size.y * 0.28)
		var txt := "x%d" % n
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(size.x - tw - 6, size.y - 6)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
