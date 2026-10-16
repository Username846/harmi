class_name RoomArt
extends RefCounted
## Procedural one-point-perspective rooms for the picture box.
## Normalized picture space: back wall spans x 0.2..0.8, y 0.14..0.62.

const BX0 := 0.2
const BX1 := 0.8
const BY0 := 0.14
const BY1 := 0.62

const THEMES := {
	"dugout": {"wall": Color(0.33, 0.25, 0.18), "floor": Color(0.22, 0.16, 0.11), "ceil": Color(0.16, 0.12, 0.09), "wpat": "vplanks", "fpat": "duckboard", "cpat": "beams"},
	"trench": {"wall": Color(0.36, 0.27, 0.19), "floor": Color(0.22, 0.16, 0.11), "sky": [Color(0.24, 0.26, 0.3), Color(0.5, 0.48, 0.46)], "wall_top": 0.3, "wpat": "mud", "fpat": "duckboard"},
	"tunnel": {"wall": Color(0.28, 0.2, 0.14), "floor": Color(0.2, 0.14, 0.1), "ceil": Color(0.18, 0.13, 0.09), "wpat": "mud", "fpat": "mud", "cpat": "beams"},
	"heart": {"wall": Color(0.24, 0.07, 0.08), "floor": Color(0.13, 0.04, 0.05), "ceil": Color(0.1, 0.03, 0.04), "wpat": "veins", "fpat": "veins", "cpat": "veins", "glow": Color(0.9, 0.2, 0.1)},
	"village": {"wall": Color(0.45, 0.38, 0.32), "floor": Color(0.32, 0.3, 0.29), "sky": [Color(0.18, 0.13, 0.25), Color(0.75, 0.42, 0.3)], "wall_top": 0.22, "wpat": "facade", "fpat": "cobble"},
	"cottage": {"wall": Color(0.55, 0.47, 0.37), "floor": Color(0.36, 0.26, 0.17), "ceil": Color(0.25, 0.18, 0.12), "wpat": "timber", "fpat": "planks", "cpat": "beams"},
	"wellshaft": {"wall": Color(0.3, 0.31, 0.3), "floor": Color(0.06, 0.1, 0.12), "ceil": Color(0.12, 0.13, 0.13), "wpat": "brick", "fpat": "water", "cpat": "skyhole"},
	"cellar": {"wall": Color(0.27, 0.28, 0.27), "floor": Color(0.06, 0.1, 0.12), "ceil": Color(0.15, 0.15, 0.15), "wpat": "brick", "fpat": "water", "cpat": "vault"},
	"barracks": {"wall": Color(0.42, 0.32, 0.22), "floor": Color(0.3, 0.29, 0.28), "ceil": Color(0.22, 0.16, 0.11), "wpat": "hplanks", "fpat": "flag", "cpat": "beams"},
	"stone": {"wall": Color(0.36, 0.35, 0.34), "floor": Color(0.27, 0.26, 0.25), "ceil": Color(0.18, 0.18, 0.18), "wpat": "brick", "fpat": "flag", "cpat": "vault"},
	"castle": {"wall": Color(0.42, 0.41, 0.4), "floor": Color(0.3, 0.29, 0.28), "sky": [Color(0.15, 0.17, 0.22), Color(0.4, 0.42, 0.46)], "wall_top": 0.08, "wpat": "blocks", "fpat": "cobble"},
	"tower": {"wall": Color(0.33, 0.32, 0.31), "floor": Color(0.25, 0.24, 0.23), "ceil": Color(0.12, 0.12, 0.12), "wpat": "blocks", "fpat": "flag", "cpat": "vault"},
	"battlement": {"wall": Color(0.4, 0.39, 0.38), "floor": Color(0.3, 0.29, 0.28), "sky": [Color(0.12, 0.13, 0.2), Color(0.38, 0.38, 0.45)], "wall_top": 0.46, "wpat": "crenel", "fpat": "flag"},
	"dungeon": {"wall": Color(0.24, 0.24, 0.25), "floor": Color(0.17, 0.17, 0.17), "ceil": Color(0.1, 0.1, 0.1), "wpat": "blocks", "fpat": "flag", "cpat": "vault"},
	"wood": {"wall": Color(0.4, 0.28, 0.18), "floor": Color(0.3, 0.21, 0.14), "ceil": Color(0.2, 0.14, 0.09), "wpat": "panels", "fpat": "planks", "cpat": "beams"},
	"chapel": {"wall": Color(0.5, 0.48, 0.45), "floor": Color(0.3, 0.29, 0.28), "ceil": Color(0.2, 0.19, 0.19), "wpat": "blocks", "fpat": "carpet", "cpat": "vault"},
	"library": {"wall": Color(0.35, 0.24, 0.16), "floor": Color(0.3, 0.21, 0.14), "ceil": Color(0.15, 0.1, 0.07), "wpat": "books", "fpat": "planks", "cpat": "beams"},
}

