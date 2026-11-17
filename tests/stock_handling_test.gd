extends "res://tests/service_runtime_base.gd"

func visible_goods(id: StringName) -> int:
	var amount := 0
	for item in world.layout.carry_contents[id]:
		if item.visible: amount += 1
	return amount

func mesh_bounds(node: Node3D, relative: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.get_children():
		if child is MeshInstance3D:
			var bound: AABB = (relative.global_transform.affine_inverse()*child.global_transform)*child.get_aabb()
			box = bound if first else box.merge(bound)
			first = false
	return box

func run() -> void:
	await setup()
	var layout = world.layout
	for id in [&"water",&"energy",&"chips"]:
		var stock = loop.inventory.stocks[id]
		var warehouse: int = stock.warehouse_units
		var shelf: int = stock.shelf_units
		check(loop.inventory.reserve(101,id,1),"An existing customer reservation coexists with stock handling")
		check(loop.collect_stock(id),"Collect a physical crate: "+String(id))
		var carried: int = stock.carried_units
		check(visible_goods(id) == carried and layout.carried_visual.visible,"Open crate shows its actual carried quantity: "+String(id))
		for slot in layout.carry_contents[id]:
			var bounds := mesh_bounds(slot,layout.carried_visual)
			check(bounds.position.x >= -0.198 and bounds.end.x <= 0.198 and bounds.position.z >= -0.138 and bounds.end.z <= 0.138,"Merchandise lies inside the physical crate walls")
			check(bounds.position.y >= -0.135 and bounds.position.y <= -0.12,"Merchandise rests on the crate floor, not in midair")
		var attachment: Transform3D = layout.carried_visual.transform
		var anchor: Node3D = layout.carried_visual.get_parent()
		check(anchor.name == "CarryAnchor" and absf(anchor.position.x) < 0.01,"Crate attaches centrally to Mike instead of floating beside him")
		for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			world.player._update_facing(direction)
			check(layout.carried_visual.transform.is_equal_approx(attachment),"Turning cannot detach the container or its contents")
		for other in loop.inventory.products:
			if other != id: check(visible_goods(other) == 0,"Crate does not show the wrong merchandise")
		# Receiving or reserving goods while a crate is carried must not invent
		# stock when that crate is returned instead of restocked.
		var reserved: int = stock.reserved_units
		check(loop.return_stock(),"Unused crate can be put back")
		check(stock.warehouse_units == warehouse and stock.shelf_units == shelf and stock.reserved_units == reserved,"Return conserves warehouse, display and reservations")
		check(not layout.carried_visual.visible and visible_goods(id) == 0,"Return clears physical contents")
		check(not loop.return_stock(),"Repeated return cannot duplicate warehouse stock")
		check(loop.collect_stock(id),"Returned merchandise can be picked up again")
		loop.fill_shelf(id)
		check(stock.carried_units == 0 and stock.shelf_units == shelf+carried,"Placement uses the existing stock authority exactly once")
		var slots: Array = layout.shelf.get_parent().restock_items if id == &"water" else layout.displays[id].slots
		var target: Node3D = slots[shelf]
		var rest: Vector3 = layout.placement_tweens[target].rest
		check(not target.position.is_equal_approx(rest),"Actual shelf merchandise moves during placement")
		await create_timer(0.55).timeout
		check(target.position.is_equal_approx(rest) and layout.placement_tweens.is_empty(),"Placement settles at the authored shelf positions without leftover tweens")
		check(stock.reserved_units == reserved,"Restocking does not consume a customer's reservation")
		loop.inventory.release(101)
	await finish()
