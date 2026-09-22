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
	var delivery = world.delivery_check
	var player = world.player

	world.phase = world.Phase.ACTIVE
	loop.active = true
	loop.inventory.initialize_shelves()
	loop.delivery_ready = true
	world.layout.delivery.available = true
	world.layout.delivery_visual.show()

	check(delivery.begin(),"Waiting yard delivery opens receiving inspection")
	check(delivery.active and player.controls_locked,"Delivery inspection locks movement without pausing the shift")
	check(delivery.order.size() == loop.delivery_manifest.size(),"Inspection exposes every manifest line")

	delivery._accept()
	check(loop.delivery_ready and not loop.delivery_carried,"Unchecked delivery cannot be accepted")

	for i in delivery.order.size():
		delivery.selected = i
		delivery._verify_selected(true)
	check(delivery.verified.size() == loop.delivery_manifest.size(),"Every matching carton can be verified")

	delivery._accept()
	await process_frame
	check(loop.delivery_carried and not loop.delivery_ready,"Verified delivery becomes the carried mixed shipment")
	check(loop.carried_delivery_manifest == loop.delivery_manifest,"Accepted shipment preserves its verified manifest")
	check(not delivery.active and not player.controls_locked,"Accepted delivery returns control to the player")

	loop.interact(&"supply",player)
	check(not loop.delivery_carried and loop.tasks.has(&"delivery"),"Verified shipment stores through the existing warehouse workflow")
	check(loop.carried_delivery_manifest.is_empty(),"Stored shipment leaves no stale carried manifest")

	world.queue_free()
	await create_timer(0.3).timeout
	print("DELIVERY CHECK TESTS: %d failure(s)" % failures)
	quit(failures)
