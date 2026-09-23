extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.career_shifts = 3
	loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(4))
	await create_timer(0.1).timeout
	var story = world.story_world
	loop.navigation.rebuild(world,layout.doors)
	var route_point: Node3D = story.get_node("route")
	var route: PackedVector3Array = loop.navigation.path(player.global_position,route_point.global_position)
	check(not route.is_empty(),"Night 4 route marker stays on the walkable branch")
	await walk(route_point.global_position)
	player._update_interaction()
	check(player.interaction_target == route_point,"Player can interact at the physical route marker")
	await use()
	while story.trip_busy: await create_timer(0.1).timeout
	check(story.in_depot,"Night 4 route reaches the depot through the physical interaction")
	loop.navigation.rebuild(world,layout.doors)
	for action in [&"move_left",&"move_right",&"move_forward",&"move_backward"]:
		player.global_position = story.depot.global_position+Vector3(0,0.05,0)
		player.velocity = Vector3.ZERO
		Input.action_press(action)
		await create_timer(1.2).timeout
		Input.action_release(action)
		await create_timer(0.2).timeout
		var local: Vector3 = story.depot.to_local(player.global_position)
		check(absf(local.x)<2.8 and absf(local.z)<2.8 and local.y > -0.1,"Depot boundary blocks movement without falling: "+String(action))
	await walk(story.depot.get_node("depot_clerk").global_position)
	await use()
	check(loop.dialogue.active,"Clerk remains reachable with solid counter")
	while loop.dialogue.active: await key(KEY_SPACE)
	await walk(story.depot.get_node("return").global_position)
	await use()
	while story.trip_busy: await create_timer(0.1).timeout
	check(not story.in_depot,"Player returns through physical depot interaction")
	await finish()
