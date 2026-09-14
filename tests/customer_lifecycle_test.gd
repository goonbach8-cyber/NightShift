extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var loop = world.gameplay
	loop.customer_count = 0
	world._on_used(&"start")
	while loop.preparing: await process_frame
	loop.order_patterns.assign([{&"water":1,&"chips":1}])
	loop.spawn_customer()
	var customer = loop.customers[0]
	var owner_id: int = customer.get_instance_id()
	check(loop.inventory.reserve(owner_id,&"water",1) and loop.inventory.reserve(owner_id,&"chips",1),"Customer owns multiple reservations")
	customer.queue_free()
	await create_timer(0.2).timeout
	check(loop.inventory.reservations.is_empty() and loop.stock.reserved_units == 0 and loop.inventory.stocks.chips.reserved_units == 0,"Unexpected NPC removal releases every product")
	check(loop.customers.is_empty() and loop.queue.is_empty() and loop.lost_sales == 1 and loop.departed == 1,"Unexpected removal clears lifecycle and queue")
	loop.order_patterns.assign([{&"energy":1}])
	loop.spawn_customer()
	customer = loop.customers[0]
	customer.global_position = world.layout.shelf_point.global_position
	customer.walking = false
	customer.state = &"stock_wait"
	customer.patience = 0.1
	loop.inventory.stocks.energy.shelf_units = 0
	loop.inventory.stocks.energy.warehouse_units = 0
	await create_timer(0.3).timeout
	check(customer.abandoned and customer.state == &"leaving" and loop.lost_sales == 2,"Empty shop and warehouse eventually let customer leave")
	loop.abandon_customer(customer)
	check(loop.lost_sales == 2,"Repeated abandonment cannot count loss twice")
	var deadline := Time.get_ticks_msec()+30000
	while loop.departed < 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.25).timeout
	check(loop.departed == 2 and loop.customers.is_empty(),"Abandoned customer reaches exit")
	world.queue_free()
	await create_timer(0.3).timeout
	print("CUSTOMER LIFECYCLE TESTS: %d failure(s)" % failures)
	quit(failures)
