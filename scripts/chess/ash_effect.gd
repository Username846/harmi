class_name AshEffect
extends Node2D
## A piece crumbling into ash from the top down, shedding embers that cool to grey.

signal finished

var shapes: Array = []
var line := Color.WHITE
var line_w := 1.0
var top_y := 0.0
var bot_y := 0.0
var x_min := 0.0
var x_max := 0.0
var base := Vector2.ZERO
var sq := 64.0
var dur := 1.9
var t := 0.0
var particles: Array = []
var _spawn_acc := 0.0
var _done := false


func setup(piece_type: int, white: bool, cx: float, by: float, s: float, duration: float = 1.9) -> void:
	shapes = PieceArt.build(piece_type, white, cx, by, s)
	line = PieceArt.line_color(white)
	line_w = maxf(1.0, s * 0.028)
	sq = s
	dur = duration
	base = Vector2(cx, by)
	top_y = by - PieceArt.height(piece_type) * s - 2.0
	bot_y = by + 2.0
	x_min = cx - 0.36 * s
	x_max = cx + 0.36 * s


func _front() -> float:
	var k := clampf(t / dur, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	return lerpf(top_y, bot_y, k)


func _inside(p: Vector2) -> bool:
	for sh in shapes:
		var c: Color = sh["c"]
		if c.a >= 0.9 and Geometry2D.is_point_in_polygon(p, sh["p"]):
			return true
	return false


func _process(delta: float) -> void:
	t += delta
	var front := _front()
	if t < dur:
		_spawn_acc += delta * 320.0 * clampf(sq / 64.0, 0.5, 3.0)
		var tries := 0
		while _spawn_acc >= 1.0 and tries < 60:
			tries += 1
			var p := Vector2(randf_range(x_min, x_max), front + randf_range(-3.0, 3.0))
			if _inside(p):
				_spawn_acc -= 1.0
				var life := randf_range(0.9, 1.9)
				particles.append({
					"p": p,
					"v": Vector2(randf_range(-12.0, 28.0), randf_range(-38.0, -8.0)) * (sq / 64.0),
					"life": life, "max": life,
					"size": randf_range(1.2, 3.2) * clampf(sq / 64.0, 0.6, 2.5),
					"seed": randf() * TAU,
				})
		if tries >= 60:
			_spawn_acc = 0.0
	var wind := 22.0 * (sq / 64.0)
	for p in particles:
		var age: float = 1.0 - p["life"] / p["max"]
		var v: Vector2 = p["v"]
		v.x += (wind * 0.6 + sin(t * 3.0 + p["seed"]) * 30.0) * delta
		v.y += (-6.0 + age * 18.0) * delta * (sq / 64.0)
		p["v"] = v
		p["p"] += v * delta
		p["life"] -= delta
	particles = particles.filter(func(p): return p["life"] > 0.0)
	if t >= dur and particles.is_empty() and not _done:
		_done = true
		finished.emit()
		queue_free()
	queue_redraw()


func _draw() -> void:
	var front := _front()
	var char_k := clampf(t / dur * 1.3, 0.0, 0.85)
	# ash heap growing at the base
	var heap_w := 0.34 * sq * clampf(t / dur * 1.2, 0.0, 1.0)
	if heap_w > 1.0:
		var heap := PackedVector2Array()
		for i in 16:
			var a := PI + PI * i / 15.0
			heap.append(base + Vector2(cos(a) * heap_w, sin(a) * heap_w * 0.35))
		draw_colored_polygon(heap, Color(0.33, 0.31, 0.3, 0.9))
	if front < bot_y:
		var clip := PackedVector2Array([Vector2(x_min - 8, front), Vector2(x_max + 8, front),
			Vector2(x_max + 8, bot_y + 8), Vector2(x_min - 8, bot_y + 8)])
		var charred := Color(0.22, 0.2, 0.2)
		for sh in shapes:
			var c: Color = sh["c"]
			var pieces := Geometry2D.intersect_polygons(sh["p"], clip)
			for poly in pieces:
				if poly.size() < 3:
					continue
				if c.a > 0.0:
					var cc := c.lerp(Color(charred.r, charred.g, charred.b, c.a), char_k)
					draw_colored_polygon(poly, cc)
				if sh["line"]:
					var closed := poly.duplicate()
					closed.append(poly[0])
					draw_polyline(closed, line.lerp(Color(0.15, 0.1, 0.08), char_k), line_w, true)
		# glowing seam
		if t < dur:
			for i in 10:
				var p := Vector2(lerpf(x_min, x_max, (i + 0.5) / 10.0), front + 1.0)
				if _inside(p + Vector2(0, 2)):
					draw_circle(p, sq * 0.035, Color(1.0, 0.55, 0.15, 0.55))
	for p in particles:
		var age: float = 1.0 - p["life"] / p["max"]
		var col: Color
		if age < 0.18:
			col = Color(1.0, 0.75, 0.3).lerp(Color(0.85, 0.3, 0.1), age / 0.18)
		else:
			col = Color(0.85, 0.3, 0.1).lerp(Color(0.42, 0.4, 0.4), clampf((age - 0.18) * 3.0, 0.0, 1.0))
		col.a = clampf(1.0 - age, 0.0, 1.0)
		var sz: float = p["size"]
		draw_rect(Rect2(p["p"] - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
