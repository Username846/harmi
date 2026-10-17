class_name BoardView
extends Control
## Draws the chessboard and its elongated pieces, and turns taps into squares.

signal tapped(square: int, piece_square: int)

const LIGHT := Color(0.80, 0.74, 0.62)
const DARK := Color(0.40, 0.30, 0.27)
const TOP_RESERVE := 0.95
const FRAME := 0.3

var rules: ChessRules
var sq := 64.0
var origin := Vector2.ZERO
var selected := -1
var targets: Dictionary = {}
var last_from := -1
var last_to := -1
var check_sq := -1
var hover_sq := -1
var hidden_ids: Dictionary = {}
var offsets: Dictionary = {}
var on_top_id := -1
var alpha_of: Dictionary = {} # piece id -> opacity while fading in
var ash_marks: Array = []
var interactive := true
var target_color := Color(0.95, 0.25, 0.15)
var fx: BoardFX
var _t := 0.0
var _shake := 0.0
var _shake_off := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_fit)
	fx = BoardFX.new()
	fx.board = self
	add_child(fx)
	_fit()


func _fit() -> void:
	sq = floorf(minf(size.x / (8.0 + FRAME * 2.0), size.y / (8.0 + TOP_RESERVE + FRAME)))
	var bw := sq * 8.0
	origin = Vector2(floorf((size.x - bw) * 0.5), floorf(size.y - FRAME * sq - bw))
	pivot_offset = size * 0.5
	queue_redraw()


static func needed_height(width: float) -> float:
	var s := width / (8.0 + FRAME * 2.0)
	return s * (8.0 + TOP_RESERVE + FRAME)


func _process(delta: float) -> void:
	_t += delta
	if _shake > 0.0 or _shake_off != Vector2.ZERO:
		_shake = maxf(0.0, _shake - delta)
		position -= _shake_off
		_shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * sq * 0.12 * minf(_shake * 4.0, 1.0) if _shake > 0.0 else Vector2.ZERO
		position += _shake_off
	queue_redraw()


## Rattles the board for a moment (gunshots, a Beyblade landing).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func square_rect(s: int) -> Rect2:
	var f := s & 7
	var r := s >> 3
	return Rect2(origin + Vector2(f * sq, (7 - r) * sq), Vector2(sq, sq))


func square_center(s: int) -> Vector2:
	return square_rect(s).get_center()


func piece_base(s: int) -> Vector2:
	var r := square_rect(s)
	return Vector2(r.get_center().x, r.end.y - sq * 0.13)


func square_at(p: Vector2) -> int:
	var lp := p - origin
	if lp.x < 0 or lp.y < 0 or lp.x >= sq * 8 or lp.y >= sq * 8:
		return -1
	var f := int(lp.x / sq)
	var r := 7 - int(lp.y / sq)
	return r * 8 + f


func piece_square_at(p: Vector2) -> int:
	if rules == null:
		return -1
	for r in 8:
		for f in 8:
			var s := r * 8 + f
			var code := rules.board[s]
			if code == 0 or hidden_ids.has(rules.ids[s]):
				continue
			var b: Vector2 = piece_base(s) + offsets.get(rules.ids[s], Vector2.ZERO)
			var rect := PieceArt.bounds(code & 7, b.x, b.y, sq).grow(sq * 0.04)
			if rect.has_point(p):
				return s
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := square_at(event.position)
		if h != hover_sq:
			hover_sq = h
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not interactive:
			return
		tapped.emit(square_at(event.position), piece_square_at(event.position))
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover_sq = -1


