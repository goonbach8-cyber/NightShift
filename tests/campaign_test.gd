extends "res://tests/multi_product_test.gd"

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await create_timer(0.1).timeout

func bind_world() -> void:
	world = current_scene
	player = world.get_node("Player")
	loop = world.gameplay
	layout = world.layout

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	if "--shift-layout" in OS.get_cmdline_user_args(): world.position = Vector3(20,0,-15)
	root.add_child(world)
	current_scene = world
	bind_world()
	var checkpoint_path := "user://nightshift_campaign_test_%d.json" % Time.get_ticks_usec()
	world.checkpoint.path = checkpoint_path
	for night in 2:
		await create_timer(0.4).timeout
		loop.navigation.rebuild(world,layout.doors)
		await walk(world.get_node("Station/ShiftBoard").global_position+Vector3(0,0,1))
		await use()
		while loop.preparing: await process_frame
		check(loop.active and loop.career_shifts == night,"Configured night begins: %d" % (night+1))
		await key(KEY_T)
		check(world.radio.enabled,"Radio toggles through real key input")
		await walk(layout.operator_point.global_position)
		for i in 2:
			if not await await_customer():
				await finish()
				return
			await sell()
		for id in loop.inventory.products:
			await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
			await choose(id)
			await use()
			check(loop.inventory.carried_product() == id,"Night %d warehouse pickup: %s" % [night+1,id])
			await walk(layout.product_points[id].global_position)
			await use()
			check(loop.inventory.carried_product() == &"","Load deposited at matching shelf")
		await walk(layout.delivery.global_position+Vector3(-1,0,0))
		await use()
		check(loop.delivery_carried,"Delivery arrives during customer operation")
		await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
		await use()
		check(loop.tasks.has(&"delivery"),"Mixed delivery stored")
		if loop.required_tasks.has(&"service"):
			await walk(world.get_node("Station/ServicePoint/Approach").global_position)
			await use()
			check(loop.tasks.has(&"service"),"Night two service task reachable and functional")
		await walk(layout.operator_point.global_position)
		if not await await_customer():
			await finish()
			return
		await key(KEY_F)
		check(loop.dialogue.active,"Customer dialogue opens during trading")
		for i in 5:
			if not loop.dialogue.active: break
			if loop.dialogue.index == loop.dialogue.lines.size()-1 and not loop.dialogue.choices.is_empty():
				await key(KEY_1)
			else: await key(KEY_SPACE)
		check(not loop.dialogue.active,"Player can answer and finish dialogue")
		await capture("night%d-dialogue-and-queue" % (night+1))
		for i in loop.customer_count-2:
			if not await await_customer():
				await finish()
				return
			await sell()
		var deadline := Time.get_ticks_msec()+50000
		while loop.departed < loop.customer_count and Time.get_ticks_msec() < deadline:
			await create_timer(0.25).timeout
		check(loop.served == loop.customer_count and loop.lost_sales == 0,"All customers served in night %d" % (night+1))
		check(loop.revenue_rappen == [3020,3590][night] and loop.sold_units == [11,13][night],"Night basket statistics match exact expected totals")
		check(loop.event_history.has(StringName("night_%d_main" % (night+1))),"Guaranteed main event happened during shift")
		await use()
		check(world.phase == world.Phase.COMPLETE,"Night can finish")
		await capture("night%d-complete" % (night+1))
		await key(KEY_N)
		await create_timer(0.8).timeout
		bind_world()
		check(world.phase == world.Phase.NOT_STARTED and loop.career_shifts == night+1,"Next night transition loads checkpoint")
	check(loop.career_revenue == 6610 and loop.career_shifts == 2,"Two completed nights persist CHF 66.10")
	check(loop.story_flags.get(&"asked_about_call",false) and loop.event_history.has(&"night_1_main") and loop.event_history.has(&"night_2_main"),"Decisions and main-event history survive both transitions")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(checkpoint_path+suffix): DirAccess.remove_absolute(checkpoint_path+suffix)
	await finish()
