class_name OddJobs
extends RefCounted
## Odd jobs and really odd jobs: what pieces do for money when they leave the board.

const ODD := [
	"mow the neighbour's lawn in neat little L-shapes",
	"walk six extremely small dogs",
	"assemble a flat-pack bookcase with one missing screw",
	"deliver pizzas, strictly diagonally",
	"babysit the h-pawn's cousins",
	"repaint every white square (one coat)",
	"hold a ladder for a rook",
	"bag groceries at the corner shop",
	"wash cars at a charity car wash",
	"rake leaves off the a-file",
	"stuff envelopes for the chess club newsletter",
	"tutor a checkers piece in basic geometry",
]

const REALLY_ODD := [
	"pose as a garden gnome for a week",
	"stand in for a lamp at a dinner party",
	"taste-test ash for an artisanal crematorium bakery",
	"work as a stunt double for a bishop",
	"count every grain of sand in an hourglass",
	"wear a sandwich board reading THE END IS NIGH (IN 3 MOVES)",
	"be the 'before' photo in a posture advert",
	"sit very still in a museum labelled 'Modern Grief, No. 4'",
	"play the villain at a children's Beyblade party",
	"hand out flyers inside somebody else's labyrinth",
	"audition for a rival game of checkers in disguise",
	"guard a door that leads nowhere, overnight",
]

const BASE_PAY := [0, 7, 9, 9, 10, 13, 15]


static func pick(really: bool) -> String:
	var pool: Array = REALLY_ODD if really else ODD
	return pool[randi() % pool.size()]


## Expected range shown before sending a piece off.
static func estimate(t: int, mood: float, really: bool) -> Vector2i:
	var base := float(BASE_PAY[t]) * (0.6 + mood / 125.0) * (2.6 if really else 1.0)
	return Vector2i(int(round(base * 0.8)), int(round(base * 1.25)))


## What happens when a piece comes back. Returns {"pay", "mood", "item", "text"}.
static func outcome(t: int, mood: float, really: bool) -> Dictionary:
	var pay := int(round(float(BASE_PAY[t]) * (0.6 + mood / 125.0) * randf_range(0.8, 1.25) * (2.6 if really else 1.0)))
	var r := randf()
	if not really:
		if r < 0.2:
			return {"pay": pay, "mood": 5.0, "item": "", "text": "and actually enjoyed it"}
		if r < 0.3:
			return {"pay": pay, "mood": -4.0, "item": "", "text": "and would rather not talk about it"}
		return {"pay": pay, "mood": 0.0, "item": "", "text": ""}
	if r < 0.2:
		return {"pay": int(pay * 1.3), "mood": 8.0, "item": "", "text": "and got a generous tip"}
	if r < 0.35:
		var gifts := ["gourd", "spoon", "pet_rock", "roses", "nitrous", "potion"]
		var g: String = gifts[randi() % gifts.size()]
		return {"pay": pay, "mood": 2.0, "item": g, "text": "and was paid partly in %s" % Game.item_name(g)}
	if r < 0.45:
		return {"pay": int(pay * 1.5), "mood": -18.0, "item": "", "text": "and got hazard pay, plus a thousand-yard stare"}
	if r < 0.55:
		return {"pay": 0, "mood": -10.0, "item": "", "text": "but was paid entirely in 'exposure'"}
	return {"pay": pay, "mood": -5.0, "item": "", "text": "and is a little stranger now"}
