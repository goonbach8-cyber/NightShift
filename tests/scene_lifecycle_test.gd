extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func run() -> void:
	var baseline := -1
	for night in 3:
		var world = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(world)
		world.gameplay.configure_night(preload("res://scripts/night_catalog.gd").for_night(night+1))
		await create_timer(0.1).timeout
		var props: Array[Node] = get_nodes_in_group("story_prop")
		var checkout_displays := props.filter(func(prop: Node): return prop.name == "CheckoutDisplay")
		var stockroom_parcels := props.filter(func(prop: Node): return prop.name == "LooseCarton")
		check(props.size() == 2 and checkout_displays.size() == 1 and stockroom_parcels.size() == 1,"Each physical story prop is instantiated exactly once")
		check(world.gameplay.events.triggered.get_connections().size() == 1,"Event presentation signal is connected once")
		check(world.layout.story_areas.size() == 1,"One stockroom trigger per scene")
		world.radio.toggle()
		world.effects.light_dip()
		world.queue_free()
		await create_timer(0.2).timeout
		check(get_nodes_in_group("story_prop").is_empty() and get_nodes_in_group("customer").is_empty(),"Scene exit releases event and NPC group members")
		var count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if baseline < 0: baseline = count
		else: check(count == baseline,"No node growth after repeated scene/audio/event teardown")
	quit(failures)
