extends "res://tests/campaign_test.gd"

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await physics_frame
	loop.navigation.rebuild(world,layout.doors)
	player.global_position = layout.operator_point.global_position
	var people: Array[CharacterBody3D] = []
	for offset in [Vector3(-1.04,0,0.68),Vector3(-1.08,0,1.20)]:
		var person := CharacterBody3D.new()
		person.set_script(preload("res://scripts/customer.gd"))
		world.add_child(person)
		person.navigation = loop.navigation
		person.doors = layout.doors
		person.global_position = layout.checkout.global_position + offset
		people.append(person)
	people[0].go_to(layout.queue_points[0])
	var deadline := Time.get_ticks_msec()+20000
	while people[0].walking and Time.get_ticks_msec()<deadline: await physics_frame
	check(not people[0].walking and people[0].global_position.distance_to(layout.queue_points[0].global_position)<0.6,"Queue leader routes around a stationary follower in reproduced Night 2 blockage")
	check(people[0].global_position.distance_to(people[1].global_position)>0.52,"Recovered queue does not overlap bodies")
	await finish()
