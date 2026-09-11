extends SceneTree

const INPUT = "res://tools/animation_sources/opposite_step.png"
const OUTPUT = "res://assets/sprites/player_side/"

func _initialize() -> void:
	var source := Image.load_from_file(INPUT)
	print("Source: ", source.get_size(), " corner alpha: ", source.get_pixel(0, 0).a)
	assert(source.get_pixel(0, 0).a == 0.0, "Generation must have real transparency")
	var retained: Array[Image] = []
	for i in range(4):
		retained.append(Image.load_from_file("res://tools/animation_sources/walk_side_%02d.png" % (i + 1)))
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var frames: Array[Image] = []
	for i in range(8):
		var cell := Rect2i(int(i % 4 * source.get_width() / 4.0), int(i / 4) * int(source.get_height() / 2.0), int(source.get_width() / 4.0), int(source.get_height() / 2.0))
		var tile := source.get_region(cell)
		var bounds := Rect2i(0, 0, 0, 0)
		for y in range(tile.get_height()):
			for x in range(tile.get_width()):
				if tile.get_pixel(x, y).a > 0.8:
					if bounds.size == Vector2i.ZERO:
						bounds = Rect2i(x, y, 1, 1)
					else:
						bounds = bounds.expand(Vector2i(x, y))
		# Register by the head centre and the common ground baseline, never by foot width.
		var head_left := 10000
		var head_right := 0
		for y in range(bounds.position.y, bounds.position.y + 100):
			for x in range(tile.get_width()):
				if tile.get_pixel(x, y).a > 0.8:
					head_left = mini(head_left, x)
					head_right = maxi(head_right, x)
		var anchor_x := (head_left + head_right) / 2.0
		var scale_factor := 74.0 / bounds.size.y
		var frame := Image.create(64, 80, false, Image.FORMAT_RGBA8)
		for y in range(80):
			for x in range(64):
				var sx := int(round(anchor_x + (x - 34.0) / scale_factor))
				var sy := int(round(bounds.position.y + (y - 5.0) / scale_factor))
				if sx >= 0 and sy >= 0 and sx < tile.get_width() and sy < tile.get_height():
					var color := tile.get_pixel(sx, sy)
					color.a = 1.0 if color.a >= 0.8 else 0.0
					frame.set_pixel(x, y, color)
		print("Frame ", i + 1, " bounds ", bounds, " anchor ", anchor_x)
		frames.append(retained[i] if i < 4 else frame)
	# Use one fixed head/chest crop throughout the cycle. Moving hands/legs stay independent.
	for i in range(8):
		frames[i].blit_rect(frames[0], Rect2i(0, 0, 64, 43), Vector2i.ZERO)
		frames[i].save_png(OUTPUT + "walk_side_%02d.png" % (i + 1))
		var left := frames[i].duplicate()
		left.flip_x()
		left.save_png(OUTPUT + "walk_left_%02d.png" % (i + 1))
	var idle_source := Image.load_from_file("res://tools/animation_sources/idle_source.png")
	var idle_bounds := idle_source.get_used_rect()
	var head_left := 10000
	var head_right := 0
	for y in range(idle_bounds.position.y, idle_bounds.position.y + int(idle_bounds.size.y * 0.24)):
		for x in range(idle_source.get_width()):
			if idle_source.get_pixel(x, y).a > 0.8:
				head_left = mini(head_left, x)
				head_right = maxi(head_right, x)
	var idle_scale := 74.0 / idle_bounds.size.y
	var idle := Image.create(64, 80, false, Image.FORMAT_RGBA8)
	for y in range(80):
		for x in range(64):
			var sx := int(round((head_left + head_right) / 2.0 + (x - 34.0) / idle_scale))
			var sy := int(round(idle_bounds.position.y + (y - 5.0) / idle_scale))
			if sx >= 0 and sy >= 0 and sx < idle_source.get_width() and sy < idle_source.get_height():
				var color := idle_source.get_pixel(sx, sy)
				color.a = 1.0 if color.a >= 0.8 else 0.0
				idle.set_pixel(x, y, color)
	idle.blit_rect(frames[0], Rect2i(0, 0, 64, 43), Vector2i.ZERO)
	idle.save_png(OUTPUT + "idle_side.png")
	idle.flip_x()
	idle.save_png(OUTPUT + "idle_left.png")
	quit()
