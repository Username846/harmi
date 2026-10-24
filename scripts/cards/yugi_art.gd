class_name YugiArt
extends RefCounted
## Yugi Moto, a procedural cartoon kid: an enormous spiky tri-colour hairdo
## (black spikes, magenta tips, blonde bangs), big violet eyes, a golden puzzle
## pendant on a chain and a blue school jacket. Drawn as a bust that always fits
## inside the given rect (designed for 120-400 px tall).
##
## draw(ci, rect, t, expression, yami, talk): expression is "smug", "shocked",
## "happy" or "determined"; t is the time in seconds (for bobbing, blinking and
## hair sway). yami draws his darker half instead (taller spikes, crimson eyes,
## the eye glowing on his forehead); talk >= 0 opens his mouth that wide (0-1),
## for singing.

const BOX_H := 1.25 # the figure is 1 unit wide and BOX_H units tall

const SKIN := Color(1.0, 0.86, 0.72)
const SKIN_SHADE := Color(0.93, 0.72, 0.6)
const HAIR := Color(0.08, 0.06, 0.1)
const HAIR_TIP := Color(0.82, 0.12, 0.52)
const HAIR_TIP_LIGHT := Color(0.98, 0.42, 0.75)
const BLONDE := Color(1.0, 0.84, 0.3)
const BLONDE_SHADE := Color(0.88, 0.6, 0.12)
const IRIS := Color(0.55, 0.22, 0.68)
const JACKET := Color(0.17, 0.24, 0.5)
const JACKET_DARK := Color(0.1, 0.14, 0.32)
const GOLD := Color(1.0, 0.8, 0.25)
const GOLD_DARK := Color(0.75, 0.52, 0.12)
const INK := Color(0.08, 0.05, 0.08)

const EXPRESSIONS := ["smug", "shocked", "happy", "determined"]

const HEAD_SCALE := 1.16
const HEAD_PIVOT := Vector2(0.5, 0.74)

const YAMI_IRIS := Color(0.78, 0.08, 0.16)
const YAMI_JACKET := Color(0.13, 0.08, 0.16)
const YAMI_JACKET_DARK := Color(0.06, 0.03, 0.08)

static var _yami := false
static var _talk := -1.0
static var _o := Vector2.ZERO
static var _s := 100.0
static var _base_o := Vector2.ZERO
static var _base_s := 100.0


## Draw the head bigger than the body (cartoon proportions): scales the unit
## mapping around the neck.
static func _head_on() -> void:
	_o = _base_o + HEAD_PIVOT * _base_s * (1.0 - HEAD_SCALE)
	_s = _base_s * HEAD_SCALE


static func _head_off() -> void:
	_o = _base_o
	_s = _base_s


