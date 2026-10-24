class_name Help
extends RefCounted

const TEXT := """[color=#e0aa4a][b]The Board[/b][/color]
Standard chess, but every piece is a long, strange figure. Tap (or click) one of your pieces to open its [b]action menu[/b]:
 • [b]Move[/b] – highlights where it can go. Tap a gold dot to move, or a red square to capture.
 • [b]Odd Jobs[/b] – send the piece off to earn money. An odd job brings it back next turn; a [b]really odd job[/b] keeps it away for two turns, pays more, and things happen. Uses your turn.
 • [b]Pink Slip Race[/b] – challenge an enemy piece to a drag race. The loser signs over its car and can't move until it gets another. Uses your turn.
 • [b]Date[/b] – take the piece out to lift its mood. You can even ask enemy pieces out. Uses your turn.
 • [b]Use Item[/b] – Whetstone and Ward Charm strengthen its next fight; Roses cheer it up; a Used Car gets it moving again; a Sniper Rifle takes a shot.
 • [b]Inspect[/b] – how it moves, its mood, its car, and what lies inside enemies.

[color=#e0aa4a][b]Money and the Shop[/b][/color]
Odd jobs, captures and pink slips earn money. The [b]Shop[/b] sells goods, some actually useful: the [b]Double Move Upgrade[/b] (move twice in one turn), the [b]Sniper Rifle[/b] (one shot, no labyrinth), the [b]Drive-By Hotline[/b] (the pieces from the board next door roll up and take out enemies along one edge), Used Cars, Nitrous for races, Roses, a Headlamp, card Booster Packs, Spare Beyblades... and a gourd. Turn items like the Double Move and the Drive-By are used from the [b]Inventory[/b] button on your turn.

[color=#e0aa4a][b]Moods[/b][/color]
Every piece has a mood. It sinks whenever a piece sees its comrades turn to ash or lose their cars, especially nearby. Gloomy pieces fight worse in duels, earn less, race worse, and get rain clouds. The darker an enemy's mood, the [b]darker its labyrinth[/b] when you capture it: your light follows your pointer or your last tap. Dates and roses restore moods.

[color=#e0aa4a][b]Affection and Babies[/b][/color]
Every piece also has an [b]affection meter[/b] (see Inspect). Dates fill it, and so does watching a friend nearby capture an enemy: the onlooker gets a crush on the hero. When the meter is full a heart floats over the piece, and at the start of your turn it may have a [b]baby piece[/b] with its crush on a free square beside them.

[color=#e0aa4a][b]Capturing[/b][/color]
When you capture, the board falls away and you enter the captured piece:
 • [b]Labyrinths[/b] (pawns, rooks, bishops) – a picture-in-a-box adventure. Choose a command (OPEN, INSPECT, PUNCH, USE, GO) and then tap something in the picture. To use an item, pick USE, tap the item in your satchel, then tap the target. Find the piece's heart and destroy it.
 • [b]Duels[/b] (knights, the queen, some pawns) – turn-based fights with health and mana bars. Strike, use skills, guard, and drink potions.
 • [b]Team battles[/b] – sometimes the pieces standing next to the two fighters pile in. Each of your pieces acts in turn; tap an enemy to target it. Knock out the whole enemy party to win.
Finish the encounter and the captured piece crumbles into ash. Stuck? Every labyrinth has a [b]Hint[/b] button, and you can always [b]Retreat[/b] to take your move back.

[color=#e0aa4a][b]The Graveyard[/b][/color]
Fallen pieces go to the graveyard. Visit it and duel [b]Yugi Moto[/b] in a children's card game: win, and the piece of your choice returns to the board. The duel uses your turn.
Or duel him [b]For Reals[/b]: a shadow game with 12,000 life points each. Lose, and you are sent to the [b]Shadow Realm[/b] – game over. Win, and Yugi is sent there instead. The graveyard falls into disarray and despair, sinking every piece's mood, until you repair all six sections with money and items. Repair the last one and you become the new [b]Gravekeeper[/b], able to raise a fallen piece for free every few turns.

[color=#e0aa4a][b]Music[/b][/color]
The volume control is a [b]Beyblade[/b]. Tap it and pull the rip cord: the harder you pull, the louder the bassline and the longer it spins before dying down. Pull too hard and it snaps off and crashes into the board, knocking pieces onto other squares or flat on their backs (a knocked-over piece loses its next turn).

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
