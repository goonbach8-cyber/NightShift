extends "res://tests/service_runtime_base.gd"
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
	key(service,KEY_R)
	check(service.fault_pending,"Reset rejected while fasteners closed")
	for i in 3:
		key(service,KEY_E)
		key(service,KEY_E)
		key(service,KEY_RIGHT)
	check(service._all_screws_open(),"Three screws each require two turns")
	key(service,KEY_R)
	await create_timer(0.65).timeout
	check(not service.fault_pending and service.return_required and not world.player.controls_locked,"Repair releases focus and requires toolkit return")
	world._on_used(&"service_tools")
	check(service.completed and not service.toolkit_carried and not service.return_required,"Returning toolkit completes maintenance")
	check(loop.story_flags.get(&"cooler_service_night_3",false),"Maintenance completion persists as story flag")
	await finish()
