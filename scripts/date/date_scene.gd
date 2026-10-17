class_name DateScene
extends Control
## The framed "picture in a box" for a date: the venue, the date piece swaying
## across from you, speech bubbles, hearts / rain clouds / sweat drops, and a
## mood strip along the bottom. Tapping it emits `tapped` (a tap while a line
## is still typing out just finishes the line).

signal tapped

const TITLE_H := 30.0
const STRIP_H := 34.0
const INSET := 6.0
const BUBBLE_BG := Color(0.99, 0.96, 0.89)
const BUBBLE_LINE := Color(0.24, 0.17, 0.12)
const BUBBLE_TEXT := Color(0.15, 0.10, 0.08)
const YOU_BG := Color(0.86, 0.92, 0.99)
const TYPE_SPEED := 80.0

var title := ""
var venue := "park"
var piece_type := 1
var piece_white := true
var mood_shown := 50.0
var mood_target := 50.0
var bubble := ""
var bubble_chars := 0.0
var you_text := ""
var you_alpha := 0.0
var _you_hold := 0.0
var hearts: Array = []
var floaters: Array = []
var cloud_t := 0.0
var sweat_t := 0.0
var hop_t := -1.0
var sulk := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


# --- API -------------------------------------------------------------------------

func say(text: String) -> void:
	bubble = text
	bubble_chars = 0.0


func say_you(text: String) -> void:
	you_text = text
	you_alpha = 1.0
	_you_hold = 2.4


func is_typing() -> bool:
	return bubble_chars < float(bubble.length())


func finish_typing() -> void:
	bubble_chars = float(bubble.length())


## Shows how a reply landed: +2 lots of hearts and a hop, +1 a few hearts,
## anything else a little rain cloud.
func react(score: int) -> void:
	if score >= 2:
		love(12)
		hop()
	elif score == 1:
		love(5)
	else:
		rain()


func love(n: int) -> void:
	var hp := head_pos()
	var s := piece_scale()
	for i in n:
		hearts.append({"p": hp + Vector2(randf_range(-0.32, 0.32) * s, randf_range(-0.05, 0.3) * s),
			"v": Vector2(randf_range(-20, 20), randf_range(-75, -40)), "t": -i * 0.07,
			"life": randf_range(1.3, 2.1), "sz": randf_range(7.0, 14.0) * clampf(s / 170.0, 0.75, 1.4), "ph": randf() * TAU})


func hop() -> void:
	hop_t = 0.0


func rain() -> void:
	cloud_t = 3.0
	sulk = 1.0


func worry() -> void:
	sweat_t = 2.4


func float_text(text: String, color: Color) -> void:
	# bottom-left, rising from the mood strip (your reply bubble sits bottom-right)
	var fr := frame_rect()
	floaters.append({"text": text, "p": Vector2(fr.position.x + 48.0, fr.end.y - STRIP_H - 8.0), "c": color, "t": 0.0})


# --- geometry --------------------------------------------------------------------

func frame_rect() -> Rect2:
	return Rect2(Vector2(INSET, INSET), size - Vector2(INSET, INSET) * 2.0)


func pic_rect() -> Rect2:
	var fr := frame_rect()
	return Rect2(fr.position + Vector2(0, TITLE_H), Vector2(fr.size.x, maxf(10.0, fr.size.y - TITLE_H - STRIP_H)))


func piece_scale() -> float:
	var r := pic_rect()
	var h := PieceArt.height(piece_type)
	# small pieces are drawn a little larger so a pawn is still a presence
	var boost := lerpf(1.0, 1.3, clampf((1.78 - h) / 0.85, 0.0, 1.0))
	return minf(r.size.y * 0.40, r.size.x * 0.34) * boost


func _gloom() -> float:
	return clampf((45.0 - mood_shown) / 45.0, 0.0, 1.0)


func piece_base() -> Vector2:
	var b := DateVenueArt.piece_spot(venue, pic_rect(), _t)
	if hop_t >= 0.0:
		b.y -= absf(sin(hop_t * PI * 2.5)) * piece_scale() * 0.09 * (1.0 - hop_t)
	return b


func head_pos() -> Vector2:
	return piece_base() - Vector2(0, PieceArt.height(piece_type) * piece_scale() * 0.95)


