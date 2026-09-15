extends SceneTree
## Manual UI fixture: one customer, operator spawn, no automated gameplay inputs.
var world: Node3D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var audit = preload("res://tests/native_input_audit.gd").new()
	world.add_child(audit)
	world.gameplay.customer_count = 1
	world.gameplay.order_patterns.assign([{&"water":1}])
	world.gameplay.required_tasks.clear()
	world.get_node("Player").global_position = world.layout.operator_point.global_position+Vector3.UP*0.05
	world._on_used(&"start")
	while world.gameplay.preparing: await process_frame
	world.checkpoint.path = "user://nightshift_manual_test.json"
	world.gameplay.changed.connect(report)
	print("MANUAL FIXTURE READY: native E/F/Space/1/Tab/T/Y/M input only")
	await create_timer(600).timeout
	world.queue_free()
	await create_timer(0.3).timeout
	quit()
var last_report: String = ""
func report() -> void:
	var state: String = "served=%d scanned=%d revenue=%d dialogue=%s flags=%s" % [world.gameplay.served,world.gameplay.scanned_units,world.gameplay.revenue_rappen,str(world.gameplay.dialogue.active),str(world.gameplay.story_flags)]
	if state != last_report:
		print("MANUAL "+state)
		last_report = state
