class_name DissTicker
extends Control
## The title screen's diss track and its lyrics, scrolling across the top of
## the screen in time with the rapping. Tap the strip to mute or unmute.

const LYRICS := preload("res://scripts/title/diss_lyrics.gd")
const TRACK := preload("res://assets/audio/diss_track.ogg")
const STRIP_H := 64.0

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
	# mute by volume, never by pausing: the track keeps its place, so the lyrics stay in step
	var want_db := -80.0 if muted or Music.spinning else -2.0
	if player.volume_db != want_db:
		player.volume_db = want_db
	queue_redraw()


## One centred line, shrunk to fit if it's too long for the screen.
func _line(font: Font, text: String, cx: float, y: float, fs: int, room: float, alpha: float) -> void:
	if text == "":
		return
	var size_px := fs
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	if tw > room:
		size_px = maxi(11, int(fs * room / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var p := Vector2(cx - tw * 0.5, y)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0, 0, 0, 0.9 * alpha))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, alpha))


## Where the song is right now, as heard: the mixer's position plus the time
## since it last mixed, minus the delay before sound reaches the speakers.
func _pos() -> float:
	return maxf(0.0, player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())


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
	elif not player.playing or _pos() < 0.05:
		notice = "Tap anywhere to drop the beat"
	var cx := label_w + (w - label_w) * 0.5
	var room := w - label_w - 24.0
	if notice != "":
		_line(font, notice, cx, STRIP_H * 0.5 + 8.0, fs, room, 1.0)
	else:
		# two fixed lines: what's being rapped now, and what's coming next
		var pos := _pos()
		var lines: Array = LYRICS.LINES
		var cur := -1
		for i in lines.size():
			if float(lines[i][0]) <= pos:
				cur = i
			else:
				break
		var now_text: String = lines[cur][2] if cur >= 0 else ""
		var next_text: String = lines[cur + 1][2] if cur + 1 < lines.size() else ""
		if cur >= 0 and pos > float(lines[cur][1]) + 1.5 and next_text != "":
			now_text = ""  # an instrumental stretch: only the upcoming line shows
		_line(font, now_text, cx, 28.0, fs, room, 1.0)
		_line(font, next_text, cx, 54.0, 17, room, 0.42)
	if label_w > 0.0:
		# a fixed "now playing" tag the lyrics slide under
		draw_rect(Rect2(Vector2.ZERO, Vector2(label_w, STRIP_H)), Color(0.12, 0.05, 0.05))
		var beat := 0.5 + 0.5 * absf(sin(_pos() * PI * 1.5)) if player.playing and not muted else 0.5
		draw_circle(Vector2(14, STRIP_H * 0.5 - 4.0), 5.0, UI.RED.lerp(Color(1, 0.6, 0.5), beat))
		draw_string(font, Vector2(26, 27), "NOW PLAYING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		draw_string(font, Vector2(26, 45), "Long Boy Diss", HORIZONTAL_ALIGNMENT_LEFT, label_w - 30.0, 14, UI.TEXT)
