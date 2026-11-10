extends "res://tests/vertical_slice_test.gd"

func run() -> void:
	root.size = Vector2i(1280,720)
	set_meta("nightshift_menu_session",true)
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.player
	loop = world.gameplay
	layout = world.layout
	await create_timer(0.2).timeout
	var josh: CharacterBody3D = world.story_world.josh
	var camera: Camera3D = player.get_node("CameraRig/Camera3D")
	var face := josh.global_position+Vector3.UP*1.18
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position,face,1)
	check(josh.is_visible_in_tree() and not camera.is_position_behind(face) and root.get_visible_rect().has_point(camera.unproject_position(face)),"Josh is in the normal start camera frame")
	check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"No shop collision occludes Josh from the opening camera")
	player._update_interaction()
	check(player.interaction_target == josh.get_node("josh"),"Josh owns the opening conversation prompt")
	await use()
	check(loop.dialogue.active and world.hud.conversation.speaker.text == "Josh","E opens the handover while Josh is in view")
	loop.dialogue.close()
	check(not loop.story_flags.get(&"josh_handover_1",false) and josh.get_node("josh").available,"Interrupted handover remains physically available")
	await use()
	while loop.dialogue.active:
		await key(KEY_SPACE)
	check(loop.story_flags.get(&"josh_handover_1",false) and josh.walking,"Completed handover starts Josh walking to the entrance")
	var furthest_z := josh.global_position.z
	var deadline := Time.get_ticks_msec()+7000
	while is_instance_valid(josh) and Time.get_ticks_msec() < deadline:
		furthest_z = maxf(furthest_z,josh.global_position.z)
		await physics_frame
	check(furthest_z > layout.entrance.global_position.z and not is_instance_valid(josh),"Josh walks through the door before being removed")
	loop.navigation.rebuild(world,layout.doors)
	var report: Node3D = world.story_world.get_node("accident")
	var desk: Node3D = layout.warehouse.get_node("ReportDesk")
	check(report.global_position.is_equal_approx(desk.get_node("ReportSurface").global_position),"The report is mounted on the warehouse worktop")
	var below := PhysicsRayQueryParameters3D.create(report.global_position+Vector3.UP*0.04,report.global_position-Vector3.UP*0.13,1)
	check(not world.get_world_3d().direct_space_state.intersect_ray(below).is_empty(),"The report has a solid support beneath it")
	await walk(desk.to_global(Vector3(-1.28,0,0.01)))
	player._update_interaction()
	check(player.interaction_target == report,"Player can focus the report from the staff work aisle")
	await use()
	check(world.hud.conversation.document.visible and world.hud.conversation.document_body.text.contains("03:17"),"The physical report opens the original article")
	await key(KEY_ENTER)
	check(loop.story_flags.get(&"clue_accident",false),"Reading still records the clue")
	await walk(world.get_node("Station/ShiftBoard").global_position+Vector3(0,0,1))
	await use()
	check(world.phase == world.Phase.ACTIVE,"Night 1 can start after Josh leaves and the report is read")
	await finish()
