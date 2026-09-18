extends "res://tests/campaign_test.gd"

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.customer_count = 1
	loop.order_patterns.assign([{&"water":1}])
	world._on_used(&"start")
	while loop.preparing: await process_frame
	await walk(layout.product_points[&"water"].global_position)
	while loop.elapsed < 23: await process_frame
	check(loop.event_history.has(&"night_1_main"),"Night 1 main event triggers after 22 seconds")
	check(not loop.story_flags.get(&"noticed_call",false) and not world.pending_events.is_empty(),"Off-camera main event waits for staffed checkout")
	await walk(layout.operator_point.global_position)
	if not await await_customer():
		await finish()
		return
	await create_timer(0.2).timeout
	check(world.story_label.visible and world.story_time > 10,"Guaranteed main caption is clearly displayed for a long reading window")
	check(world.hud.secondary.text.contains("[F] Talk"),"Special talk control appears at checkout")
	var story: String = world.story_label.text
	world._say("Ordinary delivery notification")
	await process_frame
	check(world.story_label.text == story and world.story_label.visible,"Ordinary gameplay notification cannot replace story caption")
	await capture("guaranteed-main-event")
	world.menu.show_page("pause")
	var remaining: float = world.story_time
	await create_timer(0.5).timeout
	check(is_equal_approx(world.story_time,remaining),"Pause preserves event reading time")
	world.menu.close()
	await key(KEY_F)
	check(loop.dialogue.active,"F opens the discoverable special conversation")
	await key(KEY_SPACE)
	check(loop.dialogue.choices.size() == 2,"Special conversation offers two answers")
	await key(KEY_1)
	check(loop.story_flags.get(&"asked_about_call",false),"Chosen answer updates persistent story flag")
	await key(KEY_SPACE)
	check(not loop.dialogue.active,"Conversation returns control to checkout")
	await finish()
