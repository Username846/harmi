class_name AdScenes
extends RefCounted
## The "gameplay footage" in the fake ads: little procedural clips of games that
## don't exist, plus product shots. draw(ci, id, rect, t, ad) paints scene `id`
## filling `rect` at `t` seconds in, coloured by the ad's palette (ad.c).

const IDS := ["runner", "pull_pin", "match3", "merge", "idle", "hole", "stack", "racing", "shooter", "castle",
	"slots", "fishing", "word", "draw_save", "ball_sort", "chat", "food", "product", "slice", "cards",
	"jumper", "rope", "basket"]


static func draw(ci: CanvasItem, id: String, r: Rect2, t: float, ad: Dictionary) -> void:
	var c: Array = ad.get("c", [Color(0.4, 0.6, 1.0), Color(1.0, 0.5, 0.3), Color(1.0, 0.9, 0.3)])
	match id:
		"runner": _runner(ci, r, t, c, ad)
		"pull_pin": _pull_pin(ci, r, t, c)
		"match3": _match3(ci, r, t, c)
		"merge": _merge(ci, r, t, c)
		"idle": _idle(ci, r, t, c)
		"hole": _hole(ci, r, t, c)
		"stack": _stack(ci, r, t, c)
		"racing": _racing(ci, r, t, c)
		"shooter": _shooter(ci, r, t, c)
		"castle": _castle(ci, r, t, c)
		"slots": _slots(ci, r, t, c)
		"fishing": _fishing(ci, r, t, c)
		"word": _word(ci, r, t, c, String(ad.get("word", "CHESS")))
		"draw_save": _draw_save(ci, r, t, c)
		"ball_sort": _ball_sort(ci, r, t, c)
		"chat": _chat(ci, r, t, c, ad.get("chat", ["hi", "hello", "wanna play?"]))
		"food": _food(ci, r, t, c)
		"slice": _slice(ci, r, t, c)
		"cards": _cards(ci, r, t, c)
		"jumper": _jumper(ci, r, t, c)
		"rope": _rope(ci, r, t, c)
		"basket": _basket(ci, r, t, c)
		_: _product(ci, r, t, c, ad)


# --- helpers -----------------------------------------------------------------------

static func hash01(i: int, k: int = 0) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


static func text(ci: CanvasItem, s: String, center: Vector2, fs: int, col: Color, outline: int = 6, max_w: float = 0.0) -> void:
	if fs < 2 or s == "":
		return # still popping in
	var font := ThemeDB.fallback_font
	var size_px := fs
	if max_w > 0.0:
		while size_px > 10 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x > max_w:
			size_px -= 1
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var p := center + Vector2(-w * 0.5, size_px * 0.35)
	if outline > 0:
		ci.draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, outline, Color(0, 0, 0, 0.85 * col.a))
	ci.draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


## A white cartoon pointing hand, fingertip at p (every ad has one).
static func hand(ci: CanvasItem, p: Vector2, s: float, pressed: bool = false) -> void:
	var k := 0.9 if pressed else 1.0
	var palm := p + Vector2(s * 0.28, s * 0.62) * k
	var outline := Color(0.1, 0.1, 0.12)
	ci.draw_circle(palm, s * 0.3 + 2, outline)
	ci.draw_line(p, palm, outline, s * 0.2 + 4, true)
	ci.draw_circle(p, s * 0.1 + 2, outline)
	ci.draw_circle(palm, s * 0.3, Color(1, 1, 1))
	ci.draw_line(p, palm, Color(1, 1, 1), s * 0.2, true)
	ci.draw_circle(p, s * 0.1, Color(1, 1, 1))
	if pressed:
		ci.draw_arc(p, s * 0.25, 0, TAU, 20, Color(1, 1, 1, 0.7), 3.0, true)


static func sky(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func star(ci: CanvasItem, c: Vector2, rad: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := rot - PI / 2 + i * PI / 5
		pts.append(c + Vector2.from_angle(a) * (rad if i % 2 == 0 else rad * 0.45))
	ci.draw_colored_polygon(pts, col)


static func coin(ci: CanvasItem, c: Vector2, rad: float, spin: float) -> void:
	var w := absf(cos(spin))
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(c + Vector2(cos(a) * rad * maxf(0.15, w), sin(a) * rad))
	ci.draw_colored_polygon(pts, Color(0.75, 0.55, 0.1))
	for i in 16:
		pts[i] = c + (pts[i] - c) * 0.8
	ci.draw_colored_polygon(pts, Color(1.0, 0.85, 0.25))


## An app's icon: a rounded square in its colours with its initial.
static func app_icon(ci: CanvasItem, r: Rect2, a: Dictionary) -> void:
	var c: Array = a.get("c", [Color(0.4, 0.6, 1.0), Color(1, 0.5, 0.3), Color(1, 0.9, 0.3)])
	box(ci, r, c[0], r.size.x * 0.22)
	box(ci, Rect2(r.position + r.size * 0.12, r.size * 0.76), c[0].lightened(0.15), r.size.x * 0.18)
	if String(a.get("obj", "")) == "shield":
		product_shape(ci, "shield", r.get_center(), r.size.x * 0.8, 0.0, c)
		return
	text(ci, String(a.get("name", "?")).substr(0, 1), r.get_center(), int(r.size.y * 0.55), c[2], 5)


static func box(ci: CanvasItem, rect: Rect2, col: Color, rad: float = 8.0) -> void:
	CardArt.fill_rrect(ci, rect, rad, col)


static func pop(t: float, at: float) -> float:
	## 0 before `at`, overshoots to ~1.2 then settles at 1: for text that bounces in
	var k := t - at
	if k < 0.0:
		return 0.0
	return 1.0 + sin(minf(k * 9.0, PI)) * 0.25 * exp(-k * 3.0) if k > 0.12 else k / 0.12


# --- scenes ------------------------------------------------------------------------

static func _runner(ci: CanvasItem, r: Rect2, t: float, c: Array, ad: Dictionary) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.4), c[0])
	var hz := r.position.y + r.size.y * 0.3
	var cx := r.get_center().x
	var road := PackedVector2Array([Vector2(cx - u * 0.08, hz), Vector2(cx + u * 0.08, hz), Vector2(cx + u * 0.6, r.end.y), Vector2(cx - u * 0.6, r.end.y)])
	ci.draw_colored_polygon(road, Color(0.85, 0.85, 0.9))
	for i in 8:
		var z := fposmod(i / 8.0 + t * 0.6, 1.0)
		var y := lerpf(hz, r.end.y, z * z)
		ci.draw_line(Vector2(cx, y), Vector2(cx, y + 6 + z * 30), Color(1, 1, 1), 2 + z * 6)
	# gates rush toward you every 2 seconds: good on one side, bad on the other
	t = fposmod(t, 12.0)
	var phase := fposmod(t, 2.0) / 2.0
	var gy := lerpf(hz, r.end.y - u * 0.2, phase * phase)
	var gw := lerpf(u * 0.06, u * 0.5, phase * phase)
	var round_i := int(t / 2.0)
	var good: String = ["+10", "x2", "x3", "+25"][round_i % 4]
	var bad: String = ["-5", "÷2", "-20", "÷3"][round_i % 4]
	for side in [-1, 1]:
		var gx: float = cx + side * gw * 0.55
		var col: Color = Color(0.2, 0.6, 1.0, 0.55) if side == -1 else Color(1.0, 0.25, 0.2, 0.55)
		ci.draw_rect(Rect2(gx - gw * 0.5, gy - gw * 0.6, gw, gw * 0.6), col)
		text(ci, good if side == -1 else bad, Vector2(gx, gy - gw * 0.3), int(maxf(10, gw * 0.25)), Color(1, 1, 1), 4)
	# the crowd doubles every gate, dragged left by your thumb
	var count := mini(5 * int(pow(2, round_i)), 9999)
	var crowd_x := cx - u * 0.12 + sin(t * 1.3) * u * 0.05
	var crowd_y := r.end.y - u * 0.3
	var shown := mini(count, 60)
	var pawny := String(ad.get("name", "")).contains("Pawn")
	for i in shown:
		var a := hash01(i) * TAU
		var d := sqrt(hash01(i, 3)) * u * (0.03 + 0.08 * sqrt(shown / 60.0))
		var p := Vector2(crowd_x + cos(a) * d, crowd_y + sin(a) * d * 0.5 + sin(t * 14.0 + i) * 2.0)
		if pawny:
			PieceArt.draw_piece(ci, 1, true, p.x, p.y, u * 0.06, Color.WHITE, false)
		else:
			ci.draw_circle(p, u * 0.016, c[1].darkened(0.3))
			ci.draw_circle(p - Vector2(0, u * 0.022), u * 0.012, c[1])
	text(ci, str(count), Vector2(crowd_x, crowd_y - u * 0.16), int(u * 0.06), Color(1, 1, 1))
	hand(ci, Vector2(crowd_x + u * 0.1, crowd_y + u * 0.02), u * 0.1, true)


