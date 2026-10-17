class_name ChessRules
extends RefCounted
## Standard chess rules: legal move generation, check, castling, en passant,
## promotion, mate/stalemate and draw detection.
## Squares are 0..63 with index = rank * 8 + file, rank 0 = White's back rank.

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const BLACK_BIT := 8

const WHITE := 0
const BLACK := 1

const FLAG_NORMAL := 0
const FLAG_DOUBLE := 1
const FLAG_EP := 2
const FLAG_CASTLE_K := 3
const FLAG_CASTLE_Q := 4

const KNIGHT_OFFS := [Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2)]
const KING_OFFS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const DIAG_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const ORTHO_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const LETTERS := ["", "", "N", "B", "R", "Q", "K"]

var board := PackedInt32Array()
var ids := PackedInt32Array()
var side := WHITE
var castling := 15 # 1 = white O-O, 2 = white O-O-O, 4 = black O-O, 8 = black O-O-O
var ep := -1
var halfmove := 0
var fullmove := 1
var _undo: Array = []
var position_counts: Dictionary = {}


func _init() -> void:
	board.resize(64)
	ids.resize(64)
	clear()


func clear() -> void:
	for i in 64:
		board[i] = EMPTY
		ids[i] = -1
	side = WHITE
	castling = 0
	ep = -1
	halfmove = 0
	fullmove = 1
	_undo.clear()
	position_counts.clear()


func setup_start() -> void:
	clear()
	var back := [ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK]
	for f in 8:
		board[f] = back[f]
		ids[f] = f
		board[8 + f] = PAWN
		ids[8 + f] = 8 + f
		board[48 + f] = PAWN | BLACK_BIT
		ids[48 + f] = 24 + f
		board[56 + f] = back[f] | BLACK_BIT
		ids[56 + f] = 16 + f
	castling = 15
	record_position()


## Loads a FEN string (piece ids are assigned in scan order). Used by tests.
func load_fen(fen: String) -> void:
	clear()
	var parts := fen.split(" ")
	var rows := parts[0].split("/")
	var next_id := 0
	for i in 8:
		var r := 7 - i
		var f := 0
		for ch in rows[i]:
			if ch.is_valid_int():
				f += int(ch)
				continue
			var t: int = "pnbrqk".find(ch.to_lower()) + 1
			var code := t
			if ch == ch.to_lower():
				code |= BLACK_BIT
			board[r * 8 + f] = code
			ids[r * 8 + f] = next_id
			next_id += 1
			f += 1
	side = WHITE if parts[1] == "w" else BLACK
	castling = 0
	if parts.size() > 2:
		if parts[2].contains("K"): castling |= 1
		if parts[2].contains("Q"): castling |= 2
		if parts[2].contains("k"): castling |= 4
		if parts[2].contains("q"): castling |= 8
	ep = -1
	if parts.size() > 3 and parts[3] != "-":
		ep = square_from_name(parts[3])
	record_position()


func copy() -> ChessRules:
	var c := ChessRules.new()
	c.board = board.duplicate()
	c.ids = ids.duplicate()
	c.side = side
	c.castling = castling
	c.ep = ep
	c.halfmove = halfmove
	c.fullmove = fullmove
	c.position_counts = position_counts.duplicate()
	return c


static func type_of(code: int) -> int:
	return code & 7


static func color_of(code: int) -> int:
	return 1 if (code & BLACK_BIT) != 0 else 0


static func square_name(s: int) -> String:
	return "abcdefgh"[s & 7] + str((s >> 3) + 1)


static func square_from_name(n: String) -> int:
	return (int(n.substr(1, 1)) - 1) * 8 + "abcdefgh".find(n.substr(0, 1))


func piece_at(s: int) -> int:
	return board[s]


func find_id(piece_id: int) -> int:
	for s in 64:
		if ids[s] == piece_id:
			return s
	return -1


func king_square(color: int) -> int:
	var k := KING | (BLACK_BIT if color == BLACK else 0)
	for s in 64:
		if board[s] == k:
			return s
	return -1


