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
| **Select a piece** | Tap or click it. Its **action menu** opens: *Move*, *Inspect*, *Use Item*, *Cancel*. |
| **Move** | Gold dots are moves; red squares are captures. Tap one. Tap elsewhere to cancel. |
| **Inspect** | Shows how the piece moves, its duel stats, any blessings and, for enemies, what waits inside it. |
| **Use Item** | Board items bless one of your pieces for its next duel (Whetstone: +4 attack, Ward Charm: +25 health). |
| **Inventory** | Everything you carry. Labyrinth items vanish when you leave that labyrinth; potions, charms and ash stay. |
| **Labyrinths** | Choose a command, then tap the picture. To use an item: tap **USE**, tap the item in your satchel, then tap the target (or another item to combine them). Tap doorways and arrows to travel; the minimap shows where you've been. **Hint** helps when you're stuck. |
| **Duels** | *Strike*, *Skills* (cost mana), *Guard* (halves the next hit and restores mana), *Items* (Health Draught, Mana Tincture, Pinch of Ash to blind the foe). If you lose you can try again with your items restored. |
| **Retreat** | Available in every labyrinth and ordinary duel. It calls the capture off and you choose another move. |
| **Winning** | Checkmate the enemy king, then defeat it in a final duel. |

Modes: **vs Computer** (Easy / Normal / Hard) or **Two Players** on the same device.
The board uses standard chess rules: castling, en passant, promotion, check, checkmate, stalemate,
the fifty-move rule, threefold repetition and insufficient material.

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
  game.gd                Autoload: inventory, item database, encounter assignment
  chess/                 Rules (chess_rules.gd), AI, elongated piece art, board view, ash effect, board screen
  adventure/             Picture-in-a-box engine, room & object art, labs/ (one script per labyrinth)
  battle/                Duel stats, arena drawing, duel screen
  title/, ui/            Title screen, theme, modals, inventory, item icons, help
tests/                   Headless tests (perft, labyrinth walkthroughs, AI timing)
docs/                    Exported web build served by GitHub Pages
```

All art is drawn procedurally in code; the project has no image or audio assets.

## Development

Open the folder in **Godot 4.7.2** and press Play. Run the tests from a terminal:

```sh
godot --headless --path . --import                  # first time only
godot --headless --path . -s tests/test_chess.gd    # move generator perft suite
godot --headless --path . res://tests/labs.tscn     # solves every labyrinth start to finish
godot --headless --path . -s tests/test_ai.gd       # AI timing per difficulty
```

To rebuild the web version into `docs/` (requires the 4.7.2 web export templates):

```sh
godot --headless --path . --export-release "Web" docs/index.html
```

Testing shortcuts for the web build (append to the URL):
`?lab=trench` (also `well`, `barracks`, `tower`, `undercroft`, `chapel`, `scriptorium`, optionally `&room=<id>`),
`?fight=5` (foe piece type 1–6, optionally `&hero=2`), and `?fen=<FEN with _ for spaces>` to start from a position.