static func _pull_pin(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.3), c[0].darkened(0.2))
	var k := fposmod(t, 4.5)
	var tube := Rect2(r.get_center() - Vector2(u * 0.22, u * 0.42), Vector2(u * 0.44, u * 0.84))
	box(ci, tube, Color(0.85, 0.95, 1.0, 0.25), u * 0.05)
	CardArt.line_rrect(ci, tube, u * 0.05, Color(1, 1, 1, 0.9), 4.0)
	var pin_y := [tube.position.y + tube.size.y * 0.32, tube.position.y + tube.size.y * 0.62]
	# the wrong pin comes out: the lava drops onto the gold, then the hero
	var pulled := clampf((k - 1.0) / 0.5, 0.0, 1.0)
	var fall := clampf((k - 1.5) / 1.2, 0.0, 1.0)
	for i in 2:
		var off := pulled * u * 0.5 if i == 1 else 0.0
		var y: float = pin_y[i]
		ci.draw_rect(Rect2(tube.position.x - u * 0.04 + off, y - u * 0.015, tube.size.x + u * 0.04, u * 0.03), Color(0.85, 0.85, 0.9))
		ci.draw_arc(Vector2(tube.end.x + u * 0.05 + off, y), u * 0.04, 0, TAU, 20, Color(0.85, 0.85, 0.9), u * 0.018)
	for i in 14:
		var base := Vector2(tube.position.x + tube.size.x * (0.15 + 0.7 * hash01(i)), tube.position.y + tube.size.y * (0.08 + 0.2 * hash01(i, 1)))
		var dropped := base + Vector2(0, tube.size.y * 0.56 * fall * fall)
		ci.draw_circle(dropped, u * 0.035, c[1].lerp(Color(1, 0.9, 0.2), hash01(i, 2) * 0.5))
	for i in 8:
		var gp := Vector2(tube.position.x + tube.size.x * (0.2 + 0.6 * hash01(i, 5)), pin_y[0] + tube.size.y * (0.08 + 0.15 * hash01(i, 6)))
		if fall < 0.5:
			coin(ci, gp, u * 0.025, t * 3.0 + i)
	# the hero at the bottom
	var hero := Vector2(tube.get_center().x, tube.end.y - u * 0.1)
	var burnt := fall >= 1.0
	var skin := Color(0.25, 0.1, 0.05) if burnt else Color(1.0, 0.85, 0.7)
	ci.draw_circle(hero - Vector2(0, u * 0.06), u * 0.035, skin)
	ci.draw_line(hero - Vector2(0, u * 0.03), hero + Vector2(0, u * 0.04), skin, u * 0.02)
	ci.draw_line(hero, hero + Vector2(-u * 0.04, -u * 0.03 if burnt else u * 0.02), skin, u * 0.012)
	ci.draw_line(hero, hero + Vector2(u * 0.04, -u * 0.03 if burnt else u * 0.02), skin, u * 0.012)
	if k < 1.4:
		hand(ci, Vector2(tube.end.x + u * 0.05 + pulled * u * 0.5, pin_y[1]), u * 0.12, k > 0.9)
	if burnt:
		var s := pop(k, 2.8)
		text(ci, "FAIL", r.get_center() + Vector2(0, -u * 0.05), int(u * 0.16 * s), Color(1, 0.2, 0.15), 10)


static func _gem(ci: CanvasItem, p: Vector2, s: float, kind: int, c: Array) -> void:
	var cols := [c[0], c[1], c[2], Color(0.3, 0.9, 0.4), Color(1.0, 0.4, 0.3)]
	var col: Color = cols[kind % cols.size()]
	match kind % 3:
		0:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), col)
		1:
			ci.draw_circle(p, s * 0.85, col)
		_:
			star(ci, p, s, col)
	ci.draw_circle(p - Vector2(s * 0.3, s * 0.3), s * 0.18, Color(1, 1, 1, 0.7))


static func _match3(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].darkened(0.4), c[1].darkened(0.5))
	var n := 7
	var cell := u * 0.8 / n
	var o := r.get_center() - Vector2(cell * n, cell * n) * 0.5
	box(ci, Rect2(o - Vector2(8, 8), Vector2(cell * n + 16, cell * n + 16)), Color(0, 0, 0, 0.35), 12)
	var epoch := int(t / 1.6)
	var k := fposmod(t, 1.6)
	var row := 2 + epoch % 3
	var clearing := k > 0.6
	for y in n:
		for x in n:
			var kind := int(hash01(x + y * 7, epoch * (1 if y <= row else 0)) * 5)
			if y == row and x >= 2 and x <= 4:
				kind = epoch % 5
				if clearing:
					var s := maxf(0.0, 1.0 - (k - 0.6) * 3.0)
					if s > 0.0:
						_gem(ci, o + Vector2(x + 0.5, y + 0.5) * cell, cell * 0.38 * s, kind, c)
					for i in 6:
						var a := TAU * i / 6.0 + x
						ci.draw_circle(o + Vector2(x + 0.5, y + 0.5) * cell + Vector2.from_angle(a) * (k - 0.6) * cell * 2.0, 3.0, Color(1, 1, 0.8, maxf(0.0, 1.0 - (k - 0.6) * 1.5)))
					continue
			var drop := 0.0
			if clearing and y < row and x >= 2 and x <= 4:
				drop = minf(1.0, (k - 0.9) * 4.0) if k > 0.9 else 0.0
			_gem(ci, o + Vector2(x + 0.5, y + 0.5 + drop) * cell, cell * 0.38, kind, c)
	if not clearing:
		hand(ci, o + Vector2(5.5 - k * 1.5, row + 0.5) * cell, cell * 1.2, true)
	else:
		text(ci, ["SWEET!", "COMBO x3!", "DELICIOUS!", "WOW!"][epoch % 4], r.get_center() - Vector2(0, u * 0.42), int(u * 0.09 * pop(k, 0.6)), c[2], 8)


static func _merge(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[1].lightened(0.3), c[0].lightened(0.2))
	var n := 4
	var cell := u * 0.8 / n
	var o := r.get_center() - Vector2(cell * n, cell * n) * 0.5
	box(ci, Rect2(o - Vector2(10, 10), Vector2(cell * n + 20, cell * n + 20)), Color(0.45, 0.4, 0.35, 0.8), 14)
	var epoch := int(t / 1.3)
	var k := fposmod(t, 1.3)
	var mr := epoch % 4
	for y in n:
		for x in n:
			var v := int(pow(2, 1 + int(hash01(x + y * 4, epoch) * 8)))
			if y == mr and x <= 1:
				v = int(pow(2, 2 + epoch % 9))
			var pos := o + Vector2(x, y) * cell
			if y == mr and x == 0:
				pos.x += minf(1.0, k / 0.5) * cell
				if k > 0.5:
					continue
			var merged := y == mr and x == 1 and k > 0.5
			if merged:
				v *= 2
			var s := pop(k, 0.5) if merged else 1.0
			var rr := Rect2(pos + Vector2(cell, cell) * 0.5 * (1.0 - 0.9 * s) + Vector2(4, 4), Vector2(cell, cell) * 0.9 * s - Vector2(8, 8) * s)
			var shade := clampf(log(v) / log(2) / 11.0, 0.0, 1.0)
			box(ci, rr, c[0].lerp(c[2], shade), 10)
			text(ci, str(v), rr.get_center(), int(cell * (0.38 if v < 1000 else 0.26) * s), Color(1, 1, 1), 4)
	hand(ci, o + Vector2(0.5 + minf(1.0, k / 0.5), mr + 0.6) * cell, cell * 1.0, k < 0.5)


static func big_number(v: float) -> String:
	var suffix := ["", "K", "M", "B", "T", "aa", "ab", "ac"]
	var i := 0
	while v >= 1000.0 and i < suffix.size() - 1:
		v /= 1000.0
		i += 1
	return ("%.1f" % v if v < 100 else "%d" % int(v)) + suffix[i]


