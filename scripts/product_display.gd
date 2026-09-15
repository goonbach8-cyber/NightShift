extends Node3D
## Product-independent stock binding; geometry is chosen by display configuration.
var stock: Resource
var slots: Array[Node3D] = []

func bind(item: Resource, kind: String, count: int, origin: Vector3, spacing: Vector3) -> void:
	stock = item
	for i in count:
		var slot := Node3D.new()
		add_child(slot)
		slot.position = origin + Vector3((i % 3) * spacing.x, floori(float(i) / 3.0) * spacing.y, 0)
		slots.append(slot)
		match kind:
			"can":
				var can := CylinderMesh.new()
				can.top_radius = 0.075
				can.bottom_radius = 0.075
				can.height = 0.25
				can.radial_segments = 12
				part(slot, can, Vector3.ZERO, Color("439d8d"))
				for y in [-0.125, 0.125]:
					var rim := CylinderMesh.new()
					rim.top_radius = 0.08
					rim.bottom_radius = 0.08
					rim.height = 0.012
					part(slot, rim, Vector3(0,y,0), Color("b8c8c4"))
				box(slot, Vector3(0,0,0.075), Vector3(0.06,0.16,0.01), Color("f0d461"))
			"bag":
				var bag := PrismMesh.new()
				bag.size = Vector3(0.26,0.31,0.18)
				part(slot, bag, Vector3.ZERO, Color("c97435"))
				for y in [-0.15,0.15]: box(slot, Vector3(0,y,0), Vector3(0.28,0.025,0.1), Color("e9b356"))
				box(slot, Vector3(0,-0.015,0.095), Vector3(0.18,0.10,0.01), Color("f2db9b"))
	stock.changed.connect(sync)
	sync()

func sync() -> void:
	for i in slots.size(): slots[i].visible = i < stock.shelf_units

func part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	visual.material_override = material
	parent.add_child(visual)

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	part(parent,mesh,at,color)
