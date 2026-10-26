class_name ChessAI
extends RefCounted
## Small alpha-beta searcher with piece-square tables and a quiescence search.

const VALUES := [0, 100, 320, 330, 500, 900, 0]
const MATE := 100000

# Piece-square tables from White's point of view, index = rank * 8 + file.
const PST_PAWN := [
	0, 0, 0, 0, 0, 0, 0, 0,
	5, 10, 10, -20, -20, 10, 10, 5,
	5, -5, -10, 0, 0, -10, -5, 5,
	0, 0, 0, 20, 20, 0, 0, 0,
	5, 5, 10, 25, 25, 10, 5, 5,
	10, 10, 20, 30, 30, 20, 10, 10,
	50, 50, 50, 50, 50, 50, 50, 50,
	0, 0, 0, 0, 0, 0, 0, 0]
const PST_KNIGHT := [
	-50, -40, -30, -30, -30, -30, -40, -50,
	-40, -20, 0, 5, 5, 0, -20, -40,
	-30, 5, 10, 15, 15, 10, 5, -30,
	-30, 0, 15, 20, 20, 15, 0, -30,
	-30, 5, 15, 20, 20, 15, 5, -30,
	-30, 0, 10, 15, 15, 10, 0, -30,
	-40, -20, 0, 0, 0, 0, -20, -40,
	-50, -40, -30, -30, -30, -30, -40, -50]
const PST_BISHOP := [
	-20, -10, -10, -10, -10, -10, -10, -20,
	-10, 5, 0, 0, 0, 0, 5, -10,
	-10, 10, 10, 10, 10, 10, 10, -10,
	-10, 0, 10, 10, 10, 10, 0, -10,
	-10, 5, 5, 10, 10, 5, 5, -10,
	-10, 0, 5, 10, 10, 5, 0, -10,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-20, -10, -10, -10, -10, -10, -10, -20]
const PST_ROOK := [
	0, 0, 0, 5, 5, 0, 0, 0,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	5, 10, 10, 10, 10, 10, 10, 5,
	0, 0, 0, 0, 0, 0, 0, 0]
const PST_QUEEN := [
	-20, -10, -10, -5, -5, -10, -10, -20,
	-10, 0, 5, 0, 0, 0, 0, -10,
	-10, 5, 5, 5, 5, 5, 0, -10,
	0, 0, 5, 5, 5, 5, 0, -5,
	-5, 0, 5, 5, 5, 5, 0, -5,
	-10, 0, 5, 5, 5, 5, 0, -10,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-20, -10, -10, -5, -5, -10, -10, -20]
const PST_KING := [
	20, 30, 10, 0, 0, 10, 30, 20,
	20, 20, 0, 0, 0, 0, 20, 20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30]

var nodes := 0
var deadline := 0
var aborted := false


static func pst(t: int, idx: int) -> int:
	match t:
		1: return PST_PAWN[idx]
		2: return PST_KNIGHT[idx]
		3: return PST_BISHOP[idx]
		4: return PST_ROOK[idx]
		5: return PST_QUEEN[idx]
		6: return PST_KING[idx]
	return 0


## Static evaluation from the side to move's perspective.
static func evaluate(b: ChessRules) -> int:
	var score := 0
	var mat := [0, 0]
	var kings := [0, 0]
	for s in 64:
		var code := b.board[s]
		if code == 0:
			continue
		var t := code & 7
		if t == 6:
			kings[1 if (code & 8) else 0] = s
		if (code & 8) == 0:
			score += VALUES[t] + pst(t, s)
			mat[0] += VALUES[t]
		else:
			# mirror rank for black
			score -= VALUES[t] + pst(t, (7 - (s >> 3)) * 8 + (s & 7))
			mat[1] += VALUES[t]
	# mop-up: well ahead in an ending, herd the enemy king to the edge and walk yours over
	var lead: int = mat[0] - mat[1]
	if absi(lead) >= 400 and mini(mat[0], mat[1]) <= 1300:
		var w := 0 if lead > 0 else 1
		var lk: int = kings[1 - w]
		var wk: int = kings[w]
		var edge := maxi(3 - (lk & 7), (lk & 7) - 4) + maxi(3 - (lk >> 3), (lk >> 3) - 4)
		var near := 14 - (absi((lk & 7) - (wk & 7)) + absi((lk >> 3) - (wk >> 3)))
		var mop := edge * 12 + near * 5
		score += mop if w == 0 else -mop
	return score if b.side == ChessRules.WHITE else -score


static func _order(b: ChessRules, moves: Array) -> void:
	for m in moves:
		var v := 0
		var victim := b.board[m["to"]] & 7
		if victim != 0:
			v = 10 * VALUES[victim] - VALUES[b.board[m["from"]] & 7] + 10000
		elif m["flag"] == ChessRules.FLAG_EP:
			v = 10000 + 900
		if m["promo"] != 0:
			v += VALUES[m["promo"]] + 5000
		m["score"] = v
	moves.sort_custom(func(a, c): return a["score"] > c["score"])


