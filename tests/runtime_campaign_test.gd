extends "res://tests/campaign_test.gd"
## The campaign safety net with the real focused checkout/delivery services.
## All input is injected inside Godot; no OS input or desktop window is used.

func use() -> void:
	if is_instance_valid(player.interaction_target) and player.interaction_target.action_id == &"delivery" and loop.delivery_ready:
		check(world.delivery_check.begin(),"Campaign opens receiving clipboard")
		var delivery = world.delivery_check
		for i in delivery.order.size():
			var id: StringName = delivery.order[delivery.selected]
			await key(KEY_E if delivery.actual_manifest[id] == loop.delivery_manifest[id] else KEY_R)
			await key(KEY_RIGHT)
		await key(KEY_ENTER)
		return
	await super.use()

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
			request.handle_checkout_use()
			check(request.completed and not request.active,"Customer request returns its physical item and releases checkout")
		elif world.customer_assistance.handle_checkout_use():
			var assistance = world.customer_assistance
			await walk(assistance.item_node.global_position)
			await use()
			await walk(layout.operator_point.global_position)
			assistance.handle_checkout_use()
		else:
			break
	var previous: int = loop.served
	var game = world.checkout_minigame
	var opened: bool = game.begin()
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
	await service_pending()
	await walk(layout.operator_point.global_position)
	player._update_interaction()
	check(not player.controls_locked and player.interaction_target == layout.checkout,"Checkout remains selectable before closing the shift")

func service_pending() -> void:
	if world.phone_system.ringing:
		print("PHONE_DIAG before caller=",world.phone_system.incoming_caller," kind=",world.phone_system.incoming_kind," mode=",world.phone_system.mode)
		await walk(layout.phone_point.get_node("Approach").global_position)
		check(player.interaction_target == layout.phone_point,"Ringing phone owns its physical interaction point")
		if player.interaction_target != layout.phone_point:
			return
		await use()
		await key(KEY_E)
		for i in 6:
			if not world.phone_system.active: break
			await key(KEY_1 if not world.phone_system.call_choices.is_empty() else KEY_E)
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