static func _idle(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[1].lightened(0.2), c[1].darkened(0.3))
	var money := pow(10.0, 1.0 + fposmod(t, 14.0) * 1.3)
	text(ci, "$" + big_number(money), r.get_center() - Vector2(0, u * 0.36), int(u * 0.11), c[2], 8)
	# the shop: tap, tap, tap
	var shop := r.get_center() + Vector2(0, u * 0.02)
	var squash := 1.0 - 0.06 * absf(sin(t * 12.0))
	var b := Rect2(shop - Vector2(u * 0.2, u * 0.16) * squash, Vector2(u * 0.4, u * 0.32) * squash)
	box(ci, b, c[0], 10)
	ci.draw_colored_polygon(PackedVector2Array([b.position - Vector2(u * 0.03, 0), Vector2(b.end.x + u * 0.03, b.position.y), Vector2(b.get_center().x, b.position.y - u * 0.14)]), c[0].darkened(0.3))
	for i in 5:
		ci.draw_rect(Rect2(b.position + Vector2(i * b.size.x / 5.0, 0), Vector2(b.size.x / 10.0, u * 0.05)), Color(1, 1, 1, 0.8))
	box(ci, Rect2(b.get_center() - Vector2(u * 0.05, -u * 0.02), Vector2(u * 0.1, b.end.y - b.get_center().y - u * 0.02)), c[0].darkened(0.5), 4)
	for i in 10:
		var k := fposmod(t * 1.5 + i * 0.1, 1.0)
		var p := shop + Vector2((hash01(i) - 0.5) * u * 0.5, -k * u * 0.4)
		coin(ci, p, u * 0.025, t * 5.0 + i)
		text(ci, "+$" + big_number(money * 0.01 * (1 + hash01(i, 2))), p + Vector2(u * 0.05, 0), int(u * 0.03), Color(1, 1, 1, 1.0 - k), 3)
	hand(ci, shop + Vector2(u * 0.05, u * 0.03), u * 0.12, sin(t * 12.0) > 0.0)
	for i in 3:
		var br := Rect2(r.position.x + r.size.x * (0.08 + i * 0.3), r.end.y - u * 0.34, r.size.x * 0.26, u * 0.11)
		var glow := 0.5 + 0.5 * sin(t * 6.0 + i)
		box(ci, br, Color(0.3, 0.75, 0.3).lerp(Color(0.5, 0.95, 0.4), glow), 10)
		text(ci, ["UPGRADE", "x10", "HIRE"][i], br.get_center(), int(u * 0.035), Color(1, 1, 1), 3, br.size.x - 8)


static func _hole(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	ci.draw_rect(r, Color(0.55, 0.6, 0.55))
	var grid := u * 0.18
	for i in int(r.size.x / grid) + 2:
		ci.draw_rect(Rect2(r.position.x + i * grid - grid * 0.12, r.position.y, grid * 0.24, r.size.y), Color(0.35, 0.36, 0.4))
	for j in int(r.size.y / grid) + 2:
		ci.draw_rect(Rect2(r.position.x, r.position.y + j * grid - grid * 0.12, r.size.x, grid * 0.24), Color(0.35, 0.36, 0.4))
	t = fposmod(t, 12.0)
	var hp := r.get_center() + Vector2(sin(t * 0.9) * r.size.x * 0.3, sin(t * 1.4) * r.size.y * 0.25)
	var hr := u * (0.05 + t * 0.012)
	var eaten := 0
	for i in 40:
		var p := r.position + Vector2(hash01(i) * r.size.x, hash01(i, 1) * r.size.y)
		var sz := u * (0.02 + 0.04 * hash01(i, 2))
		var d := p.distance_to(hp)
		if d < hr + sz:
			eaten += 1
			if d < hr * 0.6:
				continue
			sz *= clampf((d - hr * 0.6) / (hr * 0.4 + sz), 0.0, 1.0)
			p = p.lerp(hp, 0.3)
		var col: Color = [c[1], c[2], Color(0.9, 0.9, 0.95), c[0].lightened(0.3)][i % 4]
		ci.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
		ci.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz * 0.25)), col.lightened(0.3))
	ci.draw_circle(hp, hr * 1.08, Color(0.2, 0.2, 0.25))
	ci.draw_circle(hp, hr, Color(0.02, 0.02, 0.03))
	text(ci, "SIZE %d" % (1 + int(t * 2.0) + eaten), r.position + Vector2(r.size.x * 0.5, u * 0.08), int(u * 0.07), c[2], 6)


static func _stack(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.3), c[1].lightened(0.2))
	t = fposmod(t, 14.0)
	var n := int(t / 0.7)
	var bh := u * 0.06
	var cam := maxf(0.0, n - 8) * bh
	var base_y := r.end.y - u * 0.1 + cam
	for i in n:
		var w := u * 0.4 * (1.0 - 0.012 * i)
		var x := r.get_center().x + (hash01(i) - 0.5) * u * 0.01
		var col: Color = c[i % 3].lerp(Color.WHITE, 0.15 * (i % 2))
		ci.draw_rect(Rect2(x - w * 0.5, base_y - (i + 1) * bh, w, bh - 2), col)
		ci.draw_rect(Rect2(x - w * 0.5, base_y - (i + 1) * bh, w, bh * 0.25), col.lightened(0.25))
	var slide := sin(fposmod(t, 0.7) / 0.7 * PI - PI * 0.5)
	var w2 := u * 0.4 * (1.0 - 0.012 * n)
	ci.draw_rect(Rect2(r.get_center().x + slide * u * 0.35 - w2 * 0.5, base_y - (n + 1) * bh, w2, bh - 2), c[n % 3])
	if n > 0 and fposmod(t, 0.7) < 0.35:
		text(ci, "PERFECT!", r.get_center() - Vector2(0, u * 0.32), int(u * 0.09 * pop(fposmod(t, 0.7), 0.0)), Color(1, 1, 1), 8)
	text(ci, str(n), Vector2(r.get_center().x, r.position.y + u * 0.1), int(u * 0.12), Color(1, 1, 1), 8)


