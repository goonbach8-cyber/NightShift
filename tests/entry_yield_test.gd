extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	player.global_position = layout.operator_point.global_position
	await physics_frame
	loop.navigation.rebuild(world,layout.doors)
	loop.inventory.initialize_shelves()
	loop.customer_count = 2
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	var departing = loop.customers[0]
	departing.state = &"leaving"
	departing.paid = true
	departing.global_position = layout.entrance.global_position+Vector3(0.55,0,-0.53)
	departing.go_to(layout.spawn_point)
	loop.spawn_customer()
	var arriving = loop.customers[1]
	arriving.global_position = layout.entrance.global_position+Vector3(0.08,0,-0.30)
	loop.active = true
	check(arriving.should_yield_at_entry(),"Reproduced opposing doorway contact requests entry yield")
	check(not departing.should_yield_at_entry(),"Departing customer keeps right of way")
	var deadline := Time.get_ticks_msec()+25000
	while is_instance_valid(departing) and Time.get_ticks_msec()<deadline: await process_frame
	check(not is_instance_valid(departing),"Departing customer physically clears the shared entrance")
	while arriving.state != &"queued" and Time.get_ticks_msec()<deadline: await process_frame
	check(arriving.state == &"queued","Arriving customer resumes shopping and reaches checkout")
	check(not arriving.yielding_at_entry and loop.stock.reserved_units == 1,"Yield leaves no stuck state or duplicated stock")
	loop.active = false
	await finish()
