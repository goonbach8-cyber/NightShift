extends "res://tests/service_runtime_base.gd"

func walk_to(player: CharacterBody3D, target: Vector3) -> void:
	var route: PackedVector3Array = world.gameplay.navigation.path(player.global_position,target)
	check(not route.is_empty(),"Service approach has a navigable route")
	var deadline := Time.get_ticks_msec()+10000
	while not route.is_empty() and Time.get_ticks_msec() < deadline:
		var delta: Vector3 = route[0]-player.global_position
		delta.y = 0
		for action in ["move_left","move_right","move_forward","move_backward"]:
			Input.action_release(action)
		if delta.length() < 0.17:
			route.remove_at(0)
		else:
			var direction := delta.normalized()
			Input.action_press("move_right" if direction.x > 0 else "move_left",absf(direction.x))
			Input.action_press("move_backward" if direction.z > 0 else "move_forward",absf(direction.z))
		await physics_frame
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	await create_timer(0.3).timeout
	check(player.global_position.distance_to(target) < 0.6,"Player physically reaches service approach")

func run() -> void:
	await setup()
	var player = world.player
	var chips = world.layout.product_nodes[&"chips"]
	var approach: Vector3 = world.layout.product_points[&"chips"].global_position
	player.global_position = approach+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == chips,"Player can select chips from its actual customer approach")
	var phone = world.layout.phone_point
	world.phone_system.story_ring()
	player.global_position = phone.get_node("Approach").global_position+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == phone,"Ringing phone wins at its authored approach")
	player.global_position = Vector3(4.04,0.05,1.44)
	player.interaction_target = world.layout.checkout
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == phone,"Ringing phone remains selectable at the navigated stopping point")
	world.phone_system._ignore()
	world.pump_service._create_request()
	var pump = world.layout.pump_terminal
	world.gameplay.navigation.rebuild(world,world.layout.doors)
	player.global_position = pump.get_node("Approach").global_position+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == pump,"Pending pump request is selectable at its terminal approach")
	player.global_position = Vector3(4.04,0.05,1.43)
	player.interaction_target = world.layout.checkout
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == pump,"Pending pump request wins at the navigated stopping point after checkout")
	player.global_position = world.layout.operator_point.global_position+Vector3.UP*0.05
	player.interaction_target = world.layout.checkout
	await walk_to(player,pump.get_node("Approach").global_position)
	player._update_interaction()
	check(player.interaction_target == pump,"Pending pump request survives physical movement from checkout")
	world.pump_service._complete_request()
	world.cctv_system._queue_motion_check()
	var cctv = world.layout.cctv_terminal
	player.global_position = cctv.get_node("Approach").global_position+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == cctv,"Pending CCTV alert is selectable at its terminal approach")
	var cleaning = world.layout.cleaning_station
	world.gameplay.navigation.rebuild(world,world.layout.doors)
	var cleaning_approach: Vector3 = cleaning.get_node("Approach").global_position
	var cleaning_route: PackedVector3Array = world.gameplay.navigation.path(world.layout.radio_point.global_position,cleaning_approach)
	check(not cleaning_route.is_empty(),"Cleaning kit approach has a real player route")
	player.global_position = cleaning_approach+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == cleaning,"Cleaning kit can be selected at its approach")
	var key_station = world.layout.customer_service_key
	key_station.available = true
	var key_approach: Vector3 = key_station.get_node("Approach").global_position
	check(not world.gameplay.navigation.path(world.layout.operator_point.global_position,key_approach).is_empty(),"Restroom key has a route from checkout")
	player.global_position = key_approach+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == key_station,"Restroom key can be selected at its staff-area approach")
	key_station.available = false
	world.cctv_system.motion_pending = false
	world.cctv_system._update_terminal_prompt()
	player.global_position = world.layout.operator_point.global_position+Vector3.UP*0.05
	await physics_frame
	player._update_interaction()
	check(player.interaction_target == world.layout.checkout,"Idle counter selects checkout at the operator point")
	await finish()
