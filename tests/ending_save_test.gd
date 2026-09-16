extends "res://tests/campaign_test.gd"
func continue_button() -> void:
	for child in world.menu.column.get_children():
		if child is Button and child.text == "CONTINUE":
			child.pressed.emit()
			return
	check(false,"Ending Continue button exists")
func run() -> void:
	for count in [0,3,4]:
		var path := "user://ending_test_%d.json" % Time.get_ticks_usec()
		world = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		bind_world()
		loop.career_shifts = 5
		loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(6))
		loop.customer_count = 0
		for task in loop.required_tasks: loop.tasks[task] = true
		var ids: Array = preload("res://scripts/clue_catalog.gd").ENTRIES.keys()
		for i in count: loop.story_flags[StringName("clue_"+String(ids[i]))] = true
		world.phase = world.Phase.COMPLETE
		world.checkpoint.path = path
		world.menu.next_night()
		check(world.menu.page == "ending","Normal ending reachable with %d clues" % count)
		check(not world.story_world.alternate.visible,"Return world state applied before ending pauses tree")
		continue_button()
		check(world.menu.page == ("josh_call" if count >= 4 else "credits"),"Actual ending UI uses clue threshold %d" % count)
		world.menu.close()
		world.queue_free()
		await process_frame
		world = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		bind_world()
		world.checkpoint.path = path
		check(world.checkpoint.load_checkpoint(loop) and loop.career_shifts == 6,"Completed six-night save reloads")
		check(preload("res://scripts/clue_catalog.gd").eligible(loop.story_flags) == (count >= 4),"Optional call eligibility survives save/load")
		check(loop.story_flags.get(&"ending_seen",false),"Ending state persists independently of optional call")
		world.queue_free()
		await process_frame
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("ENDING SAVE TESTS: %d failure(s)" % failures)
	await create_timer(0.3).timeout
	quit(failures)