const EXIT_RECTS := {
	"north": Rect2(0.42, 0.3, 0.16, 0.32),
	"west": Rect2(0.03, 0.3, 0.15, 0.58),
	"east": Rect2(0.82, 0.3, 0.15, 0.58),
	"south": Rect2(0.38, 0.86, 0.24, 0.14),
	"up": Rect2(0.63, 0.16, 0.16, 0.47),
	"down": Rect2(0.06, 0.8, 0.28, 0.13),
}


static func P(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x * r.size.x, y * r.size.y)


## Left (side=-1) or right (side=1) wall point at depth d (0 back, 1 front) and height h (0 floor, 1 ceiling).
static func wall_pt(r: Rect2, side: int, d: float, h: float) -> Vector2:
	var x := lerpf(BX0, 0.0, d) if side < 0 else lerpf(BX1, 1.0, d)
	var yf := lerpf(BY1, 1.0, d)
	var yc := lerpf(BY0, 0.0, d)
	return P(r, x, lerpf(yf, yc, h))


## Floor point at across u (0 left, 1 right) and depth d.
static func floor_pt(r: Rect2, u: float, d: float) -> Vector2:
	var x := lerpf(lerpf(BX0, BX1, u), u, d)
	return P(r, x, lerpf(BY1, 1.0, d))


static func ceil_pt(r: Rect2, u: float, d: float) -> Vector2:
	var x := lerpf(lerpf(BX0, BX1, u), u, d)
	return P(r, x, lerpf(BY0, 0.0, d))


static func _quad(ci: CanvasItem, pts: Array, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), c)


static func _grad_quad(ci: CanvasItem, pts: Array, cols: Array) -> void:
	ci.draw_polygon(PackedVector2Array(pts), PackedColorArray(cols))


