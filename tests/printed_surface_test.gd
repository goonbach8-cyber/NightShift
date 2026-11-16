extends "res://tests/campaign_test.gd"

func audit(node: Node, names: Array[String]) -> void:
	if node is Label3D and node.is_visible_in_tree():
		names.append(String(world.get_path_to(node)))
	for child in node.get_children(): audit(child,names)

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await create_timer(0.15).timeout
	var labels: Array[String] = []
	audit(world,labels)
	print("VISIBLE WORLD LABELS ",labels)
	check(labels.is_empty(),"Ordinary startup has no visible standalone world text")
	check(world.layout.phone_display is MeshInstance3D,"Phone status is drawn on a device surface")
	check(world.pump_service.pump_labels[1] is MeshInstance3D,"Fuel status is drawn on a dispenser surface")
	for parent in [world.checkout_minigame.cash_root,world.checkout_minigame.receipt_root,world.delivery_check.clipboard_root]:
		var found: Array[String] = []
		parent.show()
		audit(parent,found)
		check(found.is_empty(),String(parent.name)+" contains printed surfaces instead of billboards")
		parent.hide()
	var screen = world.layout.phone_display
	var fixed_transform: Transform3D = screen.global_transform
	screen.text = "INCOMING
0317"
	check(screen.text.contains("0317") and screen.global_transform == fixed_transform,"A live phone update changes its print without detaching from the device")
	check(screen.material_override is StandardMaterial3D and screen.material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,"Readout uses an opaque lit material")
	var receipt = world.checkout_minigame.receipt_label
	check(receipt.global_basis.z.dot(Vector3.UP) > 0.99,"Receipt print lies on the horizontal paper")
	check(world.delivery_check.clipboard_label.global_basis.z.dot(Vector3.UP) > 0.99,"Manifest print lies on the clipboard")
	world.hud.update()
	check(world.hud.prompt_panel.visible,"A focused object has one contextual HUD prompt")
	player.global_position = world.to_global(Vector3(-8.4,0.04,-1.5))
	await physics_frame
	await physics_frame
	player._update_interaction()
	world.hud.update()
	check(player.interaction_target == null and not world.hud.prompt_panel.visible,"Interaction prompt disappears after leaving all targets")
	check(world.checkout_minigame.receipt_root.position.y > 1.065,"Receipt paper sits above the actual counter top")
	check(world.delivery_check.clipboard_root.position.y >= world.layout.delivery_visual.position.y+0.25,"Delivery clipboard is supported by the delivery carton")
	check(world.pump_service.pump_labels[1].position.z > 7.25+0.433,"Pump readout is in front of its display bezel")
	await finish()
