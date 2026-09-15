extends "res://tests/vertical_slice_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	if "--shift-layout" in OS.get_cmdline_user_args(): world.position = Vector3(20,0,-15)
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	loop = world.gameplay
	loop.quick_checkout = true # Routing/legacy fixture; staged checkout has a dedicated test.
	layout = world.layout
	loop.customer_count = 8
	loop.spawn_interval = 2
	loop.order_patterns.assign([{&"water":1}])
	player.global_position = world.get_node("Station/ShiftBoard").global_position+Vector3(0,0.05,1)
	await create_timer(0.5).timeout
	await use()
	while loop.preparing: await process_frame
	loop.stock.shelf_units = 8
	loop.stock.changed.emit()
	await walk(layout.operator_point.global_position)
	var deadline := Time.get_ticks_msec()+90000
	while (loop.queue.size() < 4 or loop.queue.any(func(c): return c.walking)) and Time.get_ticks_msec() < deadline:
		await create_timer(0.25).timeout
	check(loop.queue.size() == 4 and loop.queue.all(func(c): return not c.walking),"Four customers reach separate queue markers")
	for customer in loop.customers:
		print("QUEUE DEBUG ",customer.name," ",customer.state," at ",customer.global_position," walking ",customer.walking," route ",customer.route)
		for j in customer.get_slide_collision_count():
			var hit = customer.get_slide_collision(j)
			print("CONTACT ",hit.get_collider().get_path()," ",hit.get_position()," ",hit.get_normal())
	for i in loop.queue.size():
		for j in range(i+1,loop.queue.size()):
			check(loop.queue[i].global_position.distance_to(loop.queue[j].global_position) > 0.5,"Queue bodies do not overlap")
	await capture("four-person-queue")
	var tail: Vector3 = layout.queue_points[-1].global_position
	var head: Vector3 = layout.queue_points[0].global_position
	for point in [tail+Vector3(-1.0,0,-0.8),tail+Vector3(-1.0,0,0.9),head+Vector3(0.8,0,0.9),head+Vector3(1.3,0,0),layout.operator_point.global_position+Vector3(1.6,0,0),layout.operator_point.global_position]:
		await walk(point)
	check(loop.queue.size() == 4,"Player can pass behind and beside four waiting customers")
	await walk(tail+Vector3(-1.0,0,-0.8))
	await walk(layout.entrance.global_position+Vector3(0,0,-1.1))
	await walk(layout.entrance.global_position+Vector3(0,0,1.0))
	check(player.global_position.z > layout.entrance.global_position.z,"Entrance remains reachable with full queue")
	await walk(layout.entrance.global_position+Vector3(0,0,-1.1))
	await walk(tail+Vector3(-1.0,0,-0.8))
	await walk(layout.operator_point.global_position)
	for i in 8:
		if not await await_customer():
			await finish()
			return
		await use()
	check(loop.served == 8 and loop.lost_sales == 0 and loop.stock.shelf_units == 0,"Eight customers cycle through a bounded queue without overselling")
	deadline = Time.get_ticks_msec()+45000
	while loop.departed < 8 and Time.get_ticks_msec() < deadline:
		await create_timer(0.25).timeout
	check(loop.departed == 8 and loop.inventory.reservations.is_empty(),"Stress run leaves no stranded customers or reservations")
	await finish()
