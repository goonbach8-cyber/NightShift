extends "res://tests/campaign_test.gd"

func until(predicate: Callable, seconds: float, description: String) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline: await create_timer(0.1).timeout
	var result: bool = predicate.call()
	check(result,description)
	return result

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.career_shifts = 2
	loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(3))
	# One real shopper isolates the all-unserved edge case; authored events/tasks stay intact.
	loop.customer_count = 1
	loop.order_patterns.assign([{&"water":1}])
	await create_timer(0.4).timeout
	world._on_used(&"start")
	while loop.preparing: await process_frame
	check(loop.active,"Night 3 starts with its real tasks and events")
	await walk(layout.operator_point.global_position)
	if not await await_customer():
		await finish()
		return
	if not await until(func(): return loop.story_flags.get(&"presented_night_3_main",false),45,"Night 3 main event is actually presented"):
		await finish()
		return
	var customer = loop.queue[0]
	customer.patience = customer.wait_seconds+0.15
	await until(func(): return loop.lost_sales == 1,3,"Patience expiry records exactly one unserved customer")
	check(loop.queue.is_empty() and loop.inventory.reservations.is_empty(),"Unserved customer releases queue and reserved goods")
	check(world.objective.text.contains("Customers 1/1 (1 unserved)"),"HUD counts departure as resolved, not an outstanding customer")
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	await until(func(): return loop.departed == 1,40,"Unserved customer physically exits and increments departed")
	check(loop.customers.is_empty() and loop.lost_sales == 1,"Exit removes NPC without counting its loss twice")
	var prop = layout.warehouse.get_node("Supply/LooseCarton")
	if not await until(func(): return prop.changed_state and loop.story_flags.get(&"presented_night_3_store_parcel",false),50,"Required physical change is presented before completion"):
		await finish()
		return
	await create_timer(1).timeout
	check(absf(prop.rotation.z)>0.9,"Physical change remains visibly tipped")
	check(not world.objective.text.contains("Check the stockroom before leaving") and world.objective.text.contains("Check WC"),"Objective removes completed story destination and retains normal task")
	check(not loop.can_finish(),"Remaining normal tasks still prevent premature completion")
	await use()
	await walk(layout.product_points[&"water"].global_position)
	await use()
	await walk(layout.product_points[&"energy"].global_position)
	await use()
	await walk(layout.delivery.global_position+Vector3(-1,0,0))
	await use()
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	await use()
	await walk(layout.wc_point.get_node("Approach").global_position)
	await use()
	check(loop.can_finish(),"All-unserved Night 3 becomes finishable after actual tasks and story")
	await walk(world.get_node("Station/ShiftBoard").global_position+Vector3(0,0,1))
	await use()
	check(world.phase == world.Phase.COMPLETE,"Staff notes complete Night 3 despite unserved customer")
	await finish()
