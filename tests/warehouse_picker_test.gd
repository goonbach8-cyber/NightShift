extends "res://tests/vertical_slice_test.gd"

func click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion,true)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.player
	loop = world.gameplay
	layout = world.layout
	world.phase = world.Phase.ACTIVE
	loop.inventory.initialize_shelves()
	player.global_position = layout.warehouse.get_node("Supply").global_position+Vector3(0,0.05,1)
	await create_timer(0.3).timeout
	var item = loop.inventory.stocks[&"energy"]
	var warehouse_before: int = item.warehouse_units
	var shelf_before: int = item.shelf_units
	await key(KEY_E)
	var picker = world.get_node_or_null("HUD/StockPicker")
	check(is_instance_valid(picker) and picker.visible,"E opens the warehouse list without collecting a crate")
	check(loop.inventory.carried_product() == &"","Opening the list does not change inventory")
	if not is_instance_valid(picker):
		await finish()
		return
	check(player.controls_locked,"Warehouse list owns movement focus")
	var energy_row: TreeItem = picker.list.get_root().get_first_child().get_next()
	check(energy_row.get_text(1) == str(warehouse_before) and energy_row.get_text(2) == "%d / %d" % [shelf_before,item.capacity] and energy_row.get_text(3) == str(item.capacity-shelf_before),"List shows warehouse, shelf and remaining capacity from live stock")
	await key(KEY_DOWN)
	await key(KEY_ENTER)
	check(loop.inventory.carried_product() == &"energy" and item.warehouse_units+item.carried_units == warehouse_before,"Keyboard chooses Energy and conserves stock")
	check(not picker.visible and not player.controls_locked,"Pickup closes the picker and releases movement")
	await key(KEY_E)
	check(not picker.visible and item.carried_units > 0,"Carrying a crate cannot open another pickup")
	loop.interact(&"cooler",player)
	check(item.shelf_units == item.capacity and item.carried_units == 0,"Existing cooler restock consumes the selected crate")
	await key(KEY_E)
	energy_row = picker.list.get_root().get_first_child().get_next()
	check(energy_row.get_text(3) == "0","A full display shows zero remaining space")
	await key(KEY_DOWN)
	check(picker.take.disabled and picker.take.text == "Display full","Full shelf disables pickup")
	var chips = loop.inventory.stocks[&"chips"]
	var chips_before: int = chips.warehouse_units
	chips.warehouse_units = 0
	chips.changed.emit()
	await key(KEY_DOWN)
	check(picker.take.disabled and picker.take.text == "Out of stock","Empty warehouse row disables pickup")
	await key(KEY_ESCAPE)
	check(not picker.visible and world.menu.page == "" and not player.controls_locked,"Escape dismisses the picker without pausing or changing stock")
	chips.warehouse_units = chips_before
	chips.changed.emit()
	await key(KEY_E)
	check(picker.visible,"Picker reopens after cancellation")
	var chips_row: TreeItem = picker.list.get_root().get_first_child().get_next().get_next()
	var cell: Rect2 = picker.list.get_item_area_rect(chips_row,0)
	await click(picker.list.get_global_transform_with_canvas()*cell.get_center())
	if picker.list.get_selected() != chips_row:
		print("MOUSE_DIAG viewport=",root.get_visible_rect()," list=",picker.list.get_global_rect()," row=",cell," selected=",picker.list.get_selected().get_text(0))
	check(picker.list.get_selected() == chips_row,"Mouse selects the intended product row")
	await click(picker.take.get_global_rect().get_center())
	check(not picker.visible and loop.inventory.carried_product() == &"chips" and chips.warehouse_units+chips.carried_units == chips_before,"Mouse take action transfers the correct stock")
	await finish()
