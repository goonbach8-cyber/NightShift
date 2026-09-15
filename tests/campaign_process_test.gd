extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func run() -> void:
	var stage := 0
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = int(arg.trim_prefix("--stage="))
		if arg.begins_with("--checkpoint="): path = arg.trim_prefix("--checkpoint=")
	if stage < 1 or stage > 3 or not path.begins_with("user://campaign_process_"):
		quit(1)
		return
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var loop = world.gameplay
	world.checkpoint.path = path
	if stage > 1:
		check(world.checkpoint.load_checkpoint(loop),"Fresh process loads previous night")
		check(loop.career_shifts == stage-1 and loop.career_revenue == (stage-1)*1000,"Night and cumulative revenue cross process boundary")
		check(loop.story_flags.get(&"asked_about_call",false),"Decision survives process exit")
		check(loop.event_history.has(StringName("process_night_%d" % (stage-1))),"Event history survives process exit")
		check(loop.stock.warehouse_units == 20-(stage-1),"Warehouse stock survives process exit")
	if stage < 3:
		loop.customer_count = 0
		for task in loop.required_tasks: loop.tasks[task] = true
		loop.revenue_rappen = 1000
		loop.stock.warehouse_units = 20-stage
		loop.story_flags[&"asked_about_call"] = true
		loop.event_history[StringName("process_night_%d" % stage)] = true
		check(world.checkpoint.write_checkpoint(loop),"Completed boundary writes next-night checkpoint")
	else:
		check(loop.definition.title.contains("Reality changes"),"Third process configures distinct Night 3")
		var content = preload("res://scripts/dialogue_catalog.gd").for_context(loop.event_history,loop.story_flags,3)
		check(content.lines[0].contains("asking"),"Persisted choice selects visible Night 3 response")
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	world.queue_free()
	await create_timer(0.3).timeout
	quit(failures)
