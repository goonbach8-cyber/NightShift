extends SceneTree
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value:
		failures += 1

func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var cctv = world.cctv_system
	var loop = world.gameplay
	var player = world.player

	world.phase = world.Phase.ACTIVE
	loop.active = true
	loop.elapsed = 50.0

	check(cctv.channels.size() == 4,"CCTV exposes four authored station camera positions")
	check(is_instance_valid(cctv.viewport) and is_instance_valid(cctv.feed_camera),"CCTV owns a live shared-world camera feed")
	cctv._queue_motion_check()
	check(cctv.motion_pending and cctv.motion_channel >= 0 and cctv.motion_channel < 4,"Motion alert targets one real camera")
	check(world.layout.cctv_terminal.prompt.contains("motion alert"),"Physical monitor advertises a pending alert")

	check(cctv.begin(),"Security monitor opens during an active shift")
	check(cctv.active and player.controls_locked,"CCTV focus locks movement without pausing the shift")
	var target: int = cctv.motion_channel
	cctv.selected_channel = (target+1)%cctv.channels.size()
	cctv.view_time = 1.0
	cctv._acknowledge()
	check(cctv.motion_pending,"Wrong camera cannot clear the alert")

	cctv.selected_channel = target
	cctv._apply_channel()
	cctv.view_time = 0.2
	cctv._acknowledge()
	check(cctv.motion_pending,"Alert cannot be cleared before the feed is actually reviewed")

	cctv.view_time = 1.0
	cctv._acknowledge()
	check(not cctv.motion_pending and cctv.checks_completed == 1,"Reviewed matching feed clears exactly one motion alert")
	check(world.layout.cctv_terminal.prompt == "Security cameras","CCTV monitor returns to normal after review")
	cctv.close()
	check(not cctv.active and not player.controls_locked,"Closing CCTV returns normal player control")

	world.queue_free()
	await create_timer(0.3).timeout
	print("CCTV SYSTEM TESTS: %d failure(s)" % failures)
	quit(failures)
