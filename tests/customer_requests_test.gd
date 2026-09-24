extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var requests = world.customer_requests
	var player = world.player
	var actor = customer()
	loop.served = 3
	for night in [2,3,4,5]:
		loop.career_shifts = night-1
		requests.completed = false
		check(requests.handle_checkout_use(),"Customer starts request in Night %d" % night)
		check(actor.state == &"customer_request","Request holds customer at checkout")
		match requests.request_kind:
			&"wc_key":
				check(world.layout.customer_service_key.available,"Staff-area key becomes available")
				world._on_used(&"customer_service_key")
				check(is_instance_valid(requests.carried_prop),"Restroom key is physically carried")
			&"price_check":
				check(is_instance_valid(requests.task_point),"Price check has a shelf interaction")
				player.global_position = world.layout.product_points[requests.target_product].global_position+Vector3.UP*0.05
				await physics_frame
				player._update_interaction()
				if player.interaction_target != requests.task_point:
					print("PRICE_CHECK_DIAG product=",requests.target_product," player=",player.global_position," marker=",world.layout.product_points[requests.target_product].global_position," point=",requests.task_point.global_position," target=",player.interaction_target.action_id if is_instance_valid(player.interaction_target) else "none")
				check(player.interaction_target == requests.task_point,"Price tag is reachable from the correct shelf approach")
				if player.interaction_target == requests.task_point:
					player.interaction_target.interact(player)
				check(requests.task_complete,"Actual shelf price is read")
			&"fuel_receipt":
				player.global_position = world.layout.pump_terminal.get_node("Approach").global_position+Vector3.UP*0.05
				await physics_frame
				player._update_interaction()
				check(player.interaction_target == world.layout.pump_terminal,"Fuel-receipt request owns the terminal focus beside the register")
				if player.interaction_target == world.layout.pump_terminal:
					player.interaction_target.interact(player)
				check(requests.task_complete and is_instance_valid(requests.carried_prop) and not world.pump_service.active,"Receipt terminal serves request without opening pump service")
		player.global_position = world.layout.operator_point.global_position+Vector3.UP*0.05
		await physics_frame
		player._update_interaction()
		check(player.interaction_target == world.layout.checkout,"Customer request can be returned from the real checkout point")
		if player.interaction_target == world.layout.checkout:
			player.interaction_target.interact(player)
		check(requests.completed and not requests.active and actor.state == &"queued","Request return unblocks checkout")
	check(loop.checkout() and loop.checkout() and actor.paid,"Requested services preserve customer's basket")
	await finish()
