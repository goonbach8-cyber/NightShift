extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	check(loop.interaction_prompt(layout.product_nodes[&"water"],player).begins_with("Check"),"Empty hands do not promise immediate restocking")
	loop.inventory.take_crate(&"water")
	check(loop.interaction_prompt(layout.delivery,player).contains("Refill") and not loop.interaction_prompt(layout.delivery,player).contains("Collect"),"Full hands do not advertise delivery pickup")
	check(loop.interaction_prompt(layout.product_nodes[&"water"],player).begins_with("Restock"),"Matching load offers restocking")
	check(loop.interaction_prompt(layout.product_nodes[&"chips"],player).begins_with("Check"),"Wrong load does not promise restocking")
	check(loop.interaction_prompt(layout.warehouse.get_node("Supply"),player).contains("Refill its display"),"Supply identifies the currently blocked action")
	check(loop.interaction_prompt(layout.product_nodes[&"chips"],player).contains("Carrying"),"Wrong-product prompt names the carried load")
	loop.inventory.restock(&"water")
	check(loop.interaction_prompt(layout.warehouse.get_node("Supply"),player).contains("Display full"),"Full display does not promise another crate")
	loop.stock.warehouse_units = 0
	check(loop.interaction_prompt(layout.warehouse.get_node("Supply"),player).contains("Warehouse empty"),"Empty warehouse is clear before pressing E")
	check(loop.interaction_prompt(layout.delivery,player).contains("6"),"Delivery prompt exposes manifest")
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.walking = false
	customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(customer)
	player.global_position = layout.operator_point.global_position
	check(loop.interaction_prompt(layout.checkout,player).begins_with("Scan"),"Checkout prompt names the scan action")
	loop.scanned_owner = customer.get_instance_id()
	loop.scanned_units = 1
	check(loop.interaction_prompt(layout.checkout,player).contains("Accept payment"),"Prompt changes to payment after scanning")
	var supply = layout.warehouse.get_node("Supply")
	var door = layout.warehouse.get_node("StoreDoor")
	door.is_open = true
	player.global_position = supply.global_position+Vector3(-0.085,0.05,1.17)
	player.interaction_target = door
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == supply,"Open store door does not steal E at warehouse supply")
	world.queue_free()
	await process_frame
	# Isolated candidates test stability without depending on current shop layout.
	var room := Node3D.new()
	root.add_child(room)
	var actor = load("res://scenes/player/player.tscn").instantiate()
	room.add_child(actor)
	actor.set_physics_process(false)
	var candidates: Array[Node3D] = []
	for x in [-0.6,0.6]:
		var candidate := Node3D.new()
		candidate.set_script(preload("res://scenes/interactions/interactable.gd"))
		candidate.position.x = x
		room.add_child(candidate)
		candidates.append(candidate)
	await physics_frame
	actor._update_interaction()
	var original = actor.interaction_target
	actor.position.x = 0.02 if original == candidates[0] else -0.02
	actor._update_interaction()
	check(actor.interaction_target == original,"Tiny movement between objects does not flicker prompt")
	actor.position.x = 0.35 if original == candidates[0] else -0.35
	actor._update_interaction()
	check(actor.interaction_target != original,"Deliberate movement selects the closer object")
	actor.interaction_target.hide()
	actor._update_interaction()
	check(actor.interaction_target == original,"Hidden object cannot retain the interaction prompt")
	actor.position.x = 5
	actor._update_interaction()
	check(actor.interaction_target == null,"Selection stability never extends interaction range")
	room.queue_free()
	await create_timer(0.3).timeout
	print("INTERACTION QUALITY TESTS: %d failure(s)" % failures)
	quit(failures)