func is_attacked(s: int, by: int) -> bool:
	var f := s & 7
	var r := s >> 3
	var bb := BLACK_BIT if by == BLACK else 0
	# pawns
	var pr := r - (1 if by == WHITE else -1)
	if pr >= 0 and pr < 8:
		if f > 0 and board[pr * 8 + f - 1] == (PAWN | bb):
			return true
		if f < 7 and board[pr * 8 + f + 1] == (PAWN | bb):
			return true
	# knights
	for o in KNIGHT_OFFS:
		var nf: int = f + o.x
		var nr: int = r + o.y
		if nf >= 0 and nf < 8 and nr >= 0 and nr < 8 and board[nr * 8 + nf] == (KNIGHT | bb):
			return true
	# king
	for o in KING_OFFS:
		var nf: int = f + o.x
		var nr: int = r + o.y
		if nf >= 0 and nf < 8 and nr >= 0 and nr < 8 and board[nr * 8 + nf] == (KING | bb):
			return true
	# sliders
	for d in ORTHO_DIRS:
		var nf: int = f + d.x
		var nr: int = r + d.y
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var c := board[nr * 8 + nf]
			if c != EMPTY:
				if c == (ROOK | bb) or c == (QUEEN | bb):
					return true
				break
			nf += d.x
			nr += d.y
	for d in DIAG_DIRS:
		var nf: int = f + d.x
		var nr: int = r + d.y
		while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
			var c := board[nr * 8 + nf]
			if c != EMPTY:
				if c == (BISHOP | bb) or c == (QUEEN | bb):
					return true
				break
			nf += d.x
			nr += d.y
	return false


func in_check(color: int) -> bool:
	var k := king_square(color)
	return k >= 0 and is_attacked(k, 1 - color)


func _add_pawn(moves: Array, from: int, to: int, promote: bool) -> void:
	if promote:
		for p in [QUEEN, ROOK, BISHOP, KNIGHT]:
			moves.append({"from": from, "to": to, "flag": FLAG_NORMAL, "promo": p})
	else:
		moves.append({"from": from, "to": to, "flag": FLAG_NORMAL, "promo": 0})


## Pseudo-legal moves for the side to move (castling is fully checked).
func gen_pseudo(captures_only: bool = false) -> Array:
	var moves: Array = []
	var bb := BLACK_BIT if side == BLACK else 0
	for s in 64:
		var code := board[s]
		if code == EMPTY or (code & BLACK_BIT) != bb:
			continue
		var t := code & 7
		var f := s & 7
		var r := s >> 3
		if t == PAWN:
			var dir := 1 if side == WHITE else -1
			var start_rank := 1 if side == WHITE else 6
			var promo_rank := 7 if side == WHITE else 0
			var r1 := r + dir
			if r1 >= 0 and r1 < 8:
				var t1 := r1 * 8 + f
				if board[t1] == EMPTY and (not captures_only or r1 == promo_rank):
					_add_pawn(moves, s, t1, r1 == promo_rank)
					if not captures_only and r == start_rank and board[(r + 2 * dir) * 8 + f] == EMPTY:
						moves.append({"from": s, "to": (r + 2 * dir) * 8 + f, "flag": FLAG_DOUBLE, "promo": 0})
				for df in [-1, 1]:
					var nf: int = f + df
					if nf < 0 or nf > 7:
						continue
					var t2: int = r1 * 8 + nf
					var c2 := board[t2]
					if c2 != EMPTY and (c2 & BLACK_BIT) != bb:
						_add_pawn(moves, s, t2, r1 == promo_rank)
					elif t2 == ep and c2 == EMPTY:
						moves.append({"from": s, "to": t2, "flag": FLAG_EP, "promo": 0})
		elif t == KNIGHT or t == KING:
			var offs: Array = KNIGHT_OFFS if t == KNIGHT else KING_OFFS
			for o in offs:
				var nf: int = f + o.x
				var nr: int = r + o.y
				if nf < 0 or nf > 7 or nr < 0 or nr > 7:
					continue
				var t3: int = nr * 8 + nf
				var c3 := board[t3]
				if c3 == EMPTY:
					if not captures_only:
						moves.append({"from": s, "to": t3, "flag": FLAG_NORMAL, "promo": 0})
				elif (c3 & BLACK_BIT) != bb:
					moves.append({"from": s, "to": t3, "flag": FLAG_NORMAL, "promo": 0})
			if t == KING and not captures_only:
				_gen_castles(moves, s)
		else:
			var dirs: Array
			if t == BISHOP:
				dirs = DIAG_DIRS
			elif t == ROOK:
				dirs = ORTHO_DIRS
			else:
				dirs = DIAG_DIRS + ORTHO_DIRS
			for d in dirs:
				var nf: int = f + d.x
				var nr: int = r + d.y
				while nf >= 0 and nf < 8 and nr >= 0 and nr < 8:
					var t4: int = nr * 8 + nf
					var c4 := board[t4]
					if c4 == EMPTY:
						if not captures_only:
							moves.append({"from": s, "to": t4, "flag": FLAG_NORMAL, "promo": 0})
					else:
						if (c4 & BLACK_BIT) != bb:
							moves.append({"from": s, "to": t4, "flag": FLAG_NORMAL, "promo": 0})
						break
					nf += d.x
					nr += d.y
	return moves


