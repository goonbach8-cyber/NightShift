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
	var service = world.pump_service
	var loop = world.gameplay
	var player = world.player
	world.phase = world.Phase.ACTIVE
	loop.active = true
	loop.elapsed = 30.0

	service._create_request()
	check(service.request_pending and service.request_pump in [1,2,3,4],"Fuel request selects one of four physical pumps")
	check(service.request_limit in [3000,5000,8000],"Fuel request uses a supported prepay limit")
	check(is_instance_valid(service.vehicle_root),"Waiting fuel request creates a visible forecourt vehicle")
	check(world.layout.pump_terminal.prompt.contains("awaiting authorization"),"Physical pump terminal advertises the waiting request")

	check(service.begin(),"Pending request opens pump authorization mode")
	check(service.active and player.controls_locked,"Pump terminal locks player movement while focused")
	var requested_pump: int = service.request_pump
	var requested_limit: int = service.request_limit

	service.selected_pump = 1 if requested_pump != 1 else 2
	service._authorize()
	check(service.request_pending and not service.busy,"Wrong pump cannot authorize somebody else's dispenser")

	service.selected_pump = requested_pump
	service.selected_limit_index = ([3000,5000,8000].find(requested_limit)+1)%[3000,5000,8000].size()
	service._authorize()
	check(service.request_pending and not service.busy,"Wrong prepay limit leaves request safely pending")

	service.selected_limit_index = [3000,5000,8000].find(requested_limit)
	service._authorize()
	await create_timer(0.9).timeout
	check(not service.request_pending and service.requests_completed == 1,"Correct pump and limit complete exactly one forecourt request")
	check(not service.active and not player.controls_locked,"Authorization returns control to normal play")
	check(not is_instance_valid(service.vehicle_root),"Authorized forecourt vehicle leaves its pump")
	check(world.layout.pump_terminal.prompt.contains("No requests"),"Terminal clears after service")

	# Later shifts can turn an authorization into a physical dispenser fault.
	loop.career_shifts = 1
	service._create_request()
	var fault_request_pump: int = service.request_pump
	service.begin()
	service.selected_pump = fault_request_pump
	service.selected_limit_index = [3000,5000,8000].find(service.request_limit)
	service._authorize()
	await create_timer(0.9).timeout
	check(service.fault_pending and service.fault_pump == fault_request_pump,"Later authorization can require a physical pump reset")
	check(world.layout.pump_reset_points[fault_request_pump].available,"Only the faulted dispenser exposes its reset interaction")
	check(not service.active,"Fault sends the player back into the forecourt instead of trapping them in terminal UI")
	service.reset_fault(fault_request_pump)
	await process_frame
	check(not service.fault_pending and service.requests_completed == 2,"Outdoor reset completes the interrupted fuel request")
	check(not world.layout.pump_reset_points[fault_request_pump].available,"Reset control disables again after repair")

	world.queue_free()
	await create_timer(0.3).timeout
	print("PUMP SERVICE TESTS: %d failure(s)" % failures)
	quit(failures)
