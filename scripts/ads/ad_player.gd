class_name AdPlayer
extends Control
## A full-screen fake mobile ad: a few seconds of "gameplay footage" with shouty
## captions, an install banner, then the end card. The close button only turns
## up when the countdown is done; closing it pays the reward. A cheerful,
## slightly annoying jingle loops underneath.
## setup(ad) before adding; emits finished(reward) and frees itself.

signal finished(reward: int)

const END_CARD := 2.2
const BANNER_H := 0.14 # of the shorter side
const TOP_H := 0.1

var ad: Dictionary = {}
var dur := 8.0
var reward := 5
var t := 0.0
var _toast := ""
var _toast_t := 0.0
var _player: AudioStreamPlayer
var _done := false


static func reward_for(a: Dictionary) -> int:
	return 2 + int(float(a.get("dur", 8)) * 0.5)


func setup(a: Dictionary) -> void:
	ad = a
	dur = clampf(float(a.get("dur", 8)), 5.0, 15.0)
	reward = reward_for(a)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	_player = AudioStreamPlayer.new()
	_player.stream = jingle(String(ad.get("name", "")).hash())
	_player.volume_db = -10.0
	_player.finished.connect(func(): if not _done: _player.play())
	add_child(_player)
	if DisplayServer.get_name() != "headless":
		_player.play()


func _process(delta: float) -> void:
	t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	queue_redraw()


func _unit() -> float:
	return minf(size.x, size.y)


func _close_rect() -> Rect2:
	var u := _unit()
	return Rect2(Vector2(size.x - u * 0.1, u * 0.012), Vector2(u * 0.076, u * 0.076))


func _cta_rect() -> Rect2:
	var u := _unit()
	if t >= dur - END_CARD:
		return Rect2(Vector2(size.x * 0.5 - u * 0.3, size.y * 0.5 + u * 0.24), Vector2(u * 0.6, u * 0.12))
	var bh := u * BANNER_H
	return Rect2(Vector2(size.x - u * 0.3, size.y - bh + bh * 0.2), Vector2(u * 0.26, bh * 0.6))


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var p: Vector2 = event.position
	if t >= dur and _close_rect().grow(12.0).has_point(p):
		_finish()
	elif _cta_rect().has_point(p):
		_toast = "This is a fake ad. There is nothing to install. There never was."
		_toast_t = 2.2


func _finish() -> void:
	if _done:
		return
	_done = true
	_player.stop()
	finished.emit(reward)
	queue_free()


# --- drawing ---------------------------------------------------------------------

func _draw() -> void:
	var u := _unit()
	var c: Array = ad.get("c", [Color(0.4, 0.6, 1.0), Color(1, 0.5, 0.3), Color(1, 0.9, 0.3)])
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0))
	var scenes: Array = ad.get("scenes", [["product", ""]])
	var play := dur - END_CARD
	if t < play:
		var per := play / scenes.size()
		var i := mini(int(t / per), scenes.size() - 1)
		var st := t - i * per
		# the clip sits between the chrome strip on top and the install banner below
		var area := Rect2(Vector2(0, u * TOP_H), size - Vector2(0, u * (BANNER_H + TOP_H)))
		AdScenes.draw(self, String(scenes[i][0]), area, st + i * 1.7, ad)
		if st < 0.12:
			draw_rect(area, Color(1, 1, 1, 0.8 * (1.0 - st / 0.12)))
		var caption := String(scenes[i][1])
		if caption != "":
			var s := AdScenes.pop(st, 0.15)
			var cy := area.end.y - u * 0.09
			draw_rect(Rect2(0, cy - u * 0.06, size.x, u * 0.12), Color(0, 0, 0, 0.35 * minf(1.0, s)))
			AdScenes.text(self, caption, Vector2(size.x * 0.5, cy), int(u * 0.07 * s), Color(1, 1, 1), 8, size.x * 0.92)
		_banner(u, c)
	else:
		_end_card(u, c)
	_chrome(u)
	if _toast_t > 0.0:
		var a := minf(1.0, _toast_t * 3.0)
		var tr := Rect2(Vector2(size.x * 0.5 - u * 0.45, size.y * 0.5 - u * 0.06), Vector2(u * 0.9, u * 0.12))
		AdScenes.box(self, tr, Color(0.1, 0.1, 0.12, 0.92 * a), 12)
		AdScenes.text(self, _toast, tr.get_center(), int(u * 0.032), Color(1, 1, 1, a), 0, tr.size.x - 20)