static func _car(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	box(ci, Rect2(p - Vector2(s * 0.3, s * 0.5), Vector2(s * 0.6, s)), col, s * 0.12)
	box(ci, Rect2(p - Vector2(s * 0.22, s * 0.25), Vector2(s * 0.44, s * 0.3)), Color(0.15, 0.2, 0.3), s * 0.06)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			ci.draw_rect(Rect2(p + Vector2(sx * s * 0.33 - s * 0.05, sy * s * 0.3 - s * 0.1), Vector2(s * 0.1, s * 0.2)), Color(0.08, 0.08, 0.08))


static func _racing(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	ci.draw_rect(r, Color(0.3, 0.55, 0.25))
	var road := Rect2(r.get_center().x - u * 0.3, r.position.y, u * 0.6, r.size.y)
	ci.draw_rect(road, c[1].darkened(0.3) if c[1].get_luminance() > 0.5 else Color(0.25, 0.25, 0.28))
	for lane in [1, 2]:
		for j in 12:
			var y := fposmod(j * u * 0.18 + t * u * 1.6, r.size.y + u * 0.2) + r.position.y - u * 0.1
			ci.draw_rect(Rect2(road.position.x + road.size.x * lane / 3.0 - 3, y, 6, u * 0.08), Color(1, 1, 1, 0.8))
	for i in 6:
		var lane := int(hash01(i) * 3)
		var y := fposmod(hash01(i, 1) * r.size.y * 1.5 + t * u * 0.9, r.size.y * 1.5) + r.position.y - r.size.y * 0.3
		_car(ci, Vector2(road.position.x + road.size.x * (lane + 0.5) / 3.0, y), u * 0.13, [Color(0.9, 0.9, 0.95), Color(0.2, 0.5, 0.9), Color(0.95, 0.8, 0.2)][i % 3])
	var px := road.get_center().x + sin(t * 2.2) * road.size.x * 0.33
	var py := r.end.y - u * 0.18
	for i in 5:
		ci.draw_circle(Vector2(px + (hash01(i, int(t * 30)) - 0.5) * u * 0.04, py + u * 0.08 + i * u * 0.02), u * (0.03 - i * 0.004), Color(1.0, 0.6 - i * 0.1, 0.1, 0.8))
	_car(ci, Vector2(px, py), u * 0.15, c[0])
	text(ci, "%d km/h" % (180 + int(t * 20) % 120), Vector2(r.end.x - u * 0.2, r.position.y + u * 0.08), int(u * 0.05), c[2], 6)


static func _stick(ci: CanvasItem, p: Vector2, s: float, col: Color, walk: float, lean: float = 0.0) -> void:
	var hip := p + Vector2(lean * s * 0.3, -s * 0.45)
	var neck := hip + Vector2(lean * s * 0.2, -s * 0.35)
	ci.draw_line(hip, neck, col, s * 0.08)
	ci.draw_circle(neck + Vector2(0, -s * 0.12), s * 0.12, col)
	ci.draw_line(hip, p + Vector2(sin(walk) * s * 0.2, 0), col, s * 0.07)
	ci.draw_line(hip, p + Vector2(-sin(walk) * s * 0.2, 0), col, s * 0.07)
	ci.draw_line(neck + Vector2(0, s * 0.08), neck + Vector2(-s * 0.25, s * 0.1 + lean * s * 0.1), col, s * 0.06)


static func _shooter(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, Color(0.25, 0.2, 0.3), c[1].darkened(0.4))
	var ground := r.end.y - u * 0.18
	ci.draw_rect(Rect2(r.position.x, ground, r.size.x, r.end.y - ground), c[0].darkened(0.4))
	var hero := Vector2(r.position.x + r.size.x * 0.15, ground)
	_stick(ci, hero, u * 0.3, Color(0.9, 0.9, 0.95), 0.0)
	var gun_y := ground - u * 0.21
	ci.draw_rect(Rect2(hero.x + u * 0.02, gun_y - u * 0.012, u * 0.1, u * 0.024), Color(0.2, 0.2, 0.2))
	var kills := 0
	for i in 9:
		var age := fposmod(t - i * 0.7, 6.3)
		if age < 0.0:
			continue
		var x := r.end.x + u * 0.05 - age * u * 0.25
		var die := 1.4 + hash01(i) * 0.6
		var zcol := Color(0.45, 0.75, 0.35)
		if age > die:
			var fall := minf(1.0, (age - die) * 4.0)
			_stick(ci, Vector2(x + (age - die) * u * 0.25, ground), u * 0.28, zcol.darkened(0.3), 0.0, fall * 3.0)
			if age - die < 0.5:
				text(ci, "HEADSHOT!", Vector2(x, ground - u * 0.4), int(u * 0.05 * pop(age, die)), Color(1, 0.3, 0.2), 5)
			continue
		_stick(ci, Vector2(x, ground), u * 0.28, zcol, age * 6.0, -0.3)
	if fposmod(t, 0.2) < 0.08:
		ci.draw_circle(Vector2(hero.x + u * 0.13, gun_y), u * 0.03, Color(1, 0.85, 0.3))
		ci.draw_line(Vector2(hero.x + u * 0.14, gun_y), Vector2(r.end.x, gun_y + (hash01(int(t * 50)) - 0.5) * u * 0.05), Color(1, 0.95, 0.6, 0.8), 2.0)
	kills = int(t * 1.4)
	text(ci, "KILLS: %d" % (kills * 7 + int(t)), Vector2(r.get_center().x, r.position.y + u * 0.08), int(u * 0.06), c[2], 6)


static func _castle(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[1].lightened(0.2), c[1].darkened(0.2))
	var ground := r.get_center().y + u * 0.2
	ci.draw_rect(Rect2(r.position.x, ground, r.size.x, r.end.y - ground), Color(0.35, 0.6, 0.3))
	var cc := Vector2(r.get_center().x, ground)
	var stone: Color = c[0]
	ci.draw_rect(Rect2(cc.x - u * 0.15, ground - u * 0.2, u * 0.3, u * 0.2), stone)
	for sx in [-1.0, 1.0]:
		var tx: float = cc.x + sx * u * 0.17
		ci.draw_rect(Rect2(tx - u * 0.05, ground - u * 0.32, u * 0.1, u * 0.32), stone.darkened(0.1))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(tx - u * 0.065, ground - u * 0.32), Vector2(tx + u * 0.065, ground - u * 0.32), Vector2(tx, ground - u * 0.42)]), Color(0.8, 0.2, 0.2))
	ci.draw_rect(Rect2(cc.x - u * 0.04, ground - u * 0.1, u * 0.08, u * 0.1), Color(0.25, 0.15, 0.1))
	var flag := Vector2(cc.x, ground - u * 0.3)
	ci.draw_line(flag, flag - Vector2(0, u * 0.1), Color(0.3, 0.3, 0.3), 2)
	ci.draw_colored_polygon(PackedVector2Array([flag - Vector2(0, u * 0.1), flag - Vector2(-u * 0.06 - sin(t * 6) * 3, u * 0.08), flag - Vector2(0, u * 0.06)]), c[2])
	for i in 16:
		var side := -1.0 if i % 2 == 0 else 1.0
		var k := fposmod(t * 0.25 + hash01(i), 1.0)
		var x := cc.x + side * lerpf(r.size.x * 0.55, u * 0.22, k)
		_stick(ci, Vector2(x, ground + u * 0.05 + hash01(i, 2) * u * 0.1), u * 0.08, Color(0.6, 0.15, 0.15), t * 8.0 + i)
	for i in 6:
		var k := fposmod(t * 0.8 + i / 6.0, 1.0)
		var side := -1.0 if i % 2 == 0 else 1.0
		var start := Vector2(cc.x + side * u * 0.17, ground - u * 0.32)
		var end := Vector2(cc.x + side * u * 0.45, ground + u * 0.08)
		var p := start.lerp(end, k) - Vector2(0, sin(k * PI) * u * 0.15)
		ci.draw_line(p, p + (end - start).normalized().rotated(-0.4 * side * (1 - 2 * k)) * u * 0.04, Color(0.2, 0.15, 0.1), 2)
	var res := ["Gold", "Wood", "Stone"]
	for i in 3:
		var p := Vector2(r.position.x + r.size.x * (0.2 + i * 0.3), r.position.y + u * 0.08)
		box(ci, Rect2(p - Vector2(r.size.x * 0.13, u * 0.035), Vector2(r.size.x * 0.26, u * 0.07)), Color(0, 0, 0, 0.45), 8)
		text(ci, "%s %s" % [res[i], big_number(pow(10.0, 2.0 + t * 0.6 + i * 0.3))], p, int(u * 0.035), Color(1, 0.95, 0.7), 3, r.size.x * 0.24)


static func _slots(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[1].darkened(0.3), c[0].darkened(0.4))
	var k := fposmod(t, 3.2)
	var frame := Rect2(r.get_center() - Vector2(u * 0.4, u * 0.22), Vector2(u * 0.8, u * 0.44))
	box(ci, frame.grow(u * 0.03), c[2].darkened(0.2), 18)
	box(ci, frame, Color(0.98, 0.96, 0.9), 10)
	var syms := ["7", "BAR", "@", "$", "*"]
	for reel in 3:
		var stop := 1.0 + reel * 0.4
		var rx := frame.position.x + frame.size.x * (reel + 0.5) / 3.0
		var spinning := k < stop
		for j in 3:
			var off := fposmod(k * 12.0, 1.0) if spinning else 0.0
			var y := frame.position.y + frame.size.y * ((j + off) / 3.0 + 1.0 / 6.0)
			var sym: String = syms[int(hash01(reel * 10 + j, int(k * 12.0))) * 5] if spinning else ("7" if j == 1 else syms[(reel + j) % 5])
			if sym == "@":
				ci.draw_circle(Vector2(rx - u * 0.025, y + u * 0.01), u * 0.03, Color(0.85, 0.1, 0.15))
				ci.draw_circle(Vector2(rx + u * 0.025, y + u * 0.015), u * 0.03, Color(0.85, 0.1, 0.15))
			else:
				text(ci, sym, Vector2(rx, y), int(u * 0.09), Color(0.85, 0.1, 0.15) if sym == "7" else Color(0.2, 0.2, 0.3), 0)
		if reel < 2:
			ci.draw_line(Vector2(frame.position.x + frame.size.x * (reel + 1) / 3.0, frame.position.y), Vector2(frame.position.x + frame.size.x * (reel + 1) / 3.0, frame.end.y), Color(0.7, 0.7, 0.7), 2)
	ci.draw_line(Vector2(frame.position.x, frame.get_center().y), Vector2(frame.end.x, frame.get_center().y), Color(1, 0.2, 0.2, 0.5), 3)
	if k > 2.0:
		text(ci, "JACKPOT!", r.get_center() - Vector2(0, u * 0.33), int(u * 0.12 * pop(k, 2.0)), c[2], 10)
		for i in 24:
			var p := Vector2(r.position.x + hash01(i) * r.size.x, r.position.y + fposmod(hash01(i, 1) + (k - 2.0) * 0.8, 1.0) * r.size.y)
			coin(ci, p, u * 0.03, t * 6.0 + i)


static func _fish(ci: CanvasItem, p: Vector2, s: float, col: Color, dir: float) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(p + Vector2(cos(a) * s, sin(a) * s * 0.45))
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(PackedVector2Array([p - Vector2(dir * s * 0.9, 0), p - Vector2(dir * s * 1.4, s * 0.4), p - Vector2(dir * s * 1.4, -s * 0.4)]), col.darkened(0.2))
	ci.draw_circle(p + Vector2(dir * s * 0.55, -s * 0.1), s * 0.1, Color(0.05, 0.05, 0.05))


