class_name CardArt
extends RefCounted
## Procedural card faces and backs for the graveyard card duel. Works for any
## card rect from about 40 to 200 px wide (cards are 1.4 times taller than wide).
##
## draw_card(ci, rect, id, opts) - opts: "white" (bool, tints the player's
## chess-piece monsters, default true), "atk" (int, shown instead of the
## printed ATK), "t" (float, animation time), "dim" (bool).

const ASPECT := 1.4
const INK := Color(0.10, 0.07, 0.06)
const PARCHMENT := Color(0.93, 0.88, 0.76)


# --- small helpers ------------------------------------------------------------------

static func rrect_points(r: Rect2, rad: float, seg: int = 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# keep the corner arcs from touching (duplicate points break triangulation)
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5 - 0.5)
	if rad < 0.5:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var corners := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	var start := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in 4:
		for i in seg + 1:
			var a: float = start[c] + PI * 0.5 * i / seg
			pts.append(corners[c] + Vector2(cos(a), sin(a)) * rad)
	return pts


static func fill_rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	if r.size.x < 1.0 or r.size.y < 1.0:
		return
	ci.draw_colored_polygon(rrect_points(r, rad), col)


## Draws a polygon unless it is a degenerate sliver (clipping can produce
## those, and the renderer refuses to triangulate them).
static func safe_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var area := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	if absf(area) < 2.0:
		return
	ci.draw_colored_polygon(pts, col)


static func line_rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color, w: float) -> void:
	var pts := rrect_points(r, rad)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, w, true)


static func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func _fit_size(text: String, max_w: float, size: int, min_size: int = 7) -> int:
	var font := ThemeDB.fallback_font
	var s := size
	while s > min_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 1
	return s


