extends "res://tests/multi_product_test.gd"

func sell() -> void:
	await service_pending()
	await walk(layout.operator_point.global_position)
	# Serve existing customer-help requests before opening the basket.
	for attempt in 3:
		if world.customer_requests.handle_checkout_use():
			var request = world.customer_requests
			match request.request_kind:
				&"wc_key":
					await walk(layout.customer_service_key.get_node("Approach").global_position)
					await use()
				&"price_check":
					await walk(layout.product_points[request.target_product].global_position)
					player._update_interaction()
					check(player.interaction_target == request.task_point,"Price-check tag is reachable from the matching shelf approach")
					if player.interaction_target != request.task_point:
						return
					await use()
				&"fuel_receipt":
					await walk(layout.pump_terminal.get_node("Approach").global_position)
					await use()
			await walk(layout.operator_point.global_position)
			await use()
			check(request.completed and not request.active,"Customer request returns its physical item and releases checkout")
		elif world.customer_assistance.handle_checkout_use():
			var assistance = world.customer_assistance
			await walk(assistance.item_node.global_position)
			await use()
			await walk(layout.operator_point.global_position)
			await use()
		else:
			break
	var previous: int = loop.served
	var game = world.checkout_minigame
	var register_focused := false
	for focus_attempt in 3:
		if focus_attempt > 0:
			# A new phone/service interruption can begin while walking back to the
			# counter; resolve it before expecting the register to own focus.
			await service_pending()
		await walk(layout.operator_point.global_position)
		player._update_interaction()
		if player.interaction_target == layout.checkout:
			register_focused = true
			break
	if not register_focused:
		print("CHECKOUT_FOCUS_DIAG target=",player.interaction_target.action_id if is_instance_valid(player.interaction_target) else "none"," pos=",player.global_position," locked=",player.controls_locked," dialogue=",loop.dialogue.active," phone=",world.phone_system.active," ringing=",world.phone_system.ringing," pump=",world.pump_service.active," cctv=",world.cctv_system.active," power=",world.power_service.active," delivery=",world.delivery_check.active," spill=",world.spill_service.active," radio=",world.radio_tuner.active," device=",world.device_service.active)
		for candidate in root.get_tree().get_nodes_in_group("interactable"):
			if candidate.is_available() and candidate.global_position.distance_to(player.global_position) < 1.8:
				print("CHECKOUT_FOCUS_CANDIDATE action=",candidate.action_id," distance=",candidate.global_position.distance_to(player.global_position)," bias=",candidate.interaction_bias())
	check(register_focused,"Campaign reaches the register from its physical operator position")
	if not register_focused:
		return
	# Headless Godot intentionally uses checkout_minigame.begin() because the
	# render-only item-scanning interaction is disabled in DisplayServer.headless.
	# The player must still physically reach and focus the register first.
	var opened: bool = game.active if game.active else game.begin()
	if not opened:
		print("CHECKOUT_DIAG queue=",loop.queue.size()," ready=",loop.checkout_ready()," partner=",loop.dialogue.active," player=",player.global_position," operator=",layout.operator_point.global_position," phone=",world.phone_system.active," ring=",world.phone_system.ringing," focus=",world.has_interaction_focus(game))
	check(opened,"Campaign opens physical checkout")
	if not opened:
		return
	var deadline := Time.get_ticks_msec()+25000
	while game.active and Time.get_ticks_msec() < deadline:
		if game.busy and game.phase not in [&"printer_jam",&"receipt"]:
			await process_frame
			continue
		match game.phase:
			&"scan":
				# Drive the same held-key movement used by the player.
				game.rotate_left = true
				while not game._barcode_aligned() and game.phase == &"scan" and Time.get_ticks_msec() < deadline:
					game._process(0.04)
				game.rotate_left = false
				game.move_right = true
				while not game.busy and game.phase == &"scan" and Time.get_ticks_msec() < deadline:
					game._process(0.04)
				game.move_right = false
			&"card", &"card_retry":
				await key(KEY_E)
			&"cash":
				var due: int = game.cash_given-game.cash_due-game.cash_added
				for value in [500,200,100,50,20,10,5]:
					while due >= value:
						game.cash_selection = game.CASH_VALUES.find(value)
						await key(KEY_E)
						due -= value
				await key(KEY_ENTER)
			&"printer_jam":
				while absf(game.printer_alignment) > 0.1:
					await key(KEY_LEFT if game.printer_alignment > 0 else KEY_RIGHT)
				await key(KEY_E)
		await process_frame
	check(not game.active and loop.served == previous+1,"Physical checkout completes exactly one basket and releases focus")

func prepare_shift_end() -> void:
	for attempt in 3:
		await service_pending()
		await walk(layout.operator_point.global_position)
		player._update_interaction()
		if not player.controls_locked and player.interaction_target == layout.checkout:
			break
	if player.controls_locked or player.interaction_target != layout.checkout:
		print("SHIFT_END_DIAG locked=",player.controls_locked," target=",player.interaction_target.action_id if is_instance_valid(player.interaction_target) else "none")
		for candidate in root.get_tree().get_nodes_in_group("interactable"):
			if candidate.is_available() and candidate.global_position.distance_to(player.global_position) < 2.2:
				print("SHIFT_END_CANDIDATE ",candidate.action_id," distance=",candidate.global_position.distance_to(player.global_position)," bias=",candidate.interaction_bias())
	check(not player.controls_locked and player.interaction_target == layout.checkout,"Checkout remains selectable before closing the shift")

