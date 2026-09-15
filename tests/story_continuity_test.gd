extends "res://tests/campaign_test.gd"
func run() -> void:
	var save_path := "user://story_continuity_%d.json" % Time.get_ticks_usec()
	var branches: Array[String] = []
	for answer in 2:
		world = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		bind_world()
		loop.event_history[&"night_1_main"] = true
		var content = preload("res://scripts/dialogue_catalog.gd").for_context(loop.event_history,loop.story_flags)
		loop.dialogue.begin(1,content.lines,content.choices,loop.story_flags)
		loop.dialogue.advance()
		loop.dialogue.choose(answer)
		loop.dialogue.advance()
		world.checkpoint.path = save_path
		check(world.checkpoint.store_data(world.checkpoint.snapshot(loop),loop.inventory),"Choice checkpoint written: %d" % answer)
		world.queue_free()
		await process_frame
		world = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		bind_world()
		world.checkpoint.path = save_path
		check(world.checkpoint.load_checkpoint(loop) and loop.career_shifts == 1,"New world loads decision into Night 2")
		loop.spawn_customer()
		var customer = loop.customers[0]
		customer.state = &"queued"
		customer.walking = false
		customer.global_position = layout.queue_points[0].global_position
		loop.queue.append(customer)
		player.global_position = layout.operator_point.global_position
		await process_frame
		await key(KEY_F)
		check(loop.dialogue.active,"F opens follow-up dialogue after loading")
		branches.append(loop.dialogue.lines[0])
		check(loop.dialogue.lines[0].contains("asking" if answer == 0 else "nobody"),"Visible dialogue responds to earlier choice")
		loop.dialogue.close()
		loop.talk()
		check(loop.dialogue.lines[0] == "Evening. Long shift?","Follow-up does not repeat for every conversation")
		world.queue_free()
		await process_frame
	check(branches[0] != branches[1],"Saved answers produce distinct playable dialogue")
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.career_shifts = 2
	loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(3))
	check(loop.customer_count == 7 and loop.spawn_interval == 9,"Night 3 has independent pacing")
	loop.events.setup(loop.definition.events,loop.event_history,loop.story_flags)
	loop.event_history[&"night_3_main"] = true
	loop.navigation.rebuild(world,layout.doors)
	player.global_position = layout.operator_point.global_position
	await create_timer(0.1).timeout
	loop.events.advance(100,0)
	check(not loop.event_history.has(&"night_3_store_parcel"),"Physical event waits for player in stockroom")
	await walk(layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1))
	check(loop.events.occupied_areas.has(&"stockroom"),"Real player collision activates stockroom Area3D")
	var prop = layout.warehouse.get_node("Supply/LooseCarton")
	var before: Vector3 = prop.position
	loop.events.advance(100,0)
	await create_timer(0.9).timeout
	check(prop.changed_state and prop.position.y < before.y-0.7,"World event leaves carton visibly lowered")
	check(world.story_label.visible and world.story_label.text.contains("carton"),"Physical event is presented at its room, not the checkout")
	var settled: Vector3 = prop.position
	loop.events.advance(200,10)
	await create_timer(0.8).timeout
	check(prop.position.is_equal_approx(settled),"Repeated updates do not replay or drift physical event")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(save_path+suffix)
	await finish()
