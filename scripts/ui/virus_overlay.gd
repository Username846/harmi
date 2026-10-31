class_name VirusOverlay
extends Control
## The virus from that ad, laid over every screen: pixel space invaders that
## march back and forth across the game, firing little lasers, while the
## picture glitches and scam popups keep appearing. More invaders turn up as
## time goes on. When the board sends one on an errand (Game.virus_errand) it
## flies over and eats your money or zaps a piece. They never talk, and the
## game never freezes or looks broken: it's just infested.

const PIXEL := 4.0
## The classic crab, two frames of legs.
const FRAMES := [
	["..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.", "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."],
	["..X.....X..", "X..X...X..X", "X.XXXXXXX.X", "XXX.XXX.XXX", "XXXXXXXXXXX", ".XXXXXXXXX.", "..X.....X..", ".X.......X."],
]
const MAX_INVADERS := 5
const MAX_POPUPS := 3
const SCAMS := [
	["CONGRATULATIONS!!!", "You are the 1,000,000th visitor! Tap CLAIM for your FREE NeoPhone 17!", "CLAIM"],
	["WARNING", "Your device has (37) viruses! Tap CLEAN to download Totally Real Cleaner.", "CLEAN"],
	["Hot Singles", "Lonely bishops in your area want to move diagonally with you.", "CHAT"],
	["You won!", "Spin the wheel for a chance to win $5,000 in Gambit Goods & Gas gift cards!", "SPIN"],
	["System Alert", "Your Beyblade warranty is about to expire. Renew now?", "RENEW"],
	["Free RAM!!!", "Download 128 GB of RAM instantly. 100% free. No virus.", "DOWNLOAD"],
	["Update required", "A critical update is available for your chess pieces. Install now?", "UPDATE"],
	["Survey", "Answer 3 questions and win a lifetime supply of decorative gourds!", "START"],
]

var t := 0.0
var invaders: Array = [] # {p, dir, row_y, task, target, done, eat_t, col}
var zaps: Array = [] # {from, to, t}
var bits: Array = [] # coins and pixel debris {p, v, t, col, coin}
var floats: Array = [] # {text, p, t}
var _glitch_at := 2.0
var _glitch_t := -1.0
var _next_popup := 12.0
var _next_spawn := 60.0
var _next_zap := 3.0
var popups: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	Game.virus_errand.connect(_on_errand)
	_spawn()


func _exit_tree() -> void:
	if Game.virus_errand.is_connected(_on_errand):
		Game.virus_errand.disconnect(_on_errand)


func _spawn() -> void:
	var w := 11.0 * PIXEL
	var hue: Color = [Color(0.3, 1.0, 0.35), Color(1.0, 0.3, 0.75), Color(0.35, 0.8, 1.0), Color(1.0, 0.85, 0.2), Color(1.0, 0.45, 0.25)][invaders.size() % 5]
	invaders.append({"p": Vector2(randf_range(w, maxf(w * 2.0, size.x - w * 2.0)), randf_range(40.0, maxf(60.0, size.y * 0.4))),
		"dir": 1.0 if randf() < 0.5 else -1.0, "task": "", "target": Vector2.ZERO, "done": Callable(), "eat_t": 0.0, "col": hue})


func _on_errand(kind: String, target: Vector2, done: Callable) -> void:
	if invaders.is_empty():
		done.call()
		return
	# the nearest idle invader takes the job
	var best: Dictionary = {}
	for inv in invaders:
		if inv["task"] == "" and (best.is_empty() or Vector2(inv["p"]).distance_to(target) < Vector2(best["p"]).distance_to(target)):
			best = inv
	if best.is_empty():
		done.call()
		return
	best["task"] = kind
	best["target"] = get_global_transform().affine_inverse() * target
	best["done"] = done
	best["eat_t"] = 0.0


