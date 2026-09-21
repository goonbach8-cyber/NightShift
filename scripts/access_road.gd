extends Node3D
## A real branch road: the first metres overlap the established carriageway,
## then the road narrows and bends away. It must never read as a parallel copy.
var centers := PackedVector2Array([
	Vector2(0.0,0.0),
	Vector2(0.0,1.0),
	Vector2(0.15,2.1),
	Vector2(0.55,3.2),
	Vector2(1.25,4.25),
	Vector2(2.25,5.15),
	Vector2(3.55,5.9),
	Vector2(5.0,6.5),
	Vector2(6.6,6.95),
	Vector2(8.2,7.25)
])
var surface: MeshInstance3D
var gate: StaticBody3D
var gate_visual: Node3D
var road_floor: StaticBody3D
var model = preload("res://scripts/product_display.gd").new()

func _ready() -> void:
	add_child(model)
	var strip := SurfaceTool.new()
	strip.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(centers.size()-1):
		var a := edge(i,-1)
		var b := edge(i,1)
		var c := edge(i+1,-1)
		var d := edge(i+1,1)
		for vertex in [a,b,c,b,d,c]:
			strip.add_vertex(vertex)
	strip.generate_normals()
	surface = MeshInstance3D.new()
	surface.name = "BranchCarriageway"
	surface.mesh = strip.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("20272d")
	material.roughness = 0.97
	surface.material_override = material
	add_child(surface)

	road_floor = StaticBody3D.new()
	road_floor.name = "RoadSurface"
	var collision := CollisionShape3D.new()
	collision.shape = surface.mesh.create_trimesh_shape()
	road_floor.add_child(collision)
	add_child(road_floor)

	# Edge paint starts after the mouth so it visually merges into the old road.
	for side in [-1,1]:
		for i in range(2,centers.size()-1):
			line(edge(i,side)+Vector3(0,0.009,0),edge(i+1,side)+Vector3(0,0.009,0),0.065,Color("b8b7a6"))
	# Sparse centre dashes make the branch direction immediately readable.
	for i in range(2,centers.size()-1,2):
		var a := center3(i)
		var b := center3(i+1)
		line(a.lerp(b,0.24)+Vector3(0,0.012,0),a.lerp(b,0.72)+Vector3(0,0.012,0),0.055,Color("d4d0b8"))
	# Gravel shoulders hug the branch instead of forming a second rectangular road slab.
	for side in [-1,1]:
		for i in range(2,centers.size()-1):
			var a := edge(i,side)
			var b := edge(i+1,side)
			var outward_a := (a-center3(i)).normalized()
			var outward_b := (b-center3(i+1)).normalized()
			line(a+outward_a*0.24-Vector3(0,0.025,0),b+outward_b*0.24-Vector3(0,0.025,0),0.42,Color("39413d"))

	# The gate sits well beyond the junction. The mouth itself stays visibly connected.
	var gate_index := 5
	gate = StaticBody3D.new()
	gate.name = "AccessGate"
	gate.position = center3(gate_index)+Vector3(0,0.55,0)
	gate.rotation.y = road_angle(gate_index)
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.45,1.1,0.12)
	var blocker := CollisionShape3D.new()
	blocker.shape = shape
	gate.add_child(blocker)
	add_child(gate)
	gate_visual = Node3D.new()
	gate_visual.position = gate.position
	gate_visual.rotation.y = gate.rotation.y
	add_child(gate_visual)
	for x in [-2.15,2.15]:
		model.box(gate_visual,Vector3(x,-0.05,0),Vector3(0.12,1,0.12),Color("7d8983"))
	model.box(gate_visual,Vector3(0,0.30,0),Vector3(4.3,0.09,0.09),Color("b3b9ad"))
	model.box(gate_visual,Vector3(0,0.05,0),Vector3(4.3,0.05,0.06),Color("64716b"))

	# A low kerb makes the compact route end intentionally rather than at an invisible edge.
	line(edge(centers.size()-1,-1),edge(centers.size()-1,1),0.18,Color("73786d"))

func center3(index: int) -> Vector3:
	return Vector3(centers[index].x,-0.02,centers[index].y)

func tangent_at(index: int) -> Vector2:
	var previous := centers[maxi(index-1,0)]
	var following := centers[mini(index+1,centers.size()-1)]
	return (following-previous).normalized()

func road_angle(index: int) -> float:
	var tangent := tangent_at(index)
	return atan2(tangent.x,tangent.y)

func edge(index: int, side: int) -> Vector3:
	var tangent := tangent_at(index)
	var normal := Vector2(-tangent.y,tangent.x)
	# A flared mouth overlaps the existing carriageway and then narrows to a normal lane.
	var half_width := 3.4 if index == 0 else (3.0 if index == 1 else (2.55 if index == 2 else 2.2))
	var p := centers[index]+normal*half_width*side
	return Vector3(p.x,-0.02,p.y)

func line(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var item := model.box(self,(a+b)/2,Vector3(width,0.012,a.distance_to(b)),color)
	item.rotation.y = atan2((b-a).x,(b-a).z)

func set_open(value: bool) -> void:
	gate.collision_layer = 0 if value else 1
	gate_visual.visible = not value
	road_floor.collision_layer = 1 if visible else 0
