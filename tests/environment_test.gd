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
	for target in [Vector2(0,0), Vector2(-4.8,0), Vector2(-4.8,-2.3), Vector2(-4.8,0), Vector2(4.8,0), Vector2(4.8,-2.3), Vector2(4.8,0), Vector2(5.9,0.2), Vector2(5.9,1.3), Vector2(4.3,1.3), Vector2(3.0,1.3), Vector2(3.0,0), Vector2(3.0,3.6), Vector2(4.6,3.6), Vector2(0,3.6), Vector2(-4.8,3.6)]:
		var reached := false
		for frame in 240:
			var delta: Vector2 = target - Vector2(player.position.x,player.position.z)
			for action in ACTIONS:
				Input.action_release(action)
			if delta.length() < 0.16:
				reached = true
				break
			var direction: Vector2 = delta.normalized()
			Input.action_press("move_right" if direction.x > 0 else "move_left",absf(direction.x))
			Input.action_press("move_backward" if direction.y > 0 else "move_forward",absf(direction.y))
			await physics_frame
		print(("PASS" if reached else "FAIL") + ": Walkable route to " + str(target))
		if not reached:
			failures += 1
	for action in ACTIONS:
		Input.action_release(action)
	print("ENVIRONMENT ROUTES: %d failure(s)" % failures)
	world.queue_free()
	await create_timer(0.3).timeout
	quit(failures)