func _draw() -> void:
	if rules == null:
		return
	var font := ThemeDB.fallback_font
	var board_rect := Rect2(origin, Vector2(sq * 8, sq * 8))
	# frame
	var fr := board_rect.grow(sq * FRAME)
	draw_rect(fr.grow(3), Color(0.03, 0.02, 0.03))
	draw_rect(fr, Color(0.20, 0.13, 0.10))
	draw_rect(fr.grow(-sq * 0.06), Color(0.26, 0.17, 0.12))
	draw_rect(board_rect.grow(3), UI.GOLD.darkened(0.35))
	# squares
	for s in 64:
		var rr := square_rect(s)
		var light := ((s & 7) + (s >> 3)) % 2 == 1
		var c := LIGHT if light else DARK
		# gentle vertical shading so the board feels lit from the top
		var shade := 1.0 - 0.10 * float(7 - (s >> 3)) / 7.0
		draw_rect(rr, Color(c.r * shade, c.g * shade, c.b * shade))
		var h := absi(hash(s * 7919))
		for k in 3:
			var px := float((h >> (k * 5)) % 97) / 97.0
			var py := float((h >> (k * 7 + 3)) % 89) / 89.0
			draw_circle(rr.position + Vector2(px, py) * sq, sq * 0.06, Color(0, 0, 0, 0.025))
	# coordinates
	var fs := int(maxf(10.0, sq * 0.22))
	for i in 8:
		var fx := origin.x + i * sq + sq * 0.5 - fs * 0.25
		draw_string(font, Vector2(fx, board_rect.end.y + sq * FRAME * 0.78), "abcdefgh"[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.DIM)
		var ry := origin.y + (7 - i) * sq + sq * 0.5 + fs * 0.35
		draw_string(font, Vector2(origin.x - sq * FRAME * 0.72, ry), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.DIM)
	# ash marks of fallen pieces
	for m in ash_marks:
		var center: Vector2 = square_center(m["sq"]) + Vector2(0, sq * 0.22)
		var rng := RandomNumberGenerator.new()
		rng.seed = m["seed"]
		for k in 9:
			var off := Vector2(rng.randf_range(-0.28, 0.28), rng.randf_range(-0.1, 0.1)) * sq
			draw_circle(center + off, sq * rng.randf_range(0.04, 0.1), Color(0.12, 0.11, 0.11, 0.35))
	# last move
	if last_from >= 0:
		draw_rect(square_rect(last_from), Color(0.95, 0.75, 0.3, 0.18))
		draw_rect(square_rect(last_to), Color(0.95, 0.75, 0.3, 0.28))
	if hover_sq >= 0 and interactive:
		draw_rect(square_rect(hover_sq), Color(1, 1, 1, 0.07))
	if check_sq >= 0:
		var cr := square_rect(check_sq)
		var pulse := 0.45 + 0.25 * sin(_t * 6.0)
		draw_circle(cr.get_center(), sq * 0.52, Color(0.9, 0.12, 0.08, pulse * 0.5))
		draw_rect(cr, Color(0.9, 0.15, 0.1, pulse * 0.35))
	if selected >= 0:
		draw_rect(square_rect(selected), Color(0.95, 0.75, 0.3, 0.45))
		draw_rect(square_rect(selected), UI.GOLD, false, 3.0)
	# capture (or challenge / target) rings under pieces
	for tsq in targets:
		if targets[tsq]:
			var rr := square_rect(tsq)
			var tc := target_color
			draw_rect(rr, Color(tc.r * 0.9, tc.g * 0.6, tc.b * 0.6, 0.22 + 0.08 * sin(_t * 5.0)))
			draw_rect(rr.grow(-2), Color(tc.r, tc.g, tc.b, 0.9), false, 3.0)
	# pieces, back rank to front rank
	var top_piece := {}
	for r in range(7, -1, -1):
		for f in 8:
			var s := r * 8 + f
			var code := rules.board[s]
			if code == 0:
				continue
			var pid := rules.ids[s]
			if hidden_ids.has(pid):
				continue
			if pid == on_top_id:
				top_piece = {"s": s, "code": code, "pid": pid}
				continue
			_draw_piece_at(s, code, pid)
	if not top_piece.is_empty():
		_draw_piece_at(top_piece["s"], top_piece["code"], top_piece["pid"])
	# move dots on top so they stay visible behind tall pieces
	for tsq in targets:
		if not targets[tsq]:
			var c := square_center(tsq) + Vector2(0, sq * 0.12)
			draw_circle(c, sq * 0.15, Color(0.1, 0.07, 0.05, 0.35))
			draw_circle(c, sq * 0.12, Color(0.95, 0.78, 0.35, 0.85))


func _draw_piece_at(s: int, code: int, pid: int) -> void:
	var b: Vector2 = piece_base(s) + offsets.get(pid, Vector2.ZERO)
	var t := code & 7
	var white := (code & 8) == 0
	var life := Game.piece(pid)
	if int(life["toppled"]) > 0:
		_draw_toppled(s, t, white, pid, b)
		return
	var away := int(life["away"]) > 0
	if s == selected:
		var glow := PieceArt.build(t, white, b.x, b.y, sq)
		for sh in glow:
			if sh["line"]:
				var pts: PackedVector2Array = sh["p"].duplicate()
				pts.append(pts[0])
				draw_polyline(pts, Color(1.0, 0.8, 0.35, 0.55 + 0.25 * sin(_t * 5.0)), sq * 0.09, true)
	var alpha: float = alpha_of.get(pid, 1.0) * (0.38 if away else 1.0)
	PieceArt.draw_piece(self, t, white, b.x, b.y, sq, Color(1, 1, 1, alpha))
	var top: float = b.y - PieceArt.height(t) * sq
	if not Game.buffs_of(pid).is_empty():
		var tw := sin(_t * 4.0 + pid) * 0.3 + 1.0
		_sparkle(Vector2(b.x + sq * 0.18, top - sq * 0.02), sq * 0.09 * tw)
	if away:
		_draw_job_sign(b, int(life["away"]))
	elif float(life["mood"]) < 30.0:
		_draw_rain_cloud(Vector2(b.x, top - sq * 0.2), float(life["mood"]), pid)
	if not bool(life["car"]):
		_draw_no_car(Vector2(b.x - sq * 0.3, b.y - sq * 0.06))


## A piece knocked over by a Beyblade lies on its side, seeing stars.
func _draw_toppled(s: int, t: int, white: bool, pid: int, b: Vector2) -> void:
	var sgn := 1.0 if pid % 2 == 0 else -1.0
	var k := clampf(0.95 / PieceArt.height(t), 0.5, 0.95)
	var length := PieceArt.height(t) * sq * k
	var pivot := Vector2(b.x + sgn * length * 0.5, b.y - sq * 0.08)
	draw_set_transform(pivot, -sgn * PI * 0.5, Vector2(k, k))
	PieceArt.draw_piece(self, t, white, 0.0, 0.0, sq, Color.WHITE, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var head := Vector2(pivot.x - sgn * length, pivot.y - sq * 0.1)
	for i in 3:
		var a := _t * 3.0 + TAU * i / 3.0
		var p := head + Vector2(cos(a) * sq * 0.16, sin(a) * sq * 0.06 - sq * 0.12)
		_sparkle(p, sq * 0.05)
	if s == selected:
		draw_rect(square_rect(s).grow(-3), Color(1.0, 0.8, 0.35, 0.6), false, 2.0)


func _draw_job_sign(b: Vector2, turns: int) -> void:
	var font := ThemeDB.fallback_font
	var post_top := b.y - sq * 0.62
	draw_line(Vector2(b.x + sq * 0.22, b.y - sq * 0.02), Vector2(b.x + sq * 0.22, post_top), Color(0.35, 0.24, 0.15), maxf(2.0, sq * 0.04))
	var r := Rect2(Vector2(b.x - sq * 0.12, post_top - sq * 0.24), Vector2(sq * 0.68, sq * 0.3))
	draw_rect(r, Color(0.86, 0.72, 0.45))
	draw_rect(r, Color(0.35, 0.24, 0.15), false, maxf(1.0, sq * 0.025))
	var fs := int(maxf(9.0, sq * 0.15))
	draw_string(font, r.position + Vector2(sq * 0.04, r.size.y * 0.5 + fs * 0.35), "BRB x%d" % turns, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - sq * 0.06, fs, Color(0.2, 0.12, 0.08))


func _draw_rain_cloud(c: Vector2, mood: float, pid: int) -> void:
	var k := sq * 0.1
	var dark := clampf(1.0 - mood / 30.0, 0.0, 1.0)
	var col := Color(0.55, 0.57, 0.62).lerp(Color(0.25, 0.25, 0.3), dark)
	var drift := Vector2(sin(_t * 0.8 + pid) * k * 0.4, 0)
	for o in [Vector2(-1.2, 0.2), Vector2(0, -0.35), Vector2(1.1, 0.15), Vector2(0.4, 0.35), Vector2(-0.5, 0.4)]:
		draw_circle(c + drift + o * k, k * 0.95, col)
	for i in 3:
		var ph := fmod(_t * 1.6 + i * 0.37 + pid * 0.13, 1.0)
		var p := c + drift + Vector2((i - 1) * k * 0.9, k * 0.9 + ph * k * 2.6)
		draw_line(p, p + Vector2(-k * 0.15, k * 0.45), Color(0.55, 0.7, 0.95, 0.85 * (1.0 - ph)), maxf(1.0, sq * 0.02))


## Small "no car" badge: a car with a red slash.
func _draw_no_car(p: Vector2) -> void:
	var k := sq * 0.07
	var body := PackedVector2Array([p + Vector2(-2.0, 0.4) * k, p + Vector2(2.0, 0.4) * k, p + Vector2(2.0, -0.4) * k,
		p + Vector2(1.0, -0.5) * k, p + Vector2(0.6, -1.1) * k, p + Vector2(-0.9, -1.1) * k, p + Vector2(-1.4, -0.5) * k, p + Vector2(-2.0, -0.4) * k])
	draw_colored_polygon(body, Color(0.35, 0.6, 0.85, 0.9))
	draw_circle(p + Vector2(-1.1, 0.45) * k, k * 0.42, Color(0.1, 0.1, 0.12))
	draw_circle(p + Vector2(1.1, 0.45) * k, k * 0.42, Color(0.1, 0.1, 0.12))
	draw_circle(p + Vector2(0, -0.3) * k, k * 2.3, Color(0.9, 0.15, 0.1), false, maxf(1.5, k * 0.35))
	draw_line(p + Vector2(-1.6, 1.3) * k, p + Vector2(1.6, -1.9) * k, Color(0.9, 0.15, 0.1), maxf(1.5, k * 0.35))


func _sparkle(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := PI * 0.25 * i
		var rad := r if i % 2 == 0 else r * 0.35
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.4, 0.95))


## Animates a piece's visual offset from its logical square toward another square.
func slide(pid: int, from_sq: int, to_sq: int, frac_from: float, frac_to: float, dur: float) -> Tween:
	var delta := piece_base(to_sq) - piece_base(from_sq)
	on_top_id = pid
	var tw := create_tween()
	tw.tween_method(func(k: float): offsets[pid] = delta * k, frac_from, frac_to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


func clear_offset(pid: int) -> void:
	offsets.erase(pid)
	if on_top_id == pid:
		on_top_id = -1


## Spawns a crumbling-to-ash effect for the piece currently drawn on square s.
func disintegrate(s: int, duration: float = 1.9) -> AshEffect:
	var code := rules.board[s]
	var pid := rules.ids[s]
	var b: Vector2 = piece_base(s) + offsets.get(pid, Vector2.ZERO)
	hidden_ids[pid] = true
	var fx := AshEffect.new()
	fx.setup(code & 7, (code & 8) == 0, b.x, b.y, sq, duration)
	add_child(fx)
	ash_marks.append({"sq": s, "seed": randi()})
	return fx