static func _fishing(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	var surface := r.position.y + r.size.y * 0.25
	sky(ci, Rect2(r.position, Vector2(r.size.x, surface - r.position.y)), Color(0.6, 0.85, 1.0), Color(0.9, 0.95, 1.0))
	sky(ci, Rect2(Vector2(r.position.x, surface), Vector2(r.size.x, r.end.y - surface)), c[0], c[0].darkened(0.6))
	var boat := Vector2(r.get_center().x, surface + sin(t * 2.0) * 3.0)
	ci.draw_colored_polygon(PackedVector2Array([boat + Vector2(-u * 0.18, -u * 0.02), boat + Vector2(u * 0.18, -u * 0.02), boat + Vector2(u * 0.12, u * 0.05), boat + Vector2(-u * 0.12, u * 0.05)]), c[1])
	var k := fposmod(t, 4.0)
	var depth := clampf(k / 1.5, 0.0, 1.0) * (r.end.y - surface) * 0.75
	if k > 2.5:
		depth *= maxf(0.0, 1.0 - (k - 2.5) / 1.0)
	var hook := Vector2(boat.x + u * 0.1, surface + depth)
	ci.draw_line(boat + Vector2(u * 0.1, -u * 0.12), hook, Color(1, 1, 1, 0.8), 1.5)
	for i in 7:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var x := fposmod(hash01(i) * r.size.x + t * u * 0.15 * dir, r.size.x + u * 0.3) + r.position.x - u * 0.15
		var y := surface + (0.25 + hash01(i, 1) * 0.65) * (r.end.y - surface)
		_fish(ci, Vector2(x, y), u * (0.03 + 0.03 * hash01(i, 2)), c[2].lerp(c[1], hash01(i, 3)), dir)
	if k > 2.5:
		_fish(ci, hook + Vector2(0, u * 0.06), u * 0.1, Color(0.95, 0.75, 0.2), 1.0)
		text(ci, "LEGENDARY CATCH!", r.get_center() + Vector2(0, -u * 0.38), int(u * 0.07 * pop(k, 2.5)), Color(1, 0.85, 0.2), 8)
		text(ci, "%d kg" % (40 + int(hash01(int(t / 4.0)) * 60)), r.get_center() + Vector2(0, -u * 0.28), int(u * 0.05 * pop(k, 2.7)), Color(1, 1, 1), 5)


static func _word(ci: CanvasItem, r: Rect2, t: float, c: Array, word: String) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0], c[0].darkened(0.5))
	var n := word.length()
	var k := fposmod(t, 1.0 + n * 0.45)
	var got := clampi(int(k / 0.45), 0, n)
	var cs := u * 0.1
	var gx := r.get_center().x - cs * n * 0.5
	for i in n:
		var cell := Rect2(Vector2(gx + i * cs, r.position.y + r.size.y * 0.2), Vector2(cs - 4, cs - 4))
		box(ci, cell, Color(1, 1, 1, 0.95) if i < got else Color(1, 1, 1, 0.25), 6)
		if i < got:
			text(ci, word[i], cell.get_center(), int(cs * 0.6), c[0].darkened(0.3), 0)
	var wheel := r.get_center() + Vector2(0, u * 0.18)
	var wr := u * 0.22
	ci.draw_circle(wheel, wr * 1.3, Color(1, 1, 1, 0.2))
	var letters := word + "XQ"
	var pts := []
	for i in letters.length():
		var a := -PI / 2 + TAU * i / letters.length()
		pts.append(wheel + Vector2.from_angle(a) * wr)
	var path := PackedVector2Array()
	for i in got:
		path.append(pts[i])
	if got < n and got > 0:
		path.append(Vector2(pts[got - 1]).lerp(pts[got], fposmod(k, 0.45) / 0.45))
	if path.size() > 1:
		ci.draw_polyline(path, c[2], u * 0.025, true)
	for i in letters.length():
		var lit := i < got
		ci.draw_circle(pts[i], u * 0.06, c[2] if lit else Color(1, 1, 1))
		text(ci, letters[i], pts[i], int(u * 0.06), c[0].darkened(0.4), 0)
	if path.size() > 0:
		hand(ci, path[path.size() - 1], u * 0.1, true)
	if got >= n:
		text(ci, "GENIUS!", r.get_center() - Vector2(0, u * 0.05), int(u * 0.1 * pop(k, n * 0.45)), c[2], 8)


static func _draw_save(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, Color(0.98, 0.98, 0.95), Color(0.9, 0.92, 0.88))
	var k := fposmod(t, 5.0)
	var ground := r.get_center().y + u * 0.25
	ci.draw_rect(Rect2(r.position.x, ground, r.size.x, r.end.y - ground), c[0])
	var dog := Vector2(r.get_center().x, ground - u * 0.06)
	ci.draw_circle(dog, u * 0.07, Color(0.75, 0.5, 0.3))
	ci.draw_circle(dog + Vector2(-u * 0.055, -u * 0.04), u * 0.03, Color(0.55, 0.35, 0.2))
	ci.draw_circle(dog + Vector2(u * 0.055, -u * 0.04), u * 0.03, Color(0.55, 0.35, 0.2))
	ci.draw_circle(dog + Vector2(-u * 0.025, -u * 0.01), u * 0.01, Color(0.05, 0.05, 0.05))
	ci.draw_circle(dog + Vector2(u * 0.025, -u * 0.01), u * 0.01, Color(0.05, 0.05, 0.05))
	ci.draw_circle(dog + Vector2(0, u * 0.02), u * 0.012, Color(0.1, 0.05, 0.05))
	# the line you draw: an arch over the dog
	var drawn := clampf(k / 1.5, 0.0, 1.0)
	var arch := PackedVector2Array()
	var segs := int(24 * drawn)
	for i in segs + 1:
		var a := PI + PI * i / 24.0
		arch.append(dog + Vector2(cos(a) * u * 0.16, sin(a) * u * 0.17 + u * 0.05))
	if arch.size() > 1:
		ci.draw_polyline(arch, Color(0.1, 0.1, 0.15), u * 0.018, true)
	if k < 1.5 and arch.size() > 0:
		hand(ci, arch[arch.size() - 1], u * 0.1, true)
	var hive := Vector2(r.end.x - u * 0.15, r.position.y + u * 0.15)
	ci.draw_circle(hive, u * 0.06, c[1].darkened(0.1))
	for i in 3:
		ci.draw_line(hive + Vector2(-u * 0.055, (i - 1) * u * 0.025), hive + Vector2(u * 0.055, (i - 1) * u * 0.025), c[1].darkened(0.4), 2)
	if k > 1.5:
		for i in 14:
			var a := hash01(i) * TAU + (k - 1.5) * 2.0 * (1.0 if i % 2 else -1.0)
			var ring := u * 0.2 + sin(k * 5.0 + i) * u * 0.02
			var target := dog + Vector2(cos(a), sin(a) * 0.8) * ring - Vector2(0, u * 0.05)
			var p := hive.lerp(target, minf(1.0, (k - 1.5) * 1.5))
			ci.draw_circle(p, u * 0.012, Color(1, 0.85, 0.1))
			ci.draw_line(p - Vector2(u * 0.008, 0), p + Vector2(u * 0.008, 0), Color(0.1, 0.1, 0.1), 2)
	if k < 4.0:
		text(ci, str(10 - int(k * 2.0)), Vector2(r.get_center().x, r.position.y + u * 0.1), int(u * 0.1), c[2], 6)
	else:
		text(ci, "SAVED!", r.get_center() - Vector2(0, u * 0.25), int(u * 0.12 * pop(k, 4.0)), Color(0.2, 0.8, 0.3), 8)


static func _ball_sort(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.4), c[1].lightened(0.3))
	var cols := [c[0].darkened(0.2), c[1].darkened(0.1), c[2].darkened(0.2), Color(0.95, 0.85, 0.2)]
	var n := 5
	var tw := u * 0.12
	var epoch := int(t / 1.0)
	var k := fposmod(t, 1.0)
	var from := epoch % 4
	var to := 4
	for i in n:
		var x := r.get_center().x + (i - (n - 1) * 0.5) * tw * 1.6
		var tube := Rect2(x - tw * 0.5, r.get_center().y - tw * 2.2, tw, tw * 4.4)
		CardArt.line_rrect(ci, tube, tw * 0.45, Color(1, 1, 1, 0.9), 3.0)
		var balls := 4 if i < 4 else mini(epoch, 3)
		for j in balls:
			if i == from and j == balls - 1:
				continue
			var col: Color = cols[(i + j * 3 + epoch) % 4] if i < 4 else cols[0]
			ci.draw_circle(Vector2(x, tube.end.y - tw * (0.55 + j * 1.0)), tw * 0.42, col)
	var fx := r.get_center().x + (from - (n - 1) * 0.5) * tw * 1.6
	var tx := r.get_center().x + (to - (n - 1) * 0.5) * tw * 1.6
	var lift := r.get_center().y - tw * 2.8
	var p := Vector2(lerpf(fx, tx, smoothstep(0.2, 0.7, k)), lift - sin(clampf((k - 0.2) / 0.5, 0, 1) * PI) * tw * 0.4)
	if k > 0.7:
		p.y = lerpf(lift, r.get_center().y + tw * 1.6 - mini(epoch, 3) * tw, (k - 0.7) / 0.3)
	ci.draw_circle(p, tw * 0.42, cols[0])
	hand(ci, Vector2(fx if k < 0.2 else tx, r.get_center().y + tw * 2.6), u * 0.1, k < 0.15)


