extends "res://tests/campaign_test.gd"

func run() -> void:
	var path := "user://nightshift_menu_test_%d.json" % Time.get_ticks_usec()
	set_meta("nightshift_checkpoint_path",path)
	var start = load("res://scenes/main/menu.tscn").instantiate()
	root.add_child(start)
	current_scene = start
	await process_frame
	check(start.page == "main" and not start.has_checkpoint(),"Startup menu without checkpoint disables Continue")
	await capture("menu")
	start.request_new()
	await create_timer(1).timeout
	bind_world()
	check(world.phase == world.Phase.NOT_STARTED and loop.career_shifts == 0,"New Game starts Night 1")
	check(world.menu.has_checkpoint(),"New Game creates a safe start checkpoint")
	await key(KEY_ESCAPE)
	check(paused and world.menu.page == "pause","ESC opens Pause")
	var position := player.global_position
	Input.action_press("move_right")
	await create_timer(0.3).timeout
	check(player.global_position == position,"Pause blocks movement")
	await key(KEY_E)
	check(world.phase == world.Phase.NOT_STARTED,"Pause blocks interactions")
	world.menu.show_page("settings")
	check(paused and world.menu.page == "settings","Settings keeps gameplay paused")
	var settings_before: Dictionary = world.menu.settings.values.duplicate()
	world.menu.settings.path = path + ".cfg"
	var sliders: Array = world.menu.column.get_children().filter(func(node): return node is HSlider)
	sliders[0].value = 0.35
	check(is_equal_approx(world.menu.settings.values.Master,0.35),"Master slider controls Master volume")
	sliders[1].value = 0.45
	check(is_equal_approx(world.menu.settings.values.Music,0.45) and is_equal_approx(world.menu.settings.values.SFX,settings_before.SFX),"Music slider does not alter effects volume")
	world.menu.settings.values = settings_before
	world.menu.settings.apply()
	world.menu.show_page("pause")
	await capture("pause")
	await key(KEY_ESCAPE)
	check(not paused and world.menu.page == "" and not Input.is_action_pressed("move_right"),"Resume releases held movement inputs")
	Input.action_press("move_right")
	await create_timer(0.3).timeout
	Input.action_release("move_right")
	check(player.global_position.distance_to(position)>0.2,"Movement resumes after closing menu")
	world.menu.return_main()
	await create_timer(0.5).timeout
	start = current_scene
	check(start.has_checkpoint(),"Main menu discovers existing save")
	var previous: Dictionary = start.save.read_data(path)
	previous.shifts = 1
	previous.revenue = 1234
	previous.flags = {"prior_choice":true}
	previous.events = {"night_1_main":true}
	check(start.save.store_data(previous,start.inventory),"Menu fixture stores completed-night checkpoint")
	var old: String = FileAccess.get_file_as_string(path)
	start.request_new()
	check(start.page == "confirm_new" and FileAccess.get_file_as_string(path) == old,"New Game cannot overwrite without confirmation")
	start.show_page("main")
	start.continue_game()
	await create_timer(0.8).timeout
	bind_world()
	check(loop.career_shifts == 1 and loop.inventory.stocks[&"water"].shelf_units == 2,"Continue restores Night 2 checkpoint stock")
	check(loop.career_revenue == 1234 and loop.story_flags.get("prior_choice",false) and loop.event_history.has("night_1_main"),"Menu Continue restores revenue, decisions and main events")
	world.menu.return_main()
	await create_timer(0.5).timeout
	start = current_scene
	start.request_new()
	check(start.page == "confirm_new","Existing campaign requests New Game confirmation")
	start.new_game()
	await create_timer(0.8).timeout
	bind_world()
	check(loop.career_shifts == 0 and loop.career_revenue == 0 and loop.story_flags.is_empty() and loop.event_history.is_empty(),"Confirmed New Game resets campaign to Night 1")
	world.queue_free()
	await process_frame
	var broken := FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	start = load("res://scenes/main/menu.tscn").instantiate()
	root.add_child(start)
	current_scene = start
	check(start.has_checkpoint(),"Corrupt primary save retains Continue through valid backup")
	DirAccess.remove_absolute(path+".bak")
	check(not start.has_checkpoint(),"Corrupt save without backup is safely unavailable")
	for version in [true,"1",{},[],null,-1,2]:
		check(not start.save.valid({"version":version},start.inventory),"Invalid checkpoint version rejected: %s" % str(version))
	var config = preload("res://scripts/game_settings.gd").new()
	config.path = path + ".cfg"
	config.values.Music = 0.35
	check(config.save() == OK,"Settings save")
	var loaded = preload("res://scripts/game_settings.gd").new()
	loaded.path = config.path
	loaded.load_settings()
	check(is_equal_approx(loaded.values.Music,0.35),"Settings reload volume")
	preload("res://scripts/game_settings.gd").new().load_settings()
	for suffix in ["",".bak",".tmp",".cfg"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	start.queue_free()
	await process_frame
	quit(1 if failures else 0)