func _process(delta: float) -> void:
	t += delta
	if size.x < 50.0:
		return
	for inv in invaders:
		_move(inv, delta)
	if _glitch_t >= 0.0:
		_glitch_t += delta
		if _glitch_t > 0.32:
			_glitch_t = -1.0
			_glitch_at = t + randf_range(2.0, 5.0)
	elif t >= _glitch_at:
		_glitch_t = 0.0
	if t >= _next_zap:
		_next_zap = t + randf_range(2.0, 4.5)
		var inv: Dictionary = invaders[randi() % invaders.size()]
		if inv["task"] == "":
			var from: Vector2 = inv["p"] + Vector2(0, 5.0 * PIXEL)
			zaps.append({"from": from, "to": Vector2(from.x, minf(size.y - 10.0, from.y + randf_range(120.0, 360.0))), "t": 0.0})
	if t >= _next_spawn and invaders.size() < MAX_INVADERS:
		_spawn()
		_next_spawn = t + randf_range(50.0, 80.0)
	popups = popups.filter(func(p): return is_instance_valid(p))
	if t >= _next_popup:
		_next_popup = t + randf_range(15.0, 30.0)
		if popups.size() < MAX_POPUPS:
			_show_popup()
	for z in zaps:
		z["t"] += delta
		if z["t"] > 0.12 and not z.has("hit"):
			z["hit"] = true
			for i in 10:
				bits.append({"p": z["to"], "v": Vector2.from_angle(randf() * TAU) * randf_range(40.0, 140.0), "t": 0.0, "col": Color(0.4, 1.0, 0.4), "coin": false})
	zaps = zaps.filter(func(z): return z["t"] < 0.35)
	for b in bits:
		b["t"] += delta
		b["p"] += b["v"] * delta
		b["v"].y += 260.0 * delta
	bits = bits.filter(func(b): return b["t"] < 0.9)
	for f in floats:
		f["t"] += delta
		f["p"].y -= 40.0 * delta
	floats = floats.filter(func(f): return f["t"] < 1.4)
	queue_redraw()


func _move(inv: Dictionary, delta: float) -> void:
	var p: Vector2 = inv["p"]
	if inv["task"] == "":
		# march: sideways in little steps, down a row at each edge, back to the top at the bottom
		var step := 70.0 * delta
		p.x += step * float(inv["dir"])
		var half := 5.5 * PIXEL
		if p.x > size.x - half or p.x < half:
			inv["dir"] = -float(inv["dir"])
			p.x = clampf(p.x, half, size.x - half)
			p.y += 8.0 * PIXEL
			if p.y > size.y - 40.0:
				p.y = 40.0
		inv["p"] = p
		return
	var target: Vector2 = inv["target"]
	var d := target - p
	if d.length() > 6.0:
		inv["p"] = p + d.normalized() * minf(d.length(), 420.0 * delta)
		return
	inv["eat_t"] = float(inv["eat_t"]) + delta
	var et: float = inv["eat_t"]
	if inv["task"] == "eat" and fposmod(et, 0.25) < delta:
		bits.append({"p": p + Vector2(randf_range(-10, 10), 10), "v": Vector2(randf_range(-90, 90), randf_range(-160, -60)), "t": 0.0, "col": Color(1.0, 0.85, 0.25), "coin": true})
	if inv["task"] == "zap" and et < delta * 1.5:
		zaps.append({"from": p + Vector2(0, -60), "to": p, "t": 0.0})
	if et >= (1.3 if inv["task"] == "eat" else 0.5):
		var done: Callable = inv["done"]
		inv["task"] = ""
		inv["p"] = p + Vector2(0, -30)
		if done.is_valid():
			var r: Variant = done.call()
			if r is int and int(r) > 0:
				floats.append({"text": "-$%d" % int(r), "p": p + Vector2(0, -20), "t": 0.0})