func _gen_castles(moves: Array, s: int) -> void:
	var enemy := 1 - side
	if side == WHITE and s == 4:
		if (castling & 1) and board[5] == EMPTY and board[6] == EMPTY and board[7] == ROOK:
			if not is_attacked(4, enemy) and not is_attacked(5, enemy) and not is_attacked(6, enemy):
				moves.append({"from": 4, "to": 6, "flag": FLAG_CASTLE_K, "promo": 0})
		if (castling & 2) and board[3] == EMPTY and board[2] == EMPTY and board[1] == EMPTY and board[0] == ROOK:
			if not is_attacked(4, enemy) and not is_attacked(3, enemy) and not is_attacked(2, enemy):
				moves.append({"from": 4, "to": 2, "flag": FLAG_CASTLE_Q, "promo": 0})
	elif side == BLACK and s == 60:
		if (castling & 4) and board[61] == EMPTY and board[62] == EMPTY and board[63] == (ROOK | BLACK_BIT):
			if not is_attacked(60, enemy) and not is_attacked(61, enemy) and not is_attacked(62, enemy):
				moves.append({"from": 60, "to": 62, "flag": FLAG_CASTLE_K, "promo": 0})
		if (castling & 8) and board[59] == EMPTY and board[58] == EMPTY and board[57] == EMPTY and board[56] == (ROOK | BLACK_BIT):
			if not is_attacked(60, enemy) and not is_attacked(59, enemy) and not is_attacked(58, enemy):
				moves.append({"from": 60, "to": 58, "flag": FLAG_CASTLE_Q, "promo": 0})


## Square of the piece a move captures (differs from "to" for en passant), or -1.
func capture_square(m: Dictionary) -> int:
	if m["flag"] == FLAG_EP:
		return m["to"] + (-8 if color_of(board[m["from"]]) == WHITE else 8)
	if board[m["to"]] != EMPTY:
		return m["to"]
	return -1


func make_move(m: Dictionary) -> void:
	var from: int = m["from"]
	var to: int = m["to"]
	var flag: int = m["flag"]
	var code := board[from]
	var pid := ids[from]
	var cap_sq := to
	if flag == FLAG_EP:
		cap_sq = to + (-8 if side == WHITE else 8)
	var rec := {"m": m, "captured": board[cap_sq], "cap_id": ids[cap_sq], "cap_sq": cap_sq,
		"castling": castling, "ep": ep, "halfmove": halfmove, "fullmove": fullmove}
	_undo.append(rec)
	board[cap_sq] = EMPTY
	ids[cap_sq] = -1
	board[to] = code
	ids[to] = pid
	board[from] = EMPTY
	ids[from] = -1
	var promo: int = m["promo"]
	if promo != 0:
		board[to] = promo | (code & BLACK_BIT)
	if flag == FLAG_CASTLE_K:
		board[to - 1] = board[to + 1]
		ids[to - 1] = ids[to + 1]
		board[to + 1] = EMPTY
		ids[to + 1] = -1
	elif flag == FLAG_CASTLE_Q:
		board[to + 1] = board[to - 2]
		ids[to + 1] = ids[to - 2]
		board[to - 2] = EMPTY
		ids[to - 2] = -1
	for sq in [from, to]:
		match sq:
			0: castling &= ~2
			4: castling &= ~3
			7: castling &= ~1
			56: castling &= ~8
			60: castling &= ~12
			63: castling &= ~4
	ep = (from + to) / 2 if flag == FLAG_DOUBLE else -1
	if (code & 7) == PAWN or rec["captured"] != EMPTY:
		halfmove = 0
	else:
		halfmove += 1
	if side == BLACK:
		fullmove += 1
	side = 1 - side


func unmake_move() -> void:
	var rec: Dictionary = _undo.pop_back()
	var m: Dictionary = rec["m"]
	var from: int = m["from"]
	var to: int = m["to"]
	side = 1 - side
	var code := board[to]
	if m["promo"] != 0:
		code = PAWN | (code & BLACK_BIT)
	board[from] = code
	ids[from] = ids[to]
	board[to] = EMPTY
	ids[to] = -1
	var cap_sq: int = rec["cap_sq"]
	board[cap_sq] = rec["captured"]
	ids[cap_sq] = rec["cap_id"]
	var flag: int = m["flag"]
	if flag == FLAG_CASTLE_K:
		board[to + 1] = board[to - 1]
		ids[to + 1] = ids[to - 1]
		board[to - 1] = EMPTY
		ids[to - 1] = -1
	elif flag == FLAG_CASTLE_Q:
		board[to - 2] = board[to + 1]
		ids[to - 2] = ids[to + 1]
		board[to + 1] = EMPTY
		ids[to + 1] = -1
	castling = rec["castling"]
	ep = rec["ep"]
	halfmove = rec["halfmove"]
	fullmove = rec["fullmove"]


