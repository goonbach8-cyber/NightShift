extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var service = world.customer_assistance
	var player = world.player
	var actor = customer()
	loop.served = 1
	check(not service.handle_checkout_use(),"First night does not require lost-item assistance")
	for night in [2,3,4]:
		loop.career_shifts = night-1
		service.completed = false
		await use_checkout()
		check(service.request_active,"Later customer requests lost item through checkout interaction")
		check(actor.state == &"assistance" and is_instance_valid(service.item_node),"Customer waits while lost item exists in shop")
		var before: float = actor.wait_seconds
		loop.customer_count = loop.spawned
		loop._process(5.0)
		check(actor.wait_seconds == before,"Assisted customer does not lose patience")
		await use_at(service.item_node)
		check(service.item_found and is_instance_valid(service.carried_item),"Lost item can be carried")
		await use_checkout()
		check(actor.state == &"queued" and service.completed and not service.request_active,"Returning item restores normal queue state")
	check(loop.checkout() and loop.checkout() and actor.paid,"Checkout works after assistance")
	await finish()

func use_at(point: Node3D) -> void:
	var player = world.player
	player.global_position = point.global_position+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == point,"Player focus reaches %s" % point.name)
	if player.interaction_target == point:
		player.interaction_target.interact(player)

func use_checkout() -> void:
	var player = world.player
	player.global_position = world.layout.operator_point.global_position+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == world.layout.checkout,"Checkout is focused from staff position")
	if player.interaction_target == world.layout.checkout:
		player.interaction_target.interact(player)