static func _v(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


static func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in arr:
		out.append(_o + p * _s)
	return out


static func _w(u: float) -> float:
	return maxf(1.0, u * _s)


static func _fill(ci: CanvasItem, arr: Array, col: Color, line: Color = INK, lw: float = 0.008) -> void:
	var p := _pts(arr)
	ci.draw_colored_polygon(p, col)
	if line.a > 0.0:
		var c := p.duplicate()
		c.append(p[0])
		ci.draw_polyline(c, line, _w(lw), true)


static func _ellipse(cx: float, cy: float, rx: float, ry: float, n: int = 24, rot: float = 0.0) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * i / n
		out.append(Vector2(cx, cy) + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func _curve(ci: CanvasItem, arr: Array, col: Color, lw: float) -> void:
	ci.draw_polyline(_pts(arr), col, _w(lw), true)


static func _arc_pts(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int = 12) -> Array:
	var out: Array = []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return out


## Where the figure's unit box lands inside `rect` (for placing speech bubbles).
static func figure_rect(rect: Rect2) -> Rect2:
	var s := minf(rect.size.x, rect.size.y / BOX_H)
	var o := Vector2(rect.position.x + (rect.size.x - s) * 0.5, rect.end.y - s * BOX_H)
	return Rect2(o, Vector2(s, s * BOX_H))


## Point of the mouth in screen space (speech bubble tails aim here).
static func mouth_point(rect: Rect2) -> Vector2:
	var f := figure_rect(rect)
	return f.position + Vector2(0.5, 0.73) * f.size.x


static func draw(ci: CanvasItem, rect: Rect2, t: float, expression: String = "smug", yami: bool = false, talk: float = -1.0) -> void:
	if not EXPRESSIONS.has(expression):
		expression = "smug"
	_yami = yami
	_talk = talk
	var f := figure_rect(rect)
	var bob := sin(t * 1.8) * 0.006
	if expression == "shocked":
		bob += sin(t * 40.0) * 0.003 # trembling
	_base_s = f.size.x
	_base_o = f.position + Vector2(0, bob * _base_s)
	_head_off()
	if expression == "determined":
		_aura(ci, t)
	_head_on()
	_hair_back(ci, t, expression)
	_head_off()
	_body(ci)
	_head_on()
	_face(ci, t, expression)
	_bangs(ci, t)
	_brows(ci, expression)
	if _yami:
		_third_eye(ci, t)
	_head_off()
	_pendant(ci, t, expression)
	if expression == "shocked":
		_head_on()
		var k := fmod(t * 0.8, 1.0)
		_fill(ci, [Vector2(0.69, 0.5 + k * 0.05), Vector2(0.71, 0.545 + k * 0.05), Vector2(0.7, 0.56 + k * 0.05), Vector2(0.68, 0.545 + k * 0.05)],
			Color(0.6, 0.85, 1.0, 1.0 - k * 0.5), Color(0.2, 0.4, 0.7, 1.0 - k * 0.5), 0.005)
		for i in 3:
			var a := -2.4 + i * 0.35
			_curve(ci, [Vector2(0.5, 0.45) + Vector2.from_angle(a) * 0.3, Vector2(0.5, 0.45) + Vector2.from_angle(a) * 0.36], INK, 0.008)
		_head_off()


static func _aura(ci: CanvasItem, t: float) -> void:
	var c := _v(0.5, 0.5)
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	for i in 5:
		ci.draw_circle(c, _s * (0.5 - i * 0.07 + pulse * 0.02), Color(1.0, 0.8, 0.3, 0.06 + i * 0.015))
	for i in 12:
		var a := TAU * i / 12.0 + t * 0.5
		var p1 := c + Vector2.from_angle(a) * _s * 0.3
		var p2 := c + Vector2.from_angle(a) * _s * (0.47 + 0.03 * sin(t * 6.0 + i))
		ci.draw_line(p1, p2, Color(1.0, 0.85, 0.4, 0.35), _w(0.012), true)


const SPIKES := [
	# angle (radians, -PI/2 = straight up), length, half-width at the base
	[-2.98, 0.3, 0.3], [-2.55, 0.35, 0.32], [-2.07, 0.37, 0.3], [-1.57, 0.36, 0.28],
	[-1.07, 0.37, 0.3], [-0.59, 0.35, 0.32], [-0.16, 0.3, 0.3],
]
const HAIR_RIM := Color(0.36, 0.16, 0.4)


static func _hair_back(ci: CanvasItem, t: float, expression: String) -> void:
	var c := Vector2(0.5, 0.47)
	var bristle := 1.05 if expression == "shocked" else 1.0
	if _yami:
		bristle *= 1.14
	_fill(ci, _ellipse(0.5, 0.48, 0.235, 0.2), HAIR, Color(0, 0, 0, 0))
	for i in SPIKES.size():
		var sp: Array = SPIKES[i]
		var a: float = float(sp[0]) + sin(t * 1.3 + i * 1.7) * 0.025
		var length: float = float(sp[1]) * bristle
		var hw: float = sp[2]
		var b1 := c + Vector2.from_angle(a - hw) * 0.16
		var b2 := c + Vector2.from_angle(a + hw) * 0.16
		var tip := c + Vector2.from_angle(a) * length
		_fill(ci, [b1, tip, b2], HAIR, Color(0, 0, 0, 0))
		# magenta tips with a light streak
		var k := 0.48
		var m1 := b1.lerp(tip, k)
		var m2 := b2.lerp(tip, k)
		_fill(ci, [m1, tip, m2], HAIR_TIP, Color(0, 0, 0, 0))
		_fill(ci, [m1.lerp(m2, 0.2), tip, m1.lerp(m2, 0.45)], HAIR_TIP_LIGHT, Color(0, 0, 0, 0))
		_curve(ci, [b1, tip, b2], HAIR_RIM.lightened(0.15), 0.009)
	# shadowy strands on the black mass
	for i in 5:
		var a2 := -2.6 + i * 0.52
		_curve(ci, [c + Vector2.from_angle(a2) * 0.06, c + Vector2.from_angle(a2) * 0.2], Color(0.3, 0.2, 0.35, 0.7), 0.008)


static func _body(ci: CanvasItem) -> void:
	# jacket
	var jacket := YAMI_JACKET if _yami else JACKET
	var jacket_dark := YAMI_JACKET_DARK if _yami else JACKET_DARK
	_fill(ci, [Vector2(0.06, BOX_H), Vector2(0.09, 1.02), Vector2(0.2, 0.9), Vector2(0.38, 0.85), Vector2(0.62, 0.85),
		Vector2(0.8, 0.9), Vector2(0.91, 1.02), Vector2(0.94, BOX_H)], jacket, INK, 0.008)
	_fill(ci, [Vector2(0.06, BOX_H), Vector2(0.09, 1.02), Vector2(0.14, 0.96), Vector2(0.18, BOX_H)], jacket_dark, Color(0, 0, 0, 0))
	_fill(ci, [Vector2(0.94, BOX_H), Vector2(0.91, 1.02), Vector2(0.86, 0.96), Vector2(0.82, BOX_H)], jacket_dark, Color(0, 0, 0, 0))
	# black tank top under the open jacket
	_fill(ci, [Vector2(0.38, 0.86), Vector2(0.62, 0.86), Vector2(0.6, BOX_H), Vector2(0.4, BOX_H)], Color(0.1, 0.1, 0.13), INK, 0.006)
	# stand-up collar and lapels
	_fill(ci, [Vector2(0.37, 0.85), Vector2(0.32, 0.8), Vector2(0.3, 0.88), Vector2(0.42, 1.08)], jacket, INK, 0.007)
	_fill(ci, [Vector2(0.63, 0.85), Vector2(0.68, 0.8), Vector2(0.7, 0.88), Vector2(0.58, 1.08)], jacket, INK, 0.007)
	for y in [1.13, 1.2]:
		ci.draw_circle(_v(0.36, y), _s * 0.012, GOLD)
		ci.draw_circle(_v(0.64, y), _s * 0.012, GOLD)
	# neck and choker
	_fill(ci, [Vector2(0.45, 0.74), Vector2(0.55, 0.74), Vector2(0.56, 0.87), Vector2(0.44, 0.87)], SKIN, INK, 0.006)
	_fill(ci, [Vector2(0.45, 0.79), Vector2(0.55, 0.79), Vector2(0.552, 0.82), Vector2(0.448, 0.82)], INK, Color(0, 0, 0, 0))
	_fill(ci, [Vector2(0.49, 0.79), Vector2(0.51, 0.79), Vector2(0.51, 0.82), Vector2(0.49, 0.82)], Color(0.8, 0.82, 0.88), Color(0, 0, 0, 0))


static func _face(ci: CanvasItem, t: float, expression: String) -> void:
	# ears
	_fill(ci, _ellipse(0.335, 0.615, 0.022, 0.04), SKIN_SHADE, INK, 0.006)
	_fill(ci, _ellipse(0.665, 0.615, 0.022, 0.04), SKIN_SHADE, INK, 0.006)
	var face := [Vector2(0.335, 0.5), Vector2(0.4, 0.43), Vector2(0.5, 0.415), Vector2(0.6, 0.43), Vector2(0.665, 0.5),
		Vector2(0.66, 0.6), Vector2(0.63, 0.68), Vector2(0.57, 0.75), Vector2(0.5, 0.785), Vector2(0.43, 0.75),
		Vector2(0.37, 0.68), Vector2(0.34, 0.6)]
	_fill(ci, face, SKIN, INK, 0.008)
	# soft jaw shading
	_fill(ci, [Vector2(0.6, 0.62), Vector2(0.655, 0.6), Vector2(0.63, 0.68), Vector2(0.57, 0.75), Vector2(0.53, 0.77), Vector2(0.6, 0.7)], SKIN_SHADE, Color(0, 0, 0, 0))
	if expression == "happy":
		_fill(ci, _ellipse(0.39, 0.68, 0.035, 0.018), Color(1.0, 0.5, 0.55, 0.55), Color(0, 0, 0, 0))
		_fill(ci, _ellipse(0.61, 0.68, 0.035, 0.018), Color(1.0, 0.5, 0.55, 0.55), Color(0, 0, 0, 0))
	var blink := fmod(t, 3.7) < 0.13 and expression != "happy"
	for side in [-1.0, 1.0]:
		_eye(ci, 0.5 + side * 0.078, 0.615, side, expression, blink)
	# nose
	_curve(ci, [Vector2(0.505, 0.655), Vector2(0.515, 0.685), Vector2(0.5, 0.69)], Color(0.6, 0.4, 0.32), 0.006)
	_mouth(ci, t, expression)


static func _eye(ci: CanvasItem, cx: float, cy: float, side: float, expression: String, blink: bool) -> void:
	if blink or expression == "happy":
		# closed eye: a curve (happy eyes bend upward)
		var up := expression == "happy"
		var pts := _arc_pts(cx, cy + (0.012 if up else -0.005), 0.042, 0.03 if up else 0.012, PI if up else 0.0, TAU if up else PI, 10)
		_curve(ci, pts, INK, 0.012)
		return
	var ry := 0.058
	var iris_r := 0.036
	var look := Vector2.ZERO
	var tilt_yami := 0.0
	match expression:
		"shocked":
			ry = 0.066
			iris_r = 0.022
		"smug":
			look = Vector2(0.012, 0.004)
		"determined":
			ry = 0.05
	if _yami:
		ry *= 0.82
		tilt_yami = 0.45 * side
	var white := _ellipse(cx, cy, 0.05, ry, 24)
	_fill(ci, white, Color(1, 1, 1), Color(0, 0, 0, 0))
	var ic := Vector2(cx, cy + 0.006) + look
	var iris := YAMI_IRIS if _yami else IRIS
	ci.draw_circle(_v(ic.x, ic.y), _s * iris_r, iris)
	ci.draw_circle(_v(ic.x, ic.y + iris_r * 0.3), _s * iris_r * 0.65, iris.darkened(0.35))
	ci.draw_circle(_v(ic.x, ic.y), _s * iris_r * 0.45, INK)
	ci.draw_circle(_v(ic.x - iris_r * 0.35, ic.y - iris_r * 0.4), _s * iris_r * 0.3, Color(1, 1, 1))
	ci.draw_circle(_v(ic.x + iris_r * 0.35, ic.y + iris_r * 0.35), _s * iris_r * 0.14, Color(1, 1, 1, 0.8))
	# eyelids for the half-closed looks
	var lid := 0.0
	var tilt := 0.0
	match expression:
		"smug":
			lid = 0.45
		"determined":
			lid = 0.3
			tilt = 0.35 * side # lower toward the nose
	if _yami:
		lid = maxf(lid, 0.32)
		tilt = tilt_yami # a hard, angled glare
	if lid > 0.0:
		var top := cy - ry
		var y_in := top + ry * 2.0 * lid * (1.0 + tilt)
		var y_out := top + ry * 2.0 * lid * (1.0 - tilt)
		var x_in := cx - side * 0.056
		var x_out := cx + side * 0.056
		_fill(ci, [Vector2(x_in, top - 0.01), Vector2(x_out, top - 0.01), Vector2(x_out, y_out), Vector2(x_in, y_in)], SKIN, Color(0, 0, 0, 0))
		_curve(ci, [Vector2(x_in, y_in), Vector2(x_out, y_out)], INK, 0.013)
	else:
		_curve(ci, _arc_pts(cx, cy, 0.052, ry, PI * 1.05, TAU * 0.98, 12), INK, 0.015)
	# outer lash flick
	_curve(ci, [Vector2(cx + side * 0.05, cy - ry * 0.4), Vector2(cx + side * 0.068, cy - ry * 0.78)], INK, 0.011)
	_curve(ci, _arc_pts(cx, cy, 0.05, ry, PI * 0.2, PI * 0.8, 8), Color(0.45, 0.3, 0.3), 0.005)


static func _mouth(ci: CanvasItem, t: float, expression: String) -> void:
	if _talk >= 0.0:
		_singing_mouth(ci, _talk)
		return
	match expression:
		"smug":
			_curve(ci, [Vector2(0.465, 0.728), Vector2(0.5, 0.732), Vector2(0.53, 0.726), Vector2(0.548, 0.712)], INK, 0.009)
			_curve(ci, [Vector2(0.546, 0.706), Vector2(0.552, 0.716)], INK, 0.006)
		"shocked":
			_fill(ci, _ellipse(0.5, 0.735, 0.028, 0.034 + sin(t * 9.0) * 0.003), Color(0.45, 0.08, 0.12), INK, 0.008)
			_fill(ci, _ellipse(0.5, 0.755, 0.016, 0.01), Color(0.9, 0.4, 0.45), Color(0, 0, 0, 0))
		"happy":
			var smile := [Vector2(0.44, 0.715), Vector2(0.56, 0.715), Vector2(0.545, 0.745), Vector2(0.52, 0.762), Vector2(0.48, 0.762), Vector2(0.455, 0.745)]
			_fill(ci, smile, Color(0.5, 0.1, 0.14), INK, 0.008)
			_fill(ci, [Vector2(0.445, 0.716), Vector2(0.555, 0.716), Vector2(0.55, 0.727), Vector2(0.45, 0.727)], Color(1, 1, 1), Color(0, 0, 0, 0))
			_fill(ci, _ellipse(0.5, 0.752, 0.025, 0.009), Color(0.92, 0.45, 0.5), Color(0, 0, 0, 0))
		"determined":
			_fill(ci, [Vector2(0.465, 0.722), Vector2(0.535, 0.722), Vector2(0.53, 0.738), Vector2(0.47, 0.738)], Color(1, 1, 1), INK, 0.008)
			_curve(ci, [Vector2(0.467, 0.73), Vector2(0.533, 0.73)], Color(0.5, 0.45, 0.45), 0.004)


## A mouth opened `k` (0-1) wide: lips, a dark inside, top teeth; Yami's grin is
## wider and toothier, with fangs.
static func _singing_mouth(ci: CanvasItem, k: float) -> void:
	var w := (0.04 if _yami else 0.032) + k * 0.006
	var h := 0.004 + k * 0.034
	var cy := 0.73 + h * 0.35
	if k < 0.08:
		if _yami:
			_curve(ci, [Vector2(0.5 - w, 0.722), Vector2(0.5, 0.732), Vector2(0.5 + w, 0.718)], INK, 0.009)
		else:
			_curve(ci, [Vector2(0.5 - w * 0.8, 0.73), Vector2(0.5 + w * 0.8, 0.73)], INK, 0.009)
		return
	var shape := _ellipse(0.5, cy, w, h, 20)
	_fill(ci, shape, Color(0.32, 0.04, 0.08), INK, 0.008)
	# top teeth
	_fill(ci, [Vector2(0.5 - w * 0.8, cy - h * 0.82), Vector2(0.5 + w * 0.8, cy - h * 0.82), Vector2(0.5 + w * 0.7, cy - h * 0.45), Vector2(0.5 - w * 0.7, cy - h * 0.45)], Color(1, 1, 1), Color(0, 0, 0, 0))
	if _yami:
		for sx in [-1.0, 1.0]:
			_fill(ci, [Vector2(0.5 + sx * w * 0.55, cy - h * 0.5), Vector2(0.5 + sx * w * 0.35, cy - h * 0.5), Vector2(0.5 + sx * w * 0.45, cy - h * 0.05)], Color(1, 1, 1), Color(0, 0, 0, 0))
	# tongue
	if h > 0.016:
		_fill(ci, _ellipse(0.5, cy + h * 0.55, w * 0.55, h * 0.3, 14), Color(0.9, 0.4, 0.45), Color(0, 0, 0, 0))


## Yami's eye: the pendant's glyph burning on his forehead.
static func _third_eye(ci: CanvasItem, t: float) -> void:
	var pulse := 0.6 + 0.4 * sin(t * 5.0)
	var c := Vector2(0.5, 0.505)
	ci.draw_circle(_v(c.x, c.y), _s * (0.05 + 0.01 * pulse), Color(1.0, 0.8, 0.25, 0.22 * pulse))
	_fill(ci, _ellipse(c.x, c.y, 0.034, 0.014, 16), Color(1.0, 0.92, 0.55), Color(0.85, 0.55, 0.1), 0.005)
	ci.draw_circle(_v(c.x, c.y), _s * 0.008, Color(0.55, 0.3, 0.05))
	_curve(ci, [Vector2(c.x - 0.004, c.y + 0.014), Vector2(c.x - 0.012, c.y + 0.032)], Color(0.85, 0.55, 0.1), 0.005)
	_curve(ci, [Vector2(c.x + 0.01, c.y + 0.014), Vector2(c.x + 0.022, c.y + 0.026), Vector2(c.x + 0.03, c.y + 0.024)], Color(0.85, 0.55, 0.1), 0.005)


static func _bangs(ci: CanvasItem, t: float) -> void:
	var sway := sin(t * 1.3) * 0.004
	# blonde spikes rising in front of the black hair
	_fill(ci, [Vector2(0.43, 0.44), Vector2(0.4, 0.3), Vector2(0.43, 0.32), Vector2(0.42, 0.2 + sway), Vector2(0.5, 0.36), Vector2(0.48, 0.44)], BLONDE, INK, 0.007)
	_fill(ci, [Vector2(0.52, 0.44), Vector2(0.5, 0.36), Vector2(0.58, 0.2 - sway), Vector2(0.57, 0.32), Vector2(0.6, 0.3), Vector2(0.57, 0.44)], BLONDE, INK, 0.007)
	# hairline: the top of the head is black hair
	_fill(ci, [Vector2(0.33, 0.52), Vector2(0.36, 0.44), Vector2(0.43, 0.405), Vector2(0.57, 0.405), Vector2(0.64, 0.44), Vector2(0.67, 0.52),
		Vector2(0.62, 0.47), Vector2(0.38, 0.47)], HAIR, Color(0, 0, 0, 0))
	# side bangs framing the face (lightning-bolt locks)
	for side in [-1.0, 1.0]:
		var sx: float = side
		var lock := [Vector2(0.5 + sx * 0.06, 0.42), Vector2(0.5 + sx * 0.17, 0.43), Vector2(0.5 + sx * 0.19, 0.53),
			Vector2(0.5 + sx * 0.175, 0.56), Vector2(0.5 + sx * 0.2 + sway * sx, 0.7), Vector2(0.5 + sx * 0.155, 0.6),
			Vector2(0.5 + sx * 0.15, 0.55), Vector2(0.5 + sx * 0.12, 0.5), Vector2(0.5 + sx * 0.13, 0.57), Vector2(0.5 + sx * 0.09, 0.47)]
		_fill(ci, lock, BLONDE, INK, 0.007)
		_fill(ci, [Vector2(0.5 + sx * 0.17, 0.44), Vector2(0.5 + sx * 0.185, 0.53), Vector2(0.5 + sx * 0.165, 0.55)], BLONDE_SHADE, Color(0, 0, 0, 0))
	# the centre lock hangs between the eyes
	var mid := [Vector2(0.455, 0.41), Vector2(0.545, 0.41), Vector2(0.53, 0.47), Vector2(0.545, 0.5), Vector2(0.51, 0.495),
		Vector2(0.515, 0.565 + sway), Vector2(0.485, 0.505), Vector2(0.47, 0.52), Vector2(0.475, 0.47)]
	_fill(ci, mid, BLONDE, INK, 0.007)
	_fill(ci, [Vector2(0.51, 0.42), Vector2(0.535, 0.42), Vector2(0.52, 0.47)], BLONDE_SHADE, Color(0, 0, 0, 0))


static func _brows(ci: CanvasItem, expression: String) -> void:
	var l: Array
	var r: Array
	match expression:
		"shocked":
			l = [Vector2(0.39, 0.535), Vector2(0.425, 0.515), Vector2(0.46, 0.53)]
			r = [Vector2(0.54, 0.53), Vector2(0.575, 0.515), Vector2(0.61, 0.535)]
		"happy":
			l = [Vector2(0.39, 0.55), Vector2(0.425, 0.535), Vector2(0.46, 0.548)]
			r = [Vector2(0.54, 0.548), Vector2(0.575, 0.535), Vector2(0.61, 0.55)]
		"determined":
			l = [Vector2(0.385, 0.535), Vector2(0.425, 0.548), Vector2(0.468, 0.572)]
			r = [Vector2(0.532, 0.572), Vector2(0.575, 0.548), Vector2(0.615, 0.535)]
		_: # smug: one brow cocked
			l = [Vector2(0.39, 0.548), Vector2(0.425, 0.538), Vector2(0.46, 0.55)]
			r = [Vector2(0.54, 0.54), Vector2(0.575, 0.52), Vector2(0.61, 0.53)]
	if _yami:
		l = [Vector2(0.38, 0.528), Vector2(0.425, 0.546), Vector2(0.47, 0.574)]
		r = [Vector2(0.53, 0.574), Vector2(0.575, 0.546), Vector2(0.62, 0.528)]
	_curve(ci, l, INK, 0.019 if _yami else 0.016)
	_curve(ci, r, INK, 0.019 if _yami else 0.016)


static func _pendant(ci: CanvasItem, t: float, expression: String) -> void:
	# chain
	var chain := Color(0.85, 0.7, 0.3)
	_curve(ci, [Vector2(0.45, 0.82), Vector2(0.43, 0.9), Vector2(0.435, 0.965)], chain, 0.007)
	_curve(ci, [Vector2(0.55, 0.82), Vector2(0.57, 0.9), Vector2(0.565, 0.965)], chain, 0.007)
	var glow := 0.0
	if expression == "determined":
		glow = 0.6 + 0.4 * sin(t * 5.0)
	if glow > 0.0:
		ci.draw_circle(_v(0.5, 1.03), _s * (0.12 + glow * 0.03), Color(1.0, 0.85, 0.3, 0.25 * glow))
	# inverted pyramid: lit left face, shaded right face
	var top_l := Vector2(0.405, 0.965)
	var top_r := Vector2(0.595, 0.965)
	var tip := Vector2(0.5, 1.13)
	var front := Vector2(0.49, 0.985)
	_fill(ci, [top_l, top_r, tip], GOLD, INK, 0.008)
	_fill(ci, [front, top_r, tip], GOLD_DARK, Color(0, 0, 0, 0))
	_fill(ci, [top_l, Vector2(0.5, 0.955), top_r, front], Color(1.0, 0.92, 0.6), INK, 0.006)
	# puzzle seams and an eye-like glyph
	_curve(ci, [Vector2(0.44, 1.02), Vector2(0.475, 1.03), Vector2(0.47, 1.06)], Color(0.55, 0.35, 0.08), 0.005)
	_curve(ci, [Vector2(0.53, 1.04), Vector2(0.56, 1.02)], Color(0.55, 0.35, 0.08), 0.005)
	_fill(ci, _ellipse(0.49, 1.025, 0.026, 0.013, 16), Color(1.0, 0.95, 0.75), Color(0.45, 0.28, 0.05), 0.005)
	ci.draw_circle(_v(0.49, 1.025), _s * 0.008, Color(0.45, 0.28, 0.05))
	# a travelling sparkle
	var k := fmod(t * 0.5, 2.0)
	if k < 1.0:
		var p := top_l.lerp(tip, k)
		var a := _v(p.x, p.y)
		var r := _s * 0.025 * sin(k * PI)
		ci.draw_line(a - Vector2(r, 0), a + Vector2(r, 0), Color(1, 1, 0.9), _w(0.005), true)
		ci.draw_line(a - Vector2(0, r), a + Vector2(0, r), Color(1, 1, 0.9), _w(0.005), true)
