class_name ShadowArt
extends RefCounted
## Procedural pieces of the Shadow Realm, shared by the "for reals" card duel
## and the game-over screen: a swirling void, drifting mist, grasping tendrils,
## a lost soul's silhouette and a looping drone made from sine waves.

const VOID := Color(0.035, 0.02, 0.06)
const PURPLE := Color(0.52, 0.2, 0.78)
const GREEN := Color(0.3, 0.95, 0.55)

static var _drones: Dictionary = {}


## A spiral vortex centred on c. alpha fades the whole thing; `green` mixes the
## sickly green of the deep realm into the purple arms.
static func vortex(ci: CanvasItem, c: Vector2, r: float, t: float, alpha: float = 1.0, green: float = 0.5, arms: int = 6) -> void:
	if r < 2.0 or alpha <= 0.0:
		return
	for i in 7:
		var k := 1.0 - i / 7.0
		ci.draw_circle(c, r * k, Color(VOID, 0.16 * alpha))
	for a in arms:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var base := TAU * a / arms + t * 0.9
		var n := 34
		for j in n:
			var u := float(j) / (n - 1)
			var rr := r * (0.06 + 0.94 * u)
			var ang := base + (1.0 - u) * 4.2 + sin(t * 1.3 + a) * 0.08
			pts.append(c + Vector2(cos(ang), sin(ang) * 0.86) * rr)
			var col := PURPLE.lerp(GREEN, green * (1.0 - u) + 0.15 * sin(t + a))
			col.a = alpha * 0.55 * sin(u * PI)
			cols.append(col)
		ci.draw_polyline_colors(pts, cols, maxf(1.5, r * 0.035), true)
	# the eye of it: black, with a thin green rim
	ci.draw_circle(c, r * 0.13, Color(0, 0, 0, alpha))
	ci.draw_arc(c, r * 0.14, 0.0, TAU, 28, Color(GREEN, 0.35 * alpha * (0.7 + 0.3 * sin(t * 3.0))), maxf(1.0, r * 0.012), true)


## Slow soft fog in a band of rect (y0..y1 are fractions of its height).
static func mist(ci: CanvasItem, rect: Rect2, t: float, col: Color, n: int = 9, y0: float = 0.55, y1: float = 1.0) -> void:
	for i in n:
		var sp := 6.0 + (i % 4) * 3.0
		var w := rect.size.x * (0.22 + 0.06 * (i % 3))
		var x := rect.position.x + fmod(t * sp + i * rect.size.x * 0.37, rect.size.x + w * 2.0) - w
		var y := rect.position.y + rect.size.y * lerpf(y0, y1, fmod(i * 0.618, 1.0))
		for k in 3:
			var rr := w * (0.5 - k * 0.12)
			var p := Vector2(x + k * w * 0.18, y + sin(t * 0.4 + i) * 6.0)
			ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.32))
			ci.draw_circle(Vector2.ZERO, rr, Color(col, col.a * (0.5 + k * 0.25)))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A wobbling shadow tendril from `from` toward `to` (k = how far it has reached, 0..1).
static func tendril(ci: CanvasItem, from: Vector2, to: Vector2, t: float, w: float, col: Color, k: float = 1.0, seed_f: float = 0.0) -> void:
	var pts := PackedVector2Array()
	var n := 16
	var d := to - from
	var nrm := Vector2(-d.y, d.x).normalized()
	for j in n:
		var u := float(j) / (n - 1) * clampf(k, 0.0, 1.0)
		var wob := sin(u * 7.0 + t * 3.0 + seed_f) * d.length() * 0.06 * u
		pts.append(from + d * u + nrm * wob)
	if pts.size() < 2:
		return
	# a faint violet glow, then the dark core tapering from thick to thin
	for j in n - 1:
		var ug := float(j) / (n - 1)
		ci.draw_line(pts[j], pts[j + 1], Color(0.5, 0.22, 0.7, col.a * 0.35), maxf(2.0, w * 1.7 * (1.0 - ug * 0.85)), true)
	for j in n - 1:
		var u2 := float(j) / (n - 1)
		ci.draw_line(pts[j], pts[j + 1], col, maxf(1.0, w * (1.0 - u2 * 0.85)), true)
	ci.draw_circle(pts[n - 1], maxf(1.0, w * 0.18), col)