static func draw_room(ci: CanvasItem, r: Rect2, theme_id: String, t: float) -> void:
	var th: Dictionary = THEMES.get(theme_id, THEMES["stone"])
	var wall: Color = th["wall"]
	var floor_c: Color = th["floor"]
	var line := wall.darkened(0.35)
	var has_sky := th.has("sky")
	var wt: float = th.get("wall_top", BY0) if has_sky else BY0
	var wt_h := (BY1 - wt) / (BY1 - BY0) # wall height fraction (1 = full)
	if has_sky:
		var sky: Array = th["sky"]
		_grad_quad(ci, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)],
			[sky[0], sky[0], sky[1], sky[1]])
		# drifting clouds
		for i in 5:
			var cx := fmod(0.1 + i * 0.23 + t * 0.006 * (1 + i % 2), 1.2) - 0.1
			var cy := 0.05 + (i % 3) * 0.06
			ci.draw_circle(P(r, cx, cy), r.size.x * (0.05 + (i % 2) * 0.02), Color(1, 1, 1, 0.06))
			ci.draw_circle(P(r, cx + 0.04, cy + 0.01), r.size.x * 0.04, Color(1, 1, 1, 0.05))
	else:
		var ceil_c: Color = th["ceil"]
		_quad(ci, [P(r, 0, 0), P(r, 1, 0), P(r, BX1, BY0), P(r, BX0, BY0)], ceil_c)
	# floor
	_grad_quad(ci, [P(r, BX0, BY1), P(r, BX1, BY1), P(r, 1, 1), P(r, 0, 1)],
		[floor_c.darkened(0.35), floor_c.darkened(0.35), floor_c, floor_c])
	# side walls
	var side_c := wall.darkened(0.22)
	for side in [-1, 1]:
		_grad_quad(ci, [wall_pt(r, side, 0, 0), wall_pt(r, side, 1, 0), wall_pt(r, side, 1, wt_h), wall_pt(r, side, 0, wt_h)],
			[side_c.darkened(0.25), side_c, side_c, side_c.darkened(0.25)])
	# back wall
	_grad_quad(ci, [P(r, BX0, wt), P(r, BX1, wt), P(r, BX1, BY1), P(r, BX0, BY1)],
		[wall.darkened(0.1), wall.darkened(0.1), wall, wall])
	_wall_pattern(ci, r, String(th["wpat"]), wall, line, wt, wt_h, t)
	_floor_pattern(ci, r, String(th["fpat"]), floor_c, t)
	if not has_sky:
		_ceil_pattern(ci, r, String(th.get("cpat", "")), th["ceil"], t)
	# edges
	var edge := Color(0, 0, 0, 0.35)
	ci.draw_line(P(r, BX0, BY1), P(r, BX1, BY1), edge, 2.0)
	ci.draw_line(P(r, BX0, wt), P(r, BX0, BY1), edge, 2.0)
	ci.draw_line(P(r, BX1, wt), P(r, BX1, BY1), edge, 2.0)
	ci.draw_line(P(r, BX0, BY1), P(r, 0, 1), edge, 2.0)
	ci.draw_line(P(r, BX1, BY1), P(r, 1, 1), edge, 2.0)
	if th.has("glow"):
		var g: Color = th["glow"]
		var pulse := 0.5 + 0.5 * sin(t * 2.2)
		for i in 4:
			ci.draw_circle(P(r, 0.5, 0.42), r.size.x * (0.12 + i * 0.08), Color(g.r, g.g, g.b, 0.035 + 0.02 * pulse))


static func vignette(ci: CanvasItem, r: Rect2, strength: float = 0.55) -> void:
	var k := Color(0, 0, 0, strength)
	var z := Color(0, 0, 0, 0)
	var e := r.size.x * 0.16
	var a := r.position
	var b := r.end
	_grad_quad(ci, [a, Vector2(b.x, a.y), Vector2(b.x, a.y + e), Vector2(a.x, a.y + e)], [k, k, z, z])
	_grad_quad(ci, [Vector2(a.x, b.y - e), Vector2(b.x, b.y - e), b, Vector2(a.x, b.y)], [z, z, k, k])
	_grad_quad(ci, [a, Vector2(a.x + e, a.y), Vector2(a.x + e, b.y), Vector2(a.x, b.y)], [k, z, z, k])
	_grad_quad(ci, [Vector2(b.x - e, a.y), Vector2(b.x, a.y), b, Vector2(b.x - e, b.y)], [z, k, k, z])


