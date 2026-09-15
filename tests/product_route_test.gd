extends "res://tests/campaign_test.gd"
var observed: Dictionary = {}

func observe_reservations() -> void:
	for owner_id in loop.inventory.reservations:
		var customer: Node3D = instance_from_id(owner_id)
		for id in loop.inventory.reservations[owner_id]:
			if observed.has(id): continue
			observed[id] = true
			check(customer.global_position.distance_to(layout.product_points[id].global_position)<0.81,"Customer physically selects product at %s" % id)

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.customer_count = 1
	loop.order_patterns.assign([{&"water":1,&"chips":1,&"energy":1}])
	loop.use_loaded_stock = true
	for stock in loop.inventory.stocks.values():
		stock.shelf_units = 3
		stock.changed.emit()
	loop.inventory.changed.connect(observe_reservations)
	world._on_used(&"start")
	while loop.preparing: await process_frame
	await walk(layout.operator_point.global_position)
	if await await_customer():
		check(observed.size() == 3,"One basket visits all three physical product areas")
		await sell()
		check(loop.revenue_rappen == 860,"Mixed physical route pays exact total")
		for id in loop.inventory.stocks:
			var slots: Array = world.get_node("Station").restock_items if id == &"water" else layout.displays[id].slots
			var visible := 0
			for slot in slots:
				if slot.visible: visible += 1
			check(visible == 2,"Payment removes visible %s item only from matching display" % id)
	loop.inventory.changed.disconnect(observe_reservations)
	await finish()
