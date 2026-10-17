extends SceneTree
## Renders every card face (at two sizes), the card back and Yugi's four
## expressions, animating through many time steps so polygon problems show up
## as renderer errors, then saves the last frame to a PNG for eyeballing.
## Needs a display, e.g.:
## xvfb-run godot --path . -s tests/card_gallery.gd -- out=/tmp/gallery.png w=100 frames=120

var canvas: Control
var frames := 0
var max_frames := 120
var out_path := "user://card_gallery.png"
var card_w := 100.0
var t := 0.0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"out":
				out_path = kv[1]
			"w":
				card_w = float(kv[1])
			"frames":
				max_frames = int(kv[1])
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_factor = 1.0
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(_draw_gallery)
	root.add_child(canvas)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	t += 0.173
	canvas.queue_redraw()
	if frames == max_frames:
		var img := root.get_texture().get_image()
		img.save_png(out_path)
		print("saved ", out_path, " ", img.get_size(), " after ", frames, " frames")
		quit()


func _draw_gallery() -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), UI.BG)
	var ids := CardData.all_ids()
	var x := 8.0
	var y := 8.0
	var row_h := 0.0
	for pass_w in [card_w, card_w * 0.45]:
		var w: float = pass_w
		var h := w * CardArt.ASPECT
		for i in ids.size() + 1:
			if x + w > canvas.size.x - 8.0:
				x = 8.0
				y += row_h + 8.0
			var r := Rect2(x, y, w, h)
			if i == ids.size():
				CardArt.draw_back(canvas, r, t)
			else:
				CardArt.draw_card(canvas, r, String(ids[i]), {"white": i % 2 == 0, "t": t + i})
			row_h = h
			x += w + 8.0
		x = 8.0
		y += row_h + 12.0
	var exprs := ["smug", "shocked", "happy", "determined"]
	var sizes := [120.0, 200.0, 300.0, 160.0]
	for e in exprs.size():
		var hh: float = sizes[e]
		var rr := Rect2(x, y, hh * 0.8, hh)
		canvas.draw_rect(rr, Color(1, 1, 1, 0.06), false, 1.0)
		YugiArt.draw(canvas, rr, t + e, exprs[e])
		x += hh * 0.8 + 10.0