## Shrinks, then shortens with an ellipsis, until text fits max_w. Returns [text, size].
static func _fit_text(text: String, max_w: float, size: int, min_size: int) -> Array:
	var font := ThemeDB.fallback_font
	var s := _fit_size(text, max_w, size, min_size)
	var out := text
	while out.length() > 2 and font.get_string_size(out, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		out = out.substr(0, out.length() - 2).strip_edges() + "…"
	return [out, s]


static func _text_c(ci: CanvasItem, center: Vector2, text: String, size: int, col: Color, max_w: float = -1.0) -> void:
	var font := ThemeDB.fallback_font
	var s := size if max_w <= 0.0 else _fit_size(text, max_w, size)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s)
	ci.draw_string(font, Vector2(center.x - ts.x * 0.5, center.y + s * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


## Frame colours: [frame, frame_dark, trim, name_bar, name_ink].
static func _palette(id: String) -> Array:
	var monster := CardData.is_monster(id)
	match CardData.card_set(id):
		"chess":
			if monster:
				return [Color(0.20, 0.16, 0.18), Color(0.10, 0.08, 0.09), UI.GOLD, Color(0.17, 0.13, 0.14), UI.GOLD]
			return [Color(0.13, 0.36, 0.34), Color(0.06, 0.18, 0.17), UI.GOLD, Color(0.09, 0.22, 0.21), Color(0.95, 0.88, 0.66)]
		"booster":
			return [Color(0.40, 0.20, 0.52), Color(0.18, 0.08, 0.26), Color(0.95, 0.75, 1.0), Color(0.86, 0.80, 0.94), Color(0.20, 0.06, 0.26)]
	if monster:
		return [Color(0.78, 0.53, 0.27), Color(0.45, 0.28, 0.12), Color(0.35, 0.22, 0.10), PARCHMENT, INK]
	return [Color(0.15, 0.50, 0.44), Color(0.06, 0.26, 0.22), Color(0.07, 0.25, 0.22), PARCHMENT, INK]


# --- card face ---------------------------------------------------------------------------

static func draw_card(ci: CanvasItem, r: Rect2, id: String, opts: Dictionary = {}) -> void:
	var white: bool = opts.get("white", true)
	var t: float = opts.get("t", 0.0)
	var w := r.size.x
	var h := r.size.y
	var pal := _palette(id)
	var frame: Color = pal[0]
	var trim: Color = pal[2]
	var rad := w * 0.06
	# shadow and frame
	fill_rrect(ci, Rect2(r.position + Vector2(w * 0.03, w * 0.04), r.size), rad, Color(0, 0, 0, 0.45))
	fill_rrect(ci, r, rad, frame)
	_vgrad(ci, Rect2(r.position + Vector2(w * 0.04, h * 0.5), Vector2(w * 0.92, h * 0.46)), Color(frame, 0.0), Color(pal[1], 0.55))
	if CardData.card_set(id) == "booster":
		# holographic shimmer sweeping across the frame
		var k := fmod(t * 0.35 + r.position.x * 0.002, 1.0)
		var sx := r.position.x + (k * 1.6 - 0.3) * w
		var band := PackedVector2Array([Vector2(sx, r.position.y + 2), Vector2(sx + w * 0.18, r.position.y + 2),
			Vector2(sx - w * 0.12, r.end.y - 2), Vector2(sx - w * 0.3, r.end.y - 2)])
		var clipped := Geometry2D.intersect_polygons(band, rrect_points(r.grow(-2), rad))
		for poly in clipped:
			safe_poly(ci, poly, Color(1, 0.9, 1, 0.22))
	line_rrect(ci, r, rad, trim, maxf(1.0, w * 0.022))
	line_rrect(ci, r.grow(-w * 0.035), rad * 0.7, Color(0, 0, 0, 0.35), maxf(1.0, w * 0.01))
	var pad := w * 0.07
	var tiny := w < 64.0
	var big := w >= 175.0
	# name bar
	var name_r := Rect2(r.position + Vector2(pad, pad), Vector2(w - pad * 2.0, h * 0.11))
	var art_top := name_r.end.y + h * 0.02
	if tiny:
		art_top = r.position.y + pad
	else:
		ci.draw_rect(name_r, pal[3])
		ci.draw_rect(name_r, Color(0, 0, 0, 0.5), false, maxf(1.0, w * 0.01))
		var fs := int(clampf(w * 0.105, 7.0, 19.0))
		var fit := _fit_text(CardData.card_name(id), name_r.size.x - pad * 0.6, fs, 7)
		var nm: String = fit[0]
		var s: int = fit[1]
		var font := ThemeDB.fallback_font
		ci.draw_string(font, Vector2(name_r.position.x + pad * 0.3, name_r.get_center().y + s * 0.36), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, s, pal[4])
	# bottom strip and text box
	var foot_h := h * (0.13 if not tiny else 0.2)
	var foot := Rect2(r.position.x + pad, r.end.y - pad - foot_h, w - pad * 2.0, foot_h)
	var text_r := Rect2()
	var art_bottom := foot.position.y - h * 0.02
	if big:
		text_r = Rect2(foot.position.x, foot.position.y - h * 0.2, foot.size.x, h * 0.19)
		art_bottom = text_r.position.y - h * 0.015
	var art_r := Rect2(r.position.x + pad, art_top, w - pad * 2.0, art_bottom - art_top)
	ci.draw_rect(art_r.grow(maxf(1.0, w * 0.012)), Color(0, 0, 0, 0.6))
	draw_illustration(ci, art_r, id, white, t)
	if big:
		ci.draw_rect(text_r, Color(pal[3], 0.92))
		var font2 := ThemeDB.fallback_font
		var ts := int(clampf(w * 0.062, 9.0, 13.0))
		ci.draw_multiline_string(font2, text_r.position + Vector2(4, ts + 2), CardData.card_text(id), HORIZONTAL_ALIGNMENT_LEFT,
			text_r.size.x - 8, ts, 4, pal[4])
	# ATK or SPELL
	if CardData.is_monster(id):
		var atk_v: int = opts.get("atk", CardData.atk(id))
		var fs2 := int(clampf(w * (0.2 if tiny else 0.15), 9.0, 28.0))
		var txt := str(atk_v)
		var col := Color(1, 0.95, 0.85)
		if atk_v > CardData.atk(id):
			col = Color(0.6, 1.0, 0.6)
		ci.draw_rect(foot, Color(0, 0, 0, 0.55))
		if not tiny:
			var ls := int(clampf(w * 0.075, 7.0, 13.0))
			ci.draw_string(ThemeDB.fallback_font, Vector2(foot.position.x + pad * 0.3, foot.get_center().y + ls * 0.36), "ATK", HORIZONTAL_ALIGNMENT_LEFT, -1, ls, UI.GOLD)
			var font3 := ThemeDB.fallback_font
			var tw := font3.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			ci.draw_string_outline(font3, Vector2(foot.end.x - tw - pad * 0.3, foot.get_center().y + fs2 * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 3, Color(0, 0, 0, 0.8))
			ci.draw_string(font3, Vector2(foot.end.x - tw - pad * 0.3, foot.get_center().y + fs2 * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, col)
		else:
			_text_c(ci, foot.get_center(), txt, fs2, col, foot.size.x)
	else:
		ci.draw_rect(foot, Color(0, 0, 0, 0.4))
		var label := "SPELL" if not tiny else "SP"
		_text_c(ci, foot.get_center(), label, int(clampf(w * 0.12, 8.0, 20.0)), Color(0.7, 1.0, 0.92), foot.size.x)
	if opts.get("dim", false):
		fill_rrect(ci, r, rad, Color(0, 0, 0, 0.45))


static func draw_back(ci: CanvasItem, r: Rect2, t: float = 0.0) -> void:
	var w := r.size.x
	var rad := w * 0.06
	fill_rrect(ci, Rect2(r.position + Vector2(w * 0.03, w * 0.04), r.size), rad, Color(0, 0, 0, 0.45))
	fill_rrect(ci, r, rad, Color(0.22, 0.10, 0.13))
	var inner := r.grow(-w * 0.08)
	_vgrad(ci, inner, Color(0.30, 0.12, 0.20), Color(0.12, 0.05, 0.10))
	var c := r.get_center()
	# a slow golden vortex
	for i in 5:
		var k := 1.0 - i * 0.17
		var pts := PackedVector2Array()
		for j in 33:
			var a := TAU * j / 32.0
			pts.append(c + Vector2(cos(a) * inner.size.x * 0.44 * k, sin(a) * inner.size.y * 0.42 * k).rotated(t * 0.2 * (1 if i % 2 == 0 else -1) + i * 0.4))
		ci.draw_polyline(pts, Color(UI.GOLD, 0.25 + 0.1 * i), maxf(1.0, w * 0.012), true)
	var oval := PackedVector2Array()
	for j in 32:
		var a2 := TAU * j / 32.0
		oval.append(c + Vector2(cos(a2) * inner.size.x * 0.22, sin(a2) * inner.size.y * 0.24))
	ci.draw_colored_polygon(oval, Color(0.08, 0.03, 0.06))
	PieceArt.draw_piece(ci, 1, false, c.x, c.y + inner.size.y * 0.16, inner.size.y * 0.33, Color(1, 0.85, 0.55), false)
	line_rrect(ci, r, rad, UI.GOLD, maxf(1.0, w * 0.022))
	line_rrect(ci, inner, rad * 0.6, Color(UI.GOLD, 0.6), maxf(1.0, w * 0.012))


# --- illustrations -----------------------------------------------------------------------
# Each picture is drawn in a square `q` centred in the art box; coordinates are 0..1.

static func _q(a: Rect2) -> Rect2:
	var s := minf(a.size.x, a.size.y)
	return Rect2(a.get_center() - Vector2(s, s) * 0.5, Vector2(s, s))


static func _p(q: Rect2, x: float, y: float) -> Vector2:
	return q.position + Vector2(x, y) * q.size.x


static func _pts(q: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in pts:
		out.append(_p(q, v.x, v.y))
	return out


static func _shape(ci: CanvasItem, q: Rect2, pts: Array, fill: Color, line: Color = INK, lw: float = 0.018) -> void:
	var p := _pts(q, pts)
	ci.draw_colored_polygon(p, fill)
	if line.a > 0.0:
		var cl := p.duplicate()
		cl.append(p[0])
		ci.draw_polyline(cl, line, maxf(1.0, q.size.x * lw), true)


static func _circ(ci: CanvasItem, q: Rect2, x: float, y: float, rr: float, fill: Color, line: Color = INK, lw: float = 0.018) -> void:
	ci.draw_circle(_p(q, x, y), rr * q.size.x, fill)
	if line.a > 0.0:
		ci.draw_arc(_p(q, x, y), rr * q.size.x, 0, TAU, 24, line, maxf(1.0, q.size.x * lw), true)


static func _ell(q: Rect2, x: float, y: float, rx: float, ry: float, n: int = 24, rot: float = 0.0) -> Array:
	var out: Array = []
	for i in n:
		var a := TAU * i / n
		out.append(Vector2(x, y) + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out


static func _ln(ci: CanvasItem, q: Rect2, x1: float, y1: float, x2: float, y2: float, col: Color, lw: float = 0.02) -> void:
	ci.draw_line(_p(q, x1, y1), _p(q, x2, y2), col, maxf(1.0, q.size.x * lw), true)


static func _eyes(ci: CanvasItem, q: Rect2, x: float, y: float, gap: float, rr: float, look: Vector2 = Vector2.ZERO) -> void:
	for sx in [-1.0, 1.0]:
		_circ(ci, q, x + sx * gap, y, rr, Color(1, 1, 1), INK, 0.012)
		_circ(ci, q, x + sx * gap + look.x * rr * 0.4, y + look.y * rr * 0.4, rr * 0.5, INK, Color(0, 0, 0, 0))
		_circ(ci, q, x + sx * gap + look.x * rr * 0.4 - rr * 0.18, y + look.y * rr * 0.4 - rr * 0.2, rr * 0.16, Color(1, 1, 1), Color(0, 0, 0, 0))


static func draw_illustration(ci: CanvasItem, a: Rect2, id: String, white: bool = true, t: float = 0.0) -> void:
	var bg := CardData.color(id)
	_vgrad(ci, a, bg.lightened(0.18), bg.darkened(0.45))
	var q := _q(a)
	match CardData.art(id):
		"piece":
			_floor(ci, a, bg)
			var pt := CardData.piece_type(id)
			var s := minf(a.size.y * 0.8 / PieceArt.height(pt), a.size.x * 0.85 / 0.62)
			PieceArt.draw_piece(ci, pt, white, a.get_center().x, a.end.y - a.size.y * 0.1, s)
		"sorcerer":
			_sorcerer(ci, q, t)
		"skull":
			_skull(ci, q, t)
		"sandal":
			_sandal(ci, q)
		"gazelle":
			_gazelle(ci, q, t)
		"hedge":
			_hedge(ci, q)
		"pebble":
			_pebble(ci, q)
		"teapot":
			_teapot(ci, q, t)
		"beaver":
			_beaver(ci, q)
		"fuzzball":
			_fuzzball(ci, q, t)
		"dragon":
			_dragon(ci, q, t)
		"beyblade":
			_beyblade(ci, q, t)
		"promotion":
			_rays(ci, q, Color(1, 0.85, 0.4, 0.25), t, a)
			PieceArt.draw_piece(ci, 1, white, _p(q, 0.5, 0).x, _p(q, 0, 0.92).y, q.size.x * 0.62)
			_crown(ci, q, 0.5, 0.2 + sin(t * 3.0) * 0.02, 0.2)
		"checkmate":
			_checkmate(ci, q, white)
		"en_passant":
			_floor(ci, a, bg)
			PieceArt.draw_piece(ci, 1, not white, _p(q, 0.34, 0).x, _p(q, 0, 0.85).y, q.size.x * 0.5)
			PieceArt.draw_piece(ci, 1, white, _p(q, 0.68, 0).x, _p(q, 0, 0.62).y, q.size.x * 0.5)
			for i in 4:
				var k := i / 4.0
				_ln(ci, q, 0.62 - k * 0.3, 0.3 + k * 0.3, 0.62 - (k + 0.12) * 0.3, 0.3 + (k + 0.12) * 0.3, Color(1, 0.9, 0.5), 0.035)
			_shape(ci, q, [Vector2(0.27, 0.62), Vector2(0.37, 0.6), Vector2(0.3, 0.52)], Color(1, 0.9, 0.5), Color(0, 0, 0, 0))
		"fifty_move":
			_hourglass(ci, q, t)
		"pot":
			_pot(ci, q, t)
		"swords":
			_rays(ci, q, Color(1, 1, 0.8, 0.12), t, a)
			_swords(ci, q, t)
		"rerun":
			_rerun(ci, q, t)
		"driveby":
			_car(ci, q, t, Color(0.92, 0.35, 0.62))
		"sniper":
			_sniper(ci, q, t)
		"double_move":
			_espresso(ci, q, t)
		"pink_slip":
			_pink_slip(ci, q)
		"zugzwang":
			_clock(ci, q, t)


static func _floor(ci: CanvasItem, a: Rect2, bg: Color) -> void:
	# a strip of chessboard in perspective along the bottom of the art box
	var y0 := a.end.y - a.size.y * 0.24
	var rows := 3
	for rr in rows:
		var ya := lerpf(y0, a.end.y, float(rr) / rows)
		var yb := lerpf(y0, a.end.y, float(rr + 1) / rows)
		var cols := 6
		for c in cols:
			var spread_a := 0.7 + 0.3 * float(rr) / rows
			var spread_b := 0.7 + 0.3 * float(rr + 1) / rows
			var cx := a.get_center().x
			var xa0 := cx + (lerpf(a.position.x, a.end.x, float(c) / cols) - cx) * spread_a
			var xa1 := cx + (lerpf(a.position.x, a.end.x, float(c + 1) / cols) - cx) * spread_a
			var xb0 := cx + (lerpf(a.position.x, a.end.x, float(c) / cols) - cx) * spread_b
			var xb1 := cx + (lerpf(a.position.x, a.end.x, float(c + 1) / cols) - cx) * spread_b
			var col := Color(1, 1, 1, 0.13) if (rr + c) % 2 == 0 else Color(0, 0, 0, 0.22)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(xa0, ya), Vector2(xa1, ya), Vector2(xb1, yb), Vector2(xb0, yb)]), col)


static func _rays(ci: CanvasItem, q: Rect2, col: Color, t: float, clip: Rect2) -> void:
	var c := _p(q, 0.5, 0.45)
	var box := PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)])
	for i in 10:
		var ang := TAU * i / 10.0 + t * 0.3
		var ray := PackedVector2Array([c, c + Vector2.from_angle(ang - 0.12) * q.size.x, c + Vector2.from_angle(ang + 0.12) * q.size.x])
		for poly in Geometry2D.intersect_polygons(ray, box):
			safe_poly(ci, poly, col)