static func _wall_pattern(ci: CanvasItem, r: Rect2, pat: String, wall: Color, line: Color, wt: float, wt_h: float, t: float) -> void:
	var lc := Color(line.r, line.g, line.b, 0.55)
	match pat:
		"brick", "blocks":
			var rows := 10 if pat == "brick" else 6
			var bw := 0.06 if pat == "brick" else 0.1
			for i in rows + 1:
				var h := float(i) / rows
				if h > wt_h + 0.001:
					break
				var y := lerpf(BY1, BY0, h)
				ci.draw_line(P(r, BX0, y), P(r, BX1, y), lc, 1.0)
				for side in [-1, 1]:
					ci.draw_line(wall_pt(r, side, 0, h), wall_pt(r, side, 1, h), lc, 1.0)
				if i < rows and (float(i + 1) / rows) <= wt_h + 0.001:
					var y2 := lerpf(BY1, BY0, float(i + 1) / rows)
					var off := bw * 0.5 if i % 2 == 0 else 0.0
					var x := BX0 + off
					while x < BX1:
						ci.draw_line(P(r, x, y), P(r, x, y2), lc, 1.0)
						x += bw
					for side in [-1, 1]:
						var d := 0.12 + off
						while d < 1.0:
							ci.draw_line(wall_pt(r, side, d, h), wall_pt(r, side, d, float(i + 1) / rows), lc, 1.0)
							d += 0.25
		"vplanks", "panels":
			var step := 0.05 if pat == "vplanks" else 0.12
			var x := BX0
			while x <= BX1 + 0.001:
				ci.draw_line(P(r, x, wt), P(r, x, BY1), lc, 1.5)
				x += step
			for side in [-1, 1]:
				var d := 0.0
				while d <= 1.0:
					ci.draw_line(wall_pt(r, side, d, 0), wall_pt(r, side, d, wt_h), lc, 1.5)
					d += 0.14
			if pat == "panels":
				ci.draw_line(P(r, BX0, 0.5), P(r, BX1, 0.5), lc, 2.0)
				for side in [-1, 1]:
					ci.draw_line(wall_pt(r, side, 0, 0.25), wall_pt(r, side, 1, 0.25), lc, 2.0)
		"hplanks":
			for i in 12:
				var h := float(i) / 12.0
				ci.draw_line(P(r, BX0, lerpf(BY1, BY0, h)), P(r, BX1, lerpf(BY1, BY0, h)), lc, 1.2)
				for side in [-1, 1]:
					ci.draw_line(wall_pt(r, side, 0, h), wall_pt(r, side, 1, h), lc, 1.2)
		"mud":
			var rng := RandomNumberGenerator.new()
			rng.seed = 77
			for i in 40:
				var p := P(r, rng.randf_range(BX0, BX1), rng.randf_range(wt, BY1))
				ci.draw_circle(p, r.size.x * rng.randf_range(0.006, 0.02), Color(0, 0, 0, 0.12))
			# revetment stakes
			var x := BX0 + 0.04
			while x < BX1:
				ci.draw_line(P(r, x, wt), P(r, x, BY1), Color(0.2, 0.14, 0.09, 0.8), 3.0)
				x += 0.12
			for side in [-1, 1]:
				var d := 0.1
				while d < 1.0:
					ci.draw_line(wall_pt(r, side, d, 0), wall_pt(r, side, d, wt_h), Color(0.2, 0.14, 0.09, 0.8), 3.0)
					d += 0.3
		"timber":
			var beam := Color(0.28, 0.19, 0.12)
			ci.draw_line(P(r, BX0, 0.28), P(r, BX1, 0.28), beam, 6.0)
			var x := BX0
			while x <= BX1 + 0.001:
				ci.draw_line(P(r, x, BY0), P(r, x, BY1), beam, 5.0)
				x += 0.2
			for side in [-1, 1]:
				ci.draw_line(wall_pt(r, side, 0, 0.7), wall_pt(r, side, 1, 0.7), beam, 6.0)
				ci.draw_line(wall_pt(r, side, 0.5, 0), wall_pt(r, side, 0.5, 1), beam, 6.0)
		"veins":
			for i in 7:
				var pts := PackedVector2Array()
				for k in 9:
					var u := float(k) / 8.0
					pts.append(P(r, lerpf(BX0, BX1, u), lerpf(BY0 + 0.05, BY1 - 0.05, float(i) / 6.0) + sin(u * 9.0 + i * 1.7 + t * 0.8) * 0.02))
				ci.draw_polyline(pts, Color(0.55, 0.1, 0.1, 0.45), 2.0, true)
		"facade":
			# shuttered windows and a roofline
			for i in 3:
				var x0 := BX0 + 0.05 + i * 0.2
				ci.draw_rect(Rect2(P(r, x0, 0.3), r.size * Vector2(0.1, 0.12)), Color(0.22, 0.16, 0.12))
				ci.draw_line(P(r, x0 + 0.05, 0.3), P(r, x0 + 0.05, 0.42), Color(0.1, 0.07, 0.05), 2.0)
			_quad(ci, [P(r, BX0 - 0.02, wt), P(r, BX1 + 0.02, wt), P(r, BX1 - 0.05, wt - 0.06), P(r, BX0 + 0.05, wt - 0.06)], Color(0.25, 0.15, 0.13))
			for side in [-1, 1]:
				_quad(ci, [wall_pt(r, side, 0.3, 0.45), wall_pt(r, side, 0.6, 0.45), wall_pt(r, side, 0.6, 0.65), wall_pt(r, side, 0.3, 0.65)], Color(0.22, 0.16, 0.12))
		"crenel":
			var n := 6
			for i in n:
				if i % 2 == 1:
					continue
				var x0 := lerpf(BX0, BX1, float(i) / n)
				var x1 := lerpf(BX0, BX1, float(i + 1) / n)
				_quad(ci, [P(r, x0, wt), P(r, x1, wt), P(r, x1, wt - 0.06), P(r, x0, wt - 0.06)], wall)
				ci.draw_rect(Rect2(P(r, x0, wt - 0.06), r.size * Vector2(x1 - x0, 0.06)), line, false, 1.0)
			ci.draw_line(P(r, BX0, wt + 0.05), P(r, BX1, wt + 0.05), lc, 1.0)
			# lightning flicker
			if fmod(t, 7.0) < 0.12:
				ci.draw_rect(r, Color(1, 1, 1, 0.12))
		"books":
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for shelf in 6:
				var y1 := lerpf(BY1, BY0, float(shelf) / 6.0)
				var y0 := lerpf(BY1, BY0, float(shelf + 1) / 6.0)
				ci.draw_line(P(r, BX0, y1), P(r, BX1, y1), Color(0.18, 0.11, 0.07), 3.0)
				var x := BX0 + 0.005
				while x < BX1 - 0.01:
					var w := rng.randf_range(0.008, 0.018)
					var hgt := rng.randf_range(0.7, 0.95) * (y1 - y0)
					var c := Color.from_hsv(rng.randf_range(0.0, 0.15), rng.randf_range(0.3, 0.6), rng.randf_range(0.25, 0.5))
					ci.draw_rect(Rect2(P(r, x, y1 - hgt), r.size * Vector2(w, hgt)), c)
					x += w + 0.002
			for side in [-1, 1]:
				for shelf in 6:
					ci.draw_line(wall_pt(r, side, 0, float(shelf) / 6.0), wall_pt(r, side, 1, float(shelf) / 6.0), Color(0.18, 0.11, 0.07), 3.0)


