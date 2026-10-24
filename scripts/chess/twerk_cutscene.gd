class_name TwerkCutscene
extends Control
## After every capture she makes, the queen climbs onto her victim's fresh grave
## and twerks on it to her own song. Tap to skip. Emits `finished` and frees itself.

signal finished

const SONG := preload("res://assets/audio/songs/bounce.ogg")
const LYRICS := preload("res://scripts/title/lyrics_bounce.gd")
## Where in "Back Rank Bounce" the cutscene picks up: just before "My tushy is so cushy".
const START := 14.0
const LENGTH := 7.6
const FADE := 0.35

var queen_white := true
var victim_type := 1
var victim_white := false
var _t := 0.0
var _done := false
var _player: AudioStreamPlayer
var _stars: Array = []
var _sparkles: Array = []


func setup(info: Dictionary) -> void:
	queen_white = bool(info.get("queen_white", true))
	victim_type = int(info.get("victim_type", 1))
	victim_white = bool(info.get("victim_white", false))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var rng := RandomNumberGenerator.new()
	for i in 60:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.55, rng.randf_range(0.5, 1.6)))
	for i in 26:
		_sparkles.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))
	_player = AudioStreamPlayer.new()
	_player.stream = SONG
	_player.volume_db = -3.0
	add_child(_player)
	_player.play(START)


func _process(delta: float) -> void:
	_t += delta
	var left := LENGTH - _t
	if left < 0.6 and _player.playing:
		_player.volume_db = lerpf(-40.0, -3.0, clampf(left / 0.6, 0.0, 1.0))
	if _t >= LENGTH:
		_finish()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _t > 0.8 and _t < LENGTH - FADE:
			_t = LENGTH - FADE


func _finish() -> void:
	if _done:
		return
	_done = true
	_player.stop()
	finished.emit()
	queue_free()


