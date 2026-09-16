extends "res://tests/campaign_test.gd"

func inspect_conversation(lines: PackedStringArray, choices: Array[Dictionary], label: String) -> void:
	if lines.is_empty(): return
	loop.dialogue.begin(-99,lines,choices,{})
	var fits := true
	for index in lines.size():
		await create_timer(0.04).timeout
		fits = fits and world.dialogue_label.get_minimum_size().y <= world.dialogue_label.size.y
		fits = fits and world.dialogue_backdrop.get_global_rect().encloses(world.dialogue_label.get_global_rect())
		if index+1 < lines.size(): loop.dialogue.advance()
	check(fits,label+" fits without cropping its text or choices")
	if not choices.is_empty():
		check(world.dialogue_label.text.contains("[1]") and world.dialogue_label.text.contains("[2]") and not world.dialogue_label.text.contains("[Space]"),label+" shows answer keys instead of a misleading continue action")
	loop.dialogue.close()

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await create_timer(0.4).timeout
	var no_choices: Array[Dictionary] = []
	for night in range(1,7):
		var definition = preload("res://scripts/night_catalog.gd").for_night(night)
		await inspect_conversation(definition.handover,no_choices,"Night %d handover" % night)
		for flags in [{},{&"asked_about_call":true},{&"denied_call":true}]:
			var content = preload("res://scripts/dialogue_catalog.gd").for_context({&"night_1_main":true},flags,night)
			await inspect_conversation(content.lines,content.choices,"Night %d customer branch %s" % [night,str(flags)])
	await create_timer(0.1).timeout
	check(not world.dialogue_backdrop.visible and not world.dialogue_label.visible,"Completed conversations leave no permanent dialogue panel")
	check(world.dialogue_backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Dialogue background does not intercept pointer input")
	await finish()
