extends "res://tests/vertical_slice_test.gd"

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.player
	loop = world.gameplay
	layout = world.layout
	await physics_frame
	var floor_shape: BoxShape3D = world.get_node("PrototypeRoom/Floor/CollisionShape3D").shape
	check(floor_shape.size.x*floor_shape.size.z >= 190,"The usable shop floor has been expanded")
	var dressing = world.get_node("Station/StationDressing")
	var left: Node3D = dressing.get_node("SnackIsland")
	var middle: Node3D = dressing.get_node("TravelIsland")
	var right: Node3D = dressing.get_node("DailyIsland")
	check(middle.position.x-left.position.x >= 3.0 and right.position.x-middle.position.x >= 3.0,"Display islands leave room for two bodies to pass")
	loop.navigation.rebuild(world,layout.doors)
	for x in [-7.7,(left.position.x+middle.position.x)/2,(middle.position.x+right.position.x)/2]:
		await walk(world.to_global(Vector3(x,0,0.9)))
		Input.action_press("move_forward")
		var deadline := Time.get_ticks_msec()+5000
		while world.to_local(player.global_position).z > -4.45 and Time.get_ticks_msec() < deadline:
			await physics_frame
		Input.action_release("move_forward")
		check(world.to_local(player.global_position).z <= -4.45,"Player traverses the aisle directly at x %.2f" % x)
	await walk(layout.product_points[&"energy"].global_position)
	await walk(layout.product_points[&"chips"].global_position)
	await walk(layout.product_points[&"water"].global_position)
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	await walk(layout.operator_point.global_position)
	await walk(layout.entrance.global_position+Vector3(0,0,1))
	await finish()