static func _chat(ci: CanvasItem, r: Rect2, t: float, c: Array, lines: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.2), c[1].lightened(0.1))
	var phone := Rect2(r.get_center() - Vector2(u * 0.26, u * 0.45), Vector2(u * 0.52, u * 0.9))
	box(ci, phone.grow(8), Color(0.1, 0.1, 0.12), u * 0.06)
	box(ci, phone, Color(0.97, 0.97, 0.98), u * 0.04)
	box(ci, Rect2(phone.position, Vector2(phone.size.x, u * 0.08)), c[1], u * 0.03)
	ci.draw_circle(phone.position + Vector2(u * 0.05, u * 0.04), u * 0.025, c[0])
	text(ci, "online now", phone.position + Vector2(phone.size.x * 0.5, u * 0.04), int(u * 0.03), Color(1, 1, 1), 0)
	t = fposmod(t, lines.size() * 0.9 + 3.0)
	var shown := mini(lines.size(), int(t / 0.9) + 1)
	var y := phone.position.y + u * 0.12
	var font := ThemeDB.fallback_font
	var fs := int(u * 0.032)
	for i in shown:
		var s := String(lines[i])
		var w := minf(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 20, phone.size.x * 0.8)
		var mine := i % 2 == 1
		var x := phone.end.x - w - 10 if mine else phone.position.x + 10
		var grow := minf(1.0, (t - i * 0.9) * 5.0)
		var br := Rect2(Vector2(x, y), Vector2(w, fs * 1.8) * grow)
		box(ci, br, c[0] if mine else Color(0.88, 0.88, 0.9), 12)
		if grow >= 1.0:
			ci.draw_string(font, br.position + Vector2(10, fs * 1.25), s, HORIZONTAL_ALIGNMENT_LEFT, w - 16, fs, Color(1, 1, 1) if mine else Color(0.1, 0.1, 0.12))
		y += fs * 2.2
	if shown < lines.size():
		var dots := Rect2(Vector2(phone.position.x + 10, y), Vector2(u * 0.12, fs * 1.6))
		box(ci, dots, Color(0.88, 0.88, 0.9), 12)
		for i in 3:
			ci.draw_circle(dots.position + Vector2(u * 0.03 + i * u * 0.03, fs * 0.8 - absf(sin(t * 6.0 + i)) * 4), u * 0.008, Color(0.4, 0.4, 0.45))


static func _food(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.3), c[0])
	var plate := Vector2(r.get_center().x, r.get_center().y + u * 0.3)
	var pr := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pr.append(plate + Vector2(cos(a) * u * 0.3, sin(a) * u * 0.06))
	ci.draw_colored_polygon(pr, Color(0.97, 0.97, 0.97))
	var layers := [[Color(0.9, 0.62, 0.3), 0.05], [Color(0.4, 0.22, 0.12), 0.05], [Color(1.0, 0.8, 0.15), 0.02], [Color(0.4, 0.8, 0.3), 0.025],
		[Color(0.9, 0.25, 0.2), 0.025], [Color(0.4, 0.22, 0.12), 0.05], [Color(0.92, 0.65, 0.3), 0.09]]
	var k := fposmod(t, layers.size() * 0.6 + 1.2)
	var y := plate.y - u * 0.02
	for i in layers.size():
		var land := i * 0.6 + 0.4
		if k < i * 0.6:
			break
		var h: float = float(layers[i][1]) * u
		var fall := clampf((land - k) / 0.4, 0.0, 1.0)
		var ly := y - h - fall * u * 0.5
		var w := u * (0.24 if i != 2 else 0.26)
		if i == layers.size() - 1:
			var dome := PackedVector2Array()
			for j in 13:
				var a := PI + PI * j / 12.0
				dome.append(Vector2(plate.x + cos(a) * w, ly + h + sin(a) * h))
			ci.draw_colored_polygon(dome, layers[i][0])
			for j in 6:
				ci.draw_circle(Vector2(plate.x + (hash01(j) - 0.5) * w * 1.2, ly + h * (0.3 + hash01(j, 1) * 0.4)), u * 0.008, Color(1, 0.97, 0.85))
		else:
			box(ci, Rect2(plate.x - w, ly, w * 2, h), layers[i][0], h * 0.4)
		y -= h
	if k > layers.size() * 0.6:
		text(ci, "PERFECT!", r.get_center() - Vector2(0, u * 0.38), int(u * 0.1 * pop(k, layers.size() * 0.6)), Color(1, 1, 1), 8)
		for i in 6:
			star(ci, r.get_center() + Vector2.from_angle(TAU * i / 6.0 + t) * u * 0.35, u * 0.03, c[2], t)


static func _slice(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.1), c[0].darkened(0.4))
	var combo := 0
	for i in 8:
		var start := i * 0.45
		var age := fposmod(t - start, 3.6)
		var x0 := r.position.x + r.size.x * (0.15 + hash01(i) * 0.7)
		var vx := (hash01(i, 1) - 0.5) * u * 0.3
		var p := Vector2(x0 + vx * age, r.end.y - (age * u * 1.4 - age * age * u * 0.55))
		var col: Color = [c[1], c[2], Color(1.0, 0.75, 0.1), Color(0.6, 0.3, 0.8)][i % 4]
		var cut := age > 1.2
		if cut:
			combo += 1
			var sep := (age - 1.2) * u * 0.15
			for s in [-1.0, 1.0]:
				ci.draw_circle(p + Vector2(s * sep, (age - 1.2) * u * 0.1), u * 0.045, col)
			ci.draw_circle(p, u * 0.06 * minf(1.0, (age - 1.2) * 3.0), Color(col, 0.25))
		else:
			ci.draw_circle(p, u * 0.055, col)
			ci.draw_circle(p - Vector2(u * 0.015, u * 0.02), u * 0.015, Color(1, 1, 1, 0.6))
	var trail := PackedVector2Array()
	for j in 8:
		var tt := t - j * 0.02
		trail.append(r.get_center() + Vector2(sin(tt * 4.0) * u * 0.35, cos(tt * 3.1) * u * 0.25))
	ci.draw_polyline(trail, Color(1, 1, 1, 0.9), u * 0.012, true)
	text(ci, "COMBO x%d" % (combo + 1), Vector2(r.get_center().x, r.position.y + u * 0.1), int(u * 0.07), c[2], 6)


static func _cards(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].darkened(0.3), c[0].darkened(0.7))
	var k := fposmod(t, 3.6)
	for i in 3:
		var flip := clampf((k - 0.5 - i * 0.6) / 0.35, 0.0, 1.0)
		var center := r.get_center() + Vector2((i - 1) * u * 0.3, 0)
		var w := u * 0.24 * absf(cos(flip * PI))
		var card := Rect2(center - Vector2(w * 0.5, u * 0.18), Vector2(w, u * 0.36))
		var legendary := i == 2
		if flip >= 0.5:
			if legendary:
				for j in 12:
					var a := TAU * j / 12.0 + t
					ci.draw_line(center, center + Vector2.from_angle(a) * u * 0.3, Color(c[1], 0.35), u * 0.02)
			box(ci, card, c[1] if legendary else Color(0.85, 0.85, 0.9), 8)
			box(ci, card.grow(-u * 0.015), Color(0.15, 0.1, 0.2), 6)
			if w > u * 0.05:
				PieceArt.draw_piece(ci, [2, 4, 5][i], true, center.x, center.y + u * 0.1, u * 0.14, Color.WHITE, false)
				text(ci, ["RARE", "EPIC", "LEGENDARY"][i], center + Vector2(0, -u * 0.14), int(u * 0.03), c[1] if legendary else Color(0.8, 0.8, 1.0), 3, w)
		else:
			box(ci, card, c[2].darkened(0.3), 8)
			ci.draw_circle(center, w * 0.3, c[2])
	if k > 2.2:
		text(ci, "LEGENDARY!", r.get_center() - Vector2(0, u * 0.33), int(u * 0.1 * pop(k, 2.2)), c[1], 8)


static func _jumper(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.35), c[0])
	var climb := t * u * 0.35
	var gap := u * 0.16
	var first := int(climb / gap) - 1
	for k in 9:
		var i := first + k
		var y := r.end.y - (i * gap - climb) - u * 0.05
		var x := r.position.x + r.size.x * (0.15 + 0.7 * hash01(i, 4))
		var col: Color = c[1] if i % 5 else c[2]
		box(ci, Rect2(x - u * 0.08, y, u * 0.16, u * 0.025), col, 6)
		if i % 7 == 3:
			coin(ci, Vector2(x, y - u * 0.05), u * 0.025, t * 5.0 + i)
	# the hero bounces from platform to platform
	var hop := fposmod(t * 2.0, 1.0)
	var i2 := int(t * 2.0)
	var y0 := r.end.y - u * 0.05 - u * 0.25
	var px := r.position.x + r.size.x * (0.15 + 0.7 * lerpf(hash01(i2, 4), hash01(i2 + 1, 4), hop))
	var py := y0 - sin(hop * PI) * u * 0.18
	ci.draw_circle(Vector2(px, py), u * 0.045, Color(0.95, 0.85, 0.3))
	ci.draw_circle(Vector2(px + u * 0.015, py - u * 0.01), u * 0.01, Color(0.1, 0.1, 0.1))
	ci.draw_line(Vector2(px - u * 0.03, py + u * 0.04), Vector2(px - u * 0.04, py + u * 0.07), Color(0.1, 0.1, 0.1), 3)
	ci.draw_line(Vector2(px + u * 0.03, py + u * 0.04), Vector2(px + u * 0.04, py + u * 0.07), Color(0.1, 0.1, 0.1), 3)
	text(ci, "%d m" % int(t * 12.0), Vector2(r.get_center().x, r.position.y + u * 0.08), int(u * 0.07), Color(1, 1, 1), 6)


