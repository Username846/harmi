# Ashen Gambit

Chess with long, strange, **elongated pieces**, made in **Godot 4.7.2** for the browser.
It plays with a mouse on PC and with touch on phones and tablets.

Every time you capture, the board falls away and you enter the captured piece.

* **Labyrinths** (pawns, rooks, bishops) are *picture-in-a-box* adventures in the style of the old
  MacVenture games. Pick a command (**OPEN · INSPECT · PUNCH · USE · GO**), then tap something in the
  framed picture. Explore the piece's short labyrinth, find its heart and destroy it.
* **Duels** (knights, the queen, some pawns, and the king after checkmate) are turn-based fights
  with **health and mana bars**, skills, guarding and items.

Finish the encounter and you return to the board, where the captured piece **crumbles into ash**.

Off the board, your pieces have lives of their own:

* **Odd Jobs and Really Odd Jobs** earn money, and the **Shop** sells useful goods (a Double Move
  Upgrade, a Sniper Rifle, a Drive-By Hotline for the pieces on the chessboard next door, used cars,
  nitrous...) and some less useful ones (a decorative gourd). When you're losing badly, the shopkeeper
  will sell you a **Suitcase Nuke** from behind the counter.
* **Pink Slip Races**: challenge an enemy piece to a drag race. The loser loses its car and can't move.
* **Moods**: pieces get gloomy watching comrades lose their cars or turn to ash. Gloomy pieces fight
  worse, and the gloomier an enemy, the **darker its labyrinth**. Take pieces on **dates** to cheer them up.
* **Queen Cushy**: whenever a queen captures a piece, by any means, a cutscene shows her twerking on
  its grave to her own song. On dates she's all curves and attitude, straight out of "Back Rank Bounce".
* **Affection and babies**: dates fill a piece's affection meter, and so does watching a friend
  nearby capture an enemy (it gets a crush on the hero). A piece with a full heart may have a **baby
  piece** with its crush on a square beside them.
* **Team battles**: sometimes the pieces standing next to the fighters pile in, and the duel becomes a
  party battle, up to 4 against 4.
* **The Graveyard**: fallen pieces rest here. Beat **Yugi Moto** in a children's card game to bring one back,
  or duel him **For Reals**: 12,000 life points, and the loser goes to the Shadow Realm. Banish Yugi
  and the graveyard falls into ruin and despair; repair it section by section and become the new
  **Gravekeeper**, who can raise the fallen for free.
* **Title album**: three five-minute songs, each with its own synthesized vocalist and no line ever
  repeated: "Long Boy Diss" (MC Long Boy, boom-bap), "Coronation of the Long Boys" (Sir Ivory, orchestral,
  with brass in the second half) and "Back Rank Bounce" (Queen Cushy, dembow bounce). The line being sung
  shows across the top of the title screen with the next one faded beneath it. Tap the strip to mute,
  tap NEXT to skip.
* **Duel themes**: graveyard card duels have their own five-minute songs, with the lyrics along the top.
  Ordinary duels get "It's Time to Duel in the Graveyard", sung by a child, Little Pip. Duels For Reals
  get "Shadow Carnival", dark-carnival horrorcore from Yugi himself (and his darker half, Yami) about
  how completely screwed you are for challenging him to a children's card game.
* **Music**: the volume control is a **Beyblade**. Pull its rip cord harder and the bassline (a top
  bouncing down an oak staircase) plays louder and longer. Pull too hard and it snaps off and crashes
  into the board, knocking pieces around and over.

## Play it from GitHub (GitHub Pages)

The repository already contains a ready-to-serve web build in [`docs/`](docs/), so the game can be
hosted straight from GitHub with no build step. Choose one of these:

**Option A – serve the committed build (quickest)**
1. Open the repository on GitHub, then **Settings → Pages**.
2. Under *Build and deployment*, set **Source: Deploy from a branch**.
3. Pick the branch that contains this code and the **`/docs`** folder, then **Save**.
4. After a minute the game is live at `https://<your-user>.github.io/<repo>/`
   (for this repository: `https://username846.github.io/harmi/`).

**Option B – build automatically with GitHub Actions**
1. **Settings → Pages → Source: GitHub Actions**.
2. Every push to the default branch runs [`.github/workflows/pages.yml`](.github/workflows/pages.yml).
   It downloads Godot 4.7.2 and its web export templates, runs the tests, exports the game and deploys it.

The web export is **single-threaded**, so it runs on plain GitHub Pages without any special
cross-origin isolation headers or service-worker tricks.

## How to play

