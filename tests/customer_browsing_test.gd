extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.set_process(false)
	loop.customer_count = 1
	loop.inventory.initialize_shelves()
	loop.order_patterns.assign([{&"water":1,&"chips":1}])
	loop.spawn_customer()
	loop.active = true
	var customer = loop.customers[0]
	customer.set_physics_process(false)
	customer.global_position = layout.product_points[&"water"].global_position
	loop._process(0.01)
	check(customer.state == &"browsing" and not customer.walking,"Customer stops at the actual product location")
	check(loop.stock.reserved_units == 0,"Passing into shelf radius does not instantly take stock")
	loop._process(0.25)
	check(customer.state == &"browsing" and loop.stock.reserved_units == 0,"Short choosing interval remains visible")
	loop._process(customer.browse_seconds)
	check(loop.stock.reserved_units == 1 and customer.current_product == &"chips","One selection reserves once and continues to next product")
	check(customer.state == &"shopping" and customer.target == layout.product_points[&"chips"],"Multi-product shopper routes to the next real shelf")
	customer.global_position = layout.product_points[&"chips"].global_position
	loop._process(0.01)
	loop._process(customer.browse_seconds)
	check(customer.state == &"queued" and loop.queue.size() == 1,"Finished basket joins queue exactly once")
	loop._process(0.8)
	check(loop.inventory.stocks[&"chips"].reserved_units == 1 and loop.queue.size() == 1,"Choosing cannot repeat reservation or queue entry")
	loop.abandon_customer(customer)
	check(loop.inventory.reservations.is_empty(),"Interrupted shopping releases the complete basket")
	loop.active = false
	await finish()
