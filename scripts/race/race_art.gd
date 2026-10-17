class_name RaceArt
extends RefCounted
## Procedural drawing for the pink slip race: the five cars (one per piece
## type, with the elongated piece sticking up out of it like a driver), the
## christmas tree and the tachometer. Car geometry is in metres: x runs from
## the rear bumper forward, y up from the ground.

const PIECE_M := 1.25 ## piece scale in metres (one "board square")
const GLASS := Color(0.07, 0.09, 0.13)
const GLASS_TINT := Color(0.55, 0.7, 0.9, 0.17)
const RIM := Color(0.62, 0.62, 0.66)
const CHROME := Color(0.78, 0.8, 0.84)
const AMBER := Color(1.0, 0.68, 0.15)
const GO_GREEN := Color(0.3, 1.0, 0.4)
const NOS_BLUE := Color(0.35, 0.6, 1.0)

const PAINT := [Color(0.5, 0.5, 0.5), Color(0.80, 0.60, 0.20), Color(0.62, 0.10, 0.10),
	Color(0.15, 0.13, 0.17), Color(0.34, 0.37, 0.28), Color(0.42, 0.14, 0.54), Color(0.5, 0.5, 0.5)]

const CAR_NAMES := ["", "hatchback", "muscle car", "hearse", "armored truck", "sports car", "limousine"]

## body/windows: flat [x, y, x, y, ...] outlines. wheels: [x, radius].
## seat: where the piece stands. roof: roof height above the seat.
## pipe: exhaust [x, y, dir x, dir y].
const CARS := {
	1: {"len": 3.5, "belt": 0.95, "roof": 1.40, "seat": [1.62, 0.5],
		"body": [0.0, 0.3, 0.0, 0.92, 0.12, 1.36, 1.95, 1.42, 2.55, 0.98, 3.38, 0.86, 3.5, 0.66, 3.48, 0.3, 3.2, 0.18, 0.25, 0.18],
		"win": [[0.24, 0.98, 0.31, 1.30, 1.12, 1.33, 1.12, 0.98], [1.22, 0.98, 1.22, 1.34, 1.9, 1.36, 2.4, 0.98]],
		"wheels": [[0.72, 0.31], [2.82, 0.31]], "head": [3.44, 0.76], "tail": [0.02, 0.8], "pipe": [0.05, 0.24, -1.0, 0.0]},
	2: {"len": 4.9, "belt": 0.98, "roof": 1.30, "seat": [2.42, 0.42],
		"body": [0.0, 0.32, 0.0, 0.9, 0.2, 0.98, 1.35, 1.0, 2.0, 1.3, 2.78, 1.3, 3.3, 0.98, 3.75, 0.96, 3.85, 1.07,
			4.25, 1.07, 4.32, 0.95, 4.8, 0.88, 4.9, 0.68, 4.88, 0.32, 4.5, 0.2, 0.3, 0.2],
		"win": [[1.5, 1.0, 2.04, 1.26, 2.74, 1.26, 3.16, 0.99]],
		"wheels": [[0.95, 0.38], [3.95, 0.34]], "head": [4.86, 0.78], "tail": [0.02, 0.8], "pipe": [0.0, 0.25, -1.0, 0.0]},
	3: {"len": 5.6, "belt": 1.0, "roof": 1.52, "seat": [3.38, 0.55],
		"body": [0.0, 0.32, 0.0, 1.0, 0.08, 1.5, 3.75, 1.52, 4.3, 1.0, 5.45, 0.9, 5.6, 0.7, 5.58, 0.32, 5.25, 0.2, 0.3, 0.2],
		"win": [[1.3, 1.04, 1.3, 1.42, 2.95, 1.44, 2.95, 1.04], [3.05, 1.04, 3.05, 1.44, 3.68, 1.44, 4.15, 1.04]],
		"wheels": [[1.1, 0.36], [4.55, 0.36]], "head": [5.56, 0.8], "tail": [0.02, 0.9], "pipe": [0.05, 0.24, -1.0, 0.0]},
	4: {"len": 6.0, "belt": 1.42, "roof": 2.25, "seat": [4.62, 1.2],
		"body": [0.0, 0.42, 0.0, 2.75, 4.15, 2.75, 4.15, 2.25, 4.75, 2.25, 5.35, 1.42, 5.95, 1.3, 6.0, 0.45, 5.7, 0.3, 0.2, 0.3],
		"win": [[4.3, 1.48, 4.3, 2.1, 4.78, 2.1, 5.22, 1.48]],
		"wheels": [[1.0, 0.46], [2.05, 0.46], [5.05, 0.46]], "head": [5.96, 0.95], "tail": [0.02, 0.8], "pipe": [4.06, 3.05, 0.0, 1.0]},
	5: {"len": 4.6, "belt": 0.9, "roof": 1.18, "seat": [2.28, 0.38],
		"body": [0.0, 0.3, 0.0, 0.8, 0.15, 0.9, 1.25, 0.95, 1.95, 1.17, 2.6, 1.18, 3.15, 0.88, 4.45, 0.6, 4.6, 0.42, 4.55, 0.3, 4.3, 0.18, 0.3, 0.18],
		"win": [[1.42, 0.95, 1.98, 1.14, 2.56, 1.15, 2.98, 0.9]],
		"wheels": [[0.85, 0.34], [3.75, 0.33]], "head": [4.52, 0.55], "tail": [0.02, 0.72], "pipe": [0.0, 0.26, -1.0, 0.0]},
}

