extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await process_frame
	check(not world.checkout_backdrop.visible,"Checkout panel stays hidden away from a transaction")
	loop.order_patterns.assign([{&"water":1,&"energy":1,&"chips":1}])
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.walking = false
	loop.queue.append(customer)
	player.global_position = layout.operator_point.global_position
	await create_timer(0.1).timeout
	check(world.checkout_backdrop.visible and world.checkout_label.visible,"Staffed checkout shows its contextual panel")
	check(world.checkout_backdrop.get_rect().encloses(world.checkout_label.get_rect()),"Text lies inside the contrasting background")
	check(world.checkout_backdrop.get_rect().end.x < 500,"Checkout panel leaves the central player view clear")
	check(world.checkout_label.get_minimum_size().y <= 150,"Three-product checkout text fits its reserved height")
	check(loop.checkout_text().contains("Next:") and not loop.checkout_text().contains("[E]"),"Next article remains clear without duplicated E instructions")
	loop.scanned_owner = customer.get_instance_id()
	loop.scanned_units = 3
	await process_frame
	check(loop.checkout_text().contains("Total: CHF 8.60") and loop.checkout_text().contains("Accept payment"),"Fully scanned basket switches subtotal to final total")
	var answers: Array[Dictionary] = []
	loop.dialogue.begin(customer.get_instance_id(),PackedStringArray(["Thank you."]),answers,loop.story_flags)
	await process_frame
	check(not world.checkout_backdrop.visible and world.prompt.text.is_empty(),"Conversation clears competing checkout actions")
	loop.dialogue.advance()
	await process_frame
	check(world.checkout_backdrop.visible,"Checkout resumes after the conversation")
	await finish()
