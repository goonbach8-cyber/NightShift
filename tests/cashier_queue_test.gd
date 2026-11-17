extends "res://tests/service_runtime_base.gd"
func press(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func enqueue(index: int) -> void:
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	var actor = loop.customers[-1]
	actor.state = &"queued"
	actor.remaining_products.clear()
	actor.has_product = true
	actor.attention_target = world.layout.checkout
	var point: Marker3D = world.layout.queue_points[index]
	actor.global_position = point.global_position+Vector3(-0.7 if loop.served > 0 else 0.0,0.05,0)
	loop.queue.append(actor)
	check(loop.inventory.reserve(actor.get_instance_id(),&"water",1),"Queued customer reserves a real basket")
	actor.go_to(point)

func run() -> void:
	await setup()
	await physics_frame
	loop.navigation.rebuild(world,world.layout.doors)
	loop.inventory.stocks[&"water"].shelf_units = 8
	loop.inventory.stocks[&"water"].changed.emit()
	world.player.global_position = world.layout.operator_point.global_position
	for i in 4: enqueue(i)
	var game = world.checkout_minigame
	check(game.begin(),"Cashier starts once for a physical moving queue")
	var deadline := Time.get_ticks_msec()+60000
	for i in 5:
		while game.phase != &"scan" and Time.get_ticks_msec() < deadline: await process_frame
		if game.phase != &"scan":
			check(false,"Queue reached the cashier before timeout")
			break
		var actor = game.customer
		check(not actor.walking and actor.global_position.distance_to(world.layout.queue_points[0].global_position) <= 0.6,"Basket is presented only after physically reaching the register")
		await press(KEY_E)
		while game.busy and Time.get_ticks_msec() < deadline: await process_frame
		if game.phase == &"cash":
			for code in [KEY_1,KEY_3,KEY_4,KEY_5]: await press(code)
			await press(KEY_ENTER)
		else:
			await press(KEY_E)
		while not actor.paid and Time.get_ticks_msec() < deadline: await process_frame
		check(actor.paid and game.active,"Sale completes without leaving the workstation")
		if i == 0: enqueue(3)
		while game.phase == &"receipt" and Time.get_ticks_msec() < deadline: await process_frame
	check(loop.served == 5 and loop.revenue_rappen == 1100 and loop.inventory.stocks[&"water"].shelf_units == 3,"Five physically queued customers preserve exact money and stock")
	check(game.active and not world.has_interaction_focus(game),"Cashier focus remains the only modal owner")
	game.cancel()
	await finish()