static func _crown(ci: CanvasItem, q: Rect2, x: float, y: float, s: float) -> void:
	var pts := [Vector2(-1, 0.5), Vector2(1, 0.5), Vector2(1.1, -0.4), Vector2(0.55, 0.05), Vector2(0, -0.6), Vector2(-0.55, 0.05), Vector2(-1.1, -0.4)]
	var out: Array = []
	for v in pts:
		out.append(Vector2(x, y) + v * s * 0.5)
	_shape(ci, q, out, Color(1.0, 0.8, 0.25), INK, 0.014)
	_circ(ci, q, x, y + s * 0.1, s * 0.07, Color(0.85, 0.15, 0.2), Color(0, 0, 0, 0))


static func _sorcerer(ci: CanvasItem, q: Rect2, t: float) -> void:
	# magic circle
	for i in 2:
		ci.draw_arc(_p(q, 0.5, 0.55), q.size.x * (0.4 - i * 0.07), t * (0.6 if i == 0 else -0.8), t * (0.6 if i == 0 else -0.8) + TAU * 0.8, 28, Color(0.75, 0.5, 1.0, 0.45), maxf(1.0, q.size.x * 0.015), true)
	# robe
	_shape(ci, q, [Vector2(0.5, 0.42), Vector2(0.74, 0.98), Vector2(0.26, 0.98)], Color(0.38, 0.16, 0.62))
	_shape(ci, q, [Vector2(0.5, 0.46), Vector2(0.58, 0.98), Vector2(0.42, 0.98)], Color(0.55, 0.3, 0.78), Color(0, 0, 0, 0))
	# face
	_circ(ci, q, 0.5, 0.42, 0.075, Color(0.62, 0.72, 0.85))
	_ln(ci, q, 0.46, 0.41, 0.485, 0.425, INK, 0.015)
	_ln(ci, q, 0.54, 0.41, 0.515, 0.425, INK, 0.015)
	# spiky hat
	_shape(ci, q, [Vector2(0.38, 0.38), Vector2(0.62, 0.38), Vector2(0.66, 0.3), Vector2(0.6, 0.27), Vector2(0.7, 0.06),
		Vector2(0.55, 0.22), Vector2(0.5, 0.02), Vector2(0.45, 0.22), Vector2(0.3, 0.06), Vector2(0.4, 0.27), Vector2(0.34, 0.3)], Color(0.3, 0.12, 0.5))
	_ln(ci, q, 0.38, 0.36, 0.62, 0.36, Color(1.0, 0.8, 0.3), 0.025)
	# staff with an orb
	_ln(ci, q, 0.78, 0.3, 0.74, 0.98, Color(0.45, 0.3, 0.16), 0.03)
	var glow := 0.5 + 0.5 * sin(t * 4.0)
	_circ(ci, q, 0.785, 0.27, 0.07 + glow * 0.015, Color(0.5, 1.0, 0.7, 0.35), Color(0, 0, 0, 0))
	_circ(ci, q, 0.785, 0.27, 0.045, Color(0.55, 1.0, 0.75))


