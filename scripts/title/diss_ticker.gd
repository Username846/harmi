class_name DissTicker
extends Control
## The title screen's diss track and its lyrics, scrolling across the top of
## the screen in time with the rapping. Tap the strip to mute or unmute.

const LYRICS := preload("res://scripts/title/diss_lyrics.gd")
const TRACK := preload("res://assets/audio/diss_track.ogg")
const STRIP_H := 40.0

var player: AudioStreamPlayer
var muted := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Tap to mute or unmute the diss track"
	player = AudioStreamPlayer.new()
	player.stream = TRACK
	player.volume_db = -2.0
	player.finished.connect(func(): player.play())
	add_child(player)
	player.play()


## Browsers only allow sound after a tap, so the title screen pokes us on its first one.
func wake() -> void:
	if not muted and not player.playing:
		player.play()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		muted = not muted
		if not muted and not player.playing:
			player.play()


func _process(delta: float) -> void:
	_t += delta
	# step aside while the Beyblade is spinning its own bassline
	var want_paused := muted or Music.spinning
	if player.stream_paused != want_paused:
		player.stream_paused = want_paused
	queue_redraw()


var _speed_cache := 0.0


## Fast enough that a line never runs into the next one.
func _speed(font: Font, fs: int) -> float:
	if _speed_cache > 0.0:
		return _speed_cache
	var lines: Array = LYRICS.LINES
	_speed_cache = 120.0
	for i in lines.size() - 1:
		var gap: float = float(lines[i + 1][0]) - float(lines[i][0])
		var tw := font.get_string_size(lines[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_speed_cache = maxf(_speed_cache, (tw + 60.0) / gap)
	return _speed_cache


func _text(font: Font, p: Vector2, text: String, fs: int) -> void:
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.GOLD)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, STRIP_H)), Color(0.02, 0.015, 0.02, 0.85))
	draw_line(Vector2(0, STRIP_H), Vector2(w, STRIP_H), UI.GOLD.darkened(0.4), 2.0)
	var fs := 21
	var label_w := 150.0 if w > 700.0 else 0.0
	var y := STRIP_H * 0.5 + fs * 0.36
	var notice := ""
	if muted:
		notice = "Diss track muted - tap here to bring it back"
	elif Music.spinning:
		notice = "The Beyblade has the floor. The diss track waits its turn."
	elif not player.playing or player.get_playback_position() < 0.05:
		notice = "Tap anywhere to drop the beat"
	if notice != "":
		var nw := font.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(font, Vector2(label_w + (w - label_w - nw) * 0.5, y), notice, fs)
	else:
		# one continuous ribbon: each line enters on the right the moment it's
		# rapped and drifts left at a steady pace
		var pos := player.get_playback_position()
		var speed := _speed(font, fs)
		for line in LYRICS.LINES:
			var x: float = w + (float(line[0]) - pos) * speed
			if x > w:
				break
			var tw := font.get_string_size(line[2], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if x + tw < label_w:
				continue
			_text(font, Vector2(x, y), line[2], fs)
	if label_w > 0.0:
		# a fixed "now playing" tag the lyrics slide under
		draw_rect(Rect2(Vector2.ZERO, Vector2(label_w, STRIP_H)), Color(0.12, 0.05, 0.05))
		var beat := 0.5 + 0.5 * absf(sin(player.get_playback_position() * PI * 1.5)) if player.playing and not player.stream_paused else 0.5
		draw_circle(Vector2(14, STRIP_H * 0.5), 5.0, UI.RED.lerp(Color(1, 0.6, 0.5), beat))
		draw_string(font, Vector2(26, 17), "NOW PLAYING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		draw_string(font, Vector2(26, 33), "Long Boy Diss", HORIZONTAL_ALIGNMENT_LEFT, label_w - 30.0, 14, UI.TEXT)
