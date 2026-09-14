extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var loop = world.gameplay
	var saver = world.checkpoint
	saver.path = "user://nightshift_cross_process_test.json"
	var ok := false
	if "--write" in OS.get_cmdline_user_args():
		loop.customer_count = 0
		loop.tasks = {&"cooler":true,&"restock":true,&"delivery":true}
		loop.revenue_rappen = 4321
		loop.stock.warehouse_units = 9
		loop.event_history[&"process_test"] = true
		ok = saver.write_checkpoint(loop)
	else:
		ok = saver.load_checkpoint(loop) and loop.career_revenue == 4321 and loop.stock.warehouse_units == 9 and loop.event_history.has(&"process_test")
		for suffix in ["",".tmp",".bak"]:
			if FileAccess.file_exists(saver.path+suffix): DirAccess.remove_absolute(saver.path+suffix)
	print(("PASS" if ok else "FAIL")+": Separate-process save/load")
	world.queue_free()
	await create_timer(0.3).timeout
	quit(0 if ok else 1)