static var _lower_cache: Dictionary = {}


static func spec(t: int) -> Dictionary:
	return CARS.get(t, CARS[1])


static func car_length(t: int) -> float:
	return float(spec(t)["len"])


static func paint_color(t: int, white: bool) -> Color:
	var c: Color = PAINT[clampi(t, 0, PAINT.size() - 1)]
	return c.lerp(Color(0.93, 0.9, 0.84), 0.22) if white else c.darkened(0.25)


## Height (metres) of the top of the piece above the ground.
static func top_height(t: int) -> float:
	var seat: Array = spec(t)["seat"]
	return float(seat[1]) + PieceArt.height(t) * PIECE_M


static func _pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size() - 1, 2):
		out.append(Vector2(float(flat[i]), -float(flat[i + 1])))
	return out


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := p.duplicate()
	c.append(p[0])
	return c


static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, -y0), Vector2(x1, -y0), Vector2(x1, -y1), Vector2(x0, -y1)])


static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## The part of the body below the beltline: drawn in front of the piece so
## its base sits inside the car.
static func _lower(t: int) -> Array:
	if _lower_cache.has(t):
		return _lower_cache[t]
	var sp := spec(t)
	var belt: float = sp["belt"]
	var l: float = sp["len"]
	var cut := PackedVector2Array([Vector2(-1, -belt), Vector2(l + 1, -belt), Vector2(l + 1, 1), Vector2(-1, 1)])
	var res: Array = Geometry2D.intersect_polygons(_pts(sp["body"]), cut)
	_lower_cache[t] = res
	return res


## Vertical gradient fill for a body panel (lighter on top, like a street lamp above).
static func _shaded(ci: CanvasItem, p: PackedVector2Array, paint: Color, top_y: float, bottom_y: float) -> void:
	var cols := PackedColorArray()
	var hi := paint.lightened(0.22)
	var lo := paint.darkened(0.42)
	for v in p:
		var k := clampf((v.y - top_y) / maxf(bottom_y - top_y, 0.01), 0.0, 1.0)
		cols.append(hi.lerp(lo, k))
	ci.draw_polygon(p, cols)


