extends "res://tests/vertical_slice_test.gd"

func sell() -> void:
	var previous: int = loop.served
	var units := 0
	for quantity in loop.queue[0].order.values(): units += int(quantity)
	for i in units:
		await use()
		check(loop.served == previous,"Scanning does not charge before payment")
	await use()
	check(loop.served == previous+1,"Payment completes exactly one basket")

func choose(id: StringName) -> void:
	for i in loop.inventory.products.size():
		if loop.selected_product() == id:
			return
		var event := InputEventKey.new()
		event.physical_keycode = KEY_TAB
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = InputEventKey.new()
		event.physical_keycode = KEY_TAB
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	if "--shift-layout" in OS.get_cmdline_user_args():
		world.position = Vector3(20,0,-15)
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	loop = world.gameplay
	layout = world.layout
	player.global_position = world.get_node("Station/ShiftBoard").global_position+Vector3(0,0.05,1)
	await create_timer(0.5).timeout
	await use()
	while loop.preparing: await process_frame
	check(loop.active and loop.inventory.products.size() == 3,"Multi-product shift starts")
	await walk(layout.operator_point.global_position)
	for i in 2:
		if not await await_customer():
			await finish()
			return
		await sell()
	check(loop.served == 2 and loop.revenue_rappen == 570,"First customers buy different products")
	await capture("multi-first-sales")
	for id in loop.inventory.products:
		await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
		await choose(id)
		await use()
		check(loop.inventory.carried_product() == id,"Selected load picked up: "+String(id))
		await walk(layout.product_points[id].global_position)
		await use()
		check(loop.inventory.carried_product() == &"" and loop.inventory.stocks[id].shelf_units > 0,"Matching shelf replenished: "+String(id))
	await walk(layout.delivery.global_position+Vector3(-1,0,0))
	await use()
	check(loop.delivery_carried,"Mixed delivery picked up during customer operation")
	var before: Dictionary = {}
	for id in loop.inventory.stocks: before[id] = loop.inventory.stocks[id].warehouse_units
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	await use()
	for id in loop.delivery_manifest:
		check(loop.inventory.stocks[id].warehouse_units == before[id]+loop.delivery_manifest[id],"Delivery updates correct product: "+String(id))
	await walk(layout.operator_point.global_position)
	await capture("multi-queue")
	for i in 4:
		if not await await_customer():
			await finish()
			return
		await sell()
	check(loop.served == 6 and loop.lost_sales == 0,"Six varied customers served")
	check(loop.revenue_rappen == 3020 and loop.sold_units == 11,"All baskets total CHF 30.20 and eleven articles")
	check(loop.inventory.stocks.water.sold_units == 5 and loop.inventory.stocks.energy.sold_units == 3 and loop.inventory.stocks.chips.sold_units == 3,"Per-product sales match receipts")
	check(loop.completed_orders.any(func(receipt): return receipt.items.size() == 3),"Customer completes three-shelf basket")
	var deadline := Time.get_ticks_msec()+45000
	while loop.departed < 6 and Time.get_ticks_msec() < deadline:
		await create_timer(0.25).timeout
	check(loop.departed == 6 and loop.inventory.reservations.is_empty(),"All customers exit and no reservations leak")
	await use()
	check(world.phase == world.Phase.COMPLETE,"Multi-product shift completes")
	await capture("multi-complete")
	var event := InputEventAction.new()
	event.action = &"restart_shift"
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(1).timeout
	world = current_scene
	check(world.gameplay.sold_units == 0 and world.gameplay.inventory.reservations.is_empty(),"Restart resets basket and sales state")
	await finish()