static func _rope(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].lightened(0.4), c[0].lightened(0.1))
	var k := fposmod(t, 4.0)
	var pin := Vector2(r.get_center().x - u * 0.1, r.position.y + u * 0.1)
	var swing := sin(k * 3.0) * 0.6 * maxf(0.0, 1.0 - k * 0.3)
	var hang := pin + Vector2.from_angle(PI / 2 + swing) * u * 0.3
	var cut := k > 1.6
	var candy := hang
	if cut:
		var f := k - 1.6
		candy = hang + Vector2(f * u * 0.06, f * f * u * 0.5)
	else:
		ci.draw_line(pin, hang, Color(0.55, 0.4, 0.2), 4)
		hand(ci, pin.lerp(hang, 0.5) + Vector2(u * 0.12 - k * u * 0.06, 0), u * 0.1, k > 1.4)
	ci.draw_circle(pin, u * 0.015, Color(0.4, 0.4, 0.45))
	# the little monster waiting with its mouth open
	var mon := Vector2(r.get_center().x, r.end.y - u * 0.15)
	var eaten := cut and candy.y >= mon.y - u * 0.05
	ci.draw_circle(mon, u * 0.1, c[1])
	ci.draw_circle(mon + Vector2(-u * 0.035, -u * 0.04), u * 0.02, Color(1, 1, 1))
	ci.draw_circle(mon + Vector2(u * 0.035, -u * 0.04), u * 0.02, Color(1, 1, 1))
	ci.draw_circle(mon + Vector2(-u * 0.035, -u * 0.04), u * 0.009, Color(0.1, 0.1, 0.1))
	ci.draw_circle(mon + Vector2(u * 0.035, -u * 0.04), u * 0.009, Color(0.1, 0.1, 0.1))
	var mouth := u * (0.045 if not eaten else 0.015)
	ci.draw_circle(mon + Vector2(0, u * 0.035), mouth, Color(0.35, 0.05, 0.1))
	if not eaten:
		ci.draw_circle(candy, u * 0.04, c[2])
		ci.draw_line(candy - Vector2(u * 0.06, 0), candy + Vector2(u * 0.06, 0), c[2].darkened(0.2), u * 0.02)
	else:
		text(ci, "YUM!", mon - Vector2(0, u * 0.2), int(u * 0.09 * pop(k, 2.6)), c[2], 8)
		for i in 3:
			star(ci, mon + Vector2((i - 1) * u * 0.12, -u * 0.32), u * 0.04, Color(1, 0.85, 0.2), t)


static func _basket(ci: CanvasItem, r: Rect2, t: float, c: Array) -> void:
	var u := minf(r.size.x, r.size.y)
	sky(ci, r, c[0].darkened(0.3), c[0].darkened(0.6))
	ci.draw_rect(Rect2(r.position.x, r.end.y - u * 0.1, r.size.x, u * 0.1), Color(0.75, 0.5, 0.3))
	var hoop := Vector2(r.end.x - r.size.x * 0.25, r.position.y + r.size.y * 0.35)
	ci.draw_rect(Rect2(hoop + Vector2(u * 0.06, -u * 0.14), Vector2(u * 0.02, u * 0.2)), Color(0.95, 0.95, 0.95))
	var k := fposmod(t, 1.6)
	var shooter := Vector2(r.position.x + r.size.x * 0.2, r.end.y - u * 0.2)
	var f := clampf(k / 1.0, 0.0, 1.0)
	var ball := shooter.lerp(hoop, f) - Vector2(0, sin(f * PI) * u * 0.3)
	if k > 1.0:
		ball = hoop + Vector2(0, (k - 1.0) * u * 0.5)
	ci.draw_circle(ball, u * 0.04, Color(0.95, 0.5, 0.15))
	ci.draw_arc(ball, u * 0.04, 0, TAU, 16, Color(0.3, 0.15, 0.05), 2.0)
	ci.draw_line(ball - Vector2(u * 0.04, 0), ball + Vector2(u * 0.04, 0), Color(0.3, 0.15, 0.05), 2.0)
	ci.draw_line(hoop - Vector2(u * 0.06, 0), hoop + Vector2(u * 0.06, 0), Color(0.9, 0.2, 0.15), 4)
	for i in 5:
		ci.draw_line(hoop + Vector2(-u * 0.06 + i * u * 0.03, 0), hoop + Vector2(-u * 0.03 + i * u * 0.015, u * 0.08), Color(1, 1, 1, 0.8), 2)
	if k > 1.0:
		text(ci, ["SWISH!", "3 POINTER!", "ON FIRE!"][int(t / 1.6) % 3], hoop - Vector2(u * 0.15, u * 0.2), int(u * 0.07 * pop(k, 1.0)), c[2], 6)
	text(ci, "%d PTS" % (int(t / 1.6) * 3), Vector2(r.get_center().x, r.position.y + u * 0.08), int(u * 0.06), Color(1, 1, 1), 6)


# --- products ------------------------------------------------------------------------

static func _product(ci: CanvasItem, r: Rect2, t: float, c: Array, ad: Dictionary) -> void:
	var u := minf(r.size.x, r.size.y)
	ci.draw_rect(r, c[0].darkened(0.2))
	var cen := r.get_center()
	for i in 16:
		var a := TAU * i / 16.0 + t * 0.4
		ci.draw_colored_polygon(PackedVector2Array([cen, cen + Vector2.from_angle(a) * u * 1.2, cen + Vector2.from_angle(a + 0.18) * u * 1.2]), Color(c[0].lightened(0.25), 0.6))
	var bob := sin(t * 2.2) * u * 0.02
	var s := u * 0.5 * (0.9 + 0.1 * minf(1.0, t * 3.0))
	product_shape(ci, String(ad.get("obj", "box")), cen + Vector2(0, bob), s, t, c)
	# a shine sweeping across
	var sweep := fposmod(t * 0.6, 1.5) - 0.25
	var sx := cen.x - s * 0.6 + sweep * s * 1.2
	ci.draw_colored_polygon(PackedVector2Array([Vector2(sx, cen.y - s * 0.6), Vector2(sx + s * 0.1, cen.y - s * 0.6), Vector2(sx - s * 0.1, cen.y + s * 0.6), Vector2(sx - s * 0.2, cen.y + s * 0.6)]), Color(1, 1, 1, 0.25))
	var price := String(ad.get("price", ""))
	if price != "":
		var tag := cen + Vector2(u * 0.32, u * 0.25)
		var ps := pop(t, 0.6)
		ci.draw_circle(tag, u * 0.12 * ps, Color(0.9, 0.15, 0.15))
		star(ci, tag, u * 0.15 * ps, Color(0.9, 0.15, 0.15, 0.6), t)
		text(ci, "$" + price, tag, int(u * 0.045 * ps), Color(1, 1, 1), 3, u * 0.22)