## Draws a car with its piece. origin: screen point of the rear bumper at
## ground level. s: pixels per metre. opts: pitch, spin (wheel angle), lean
## (piece sway), flame (0..1 exhaust flame), nos (bool), brake (bool), lights (bool).
static func draw_car(ci: CanvasItem, t: int, white: bool, origin: Vector2, s: float, opts: Dictionary = {}) -> void:
	var sp := spec(t)
	var pitch: float = opts.get("pitch", 0.0)
	var spin: float = opts.get("spin", 0.0)
	var lean: float = opts.get("lean", 0.0)
	var flame: float = opts.get("flame", 0.0)
	var nos: bool = opts.get("nos", false)
	var brake: bool = opts.get("brake", false)
	var l: float = sp["len"]
	var belt: float = sp["belt"]
	var roof: float = sp["roof"]
	var seat: Array = sp["seat"]
	var head: Array = sp["head"]
	var tail: Array = sp["tail"]
	var paint := paint_color(t, white)
	var body := _pts(sp["body"])
	var top_y := -roof
	if t == 4:
		top_y = -2.75
	var rim_light := Color(1.0, 0.86, 0.62, 0.45)
	var ink := Color(0.02, 0.015, 0.03, 0.9)
	var lw := 0.045

	ci.draw_set_transform(origin, pitch, Vector2(s, s))
	# shadow and headlight beam
	ci.draw_colored_polygon(_ellipse(Vector2(l * 0.5, 0.02), l * 0.58, 0.16), Color(0, 0, 0, 0.5))
	if opts.get("lights", true):
		var hp := Vector2(float(head[0]), -float(head[1]))
		var beam := PackedVector2Array([hp, hp + Vector2(10.0, -0.5), hp + Vector2(10.0, float(head[1]) + 0.05)])
		var bc := Color(1.0, 0.94, 0.7, 0.26)
		ci.draw_polygon(beam, PackedColorArray([bc, Color(bc, 0.0), Color(bc, 0.03)]))
	# --- back layer: whole body, glass, upper details
	_shaded(ci, body, paint, top_y, 0.0)
	for w in sp["win"]:
		ci.draw_colored_polygon(_pts(w), GLASS)
	_details_back(ci, t, paint, white)
	ci.draw_polyline(_closed(body), ink, lw * 1.6, true)
	# --- the piece, standing in the cabin
	var base := origin + Vector2(float(seat[0]), -float(seat[1])).rotated(pitch) * s
	var flip := 1.0
	if t == 2 and white:
		flip = -1.0 # white knights face left; turn it to look down the strip
	ci.draw_set_transform(base, pitch + lean, Vector2(flip, 1.0))
	PieceArt.draw_piece(ci, t, white, 0.0, 0.0, PIECE_M * s, Color.WHITE, false)
	# --- front layer
	ci.draw_set_transform(origin, pitch, Vector2(s, s))
	for w in sp["win"]:
		var wp := _pts(w)
		ci.draw_colored_polygon(wp, GLASS_TINT)
		ci.draw_polyline(_closed(wp), Color(0, 0, 0, 0.6), lw, true)
	for poly in _lower(t):
		var lp: PackedVector2Array = poly
		_shaded(ci, lp, paint, top_y, 0.0)
	# roof hole the piece pokes through
	var sx: float = seat[0]
	ci.draw_line(Vector2(sx - 0.24, -roof + 0.01), Vector2(sx + 0.24, -roof + 0.01), ink, 0.07)
	ci.draw_line(Vector2(sx - 0.24, -roof - 0.025), Vector2(sx + 0.24, -roof - 0.025), CHROME.darkened(0.3), 0.035)
	_details_front(ci, t, paint, l, belt)
	# outline + rim light along the top edge
	ci.draw_polyline(_closed(body), ink, lw, true)
	var top_edge := PackedVector2Array()
	for v in body:
		if v.y < -belt * 0.95:
			top_edge.append(v + Vector2(0, 0.03))
	if top_edge.size() >= 2:
		ci.draw_polyline(top_edge, rim_light, lw, true)
	# wheels
	for wh in sp["wheels"]:
		_wheel(ci, Vector2(float(wh[0]), -float(wh[1])), float(wh[1]), spin, t == 3)
	# lights
	var hpos := Vector2(float(head[0]), -float(head[1]))
	ci.draw_colored_polygon(_ellipse(hpos, 0.08, 0.06, 10), Color(1, 0.97, 0.85))
	ci.draw_colored_polygon(_ellipse(hpos, 0.22, 0.16, 12), Color(1, 0.9, 0.6, 0.22))
	var tpos := Vector2(float(tail[0]), -float(tail[1]))
	ci.draw_colored_polygon(PackedVector2Array([tpos + Vector2(0, -0.08), tpos + Vector2(0.07, -0.08), tpos + Vector2(0.07, 0.08), tpos + Vector2(0, 0.08)]), Color(0.95, 0.12, 0.1))
	if brake:
		ci.draw_colored_polygon(_ellipse(tpos, 0.35, 0.22, 12), Color(1, 0.1, 0.08, 0.3))
	if flame > 0.01 or nos:
		_flame(ci, sp["pipe"], flame, nos)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _wheel(ci: CanvasItem, c: Vector2, r: float, spin: float, whitewall: bool) -> void:
	ci.draw_circle(c, r * 1.12, Color(0.015, 0.012, 0.02))
	ci.draw_circle(c, r, Color(0.07, 0.065, 0.075))
	if whitewall:
		ci.draw_circle(c, r * 0.8, Color(0.85, 0.83, 0.78))
	ci.draw_circle(c, r * 0.64, RIM.darkened(0.15))
	ci.draw_circle(c, r * 0.5, RIM.darkened(0.55))
	var a0 := spin / r
	for k in 5:
		var d := Vector2.from_angle(a0 + k * TAU / 5.0)
		ci.draw_line(c + d * r * 0.1, c + d * r * 0.56, RIM.lightened(0.15), r * 0.13)
	ci.draw_circle(c, r * 0.14, CHROME)