static func _skull(ci: CanvasItem, q: Rect2, t: float) -> void:
	for i in 3:
		var x := 0.2 + i * 0.3
		_ln(ci, q, x, 0.05, x + 0.06 * sin(t * 7.0 + i), 0.3, Color(0.75, 0.55, 1.0, 0.6), 0.015)
	_shape(ci, q, [Vector2(0.3, 0.32), Vector2(0.1, 0.12), Vector2(0.2, 0.36)], Color(0.85, 0.8, 0.7))
	_shape(ci, q, [Vector2(0.7, 0.32), Vector2(0.9, 0.12), Vector2(0.8, 0.36)], Color(0.85, 0.8, 0.7))
	_shape(ci, q, _ell(q, 0.5, 0.48, 0.24, 0.22), Color(0.92, 0.88, 0.78))
	_shape(ci, q, [Vector2(0.36, 0.62), Vector2(0.64, 0.62), Vector2(0.6, 0.86), Vector2(0.4, 0.86)], Color(0.92, 0.88, 0.78))
	var eye := Color(1.0, 0.3 + 0.2 * sin(t * 5.0), 0.2)
	_shape(ci, q, _ell(q, 0.41, 0.5, 0.06, 0.05), INK, Color(0, 0, 0, 0))
	_shape(ci, q, _ell(q, 0.59, 0.5, 0.06, 0.05), INK, Color(0, 0, 0, 0))
	_circ(ci, q, 0.41, 0.5, 0.022, eye, Color(0, 0, 0, 0))
	_circ(ci, q, 0.59, 0.5, 0.022, eye, Color(0, 0, 0, 0))
	_shape(ci, q, [Vector2(0.5, 0.56), Vector2(0.53, 0.62), Vector2(0.47, 0.62)], INK, Color(0, 0, 0, 0))
	for i in 5:
		_ln(ci, q, 0.4 + i * 0.05, 0.7, 0.4 + i * 0.05, 0.84, INK, 0.012)


static func _sandal(ci: CanvasItem, q: Rect2) -> void:
	_shape(ci, q, _ell(q, 0.5, 0.72, 0.36, 0.13, 28, -0.12), Color(0.55, 0.38, 0.2))
	_shape(ci, q, _ell(q, 0.5, 0.67, 0.34, 0.11, 28, -0.12), Color(0.72, 0.55, 0.32))
	# bandaged straps
	for s in [[0.3, 0.68, 0.42, 0.42], [0.5, 0.64, 0.5, 0.36], [0.68, 0.6, 0.6, 0.38]]:
		_ln(ci, q, s[0], s[1], s[2], s[3], Color(0.93, 0.9, 0.82), 0.07)
		_ln(ci, q, s[0], s[1], s[2], s[3], Color(0.6, 0.55, 0.45), 0.012)
	_shape(ci, q, _ell(q, 0.5, 0.38, 0.16, 0.08), Color(0.93, 0.9, 0.82))
	for i in 3:
		_ln(ci, q, 0.38 + i * 0.1, 0.33, 0.42 + i * 0.1, 0.44, Color(0.6, 0.55, 0.45), 0.01)
	_eyes(ci, q, 0.5, 0.37, 0.065, 0.045, Vector2(0.5, 0.3))
	for i in 3:
		_ln(ci, q, 0.12 + i * 0.05, 0.25 + i * 0.03, 0.18 + i * 0.05, 0.2 + i * 0.03, Color(0.95, 0.85, 0.6, 0.6), 0.012)


static func _gazelle(ci: CanvasItem, q: Rect2, t: float) -> void:
	# a mismatched wing on its back
	var flap := sin(t * 5.0) * 0.04
	_shape(ci, q, [Vector2(0.48, 0.52), Vector2(0.15, 0.15 + flap), Vector2(0.27, 0.32 + flap), Vector2(0.22, 0.35 + flap),
		Vector2(0.36, 0.44 + flap * 0.5), Vector2(0.31, 0.47 + flap * 0.5)], Color(0.92, 0.92, 0.95))
	for leg in [0.32, 0.4, 0.62, 0.7]:
		_ln(ci, q, leg, 0.6, leg + 0.01, 0.92, Color(0.6, 0.42, 0.2), 0.03)
	_shape(ci, q, _ell(q, 0.5, 0.58, 0.24, 0.1), Color(0.78, 0.58, 0.3))
	_shape(ci, q, [Vector2(0.66, 0.54), Vector2(0.72, 0.3), Vector2(0.78, 0.32), Vector2(0.74, 0.56)], Color(0.78, 0.58, 0.3))
	_shape(ci, q, _ell(q, 0.78, 0.28, 0.08, 0.05, 20, 0.4), Color(0.8, 0.6, 0.32))
	# spiral horns
	for h in [0.0, 0.05]:
		var pts := PackedVector2Array()
		for i in 12:
			var k := i / 11.0
			pts.append(_p(q, 0.74 + h + sin(k * 9.0) * 0.02, 0.24 - k * 0.2))
		ci.draw_polyline(pts, Color(0.3, 0.22, 0.14), maxf(1.0, q.size.x * 0.022), true)
	_circ(ci, q, 0.8, 0.27, 0.014, INK, Color(0, 0, 0, 0))
	_shape(ci, q, [Vector2(0.27, 0.52), Vector2(0.18, 0.62), Vector2(0.26, 0.58)], Color(0.6, 0.42, 0.2))


