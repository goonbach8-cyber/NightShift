extends SceneTree
var world: Node3D
var player: CharacterBody3D
var annex: Node3D
var failures := 0
const ACTIONS = ["move_left","move_right","move_forward","move_backward"]

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+label)
	if not condition:
		failures += 1

func walk(target: Vector2) -> void:
	var reached := false
	for frame in 300:
		var delta := target - Vector2(player.position.x,player.position.z)
		for action in ACTIONS:
			Input.action_release(action)
		if delta.length() < 0.15:
			reached = true
			break
		var direction := delta.normalized()
		Input.action_press("move_right" if direction.x > 0 else "move_left",absf(direction.x))
		Input.action_press("move_backward" if direction.y > 0 else "move_forward",absf(direction.y))
		await physics_frame
	for action in ACTIONS:
		Input.action_release(action)
	await create_timer(0.25).timeout
	check(reached and player.is_on_floor(),"Walk to "+str(target))

func use() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	await create_timer(0.65).timeout

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	annex = world.get_node("Station/ServiceAnnex")
	world._on_used(&"start")
	player.position = Vector3(6,0.05,-2.2)
	await create_timer(0.5).timeout
	await use()
	check(annex.get_node("StoreDoor").is_open,"Shop-to-store door opens via E")
	await walk(Vector2(8.8,-2.2))
	await walk(Vector2(8,-3.1))
	await use()
	check(annex.carried_units == 8 and annex.reserve_units == 16,"Crate transfers exactly eight reserve units")
	await use()
	check(annex.reserve_units == 16,"Cannot pick up a second crate")
	await walk(Vector2(9.5,-2.2))
	await walk(Vector2(10,0.7))
	await use()
	check(annex.get_node("WCEntry").is_open,"WC door opens via E")
	await walk(Vector2(10,2.8))
	await walk(Vector2(10,1.8))
	await use()
	check(annex.get_node("WCEntry").is_open,"WC door cannot close on the player")
	await walk(Vector2(10,0.7))
	await use()
	check(not annex.get_node("WCEntry").is_open,"WC door closes after leaving")
	await walk(Vector2(9.4,-3.9))
	await use()
	check(annex.get_node("DeliveryDoor").is_open,"Delivery door opens via E")
	await walk(Vector2(9.4,-6.4))
	check(player.position.z < -5.5,"Delivery yard is physically accessible")
	await walk(Vector2(9.4,-5))
	await use()
	check(annex.get_node("DeliveryDoor").is_open,"Delivery door cannot close on the player")
	await walk(Vector2(9.4,-3.9))
	await use()
	check(not annex.get_node("DeliveryDoor").is_open,"Delivery door closes from the warehouse")
	await walk(Vector2(9,-2.2))
	await walk(Vector2(6,-2.2))
	await use()
	check(not annex.get_node("StoreDoor").is_open,"Store door closes after returning to the shop")
	await walk(Vector2(4.8,-2.3))
	await use()
	check(annex.carried_units == 0 and annex.shop_units == 8,"Warehouse stock reaches the shop shelf")
	world._on_used(&"supply")
	check(annex.carried_units == 0 and annex.reserve_units == 16,"Completed shelf does not reserve unnecessary stock")
	check(annex.PRODUCTS[&"water"].line_total(3) == 660,"Prices use integer rappen")
	check(annex.PRODUCTS[&"water"].line_total(-1) == 0,"Negative quantities cannot create negative totals")
	world.muted = true
	await process_frame
	await process_frame
	check(annex.sounds.all(func(sound): return sound.volume_db <= -79),"Mute covers all spatial sounds")
	world.muted = false
	await process_frame
	await process_frame
	check(annex.sounds.all(func(sound): return is_equal_approx(sound.volume_db,float(sound.get_meta("base_volume")))),"Unmute restores source levels")
	world.queue_free()
	await create_timer(0.5).timeout
	print("SERVICE TESTS: %d failure(s)" % failures)
	quit(failures)
