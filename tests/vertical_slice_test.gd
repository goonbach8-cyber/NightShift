extends SceneTree
var world: Node3D
var player: CharacterBody3D
var loop: Node
var layout: Node
var failures := 0
const OUT = "C:/Users/e558926/Documents/Codex/2026-09-10/du-arbeitest-direkt-an-meinem-lokalen/outputs/"
const ACTIONS = ["move_left","move_right","move_forward","move_backward"]

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+description)
	if not condition:
		failures += 1

func use() -> void:
	print("USE at ",player.global_position," target ",player.interaction_target.name if is_instance_valid(player.interaction_target) else "none")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	await create_timer(0.1).timeout

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"Slice-"+label+".png")

func walk(to: Vector3) -> bool:
	var route: PackedVector3Array = loop.navigation.path(player.global_position,to)
	if route.is_empty():
		check(false,"Player route exists to "+str(to))
		return false
	var deadline := Time.get_ticks_msec()+30000
	while not route.is_empty() and Time.get_ticks_msec() < deadline:
		for door in layout.doors:
			if player.global_position.distance_to(door.global_position) < 1.6 and not door.is_open and not door.moving:
				door.interact(player)
		var delta := route[0]-player.global_position
		delta.y = 0
		for action in ACTIONS:
			Input.action_release(action)
		if delta.length() < 0.17:
			route.remove_at(0)
		else:
			var direction := delta.normalized()
			Input.action_press("move_right" if direction.x > 0 else "move_left",absf(direction.x))
			Input.action_press("move_backward" if direction.z > 0 else "move_forward",absf(direction.z))
		await physics_frame
	for action in ACTIONS:
		Input.action_release(action)
	await create_timer(0.3).timeout
	var reached := Vector2(player.global_position.x-to.x,player.global_position.z-to.z).length() < 0.55
	check(reached,"Player walked to "+str(to))
	return reached

func await_customer() -> bool:
	var deadline := Time.get_ticks_msec()+70000
	while Time.get_ticks_msec() < deadline:
		if not loop.queue.is_empty() and not loop.queue[0].walking:
			return true
		await create_timer(0.25).timeout
	for customer in loop.customers:
		print("CUSTOMER DEBUG ",customer.state," pos ",customer.position," path ",customer.route," moving ",customer.walking)
	check(false,"Customer reached the checkout before timeout")
	return false

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	if "--shift-layout" in OS.get_cmdline_user_args():
		world.position = Vector3(20,0,-15)
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	loop = world.gameplay
	# Focused original one-product regression; multi_product_test covers the default shift.
	loop.customer_count = 4
	loop.order_patterns.assign([{&"water":1}])
	loop.delivery_manifest = {&"water":8}
	layout = world.layout
	player.global_position = world.get_node("Station/ShiftBoard").global_position+Vector3(0,0.05,1)
	await create_timer(0.6).timeout
	await use()
	while loop.preparing:
		await process_frame
	check(loop.active,"Shift starts through E interaction")
	check(loop.stock.shelf_units == 2,"Example shift starts with two bottles")
	await walk(layout.operator_point.global_position)
	if not await await_customer():
		await finish()
		return
	await capture("customer-at-checkout")
	check(loop.stock.reserved_units > 0 and loop.stock.shelf_units == 2,"Selection reserves but does not prematurely sell stock")
	await use()
	check(loop.served == 1 and loop.revenue_rappen == 220 and loop.stock.shelf_units == 1,"First checkout charges once and reduces stock")
	await use()
	check(loop.served == 1,"Immediate repeated E cannot sell the same customer twice")
	if not await await_customer():
		await finish()
		return
	await use()
	check(loop.served == 2 and loop.stock.shelf_units == 0,"Second customer empties the starting stock")
	var wait_deadline := Time.get_ticks_msec()+20000
	while not loop.customers.any(func(customer): return customer.state == &"stock_wait") and Time.get_ticks_msec() < wait_deadline:
		await create_timer(0.25).timeout
	check(loop.customers.any(func(customer): return customer.state == &"stock_wait"),"A customer waits for unavailable stock without overselling")
	await capture("empty-shelf")
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	await use()
	check(loop.stock.carried_units > 0,"Warehouse supplies the player")
	await walk(layout.shelf_point.global_position)
	await use()
	check(loop.tasks.has(&"restock") and loop.stock.shelf_units > 0,"Restocking unblocks waiting customers")
	await walk(world.get_node("Station/Cooler").global_position+Vector3(0,0,1.3))
	await use()
	check(loop.tasks.has(&"cooler"),"Cooler task is recorded")
	await walk(layout.delivery.global_position+Vector3(-1,0,0))
	await use()
	check(loop.delivery_carried,"Timed delivery can be collected")
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	await use()
	check(loop.tasks.has(&"delivery") and not loop.delivery_carried,"Delivery is deposited in warehouse stock")
	await walk(layout.operator_point.global_position)
	await create_timer(2).timeout
	check(loop.queue.size() == 2,"Two customers form a checkout queue")
	if loop.queue.size() == 2:
		check(loop.queue[0].global_position.distance_to(loop.queue[1].global_position) > 0.5,"Queued customers occupy separate places")
	await capture("queue-and-stock")
	for i in 2:
		if not await await_customer():
			await finish()
			return
		await use()
	check(loop.served == 4 and loop.revenue_rappen == 880,"Four customers are served in queue order")
	var deadline := Time.get_ticks_msec()+45000
	while loop.departed < 4 and Time.get_ticks_msec() < deadline:
		await create_timer(0.25).timeout
	check(loop.departed == 4 and loop.customers.is_empty(),"All paid customers leave without lingering")
	await use()
	check(world.phase == world.Phase.COMPLETE,"Complete loop ends the shift")
	await capture("shift-complete")
	var restart := InputEventAction.new()
	restart.action = &"restart_shift"
	restart.pressed = true
	Input.parse_input_event(restart)
	await create_timer(1).timeout
	world = current_scene
	check(world.phase == world.Phase.NOT_STARTED and world.gameplay.served == 0 and world.gameplay.customers.is_empty(),"Restart clears customers, revenue and progress")
	await finish()

func finish() -> void:
	world.queue_free()
	await create_timer(0.5).timeout
	print("VERTICAL SLICE TESTS: %d failure(s)" % failures)
	quit(failures)