static func _hedge(ci: CanvasItem, q: Rect2) -> void:
	# the hedge
	var greens := [Color(0.16, 0.42, 0.18), Color(0.22, 0.52, 0.22), Color(0.12, 0.34, 0.14)]
	for i in 9:
		var x := 0.18 + (i % 5) * 0.16
		var y := 0.68 + floorf(i / 5.0) * 0.12
		_circ(ci, q, x, y, 0.13, greens[i % 3], Color(0.05, 0.18, 0.06), 0.012)
	# the elf guarding it
	_shape(ci, q, [Vector2(0.42, 0.38), Vector2(0.6, 0.38), Vector2(0.64, 0.66), Vector2(0.38, 0.66)], Color(0.3, 0.55, 0.3))
	_circ(ci, q, 0.51, 0.3, 0.075, Color(0.98, 0.85, 0.7))
	_shape(ci, q, [Vector2(0.43, 0.29), Vector2(0.38, 0.22), Vector2(0.45, 0.25)], Color(0.98, 0.85, 0.7))
	_shape(ci, q, [Vector2(0.59, 0.29), Vector2(0.65, 0.22), Vector2(0.58, 0.25)], Color(0.98, 0.85, 0.7))
	_shape(ci, q, [Vector2(0.43, 0.27), Vector2(0.59, 0.27), Vector2(0.53, 0.08)], Color(0.15, 0.45, 0.2))
	_circ(ci, q, 0.48, 0.31, 0.012, INK, Color(0, 0, 0, 0))
	_circ(ci, q, 0.54, 0.31, 0.012, INK, Color(0, 0, 0, 0))
	# sword raised
	_ln(ci, q, 0.66, 0.5, 0.82, 0.14, Color(0.85, 0.88, 0.95), 0.03)
	_ln(ci, q, 0.62, 0.46, 0.7, 0.54, Color(0.8, 0.6, 0.2), 0.03)


static func _pebble(ci: CanvasItem, q: Rect2) -> void:
	# a huge pebble... for a pebble
	_ln(ci, q, 0.1, 0.88, 0.9, 0.88, Color(0, 0, 0, 0.35), 0.02)
	_ln(ci, q, 0.42, 0.78, 0.4, 0.88, INK, 0.025)
	_ln(ci, q, 0.58, 0.78, 0.6, 0.88, INK, 0.025)
	_shape(ci, q, _ell(q, 0.5, 0.62, 0.2, 0.17, 18, 0.2), Color(0.6, 0.6, 0.62))
	_circ(ci, q, 0.44, 0.56, 0.03, Color(0.7, 0.7, 0.72), Color(0, 0, 0, 0))
	_shape(ci, q, _ell(q, 0.5, 0.44, 0.13, 0.06), Color(0.45, 0.45, 0.5))
	_circ(ci, q, 0.45, 0.6, 0.014, INK, Color(0, 0, 0, 0))
	_circ(ci, q, 0.55, 0.6, 0.014, INK, Color(0, 0, 0, 0))
	_ln(ci, q, 0.46, 0.67, 0.54, 0.67, INK, 0.012)
	_shape(ci, q, _ell(q, 0.26, 0.64, 0.07, 0.1), Color(0.55, 0.4, 0.25))
	_ln(ci, q, 0.72, 0.68, 0.84, 0.4, Color(0.7, 0.72, 0.78), 0.02)


static func _teapot(ci: CanvasItem, q: Rect2, t: float) -> void:
	var flap := sin(t * 8.0) * 0.06
	for sx in [-1.0, 1.0]:
		_shape(ci, q, [Vector2(0.5 + sx * 0.12, 0.5), Vector2(0.5 + sx * 0.44, 0.24 + flap), Vector2(0.5 + sx * 0.38, 0.4 + flap),
			Vector2(0.5 + sx * 0.42, 0.44 + flap), Vector2(0.5 + sx * 0.3, 0.56)], Color(0.97, 0.97, 1.0))
	_shape(ci, q, [Vector2(0.68, 0.6), Vector2(0.86, 0.42), Vector2(0.9, 0.46), Vector2(0.74, 0.7)], Color(0.35, 0.55, 0.8))
	_ln(ci, q, 0.26, 0.52, 0.18, 0.66, Color(0.35, 0.55, 0.8), 0.04)
	_shape(ci, q, _ell(q, 0.48, 0.64, 0.22, 0.17), Color(0.42, 0.62, 0.88))
	_shape(ci, q, _ell(q, 0.48, 0.48, 0.12, 0.04), Color(0.35, 0.55, 0.8))
	_circ(ci, q, 0.48, 0.43, 0.03, Color(0.35, 0.55, 0.8))
	_ln(ci, q, 0.34, 0.66, 0.62, 0.66, Color(1, 1, 1, 0.5), 0.02)
	for i in 3:
		var k := fmod(t * 0.6 + i * 0.33, 1.0)
		_circ(ci, q, 0.9 + sin(k * 6.0) * 0.03, 0.38 - k * 0.3, 0.02 + k * 0.03, Color(1, 1, 1, 0.5 * (1.0 - k)), Color(0, 0, 0, 0))