# --- update ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	mood_shown = move_toward(mood_shown, mood_target, delta * 24.0)
	if bubble_chars < float(bubble.length()):
		bubble_chars = minf(float(bubble.length()), bubble_chars + delta * TYPE_SPEED)
	if _you_hold > 0.0:
		_you_hold -= delta
	else:
		you_alpha = move_toward(you_alpha, 0.0, delta * 2.0)
	cloud_t = maxf(0.0, cloud_t - delta)
	sweat_t = maxf(0.0, sweat_t - delta)
	sulk = move_toward(sulk, 0.0, delta * 0.3)
	if hop_t >= 0.0:
		hop_t += delta
		if hop_t >= 1.0:
			hop_t = -1.0
	for h in hearts:
		h["t"] += delta
		if h["t"] > 0.0:
			h["p"] += h["v"] * delta
			h["p"].x += sin(_t * 3.0 + h["ph"]) * 0.6
	hearts = hearts.filter(func(h): return h["t"] < h["life"])
	for f in floaters:
		f["t"] += delta
		f["p"] += Vector2(0, -30.0) * delta
	floaters = floaters.filter(func(f): return f["t"] < 1.6)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if is_typing():
			finish_typing()
		else:
			tapped.emit()


# --- drawing ---------------------------------------------------------------------

func _draw() -> void:
	var fr := frame_rect()
	if fr.size.x < 40.0 or fr.size.y < TITLE_H + STRIP_H + 20.0:
		return
	UI.draw_frame(self, fr, title, TITLE_H)
	var r := pic_rect()
	DateVenueArt.draw_back(self, venue, r, _t)
	_draw_piece()
	DateVenueArt.draw_front(self, venue, r, _t)
	_draw_effects()
	_vignette(r)
	if bubble != "":
		_draw_bubble(r)
	if you_alpha > 0.01 and you_text != "":
		_draw_you(r)
	# frame edges over anything that strayed, then the bars
	draw_rect(fr.grow(5), Color(0.03, 0.025, 0.03), false, 2.0)
	draw_rect(fr.grow(3), Color(0.42, 0.33, 0.24), false, 2.0)
	draw_rect(fr.grow(1), Color(0.20, 0.155, 0.12), false, 2.0)
	UI.draw_title_bar(self, fr, title, TITLE_H)
	_draw_strip(fr)
	_draw_floaters()


func _draw_piece() -> void:
	var s := piece_scale()
	var base := piece_base()
	var g := _gloom()
	var speed := lerpf(1.3, 0.8, g)
	var rot := sin(_t * speed) * lerpf(0.03, 0.018, g) + g * 0.06 + sulk * 0.09 + DateVenueArt.piece_tilt(venue, _t)
	var sy := 1.0 - 0.035 * g - 0.05 * sulk + 0.012 * sin(_t * 2.6)
	if hop_t >= 0.0:
		sy += 0.05 * sin(hop_t * PI * 5.0) * (1.0 - hop_t)
	draw_set_transform(base, rot, Vector2(1.0 / sqrt(sy), sy))
	PieceArt.draw_piece(self, piece_type, piece_white, 0.0, 0.0, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_effects() -> void:
	var s := piece_scale()
	var head := head_pos()
	var r := pic_rect()
	if cloud_t > 0.0:
		var a := clampf(cloud_t / 0.6, 0.0, 1.0) * clampf((3.0 - cloud_t) / 0.3, 0.0, 1.0)
		var cc := Vector2(head.x, maxf(head.y - s * 0.28, r.position.y + s * 0.14))
		_draw_cloud(cc, s * 0.32, a)
	if sweat_t > 0.0:
		var a2 := clampf(sweat_t / 0.5, 0.0, 1.0)
		var slide := (2.4 - sweat_t) * s * 0.04
		_draw_sweat(head + Vector2(s * 0.2, s * 0.12 + slide), s * 0.05, a2)
	for h in hearts:
		if h["t"] < 0.0:
			continue
		var k: float = h["t"] / h["life"]
		var a3 := 1.0 - clampf((k - 0.6) / 0.4, 0.0, 1.0)
		var grow := clampf(h["t"] / 0.2, 0.3, 1.0)
		_heart(h["p"], h["sz"] * grow, Color(0.95, 0.25, 0.42, a3), Color(0.55, 0.05, 0.18, a3))


func _heart(c: Vector2, sz: float, col: Color, line: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var x := 16.0 * pow(sin(a), 3)
		var y := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(c + Vector2(x, y) * sz / 16.0)
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, 1.5, true)
	draw_circle(c + Vector2(-0.45, -0.35) * sz, sz * 0.18, Color(1, 1, 1, col.a * 0.6))


func _draw_cloud(c: Vector2, w: float, a: float) -> void:
	var dark := Color(0.36, 0.38, 0.45, a)
	var light := Color(0.55, 0.57, 0.64, a)
	for o in [Vector2(-0.38, 0.06), Vector2(0.36, 0.06), Vector2(0.0, 0.1)]:
		draw_circle(c + o * w, w * 0.3, dark)
	for o2 in [Vector2(-0.2, -0.08), Vector2(0.15, -0.16), Vector2(0.42, -0.02), Vector2(-0.45, -0.02)]:
		draw_circle(c + o2 * w, w * 0.3, light)
	for i in 5:
		var x := c.x + (i - 2) * w * 0.2
		var ph := fposmod(_t * 2.4 + i * 0.37, 1.0)
		var y0 := c.y + w * 0.3 + ph * w * 0.7
		draw_line(Vector2(x, y0), Vector2(x - 2.0, y0 + w * 0.13), Color(0.55, 0.72, 1.0, a * (1.0 - ph * 0.6)), 2.0)


func _draw_sweat(c: Vector2, rad: float, a: float) -> void:
	var col := Color(0.6, 0.85, 1.0, a)
	draw_circle(c, rad, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-rad * 0.95, -rad * 0.3), c + Vector2(rad * 0.95, -rad * 0.3), c + Vector2(0, -rad * 2.3)]), col)
	draw_circle(c + Vector2(-rad * 0.35, -rad * 0.1), rad * 0.3, Color(1, 1, 1, a * 0.8))


