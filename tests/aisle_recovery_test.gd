extends "res://tests/campaign_test.gd"
## Staged reproduction of the shifted-map stress failure. Not yet executed.
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	world.position = Vector3(20,0,-15)
	root.add_child(world)
	current_scene = world
	bind_world()
	await physics_frame
	loop.navigation.rebuild(world,layout.doors)
	player.global_position = layout.operator_point.global_position
	var people: Array[CharacterBody3D] = []
	for offset in [Vector3(3.552771,0,-0.265782),Vector3(2.990049,0,-0.585822)]:
		var person := CharacterBody3D.new()
		person.set_script(preload("res://scripts/customer.gd"))
		world.add_child(person)
		person.navigation = loop.navigation
		person.doors = layout.doors
		person.global_position = world.to_global(offset)
		people.append(person)
	people[0].go_to(layout.queue_points[0])
	people[1].go_to(layout.product_points[&"water"])
	for person in people: person.plan(true)
	var deadline := Time.get_ticks_msec()+25000
	while people.any(func(person): return person.walking) and Time.get_ticks_msec()<deadline:
		await physics_frame
	for person in people:
		check(not person.walking,"Opposing customer reaches destination through shop aisle")
		if person.walking:
			print("AISLE position=",person.global_position," target=",person.target.global_position," route=",person.route)
			print("STATIC PATH=",loop.navigation.path(person.global_position,person.target.global_position))
			for i in person.get_slide_collision_count():
				print("CONTACT=",person.get_slide_collision(i).get_collider().get_path())
	await finish()
