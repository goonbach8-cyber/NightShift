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
	check(service.request_limit in service.PRESETS,"Fuel request uses a supported prepay limit")
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
	service.selected_limit_index = (service.PRESETS.find(requested_limit)+1)%service.PRESETS.size()
	service._authorize()
	check(service.request_pending and not service.busy,"Wrong prepay limit leaves request safely pending")

	service.selected_limit_index = service.PRESETS.find(requested_limit)
	service._authorize()
	await create_timer(0.9).timeout
	check(not service.request_pending and service.requests_completed == 1,"Correct pump and limit complete exactly one forecourt request")
	check(not service.active and not player.controls_locked,"Authorization returns control to normal play")
	check(not is_instance_valid(service.vehicle_root),"Authorized forecourt vehicle leaves its pump")
	check(world.layout.pump_terminal.prompt.contains("No requests"),"Terminal clears after service")

	world.queue_free()
	await create_timer(0.3).timeout
	print("PUMP SERVICE TESTS: %d failure(s)" % failures)
	quit(failures)
