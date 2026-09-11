extends SceneTree

var failures: int = 0
var world: Node3D
var player: CharacterBody3D


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame


func place(at: Vector3) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_backward"]:
		Input.action_release(action)
	player.global_position = at
	player.velocity = Vector3.ZERO
	await frames(4)


func use() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)


func _run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	await frames(10)
	check(player.is_on_floor(), "Player lands on original room floor")
	check(world.get_node("Station").restock_items.all(func(item): return not item.visible), "Shelf has visible gaps before restocking")
	check(player.sprite.sprite_frames.get_frame_texture(&"walk_right", 0) != null, "Player texture imports")
	var texture: AtlasTexture = player.sprite.sprite_frames.get_frame_texture(&"walk_down", 0)
	check(texture.atlas.get_size() == Vector2(512, 320), "Original 512x320 artwork retained")
	var directions := {"move_left": &"left", "move_right": &"right", "move_forward": &"up", "move_backward": &"down"}
	for action in directions:
		await place(Vector3(0, 0.05, 0))
		Input.action_press(action)
		await frames(25)
		check(player.sprite.animation == StringName("walk_" + String(directions[action])), "Walk direction: " + action)
		check(Vector2(player.velocity.x, player.velocity.z).length() <= 4.001, "Speed bounded: " + action)
		Input.action_release(action)
		await frames(25)
		check(player.sprite.animation == StringName("idle_" + String(directions[action])), "Idle direction: " + action)
	for x in ["move_left", "move_right"]:
		for z in ["move_forward", "move_backward"]:
			await place(Vector3(0, 0.05, 0))
			Input.action_press(x)
			Input.action_press(z)
			await frames(20)
			check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 4.0), "Diagonal speed: " + x + "/" + z)
	await place(Vector3(0, 0.05, 0))
	Input.action_press("move_right")
	var visited: Dictionary = {}
	for i in range(70):
		await frames(1)
		visited[player.sprite.frame] = true
	check(visited.size() == 8, "Side walk advances through all eight frames without restarting")
	player.sprite.set_frame_and_progress(5, 0.3)
	player.facing = &"left"
	player._update_animation(Vector3.LEFT * 4)
	check(player.sprite.frame == 5 and is_equal_approx(player.sprite.frame_progress, 0.3), "Direction changes preserve stride phase")
	await place(Vector3(6.2, 0.05, 0))
	Input.action_press("move_right")
	await frames(40)
	check(player.position.x < 6.6, "East wall blocks movement")
	check(player.sprite.animation == &"idle_right", "Blocked player stops walking animation")
	await place(Vector3(6.2, 0.05, 0))
	var hidden_object := Node3D.new()
	hidden_object.set_script(load("res://scenes/interactions/interactable.gd"))
	hidden_object.position = Vector3(7.5, 0, 0)
	world.add_child(hidden_object)
	await frames(3)
	check(player.interaction_target == null, "Interaction cannot reach through a wall")
	hidden_object.queue_free()
	await place(Vector3(-4.8, 0.05, -2.3))
	await use()
	check(world.phase == 0 and world.completed.is_empty(), "Tasks cannot complete before shift begins")
	await place(Vector3(4.8, 0.05, -2.3))
	await use()
	check(world.get_node("Station").restock_items.all(func(item): return not item.visible), "Shelf cannot be filled before shift begins")
	await place(Vector3(-4.8, 0.05, 3.7))
	check(player.interaction_target == world.get_node("Station/ShiftBoard"), "Nearby shift board selected")
	await use()
	check(world.phase == 1, "E key begins shift")
	await place(Vector3(4.6, 0.05, 3.6))
	await use()
	check(world.phase == 1, "Register rejects incomplete checklist")
	await place(Vector3(-4.8, 0.05, -2.3))
	await use()
	await use()
	check(world.completed.size() == 1, "Cooler task is idempotent")
	await place(Vector3(4.8, 0.05, -2.3))
	await use()
	check(world.completed.size() == 2, "Shelf completes second task")
	check(world.get_node("Station").restock_items.all(func(item): return item.visible), "Restocking fills shelf in the game world")
	check(world.get_node("Station/Shelf").prompt == "Regal ansehen", "Restocked shelf has the correct prompt")
	await use()
	check(world.get_node("Station").restock_items.size() == 8 and world.completed.size() == 2, "Repeated restocking does not duplicate bottles or tasks")
	await place(Vector3(4.6, 0.05, 3.6))
	await use()
	check(world.phase == 2, "Full shift sequence completes through actual input")
	var door := world.get_node("Station/Door")
	await place(Vector3(0, 0.05, 3.9))
	Input.action_press("move_backward")
	await frames(20)
	Input.action_release("move_backward")
	check(player.position.z < 4.7, "Closed door blocks passage")
	await use()
	await frames(40)
	check(door.is_open and door.panel.collision_layer == 0, "Door opens and clears collision")
	Input.action_press("move_backward")
	await frames(35)
	Input.action_release("move_backward")
	check(player.position.z > 6.0 and player.is_on_floor(), "Player walks from room to forecourt")
	await place(Vector3(0, 0.05, 5))
	await use()
	await frames(40)
	check(door.is_open and not door.moving, "Door refuses to close on player in doorway")
	await place(Vector3(0, 0.05, 6.3))
	await use()
	await frames(8)
	await place(Vector3(0, 0.05, 5))
	await frames(70)
	check(door.is_open and door.panel.collision_layer == 0, "Door reopens if player enters while closing")
	await place(Vector3(0, 0.05, 6.3))
	await use()
	await frames(40)
	check(not door.is_open and door.panel.collision_layer == 1, "Clear doorway closes with collision restored")
	await place(Vector3(0, 0.05, 10.2))
	Input.action_press("move_backward")
	await frames(40)
	Input.action_release("move_backward")
	check(player.position.z < 10.6 and player.is_on_floor(), "Forecourt boundary prevents falling out")
	check(world.get_node("Ambience").playing, "Ambient audio starts")
	var held_key := InputEventKey.new()
	held_key.physical_keycode = KEY_M
	held_key.pressed = true
	held_key.echo = true
	world._unhandled_input(held_key)
	check(not world.muted, "Keyboard auto-repeat does not toggle audio")
	var mute_event := InputEventAction.new()
	mute_event.action = &"mute_audio"
	mute_event.pressed = true
	Input.parse_input_event(mute_event)
	await frames(2)
	check(world.muted and world.get_node("Ambience").volume_db == -80.0, "Mute silences ambience")
	mute_event.pressed = false
	Input.parse_input_event(mute_event)
	await frames(2)
	mute_event = InputEventAction.new()
	mute_event.action = &"mute_audio"
	mute_event.pressed = true
	Input.parse_input_event(mute_event)
	await frames(2)
	check(not world.muted, "Audio can be enabled again")
	# A manually instantiated scene needs its source path for reload_current_scene.
	var restart_event := InputEventAction.new()
	restart_event.action = &"restart_shift"
	restart_event.pressed = true
	Input.parse_input_event(restart_event)
	await frames(10)
	world = current_scene
	player = world.get_node("Player")
	check(world.phase == 0 and world.completed.is_empty(), "Restart resets completed shift")
	check(world.get_node("Station").restock_items.all(func(item): return not item.visible), "Restart resets visible shelf stock")
	check(player.position.distance_to(Vector3(0, 0, 1.5)) < 0.1, "Restart returns player to spawn")
	print("NIGHTSHIFT TESTS: " + str(failures) + " failure(s)")
	world.queue_free()
	await frames(3)
	# The audio mixer releases playback references asynchronously, even headless.
	await create_timer(0.3).timeout
	quit(0 if failures == 0 else 1)
