extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var loop = world.gameplay
	var saver = load("res://scripts/shift_save.gd").new()
	saver.path = "user://nightshift_test_%d.json" % Time.get_ticks_usec()
	check(not saver.load_checkpoint(loop),"No save returns safely")
	loop.customer_count = 0
	loop.tasks = {&"cooler":true,&"restock":true,&"delivery":true}
	loop.revenue_rappen = 1234
	loop.stock.shelf_units = 3
	loop.stock.warehouse_units = 17
	loop.story_flags[&"asked_about_call"] = true
	loop.event_history[&"night_1_main"] = true
	loop.active = true
	check(not saver.write_checkpoint(loop),"Active shift cannot be saved")
	loop.active = false
	check(saver.write_checkpoint(loop),"Completed boundary saves all data")
	check(saver.write_checkpoint(loop),"Repeated save replaces checkpoint without doubling statistics")
	world.queue_free()
	await create_timer(0.4).timeout
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	loop = world.gameplay
	check(saver.load_checkpoint(loop),"Fresh game scene loads checkpoint")
	check(loop.career_shifts == 1 and loop.career_revenue == 1234 and loop.customer_count == 8,"Load configures next night and correct statistics")
	check(loop.stock.shelf_units == 3 and loop.stock.warehouse_units == 17,"Shelf and warehouse quantities persist independently")
	check(loop.story_flags.get(&"asked_about_call",false) and loop.event_history.get(&"night_1_main",false),"Choices and experienced main events persist")
	check(loop.required_tasks.has(&"service"),"Night two adds service task through configuration")
	var file := FileAccess.open(saver.path,FileAccess.WRITE)
	file.store_string("broken checkpoint")
	file.close()
	check(saver.load_checkpoint(loop),"Damaged primary save falls back to previous checkpoint")
	DirAccess.remove_absolute(saver.path+".bak")
	check(not saver.load_checkpoint(loop) and loop.stock.shelf_units == 3,"Invalid save without backup leaves current state unchanged")
	check(not saver.valid({"version":1,"revenue":-1,"shifts":0,"stocks":{}},loop.inventory),"Negative or incomplete save rejected")
	world._on_used(&"start")
	while loop.preparing: await process_frame
	check(loop.stock.shelf_units == 3,"Starting loaded night preserves restored shelves")
	check(not saver.load_checkpoint(loop),"Loading cannot overwrite active customers or stock")
	world.queue_free()
	await create_timer(0.4).timeout
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(saver.path+suffix): DirAccess.remove_absolute(saver.path+suffix)
	print("SAVE TESTS: %d failure(s)" % failures)
	quit(failures)
