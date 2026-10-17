class_name CardData
extends RefCounted
## Placeholder until the card game lands.

static func booster() -> Array:
	return ["pawn", "pawn"]


static func card_name(id: String) -> String:
	return id.capitalize()
