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
	var door = world.get_node("Station/Door")
	await create_timer(0.3).timeout
	door.interact(null)
	await create_timer(0.7).timeout
	var customer := CharacterBody3D.new()
	customer.collision_layer = 4
	customer.add_to_group("customer")
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 0.7
	customer.add_child(shape)
	world.add_child(customer)
	customer.global_position = door.global_position
	await create_timer(0.3).timeout
	check(door._occupied(),"Door sensor detects customer collision layer")
	door.interact(null)
	await create_timer(0.7).timeout
	check(door.is_open and not door.moving,"Door refuses to close on customer")
	customer.queue_free()
	await create_timer(0.3).timeout
	door.interact(null)
	await create_timer(0.7).timeout
	check(not door.is_open,"Door closes after customer leaves")
	world.queue_free()
	await create_timer(0.3).timeout
	print("CUSTOMER DOOR TESTS: %d failure(s)" % failures)
	quit(failures)