| | |
|---|---|
| **Select a piece** | Tap or click it. Its **action menu** opens: *Move*, *Odd Jobs*, *Pink Slip Race*, *Date*, *Use Item*, *Inspect*, *Cancel*. Enemy pieces can be inspected or asked on a date. |
| **Move** | Gold dots are moves; red squares are captures. Tap one. Tap elsewhere to cancel. |
| **Odd Jobs** | An odd job keeps the piece away for your next turn and pays a little. A really odd job keeps it away for two turns, pays more, and things happen. Uses your turn. |
| **Pink Slip Race** | Pick an enemy piece (pink squares), then win the drag race: launch on green, shift in the green band, hit NOS if you have it. The loser can't move without a car. Uses your turn. |
| **Date** | Choose a venue and say the right things. Restores the piece's mood and fills its affection meter. Uses your turn. |
| **Use Item** | Whetstone (+4 attack next fight), Ward Charm (+25 health next fight), Roses (+mood), Used Car (moves again), Sniper Rifle (shoot an enemy in a clear straight line; uses your turn). |
| **Inventory** | Everything you carry. On your turn, use the Double Move Upgrade and the Drive-By Hotline from here. Labyrinth items vanish when you leave that labyrinth. |
| **Shop** | Spend the money from odd jobs, captures and pink slips. |
| **Graveyard** | Choose a fallen piece and duel Yugi Moto for it, normally or For Reals. Uses your turn. Once Yugi is gone, spend money and items on repairs; the Gravekeeper raises one piece free every few turns. |
| **Beyblade** | The volume control (top right). Drag the rip cord out and let go. Too hard, and it crashes into the board. Knocked-over pieces lose their next turn. |
| **Labyrinths** | Choose a command, then tap the picture. To use an item: tap **USE**, tap the item in your satchel, then tap the target (or another item to combine them). Tap doorways and arrows to travel; the minimap shows where you've been. **Hint** helps when you're stuck. In a gloomy piece's labyrinth your light follows the pointer or your last tap. |
| **Duels** | *Strike*, *Skills* (cost mana), *Guard* (halves the next hit and restores mana), *Items* (Health Draught, Mana Tincture, Pinch of Ash to blind the foe). If you lose you can try again with your items restored. In a team battle each of your pieces acts in turn: tap an enemy (or its button) to target it. |
| **Retreat** | Available in every labyrinth and ordinary duel. It calls the capture off and you choose another move. |
| **Winning** | Checkmate the enemy king, then defeat it in a final duel. |

Modes: **vs Computer** (Easy / Normal / Hard) or **Two Players** on the same device (each side has its own wallet, satchel and card deck).
The board uses standard chess rules: castling, en passant, promotion, check, checkmate, stalemate,
the fifty-move rule, threefold repetition and insufficient material. Off-board actions (jobs, races,
dates, shots, card duels) use up your turn instead of a move; you can't take them while in check.

## The children's card game

In the graveyard, Yugi Moto duels you for one fallen piece. Both sides start with 4000 life points and
three monster zones. Each turn you may summon one monster and cast one spell, then attack: the higher
ATK destroys the lower and the difference comes off its owner's life points; with an empty field you
attack directly. Your deck is your chess pieces (Pawns 600 up to the Queen 2500) plus spells like
Promotion, Checkmate, En Passant and the Fifty-Move Rule. Booster packs from the shop add the Elongated
Dragon, Beyblade, Drive-By, Sniper Shot, Double Move, Pink Slip and Zugzwang. Watch out when Yugi is
low on life: he believes in the heart of the cards.

**For Reals** is a shadow game: 12,000 life points each and no mercy. Lose and you are sent to the
Shadow Realm, and the game is over. Win and Yugi is swallowed instead. With no one left to tend it, the
graveyard falls into disarray and its despair darkens every piece's mood until you repair all six
sections (gate, stones, flowers, crypt, lanterns, shed) and are crowned the new Gravekeeper.

## The labyrinths

| Piece | Labyrinths |
|---|---|
| Pawn | *The Trench*, *The Drowned Well*, *The Barracks* (some pawns duel instead) |
| Rook | *The Bell Tower*, *The Undercroft* |
| Bishop | *The Ashen Chapel*, *The Scriptorium* |
| Knight, Queen | Duels |
| King | Final duel after checkmate |

Codes, lever sequences, lamp orders and bell counts are randomized on every visit.

## Project layout

