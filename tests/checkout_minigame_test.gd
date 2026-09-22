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

	world.queue_free()
	await create_timer(0.3).timeout
	print("CHECKOUT MINIGAME TESTS: %d failure(s)" % failures)
	quit(failures)
