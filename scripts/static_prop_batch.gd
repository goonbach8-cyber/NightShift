extends RefCounted
## Merge opaque static surfaces by material and small spatial cell.
## Small cells preserve culling and Compatibility's per-object local-light selection.
static func build(station: Node3D) -> void:
	var groups: Dictionary = {}
	var sources: Array[MeshInstance3D] = []
	var excluded: Array[Node] = [station.get_node("Door")]
	for item in station.restock_items:
		excluded.append(item)
	for item in station.get_node("ServiceAnnex").doors:
		excluded.append(item)
	collect(station,station,excluded,groups,sources)
	for key in groups:
		var group: Dictionary = groups[key]
		var merged := MeshInstance3D.new()
		merged.name = "StaticProps"
		merged.mesh = group.surface.commit()
		merged.material_override = group.material
		merged.cast_shadow = group.shadow
		station.add_child(merged)
	for source in sources:
		source.hide()
	print("STATIC BATCH: %d source meshes -> %d spatial batches" % [sources.size(),groups.size()])

static func collect(node: Node, station: Node3D, excluded: Array[Node], groups: Dictionary, sources: Array[MeshInstance3D]) -> void:
	if node in excluded:
		return
	if node is MeshInstance3D and node.is_visible_in_tree() and node.mesh != null and node.mesh.get_surface_count() == 1:
		var material: Material = node.material_override if node.material_override else node.mesh.surface_get_material(0)
		if material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			var transform: Transform3D = station.global_transform.affine_inverse() * node.global_transform
			var cell := Vector2i(floori(transform.origin.x/3.0),floori(transform.origin.z/3.0))
			var key := "%d/%s/%d" % [material.get_instance_id(),str(cell),node.cast_shadow]
			if not groups.has(key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"surface":surface,"material":material,"shadow":node.cast_shadow}
			# Primitive meshes are indexed, bevel meshes are not. Normalize first:
			# mixing the two directly would leave unindexed triangles out of the batch.
			var normalized := SurfaceTool.new()
			normalized.create_from(node.mesh,0)
			normalized.deindex()
			groups[key].surface.append_from(normalized.commit(),0,transform)
			sources.append(node)
	for child in node.get_children():
		collect(child,station,excluded,groups,sources)
