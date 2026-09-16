extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+text)
	if not ok: failures += 1
func run() -> void:
	var stage := 0
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = int(arg.trim_prefix("--stage="))
		if arg.begins_with("--checkpoint="): path = arg.trim_prefix("--checkpoint=")
	if stage < 1 or stage > 7 or not path.begins_with("user://six_process_"):
		quit(1)
		return
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var loop = world.gameplay
	world.checkpoint.path = path
	if stage > 1:
		check(world.checkpoint.load_checkpoint(loop),"New process loads completed night")
		check(loop.career_shifts == stage-1 and loop.career_revenue == (stage-1)*1000,"Night and revenue survive process boundary")
		check(loop.story_flags.get(&"asked_about_call",false),"Decision remains saved")
		check(loop.event_history.size() == stage-1,"One main event per completed night without duplication")
		check(loop.stock.warehouse_units == 30-(stage-1),"Stock remains saved")
		var clues := 0
		for id in preload("res://scripts/clue_catalog.gd").ENTRIES:
			if loop.story_flags.get(StringName("clue_"+String(id)),false): clues += 1
		check(clues == mini(stage-1,5),"All discovered clues survive process boundary")
	await create_timer(0.1).timeout
	if stage >= 4:
		check(loop.story_flags.get(&"road_exists",false) and world.story_world.road.visible,"Road remains a physical world state")
		check(world.story_world.crack.visible,"Crack survives into following night")
	if stage == 5: check(world.story_world.construction.visible,"Night 5 reconstructs construction scene")
	if stage == 6: check(loop.definition.reality == &"redwater" and world.story_world.alternate.visible,"Night 6 reconstructs Redwater separately")
	if stage < 7:
		loop.customer_count = 0
		for task in loop.required_tasks: loop.tasks[task] = true
		for event in loop.definition.required_story: loop.story_flags[StringName("presented_"+String(event))] = true
		loop.revenue_rappen = 1000
		loop.stock.warehouse_units = 30-stage
		loop.story_flags[&"asked_about_call"] = true
		loop.event_history[StringName("night_%d_main" % stage)] = true
		if stage == 3:
			loop.story_flags[&"road_exists"] = true
			loop.story_flags[&"crack_exists"] = true
		var ids: Array = preload("res://scripts/clue_catalog.gd").ENTRIES.keys()
		if stage <= 5: loop.story_flags[StringName("clue_"+String(ids[stage-1]))] = true
		if stage == 6: loop.story_flags[&"ending_seen"] = true
		check(world.checkpoint.write_checkpoint(loop),"Safe completed boundary writes checkpoint")
	else:
		check(loop.story_flags.get(&"ending_seen",false),"Ending survives program restart")
		check(preload("res://scripts/clue_catalog.gd").eligible(loop.story_flags),"Optional call remains eligible after six process boundaries")
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	world.queue_free()
	await create_timer(0.3).timeout
	quit(failures)
