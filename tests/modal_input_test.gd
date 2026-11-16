extends "res://tests/service_runtime_base.gd"
## ESC and focus arbitration between gameplay menus and active service panels.

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

func expect_service_owns_escape(service: Node, label: String) -> void:
	check(service.help.text.contains("ESC"),label+" shows an ESC hint")
	await press(KEY_ESCAPE)
	check(not service.active,label+" consumes ESC before Pause")
	check(world.menu.page == "" and not paused,label+" close does not open Pause")
	check(not world.player.controls_locked,label+" close restores movement")

func run() -> void:
	await setup()
	check(world.menu.page == "" and not paused,"Gameplay starts without an open menu")
	check(world.phone_system.begin(),"Counter phone opens for dialing")
	Input.action_press("move_forward")
	await expect_service_owns_escape(world.phone_system,"Phone panel")
	check(not Input.is_action_pressed("move_forward"),"Closing a panel releases held movement")
	check(world.phone_system.begin(),"Counter phone reopens after ESC")
	await press(KEY_ESCAPE)
	check(not world.phone_system.active and world.menu.page == "","Repeated phone open/close keeps ESC local")
	await press(KEY_ESCAPE)
	check(paused and world.menu.page == "pause","ESC opens Pause when no service owns input")
	await press(KEY_ESCAPE)
	check(not paused and world.menu.page == "","ESC closes Pause and returns to gameplay")

	world.pump_service._create_request()
	check(world.pump_service.begin(),"Pump authorization opens")
	await expect_service_owns_escape(world.pump_service,"Pump panel")

	check(world.cctv_system.begin(),"CCTV terminal opens")
	await expect_service_owns_escape(world.cctv_system,"CCTV panel")

	world.power_service._begin_fault()
	check(world.power_service.begin(),"Breaker panel opens")
	await expect_service_owns_escape(world.power_service,"Breaker panel")

	check(world.radio_tuner.begin(),"Radio tuner opens")
	await expect_service_owns_escape(world.radio_tuner,"Radio tuner")

	var actor = customer()
	world.player.global_position = world.layout.operator_point.global_position
	check(world.checkout_minigame.begin(),"Checkout opens for scanning")
	await expect_service_owns_escape(world.checkout_minigame,"Checkout panel")
	check(not actor.paid and loop.queue[0] == actor,"Checkout ESC leaves the queued basket unpaid and owned")

	await finish()