static func _floor_pattern(ci: CanvasItem, r: Rect2, pat: String, floor_c: Color, t: float) -> void:
	var lc := Color(0, 0, 0, 0.25)
	var depths := [0.06, 0.15, 0.27, 0.42, 0.6, 0.8]
	match pat:
		"planks", "duckboard":
			var n := 9 if pat == "planks" else 5
			for i in n + 1:
				var u := float(i) / n
				ci.draw_line(floor_pt(r, u, 0), floor_pt(r, u, 1), lc, 1.5)
			if pat == "duckboard":
				for d in depths:
					ci.draw_line(floor_pt(r, 0.25, d), floor_pt(r, 0.75, d), Color(0.35, 0.25, 0.15, 0.7), 3.0)
		"flag", "cobble":
			for d in depths:
				ci.draw_line(floor_pt(r, 0, d), floor_pt(r, 1, d), lc, 1.2)
			var n := 6 if pat == "flag" else 12
			for i in n + 1:
				var u := float(i) / n
				ci.draw_line(floor_pt(r, u, 0), floor_pt(r, u, 1), lc, 1.0)
		"carpet":
			_quad(ci, [floor_pt(r, 0.38, 0), floor_pt(r, 0.62, 0), floor_pt(r, 0.62, 1), floor_pt(r, 0.38, 1)], Color(0.42, 0.08, 0.1))
			ci.draw_line(floor_pt(r, 0.39, 0), floor_pt(r, 0.39, 1), Color(0.8, 0.6, 0.25, 0.6), 2.0)
			ci.draw_line(floor_pt(r, 0.61, 0), floor_pt(r, 0.61, 1), Color(0.8, 0.6, 0.25, 0.6), 2.0)
		"water":
			for i in 14:
				var d := fmod(i * 0.071 + t * 0.03, 1.0)
				var u := fmod(i * 0.37, 1.0)
				var p := floor_pt(r, u, d)
				var w := r.size.x * (0.03 + d * 0.06)
				ci.draw_line(p - Vector2(w, 0), p + Vector2(w, 0), Color(0.6, 0.75, 0.8, 0.15 * (1.0 - absf(d - 0.5))), 1.5)
		"mud":
			var rng := RandomNumberGenerator.new()
			rng.seed = 13
			for i in 30:
				ci.draw_circle(floor_pt(r, rng.randf(), rng.randf()), r.size.x * rng.randf_range(0.01, 0.03), Color(0, 0, 0, 0.12))
		"veins":
			for i in 6:
				var pts := PackedVector2Array()
				for k in 8:
					var d := float(k) / 7.0
					pts.append(floor_pt(r, float(i) / 5.0 + sin(d * 6.0 + t + i) * 0.03, d))
				ci.draw_polyline(pts, Color(0.5, 0.08, 0.08, 0.5), 2.0, true)


