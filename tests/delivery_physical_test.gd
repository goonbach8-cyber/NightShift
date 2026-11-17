extends "res://tests/service_runtime_base.gd"
func run() -> void:
	root.size = Vector2i(1280,720)
	await setup()
	loop.career_shifts = 2
	loop.delivery_ready = true
	var receiving = world.delivery_check
	var original: Vector3 = receiving.camera.position
	check(receiving.begin(),"Physical receiving opens")
	await create_timer(0.25).timeout
	check(receiving.cartons.size() == loop.delivery_manifest.size() and not world.layout.delivery_visual.visible,"Shipment presents distinct labeled cartons, not a duplicate generic parcel")
	for id in receiving.cartons:
		var at: Vector2 = receiving.camera.unproject_position(receiving.cartons[id].to_global(Vector3(0,0.13,0)))
		for down in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = at
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
		check(receiving.order[receiving.selected] == id,"Pointer selects the physical "+String(id)+" carton")
		var matches: bool = receiving.actual_manifest[id] == loop.delivery_manifest[id]
		key(receiving,KEY_R if matches else KEY_E)
		check(not receiving.verified.has(id),"Incorrect comparison cannot approve the carton")
		key(receiving,KEY_E if matches else KEY_R)
		check(receiving.verified.has(id) and receiving.carton_labels[id].text.contains("OK" if matches else "!"),"Correct comparison visibly marks the carton")
	var actual: Dictionary = receiving.actual_manifest.duplicate()
	key(receiving,KEY_ENTER)
	await create_timer(0.25).timeout
	check(not receiving.active and loop.carried_delivery_manifest == actual,"Accepted goods retain actual quantities")
	check(receiving.camera.position.is_equal_approx(original),"Leaving receiving restores the gameplay camera")
	var before: int = loop.inventory.stocks[&"chips"].warehouse_units
	loop.interact(&"supply",world.player)
	loop.interact(&"supply",world.player)
	check(loop.inventory.stocks[&"chips"].warehouse_units == before+actual[&"chips"] and loop.tasks.has(&"delivery"),"Storage records the actual shortage once")
	await finish()