func legal_moves() -> Array:
	var out: Array = []
	var mover := side
	for m in gen_pseudo():
		make_move(m)
		if not in_check(mover):
			out.append(m)
		unmake_move()
	return out


func legal_moves_from(s: int) -> Array:
	var out: Array = []
	for m in legal_moves():
		if m["from"] == s:
			out.append(m)
	return out


func position_key() -> String:
	return "%s|%d|%d|%d" % [str(board), side, castling, ep]


func record_position() -> void:
	var k := position_key()
	position_counts[k] = int(position_counts.get(k, 0)) + 1


## Plays a move for real (records history for repetition detection).
func play(m: Dictionary) -> void:
	make_move(m)
	record_position()


## Hands the turn to the other side without a chess move (odd jobs, races,
## dates, sniper shots...). Only call it when the side to move is not in check.
func pass_turn() -> void:
	ep = -1
	halfmove += 1
	if side == BLACK:
		fullmove += 1
	side = 1 - side
	# a pass breaks any repetition sequence
	position_counts.clear()
	record_position()


## Takes a piece off the board without a move (sniper, drive-by).
func remove_piece(s: int) -> void:
	board[s] = EMPTY
	ids[s] = -1
	_lose_castling(s)
	ep = -1


## Moves a piece to another square outside the rules (knocked by a Beyblade).
func relocate(from: int, to: int) -> void:
	board[to] = board[from]
	ids[to] = ids[from]
	board[from] = EMPTY
	ids[from] = -1
	_lose_castling(from)
	_lose_castling(to)
	ep = -1


## Puts a piece onto an empty square (a piece won back from the graveyard).
func place_piece(s: int, code: int, pid: int) -> void:
	board[s] = code
	ids[s] = pid
	ep = -1


func _lose_castling(s: int) -> void:
	match s:
		0: castling &= ~2
		4: castling &= ~3
		7: castling &= ~1
		56: castling &= ~8
		60: castling &= ~12
		63: castling &= ~4


func insufficient_material() -> bool:
	var minors := 0
	var bishops_light := 0
	var bishops_dark := 0
	for s in 64:
		var t := board[s] & 7
		if t == EMPTY or t == KING:
			continue
		if t == PAWN or t == ROOK or t == QUEEN:
			return false
		minors += 1
		if t == BISHOP:
			if ((s & 7) + (s >> 3)) % 2 == 0:
				bishops_dark += 1
			else:
				bishops_light += 1
	if minors <= 1:
		return true
	if minors == bishops_dark or minors == bishops_light:
		return true
	return false


## "ongoing", "checkmate", "stalemate", "fifty", "repetition", "material"
func status() -> String:
	if legal_moves().is_empty():
		return "checkmate" if in_check(side) else "stalemate"
	if halfmove >= 100:
		return "fifty"
	if int(position_counts.get(position_key(), 0)) >= 3:
		return "repetition"
	if insufficient_material():
		return "material"
	return "ongoing"


## Standard algebraic notation for a legal move in the current position.
func san(m: Dictionary) -> String:
	var from: int = m["from"]
	var to: int = m["to"]
	var flag: int = m["flag"]
	var s := ""
	if flag == FLAG_CASTLE_K:
		s = "O-O"
	elif flag == FLAG_CASTLE_Q:
		s = "O-O-O"
	else:
		var t := board[from] & 7
		var is_cap := capture_square(m) >= 0
		if t == PAWN:
			if is_cap:
				s = "abcdefgh"[from & 7] + "x"
			s += square_name(to)
			if m["promo"] != 0:
				s += "=" + LETTERS[m["promo"]]
		else:
			s = LETTERS[t]
			var same_file := false
			var same_rank := false
			var ambiguous := false
			for o in legal_moves():
				if o["to"] == to and o["from"] != from and (board[o["from"]] & 7) == t:
					ambiguous = true
					if (o["from"] & 7) == (from & 7):
						same_file = true
					if (o["from"] >> 3) == (from >> 3):
						same_rank = true
			if ambiguous:
				if not same_file:
					s += "abcdefgh"[from & 7]
				elif not same_rank:
					s += str((from >> 3) + 1)
				else:
					s += square_name(from)
			if is_cap:
				s += "x"
			s += square_name(to)
	make_move(m)
	if in_check(side):
		s += "#" if legal_moves().is_empty() else "+"
	unmake_move()
	return s


func perft(depth: int) -> int:
	if depth == 0:
		return 1
	var n := 0
	for m in legal_moves():
		make_move(m)
		n += perft(depth - 1)
		unmake_move()
	return n