func _quiesce(b: ChessRules, alpha: int, beta: int, qdepth: int) -> int:
	nodes += 1
	if aborted:
		return 0
	if (nodes & 127) == 0 and Time.get_ticks_msec() > deadline:
		aborted = true
		return 0
	var stand := evaluate(b)
	if stand >= beta:
		return beta
	if stand > alpha:
		alpha = stand
	if qdepth <= 0:
		return alpha
	var moves := b.gen_pseudo(true)
	_order(b, moves)
	var mover := b.side
	for m in moves:
		b.make_move(m)
		if b.in_check(mover):
			b.unmake_move()
			continue
		var sc := -_quiesce(b, -beta, -alpha, qdepth - 1)
		b.unmake_move()
		if sc >= beta:
			return beta
		if sc > alpha:
			alpha = sc
	return alpha


func _search(b: ChessRules, depth: int, alpha: int, beta: int, ply: int) -> int:
	if aborted:
		return 0
	nodes += 1
	if (nodes & 127) == 0 and Time.get_ticks_msec() > deadline:
		aborted = true
		return 0
	if depth <= 0:
		return _quiesce(b, alpha, beta, 4)
	var moves := b.gen_pseudo()
	_order(b, moves)
	var mover := b.side
	var legal := 0
	for m in moves:
		b.make_move(m)
		if b.in_check(mover):
			b.unmake_move()
			continue
		legal += 1
		var sc := -_search(b, depth - 1, -beta, -alpha, ply + 1)
		b.unmake_move()
		if sc >= beta:
			return beta
		if sc > alpha:
			alpha = sc
	if legal == 0:
		if b.in_check(mover):
			return -MATE + ply
		return 0
	return alpha


## Strength by difficulty, tuned with tools/ai_match.py (against Stockfish's
## 1320 floor and each level against the next):
##   depth: plies searched before the quiescence search (0 = look one move
##          ahead and judge the position as it stands, recaptures unseen)
##   noise: centipawns of slack: any move this close to the best may be played
##   blunder: chance of just playing a random legal move
##   budget: thinking time in ms
const LEVELS := [
	{"elo": 300, "depth": 0, "noise": 120, "blunder": 0.25, "budget": 300},
	{"elo": 700, "depth": 1, "noise": 25, "blunder": 0.06, "budget": 600},
	{"elo": 1200, "depth": 3, "noise": 15, "blunder": 0.05, "budget": 1500},
]


## Picks a move for the side to move. difficulty: 0 easy (~300 Elo), 1 normal
## (~700), 2 hard (~1200). Pieces on `banned` squares (no car, away on a job,
## knocked over) stay put, unless nothing else can move.
func choose_move(src: ChessRules, difficulty: int, banned: Dictionary = {}) -> Dictionary:
	var b := src.copy()
	var moves := b.legal_moves()
	if moves.is_empty():
		return {}
	if not banned.is_empty():
		var free := moves.filter(func(m): return not banned.has(m["from"]))
		if not free.is_empty():
			moves = free
	nodes = 0
	aborted = false
	var lv: Dictionary = LEVELS[clampi(difficulty, 0, LEVELS.size() - 1)]
	if randf() < float(lv["blunder"]):
		return moves[randi() % moves.size()]
	var max_depth: int = lv["depth"]
	var noise: int = lv["noise"]
	deadline = Time.get_ticks_msec() + int(lv["budget"])
	_order(b, moves)
	var best_scores := {}
	if max_depth == 0:
		# a beginner's glance: what's on the board right after my move?
		for i in moves.size():
			best_scores[i] = _glance(b, moves[i])
	for depth in range(1, max_depth + 1):
		var scores := {}
		var alpha := -MATE * 2
		var completed := true
		for i in moves.size():
			var m: Dictionary = moves[i]
			b.make_move(m)
			var sc := 0
			if b.legal_moves().is_empty():
				# mate, or a stalemate thrown away: the search below wouldn't notice either at depth 1
				sc = MATE if b.in_check(b.side) else 0
			else:
				sc = -_search(b, depth - 1, -MATE * 2, -alpha + noise + 1, 1)
			b.unmake_move()
			if aborted:
				completed = false
				break
			scores[i] = sc
			if sc > alpha:
				alpha = sc
		if not completed:
			break
		best_scores = scores
		# search best moves first next iteration
		var idx: Array = scores.keys()
		idx.sort_custom(func(x, y): return scores[x] > scores[y])
		var reordered: Array = []
		var rescored := {}
		for j in idx.size():
			reordered.append(moves[idx[j]])
			rescored[j] = scores[idx[j]]
		moves = reordered
		best_scores = rescored
	# pick among moves within the noise window of the best
	var best := -MATE * 3
	for i in best_scores:
		best = maxi(best, best_scores[i])
	var candidates: Array = []
	for i in best_scores:
		if best_scores[i] >= best - noise:
			candidates.append(moves[i])
	if candidates.is_empty():
		return moves[0]
	return candidates[randi() % candidates.size()]


## The position right after `m`, judged as it stands (mates spotted, replies not).
func _glance(b: ChessRules, m: Dictionary) -> int:
	b.make_move(m)
	var sc := -evaluate(b)
	if b.legal_moves().is_empty():
		sc = MATE if b.in_check(b.side) else 0
	b.unmake_move()
	return sc
