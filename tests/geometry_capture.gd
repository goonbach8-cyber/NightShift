extends SceneTree
## Exports actual visible triangles projected by Godot's game camera.
## A software diagnostic image is NOT a capture of Godot lighting or materials.
var world: Node3D
var camera: Camera3D
var output := "C:/Users/e558926/Documents/Codex/2026-09-10/du-arbeitest-direkt-an-meinem-lokalen/outputs/geometry/"

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.player.set_physics_process(false)
	world.gameplay.inventory.initialize_shelves()
	for id in world.gameplay.inventory.stocks:
		world.gameplay.inventory.stocks[id].shelf_units = world.gameplay.inventory.stocks[id].capacity
		world.gameplay.inventory.stocks[id].changed.emit()
	camera = world.player.get_node("CameraRig/Camera3D")
	DirAccess.make_dir_recursive_absolute(output)
	await create_timer(0.1).timeout
	for view in [
		["interior",Vector3(0,0,0),16.0],
		["checkout",Vector3(4.6,0,2.0),8.5],
		["shelves",Vector3(4.8,0,-3.6),8.5],
		["cooler",Vector3(-4.8,0,-3.6),8.5],
		["entrance",Vector3(0,0,5),8.5],
		["existing_road",Vector3(3,0,13),22.0]]:
		capture(view[0],view[1],view[2])
	world.gameplay.career_shifts = 2
	world.gameplay.configure_night(preload("res://scripts/night_catalog.gd").for_night(3))
	world.gameplay.story_flags[&"road_exists"] = true
	world.gameplay.story_flags[&"crack_exists"] = true
	var prop = world.layout.warehouse.get_node("Supply/LooseCarton")
	prop.apply_state()
	await create_timer(1).timeout
	capture("new_junction",Vector3(5,0,17),23)
	capture("night3_aftermath",Vector3(8.5,0,-3),8.5)
	world.gameplay.career_shifts = 4
	world.gameplay.configure_night(preload("res://scripts/night_catalog.gd").for_night(5))
	await create_timer(0.1).timeout
	capture("construction",Vector3(3,0,16),16)
	world.gameplay.career_shifts = 5
	world.gameplay.configure_night(preload("res://scripts/night_catalog.gd").for_night(6))
	await create_timer(0.1).timeout
	capture("redwater",Vector3(3,0,7),24)
	world.queue_free()
	await create_timer(0.2).timeout
	print("GEOMETRY EXPORT COMPLETE")
	quit()

func capture(id: String, focus: Vector3, width: float) -> void:
	camera.global_position = world.to_global(focus+Vector3(0,7,6.5))
	camera.look_at(world.to_global(focus))
	camera.size = width
	var triangles: Array = []
	collect(world,triangles)
	var file := FileAccess.open(output+id+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"name":id,"width":1280,"height":720,"triangles":triangles}))
	file.close()
	print("GEOMETRY VIEW: ",id," / ",triangles.size()," triangles")

func collect(node: Node, triangles: Array) -> void:
	if node is Node3D and not node.is_visible_in_tree(): return
	if node is MeshInstance3D and node.mesh != null:
		for surface_index in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface_index)
			if arrays.is_empty(): continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var material: Material = node.get_active_material(surface_index)
			var color := Color("858f89")
			if material is BaseMaterial3D: color = material.albedo_color
			var length: int = indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0,length-2,3):
				var points: Array[Vector3] = []
				for j in 3: points.append(node.global_transform*vertices[indices[i+j] if not indices.is_empty() else i+j])
				if points.any(func(v): return camera.is_position_behind(v)): continue
				var projected: Array = []
				var bounds := Rect2(camera.unproject_position(points[0]),Vector2.ZERO)
				for v in points:
					var screen := camera.unproject_position(v)
					bounds = bounds.expand(screen)
					projected.append([screen.x,screen.y,-camera.to_local(v).z])
				if not bounds.intersects(Rect2(0,0,1280,720)): continue
				var normal := (points[1]-points[0]).cross(points[2]-points[0]).normalized()
				var lighting: float = 0.40+0.6*absf(normal.dot(Vector3(-0.3,0.85,0.4).normalized()))
				triangles.append([projected,[color.r*lighting,color.g*lighting,color.b*lighting,color.a]])
	for child in node.get_children(): collect(child,triangles)