static func _ceil_pattern(ci: CanvasItem, r: Rect2, pat: String, _ceil_c: Color, t: float) -> void:
	match pat:
		"beams":
			for d in [0.1, 0.35, 0.7]:
				ci.draw_line(ceil_pt(r, 0, d), ceil_pt(r, 1, d), Color(0.1, 0.07, 0.05), 6.0)
		"vault":
			for i in 5:
				var u := float(i) / 4.0
				ci.draw_line(ceil_pt(r, u, 0), ceil_pt(r, u, 1), Color(0, 0, 0, 0.3), 1.5)
		"skyhole":
			var c := P(r, 0.5, 0.07)
			ci.draw_colored_polygon(ObjectArt._ellipse(c, r.size.x * 0.09, r.size.y * 0.05), Color(0.6, 0.65, 0.7, 0.5))
			ci.draw_colored_polygon(ObjectArt._ellipse(c, r.size.x * 0.065, r.size.y * 0.035), Color(0.8, 0.85, 0.9, 0.6))
			# shaft of light
			_quad(ci, [P(r, 0.44, 0.07), P(r, 0.56, 0.07), P(r, 0.64, 0.9), P(r, 0.36, 0.9)], Color(0.8, 0.85, 0.9, 0.05 + 0.02 * sin(t)))
		"veins":
			for i in 5:
				var pts := PackedVector2Array()
				for k in 8:
					var d := float(k) / 7.0
					pts.append(ceil_pt(r, float(i) / 4.0 + sin(d * 5.0 + t * 0.7 + i) * 0.03, d))
				ci.draw_polyline(pts, Color(0.5, 0.08, 0.08, 0.5), 2.0, true)


# --- exits --------------------------------------------------------------------