## A lost soul: a simple human figure, arms flung up, centred on c with height h.
static func silhouette(ci: CanvasItem, c: Vector2, h: float, rot: float, body: Color, rim: Color, t: float = 0.0) -> void:
	ci.draw_set_transform(c, rot, Vector2.ONE)
	var u := h / 10.0
	var flail := sin(t * 2.2) * 0.25
	var shapes: Array = []
	# torso
	shapes.append(PackedVector2Array([Vector2(-1.1, -2.6) * u, Vector2(1.1, -2.6) * u, Vector2(0.8, 1.2) * u, Vector2(-0.8, 1.2) * u]))
	# legs
	shapes.append(PackedVector2Array([Vector2(-0.8, 1.0) * u, Vector2(-0.1, 1.0) * u, Vector2(-0.6 - flail, 4.9) * u, Vector2(-1.3 - flail, 4.8) * u]))
	shapes.append(PackedVector2Array([Vector2(0.1, 1.0) * u, Vector2(0.8, 1.0) * u, Vector2(1.5 + flail, 4.6) * u, Vector2(0.8 + flail, 4.8) * u]))
	# arms reaching up
	shapes.append(PackedVector2Array([Vector2(-1.1, -2.5) * u, Vector2(-0.6, -2.1) * u, Vector2(-2.3 + flail, -5.0) * u, Vector2(-2.8 + flail, -4.6) * u]))
	shapes.append(PackedVector2Array([Vector2(1.1, -2.5) * u, Vector2(0.6, -2.1) * u, Vector2(2.4 - flail, -4.8) * u, Vector2(2.9 - flail, -4.3) * u]))
	for sh in shapes:
		var closed: PackedVector2Array = sh.duplicate()
		closed.append(sh[0])
		ci.draw_polyline(closed, rim, maxf(2.0, u * 0.6), true)
	ci.draw_circle(Vector2(0, -3.6) * u, u * 1.05 + maxf(1.0, u * 0.3), rim)
	for sh2 in shapes:
		ci.draw_colored_polygon(sh2, body)
	ci.draw_circle(Vector2(0, -3.6) * u, u * 1.05, body)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- sound ----------------------------------------------------------------------------------

## A seamless looping drone, built once per kind: "duel" (a low pulse with a
## heartbeat) or "realm" (deeper, with a slow howling whistle).
static func drone(kind: String = "duel") -> AudioStreamWAV:
	if _drones.has(kind):
		return _drones[kind]
	var rate := 22050
	var secs := 4
	var n := rate * secs
	var data := PackedByteArray()
	data.resize(n * 2)
	var realm := kind == "realm"
	# every frequency is a multiple of 1/secs Hz so the loop has no seam
	var f1 := 41.25 if realm else 55.0
	var f2 := 61.75 if realm else 82.5
	var f3 := 82.75 if realm else 110.25
	var whistle := 523.25
	for i in n:
		var x := float(i) / rate
		var swell := 0.6 + 0.4 * sin(TAU * 0.25 * x)
		var v := 0.34 * sin(TAU * f1 * x) + 0.22 * sin(TAU * f2 * x) * swell + 0.14 * sin(TAU * f3 * x) * (1.0 - swell * 0.5)
		if realm:
			var wob := sin(TAU * 0.5 * x)
			v += 0.05 * sin(TAU * (whistle + 12.0 * wob) * x) * (0.5 + 0.5 * sin(TAU * 0.25 * x + 1.0))
		else:
			# lub-dub every second
			var bt := fmod(x, 1.0)
			for off: float in [0.0, 0.22]:
				var d: float = bt - off
				if d >= 0.0 and d < 0.18:
					v += 0.55 * sin(TAU * 48.0 * d) * exp(-d * 26.0)
		var s := int(clampf(v * 0.55, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_drones[kind] = w
	return w


## Adds a looping drone player to `parent` and fades it in. Returns the player.
static func play_drone(parent: Node, kind: String, db: float = -12.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = drone(kind)
	p.volume_db = -40.0
	parent.add_child(p)
	if DisplayServer.get_name() == "headless":
		return p # nobody can hear it, and a playback alive at exit counts as a leak
	p.play()
	var tw := p.create_tween()
	tw.tween_property(p, "volume_db", db, 2.5)
	return p
