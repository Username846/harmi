class_name VirusOverlay
extends Control
## What the virus from that ad does to the whole game, laid over every screen:
## a faint green tint with scanlines, a quick glitch tear every few seconds,
## Wormy (the virus himself) crawling round the edges making remarks, and now
## and then a scam popup to close. Everything is brief or obviously Wormy's
## doing: the game never freezes or looks broken.

const LINES := [
	"hehe", "I live here now", "nice moves... NOT", "deleting your pawns... jk", "have you tried turning it off and on again",
	"I'm in your graveyard too", "this is my board now", "don't mind me", "mining crypto, brb", "wow you really clicked that ad",
	"your RAM tastes funny", "*munch munch*", "I sent your queen a friend request", "ctrl+alt+defeat", "antivirus? never heard of her",
	"0101 0101 hi", "I'm not a virus, I'm a feature", "who taught you chess", "boo", "that ad was legit btw",
]
const SCAMS := [
	["CONGRATULATIONS!!!", "You are the 1,000,000th visitor! Tap CLAIM for your FREE NeoPhone 17!", "CLAIM"],
	["WARNING", "Your device has (37) viruses! Tap CLEAN to download Totally Real Cleaner.", "CLEAN"],
	["Hot Singles", "Lonely bishops in your area want to move diagonally with you.", "CHAT"],
	["You won!", "Spin the wheel for a chance to win $5,000 in Gambit Goods & Gas gift cards!", "SPIN"],
	["System Alert", "Your Beyblade warranty is about to expire. Renew now?", "RENEW"],
	["Free RAM!!!", "Download 128 GB of RAM instantly. 100% free. No virus.", "DOWNLOAD"],
]

var t := 0.0
var _glitch_at := 3.0
var _glitch_t := -1.0
var _say := ""
var _say_t := 0.0
var _next_say := 2.0
var _next_popup := 25.0
var _popup: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	_say = "hiiii :)"
	_say_t = 3.0


func _process(delta: float) -> void:
	t += delta
	if _glitch_t >= 0.0:
		_glitch_t += delta
		if _glitch_t > 0.28:
			_glitch_t = -1.0
			_glitch_at = t + randf_range(4.0, 9.0)
	elif t >= _glitch_at:
		_glitch_t = 0.0
	_say_t = maxf(0.0, _say_t - delta)
	if t >= _next_say:
		_say = String(LINES[randi() % LINES.size()])
		_say_t = 3.2
		_next_say = t + randf_range(7.0, 13.0)
	if t >= _next_popup and _popup == null:
		_show_popup()
		_next_popup = t + randf_range(40.0, 70.0)
	queue_redraw()


## Where Wormy is: crawling a lap round the screen's edge, inset a little.
func worm_pos(k: float) -> Vector2:
	var m := 30.0
	var w := size.x - m * 2.0
	var h := size.y - m * 2.0
	var per := (w + h) * 2.0
	var d := fposmod(k * 55.0, per)
	if d < w:
		return Vector2(m + d, size.y - m)
	d -= w
	if d < h:
		return Vector2(size.x - m, size.y - m - d)
	d -= h
	if d < w:
		return Vector2(size.x - m - d, m)
	d -= w
	return Vector2(m, m + d)


func _draw() -> void:
	# a faint green cast, like a monitor that's seen things
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 1.0, 0.3, 0.035))
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.05), 1.0)
		y += 4.0
	if _glitch_t >= 0.0:
		for i in 7:
			var gy := randf() * size.y
			var gh := randf_range(4.0, 26.0)
			var col: Color = [Color(1.0, 0.1, 0.8, 0.22), Color(0.1, 1.0, 0.4, 0.22), Color(0.2, 0.6, 1.0, 0.2)][i % 3]
			draw_rect(Rect2(randf_range(-40.0, 40.0), gy, size.x, gh), col)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(randf() * size.x * 0.7, randf() * size.y), "0x%X" % randi(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 1.0, 0.4, 0.8))
	_draw_worm()


func _draw_worm() -> void:
	var head := worm_pos(t)
	var body := Color(0.35, 0.9, 0.35)
	for i in range(7, 0, -1):
		var p := worm_pos(t - i * 0.18)
		p += (p - head).orthogonal().normalized() * sin(t * 8.0 + i) * 3.0 if p != head else Vector2.ZERO
		draw_circle(p, 10.0 - i * 0.6, body.darkened(0.1 * (i % 2)))
	draw_circle(head, 12.0, body)
	var ahead := (worm_pos(t + 0.1) - head).normalized()
	var side := ahead.orthogonal()
	for s in [-1.0, 1.0]:
		var e: Vector2 = head + ahead * 4.0 + side * s * 5.0
		draw_circle(e, 4.0, Color(1, 1, 1))
		draw_circle(e + ahead * 1.5, 2.0, Color(0.05, 0.05, 0.05))
	# a tiny pirate bandana, because he's a bad guy
	draw_line(head - side * 11.0 - ahead * 3.0, head + side * 11.0 - ahead * 3.0, Color(0.9, 0.15, 0.2), 4.0)
	if _say_t > 0.0:
		var font := ThemeDB.fallback_font
		var fs := 15
		var w := font.get_string_size(_say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20.0
		var bp := head + Vector2(-w * 0.5, -48.0)
		bp.x = clampf(bp.x, 6.0, size.x - w - 6.0)
		bp.y = clampf(bp.y, 6.0, size.y - 36.0)
		var a := minf(1.0, _say_t * 3.0)
		CardArt.fill_rrect(self, Rect2(bp, Vector2(w, 28)), 10.0, Color(0.08, 0.15, 0.08, 0.92 * a))
		CardArt.line_rrect(self, Rect2(bp, Vector2(w, 28)), 10.0, Color(0.35, 0.9, 0.35, a), 2.0)
		draw_string(font, bp + Vector2(10, 19), _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.6, 1.0, 0.6, a))


## A scam window with an X. Its big button "works" about as well as you'd expect.
func _show_popup() -> void:
	var scam: Array = SCAMS[randi() % SCAMS.size()]
	var pop := Control.new()
	pop.mouse_filter = Control.MOUSE_FILTER_STOP
	var w := minf(380.0, size.x - 40.0)
	pop.size = Vector2(w, 170)
	pop.position = Vector2(randf_range(20.0, maxf(20.0, size.x - w - 20.0)), randf_range(60.0, maxf(60.0, size.y - 240.0)))
	var state := {"pressed": false}
	pop.draw.connect(func():
		var r := Rect2(Vector2.ZERO, pop.size)
		pop.draw_rect(r, Color(0.94, 0.94, 0.96))
		pop.draw_rect(Rect2(0, 0, r.size.x, 28), Color(0.85, 0.15, 0.2) if scam[0] != "CONGRATULATIONS!!!" else Color(0.95, 0.65, 0.1))
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
				pop.queue_free()
			elif Rect2(Vector2(pop.size.x * 0.5 - 60, pop.size.y - 44), Vector2(120, 34)).has_point(p):
				if state["pressed"]:
					pop.queue_free()
				else:
					state["pressed"] = true
					_say = "lol you clicked it"
					_say_t = 3.0
					pop.queue_redraw())
	add_child(pop)
	_popup = pop
