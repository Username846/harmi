class_name SongTicker
extends Control
## The title screen's album: three songs played in turn, with the line being
## sung shown across the top of the screen and the next line faded beneath it.
## Tap the strip to mute or unmute, tap NEXT to skip to the next song.

const SONGS := [
	[preload("res://scripts/title/lyrics_diss.gd"), preload("res://assets/audio/songs/diss.ogg")],
	[preload("res://scripts/title/lyrics_epic.gd"), preload("res://assets/audio/songs/epic.ogg")],
	[preload("res://scripts/title/lyrics_bounce.gd"), preload("res://assets/audio/songs/bounce.ogg")],
]
const STRIP_H := 64.0
const NEXT_W := 70.0
## Lyrics switch this much earlier than the measured position (tuned by ear in the browser).
const LEAD := 1.0

var player: AudioStreamPlayer
var muted := false
var song := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Tap to mute or unmute; tap NEXT for the next song"
	player = AudioStreamPlayer.new()
	player.volume_db = -2.0
	player.finished.connect(func(): _play(song + 1))
	add_child(player)
	_play(0)


func _lyrics() -> GDScript:
	return SONGS[song][0]


func _play(i: int) -> void:
	song = posmod(i, SONGS.size())
	player.stream = SONGS[song][1]
	player.play()


## Browsers only allow sound after a tap, so the title screen pokes us on its first one.
func wake() -> void:
	if not muted and not player.playing:
		player.play()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.position.x >= size.x - NEXT_W:
			_play(song + 1)
			return
		muted = not muted
		if not muted and not player.playing:
			player.play()


func _process(_delta: float) -> void:
	# mute by volume, never by pausing: the song keeps its place, so the lyrics
	# stay in step. It also steps aside while the Beyblade spins its own bassline.
	var want_db := -80.0 if muted or Music.spinning else -2.0
	if player.volume_db != want_db:
		player.volume_db = want_db
	queue_redraw()


## Where the song is right now, as heard: the mixer's position plus the time
## since it last mixed, minus the delay before sound reaches the speakers.
func _pos() -> float:
	return maxf(0.0, player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())


## One centred line, shrunk to fit if it's too long for the screen.
func _line(font: Font, text: String, cx: float, y: float, fs: int, room: float, alpha: float, col: Color = UI.GOLD) -> void:
	if text == "":
		return
	var size_px := fs
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	if tw > room:
		size_px = maxi(11, int(fs * room / tw))
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var p := Vector2(cx - tw * 0.5, y)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, Color(0, 0, 0, 0.9 * alpha))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(col.r, col.g, col.b, alpha))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	var ly := _lyrics()
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, STRIP_H)), Color(0.02, 0.015, 0.02, 0.85))
	draw_line(Vector2(0, STRIP_H), Vector2(w, STRIP_H), UI.GOLD.darkened(0.4), 2.0)
	var fs := 21
	var label_w := 200.0 if w > 700.0 else 0.0
	var cx := label_w + (w - label_w - NEXT_W) * 0.5
	var room := w - label_w - NEXT_W - 20.0
	var notice := ""
	if muted:
		notice = "Music muted - tap here to bring it back"
	elif Music.spinning:
		notice = "The Beyblade has the floor. The album waits its turn."
	elif not player.playing or _pos() < 0.05:
		notice = "Tap anywhere to drop the beat"
	if notice != "":
		_line(font, notice, cx, STRIP_H * 0.5 + 8.0, fs, room, 1.0)
	else:
		# two fixed lines: what's being sung now, and what's coming next
		var pos := _pos() + LEAD
		var lines: Array = ly.LINES
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
		if cur < 0:
			# before the first line: say what's playing
			_line(font, "%s - %s" % [ly.TITLE, ly.ARTIST], cx, 28.0, 18, room, 0.9, UI.TEXT)
		else:
			_line(font, now_text, cx, 28.0, fs, room, 1.0)
		_line(font, next_text, cx, 54.0, 17, room, 0.42)
	if label_w > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(label_w, STRIP_H)), Color(0.12, 0.05, 0.05))
		var beat := 0.5 + 0.5 * absf(sin(_pos() * PI * 1.5)) if player.playing and not muted else 0.5
		draw_circle(Vector2(14, 15), 5.0, UI.RED.lerp(Color(1, 0.6, 0.5), beat))
		draw_string(font, Vector2(26, 20), "NOW PLAYING  %d/%d" % [song + 1, SONGS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		var tfs := 14
		while tfs > 9 and font.get_string_size(ly.TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x > label_w - 16.0:
			tfs -= 1
		draw_string(font, Vector2(10, 38), ly.TITLE, HORIZONTAL_ALIGNMENT_LEFT, label_w - 14.0, tfs, UI.TEXT)
		draw_string(font, Vector2(10, 55), ly.ARTIST, HORIZONTAL_ALIGNMENT_LEFT, label_w - 16.0, 13, UI.GOLD.darkened(0.15))
	# the NEXT button
	var nr := Rect2(Vector2(w - NEXT_W, 0), Vector2(NEXT_W, STRIP_H))
	draw_rect(nr, Color(0.12, 0.05, 0.05))
	draw_line(nr.position, Vector2(nr.position.x, STRIP_H), UI.GOLD.darkened(0.4), 2.0)
	var ac := nr.get_center() + Vector2(0, -8)
	for k in 2:
		var ox := (k - 0.5) * 12.0
		draw_colored_polygon(PackedVector2Array([ac + Vector2(ox - 6, -8), ac + Vector2(ox + 6, 0), ac + Vector2(ox - 6, 8)]), UI.GOLD)
	draw_string(font, Vector2(nr.position.x, 54), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, NEXT_W, 13, UI.DIM)
