class_name ShopPanel
extends Modal
## The strip-mall shop that sprang up beside the board. Spend odd-job money on
## goods, some of which are actually useful.

signal bought(id: String, note: String)

const TILE := 92.0
const QUIPS := {
	"double_move": "Don't drink it all at once. Actually, do.",
	"sniper": "I didn't sell you that.",
	"driveby": "They're very punctual. Mostly.",
	"used_car": "Only one previous owner. He was a pawn.",
	"nitrous": "Blue means fast. Everybody knows that.",
	"roses": "Smooth.",
	"headlamp": "Fashion AND function.",
	"beyblade": "Pull gently this time.",
	"gourd": "A connoisseur, I see.",
	"spoon": "Truly commemorative.",
	"pet_rock": "His name is Gerald. Be good to him.",
	"nuke": "Don't tell me what it's for. I don't want to know.",
	"ram": "Installed. I blew on the contacts for you.",
}
const GENERIC := ["Pleasure doing business.", "No refunds!", "Tell your friends. Or don't.", "Enjoy. Responsibly."]

var selected := ""
var grid: GridContainer
var desc: Label
var keeper: Label
var wallet: Label
var buy_btn: Button


func _init() -> void:
	super("Gambit Goods & Gas", 660.0)
	keeper = add_text("\"Cash only. No questions about the rifle.\"", 16, UI.DIM)
	keeper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wallet = add_text("", 20, UI.GOLD)
	wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	desc = add_text("Tap something to take a closer look.", 17, UI.DIM)
	desc.custom_minimum_size = Vector2(0, 66)
	var row := HBoxContainer.new()
	body.add_child(row)
	buy_btn = UI.button("Buy", _on_buy)
	buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_btn.disabled = true
	row.add_child(buy_btn)
	var close_btn := UI.button("Leave", close)
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(close_btn)
	for entry in Game.SHOP:
		var id: String = entry[0]
		var price: int = entry[1]
		var b := Button.new()
		b.custom_minimum_size = Vector2(TILE, TILE * 0.92)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s - $%d" % [Game.item_name(id), price]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.draw.connect(_draw_tile.bind(b, id, price))
		b.pressed.connect(_select.bind(id))
		b.set_meta("id", id)
		grid.add_child(b)
	Game.money_changed.connect(_refresh)
	Game.inventory_changed.connect(_refresh)
	resized.connect(_columns)
	_refresh()


func _exit_tree() -> void:
	if Game.money_changed.is_connected(_refresh):
		Game.money_changed.disconnect(_refresh)
	if Game.inventory_changed.is_connected(_refresh):
		Game.inventory_changed.disconnect(_refresh)


func _columns() -> void:
	var w := minf(max_width, size.x - 24.0) - 28.0
	grid.columns = clampi(int((w + 6.0) / (TILE + 6.0)), 3, 6)


func _price(id: String) -> int:
	for entry in Game.SHOP:
		if entry[0] == id:
			return int(entry[1])
	return 0


## The nuke stays behind the counter until you're losing badly.
func _locked(id: String) -> bool:
	return id == "nuke" and not Game.losing_badly()


func _sold_out(id: String) -> bool:
	return bool(Game.ITEMS[id].get("unique", false)) and Game.has_item(id)


func _refresh() -> void:
	if Game.vs_ai:
		wallet.text = "Wallet: $%d" % Game.money
	else:
		wallet.text = "%s's wallet: $%d" % [Game.color_name(Game.active_side), Game.money]
	for b in grid.get_children():
		b.queue_redraw()
	_update_buy()


func _update_buy() -> void:
	if selected == "":
		buy_btn.disabled = true
		buy_btn.text = "Buy"
		return
	var price := _price(selected)
	if _sold_out(selected):
		buy_btn.disabled = true
		buy_btn.text = "Already owned"
	elif _locked(selected):
		buy_btn.disabled = true
		buy_btn.text = "You're not desperate enough"
	elif Game.money < price:
		buy_btn.disabled = true
		buy_btn.text = "Need $%d" % price
	else:
		buy_btn.disabled = false
		buy_btn.text = "Buy for $%d" % price


func _select(id: String) -> void:
	selected = id
	var owned := Game.count(id)
	var extra := "  (you have %d)" % owned if owned > 0 else ""
	desc.text = "%s - $%d%s\n%s" % [Game.item_name(id), _price(id), extra, Game.item_desc(id)]
	if _locked(id):
		var down := Game.material_deficit()
		desc.text += "\n\"That one's behind the counter. Come back when you're down %d points. You're down %d.\"" % [Game.NUKE_GAP, down] if down > 0 else "\n\"That one's behind the counter. You're doing fine. Come back when it's hopeless.\""
	desc.add_theme_color_override("font_color", UI.TEXT)
	for b in grid.get_children():
		b.queue_redraw()
	_update_buy()


func _on_buy() -> void:
	if selected == "" or _sold_out(selected) or _locked(selected):
		return
	var id := selected
	if not Game.spend(_price(id)):
		return
	var note := ""
	if id == "ram":
		Game.ram_sticks += 1
		note = "Installed. Out-of-memory warnings now %d%%." % roundi(Game.oom_chance() * 100.0)
		keeper.text = "\"%s\"" % QUIPS["ram"]
	elif id == "booster":
		var cards: Array = CardData.booster()
		Game.add_cards(cards)
		var names: Array = []
		for c in cards:
			names.append(CardData.card_name(c))
		note = "Inside: " + ", ".join(names) + "!"
		keeper.text = "\"%s\"" % note
	else:
		Game.add_item(id)
		if id == "beyblade" and Music.broken:
			Music.repair()
			note = "Your volume control is whole again."
		keeper.text = "\"%s\"" % QUIPS.get(id, GENERIC[randi() % GENERIC.size()])
	keeper.add_theme_color_override("font_color", UI.GOLD)
	bought.emit(id, note)
	_select(id)


func _draw_tile(b: Button, id: String, price: int) -> void:
	var s := b.size
	if id == selected:
		b.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), Color(0.88, 0.67, 0.29, 0.22))
		b.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), UI.GOLD, false, 2.5)
	var side := minf(s.x, s.y) * 0.56
	var ir := Rect2(Vector2((s.x - side) * 0.5, 6), Vector2(side, side))
	ItemArt.draw_icon(b, id, ir)
	var font := ThemeDB.fallback_font
	var afford := Game.money >= price
	var txt := "SOLD" if _sold_out(id) else "$%d" % price
	var col := UI.GOLD if afford else Color(0.55, 0.4, 0.35)
	if _locked(id):
		txt = "LOCKED"
		col = UI.DIM
		b.draw_rect(Rect2(ir.position, ir.size), Color(0.05, 0.04, 0.05, 0.55))
	if _sold_out(id):
		col = UI.DIM
	b.draw_string(font, Vector2(0, s.y - 9), txt, HORIZONTAL_ALIGNMENT_CENTER, s.x, 17, col)
	var n := Game.count(id)
	if n > 0:
		b.draw_string(font, Vector2(6, 18), "x%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.DIM)
