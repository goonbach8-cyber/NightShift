extends "res://tests/service_runtime_base.gd"

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	await setup()
	var service = world.device_service
	loop.elapsed = 500
	loop.served = 2
	service._process(0.1)
	check(not service.fault_pending,"Night 1 has no maintenance fault")
	loop.career_shifts = 2
	service._process(0.1)
	check(service.fault_pending and service.cooler_panel.visible,"Night 3 exposes physical cooler fault")
	world._on_used(&"cooler")
	check(not service.active,"Tools required before opening cooler")
	world._on_used(&"service_tools")
	check(service.toolkit_carried and is_instance_valid(service.carried_toolkit),"Toolkit carried physically")
	var cooler = world.get_node("Station/Cooler")
	check(cooler.action_id == &"cooler","Actual cooler action reaches maintenance routing")
	world._on_used(cooler.action_id)
	check(service.active and world.player.controls_locked,"Cooler interaction locks focus")
	check(service.help.text.contains("ESC"),"Cooler service labels ESC as close")
	await press(KEY_ESCAPE)
	check(not service.active and not world.player.controls_locked and world.menu.page == "","ESC closes cooler service without pausing")
	world._on_used(cooler.action_id)
	check(service.active and world.player.controls_locked,"Cooler service reopens after ESC")
	key(service,KEY_R)
	check(service.fault_pending,"Reset rejected while fasteners closed")
	key(service,KEY_E)
	check(service._all_screws_open() and service.cover.position.x < -0.3,"One deliberate action releases the cover and exposes the controller")
	key(service,KEY_R)
	await create_timer(0.65).timeout
	check(not service.fault_pending and service.return_required and not world.player.controls_locked,"Repair releases focus and requires toolkit return")
	world._on_used(&"service_tools")
	check(service.completed and not service.toolkit_carried and not service.return_required,"Returning toolkit completes maintenance")
	check(loop.story_flags.get(&"cooler_service_night_3",false),"Maintenance completion persists as story flag")
	await finish()
