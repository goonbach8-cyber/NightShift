extends "res://tests/campaign_test.gd"

func meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): result.append_array(meshes(child))
	return result

func bounds(node: Node3D, relative_to: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mesh in meshes(node):
		if not mesh.is_visible_in_tree(): continue
		var box: AABB = (relative_to.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await create_timer(0.2).timeout
	var board_sizes := {&"water":Vector3(1.8,0.09,0.65),&"energy":Vector3(1.3,0.035,0.68),&"chips":Vector3(1.3,0.07,1.55)}
	for id in board_sizes:
		var stock: Resource = loop.inventory.stocks[id]
		stock.shelf_units = stock.capacity
		stock.changed.emit()
		var parent: Node3D = layout.product_nodes[id]
		var boards: Array[AABB] = []
		var header := AABB()
		# Static source geometry remains available after batching for measurements.
		for mesh in meshes(parent):
			if not mesh.mesh is BoxMesh: continue
			var box: AABB = (parent.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
			if mesh.mesh.size.is_equal_approx(board_sizes[id]): boards.append(box)
			if id == &"water" and mesh.mesh.size.is_equal_approx(Vector3(1.8,0.19,0.66)): header = box
		check(not boards.is_empty(),String(id)+" has measurable physical shelf boards")
		var slots: Array = world.get_node("Station").restock_items if id == &"water" else layout.displays[id].slots
		player.global_position = layout.product_points[id].global_position
		await create_timer(0.1).timeout
		var camera: Camera3D = player.get_node("CameraRig/Camera3D")
		var framed := true
		var minimum_width := INF
		for i in slots.size():
			var product := bounds(slots[i],parent)
			var center := parent.to_global(product.get_center())
			framed = framed and not camera.is_position_behind(center) and root.get_visible_rect().has_point(camera.unproject_position(center))
			var left := camera.unproject_position(parent.to_global(product.get_center()-Vector3(product.size.x/2,0,0)))
			var right := camera.unproject_position(parent.to_global(product.get_center()+Vector3(product.size.x/2,0,0)))
			minimum_width = minf(minimum_width,left.distance_to(right))
			var supported := false
			for board in boards:
				var gap: float = product.position.y-board.end.y
				if gap >= -0.002 and gap <= 0.02 and product.position.x >= board.position.x and product.end.x <= board.end.x and product.position.z >= board.position.z and product.end.z <= board.end.z:
					supported = true
			check(supported,"%s slot %d sits on its shelf without floating over the edge" % [id,i])
			if id == &"water": check(not product.intersects(header),"Water slot %d clears its header" % i)
			if id == &"energy": check(product.end.z < 0.501,"Energy slot %d remains behind the glass" % i)
		check(framed,String(id)+" product centers are inside the normal camera frame at their interaction point")
		check(minimum_width >= 6,"%s products project to at least six pixels across (%.1f px); occlusion still needs visual review" % [id,minimum_width])
	await finish()
