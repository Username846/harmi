class_name Help
extends RefCounted

const TEXT := """[color=#e0aa4a][b]The Board[/b][/color]
Standard chess, but every piece is a long, strange figure. Tap (or click) one of your pieces to open its [b]action menu[/b]:
 • [b]Move[/b] – highlights where it can go. Tap a gold dot to move, or a red square to capture.
 • [b]Inspect[/b] – learn how it moves, its fighting stats and, for enemies, what lies inside them.
 • [b]Use Item[/b] – apply a board item (Whetstone, Ward Charm) to strengthen that piece's next fight.

[color=#e0aa4a][b]Capturing[/b][/color]
When you capture, the board falls away and you enter the captured piece:
 • [b]Labyrinths[/b] (pawns, rooks, bishops) – a picture-in-a-box adventure. Choose a command (OPEN, INSPECT, PUNCH, USE, GO) and then tap something in the picture. To use an item, pick USE, tap the item in your satchel, then tap the target. Tap the doorways and arrows to travel through the short labyrinth. Find the piece's heart and destroy it.
 • [b]Duels[/b] (knights, the queen, some pawns) – turn-based fights with health and mana bars. Strike, use skills, guard, and drink potions.
Finish the encounter and you return to the board, where the captured piece crumbles into ash. Each fallen piece leaves you a Pinch of Ash, which can blind a foe in a duel.
Stuck? Every labyrinth has a [b]Hint[/b] button, and you can always [b]Retreat[/b] to take your move back.

[color=#e0aa4a][b]Winning[/b][/color]
Checkmate the enemy king, then defeat it in a final duel."""


static func show(parent: Node) -> Modal:
	var m := Modal.new("How to Play", 640.0)
	var r := UI.rich(18)
	r.scroll_following = false
	r.fit_content = false
	r.custom_minimum_size = Vector2(0, 380)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.text = TEXT
	m.add(r)
	m.add_buttons([["Got it", m.close]])
	parent.add_child(m)
	return m
