class_name BoardFX
extends Control
## Short-lived effects drawn over the board: sniper shots, the drive-by from the
## chessboard next door and the Beyblade crash. A child of BoardView, so it
## works in board coordinates and zooms with the board.

const CAR_BODY := Color(0.42, 0.16, 0.55)
const CAR_TRIM := Color(0.95, 0.55, 0.85)
const NEIGHBOR_TINTS := [Color(1.0, 0.55, 0.5), Color(0.55, 1.0, 0.6), Color(1.0, 0.85, 0.4)]

var board: BoardView
var aim_from := Vector2.ZERO
var aim_to := Vector2.ZERO
var aim_k := -1.0
var tracers: Array = [] # {"a", "b", "t", "life"}
var flashes: Array = [] # {"p", "t", "life", "r"}
var sparks: Array = [] # {"p", "v", "t", "life", "c", "r"}
var car_on := false
var car_pos := Vector2.ZERO
var car_dir := 1.0
var top := {} # the Beyblade, while it is loose on the board
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	for a in [tracers, flashes, sparks]:
		for e in a:
			e["t"] += delta
	for sp in sparks:
		sp["v"] += Vector2(0, 260.0) * delta
		sp["p"] += sp["v"] * delta
	if not top.is_empty():
		top["spin"] = float(top["spin"]) + delta * float(top.get("speed", 20.0))
	tracers = tracers.filter(func(e): return e["t"] < e["life"])
	flashes = flashes.filter(func(e): return e["t"] < e["life"])
	sparks = sparks.filter(func(e): return e["t"] < e["life"])
	queue_redraw()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func flash(p: Vector2, r: float, life: float = 0.18) -> void:
	flashes.append({"p": p, "t": 0.0, "life": life, "r": r})


func burst(p: Vector2, c: Color, n: int, speed: float) -> void:
	for i in n:
		var a := randf() * TAU
		sparks.append({"p": p, "v": Vector2(cos(a), sin(a)) * randf_range(0.3, 1.0) * speed + Vector2(0, -speed * 0.4),
			"t": 0.0, "life": randf_range(0.3, 0.7), "c": c, "r": randf_range(1.5, 3.5)})


## Where a piece's "head" is, for aiming.
func head_of(s: int) -> Vector2:
	var code := board.rules.board[s]
	var b := board.piece_base(s)
	return b - Vector2(0, PieceArt.height(code & 7) * board.sq * 0.8)


## The crosshair closes in on the target, then a single shot rings out.
func snipe(from_sq: int, to_sq: int) -> void:
	aim_from = head_of(from_sq)
	aim_to = board.square_center(to_sq) - Vector2(0, board.sq * 0.35)
	aim_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "aim_k", 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	await _wait(0.25)
	aim_k = -1.0
	flash(aim_from, board.sq * 0.35)
	tracers.append({"a": aim_from, "b": aim_to, "t": 0.0, "life": 0.25})
	flash(aim_to, board.sq * 0.5, 0.25)
	burst(aim_to, Color(1.0, 0.8, 0.4), 18, board.sq * 3.0)
	board.shake(0.25)
	await _wait(0.2)


## The pieces from the chessboard next door cruise along the top or bottom edge
## of the board and fire at each target as they pass it. on_hit(square) is
## called the moment each target is hit.
func drive_by(along_top: bool, target_sqs: Array, on_hit: Callable) -> void:
	var sq := board.sq
	var y := board.origin.y - sq * 0.35 if along_top else board.origin.y + sq * 8.0 + sq * 0.55
	car_dir = 1.0
	var x0 := board.origin.x - sq * 3.2
	var x1 := board.origin.x + sq * 11.2
	var dur := 3.6
	car_pos = Vector2(x0, y)
	car_on = true
	var tw := create_tween()
	tw.tween_property(self, "car_pos:x", x1, dur)
	var order := target_sqs.duplicate()
	order.sort_custom(func(a, b): return (a & 7) < (b & 7))
	var elapsed := 0.0
	for s in order:
		var tx: float = board.square_center(s).x
		var when := clampf((tx - x0) / (x1 - x0), 0.0, 1.0) * dur
		if when > elapsed:
			await _wait(when - elapsed)
			elapsed = when
		var gun := car_pos + Vector2(0, -sq * 0.55)
		var tgt := board.square_center(s) - Vector2(0, sq * 0.3)
		for k in 3:
			flash(gun + Vector2(k * sq * 0.12, 0), sq * 0.28, 0.12)
			tracers.append({"a": gun, "b": tgt + Vector2(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12)) * sq, "t": 0.0, "life": 0.18})
		burst(tgt, Color(1.0, 0.75, 0.35), 14, sq * 2.5)
		board.shake(0.15)
		on_hit.call(s)
	await tw.finished
	car_on = false


