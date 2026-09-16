extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	var story = world.story_world
	await create_timer(0.1).timeout
	check(is_instance_valid(story.josh),"Josh exists physically before first shift")
	story.interact(&"josh")
	loop.dialogue.close()
	check(not loop.story_flags.get(&"josh_handover_1",false),"Interrupted handover remains available")
	story.interact(&"josh")
	check(loop.dialogue.lines[1].contains("don't answer"),"Night 1 playable warning uses authored rule")
	while loop.dialogue.active: await key(KEY_SPACE)
	check(loop.story_flags.get(&"josh_handover_1",false),"Completed warning persists")
	for night in range(2,7):
		loop.career_shifts = night-1
		loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(night))
		await create_timer(0.1).timeout
		if night == 2:
			story.interact(&"josh")
			check(loop.dialogue.lines[1].contains("never said"),"Night 2 Josh denies warning without explanation")
			while loop.dialogue.active: await key(KEY_SPACE)
		if night == 3:
			loop.customer_count = 0
			for task in loop.required_tasks: loop.tasks[task] = true
			check(not loop.can_finish(),"Completed work cannot bypass Night 3 physical presentation")
			loop.events.setup(loop.definition.events,loop.event_history,loop.story_flags)
			loop.events.advance(100,0,loop.tasks)
			check(loop.event_history.has(&"night_3_main"),"Night 3 required story remains reachable without successful sales")
			loop.event_history[&"night_3_store_parcel"] = true
			loop.lost_sales = 5
			await create_timer(0.1).timeout
			check(not story.road.visible,"Road waits for physical event presentation, not just scheduled history")
			loop.story_flags[&"presented_night_3_store_parcel"] = true
			await create_timer(0.1).timeout
			check(story.road.visible and story.crack.visible,"Night 3 creates real road and crack geometry")
			loop.lost_sales = 0
		if night == 4:
			check(story.road.visible,"Road remains in Night 4")
			story.interact(&"route")
			while story.trip_busy: await create_timer(0.1).timeout
			check(story.in_depot and player.global_position.distance_to(story.depot.global_position)<2,"Compact route moves player to physical depot")
			story.interact(&"depot_clerk")
			loop.dialogue.close()
			check(not loop.tasks.has(&"depot"),"Interrupted depot conversation does not complete collection")
			story.interact(&"depot_clerk")
			check(loop.dialogue.lines[1].contains("years"),"Depot clerk treats route as established")
			while loop.dialogue.active: await key(KEY_SPACE)
			story.interact(&"return")
			while story.trip_busy: await create_timer(0.1).timeout
			check(not story.in_depot and loop.tasks.has(&"depot"),"Depot task allows return to station")
		if night == 5:
			check(story.construction.visible,"Night 5 exposes physical construction notice")
			check(story.intrusions.visible and not story.alternate.visible,"Small Redwater intrusions precede the alternate world")
			story.interact(&"construction")
			check(loop.dialogue.lines[1].contains("Redwater"),"Construction notice contains contradictory map name")
			while loop.dialogue.active: await key(KEY_SPACE)
		if night == 6:
			check(story.alternate.visible and story.branding.text.contains("REDWATER"),"Night 6 changes physical station branding")
			story.interact(&"josh")
			check(loop.dialogue.lines[2].contains("No."),"Redwater Josh lacks Redwood knowledge")
			while loop.dialogue.active: await key(KEY_SPACE)
	for id in preload("res://scripts/clue_catalog.gd").ENTRIES:
		story.interact(id)
		loop.dialogue.close()
		check(not loop.story_flags.get(StringName("clue_"+String(id)),false),"Interrupted clue does not count toward optional call")
		story.interact(id)
		check(not loop.story_flags.get(StringName("clue_"+String(id)),false),"Opening clue does not count as finishing reading")
		while loop.dialogue.active: await key(KEY_SPACE)
		check(loop.story_flags.get(StringName("clue_"+String(id)),false),"Finished optional clue is persistently recorded")
	check(preload("res://scripts/clue_catalog.gd").eligible(loop.story_flags),"Enough optional clues unlock Josh call")
	check(not preload("res://scripts/clue_catalog.gd").eligible({}),"Normal ending requires no optional clues")
	story.ending_started = true
	await create_timer(0.1).timeout
	check(not story.alternate.visible and story.branding.text.contains("REDWATER"),"Ending restores familiar station with one Redwater sign")
	await finish()
