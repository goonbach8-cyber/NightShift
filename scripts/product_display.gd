extends Node3D
## Product-independent stock binding; geometry is chosen by display configuration.
var stock: Resource
var slots: Array[Node3D] = []

func bind(item: Resource, kind: String, count: int, origin: Vector3, spacing: Vector3, columns: int = 3) -> void:
	stock = item
	var row_width := maxi(1,columns)
	for i in count:
		var slot := Node3D.new()
		add_child(slot)
		slot.position = origin + Vector3((i % row_width) * spacing.x, floori(float(i) / row_width) * spacing.y, 0)
		slots.append(slot)
		match kind:
			"can":
				energy_can(slot,Vector3.ZERO)
			"bag":
				chip_packet(slot,Vector3.ZERO)
	stock.changed.connect(sync)
	sync()

func energy_can(parent: Node3D, at: Vector3) -> void:
	var can := CylinderMesh.new()
	can.top_radius = 0.075
	can.bottom_radius = 0.075
	can.height = 0.25
	can.radial_segments = 12
	part(parent,can,at,Color("439d8d"))
	var rim := CylinderMesh.new()
	rim.top_radius = 0.08
	rim.bottom_radius = 0.08
	rim.height = 0.012
	for y in [-0.125,0.125]:
		part(parent,rim,at+Vector3(0,y,0),Color("b8c8c4"))
	box(parent,at+Vector3(0,0.133,0.012),Vector3(0.038,0.006,0.051),Color("6e807b"))
	box(parent,at+Vector3(0,0,0.073),Vector3(0.061,0.156,0.014),Color("e1c760"))
	box(parent,at+Vector3(0,0.026,0.081),Vector3(0.045,0.021,0.003),Color("224941"))
	box(parent,at+Vector3(0,-0.047,0.081),Vector3(0.036,0.009,0.003),Color("224941"))

func chip_packet(parent: Node3D, at: Vector3) -> void:
	var bag := CapsuleMesh.new()
	bag.radius = 0.13
	bag.height = 0.30
	bag.radial_segments = 8
	bag.rings = 3
	part(parent,bag,at,Color("bd6636")).scale.z = 0.62
	for y in [-0.152,0.152]:
		box(parent,at+Vector3(0,y,0),Vector3(0.255,0.024,0.092),Color("e5ad52"))
	for side in [-1,1]:
		box(parent,at+Vector3(side*0.108,0,0),Vector3(0.036,0.285,0.068),Color("bd6636"))
	box(parent,at+Vector3(0,0.011,0.074),Vector3(0.152,0.127,0.024),Color("e5ad52"))
	box(parent,at+Vector3(0,0.032,0.088),Vector3(0.116,0.036,0.004),Color("773c2d"))
	box(parent,at+Vector3(0,-0.022,0.088),Vector3(0.068,0.028,0.004),Color("efda9a"))

func sync() -> void:
	for i in slots.size(): slots[i].visible = i < stock.shelf_units

func part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	visual.material_override = material
	parent.add_child(visual)
	return visual

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return part(parent,mesh,at,color)