func _vignette(r: Rect2) -> void:
	# soft dark edges: four gradient trapezoids fading inward
	var d := minf(r.size.x, r.size.y) * 0.12
	var dark := Color(0, 0, 0, 0.3)
	var clear := Color(0, 0, 0, 0)
	var cols := PackedColorArray([dark, dark, clear, clear])
	var o := r.position
	var e := r.end
	var i0 := o + Vector2(d, d)
	var i1 := e - Vector2(d, d)
	draw_polygon(PackedVector2Array([o, Vector2(e.x, o.y), Vector2(i1.x, i0.y), i0]), cols)
	draw_polygon(PackedVector2Array([e, Vector2(o.x, e.y), Vector2(i0.x, i1.y), i1]), cols)
	draw_polygon(PackedVector2Array([Vector2(o.x, e.y), o, i0, Vector2(i0.x, i1.y)]), cols)
	draw_polygon(PackedVector2Array([Vector2(e.x, o.y), e, i1, Vector2(i1.x, i0.y)]), cols)


## Word-wraps `text` to lines no wider than `width`.
static func wrap_lines(font: Font, text: String, fs: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		var trial: String = word if line == "" else line + " " + word
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


func _draw_text_lines(lines: PackedStringArray, pos: Vector2, fs: int, col: Color, visible: int) -> void:
	var font := ThemeDB.fallback_font
	var lh := font.get_height(fs) + 2.0
	var asc := font.get_ascent(fs)
	var left := visible
	for i in lines.size():
		if left <= 0:
			break
		var ln: String = lines[i]
		draw_string(font, pos + Vector2(0, asc + i * lh), ln.substr(0, left), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		left -= ln.length() + 1


func _bubble_box(rect: Rect2, bg: Color, line: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


func _draw_bubble(r: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var s := piece_scale()
	var base := piece_base()
	var head := head_pos()
	var pad := 12.0
	var left := base.x + s * 0.34 + 14.0
	var right := r.end.x - 12.0
	if right - left < 210.0:
		left = r.position.x + 12.0
	var bw := right - left
	var fs := 18
	var lines := wrap_lines(font, bubble, fs, bw - pad * 2.0)
	var lh := font.get_height(fs) + 2.0
	var max_h := r.size.y * 0.62
	while fs > 15 and lines.size() * lh + pad * 2.0 > max_h:
		fs -= 1
		lines = wrap_lines(font, bubble, fs, bw - pad * 2.0)
		lh = font.get_height(fs) + 2.0
	# shrink the bubble to the text when it's a short line
	var widest := 0.0
	for ln in lines:
		widest = maxf(widest, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	bw = minf(bw, widest + pad * 2.0 + 4.0)
	var bh := lines.size() * lh + pad * 2.0
	var rect := Rect2(left, r.position.y + 12.0, bw, bh)
	# tail toward the date's head
	var anchor := Vector2(rect.position.x + 2.0, rect.position.y + minf(bh * 0.7, bh - 18.0))
	var tip := head + Vector2(s * 0.12, s * 0.12)
	if left <= r.position.x + 12.5:
		anchor = Vector2(clampf(head.x + s * 0.3, rect.position.x + 20.0, rect.end.x - 20.0), rect.end.y - 2.0)
	var dir := tip - anchor
	tip = anchor + dir.limit_length(minf(70.0, dir.length()))
	var side := dir.orthogonal().normalized() * 9.0
	var tail := PackedVector2Array([anchor + side, tip, anchor - side])
	draw_colored_polygon(PackedVector2Array([anchor + side * 1.25, tip + dir.normalized() * 2.0, anchor - side * 1.25]), BUBBLE_LINE)
	_bubble_box(rect, BUBBLE_BG, BUBBLE_LINE)
	draw_colored_polygon(tail, BUBBLE_BG)
	_draw_text_lines(lines, rect.position + Vector2(pad, pad), fs, BUBBLE_TEXT, int(bubble_chars))


func _draw_you(r: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var pad := 10.0
	var fs := 16
	var bw := minf(r.size.x * 0.66, 400.0)
	var lines := wrap_lines(font, you_text, fs, bw - pad * 2.0)
	var widest := 0.0
	for ln in lines:
		widest = maxf(widest, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	bw = minf(bw, widest + pad * 2.0 + 4.0)
	var lh := font.get_height(fs) + 2.0
	var bh := lines.size() * lh + pad * 2.0
	var rect := Rect2(r.end.x - bw - 14.0, r.end.y - bh - 16.0, bw, bh)
	var a := you_alpha
	var tip := Vector2(rect.end.x - 26.0, r.end.y - 1.0)
	var tail := PackedVector2Array([Vector2(rect.end.x - 48.0, rect.end.y - 2.0), tip, Vector2(rect.end.x - 30.0, rect.end.y - 2.0)])
	_bubble_box(rect, Color(YOU_BG, a), Color(0.2, 0.28, 0.42, a))
	draw_colored_polygon(tail, Color(YOU_BG, a))
	draw_line(tail[0], tail[1], Color(0.2, 0.28, 0.42, a), 2.0)
	draw_line(tail[1], tail[2], Color(0.2, 0.28, 0.42, a), 2.0)
	_draw_text_lines(lines, rect.position + Vector2(pad, pad), fs, Color(0.1, 0.14, 0.24, a), 100000)


func _draw_strip(fr: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var sr := Rect2(fr.position.x, fr.end.y - STRIP_H, fr.size.x, STRIP_H)
	draw_rect(sr, Color(0.84, 0.78, 0.66))
	draw_line(sr.position, Vector2(sr.end.x, sr.position.y), Color(0.42, 0.33, 0.24), 2.0)
	var m := mood_shown
	var dark := Color(0.28, 0.2, 0.14)
	draw_string(font, Vector2(sr.position.x + 10.0, sr.position.y + 23.0), "MOOD", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, dark)
	var mood_txt := "%s %d" % [Game.mood_name(m), int(round(m))]
	var nw := font.get_string_size(mood_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var bx := sr.position.x + 64.0
	var bar := Rect2(bx, sr.position.y + 10.0, maxf(30.0, sr.end.x - bx - nw - 26.0), 15.0)
	draw_rect(bar, Color(0.2, 0.15, 0.13))
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(m / 100.0, 0.0, 1.0), bar.size.y))
	draw_rect(fill, Game.mood_color(m))
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.4)), Color(1, 1, 1, 0.22))
	for th in [25.0, 45.0, 65.0, 85.0]:
		var tx: float = bar.position.x + bar.size.x * th / 100.0
		draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.end.y), Color(0, 0, 0, 0.35), 1.0)
	draw_rect(bar, Color(0.15, 0.1, 0.08), false, 1.5)
	_heart(Vector2(fill.end.x, bar.get_center().y), 6.5, Color(0.95, 0.3, 0.45), Color(0.4, 0.05, 0.12))
	draw_string(font, Vector2(bar.end.x + 14.0, sr.position.y + 24.0), mood_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Game.mood_color(m).darkened(0.55))


func _draw_floaters() -> void:
	var font := ThemeDB.fallback_font
	for f in floaters:
		var a := 1.0 - clampf((f["t"] - 0.9) / 0.7, 0.0, 1.0)
		var fs := 24
		var txt: String = f["text"]
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = f["p"] - Vector2(tw * 0.5, 0)
		var c: Color = f["c"]
		draw_string_outline(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, a * 0.8))
		draw_string(font, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(c, a))
