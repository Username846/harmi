class_name SurvivalItemSlot
extends Button
## A square inventory button for the survival screen: item icon and count.

var item_id := ""
var count := 0
var _t := 0.0


func _init(id: String = "", n: int = 1, px: float = 54.0) -> void:
	item_id = id
	count = n
	custom_minimum_size = Vector2(px, px)
	focus_mode = Control.FOCUS_NONE
	if SurvivalSim.ITEMS.has(id):
		tooltip_text = "%s\n%s" % [SurvivalSim.item_name(id), String(SurvivalSim.ITEMS[id]["desc"])]


func _process(delta: float) -> void:
	_t += delta
	if item_id in ["flare", "radio_part", "mirror", "pawn", "beyblade"]:
		queue_redraw()


func _draw() -> void:
	if item_id == "":
		return
	var side := minf(size.x, size.y) * 0.8
	var ir := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	SurvivalArt.draw_item(self, item_id, ir, _t)
	if SurvivalSim.CONSUMABLE.has(item_id):
		draw_circle(Vector2(8, 8), 3.5, UI.GREEN)
	if count > 1:
		var font := ThemeDB.fallback_font
		var fs := int(clampf(size.y * 0.3, 15.0, 20.0))
		var txt := "x%d" % count
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2(size.x - tw - 5, size.y - 5)
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
