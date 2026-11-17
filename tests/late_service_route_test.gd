extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	world.position = Vector3(20,0,-15)
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.career_shifts = 4
	loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(5))
	world.story_world.apply_night()
	world.phase = world.Phase.ACTIVE
	loop.active = true
	loop.set_process(false)
	player.global_position = layout.operator_point.global_position
	await physics_frame
	loop.navigation.rebuild(world,layout.doors)
	var kit: Vector3 = layout.cleaning_station.get_node("Approach").global_position
	check(await walk(kit),"Night 5 route reaches the cleaning kit on the translated station")
	check(await walk(layout.operator_point.global_position),"Night 5 route returns to the register")
	check(await walk(kit),"The same route remains reachable on a second approach")
	await finish()