static func _beaver(ci: CanvasItem, q: Rect2) -> void:
	_shape(ci, q, _ell(q, 0.28, 0.82, 0.16, 0.07, 18, -0.4), Color(0.35, 0.22, 0.12))
	for i in 3:
		_ln(ci, q, 0.18 + i * 0.07, 0.78, 0.24 + i * 0.07, 0.88, Color(0.2, 0.12, 0.06), 0.01)
	_shape(ci, q, _ell(q, 0.52, 0.66, 0.18, 0.22), Color(0.55, 0.35, 0.18))
	_shape(ci, q, _ell(q, 0.52, 0.72, 0.1, 0.13), Color(0.75, 0.6, 0.42), Color(0, 0, 0, 0))
	_circ(ci, q, 0.52, 0.36, 0.13, Color(0.55, 0.35, 0.18))
	_circ(ci, q, 0.42, 0.25, 0.03, Color(0.45, 0.28, 0.14))
	_circ(ci, q, 0.62, 0.25, 0.03, Color(0.45, 0.28, 0.14))
	_circ(ci, q, 0.47, 0.33, 0.016, INK, Color(0, 0, 0, 0))
	_circ(ci, q, 0.57, 0.33, 0.016, INK, Color(0, 0, 0, 0))
	_circ(ci, q, 0.52, 0.39, 0.025, Color(0.2, 0.1, 0.06), Color(0, 0, 0, 0))
	_shape(ci, q, [Vector2(0.49, 0.43), Vector2(0.55, 0.43), Vector2(0.55, 0.49), Vector2(0.49, 0.49)], Color(1, 1, 0.92), INK, 0.01)
	# shield and sword
	_circ(ci, q, 0.3, 0.6, 0.12, Color(0.6, 0.6, 0.66))
	_circ(ci, q, 0.3, 0.6, 0.04, Color(0.85, 0.7, 0.3))
	_ln(ci, q, 0.7, 0.62, 0.86, 0.3, Color(0.85, 0.88, 0.95), 0.03)
	_ln(ci, q, 0.66, 0.58, 0.74, 0.66, Color(0.8, 0.6, 0.2), 0.03)


static func _fuzzball(ci: CanvasItem, q: Rect2, t: float) -> void:
	var bob := sin(t * 3.0) * 0.02
	var fur: Array = []
	var n := 26
	for i in n:
		var a := TAU * i / n
		var rr := 0.3 if i % 2 == 0 else 0.25
		fur.append(Vector2(0.5, 0.52 + bob) + Vector2(cos(a), sin(a)) * rr)
	_ln(ci, q, 0.36, 0.78 + bob, 0.32, 0.9, Color(0.4, 0.62, 0.3), 0.035)
	_ln(ci, q, 0.64, 0.78 + bob, 0.68, 0.9, Color(0.4, 0.62, 0.3), 0.035)
	_shape(ci, q, fur, Color(0.55, 0.36, 0.22))
	_shape(ci, q, _ell(q, 0.5, 0.52 + bob, 0.22, 0.2), Color(0.62, 0.42, 0.26), Color(0, 0, 0, 0))
	_eyes(ci, q, 0.5, 0.48 + bob, 0.085, 0.07, Vector2(0.0, 0.3))
	_circ(ci, q, 0.21, 0.56 + bob, 0.04, Color(0.4, 0.62, 0.3))
	_circ(ci, q, 0.79, 0.56 + bob, 0.04, Color(0.4, 0.62, 0.3))


static func _dragon(ci: CanvasItem, q: Rect2, t: float) -> void:
	var sway := sin(t * 1.6) * 0.03
	# wings
	_shape(ci, q, [Vector2(0.3, 0.75), Vector2(0.04, 0.5), Vector2(0.12, 0.62), Vector2(0.06, 0.68), Vector2(0.28, 0.84)], Color(0.2, 0.5, 0.55))
	# the long, long neck
	var neck := PackedVector2Array()
	var neck2 := PackedVector2Array()
	for i in 16:
		var k := i / 15.0
		var x := 0.36 + k * 0.34 + sin(k * 3.0) * 0.06 + sway * k
		var y := 0.82 - k * 0.66
		var wdt := 0.07 - k * 0.035
		neck.append(_p(q, x - wdt, y))
		neck2.append(_p(q, x + wdt, y))
	var poly := neck.duplicate()
	for i in range(neck2.size() - 1, -1, -1):
		poly.append(neck2[i])
	ci.draw_colored_polygon(poly, Color(0.25, 0.62, 0.62))
	var outline := poly.duplicate()
	outline.append(poly[0])
	ci.draw_polyline(outline, INK, maxf(1.0, q.size.x * 0.016), true)
	_shape(ci, q, _ell(q, 0.36, 0.86, 0.2, 0.09), Color(0.25, 0.62, 0.62))
	# head
	var hx := 0.7 + sway + sin(3.0) * 0.06
	_shape(ci, q, [Vector2(hx - 0.06, 0.2), Vector2(hx + 0.16, 0.18), Vector2(hx + 0.18, 0.22), Vector2(hx - 0.02, 0.26)], Color(0.3, 0.7, 0.68))
	_shape(ci, q, [Vector2(hx - 0.04, 0.17), Vector2(hx - 0.1, 0.06), Vector2(hx, 0.15)], Color(0.9, 0.85, 0.7))
	_circ(ci, q, hx + 0.03, 0.2, 0.015, Color(1, 0.85, 0.2), Color(0, 0, 0, 0))


static func _beyblade(ci: CanvasItem, q: Rect2, t: float) -> void:
	var spin := t * 14.0
	for i in 4:
		var k := 0.36 + i * 0.05
		ci.draw_arc(_p(q, 0.5, 0.6), q.size.x * k, spin + i, spin + i + 1.2, 12, Color(0.6, 0.85, 1.0, 0.4), maxf(1.0, q.size.x * 0.012), true)
	_shape(ci, q, _ell(q, 0.5, 0.62, 0.32, 0.1), Color(0.25, 0.4, 0.8))
	for i in 6:
		var a := spin + TAU * i / 6.0
		var p := Vector2(0.5 + cos(a) * 0.28, 0.62 + sin(a) * 0.08)
		_circ(ci, q, p.x, p.y, 0.025, Color(0.9, 0.9, 1.0), Color(0, 0, 0, 0))
	_shape(ci, q, _ell(q, 0.5, 0.56, 0.16, 0.06), Color(0.9, 0.3, 0.3))
	_shape(ci, q, [Vector2(0.46, 0.68), Vector2(0.54, 0.68), Vector2(0.5, 0.82)], Color(0.7, 0.7, 0.75))
	for i in 4:
		var sx := 0.2 + i * 0.2
		_ln(ci, q, sx, 0.86, sx + 0.05, 0.84 + 0.02 * sin(spin + i), Color(1.0, 0.85, 0.4), 0.012)


