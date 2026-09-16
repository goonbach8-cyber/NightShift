extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	var catalog = preload("res://scripts/night_catalog.gd")
	var first = catalog.for_night(1)
	var sixth = catalog.for_night(6)
	check(first.customer_profiles[0].id == sixth.customer_profiles[0].id,"One recognizable visitor exists in both realities")
	check(first.customer_profiles[1].id != sixth.customer_profiles[1].id,"Redwater has a different second visitor")
	loop.career_shifts = 5
	loop.configure_night(sixth)
	await create_timer(0.1).timeout
	loop.navigation.rebuild(world,layout.doors)
	loop.spawn_customer()
	var customer = loop.customers[0]
	check(customer.profile_id == &"regular_driver" and customer.greeting.contains("Mike"),"Configured visitor recognizes Mike")
	customer.walking = false
	loop.queue.append(customer)
	loop.story_flags[&"asked_about_call"] = true
	loop.story_flags[&"call_followup_night_6"] = true
	loop.talk()
	check(loop.dialogue.lines[0] == customer.greeting,"Routine conversation uses configured greeting")
	loop.dialogue.close()
	loop.story_flags.erase(&"call_followup_night_6")
	loop.talk()
	check(loop.dialogue.lines[0].contains("asking"),"Story consequence takes priority over routine profile")
	loop.dialogue.close()
	check(not loop.story_flags.get(&"call_followup_night_6",false),"Interrupted consequence remains available")
	loop.talk()
	while loop.dialogue.active: await key(KEY_SPACE)
	check(loop.story_flags.get(&"call_followup_night_6",false),"Completed consequence is recorded once")
	loop.spawn_customer()
	check(loop.customers[1].profile_id == &"redwater_courier","Second spawned visitor uses alternate-world profile")
	check(loop.customers[1].clothing_color != customer.clothing_color,"Visitors have distinct visible placeholder colors")
	await finish()