static func _flame(ci: CanvasItem, pipe: Array, k: float, nos: bool) -> void:
	var p := Vector2(float(pipe[0]), -float(pipe[1]))
	var d := Vector2(float(pipe[2]), -float(pipe[3]))
	var n := d.orthogonal()
	var flick := randf_range(0.8, 1.2)
	var length := (0.45 + k * 0.9) * flick
	var width := 0.11 + k * 0.06
	var outer := Color(1.0, 0.45, 0.1, 0.85)
	var inner := Color(1.0, 0.9, 0.45, 0.95)
	if nos:
		length = maxf(length, 1.5 * flick)
		width = 0.16
		outer = Color(0.3, 0.5, 1.0, 0.85)
		inner = Color(0.85, 0.95, 1.0, 0.95)
	var tip := p + d * length
	ci.draw_colored_polygon(PackedVector2Array([p + n * width, tip, p - n * width]), outer)
	ci.draw_colored_polygon(PackedVector2Array([p + n * width * 0.5, p + d * length * 0.6, p - n * width * 0.5]), inner)
	ci.draw_colored_polygon(_ellipse(p + d * length * 0.3, length * 0.5, length * 0.35, 12), Color(outer, 0.18))


static func _details_back(ci: CanvasItem, t: int, paint: Color, white: bool) -> void:
	var dark := paint.darkened(0.5)
	match t:
		3: # hearse: curtains in the long rear window, landau bar on the quarter
			var cur := Color(0.36, 0.1, 0.32) if not white else Color(0.5, 0.42, 0.55)
			var drape := PackedVector2Array([Vector2(1.3, -1.42), Vector2(2.95, -1.44)])
			var x := 2.95
			while x > 1.32:
				drape.append(Vector2(x - 0.17, -1.30))
				drape.append(Vector2(x - 0.34, -1.40))
				x -= 0.34
			ci.draw_colored_polygon(PackedVector2Array([Vector2(1.3, -1.04), Vector2(1.3, -1.42), Vector2(1.6, -1.42), Vector2(1.5, -1.04)]), cur)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(2.95, -1.04), Vector2(2.95, -1.43), Vector2(2.65, -1.43), Vector2(2.75, -1.04)]), cur)
			ci.draw_polyline(drape, cur.lightened(0.15), 0.06, true)
			var bar := PackedVector2Array()
			for i in 13:
				var u := i / 12.0
				bar.append(Vector2(0.3 + u * 0.8, -1.22 - sin(u * TAU) * 0.1))
			ci.draw_polyline(bar, CHROME, 0.05, true)
		4: # crenellations on the armored box: it is a rook after all
			var x2 := 0.0
			while x2 < 4.0:
				var r := _rect(x2, 2.74, x2 + 0.42, 3.0)
				ci.draw_colored_polygon(r, paint.lightened(0.05))
				ci.draw_polyline(_closed(r), Color(0, 0, 0, 0.7), 0.04, true)
				x2 += 0.7
		5: # rear wing
			ci.draw_colored_polygon(_rect(0.32, 0.88, 0.4, 1.13), dark)
			var wing := PackedVector2Array([Vector2(-0.08, -1.1), Vector2(0.82, -1.15), Vector2(0.82, -1.22), Vector2(-0.08, -1.22)])
			ci.draw_colored_polygon(wing, paint.lightened(0.1))
			ci.draw_polyline(_closed(wing), Color(0, 0, 0, 0.8), 0.035, true)