func _draw() -> void:
	# a green cast and scanlines, like a monitor that's seen things
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 1.0, 0.3, 0.04))
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.06), 1.0)
		y += 4.0
	if _glitch_t >= 0.0:
		for i in 9:
			var gy := randf() * size.y
			var gh := randf_range(4.0, 30.0)
			var col: Color = [Color(1.0, 0.1, 0.8, 0.25), Color(0.1, 1.0, 0.4, 0.25), Color(0.2, 0.6, 1.0, 0.22)][i % 3]
			draw_rect(Rect2(randf_range(-50.0, 50.0), gy, size.x, gh), col)
		var font := ThemeDB.fallback_font
		for i in 3:
			draw_string(font, Vector2(randf() * size.x * 0.8, randf() * size.y), "0x%08X" % randi(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1.0, 0.4, 0.85))
	for z in zaps:
		var a: float = 1.0 - float(z["t"]) / 0.35
		var tip: Vector2 = Vector2(z["from"]).lerp(z["to"], minf(1.0, float(z["t"]) / 0.12))
		draw_line(z["from"], tip, Color(0.5, 1.0, 0.5, a), 3.0)
		draw_line(z["from"], tip, Color(1, 1, 1, a), 1.0)
	for b in bits:
		var ba: float = 1.0 - float(b["t"]) / 0.9
		if b["coin"]:
			draw_circle(b["p"], 5.0, Color(0.75, 0.55, 0.1, ba))
			draw_circle(b["p"], 3.5, Color(1.0, 0.85, 0.25, ba))
		else:
			draw_rect(Rect2(b["p"], Vector2(PIXEL, PIXEL)), Color(b["col"], ba))
	for inv in invaders:
		_draw_invader(inv)
	var font2 := ThemeDB.fallback_font
	for f in floats:
		var fa: float = 1.0 - float(f["t"]) / 1.4
		draw_string_outline(font2, f["p"], f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 4, Color(0, 0, 0, fa))
		draw_string(font2, f["p"], f["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.35, 0.3, fa))


func _draw_invader(inv: Dictionary) -> void:
	var eating: bool = inv["task"] == "eat" and float(inv["eat_t"]) > 0.0
	var frame: Array = FRAMES[int(t * (8.0 if eating else 2.5)) % 2]
	var px := PIXEL * (1.0 + 0.15 * absf(sin(t * 16.0)) if eating else 1.0)
	var col: Color = inv["col"]
	var origin: Vector2 = inv["p"] - Vector2(11, 8) * px * 0.5
	for ry in frame.size():
		var row: String = frame[ry]
		for rx in row.length():
			if row[rx] == "X":
				draw_rect(Rect2(origin + Vector2(rx, ry) * px, Vector2(px, px)), col)
	if eating:
		# a chomping mouth
		var mouth: Vector2 = Vector2(inv["p"]) + Vector2(0, px * 1.5)
		draw_rect(Rect2(mouth - Vector2(px * 1.5, px * 0.5 * absf(sin(t * 16.0)) + 1), Vector2(px * 3, px * absf(sin(t * 16.0)) + 2)), Color(0.05, 0.05, 0.05))


## A scam window. Its big button does nothing useful, and sometimes the X runs away.
func _show_popup() -> void:
	var scam: Array = SCAMS[randi() % SCAMS.size()]
	var pop := Control.new()
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	var w := minf(380.0, size.x - 40.0)
	pop.size = Vector2(w, 170)
	var place := func():
		pop.position = Vector2(randf_range(20.0, maxf(20.0, size.x - w - 20.0)), randf_range(60.0, maxf(60.0, size.y - 240.0)))
	place.call()
	var state := {"pressed": false, "dodges": 1 if randf() < 0.5 else 0}
	pop.draw.connect(func():
		var r := Rect2(Vector2.ZERO, pop.size)
		pop.draw_rect(r, Color(0.94, 0.94, 0.96))
		pop.draw_rect(Rect2(0, 0, r.size.x, 28), Color(0.85, 0.15, 0.2) if scam[2] != "CLAIM" else Color(0.95, 0.65, 0.1))
		pop.draw_rect(r, Color(0.2, 0.2, 0.25), false, 2.0)
		var font := ThemeDB.fallback_font
		pop.draw_string(font, Vector2(10, 20), String(scam[0]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 50, 15, Color(1, 1, 1))
		pop.draw_string(font, Vector2(r.size.x - 22, 20), "X", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))
		var body := "This offer has expired." if state["pressed"] else String(scam[1])
		pop.draw_multiline_string(font, Vector2(12, 52), body, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 24, 15, -1, Color(0.15, 0.15, 0.2))
		var b := Rect2(Vector2(r.size.x * 0.5 - 60, r.size.y - 44), Vector2(120, 34))
		pop.draw_rect(b, Color(0.2, 0.7, 0.3))
		pop.draw_string(font, b.position + Vector2(0, 23), String(scam[2]), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 16, Color(1, 1, 1)))
	pop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pop.accept_event()
			var p: Vector2 = ev.position
			if p.y < 30 and p.x > pop.size.x - 36:
				if int(state["dodges"]) > 0:
					state["dodges"] = int(state["dodges"]) - 1
					place.call() # the X dodged
				else:
					pop.queue_free()
			elif Rect2(Vector2(pop.size.x * 0.5 - 60, pop.size.y - 44), Vector2(120, 34)).has_point(p):
				if state["pressed"]:
					pop.queue_free()
				else:
					state["pressed"] = true
					pop.queue_redraw())
	add_child(pop)
	popups.append(pop)
