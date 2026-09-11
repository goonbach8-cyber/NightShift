extends Node3D

const INTERACTABLE = preload("res://scenes/interactions/interactable.gd")
const DOOR = preload("res://scenes/interactions/door.tscn")

var restock_items: Array[Node3D] = []


func _ready() -> void:
	# Extend the existing room; its floor and three walls stay in use.
	var south := get_node("../PrototypeRoom/SouthWall")
	south.get_node("MeshInstance3D").visible = false
	south.get_node("CollisionShape3D").disabled = true
	_box(self, "FrontLeft", Vector3(-4.075, 0.35, 5), Vector3(5.85, 0.7, 0.3), Color("303b43"))
	_box(self, "FrontRight", Vector3(4.075, 0.35, 5), Vector3(5.85, 0.7, 0.3), Color("303b43"))
	var door := DOOR.instantiate()
	door.name = "Door"
	door.position = Vector3(0, 0, 5)
	add_child(door)
	_box(self, "Forecourt", Vector3(0, -0.15, 8), Vector3(14, 0.3, 6), Color("20272d"))
	_box(self, "SouthBoundary", Vector3(0, 0.3, 11), Vector3(14.3, 0.6, 0.3), Color("394148"))
	_box(self, "WestBoundary", Vector3(-7, 0.3, 8), Vector3(0.3, 0.6, 6), Color("394148"))
	_box(self, "EastBoundary", Vector3(7, 0.3, 8), Vector3(0.3, 0.6, 6), Color("394148"))
	_box(self, "Pump", Vector3(-3.8, 0.8, 8.3), Vector3(1.0, 1.6, 0.8), Color("afada1"))
	_box(self, "PumpDisplay", Vector3(-3.8, 1.1, 8.72), Vector3(0.7, 0.36, 0.05), Color("172d2d"), false)
	_label(self, "01  /  DIESEL", Vector3(-3.8, 1.55, 8.8), 20, Color("9edbcf"))
	for x in [-5.5, 5.5]:
		_box(self, "LightPost", Vector3(x, 1.7, 8.5), Vector3(0.12, 3.4, 0.12), Color("526064"))
		_light(Vector3(x, 3.0, 8.5), Color("81c8cb"), 2.0, 6.5)
	_light(Vector3(-2, 3, -1), Color("ffdbac"), 2.2, 8)
	_light(Vector3(3, 2.7, 2), Color("ffdbac"), 1.8, 6)
	_label(self, "NIGHTSHIFT  /  24 H", Vector3(0, 1.9, -4.7), 40, Color("94d8d1"))
	var board := _object("ShiftBoard", &"start", "Schichtzettel lesen", Vector3(-4.8, 0, 2.5))
	_box(board, "Desk", Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.7), Color("574e43"))
	_box(board, "Paper", Vector3(0, 0.92, 0), Vector3(0.5, 0.03, 0.4), Color("ded4ac"), false)
	_label(board, "SCHICHTZETTEL", Vector3(0, 1.4, 0), 22, Color("e6dab7"))
	var cooler := _object("Cooler", &"cooler", "Kühltemperatur prüfen", Vector3(-4.8, 0, -3.6))
	_box(cooler, "Body", Vector3(0, 0.8, 0), Vector3(1.5, 1.6, 0.8), Color("4b666d"))
	_box(cooler, "Glass", Vector3(0, 0.9, 0.43), Vector3(1.25, 1.1, 0.06), Color("203b40"), false)
	_label(cooler, "KÜHLUNG  /  4 °C", Vector3(0, 1.9, 0), 22, Color("a6d8d0"))
	var shelf := _object("Shelf", &"shelf", "Getränke auffüllen", Vector3(4.8, 0, -3.6))
	_box(shelf, "Back", Vector3(0, 0.65, -0.25), Vector3(1.8, 1.3, 0.2), Color("424e50"))
	for y in [0.15, 0.65, 1.15]:
		_box(shelf, "Shelf", Vector3(0, y, 0), Vector3(1.8, 0.09, 0.65), Color("69736b"))
		for x in [-0.6, -0.2, 0.2, 0.6]:
			var stock := _box(shelf, "Stock", Vector3(x, y + 0.18, 0), Vector3(0.16, 0.27, 0.2), Color("947353"), false)
			if y > 0.2:
				stock.hide()
				restock_items.append(stock)
	_label(shelf, "GETRÄNKE", Vector3(0, 1.7, 0), 22, Color("e6dab7"))
	var till := _object("Register", &"finish", "Kontrollrunde abschliessen", Vector3(4.6, 0, 2.3))
	_box(till, "Counter", Vector3(0, 0.5, 0), Vector3(1.8, 1, 0.9), Color("675d4d"))
	_box(till, "Terminal", Vector3(0, 1.14, 0), Vector3(0.5, 0.28, 0.4), Color("263d3c"))
	_label(till, "KASSE", Vector3(0, 1.65, 0), 22, Color("e6dab7"))
	var dressing := Node3D.new()
	dressing.set_script(preload("res://scenes/levels/station_dressing.gd"))
	add_child(dressing)
	var annex := Node3D.new()
	annex.name = "ServiceAnnex"
	annex.set_script(preload("res://scenes/levels/service_annex.gd"))
	add_child(annex)
	preload("res://scripts/static_prop_batch.gd").build(self)


func _object(node_name: String, id: StringName, text: String, at: Vector3) -> Node3D:
	var object := Node3D.new()
	object.set_script(INTERACTABLE)
	object.name = node_name
	object.action_id = id
	object.prompt = text
	object.position = at
	add_child(object)
	return object


func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, color: Color, solid: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return body


func complete_restock() -> void:
	for item in restock_items:
		item.show()
	$Shelf.prompt = "Regal ansehen"


func _label(parent: Node3D, text: String, at: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.005
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _light(at: Vector3, color: Color, energy: float, distance: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = distance
	add_child(light)