static func _details_front(ci: CanvasItem, t: int, paint: Color, l: float, belt: float) -> void:
	var seam := Color(0, 0, 0, 0.45)
	var lw := 0.035
	match t:
		1:
			ci.draw_line(Vector2(1.17, -0.28), Vector2(1.17, -belt), seam, lw)
			ci.draw_line(Vector2(0.9, -0.82), Vector2(1.05, -0.82), CHROME, 0.05)
			ci.draw_line(Vector2(2.0, -0.82), Vector2(2.15, -0.82), CHROME, 0.05)
		2:
			var stripe := Color(0.95, 0.92, 0.85, 0.9)
			ci.draw_colored_polygon(_rect(0.06, 0.62, l - 0.12, 0.67), stripe)
			ci.draw_colored_polygon(_rect(0.06, 0.72, l - 0.12, 0.77), stripe)
			ci.draw_line(Vector2(3.18, -0.28), Vector2(3.18, -belt), seam, lw)
			ci.draw_colored_polygon(_rect(4.7, 0.3, 4.92, 0.42), CHROME)
			ci.draw_colored_polygon(_rect(-0.03, 0.3, 0.2, 0.42), CHROME)
		3:
			ci.draw_colored_polygon(_rect(0.05, 0.72, l - 0.08, 0.76), CHROME)
			ci.draw_line(Vector2(3.0, -0.28), Vector2(3.0, -belt), seam, lw)
			ci.draw_line(Vector2(4.2, -0.28), Vector2(4.2, -belt), seam, lw)
		4:
			for y in [0.9, 1.6, 2.3]:
				ci.draw_line(Vector2(0.05, -y), Vector2(4.1, -y), seam, lw)
			for xi in 7:
				for y2 in [0.62, 1.25, 1.95, 2.6]:
					ci.draw_circle(Vector2(0.25 + xi * 0.6, -y2), 0.04, Color(0.85, 0.85, 0.75, 0.6))
			ci.draw_line(Vector2(4.15, -0.4), Vector2(4.15, -2.25), seam, lw)
			# chevrons on the rear
			for k in 3:
				var y0 := 0.5 + k * 0.22
				ci.draw_colored_polygon(PackedVector2Array([Vector2(0.0, -y0), Vector2(0.12, -y0 - 0.1), Vector2(0.12, -y0 - 0.2), Vector2(0.0, -y0 - 0.1)]), UI.GOLD)
			# exhaust stack behind the cab
			ci.draw_colored_polygon(_rect(4.0, 1.0, 4.12, 3.05), CHROME.darkened(0.25))
			ci.draw_line(Vector2(3.97, -3.05), Vector2(4.15, -3.05), CHROME, 0.06)
		5:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(1.2, -0.45), Vector2(1.85, -0.48), Vector2(1.85, -0.74), Vector2(1.5, -0.72)]), Color(0.03, 0.02, 0.04, 0.85))
			ci.draw_line(Vector2(0.1, -0.79), Vector2(4.35, -0.6), UI.GOLD, 0.04)
			ci.draw_line(Vector2(3.05, -0.28), Vector2(3.05, -0.86), seam, lw)


