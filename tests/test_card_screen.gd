extends Node
## Smoke test for CardDuelScreen: plays whole duels through the screen's own
## handlers (summon / cast / attack / end turn) at high speed, with decks full
## of booster cards so every animation path runs, then presses the end Modal's
## button and checks that `finished` arrives. Watch the output for SCRIPT ERRORs.
## Run: godot --headless --path . res://tests/card_screen.tscn

const DUELS := 9
## Log phrases of the rarer effects; each should show up at least once.
const SEEN := {"Pink slip": 0, "discards": 0, "promoted": 0, "one more time": 0, "Swords of light": 0,
	"heart of the cards": 0, "Drive-By": 0, "Sniper Shot": 0, "Beyblade": 0, "Elongated Dragon": 0}

var failures := 0
var seen := SEEN.duplicate()


func _ready() -> void:
	Engine.time_scale = 25.0
	_run.call_deferred()


func _run() -> void:
	for i in DUELS:
		var deck: Array = CardData.base_deck()
		for id in CardData.BOOSTER_POOL:
			deck.append(id)
			deck.append(id)
		var res := await _duel(deck, i % 3, 100 + i)
		print("duel %d (difficulty %d): %s" % [i, i % 3, res])
		if res != "won" and res != "lost":
			failures += 1
	# shadow games ("for reals"): 12,000 LP, a forced hard Yugi and the doom endings
	var reals_results: Array = []
	for i in 3:
		var deck2: Array = CardData.base_deck()
		for id in CardData.BOOSTER_POOL:
			deck2.append(id)
		var res2 := await _duel(deck2, 0, 300 + i, true)
		reals_results.append(res2)
		print("for-reals duel %d: %s" % [i, res2])
		if res2 != "won" and res2 != "lost":
			failures += 1
	var ff := await _duel(CardData.base_deck(), 1, 77, true, true)
	print("for-reals forfeit: %s" % ff)
	if ff != "lost":
		failures += 1
		print("  FAIL: a for-reals forfeit should be a loss")
	print("effects seen: ", seen)
	for k in seen:
		if int(seen[k]) == 0:
			failures += 1
			print("  FAIL: never saw ", k)
	print("CARD SCREEN TESTS ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _duel(deck: Array, diff: int, seed_value: int, reals: bool = false, forfeit: bool = false) -> String:
	var screen := CardDuelScreen.new()
	screen.setup({"player_color": seed_value % 2, "wager_type": 1 + seed_value % 5, "difficulty": diff, "for_reals": reals})
	screen.game = CardGame.new(deck, CardData.yugi_deck(diff), seed_value, diff)
	var result := [""]
	screen.finished.connect(func(r: String): result[0] = r)
	get_tree().root.add_child(screen)
	if reals:
		if screen.game.start_lp != CardGame.REALS_LP or screen.game.difficulty != 2 or int(screen.game.lp[0]) != CardGame.REALS_LP:
			failures += 1
			print("  FAIL: for_reals did not set up a 12,000 LP hard duel")
	var guard := 0
	while result[0] == "" and guard < 20000:
		guard += 1
		await get_tree().process_frame
		if screen.over:
			_press_modal(screen)
			continue
		if screen.busy:
			continue
		if forfeit:
			screen._on_forfeit()
			await get_tree().process_frame
			_press_modal(screen)
			forfeit = false
			continue
		var g := screen.game
		if g.current != CardGame.PLAYER:
			continue
		var act := g.ai_action(CardGame.PLAYER)
		match String(act["type"]):
			"summon":
				screen._do_summon(int(act["hand"]), int(act["zone"]))
			"cast":
				screen._do_cast(int(act["hand"]), int(act["tside"]), int(act["tzone"]))
			"attack":
				screen._do_attack(int(act["zone"]), int(act["target"]))
			_:
				screen._on_end_turn()
	var text := screen.log_box.get_parsed_text()
	for k in seen:
		seen[k] = int(seen[k]) + text.count(k)
	screen.queue_free()
	await get_tree().process_frame
	return result[0] if result[0] != "" else "timeout"


func _press_modal(screen: Control) -> void:
	for c in screen.get_children():
		if c is Modal:
			var buttons := c.find_children("*", "Button", true, false)
			if not buttons.is_empty():
				(buttons[0] as Button).pressed.emit()
			return