```
project.godot            Godot 4.7.2 project (GL Compatibility renderer, 600x600 base, expand stretch)
export_presets.cfg       "Web" preset (no threads) exporting to docs/index.html
scenes/main.tscn         Entry scene
scripts/
  main.gd                Scene manager: title -> board <-> encounters, transitions
  game.gd                Autoload: per-side satchels and wallets, item and shop database, piece moods, graveyard
  audio/music.gd         Autoload: the Beyblade-powered music
  chess/                 Rules, AI, elongated piece art, board view and effects, board screen
  life/                  Odd jobs
  adventure/             Picture-in-a-box engine, room & object art, labs/ (one script per labyrinth)
  battle/                Duel stats, arena drawing, duel screen
  race/                  Pink slip drag race
  date/                  Dates
  cards/                 Yugi Moto's children's card game
  nuke/                  the Suitcase Nuke's explosion
  survival/              (spoiler) surviving in the ruins
  title/, ui/            Title screen, theme, modals, inventory, shop, graveyard, Beyblade widget, item icons, help
assets/audio/            The bassline, sound effects (tools/gen_audio.py) , the title album and duel themes (tools/gen_songs.py)
tests/                   Headless tests (perft, labyrinths, board actions, AI timing, minigames)
docs/                    Exported web build served by GitHub Pages
```

All art is drawn procedurally in code. The music is synthesized by `tools/gen_audio.py` (Python + numpy).

### The Suitcase Nuke

The shop keeps a Suitcase Nuke ($30) behind the counter. It's only sold to a side that is down 10 or
more points of material (pawn 1, knight and bishop 3, rook 5, queen 9). Use it from the Inventory on your
turn: it's slid under the enemy king, the square splits open, the bomb beeps three times, and a
full-screen animation shows the town being destroyed. The town is named after the player's time-zone city
(`America/Chicago` -> Chicago), read from the browser without asking for location; it falls back to
"Ashenford". The chess game is then over for good and the survival game begins in the ruins: scavenge
for food and water, keep radiation down and signal the authorities until they find you. Testing
shortcuts: `?fen=rnbqkbnr/pppppppp/8/8/8/8/8/4K3_w_-_-&money=100` starts you losing badly,
`?nuke=1&town=Springfield` plays the explosion straight away, and `?screen=survival&town=Springfield`
jumps into the ruins (`&seed=N` fixes the dice, `&rescue=N` starts the rescue meter at N%).

## Development

Open the folder in **Godot 4.7.2** and press Play. Run the tests from a terminal:

```sh
godot --headless --path . --import                  # first time only
godot --headless --path . res://tests/check.tscn    # every script compiles
godot --headless --path . -s tests/test_chess.gd    # move generator perft suite
godot --headless --path . res://tests/labs.tscn     # solves every labyrinth start to finish
godot --headless --path . res://tests/board.tscn    # revivals, drive-by, sniper, knock-overs, moods, hand-backs
godot --headless --path . -s tests/test_race.gd     # drag race balance (about a minute)
godot --headless --path . res://tests/race_smoke.tscn
godot --headless --path . -s tests/test_date.gd     # date dialogue data
godot --headless --path . res://tests/date_flow.tscn
godot --headless --path . -s tests/test_cards.gd    # card rules and Yugi's win rates
godot --headless --path . res://tests/card_screen.tscn
godot --headless --path . res://tests/grave_restore.tscn # For Reals confirm, repairs, gravekeeper raises
godot --headless --path . res://tests/team_battle.tscn   # party battles played to the end
godot --headless --path . -s tests/test_survival.gd # survival balance across bots and difficulties
godot --headless --path . res://tests/survival_flow.tscn
godot --headless --path . -s tests/test_ai.gd       # AI timing per difficulty
python3 tools/gen_audio.py                          # re-render the music and sound effects
python3 tools/gen_songs.py                          # re-render the title album and duel themes (needs flite + ffmpeg)
```

To rebuild the web version into `docs/` (requires the 4.7.2 web export templates):

```sh
godot --headless --path . --export-release "Web" docs/index.html
```

Testing shortcuts for the web build (append to the URL):
`?lab=trench` (also `well`, `barracks`, `tower`, `undercroft`, `chapel`, `scriptorium`, optionally `&room=<id>`),
`?fight=5` (foe piece type 1–6, optionally `&hero=2`, and `&party=3,1&foes=1,1` for a team battle), `&fmood=10` (the foe's mood, for gloomy labyrinths and duels),
`?screen=race` (also `date`, `cards` (`&reals=1` for For Reals), `shadow`, `twerk`, with `&hero=2&foe=4&hmood=72&fmood=30&own=1`),
`?fen=<FEN with _ for spaces>` to start from a position, `&money=200&items=sniper,driveby` to start rich,
and `&grave=2,4` to start with a knight and a rook in your graveyard.