static func product_shape(ci: CanvasItem, obj: String, p: Vector2, s: float, t: float, c: Array) -> void:
	var ink := Color(0.08, 0.08, 0.1)
	match obj:
		"can":
			box(ci, Rect2(p - Vector2(s * 0.22, s * 0.4), Vector2(s * 0.44, s * 0.8)), c[0], s * 0.06)
			ci.draw_rect(Rect2(p - Vector2(s * 0.22, s * 0.12), Vector2(s * 0.44, s * 0.22)), c[1])
			text(ci, "GLORP", p, int(s * 0.1), c[2], 3)
			ci.draw_rect(Rect2(p - Vector2(s * 0.18, s * 0.44), Vector2(s * 0.36, s * 0.05)), Color(0.75, 0.75, 0.8))
		"bottle":
			box(ci, Rect2(p - Vector2(s * 0.18, s * 0.15), Vector2(s * 0.36, s * 0.55)), c[0], s * 0.08)
			ci.draw_rect(Rect2(p - Vector2(s * 0.06, s * 0.38), Vector2(s * 0.12, s * 0.24)), c[0])
			ci.draw_rect(Rect2(p - Vector2(s * 0.08, s * 0.45), Vector2(s * 0.16, s * 0.08)), c[2])
			box(ci, Rect2(p - Vector2(s * 0.14, -s * 0.02), Vector2(s * 0.28, s * 0.22)), c[1], 4)
			PieceArt.draw_piece(ci, 3, true, p.x, p.y + s * 0.22, s * 0.13, Color.WHITE, false)
		"phone":
			box(ci, Rect2(p - Vector2(s * 0.22, s * 0.45), Vector2(s * 0.44, s * 0.9)), ink, s * 0.07)
			box(ci, Rect2(p - Vector2(s * 0.19, s * 0.41), Vector2(s * 0.38, s * 0.82)), c[1], s * 0.05)
			for i in 4:
				ci.draw_circle(p + Vector2(-s * 0.1 + (i % 2) * s * 0.09, -s * 0.33 + (i / 2) * s * 0.09), s * 0.035, ink)
				ci.draw_circle(p + Vector2(-s * 0.1 + (i % 2) * s * 0.09, -s * 0.33 + (i / 2) * s * 0.09), s * 0.018, Color(0.3, 0.4, 0.6))
		"shoe":
			var sole := PackedVector2Array([p + Vector2(-s * 0.45, s * 0.15), p + Vector2(s * 0.45, s * 0.15), p + Vector2(s * 0.48, s * 0.25), p + Vector2(-s * 0.45, s * 0.25)])
			ci.draw_colored_polygon(sole, Color(0.95, 0.95, 0.95))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.42, s * 0.15), p + Vector2(-s * 0.4, -s * 0.15), p + Vector2(-s * 0.1, -s * 0.2), p + Vector2(0.0, -s * 0.05), p + Vector2(s * 0.45, s * 0.05), p + Vector2(s * 0.45, s * 0.15)]), c[0])
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.2, s * 0.1), p + Vector2(s * 0.3, -s * 0.0), p + Vector2(s * 0.2, s * 0.12)]), c[2])
		"gourd":
			ci.draw_circle(p + Vector2(0, s * 0.15), s * 0.28, c[0])
			ci.draw_circle(p - Vector2(0, s * 0.12), s * 0.17, c[0].lightened(0.1))
			ci.draw_line(p - Vector2(0, s * 0.28), p - Vector2(-s * 0.04, s * 0.42), c[1], s * 0.05)
			ci.draw_arc(p + Vector2(0, s * 0.15), s * 0.2, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.35), 3.0)
		"headphones":
			ci.draw_arc(p, s * 0.32, PI, TAU, 24, c[0], s * 0.07)
			for sx in [-1.0, 1.0]:
				box(ci, Rect2(p + Vector2(sx * s * 0.32 - s * 0.09, -s * 0.05), Vector2(s * 0.18, s * 0.26)), c[1], s * 0.06)
				ci.draw_circle(p + Vector2(sx * s * 0.32, s * 0.08), s * 0.05, c[2])
		"pizza":
			ci.draw_circle(p, s * 0.42, Color(0.9, 0.65, 0.3))
			ci.draw_circle(p, s * 0.36, Color(0.95, 0.8, 0.35))
			for i in 9:
				ci.draw_circle(p + Vector2.from_angle(i * 2.4) * s * (0.1 + 0.2 * hash01(i)), s * 0.05, c[0])
			for i in 4:
				ci.draw_line(p, p + Vector2.from_angle(i * PI / 4.0) * s * 0.42, Color(0.8, 0.55, 0.25), 2)
				ci.draw_line(p, p - Vector2.from_angle(i * PI / 4.0) * s * 0.42, Color(0.8, 0.55, 0.25), 2)
		"watch":
			box(ci, Rect2(p - Vector2(s * 0.1, s * 0.48), Vector2(s * 0.2, s * 0.96)), Color(0.2, 0.2, 0.22), 6)
			box(ci, Rect2(p - Vector2(s * 0.2, s * 0.24), Vector2(s * 0.4, s * 0.48)), ink, s * 0.08)
			box(ci, Rect2(p - Vector2(s * 0.17, s * 0.21), Vector2(s * 0.34, s * 0.42)), c[0], s * 0.06)
			text(ci, "%d:%02d" % [10 + int(t) % 2, int(t * 7.0) % 60], p - Vector2(0, s * 0.05), int(s * 0.1), c[1], 0)
			ci.draw_arc(p + Vector2(0, s * 0.1), s * 0.07, -PI / 2, -PI / 2 + TAU * fposmod(t * 0.3, 1.0), 16, c[1], 3.0)
		"car":
			box(ci, Rect2(p - Vector2(s * 0.48, s * 0.05), Vector2(s * 0.96, s * 0.2)), c[0], s * 0.06)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.25, -s * 0.05), p + Vector2(-s * 0.15, -s * 0.22), p + Vector2(s * 0.18, -s * 0.22), p + Vector2(s * 0.3, -s * 0.05)]), c[0].darkened(0.1))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.2, -s * 0.06), p + Vector2(-s * 0.13, -s * 0.18), p + Vector2(s * 0.15, -s * 0.18), p + Vector2(s * 0.24, -s * 0.06)]), Color(0.75, 0.9, 1.0))
			for sx in [-0.28, 0.3]:
				ci.draw_circle(p + Vector2(sx * s, s * 0.16), s * 0.09, ink)
				ci.draw_circle(p + Vector2(sx * s, s * 0.16), s * 0.04, Color(0.8, 0.8, 0.85))
		"sofa":
			box(ci, Rect2(p - Vector2(s * 0.45, s * 0.2), Vector2(s * 0.9, s * 0.25)), c[0], s * 0.06)
			box(ci, Rect2(p - Vector2(s * 0.48, s * 0.02), Vector2(s * 0.96, s * 0.18)), c[0].darkened(0.1), s * 0.06)
			for i in 3:
				box(ci, Rect2(p + Vector2(-s * 0.4 + i * s * 0.27, -s * 0.04), Vector2(s * 0.25, s * 0.1)), c[1], s * 0.04)
			for sx in [-0.4, 0.4]:
				ci.draw_rect(Rect2(p + Vector2(sx * s - s * 0.02, s * 0.16), Vector2(s * 0.04, s * 0.08)), ink)
		"ram":
			box(ci, Rect2(p - Vector2(s * 0.48, s * 0.14), Vector2(s * 0.96, s * 0.28)), c[0], 4)
			for i in 6:
				ci.draw_rect(Rect2(p + Vector2(-s * 0.42 + i * s * 0.145, -s * 0.09), Vector2(s * 0.11, s * 0.14)), ink)
			for i in 20:
				ci.draw_rect(Rect2(p + Vector2(-s * 0.46 + i * s * 0.046, s * 0.1), Vector2(s * 0.03, s * 0.04)), c[1])
			text(ci, "64 GB", p - Vector2(0, s * 0.22), int(s * 0.1), c[2], 4)
		"shield":
			var sh := PackedVector2Array([p + Vector2(0, -s * 0.42), p + Vector2(s * 0.34, -s * 0.28), p + Vector2(s * 0.3, s * 0.12), p + Vector2(0, s * 0.42), p + Vector2(-s * 0.3, s * 0.12), p + Vector2(-s * 0.34, -s * 0.28)])
			ci.draw_colored_polygon(sh, c[0])
			var inner := PackedVector2Array()
			for v in sh:
				inner.append(p + (v - p) * 0.82)
			ci.draw_colored_polygon(inner, c[0].lightened(0.25))
			ci.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.14, 0), p + Vector2(-s * 0.03, s * 0.12), p + Vector2(s * 0.17, -s * 0.12)]), c[2], s * 0.06, true)
		"pawn", "knight":
			for i in 3:
				ci.draw_circle(p + Vector2(0, -s * 0.05), s * (0.42 - i * 0.08), Color(c[2], 0.12))
			PieceArt.draw_piece(ci, 1 if obj == "pawn" else 2, true, p.x, p.y + s * 0.4, s * (0.85 if obj == "pawn" else 0.55))
		_:
			# a cardboard box with a big question mark
			var b := Rect2(p - Vector2(s * 0.35, s * 0.25), Vector2(s * 0.7, s * 0.55))
			ci.draw_rect(b, Color(0.75, 0.55, 0.35))
			ci.draw_colored_polygon(PackedVector2Array([b.position, Vector2(b.end.x, b.position.y), Vector2(b.end.x - s * 0.08, b.position.y - s * 0.15), Vector2(b.position.x + s * 0.08, b.position.y - s * 0.15)]), Color(0.85, 0.65, 0.42))
			ci.draw_rect(Rect2(b.get_center().x - s * 0.04, b.position.y, s * 0.08, b.size.y), Color(0.9, 0.85, 0.7, 0.8))
			text(ci, "?", b.get_center() + Vector2(0, s * 0.03), int(s * 0.3), c[1], 6)
