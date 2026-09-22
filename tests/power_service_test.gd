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
	var power = world.power_service
	var loop = world.gameplay
	var player = world.player

	world.phase = world.Phase.ACTIVE
	loop.active = true
	loop.career_shifts = 1
	loop.elapsed = 80.0

	check(power.circuits.size() == 3,"Breaker panel exposes three grounded station circuits")
	power._begin_fault()
	check(power.fault_pending and power.fault_circuit >= 0,"Electrical fault selects one real circuit")
	check(not power.affected_lights.is_empty(),"Electrical fault actually dims station lighting")
	check(world.layout.breaker_panel.prompt.contains("Reset"),"Physical breaker panel advertises the fault")

	check(power.begin(),"Pending electrical fault opens breaker interaction")
	check(power.active and player.controls_locked,"Breaker focus locks movement without pausing the shift")
	var correct: int = power.fault_circuit
	power.selected_circuit = (correct+1)%power.circuits.size()
	power._reset_selected()
	check(power.fault_pending,"Wrong breaker leaves the fault active")

	power.selected_circuit = correct
	power._reset_selected()
	await create_timer(0.7).timeout
	check(not power.fault_pending and power.completed,"Correct breaker restores the electrical fault")
	check(power.affected_lights.is_empty() and power.stored_energy.is_empty(),"Restored circuit leaves no stale lighting state")
	check(not power.active and not player.controls_locked,"Breaker repair returns normal player control")
	check(world.layout.breaker_panel.prompt == "Electrical breaker panel","Breaker prompt returns to normal")

	world.queue_free()
	await create_timer(0.3).timeout
	print("POWER SERVICE TESTS: %d failure(s)" % failures)
	quit(failures)
