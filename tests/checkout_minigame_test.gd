extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value:
		failures += 1

func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var loop = world.gameplay
	var layout = world.layout
	var player = world.player
	var game = world.checkout_minigame

	loop.inventory.initialize_shelves()
	loop.order_patterns.assign([{&"water":1,&"energy":1,&"chips":1}])
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.set_physics_process(false)
	customer.walking = false
	customer.state = &"queued"
	customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(customer)
	for id in customer.order:
		loop.inventory.reserve(customer.get_instance_id(),id,customer.order[id])
	world.phase = world.Phase.ACTIVE
	player.global_position = layout.operator_point.global_position
	await process_frame

	check(game.begin(),"Physical checkout starts for a ready staffed basket")
	check(game.active and game.phase == &"scan" and player.controls_locked,"Checkout focus locks movement without pausing the world")
	check(game.current_id == &"water","First staged item matches basket order")
	check(not game._barcode_aligned(),"Water starts with its barcode turned away from the scanner")
	game.item_rotation = -PI
	game.slide = -0.02
	game._apply_item_transform()
	check(game._barcode_aligned(),"Rotating the bottle exposes its barcode")
	game._scan_current()
	await create_timer(0.28).timeout
	check(loop.scanned_units == 1 and game.current_id == &"energy","Successful physical scan advances exactly one basket item")

	game.item_rotation = -PI/2.0
	game.slide = -0.02
	game._apply_item_transform()
	check(game._barcode_aligned(),"Energy can uses a different barcode side")
	game._scan_current()
	await create_timer(0.28).timeout
	check(loop.scanned_units == 2 and game.current_id == &"chips","Second scan advances without charging the customer")

	game.item_rotation = 0.0
	game.slide = -0.02
	game._apply_item_transform()
	check(game._barcode_aligned(),"Chip bag barcode is readable in its natural starting orientation")
	game._scan_current()
	await create_timer(0.28).timeout
	check(game.phase == &"payment" and loop.scanned_units == 3 and loop.revenue_rappen == 0,"All scans lead to card payment without selling early")
	check(game.terminal_label.visible and game.terminal_label.text.contains("CHF 8.60"),"Physical terminal shows the exact final amount")

	game._confirm_payment()
	await create_timer(1.15).timeout
	check(loop.revenue_rappen == 860 and loop.served == 1,"Card confirmation commits the existing atomic sale once")
	check(not game.active and not player.controls_locked,"Receipt completes and returns control to normal play")
	check(loop.checkout_details().is_empty(),"Completed physical checkout leaves no stale basket state")

	# Every third completed transaction uses cash so the grounded change interaction
	# receives deterministic regression coverage without random test behavior.
	loop.served = 2
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	var cash_customer = loop.customers[-1]
	cash_customer.set_physics_process(false)
	cash_customer.walking = false
	cash_customer.state = &"queued"
	cash_customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(cash_customer)
	loop.inventory.reserve(cash_customer.get_instance_id(),&"water",1)
	await process_frame
	check(game.begin(),"Third transaction can start the same physical checkout")
	game.item_rotation = -PI
	game.slide = -0.02
	game._apply_item_transform()
	game._scan_current()
	await create_timer(0.28).timeout
	check(game.phase == &"cash" and game.cash_given == 500 and game.cash_due == 220,"Third transaction asks for grounded cash change")
	game._add_cash(200)
	game._add_cash(50)
	game._add_cash(20)
	game._add_cash(10)
	check(game.cash_added == 280,"Cash tray builds the exact CHF 2.80 change")
	game._confirm_cash()
	await create_timer(1.15).timeout
	check(loop.revenue_rappen == 1080 and loop.served == 3,"Exact cash change commits the same atomic sale path")
	check(not game.active and not player.controls_locked,"Cash receipt returns to normal play")

	# From Night 2 onward, a rare deterministic card decline adds a believable interruption.
	loop.career_shifts = 1
	loop.served = 4
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	var decline_customer = loop.customers[-1]
	decline_customer.set_physics_process(false)
	decline_customer.walking = false
	decline_customer.state = &"queued"
	decline_customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(decline_customer)
	loop.inventory.reserve(decline_customer.get_instance_id(),&"water",1)
	await process_frame
	check(game.begin(),"Later-night card transaction starts normally")
	game.item_rotation = -PI
	game.slide = -0.02
	game._apply_item_transform()
	game._scan_current()
	await create_timer(0.28).timeout
	check(game.phase == &"card","Fifth transaction still uses the normal card terminal")
	game._confirm_payment()
	check(game.phase == &"card_retry" and loop.revenue_rappen == 1080,"First declined card attempt does not charge the basket")
	var retry := InputEventKey.new()
	retry.physical_keycode = KEY_E
	retry.pressed = true
	game._input(retry)
	await create_timer(1.15).timeout
	check(loop.revenue_rappen == 1300 and loop.served == 5,"Second card succeeds through the normal atomic sale path")
	check(not game.active,"Declined-card recovery still ends with a normal receipt")

	world.queue_free()
	await create_timer(0.3).timeout
	print("CHECKOUT MINIGAME TESTS: %d failure(s)" % failures)
	quit(failures)