static func _checkmate(ci: CanvasItem, q: Rect2, white: bool) -> void:
	# the enemy king lies on its side
	var c := _p(q, 0.72, 0.9)
	ci.draw_set_transform(c, -1.05, Vector2.ONE)
	PieceArt.draw_piece(ci, 6, not white, 0, 0, q.size.x * 0.46, Color.WHITE, false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_ln(ci, q, 0.1, 0.92, 0.9, 0.92, Color(0, 0, 0, 0.4), 0.03)
	_ln(ci, q, 0.18, 0.12, 0.42, 0.42, Color(0.95, 0.2, 0.15), 0.06)
	_ln(ci, q, 0.42, 0.12, 0.18, 0.42, Color(0.95, 0.2, 0.15), 0.06)


static func _hourglass(ci: CanvasItem, q: Rect2, t: float) -> void:
	_shape(ci, q, [Vector2(0.28, 0.12), Vector2(0.72, 0.12), Vector2(0.72, 0.18), Vector2(0.28, 0.18)], Color(0.55, 0.38, 0.2))
	_shape(ci, q, [Vector2(0.28, 0.84), Vector2(0.72, 0.84), Vector2(0.72, 0.9), Vector2(0.28, 0.9)], Color(0.55, 0.38, 0.2))
	_shape(ci, q, [Vector2(0.33, 0.18), Vector2(0.67, 0.18), Vector2(0.53, 0.5), Vector2(0.67, 0.84), Vector2(0.33, 0.84), Vector2(0.47, 0.5)], Color(0.85, 0.92, 1.0, 0.35))
	var k := fmod(t * 0.15, 1.0)
	_shape(ci, q, [Vector2(0.38 + k * 0.08, 0.24 + k * 0.2), Vector2(0.62 - k * 0.08, 0.24 + k * 0.2), Vector2(0.5, 0.48)], Color(0.95, 0.8, 0.45), Color(0, 0, 0, 0))
	_shape(ci, q, [Vector2(0.5, 0.62 - k * 0.08), Vector2(0.64, 0.82), Vector2(0.36, 0.82)], Color(0.95, 0.8, 0.45), Color(0, 0, 0, 0))
	_ln(ci, q, 0.5, 0.5, 0.5, 0.8, Color(0.95, 0.8, 0.45), 0.012)
	var font := ThemeDB.fallback_font
	var fs := maxi(7, int(q.size.x * 0.17))
	var at := _p(q, 0.86, 0.56)
	var tw := font.get_string_size("50", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	ci.draw_string_outline(font, at - Vector2(tw * 0.5, -fs * 0.36), "50", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, fs / 5), Color(0, 0, 0, 0.8))
	ci.draw_string(font, at - Vector2(tw * 0.5, -fs * 0.36), "50", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.8))


static func _pot(ci: CanvasItem, q: Rect2, t: float) -> void:
	_shape(ci, q, [Vector2(0.36, 0.2), Vector2(0.64, 0.2), Vector2(0.6, 0.3), Vector2(0.78, 0.5), Vector2(0.74, 0.78),
		Vector2(0.6, 0.9), Vector2(0.4, 0.9), Vector2(0.26, 0.78), Vector2(0.22, 0.5), Vector2(0.4, 0.3)], Color(0.2, 0.6, 0.35))
	_shape(ci, q, _ell(q, 0.5, 0.2, 0.15, 0.04), Color(0.15, 0.45, 0.25))
	# the grin
	var g := 0.02 * sin(t * 4.0)
	_shape(ci, q, [Vector2(0.32, 0.6), Vector2(0.68, 0.6), Vector2(0.6, 0.74 + g), Vector2(0.4, 0.74 + g)], Color(0.15, 0.05, 0.05))
	for i in 5:
		_shape(ci, q, [Vector2(0.35 + i * 0.065, 0.6), Vector2(0.4 + i * 0.065, 0.6), Vector2(0.375 + i * 0.065, 0.66)], Color(1, 1, 0.92), Color(0, 0, 0, 0))
	_shape(ci, q, [Vector2(0.35, 0.44), Vector2(0.46, 0.48), Vector2(0.35, 0.5)], Color(1, 0.9, 0.3), INK, 0.01)
	_shape(ci, q, [Vector2(0.65, 0.44), Vector2(0.54, 0.48), Vector2(0.65, 0.5)], Color(1, 0.9, 0.3), INK, 0.01)


static func _swords(ci: CanvasItem, q: Rect2, t: float) -> void:
	for i in 3:
		var x := 0.25 + i * 0.25
		var drop := fmod(t * 0.3 + i * 0.3, 1.0) * 0.05
		var y := 0.12 + (0.1 if i == 1 else 0.0) + drop
		_shape(ci, q, [Vector2(x - 0.03, y), Vector2(x + 0.03, y), Vector2(x + 0.03, y + 0.5), Vector2(x, y + 0.6), Vector2(x - 0.03, y + 0.5)],
			Color(0.95, 0.97, 1.0), Color(0.5, 0.7, 1.0), 0.012)
		_ln(ci, q, x - 0.08, y, x + 0.08, y, Color(1.0, 0.82, 0.3), 0.03)
		_ln(ci, q, x, y - 0.1, x, y, Color(0.5, 0.32, 0.18), 0.03)


static func _rerun(ci: CanvasItem, q: Rect2, t: float) -> void:
	_shape(ci, q, [Vector2(0.36, 0.86), Vector2(0.36, 0.42), Vector2(0.42, 0.34), Vector2(0.58, 0.34), Vector2(0.64, 0.42), Vector2(0.64, 0.86)], Color(0.55, 0.55, 0.6))
	_ln(ci, q, 0.5, 0.44, 0.5, 0.64, INK, 0.02)
	_ln(ci, q, 0.44, 0.5, 0.56, 0.5, INK, 0.02)
	var a0 := t * 1.5
	ci.draw_arc(_p(q, 0.5, 0.55), q.size.x * 0.38, a0, a0 + TAU * 0.75, 30, Color(0.85, 0.5, 1.0), maxf(1.5, q.size.x * 0.04), true)
	var tip := _p(q, 0.5, 0.55) + Vector2.from_angle(a0 + TAU * 0.75) * q.size.x * 0.38
	var dir := Vector2.from_angle(a0 + TAU * 0.75 + PI * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([tip + dir * q.size.x * 0.08, tip + dir.rotated(2.3) * q.size.x * 0.07, tip + dir.rotated(-2.3) * q.size.x * 0.07]), Color(0.85, 0.5, 1.0))


