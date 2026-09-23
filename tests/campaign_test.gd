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
	if "--shift-layout" in OS.get_cmdline_user_args(): world.position = Vector3(20,0,-15)
	player = world.get_node("Player")
	loop = world.gameplay
	layout = world.layout

func run() -> void:
	var checkpoint_path := "user://nightshift_campaign_test_%d.json" % Time.get_ticks_usec()
	var nights := 6 if "--six-nights" in OS.get_cmdline_user_args() else (3 if "--three-nights" in OS.get_cmdline_user_args() else 2)
	if nights == 6:
		set_meta("nightshift_checkpoint_path",checkpoint_path)
		var main_menu = load("res://scenes/main/menu.tscn").instantiate()
		root.add_child(main_menu)
		current_scene = main_menu
		main_menu.request_new()
		await create_timer(0.5).timeout
	else:
		world = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(world)
		current_scene = world
	bind_world()
	set_meta("nightshift_menu_session",true)
	world.checkpoint.path = checkpoint_path
	for night in nights:
		await create_timer(0.4).timeout
		loop.navigation.rebuild(world,layout.doors)
		await walk(world.get_node("Station/ShiftBoard").global_position+Vector3(0,0,1))
		await use()
		if loop.dialogue.active:
			while loop.dialogue.active: await key(KEY_SPACE)
			await use()
		while loop.preparing: await process_frame
		check(loop.active and loop.career_shifts == night,"Configured night begins: %d" % (night+1))
		if not loop.definition.handover.is_empty():
			check(loop.story_flags.get(StringName("josh_handover_%d" % (night+1)),false),"Josh handover completed before customer operation")
		if night == 3:
			await walk(world.story_world.get_node("route").global_position)
			await use()
			while world.story_world.trip_busy: await process_frame
			check(world.story_world.in_depot,"Night 4 navigation reaches depot")
			await walk(world.story_world.depot.get_node("depot_clerk").global_position)
			await use()
			while loop.dialogue.active: await key(KEY_SPACE)
			await walk(world.story_world.depot.get_node("return").global_position)
			await use()
			while world.story_world.trip_busy: await process_frame
			check(loop.tasks.has(&"depot") and not world.story_world.in_depot,"Depot collection and return complete")
		await walk(layout.radio_point.get_node("Approach").global_position)
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
			if id == &"energy":
				await use()
				check(loop.tasks.has(&"cooler"),"Refrigeration is explicitly checked after restocking")
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
		if loop.required_tasks.has(&"wc"):
			await walk(layout.wc_point.get_node("Approach").global_position)
			await use()
			check(loop.tasks.has(&"wc") and not layout.wc_mark.visible,"WC service has a reachable location and clears visible dirt")
		await walk(layout.operator_point.global_position)
		if not await await_customer():
			await finish()
			return
		await create_timer(0.25).timeout
		check(loop.story_flags.get(&"noticed_call",false),"Main story presented at staffed checkout")
		await capture("night%d-story-hint" % (night+1))
		await key(KEY_F)
		check(loop.dialogue.active,"Customer dialogue opens during trading")
		for i in 5:
			if not loop.dialogue.active: break
			if loop.dialogue.index == loop.dialogue.lines.size()-1 and not loop.dialogue.choices.is_empty():
				await key(KEY_1)
			else: await key(KEY_SPACE)
		check(not loop.dialogue.active,"Player can answer and finish dialogue")
		if night == 2:
			await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
			var event_deadline := Time.get_ticks_msec()+40000
			var prop = layout.warehouse.get_node("Supply/LooseCarton")
			while not prop.changed_state and Time.get_ticks_msec() < event_deadline: await process_frame
			check(prop.changed_state,"Night 3 stockroom return produces persistent physical change")
			await walk(layout.operator_point.global_position)
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
		check(loop.revenue_rappen == [3020,3590,3240,3020,3020,3020][night] and loop.sold_units == [11,13,12,11,11,11][night],"Night basket statistics match exact expected totals")
		check(loop.customers.is_empty() and loop.inventory.reservations.is_empty(),"Night ends without customer or reservation leaks")
		check(loop.event_history.has(StringName("night_%d_main" % (night+1))),"Guaranteed main event happened during shift")
		check(loop.story_flags.get(StringName("presented_night_%d_main" % (night+1)),false),"Main event was presented, not merely queued")
		if has_method("prepare_shift_end"):
			await call("prepare_shift_end")
		if not has_method("prepare_shift_end") or player.interaction_target == layout.checkout:
			await use()
		check(world.phase == world.Phase.ACTIVE,"Checkout does not end the night")
		await walk(world.get_node("Station/ShiftBoard").global_position+Vector3(0,0,1))
		await use()
		check(world.phase == world.Phase.COMPLETE,"Night can finish")
		await capture("night%d-complete" % (night+1))
		await key(KEY_N)
		await create_timer(0.8).timeout
		if night == 5:
			check(world.menu.page == "ending" and loop.story_flags.get(&"ending_seen",false),"Six-night campaign reaches saved ending instead of Night 7")
			var saved: Dictionary = world.checkpoint.read_data(checkpoint_path)
			check(saved.shifts == 6 and saved.revenue == 18910,"Six-night saved totals are exact: CHF 189.10")
			for number in range(1,7):
				check(saved.events.has("night_%d_main" % number),"Saved main-event history includes Night %d" % number)
			world.menu.close()
			break
		bind_world()
		check(world.phase == world.Phase.NOT_STARTED and loop.career_shifts == night+1,"Next night transition loads checkpoint")
	if nights < 6: check(loop.career_revenue == (9850 if nights == 3 else 6610) and loop.career_shifts == nights,"Completed nights persist exact campaign revenue")
	check(loop.story_flags.get(&"asked_about_call",false) and loop.event_history.has(&"night_1_main") and loop.event_history.has(&"night_2_main"),"Decisions and main-event history survive both transitions")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(checkpoint_path+suffix): DirAccess.remove_absolute(checkpoint_path+suffix)
	await finish()
