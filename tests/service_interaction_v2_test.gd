extends "res://tests/service_runtime_base.gd"
func click(at: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	await setup()
	var camera: Camera3D = world.player.get_node("CameraRig/Camera3D")
	var power = world.power_service
	power._begin_fault()
	world.player.global_position = world.layout.breaker_panel.get_node("Approach").global_position
	check(power.begin(),"Faulted physical breaker opens")
	var index: int = power.fault_circuit
	var lever: MeshInstance3D = world.layout.breaker_switches[index]
	check(absf(lever.rotation.z) > 0.5,"Only the tripped lever visibly changes position")
	await click(camera.unproject_position(lever.global_position))
	check(not power.fault_pending and not power.active and is_zero_approx(lever.rotation.z),"Clicking the tripped lever restores real lighting and releases focus immediately")
	var spill = world.spill_service
	loop.career_shifts = 1
	spill._spawn_spill()
	spill._take_kit()
	check(spill.begin_cleanup(),"Mop is ready at the spill")
	spill.sweep_right = true
	spill._process(0.20)
	spill.sweep_right = false
	var cleaned: int = spill.coverage.size()
	key(spill,KEY_ESCAPE)
	check(not spill.active and not world.player.controls_locked,"Mopping can be interrupted safely")
	check(spill.begin_cleanup() and spill.coverage.size() >= cleaned,"Putting the mop down does not recreate cleaned dirt")
	spill.sweep_right = true
	spill._process(1.1)
	await create_timer(0.2).timeout
	check(spill.return_required and not spill.active,"Spatial coverage replaces mandatory repeated passes")
	spill._return_kit()
	var tuner = world.radio_tuner
	loop.career_shifts = 1
	tuner._trigger_drift()
	check(tuner.begin(),"Drifting radio opens")
	if not world.radio.enabled: key(tuner,KEY_T)
	world.radio.set_frequency(tuner.drift_target)
	tuner._process(0.30)
	check(not tuner.drift_pending and tuner.active,"A stable restored signal resolves the fault without an extra confirm/close cycle")
	tuner.close()
	var cctv = world.cctv_system
	check(cctv.begin(),"CCTV opens after maintenance without overlapping focus")
	key(cctv,KEY_4)
	check(cctv.selected_channel == 3,"Number key selects the fourth physical camera directly")
	key(cctv,KEY_1)
	check(cctv.selected_channel == 0,"Number key returns to the forecourt feed")
	cctv.close()
	await finish()
