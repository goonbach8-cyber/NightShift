extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var loop = world.gameplay
	loop.inventory.initialize_shelves()
	loop.order_patterns.assign([{&"water":1,&"chips":1}])
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.state = &"queued"
	customer.walking = false
	customer.global_position = world.layout.queue_points[0].global_position
	loop.queue.append(customer)
	var owner_id: int = customer.get_instance_id()
	loop.inventory.reserve(owner_id,&"water",1)
	loop.inventory.reserve(owner_id,&"chips",1)
	check(loop.checkout_details().subtotal == 0 and loop.checkout_details().remaining == 2,"Unscanned basket starts with zero subtotal")
	check(loop.checkout() and loop.scanned_units == 1 and loop.revenue_rappen == 0,"First input scans without sale")
	check(loop.checkout_details().subtotal == 220 and loop.checkout_details().remaining == 1,"Subtotal includes only scanned product")
	check(loop.checkout_text().contains(loop.inventory.products[&"water"].display_name) and loop.checkout_text().contains("1 / 2"),"Checkout names scanned product and item progress")
	check(loop.checkout() and loop.scanned_units == 2 and loop.stock.shelf_units == 2,"Second article scans without decrementing shelf")
	check(loop.checkout_details().subtotal == 510 and loop.checkout_text().contains("Accept payment"),"Complete basket exposes exact total and payment action")
	loop.event_history[&"prototype"] = true
	loop.talk()
	check(loop.dialogue.active and loop.dialogue.choices.size() == 2,"Checkout selects authored dialogue from separate content catalog")
	check(not loop.checkout() and loop.revenue_rappen == 0,"Dialogue prevents accidental payment")
	loop.dialogue.advance()
	loop.dialogue.choose(1)
	loop.dialogue.advance()
	check(loop.story_flags.get(&"denied_call",false),"Alternative reply persists its own decision")
	check(loop.checkout() and loop.revenue_rappen == 510 and loop.sold_units == 2,"Payment atomically sells scanned basket")
	check(not loop.checkout() and loop.revenue_rappen == 510,"Repeated payment cannot double-charge")
	check(loop.checkout_details().is_empty(),"Paid basket leaves no stale checkout presentation")
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	customer = loop.customers[-1]
	customer.state = &"queued"
	customer.walking = false
	customer.global_position = world.layout.queue_points[0].global_position
	loop.queue.append(customer)
	loop.inventory.reserve(customer.get_instance_id(),&"water",1)
	loop.checkout()
	customer.queue_free()
	await create_timer(0.2).timeout
	check(loop.scanned_owner == 0 and loop.scanned_units == 0 and loop.stock.reserved_units == 0,"Customer removal clears partial scan and reservation")
	world.queue_free()
	await create_timer(0.3).timeout
	print("CHECKOUT TESTS: %d failure(s)" % failures)
	quit(failures)
