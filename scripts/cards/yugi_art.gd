class_name YugiArt
extends RefCounted
## Placeholder until the card game lands.

static func draw(ci: CanvasItem, rect: Rect2, _t: float, _expression: String = "smug") -> void:
	ci.draw_rect(rect, Color(0.4, 0.2, 0.5))