static func draw_exit(ci: CanvasItem, r: Rect2, dir: String, ex: Dictionary, highlight: bool, t: float) -> void:
	var kind: String = ex["kind"]
	var locked: bool = ex["locked"]
	var hl := Color(1.0, 0.8, 0.35, 0.9) if highlight else Color(0, 0, 0, 0)
	match dir:
		"north":
			var pts := [P(r, 0.42, BY1), P(r, 0.58, BY1), P(r, 0.58, 0.32), P(r, 0.5, 0.29), P(r, 0.42, 0.32)]
			_opening(ci, r, pts, kind, locked, t)
			if highlight:
				var c := PackedVector2Array(pts)
				c.append(pts[0])
				ci.draw_polyline(c, hl, 3.0, true)
		"west", "east":
			var side := -1 if dir == "west" else 1
			var pts := [wall_pt(r, side, 0.28, 0), wall_pt(r, side, 0.68, 0), wall_pt(r, side, 0.68, 0.62), wall_pt(r, side, 0.28, 0.62)]
			_opening(ci, r, pts, kind, locked, t)
			if highlight:
				var c := PackedVector2Array(pts)
				c.append(pts[0])
				ci.draw_polyline(c, hl, 3.0, true)
		"south":
			var c := P(r, 0.5, 0.93)
			var w := r.size.x * 0.05
			var col := Color(0.95, 0.85, 0.6, 0.55 + 0.25 * sin(t * 3.0)) if not highlight else Color(1, 0.85, 0.4)
			var arrow := PackedVector2Array([c + Vector2(-w, -w * 0.5), c + Vector2(0, w * 0.5), c + Vector2(w, -w * 0.5)])
			ci.draw_polyline(arrow, Color(0, 0, 0, 0.6), 7.0, true)
			ci.draw_polyline(arrow, col, 4.0, true)
		"up":
			if kind == "rope_up":
				var x := 0.71 + sin(t * 1.3) * 0.004
				ci.draw_line(P(r, x, 0.0), P(r, x, 0.6), Color(0.15, 0.1, 0.05), 6.0)
				ci.draw_line(P(r, x, 0.0), P(r, x, 0.6), Color(0.72, 0.6, 0.4), 3.5)
			elif kind == "ladder_up":
				for xx in [0.67, 0.75]:
					ci.draw_line(P(r, xx, 0.14), P(r, xx, BY1), Color(0.4, 0.28, 0.16), 4.0)
				var y := 0.2
				while y < BY1:
					ci.draw_line(P(r, 0.67, y), P(r, 0.75, y), Color(0.4, 0.28, 0.16), 3.0)
					y += 0.06
			else:
				# stairs rising to an opening
				_quad(ci, [P(r, 0.66, 0.18), P(r, 0.78, 0.18), P(r, 0.78, 0.3), P(r, 0.66, 0.3)], Color(0.03, 0.02, 0.03))
				for i in 6:
					var y0 := BY1 - i * 0.055
					var x0 := 0.64 + i * 0.012
					_quad(ci, [P(r, x0, y0), P(r, 0.8, y0), P(r, 0.8, y0 - 0.055), P(r, x0, y0 - 0.055)], Color(0.34, 0.32, 0.3).darkened(i * 0.08))
					ci.draw_line(P(r, x0, y0 - 0.055), P(r, 0.8, y0 - 0.055), Color(0, 0, 0, 0.4), 1.5)
			if highlight:
				ci.draw_rect(Rect2(P(r, 0.63, 0.16), r.size * Vector2(0.16, 0.47)), hl, false, 3.0)
			_arrow_marker(ci, P(r, 0.71, 0.13), -1, t)
		"down":
			var pts := [floor_pt(r, 0.08, 0.5), floor_pt(r, 0.36, 0.5), floor_pt(r, 0.38, 0.8), floor_pt(r, 0.04, 0.8)]
			_quad(ci, pts, Color(0.02, 0.015, 0.02))
			var c := PackedVector2Array(pts)
			c.append(pts[0])
			ci.draw_polyline(c, Color(0.3, 0.22, 0.15), 3.0, true)
			if kind == "rope_down":
				ci.draw_line(floor_pt(r, 0.22, 0.48), floor_pt(r, 0.22, 0.78), Color(0.72, 0.6, 0.4), 3.5)
			elif kind == "stairs_down":
				for i in 4:
					var d := 0.55 + i * 0.06
					ci.draw_line(floor_pt(r, 0.09 + i * 0.01, d), floor_pt(r, 0.35 - i * 0.01, d), Color(0.3, 0.28, 0.26), 3.0)
			if highlight:
				ci.draw_polyline(c, hl, 3.0, true)
			_arrow_marker(ci, floor_pt(r, 0.22, 0.65), 1, t)


