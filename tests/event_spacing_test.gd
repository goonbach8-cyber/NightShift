extends SceneTree
var failures := 0
var fired: Array[StringName] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func run() -> void:
	var director = preload("res://scripts/event_director.gd").new()
	root.add_child(director)
	var definitions: Array[Resource] = []
	for id in [&"first",&"second",&"third"]:
		var event = preload("res://scripts/night_event.gd").new()
		event.event_id = id
		event.main_event = true
		event.after_seconds = 0
		definitions.append(event)
	director.setup(definitions,{}, {})
	director.minimum_interval = 35
	director.triggered.connect(func(event): fired.append(event.event_id))
	director.advance(0,0)
	check(fired == [&"first"],"Only one simultaneous eligible event fires")
	director.advance(34.9,0)
	check(fired.size() == 1 and not director.attempted.has(&"second"),"Cooldown preserves pending guaranteed events")
	director.advance(35,0)
	check(fired == [&"first",&"second"],"Next event fires after configured spacing")
	director.advance(70,0)
	director.advance(105,0)
	check(fired.size() == 3,"Events fire exactly once across later updates")
	director.setup(definitions,{}, {})
	director.advance(0,0)
	check(fired.size() == 4,"New night resets cooldown clock")
	director.queue_free()
	await process_frame
	print("EVENT SPACING TESTS: %d failure(s)" % failures)
	quit(failures)
