extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + description)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func raised_sole_x(picture: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(58, 74):
		for x in range(64):
			var color := picture.get_pixel(x, y)
			if color.a > 0.5 and minf(color.r, minf(color.g, color.b)) > 0.55:
				total += x
				count += 1
	return total / maxi(count, 1)

func run() -> void:
	var scene: Node3D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(scene)
	var player: CharacterBody3D = scene.get_node("Player")
	await frames(8)
	var animations: SpriteFrames = player.sprite.sprite_frames
	var first := animations.get_frame_texture(&"walk_right", 0).get_image()
	var baseline_min := 80
	var baseline_max := 0
	var foot_widths: Array[int] = []
	for i in range(8):
		var right_texture := animations.get_frame_texture(&"walk_right", i)
		var left_texture := animations.get_frame_texture(&"walk_left", i)
		var right := right_texture.get_image()
		var left := left_texture.get_image()
		check(not right_texture is AtlasTexture and not left_texture is AtlasTexture, "Standalone PNG frame %d" % (i + 1))
		check(right.get_size() == Vector2i(64, 80) and left.get_size() == Vector2i(64, 80), "Equal canvas frame %d" % (i + 1))
		var stable := true
		var mirrored := true
		var sharp_alpha := true
		var min_foot := 64
		var max_foot := 0
		var ground := 0
		for y in range(80):
			for x in range(64):
				var color := right.get_pixel(x, y)
				if y < 43 and color != first.get_pixel(x, y):
					stable = false
				if color != left.get_pixel(63 - x, y):
					mirrored = false
				if color.a > 0.0 and color.a < 1.0:
					sharp_alpha = false
				if color.a > 0.5:
					ground = maxi(ground, y)
					if y >= 66:
						min_foot = mini(min_foot, x)
						max_foot = maxi(max_foot, x)
		baseline_min = mini(baseline_min, ground)
		baseline_max = maxi(baseline_max, ground)
		foot_widths.append(max_foot - min_foot)
		check(stable, "Identical head/chest frame %d" % (i + 1))
		check(mirrored, "Exact left/right mirror frame %d" % (i + 1))
		check(sharp_alpha, "Hard pixel alpha frame %d" % (i + 1))
	check(baseline_max - baseline_min <= 1, "Ground contact differs by at most one pixel")
	check(foot_widths[0] - foot_widths[2] >= 10 and foot_widths[4] - foot_widths[6] >= 10, "Both half-cycles contain a narrow passing pose, not only a wide stance")
	var first_passing := raised_sole_x(animations.get_frame_texture(&"walk_right", 2).get_image())
	var opposite_passing := raised_sole_x(animations.get_frame_texture(&"walk_right", 6).get_image())
	check(opposite_passing - first_passing > 4.0, "Opposite half has a distinct raised-foot position instead of repeating the first half")
	print("Raised sole centres: ", first_passing, " / ", opposite_passing)
	for direction in [&"right", &"left"]:
		var idle := animations.get_frame_texture(StringName("idle_" + String(direction)), 0)
		check(not idle is AtlasTexture and idle.get_size() == Vector2(64, 80), "Neutral standalone idle: " + String(direction))
	var sprite_position: Vector3 = player.sprite.position
	var camera_offset: Vector3 = player.get_node("CameraRig/Camera3D").position
	for direction in ["move_right", "move_left"]:
		player.position = Vector3(0, 0.05, 0)
		player.velocity = Vector3.ZERO
		Input.action_press(direction)
		var seen := {}
		for i in range(65):
			await frames(1)
			seen[player.sprite.frame] = true
		check(seen.size() == 8, "Runtime visits full cycle: " + direction)
		check(player.sprite.position == sprite_position, "Sprite pivot does not bounce: " + direction)
		Input.action_release(direction)
		await frames(20)
		check(String(player.sprite.animation).begins_with("idle_"), "Walk to idle settles: " + direction)
	for i in range(12):
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_press("move_left" if i % 2 == 0 else "move_right")
		await frames(4)
		check(player.sprite.frame >= 0 and player.sprite.frame < 8, "Rapid reversal remains in valid cycle %d" % i)
	Input.action_release("move_left")
	Input.action_release("move_right")
	await frames(20)
	check(not player.sprite.flip_h, "No double flip applied to mirrored PNGs")
	check(player.get_node("CameraRig/Camera3D").position == camera_offset, "Camera offset unchanged")
	print("SIDEWALK TESTS: %d failure(s); foot widths: %s; baseline: %d..%d" % [failures, str(foot_widths), baseline_min, baseline_max])
	scene.queue_free()
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)
