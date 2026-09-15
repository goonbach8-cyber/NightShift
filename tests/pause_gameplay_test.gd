extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	world.phase = world.Phase.ACTIVE
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.walking = false
	customer.state = &"queued"
	customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(customer)
	player.global_position = layout.operator_point.global_position
	loop.active = true
	loop.spawned = loop.customer_count
	var answers: Array[Dictionary] = []
	loop.dialogue.begin(customer.get_instance_id(),PackedStringArray(["First line","Second line"]),answers,loop.story_flags)
	await key(KEY_ESCAPE)
	var elapsed: float = loop.elapsed
	var patience: float = customer.wait_seconds
	var origin: Vector3 = player.global_position
	for code in [KEY_E,KEY_F,KEY_SPACE,KEY_1,KEY_2,KEY_TAB,KEY_T,KEY_Y,KEY_M]: await key(code)
	Input.action_press("move_right")
	await create_timer(0.2).timeout
	check(paused and loop.elapsed == elapsed,"Pause freezes shift clock")
	check(customer.wait_seconds == patience,"Pause freezes customer patience")
	check(player.global_position == origin,"Pause blocks held movement")
	check(loop.dialogue.index == 0 and loop.dialogue.active,"Pause prevents background dialogue input")
	check(loop.scanned_units == 0 and loop.revenue_rappen == 0,"Pause prevents checkout")
	check(not world.radio.enabled and not world.muted,"Pause prevents radio and mute inputs")
	await key(KEY_ESCAPE)
	check(not paused and not Input.is_action_pressed("move_right"),"Resume clears held actions")
	await key(KEY_SPACE)
	check(loop.dialogue.index == 1,"Dialogue input resumes after pause")
	loop.dialogue.close()
	await finish()