func _alpha() -> float:
	return clampf(_t / FADE, 0.0, 1.0) * clampf((LENGTH - _t) / FADE, 0.0, 1.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var a := _alpha()
	var font := ThemeDB.fallback_font
	var fade := Color(1, 1, 1, a)
	# night sky
	var top := Color(0.07, 0.03, 0.12)
	var bottom := Color(0.25, 0.07, 0.22)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top * fade, top * fade, bottom * fade, bottom * fade]))
	for st in _stars:
		var tw := 0.5 + 0.5 * sin(_t * 3.0 * st.z + st.x * 40.0)
		draw_circle(Vector2(st.x * w, st.y * h), st.z, Color(1, 0.95, 0.9, (0.3 + 0.6 * tw) * a))
	var u := minf(w, h)
	draw_circle(Vector2(w * 0.82, h * 0.16), u * 0.07, Color(1.0, 0.93, 0.8, 0.9 * a))
	draw_circle(Vector2(w * 0.80, h * 0.15), u * 0.065, Color(0.07, 0.03, 0.12, 0.25 * a))
	# disco spotlights sweeping the graveyard
	var ground := h * 0.78
	var cx := w * 0.5
	for k in 3:
		var sweep := sin(_t * (1.3 + k * 0.4) + k * 2.0) * w * 0.35
		var col: Color = [Color(1.0, 0.3, 0.7), Color(0.4, 0.6, 1.0), Color(1.0, 0.85, 0.3)][k]
		var src := Vector2(w * (0.2 + k * 0.3), -10.0)
		var tip := Vector2(cx + sweep, ground)
		draw_colored_polygon(PackedVector2Array([src, tip + Vector2(-u * 0.13, 0), tip + Vector2(u * 0.13, 0)]), Color(col.r, col.g, col.b, 0.13 * a))
	# the hill, other graves, the ground
	draw_rect(Rect2(0, ground, w, h - ground), Color(0.09, 0.07, 0.07, a))
	draw_colored_polygon(_arc(Vector2(cx, ground + u * 0.02), u * 0.36, u * 0.09), Color(0.16, 0.11, 0.09, a))
	for gx in [0.1, 0.24, 0.76, 0.9]:
		var gp := Vector2(w * gx, ground)
		draw_rect(Rect2(gp + Vector2(-u * 0.035, -u * 0.09), Vector2(u * 0.07, u * 0.09)), Color(0.28, 0.27, 0.3, a))
		draw_circle(gp + Vector2(0, -u * 0.09), u * 0.035, Color(0.28, 0.27, 0.3, a))
	# the victim's headstone behind the fresh mound
	var hs := Vector2(cx - u * 0.16, ground - u * 0.02)
	var hw := u * 0.15
	var hh := u * 0.2
	draw_rect(Rect2(hs + Vector2(-hw * 0.5, -hh), Vector2(hw, hh)), Color(0.45, 0.43, 0.46, a))
	draw_circle(hs + Vector2(0, -hh), hw * 0.5, Color(0.45, 0.43, 0.46, a))
	draw_string(font, hs + Vector2(-hw * 0.5, -hh * 0.98), "R.I.P.", HORIZONTAL_ALIGNMENT_CENTER, hw, maxi(9, int(u * 0.03)), Color(0.15, 0.13, 0.15, a))
	PieceArt.draw_piece(self, victim_type, victim_white, hs.x, hs.y - hh * 0.12, hh * 0.42, Color(1, 1, 1, 0.55 * a), false)
	draw_colored_polygon(_arc(Vector2(cx, ground + u * 0.005), u * 0.2, u * 0.05), Color(0.3, 0.19, 0.12, a))
	# Queen Cushy, back to us, twerking on the mound
	var beat := _t * 2.0 * PI * 2.1
	var jiggle := sin(beat)
	var dip := absf(sin(beat * 0.5))
	var qs := u * 0.38
	var qb := Vector2(cx + sin(_t * 2.0) * u * 0.015, ground - u * 0.01)
	draw_set_transform(qb, sin(beat * 0.5) * 0.05, Vector2(1.0 + 0.04 * dip, 1.0 - 0.07 * dip))
	PieceArt.draw_curvy_queen(self, queen_white, 0.0, 0.0, qs, true, jiggle, 0.03 * sin(beat * 0.5), fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# motion lines beside the booty
	for k in [-1.0, 1.0]:
		for i in 3:
			var y: float = qb.y - qs * (0.38 + i * 0.07)
			var x0: float = qb.x + k * qs * (0.3 + 0.03 * jiggle)
			draw_line(Vector2(x0, y), Vector2(x0 + k * qs * 0.1, y - qs * 0.02), Color(1, 0.9, 0.6, 0.7 * a * absf(jiggle)), 2.0)
	for sp in _sparkles:
		var p := Vector2(fposmod(sp.x * w + sin(_t + sp.z) * 20.0, w), fposmod(sp.y * h - _t * 40.0, h * 0.8))
		var tw2 := 0.5 + 0.5 * sin(_t * 6.0 + sp.z)
		draw_circle(p, 1.5 + tw2 * 2.0, Color(1.0, 0.6, 0.85, 0.6 * tw2 * a))
	# title and caption
	var fs := maxi(16, int(u * 0.055))
	var title := "VICTORY TWERK"
	_text(font, title, Vector2(0, h * 0.1), w, fs + 6, Color(1.0, 0.45, 0.75, a))
	var who := "The %s Queen bounces on the %s %s's grave" % ["White" if queen_white else "Black", "White" if victim_white else "Black", Game.PIECE_NAMES[victim_type]]
	_text(font, who, Vector2(0, h * 0.1 + fs * 1.4), w, maxi(13, int(fs * 0.62)), Color(1, 0.92, 0.8, a))
	var line := _lyric(_t + START)
	if line != "":
		draw_rect(Rect2(0, h - fs * 2.4, w, fs * 2.0), Color(0, 0, 0, 0.55 * a))
		_text(font, line, Vector2(0, h - fs * 1.05), w, fs, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, a))
	if _t > 0.8:
		draw_string(font, Vector2(w - 110, 26), "Tap to skip", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5 * a))


## A centred line, shrunk to fit the width.
func _text(font: Font, text: String, pos: Vector2, w: float, fs: int, col: Color) -> void:
	var size_px := fs
	while size_px > 10 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > w - 24.0:
		size_px -= 1
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size_px, 5, Color(0, 0, 0, 0.85 * col.a))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, size_px, col)


func _lyric(pos: float) -> String:
	var out := ""
	for l in LYRICS.LINES:
		if float(l[0]) - 0.3 <= pos:
			out = String(l[2]) if pos < float(l[1]) + 0.6 else ""
		else:
			break
	return out


func _arc(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts
