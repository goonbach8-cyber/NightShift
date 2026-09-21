extends Node3D
## One continuous strip leaves the south edge of the existing carriageway.
## Local origin is the junction mouth, not an arbitrary copy beside the shop.
var centers := PackedVector2Array([Vector2(0,0),Vector2(0.05,1),Vector2(0.4,2.2),Vector2(1.1,3.4),Vector2(2.2,4.5),Vector2(3.5,5.3),Vector2(5,5.9),Vector2(6.5,6.4)])
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
		for v in [a,b,c,b,d,c]: strip.add_vertex(v)
	strip.generate_normals()
	surface = MeshInstance3D.new()
	surface.name = "ConnectedCarriageway"
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
	for side in [-1,1]:
		for i in range(1,centers.size()-1):
			line(edge(i,side)+Vector3(0,0.008,0),edge(i+1,side)+Vector3(0,0.008,0),0.065,Color("b8b7a6"))
	# Ordinary locked service access, opened on the depot night.
	gate = StaticBody3D.new()
	gate.name = "AccessGate"
	gate.position = Vector3(0,0.55,0.65)
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.8,1.1,0.12)
	var blocker := CollisionShape3D.new()
	blocker.shape = shape
	gate.add_child(blocker)
	add_child(gate)
	gate_visual = Node3D.new()
	add_child(gate_visual)
	for x in [-2.9,2.9]:
		model.box(gate_visual,Vector3(x,0.5,0.65),Vector3(0.12,1,0.12),Color("7d8983"))
	model.box(gate_visual,Vector3(0,0.85,0.65),Vector3(5.8,0.09,0.09),Color("b3b9ad"))
	model.box(gate_visual,Vector3(0,0.6,0.65),Vector3(5.8,0.05,0.06),Color("64716b"))
	# Ground extent is also a navigation bound. It sits below the road surface.
	var ground := StaticBody3D.new()
	ground.name = "RoadShoulder"
	ground.position = Vector3(3,-0.16,4)
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(14,0.2,9)
	var ground_collision := CollisionShape3D.new()
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)
	add_child(ground)
	model.box(self,ground.position,ground_shape.size,Color("25312e"))
	# Concrete end stop prevents walking beyond the compact playable route.
	line(edge(centers.size()-1,-1),edge(centers.size()-1,1),0.18,Color("73786d"))

func edge(index: int, side: int) -> Vector3:
	var tangent := Vector2(0,1) if index == 0 else (centers[mini(index+1,centers.size()-1)]-centers[index-1]).normalized()
	var normal := Vector2(-tangent.y,tangent.x)
	var half_width := 2.9 if index == 0 else (2.5 if index == 1 else 2.1)
	var p := centers[index]+normal*half_width*side
	return Vector3(p.x,-0.02,p.y)

func line(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var item := model.box(self,(a+b)/2,Vector3(width,0.012,a.distance_to(b)),color)
	item.rotation.y = atan2((b-a).x,(b-a).z)

func set_open(value: bool) -> void:
	gate.collision_layer = 0 if value else 1
	gate_visual.visible = not value
	road_floor.collision_layer = 1 if visible else 0
