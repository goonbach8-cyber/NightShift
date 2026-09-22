extends SceneTree
var failures := 0
var world
var loop

func _initialize() -> void:
	call_deferred("run")

func setup() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	loop = world.gameplay
	world.phase = world.Phase.ACTIVE
	loop.active = true
	loop.inventory.initialize_shelves()
	# Isolate the service under test from unrelated timers, not its input/state logic.
	loop.set_process(false)
	for service in [world.pump_service,world.cctv_system,world.power_service,world.phone_system,world.spill_service,world.radio_tuner,world.device_service]:
		service.set_process(false)

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures += 1

func key(service: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	service._input(event)
	event.pressed = false
	service._input(event)

func customer():
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	var actor = loop.customers[-1]
	actor.set_physics_process(false)
	actor.walking = false
	actor.state = &"queued"
	actor.global_position = world.layout.queue_points[0].global_position
	loop.queue.append(actor)
	check(loop.inventory.reserve(actor.get_instance_id(),&"water",1),"Customer owns reserved basket")
	return actor

func finish() -> void:
	world.queue_free()
	await create_timer(0.3).timeout
	print("SERVICE RUNTIME TESTS: %d failure(s)" % failures)
	quit(failures)