## The snapped Beyblade flies in from `start` (board coordinates), slams down
## and caroms around the board. on_hit(square, direction) is called once for
## each piece it smacks; direction is the way it was travelling, in files/ranks.
## Returns how many pieces it hit.
func beyblade_crash(start: Vector2, on_hit: Callable) -> int:
	var sq := board.sq
	var lo := board.origin + Vector2(sq * 0.5, sq * 0.5)
	var hi := board.origin + Vector2(sq * 7.5, sq * 7.5)
	top = {"p": start, "spin": 0.0, "tilt": 0.0, "broken": true, "scale": 1.7, "speed": 40.0}
	# flight onto the board
	var land := board.square_center((randi_range(2, 5) << 3) | randi_range(2, 5))
	var arc := create_tween()
	arc.tween_method(func(k: float):
		top["p"] = start.lerp(land, k) + Vector2(0, -sin(k * PI) * sq * 2.2)
		top["scale"] = lerpf(1.7, 1.0, k), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await arc.finished
	Music.play_crash()
	board.shake(0.45)
	flash(land, sq * 0.7, 0.25)
	burst(land, Color(0.8, 0.85, 1.0), 30, sq * 3.5)
	var hit_ids := {} # lambdas capture locals by value, so count through this dictionary
	var cur := land
	var legs := randi_range(4, 6)
	for leg in legs:
		# mostly aim at pieces so the chaos lands somewhere
		var target := Vector2(randf_range(lo.x, hi.x), randf_range(lo.y, hi.y))
		var occupied: Array = []
		for s in 64:
			if board.rules.board[s] != 0 and not hit_ids.has(board.rules.ids[s]):
				occupied.append(s)
		if not occupied.is_empty() and randf() < 0.7:
			target = board.square_center(occupied[randi() % occupied.size()])
		var d := target - cur
		if d.length() < sq * 0.5:
			continue
		var dir := Vector2i(signi(int(round(d.normalized().x * 1.6))), -signi(int(round(d.normalized().y * 1.6))))
		var from := cur
		var dur := clampf(d.length() / (sq * 7.0), 0.18, 0.7)
		var tw := create_tween()
		tw.tween_method(func(k: float):
			var p := from.lerp(target, k)
			top["p"] = p
			var s2 := board.square_at(p)
			if s2 >= 0 and board.rules.board[s2] != 0:
				var pid := board.rules.ids[s2]
				if not hit_ids.has(pid):
					hit_ids[pid] = true
					flash(p, sq * 0.4, 0.15)
					burst(p, Color(1.0, 0.85, 0.5), 12, sq * 2.5)
					board.shake(0.18)
					on_hit.call(s2, dir), 0.0, 1.0, dur)
		await tw.finished
		cur = target
		top["speed"] = float(top["speed"]) * 0.82
	# wobble, then topple over
	var wob := create_tween()
	wob.tween_method(func(k: float):
		top["tilt"] = sin(k * 26.0) * 0.5 * k
		top["speed"] = lerpf(18.0, 2.0, k), 0.0, 1.0, 1.1)
	wob.tween_method(func(k: float): top["tilt"] = lerpf(0.5, 1.35, k), 0.0, 1.0, 0.25)
	await wob.finished
	var fade := create_tween()
	fade.tween_method(func(k: float): top["scale"] = 1.0 - k * 0.999, 0.0, 1.0, 0.6).set_delay(0.6)
	await fade.finished
	top = {}
	return hit_ids.size()


func _draw() -> void:
	if board == null:
		return
	var sq := board.sq
	for tr in tracers:
		var k: float = 1.0 - tr["t"] / tr["life"]
		draw_line(tr["a"], tr["b"], Color(1.0, 0.9, 0.55, k), maxf(1.5, sq * 0.035), true)
	if aim_k >= 0.0:
		var r := lerpf(sq * 1.6, sq * 0.38, aim_k)
		var c := Color(1.0, 0.2, 0.15, 0.4 + aim_k * 0.5)
		draw_line(aim_from, aim_to, Color(1.0, 0.1, 0.1, 0.35 * aim_k), maxf(1.0, sq * 0.015))
		draw_arc(aim_to, r, 0.0, TAU, 32, c, maxf(1.5, sq * 0.03), true)
		for i in 4:
			var d := Vector2.from_angle(PI * 0.5 * i)
			draw_line(aim_to + d * r * 0.45, aim_to + d * r * 1.25, c, maxf(1.5, sq * 0.03))
		draw_circle(aim_to, sq * 0.03, c)
	if car_on:
		_draw_car(car_pos, sq)
	for f in flashes:
		var k2: float = 1.0 - f["t"] / f["life"]
		draw_circle(f["p"], f["r"] * (0.6 + 0.4 * k2), Color(1.0, 0.85, 0.4, 0.75 * k2))
		draw_circle(f["p"], f["r"] * 0.45, Color(1.0, 1.0, 0.9, k2))
	for sp in sparks:
		var k3: float = 1.0 - sp["t"] / sp["life"]
		var col: Color = sp["c"]
		draw_circle(sp["p"], sp["r"], Color(col.r, col.g, col.b, k3))
	if not top.is_empty():
		BeybladeArt.draw_top(self, top["p"], sq * 0.42 * float(top.get("scale", 1.0)), top["spin"], top.get("tilt", 0.0), top.get("broken", true))


## A long, bouncing lowrider with three pieces from a neighbour's chess set.
func _draw_car(p: Vector2, sq: float) -> void:
	var L := sq * 2.8
	var H := sq * 0.42
	var bounce := sin(_t * 9.0)
	var tilt := bounce * 0.06
	draw_set_transform(p, tilt, Vector2.ONE)
	# riders first so the door hides their bases
	for i in 3:
		var tint: Color = NEIGHBOR_TINTS[i]
		var pt: int = [2, 3, 1][i]
		var px := -L * 0.25 + i * L * 0.24
		var bob := sin(_t * 9.0 + i) * sq * 0.04
		PieceArt.draw_piece(self, pt, i != 1, px, -H * 0.55 + bob, sq * 0.62, tint, false)
		# shades
		var hy := -H * 0.55 + bob - PieceArt.height(pt) * sq * 0.62 * 0.78
		draw_rect(Rect2(Vector2(px - sq * 0.11, hy - sq * 0.03), Vector2(sq * 0.22, sq * 0.06)), Color(0.05, 0.05, 0.08))
	var body := PackedVector2Array([Vector2(-L * 0.5, -H * 0.15), Vector2(-L * 0.47, -H * 0.62), Vector2(-L * 0.2, -H * 0.7),
		Vector2(L * 0.32, -H * 0.7), Vector2(L * 0.5, -H * 0.45), Vector2(L * 0.52, -H * 0.05), Vector2(L * 0.48, H * 0.2),
		Vector2(-L * 0.48, H * 0.2)])
	draw_colored_polygon(body, CAR_BODY)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, Color(0.1, 0.04, 0.12), maxf(1.5, sq * 0.03), true)
	# flame decal and chrome strip
	draw_line(Vector2(-L * 0.46, -H * 0.12), Vector2(L * 0.5, -H * 0.12), Color(0.85, 0.85, 0.9), maxf(1.5, sq * 0.035))
	for i in 4:
		var fx := L * 0.12 + i * L * 0.07
		draw_colored_polygon(PackedVector2Array([Vector2(fx, -H * 0.2), Vector2(fx + L * 0.09, -H * 0.42), Vector2(fx + L * 0.04, -H * 0.2)]), CAR_TRIM)
	draw_rect(Rect2(Vector2(L * 0.48, -H * 0.3), Vector2(sq * 0.08, H * 0.2)), Color(1.0, 0.95, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# whitewall wheels stay on the road while the body hops on hydraulics
	for wx in [-L * 0.32, L * 0.32]:
		var c := p + Vector2(wx, H * 0.25 + sq * 0.05)
		draw_circle(c, sq * 0.2, Color(0.06, 0.06, 0.07))
		draw_circle(c, sq * 0.13, Color(0.92, 0.92, 0.9))
		draw_circle(c, sq * 0.08, Color(0.7, 0.72, 0.78))
		var spin := _t * 14.0
		for k in 3:
			var d := Vector2.from_angle(spin + TAU * k / 3.0) * sq * 0.075
			draw_line(c - d, c + d, Color(0.45, 0.45, 0.5), 1.5)