# --- christmas tree -----------------------------------------------------------

## Two-column drag tree, top centre at `top`. ambers 0-3; red flags mark a
## false start on that column (left = rival, right = you).
static func draw_tree(ci: CanvasItem, top: Vector2, k: float, ambers: int, green: bool, red_left: bool, red_right: bool, labels: bool = true) -> Rect2:
	var r := 11.0 * k
	var gap_x := 30.0 * k
	var gap_y := 27.0 * k
	var rows := 6
	var w := gap_x + r * 2.0 + 22.0 * k
	var h := gap_y * (rows - 1) + r * 2.0 + 20.0 * k + (16.0 * k if labels else 0.0)
	var box := Rect2(top - Vector2(w * 0.5, 0), Vector2(w, h))
	ci.draw_rect(box.grow(3.0 * k), Color(0, 0, 0, 0.55))
	ci.draw_rect(box, Color(0.08, 0.075, 0.09))
	ci.draw_rect(box, Color(0.35, 0.33, 0.36), false, maxf(1.0, 2.0 * k))
	for col in 2:
		var x := top.x + (col - 0.5) * gap_x
		for row in rows:
			var c := Vector2(x, top.y + 10.0 * k + r + row * gap_y)
			var on := false
			var col_c := Color(0.2, 0.18, 0.18)
			match row:
				0:
					col_c = Color(1, 0.95, 0.7)
					on = true # stage bulbs
				1, 2, 3:
					col_c = AMBER
					on = ambers >= row
				4:
					col_c = GO_GREEN
					on = green and not (red_left if col == 0 else red_right)
				5:
					col_c = Color(1, 0.15, 0.1)
					on = red_left if col == 0 else red_right
			var rr := r * (0.55 if row == 0 else 1.0)
			ci.draw_circle(c, rr + 2.0 * k, Color(0, 0, 0, 0.8))
			if on:
				ci.draw_circle(c, rr * 2.1, Color(col_c, 0.16))
				ci.draw_circle(c, rr * 1.45, Color(col_c, 0.28))
				ci.draw_circle(c, rr, col_c)
				ci.draw_circle(c - Vector2(rr, rr) * 0.3, rr * 0.35, Color(1, 1, 1, 0.55))
			else:
				ci.draw_circle(c, rr, col_c.darkened(0.82))
	if labels:
		var font := ThemeDB.fallback_font
		var fs := int(maxf(9.0, 11.0 * k))
		var y := box.end.y - 6.0 * k
		ci.draw_string(font, Vector2(top.x - gap_x * 0.5 - 20.0 * k, y), "THEM", HORIZONTAL_ALIGNMENT_CENTER, 40.0 * k, fs, UI.DIM)
		ci.draw_string(font, Vector2(top.x + gap_x * 0.5 - 20.0 * k, y), "YOU", HORIZONTAL_ALIGNMENT_CENTER, 40.0 * k, fs, UI.GOLD)
	return box


# --- tachometer ----------------------------------------------------------------

const TACH_A0 := 150.0
const TACH_A1 := 390.0


static func _tach_angle(rpm: float) -> float:
	return deg_to_rad(lerpf(TACH_A0, TACH_A1, clampf(rpm, 0.0, 1.06) / 1.06))


static func _band(ci: CanvasItem, c: Vector2, r: float, w: float, a: float, b: float, col: Color) -> void:
	ci.draw_arc(c, r, _tach_angle(a), _tach_angle(b), 32, col, w, true)