func _icon(r: Rect2, c: Array) -> void:
	AdScenes.box(self, r, c[0], r.size.x * 0.22)
	AdScenes.box(self, Rect2(r.position + r.size * 0.12, r.size * 0.76), c[0].lightened(0.15), r.size.x * 0.18)
	var name := String(ad.get("name", "?"))
	AdScenes.text(self, name.substr(0, 1), r.get_center(), int(r.size.y * 0.55), c[2], 5)


func _rating() -> float:
	return 4.1 + fposmod(float(String(ad.get("name", "")).hash()) * 0.0001, 0.85)


func _stars(p: Vector2, s: float, rating: float) -> void:
	for i in 5:
		var fill := clampf(rating - i, 0.0, 1.0)
		AdScenes.star(self, p + Vector2(i * s * 2.2, 0), s, Color(0.4, 0.4, 0.4))
		if fill > 0.0:
			AdScenes.star(self, p + Vector2(i * s * 2.2, 0), s * (0.6 + 0.4 * fill), Color(1.0, 0.8, 0.15))


func _banner(u: float, c: Array) -> void:
	var bh := u * BANNER_H
	var br := Rect2(Vector2(0, size.y - bh), Vector2(size.x, bh))
	draw_rect(br, Color(0.97, 0.97, 0.98))
	_icon(Rect2(br.position + Vector2(bh * 0.15, bh * 0.15), Vector2(bh * 0.7, bh * 0.7)), c)
	var font := ThemeDB.fallback_font
	var tx := br.position.x + bh
	var room := size.x - tx - u * 0.33
	var fs := int(bh * 0.24)
	draw_string(font, Vector2(tx, br.position.y + bh * 0.4), String(ad.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, room, fs, Color(0.1, 0.1, 0.12))
	draw_string(font, Vector2(tx, br.position.y + bh * 0.62), String(ad.get("dev", "")), HORIZONTAL_ALIGNMENT_LEFT, room, int(fs * 0.75), Color(0.45, 0.45, 0.5))
	_stars(Vector2(tx + bh * 0.08, br.position.y + bh * 0.8), bh * 0.07, _rating())
	var cta := _cta_rect()
	var pulse := 1.0 + 0.06 * sin(t * 7.0)
	var pr := Rect2(cta.get_center() - cta.size * 0.5 * pulse, cta.size * pulse)
	AdScenes.box(self, pr, Color(0.15, 0.6, 1.0) if c[2].get_luminance() > 0.85 else c[2].darkened(0.1), pr.size.y * 0.3)
	AdScenes.text(self, String(ad.get("cta", "INSTALL")), pr.get_center(), int(pr.size.y * 0.42), Color(1, 1, 1), 3, pr.size.x - 10)


func _end_card(u: float, c: Array) -> void:
	var k := t - (dur - END_CARD)
	AdScenes.sky(self, Rect2(Vector2.ZERO, size), c[0].darkened(0.35), c[0].darkened(0.75))
	for i in 12:
		var a := TAU * i / 12.0 + t * 0.3
		var cen := Vector2(size.x * 0.5, size.y * 0.5 - u * 0.15)
		draw_colored_polygon(PackedVector2Array([cen, cen + Vector2.from_angle(a) * u, cen + Vector2.from_angle(a + 0.2) * u]), Color(1, 1, 1, 0.05))
	var s := AdScenes.pop(k, 0.0)
	var ic := u * 0.26 * s
	_icon(Rect2(Vector2(size.x * 0.5 - ic * 0.5, size.y * 0.5 - u * 0.3 - ic * 0.5), Vector2(ic, ic)), c)
	AdScenes.text(self, String(ad.get("name", "")), Vector2(size.x * 0.5, size.y * 0.5 - u * 0.08), int(u * 0.075), Color(1, 1, 1), 6, size.x * 0.9)
	AdScenes.text(self, String(ad.get("tag", "")), Vector2(size.x * 0.5, size.y * 0.5 + u * 0.02), int(u * 0.04), Color(1, 1, 1, 0.85), 3, size.x * 0.9)
	var rating := _rating()
	_stars(Vector2(size.x * 0.5 - u * 0.11, size.y * 0.5 + u * 0.09), u * 0.025, rating)
	var downloads := 1 + int(fposmod(float(String(ad.get("name", "")).hash()) * 0.00037, 1.0) * 99)
	AdScenes.text(self, "%.1f   |   %dM+ downloads" % [rating, downloads], Vector2(size.x * 0.5, size.y * 0.5 + u * 0.15), int(u * 0.03), Color(1, 1, 1, 0.8), 0)
	var cta := _cta_rect()
	var pulse := 1.0 + 0.05 * sin(t * 6.0)
	var pr := Rect2(cta.get_center() - cta.size * 0.5 * pulse, cta.size * pulse)
	AdScenes.box(self, pr, Color(0.15, 0.75, 0.35), pr.size.y * 0.35)
	AdScenes.text(self, String(ad.get("cta", "INSTALL")), pr.get_center(), int(pr.size.y * 0.45), Color(1, 1, 1), 3, pr.size.x - 10)
	AdScenes.hand(self, pr.get_center() + Vector2(pr.size.x * 0.3, pr.size.y * 0.3) + Vector2(sin(t * 4.0), cos(t * 4.0)) * 6.0, u * 0.1, sin(t * 6.0) > 0.6)


## "Ad" in the corner, and the countdown that turns into a close button.
func _chrome(u: float) -> void:
	draw_rect(Rect2(0, 0, size.x, u * TOP_H), Color(0, 0, 0, 0.85 if t < dur - END_CARD else 0.3))
	var tag := Rect2(Vector2(u * 0.03, u * 0.03), Vector2(u * 0.09, u * 0.05))
	AdScenes.box(self, tag, Color(0.95, 0.75, 0.1), 6)
	AdScenes.text(self, "Ad", tag.get_center(), int(u * 0.03), Color(0.1, 0.1, 0.1), 0)
	var cr := _close_rect()
	var cen := cr.get_center()
	var rad := cr.size.x * 0.5
	draw_circle(cen, rad, Color(0, 0, 0, 0.55))
	if t < dur:
		var left := ceili(dur - t)
		draw_arc(cen, rad - 3, -PI / 2, -PI / 2 + TAU * (t / dur), 32, Color(1, 1, 1, 0.9), 4.0, true)
		AdScenes.text(self, str(left), cen, int(rad * 0.9), Color(1, 1, 1), 0)
		AdScenes.text(self, "Reward in %ds" % left, cen + Vector2(-u * 0.2, 0), int(u * 0.028), Color(1, 1, 1, 0.85), 3)
	else:
		var x := rad * 0.4
		draw_line(cen - Vector2(x, x), cen + Vector2(x, x), Color(1, 1, 1), 4.0, true)
		draw_line(cen - Vector2(x, -x), cen + Vector2(x, -x), Color(1, 1, 1), 4.0, true)
		AdScenes.text(self, "+$%d earned! Close to collect" % reward, cen + Vector2(-u * 0.3, 0), int(u * 0.03), Color(0.5, 1.0, 0.5), 4)


# --- the jingle ------------------------------------------------------------------------

## Two bars of relentlessly upbeat music, different for every ad.
static func jingle(seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rate := 22050
	var bpm := 112.0 + rng.randi_range(0, 5) * 8.0
	var step := 60.0 / bpm / 4.0
	var steps := 32
	var n := int(step * steps * rate)
	var root := 57 + rng.randi_range(0, 7)
	var scale := [0, 2, 4, 7, 9, 12, 14, 16]
	var notes: Array = []
	for i in steps:
		notes.append(-1 if rng.randf() < 0.25 else root + int(scale[rng.randi_range(0, scale.size() - 1)]))
	var bass := [root - 24, root - 24 + 5, root - 24 + 7, root - 24 + 5]
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var tt := float(i) / rate
		var si := int(tt / step)
		var st := tt - si * step
		var v := 0.0
		var m: int = notes[si % steps]
		if m >= 0:
			var f := 440.0 * pow(2.0, (m - 69) / 12.0)
			v += (1.0 if fposmod(tt * f, 1.0) < 0.5 else -1.0) * 0.16 * exp(-st * 18.0)
		var bm: int = bass[(si / 8) % 4]
		var bf := 440.0 * pow(2.0, (bm - 69) / 12.0)
		v += (absf(fposmod(tt * bf, 1.0) * 4.0 - 2.0) - 1.0) * 0.22
		if si % 4 == 0:
			v += sin(TAU * (50.0 + 120.0 * exp(-st * 30.0)) * st) * 0.5 * exp(-st * 14.0)
		elif si % 4 == 2:
			v += (randf() * 2.0 - 1.0) * 0.12 * exp(-st * 40.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