static func _car(ci: CanvasItem, q: Rect2, t: float, col: Color) -> void:
	for i in 4:
		_ln(ci, q, 0.02, 0.5 + i * 0.07, 0.16 - i * 0.02, 0.5 + i * 0.07, Color(1, 1, 1, 0.4), 0.012)
	_shape(ci, q, [Vector2(0.12, 0.72), Vector2(0.14, 0.56), Vector2(0.3, 0.52), Vector2(0.4, 0.38), Vector2(0.7, 0.38),
		Vector2(0.8, 0.52), Vector2(0.92, 0.56), Vector2(0.92, 0.72)], col)
	_shape(ci, q, [Vector2(0.43, 0.42), Vector2(0.54, 0.42), Vector2(0.54, 0.52), Vector2(0.36, 0.52)], Color(0.7, 0.85, 1.0))
	_shape(ci, q, [Vector2(0.58, 0.42), Vector2(0.68, 0.42), Vector2(0.75, 0.52), Vector2(0.58, 0.52)], Color(0.7, 0.85, 1.0))
	# a pawn leans out of the window
	PieceArt.draw_piece(ci, 1, false, _p(q, 0.49, 0).x, _p(q, 0, 0.55).y, q.size.x * 0.26, Color.WHITE, false)
	for wx in [0.3, 0.75]:
		_circ(ci, q, wx, 0.74, 0.08, Color(0.12, 0.1, 0.1))
		var a := t * 12.0
		_ln(ci, q, wx + cos(a) * 0.05, 0.74 + sin(a) * 0.05, wx - cos(a) * 0.05, 0.74 - sin(a) * 0.05, Color(0.6, 0.6, 0.6), 0.015)


static func _sniper(ci: CanvasItem, q: Rect2, t: float) -> void:
	PieceArt.draw_piece(ci, 3, false, _p(q, 0.5, 0).x, _p(q, 0, 0.86).y, q.size.x * 0.48, Color(1, 1, 1, 0.9), false)
	var c := _p(q, 0.5 + sin(t * 1.3) * 0.03, 0.42 + cos(t * 1.7) * 0.03)
	var rr := q.size.x * 0.3
	var red := Color(1.0, 0.25, 0.2)
	ci.draw_arc(c, rr, 0, TAU, 32, red, maxf(1.0, q.size.x * 0.025), true)
	ci.draw_arc(c, rr * 0.45, 0, TAU, 24, Color(red, 0.6), maxf(1.0, q.size.x * 0.012), true)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		ci.draw_line(c + d * rr * 0.2, c + d * rr * 1.15, red, maxf(1.0, q.size.x * 0.016), true)
	ci.draw_circle(c, maxf(1.5, q.size.x * 0.018), red)


static func _espresso(ci: CanvasItem, q: Rect2, t: float) -> void:
	for i in 3:
		var pts := PackedVector2Array()
		for j in 10:
			var k := j / 9.0
			pts.append(_p(q, 0.38 + i * 0.1 + sin(k * 6.0 + t * 3.0 + i) * 0.025, 0.42 - k * 0.3))
		ci.draw_polyline(pts, Color(1, 1, 1, 0.45), maxf(1.0, q.size.x * 0.02), true)
	_shape(ci, q, _ell(q, 0.48, 0.86, 0.3, 0.06), Color(0.95, 0.93, 0.9))
	_shape(ci, q, [Vector2(0.28, 0.48), Vector2(0.68, 0.48), Vector2(0.62, 0.82), Vector2(0.34, 0.82)], Color(0.97, 0.95, 0.92))
	ci.draw_arc(_p(q, 0.7, 0.6), q.size.x * 0.07, -PI * 0.5, PI * 0.5, 12, INK, maxf(1.0, q.size.x * 0.03), true)
	_shape(ci, q, _ell(q, 0.48, 0.5, 0.19, 0.035), Color(0.35, 0.2, 0.1), Color(0, 0, 0, 0))
	_text_c(ci, _p(q, 0.48, 0.66), "x2", int(q.size.x * 0.17), Color(0.45, 0.25, 0.12))


static func _pink_slip(ci: CanvasItem, q: Rect2) -> void:
	ci.draw_set_transform(_p(q, 0.5, 0.5), -0.12, Vector2.ONE)
	var w := q.size.x * 0.8
	var h := q.size.x * 0.55
	ci.draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(1.0, 0.72, 0.82))
	ci.draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color(0.6, 0.25, 0.4), false, maxf(1.0, q.size.x * 0.012))
	for i in 3:
		ci.draw_line(Vector2(-w * 0.4, -h * 0.2 + i * h * 0.17), Vector2(w * 0.4, -h * 0.2 + i * h * 0.17), Color(0.6, 0.25, 0.4, 0.5), 1.0)
	var font := ThemeDB.fallback_font
	var fs := maxi(6, int(q.size.x * 0.1))
	ci.draw_string(font, Vector2(-w * 0.42, -h * 0.28), "TITLE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.5, 0.15, 0.3))
	ci.draw_polyline(PackedVector2Array([Vector2(w * 0.05, h * 0.36), Vector2(w * 0.12, h * 0.26), Vector2(w * 0.18, h * 0.36),
		Vector2(w * 0.26, h * 0.24), Vector2(w * 0.36, h * 0.34)]), Color(0.2, 0.2, 0.5), maxf(1.0, q.size.x * 0.012), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_shape(ci, q, [Vector2(0.18, 0.66), Vector2(0.2, 0.58), Vector2(0.3, 0.56), Vector2(0.36, 0.5), Vector2(0.5, 0.5), Vector2(0.56, 0.57), Vector2(0.6, 0.66)], Color(0.35, 0.6, 0.9))
	_circ(ci, q, 0.27, 0.67, 0.035, INK)
	_circ(ci, q, 0.52, 0.67, 0.035, INK)


static func _clock(ci: CanvasItem, q: Rect2, t: float) -> void:
	_shape(ci, q, [Vector2(0.1, 0.84), Vector2(0.9, 0.84), Vector2(0.84, 0.36), Vector2(0.16, 0.36)], Color(0.45, 0.3, 0.18))
	for i in 2:
		var cx := 0.32 + i * 0.36
		_circ(ci, q, cx, 0.58, 0.14, Color(0.96, 0.93, 0.85))
		var ang := t * (2.0 if i == 0 else 0.0) - PI * 0.5 + i * 2.0
		_ln(ci, q, cx, 0.58, cx + cos(ang) * 0.1, 0.58 + sin(ang) * 0.1, INK, 0.02)
		_shape(ci, q, [Vector2(cx - 0.04, 0.36), Vector2(cx + 0.04, 0.36), Vector2(cx + 0.04, 0.3), Vector2(cx - 0.04, 0.3)], Color(0.8, 0.2, 0.2) if i == 0 else Color(0.6, 0.6, 0.6))
	for i in 3:
		var k := fmod(t * 0.8 + i * 0.33, 1.0)
		_shape(ci, q, _ell(q, 0.86 + i * 0.03, 0.16 + k * 0.18, 0.018, 0.03), Color(0.6, 0.85, 1.0, 1.0 - k), Color(0, 0, 0, 0))