## Draws the tach filling `rect`. info: rpm, gear (0 = neutral), kmh, nos (bool),
## launched (bool), stalled (bool), t (time, for flashing).
static func draw_tach(ci: CanvasItem, rect: Rect2, info: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var rpm: float = info.get("rpm", 0.0)
	var gear: int = info.get("gear", 0)
	var kmh: float = info.get("kmh", 0.0)
	var nos: bool = info.get("nos", false)
	var t: float = info.get("t", 0.0)
	var stalled: bool = info.get("stalled", false)
	var r := minf(rect.size.x * 0.46, rect.size.y * 0.5 - 8.0)
	if r < 20.0:
		return
	var c := rect.get_center()
	# face
	ci.draw_circle(c, r + 6.0, Color(0.02, 0.015, 0.02))
	ci.draw_circle(c, r + 3.0, UI.BORDER)
	var face := Color(0.07, 0.06, 0.075)
	if rpm >= RaceSim.REDLINE and fmod(t * 8.0, 1.0) < 0.5:
		face = Color(0.25, 0.04, 0.04)
	elif nos:
		face = Color(0.05, 0.08, 0.2)
	ci.draw_circle(c, r, face)
	ci.draw_circle(c, r * 0.97, Color(1, 1, 1, 0.025), false, 2.0, true)
	# zones
	var bw := r * 0.13
	var br := r * 0.82
	_band(ci, c, br, bw, 0.0, RaceSim.EARLY_BELOW, Color(0.18, 0.16, 0.2))
	_band(ci, c, br, bw, RaceSim.EARLY_BELOW, RaceSim.LATE_ABOVE, Color(0.2, 0.62, 0.3))
	_band(ci, c, br, bw * 1.25, RaceSim.PERFECT_LO, RaceSim.PERFECT_HI, UI.GOLD)
	_band(ci, c, br, bw, RaceSim.LATE_ABOVE, RaceSim.REDLINE, UI.EMBER)
	_band(ci, c, br, bw, RaceSim.REDLINE, 1.06, UI.RED)
	# ticks and numbers (0-8 thousand rpm, limiter at 7.5)
	var fs := int(clampf(r * 0.12, 10.0, 22.0))
	for i in 17:
		var v := i * 0.5 / 7.5
		if v > 1.06:
			break
		var a := _tach_angle(v)
		var d := Vector2.from_angle(a)
		var major := i % 2 == 0
		ci.draw_line(c + d * r * (0.9 if major else 0.93), c + d * r * 0.98, UI.TEXT if major else UI.DIM, 2.5 if major else 1.5, true)
		if major:
			var txt := str(i / 2)
			var p := c + d * r * 0.62
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			ci.draw_string(font, p + Vector2(-sz.x * 0.5, sz.y * 0.3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.TEXT)
	var small := int(clampf(r * 0.08, 9.0, 15.0))
	ci.draw_string(font, c + Vector2(-r, -r * 0.28), "x1000 rpm", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, small, UI.DIM)
	# gear + speed
	var gtxt := "N" if gear <= 0 else str(gear)
	if stalled:
		gtxt = "!"
	var gfs := int(clampf(r * 0.36, 18.0, 80.0))
	var gcol := UI.GOLD if not stalled else UI.RED
	ci.draw_string(font, c + Vector2(-r, r * 0.45), gtxt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, gfs, gcol)
	ci.draw_string(font, c + Vector2(-r, r * 0.45 + small * 1.3), "GEAR", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, small, UI.DIM)
	var sfs := int(clampf(r * 0.15, 11.0, 28.0))
	ci.draw_string(font, c + Vector2(-r, r * 0.8), "%d km/h" % int(round(kmh)), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, sfs, UI.TEXT)
	# needle
	var na := _tach_angle(rpm)
	var nd := Vector2.from_angle(na)
	var tip := c + nd * r * 0.88
	ci.draw_line(c - nd * r * 0.12, tip, Color(0, 0, 0, 0.5), maxf(4.0, r * 0.05) + 2.0, true)
	ci.draw_line(c - nd * r * 0.12, tip, UI.EMBER.lightened(0.2), maxf(3.0, r * 0.04), true)
	ci.draw_circle(c, r * 0.08, Color(0.2, 0.18, 0.2))
	ci.draw_circle(c, r * 0.05, UI.GOLD)
	if nos:
		ci.draw_arc(c, r + 1.0, 0.0, TAU, 48, Color(NOS_BLUE, 0.5 + 0.3 * sin(t * 20.0)), 4.0, true)