func await_customer() -> bool:
	var ready := await super.await_customer()
	if not ready:
		print("QUEUE_TIMEOUT night=",loop.career_shifts+1," served=",loop.served," spawned=",loop.spawned," departed=",loop.departed," lost=",loop.lost_sales," queue=",loop.queue.size())
		for index in loop.queue.size():
			var customer: Node3D = loop.queue[index]
			var target_pos: Vector3 = customer.target.global_position if is_instance_valid(customer.target) else Vector3.INF
			var horizontal_distance := Vector2(customer.global_position.x-target_pos.x,customer.global_position.z-target_pos.z).length()
			print("QUEUE_HEAD ",index," state=",customer.state," pos=",customer.global_position," walking=",customer.walking," target=",customer.target.name if is_instance_valid(customer.target) else "none"," target_pos=",target_pos," hdist=",horizontal_distance," route=",customer.route.size()," retries=",customer.retry_time," stuck=",customer.stuck_time)
	return ready

func service_pending() -> void:
	if world.phone_system.ringing:
		await walk(layout.phone_point.get_node("Approach").global_position)
		check(player.interaction_target == layout.phone_point,"Ringing phone owns its physical interaction point")
		if player.interaction_target != layout.phone_point:
			return
		await use()
		await key(KEY_E)
		for i in 6:
			if not world.phone_system.active: break
			await key(KEY_1 if not world.phone_system.call_choices.is_empty() else KEY_E)
		if world.phone_system.active:
			print("PHONE_DIAG after active=",world.phone_system.active," mode=",world.phone_system.mode," ring=",world.phone_system.ringing," locked=",player.controls_locked)
		check(not world.phone_system.active,"Campaign phone conversation releases control")
		await create_timer(0.8).timeout
	if world.pump_service.request_pending:
		var pump = world.pump_service
		await walk(layout.pump_terminal.get_node("Approach").global_position)
		check(player.interaction_target == layout.pump_terminal,"Pending pump request owns its physical terminal")
		if player.interaction_target != layout.pump_terminal:
			return
		await use()
		check(pump.active,"Campaign opens pump authorization panel")
		if not pump.active:
			return
		pump.selected_pump = pump.request_pump
		pump.selected_limit_index = pump.PRESETS.find(pump.request_limit)
		await key(KEY_E)
		await create_timer(1.5).timeout
		if pump.fault_pending:
			var point = layout.pump_reset_points[pump.fault_pump]
			await walk(point.global_position)
			await use()
	if world.cctv_system.motion_pending:
		var cctv = world.cctv_system
		await walk(layout.cctv_terminal.get_node("Approach").global_position)
		check(player.interaction_target == layout.cctv_terminal,"CCTV alert owns its physical terminal")
		if player.interaction_target != layout.cctv_terminal:
			return
		await use()
		check(cctv.active,"Campaign opens physical CCTV terminal")
		if not cctv.active:
			return
		var channel_deadline := Time.get_ticks_msec()+3000
		while cctv.selected_channel != cctv.motion_channel and Time.get_ticks_msec() < channel_deadline:
			await key(KEY_RIGHT)
		check(cctv.selected_channel == cctv.motion_channel,"Campaign selects alerted CCTV feed")
		await create_timer(2.0).timeout
		await key(KEY_E)
		await key(KEY_ESCAPE)
	if world.power_service.fault_pending:
		await walk(layout.breaker_panel.get_node("Approach").global_position)
		await use()
		world.power_service.selected_circuit = world.power_service.fault_circuit
		await key(KEY_E)
		await create_timer(0.7).timeout
	if world.radio_tuner.drift_pending:
		await walk(layout.radio_point.get_node("Approach").global_position)
		await use()
		world.radio.set_frequency(world.radio_tuner.drift_target)
		await key(KEY_E)
	if world.spill_service.spill_pending or world.spill_service.return_required:
		var spill = world.spill_service
		if spill.spill_pending:
			await walk(layout.cleaning_station.get_node("Approach").global_position)
			await use()
			check(spill.kit_carried,"Player physically takes the cleaning kit")
			await walk(spill.spill_point.global_position)
			await use()
			check(spill.active,"Spill cleanup opens only with the carried kit")
			if not spill.active:
				return
			for i in spill.REQUIRED_PASSES:
				var event := InputEventKey.new()
				event.physical_keycode = KEY_D if i%2 == 0 else KEY_A
				event.pressed = true
				Input.parse_input_event(event)
				await create_timer(1.1).timeout
				event.pressed = false
				Input.parse_input_event(event)
			await create_timer(0.6).timeout
			check(spill.return_required and not spill.spill_pending,"Sweeps clean the visible spill")
		await walk(layout.cleaning_station.get_node("Approach").global_position)
		await use()
		check(spill.completed and not spill.kit_carried,"Cleaning kit is returned and task completes")
	if world.device_service.fault_pending or world.device_service.return_required:
		var device = world.device_service
		if device.fault_pending:
			await walk(layout.service_tool_station.get_node("Approach").global_position)
			await use()
			await walk(layout.product_points[&"energy"].global_position)
			await use()
			for i in 3:
				await key(KEY_E)
				await key(KEY_E)
				await key(KEY_RIGHT)
			await key(KEY_R)
			await create_timer(0.65).timeout
		await walk(layout.service_tool_station.get_node("Approach").global_position)
		await use()

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
