extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await create_timer(0.4).timeout
	world.story_world.interact(&"josh")
	while loop.dialogue.active: await key(KEY_SPACE)
	check(not world.checkout_backdrop.visible,"Checkout panel stays hidden away from a transaction")
	loop.inventory.initialize_shelves()
	world.phase = world.Phase.ACTIVE
	loop.order_patterns.assign([{&"water":1,&"energy":1,&"chips":1}])
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.set_physics_process(false)
	customer.walking = false
	customer.state = &"queued"
	customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(customer)
	for id in customer.order: loop.inventory.reserve(customer.get_instance_id(),id,customer.order[id])
	player.global_position = layout.operator_point.global_position
	await create_timer(0.1).timeout
	check(world.checkout_backdrop.visible and world.checkout_label.visible,"Staffed checkout shows its contextual panel")
	check(world.checkout_backdrop.get_rect().encloses(world.checkout_label.get_rect()),"Text lies inside the contrasting background")
	check(world.checkout_backdrop.get_rect().end.x < 500,"Checkout panel leaves the central player view clear")
	check(world.checkout_label.get_minimum_size().y <= 150,"Three-product checkout text fits its reserved height")
	check(not world.checkout_backdrop.get_global_rect().intersects(world.objective.get_global_rect()),"Checkout panel does not overlap shift objectives")
	check(not world.checkout_backdrop.get_global_rect().intersects(world.story_label.get_global_rect()),"Checkout panel leaves the story caption area clear")
	check(loop.checkout_text().contains("Next:") and not loop.checkout_text().contains("[E]"),"Next article remains clear without duplicated E instructions")
	customer.global_position += Vector3(0,0,1.0)
	await create_timer(0.1).timeout
	check(not world.checkout_backdrop.visible and loop.interaction_prompt(layout.checkout,player).contains("waiting"),"Stopped customer outside service position cannot advertise a scan")
	check(not loop.checkout() and loop.scanned_units == 0,"Displayed readiness matches actual checkout rejection")
	loop.talk()
	check(not loop.dialogue.active,"Conversation cannot start with a customer still away from checkout")
	customer.global_position = layout.queue_points[0].global_position
	await create_timer(0.1).timeout
	await use()
	check(world.checkout_label.text.contains("1 / 3") and world.checkout_label.text.contains("2 remaining") and world.checkout_label.text.contains("Subtotal: CHF 2.20"),"First actual E scan shows progress, remaining items and subtotal")
	check(world.checkout_label.text.contains(loop.inventory.products[&"water"].display_name+" scanned"),"Scanned product is named")
	await use()
	check(world.checkout_label.text.contains("2 / 3") and world.checkout_label.text.contains("1 remaining") and world.checkout_label.text.contains("Subtotal: CHF 5.70"),"Second actual scan updates subtotal without accepting payment")
	check(loop.revenue_rappen == 0,"Scanning has not yet charged the basket")
	await use()
	check(loop.checkout_text().contains("Total: CHF 8.60") and loop.checkout_text().contains("Accept payment"),"Fully scanned basket switches subtotal to final total")
	var answers: Array[Dictionary] = []
	loop.dialogue.begin(customer.get_instance_id(),PackedStringArray(["Thank you."]),answers,loop.story_flags)
	await create_timer(0.1).timeout
	check(not world.checkout_backdrop.visible and world.prompt.text.is_empty(),"Conversation clears competing checkout actions")
	check(world.dialogue_backdrop.visible and world.dialogue_backdrop.get_global_rect().encloses(world.dialogue_label.get_global_rect()),"Conversation has a contrasting background with consistent padding")
	check(not world.dialogue_backdrop.get_global_rect().intersects(world.message.get_global_rect()),"Conversation background leaves transaction feedback unobstructed")
	loop.dialogue.advance()
	await create_timer(0.1).timeout
	check(world.checkout_backdrop.visible,"Checkout resumes after the conversation")
	check(not world.dialogue_backdrop.visible,"Conversation background disappears with its dialogue")
	await use()
	check(loop.revenue_rappen == 860 and not world.checkout_backdrop.visible,"Payment closes the completed checkout panel")
	check(world.message.text.contains("Payment accepted") and world.message.text.contains("8.60"),"Payment confirmation retains the correct final amount")
	loop.order_patterns.assign([{&"water":1}])
	loop.spawn_customer()
	var next_customer = loop.customers[-1]
	next_customer.set_physics_process(false)
	next_customer.walking = false
	next_customer.state = &"queued"
	next_customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(next_customer)
	loop.inventory.reserve(next_customer.get_instance_id(),&"water",1)
	await create_timer(0.1).timeout
	check(world.checkout_backdrop.visible and world.checkout_label.text.contains("0 / 1") and world.checkout_label.text.contains("Subtotal: CHF 0.00"),"Next customer starts with clean scan progress and subtotal")
	check(not world.checkout_label.text.contains("8.60"),"Previous basket total does not leak into next customer's panel")
	for night in range(1,7):
		loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(night))
		world._update_objective()
		await create_timer(0.1).timeout
		check(world.objective.get_minimum_size().y <= world.objective.size.y and world.get_node("HUD/ObjectiveBackdrop").get_global_rect().encloses(world.objective.get_global_rect()),"Night %d actionable task list fits its existing background" % night)
	loop.served = 1
	loop.lost_sales = 2
	check(loop.status_text().contains("Customers 3/6 (2 unserved)"),"Shift progress distinguishes unserved departures from customers still due")
	loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(3))
	loop.served = loop.customer_count
	loop.lost_sales = 0
	check(loop.status_text().contains("Check the stockroom before leaving"),"Unpresented required story supplies the relevant departure hint")
	for id in loop.definition.required_story: loop.story_flags[StringName("presented_"+String(id))] = true
	check(not loop.status_text().contains("Check the stockroom before leaving") and loop.status_text().contains("Check WC"),"Presented story stops sending player back to stockroom while another task remains")
	var removed := Node3D.new()
	world.add_child(removed)
	player.interaction_target = removed
	removed.free()
	world._process(0.0)
	player._update_interaction()
	check(is_instance_valid(player.interaction_target) or player.interaction_target == null,"Removed selected object does not leave a freed reference in HUD or selection")
	await finish()