static func _arrow_marker(ci: CanvasItem, p: Vector2, dir_y: int, t: float) -> void:
	var bob := sin(t * 3.0) * 3.0
	var w := 9.0
	var pts := PackedVector2Array([p + Vector2(-w, -w * 0.5 * dir_y + bob), p + Vector2(0, w * 0.5 * dir_y + bob), p + Vector2(w, -w * 0.5 * dir_y + bob)])
	ci.draw_polyline(pts, Color(0, 0, 0, 0.6), 6.0, true)
	ci.draw_polyline(pts, Color(0.95, 0.85, 0.6, 0.9), 3.0, true)


static func _opening(ci: CanvasItem, r: Rect2, pts: Array, kind: String, locked: bool, t: float) -> void:
	var poly := PackedVector2Array(pts)
	var top := poly[2].y
	var bot := poly[0].y
	for p in poly:
		top = minf(top, p.y)
		bot = maxf(bot, p.y)
	var cols := PackedColorArray()
	for p in poly:
		var k := (p.y - top) / maxf(1.0, bot - top)
		cols.append(Color(0.02, 0.015, 0.02).lerp(Color(0.08, 0.06, 0.06), k))
	ci.draw_polygon(poly, cols)
	var frame := poly.duplicate()
	frame.append(poly[0])
	var frame_c := Color(0.2, 0.15, 0.12)
	if kind == "arch" or kind == "vault":
		frame_c = Color(0.45, 0.43, 0.4)
	ci.draw_polyline(frame, frame_c, 5.0, true)
	if not locked:
		return
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	match kind:
		"door":
			ci.draw_colored_polygon(poly, Color(0.36, 0.23, 0.14))
			var n := 4
			for i in range(1, n):
				var a := poly[0].lerp(poly[1], float(i) / n)
				var b := poly[3].lerp(poly[2], float(i) / n)
				if poly.size() == 5:
					b = Vector2(a.x, bb.position.y + bb.size.y * 0.06)
				ci.draw_line(a, b, Color(0.2, 0.12, 0.07), 1.5)
			for k in [0.25, 0.7]:
				var a2 := poly[0].lerp(poly[poly.size() - 1], k)
				var b2 := poly[1].lerp(poly[2], k)
				ci.draw_line(a2, b2, Color(0.15, 0.15, 0.17), 4.0)
			ci.draw_circle(bb.get_center() + Vector2(bb.size.x * 0.25, bb.size.y * 0.08), maxf(2.5, bb.size.x * 0.06), Color(0.75, 0.6, 0.3))
			ci.draw_polyline(frame, Color(0.15, 0.1, 0.07), 3.0, true)
		"grate", "cell", "portcullis":
			var n := 6
			for i in range(1, n):
				var a := poly[0].lerp(poly[1], float(i) / n)
				var b := poly[poly.size() - 1].lerp(poly[2], float(i) / n) if poly.size() == 4 else Vector2(a.x, bb.position.y + 4)
				ci.draw_line(a, b, Color(0.12, 0.12, 0.13), 4.0)
				ci.draw_line(a, b, Color(0.4, 0.38, 0.38), 2.0)
			for k in [0.3, 0.65]:
				var a2 := poly[0].lerp(poly[poly.size() - 1], k)
				var b2 := poly[1].lerp(poly[2], k)
				ci.draw_line(a2, b2, Color(0.4, 0.38, 0.38), 3.0)
			if kind == "cell":
				var c := bb.get_center()
				ci.draw_circle(c, bb.size.x * 0.12, Color(0.9, 0.25, 0.1, 0.1 + 0.08 * sin(t * 3.0)))
		"vault":
			var c := bb.get_center()
			var rad := minf(bb.size.x, bb.size.y) * 0.48
			ci.draw_circle(c, rad, Color(0.3, 0.31, 0.33))
			ci.draw_arc(c, rad, 0, TAU, 32, Color(0.15, 0.15, 0.16), 3.0, true)
			ci.draw_arc(c, rad * 0.6, 0, TAU, 24, Color(0.2, 0.2, 0.22), 2.0, true)
			for i in 4:
				var a := TAU * i / 4.0 + t * 0.2
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * rad * 0.55, Color(0.55, 0.5, 0.4), 3.0)
		_:
			pass
