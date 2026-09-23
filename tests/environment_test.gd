extends SceneTree
## Traverse the shop via real movement input; protect access around display islands.
var world: Node3D
var player: CharacterBody3D
var failures := 0
const ACTIONS = ["move_left", "move_right", "move_forward", "move_backward"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	await create_timer(0.5).timeout
	world.gameplay.navigation.rebuild(world,world.layout.doors)
	for target in [Vector2(0,0), Vector2(-4.8,0), Vector2(-4.8,-2.3), Vector2(-4.8,0), Vector2(4.8,0), Vector2(4.8,-2.3), Vector2(4.8,0), Vector2(5.9,0.2), Vector2(5.9,1.3), Vector2(4.3,1.3), Vector2(3.0,1.3), Vector2(3.0,0), Vector2(3.0,3.6), Vector2(4.6,3.6), Vector2(0,3.6), Vector2(-4.8,3.6)]:
		var route: PackedVector3Array = world.gameplay.navigation.path(player.global_position,Vector3(target.x,0,target.y))
		var reached := not route.is_empty()
		var deadline := Time.get_ticks_msec()+30000
		while not route.is_empty() and Time.get_ticks_msec()<deadline:
			for door in world.layout.doors:
				if player.global_position.distance_to(door.global_position)<1.6 and not door.is_open and not door.moving:
					door.interact(player)
			var delta: Vector3 = route[0]-player.global_position
			delta.y = 0
			for action in ACTIONS:
				Input.action_release(action)
			if delta.length() < 0.17:
				route.remove_at(0)
			else:
				var direction: Vector3 = delta.normalized()
				Input.action_press("move_right" if direction.x > 0 else "move_left",absf(direction.x))
				Input.action_press("move_backward" if direction.z > 0 else "move_forward",absf(direction.z))
			await physics_frame
		for action in ACTIONS:
			Input.action_release(action)
		await create_timer(0.2).timeout
		reached = reached and Vector2(player.global_position.x-target.x,player.global_position.z-target.y).length()<0.55
		print(("PASS" if reached else "FAIL") + ": Walkable route to " + str(target))
		if not reached:
			failures += 1
	for action in ACTIONS:
		Input.action_release(action)
	print("ENVIRONMENT ROUTES: %d failure(s)" % failures)
	world.queue_free()
	await create_timer(0.3).timeout
	quit(failures)
