extends "res://tests/vertical_slice_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
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
