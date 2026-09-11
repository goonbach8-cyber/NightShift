extends Node3D
## Visual layer for the existing store. Gameplay bodies and interaction roots stay intact.

var materials: Dictionary = {}
var station: Node3D

func _ready() -> void:
	station = get_parent()
	name = "StationDressing"
	var room := station.get_node("../PrototypeRoom")
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://scenes/levels/shop_floor.gdshader")
	room.get_node("Floor/MeshInstance3D").material_override = floor_material
	for wall in ["NorthWall", "EastWall", "WestWall"]:
		room.get_node(wall + "/MeshInstance3D").material_override = mat("a2a499")
	# Replace floating labels with signs attached to the fittings.
	for child in station.get_children():
		if child is Label3D:
			child.hide()
		if child is OmniLight3D:
			child.light_energy *= 0.45
	for key in ["ShiftBoard", "Cooler", "Shelf", "Register"]:
		for child in station.get_node(key).get_children():
			if child is Label3D:
				child.hide()
	architecture()
	shop_fittings()
	entrance()
	forecourt()

func mat(hex: String, glow: bool = false) -> StandardMaterial3D:
	var key := hex + str(glow)
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.72
		if glow:
			m.emission_enabled = true
			m.emission = Color(hex)
			m.emission_energy_multiplier = 1.2
		materials[key] = m
	return materials[key]

func box(at: Vector3, size: Vector3, color: String, parent: Node3D = self, glow: bool = false) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = mat(color, glow)
	item.position = at
	parent.add_child(item)
	return item

func cylinder(at: Vector3, radius: float, height: float, color: String, parent: Node3D = self) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	item.mesh = mesh
	item.material_override = mat(color)
	item.position = at
	parent.add_child(item)
	return item

func sign_text(text: String, at: Vector3, width: float, parent: Node3D = self, color: String = "dce7da") -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = width / maxf(text.length() * 28.0, 1.0)
	label.position = at
	label.modulate = Color(color)
	label.outline_size = 0
	parent.add_child(label)

func lamp(at: Vector3, warm: bool = true, shadows: bool = false) -> void:
	box(at, Vector3(1.5,0.10,0.28), "667a78").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(at + Vector3(0,0,0.15), Vector3(1.35,0.05,0.025), "cfdfcf", self, true)
	box(at + Vector3(0,-0.065,0), Vector3(1.35,0.04,0.21), "ffe7be" if warm else "b1e4e7", self, true)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0,-0.25,0)
	light.light_color = Color("ffdeb0" if warm else "a1dce5")
	light.light_energy = 1.05
	light.omni_range = 5.5
	light.shadow_enabled = shadows
	add_child(light)

func architecture() -> void:
	box(Vector3(0,0.12,-4.82),Vector3(13.7,0.24,0.08),"344b4b")
	box(Vector3(0,1.2,-4.82),Vector3(13.7,0.08,0.08),"317874")
	for x in [-6.82,6.82]:
		box(Vector3(x,0.12,0),Vector3(0.08,0.24,9.7),"344b4b")
		box(Vector3(x,1.2,0),Vector3(0.08,0.08,9.7),"317874")
	box(Vector3(0,1.61,-4.78),Vector3(3.9,0.61,0.09),"173d40")
	sign_text("NIGHTSHIFT / 24 H",Vector3(0,1.64,-4.72),3.3,self,"99ddd2")
	for x in [-4.5,0.0,4.5]:
		lamp(Vector3(x,2.65,-2.6),x >= 0,x == 0)
	lamp(Vector3(4.6,2.65,2.3),true,true)
	lamp(Vector3(-4.8,2.5,2.5))
	# Narrow display islands leave the centre and perimeter routes open.
	for x in [-2.6,2.6]:
		var body := StaticBody3D.new()
		body.position = Vector3(x,0,-1.8)
		add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.3,0.95,1.55)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 0.475
		body.add_child(collision)
		box(Vector3(0,0.13,0),Vector3(1.3,0.26,1.55),"253b3d",body)
		box(Vector3(0,0.56,0),Vector3(1.2,0.85,0.12),"556862",body)
		for y in [0.3,0.75]:
			box(Vector3(0,y,0),Vector3(1.3,0.07,1.55),"b4b3a0",body)
			for side in [-0.5,0.5]:
				for i in 4:
					var px := -0.46 + i * 0.30
					box(Vector3(px,y+0.17,side),Vector3(0.19,0.27,0.21),["a97344","beaa70","557b69","965647"][i],body)
					box(Vector3(px,y+0.18,side+0.112),Vector3(0.13,0.09,0.012),"d7cdb0",body)
		box(Vector3(0,1.0,0),Vector3(1.3,0.11,0.18),"246463",body)
		sign_text("SNACKS" if x < 0 else "UNTERWEGS",Vector3(0,1.02,0.10),1.0,body)

func shop_fittings() -> void:
	var cooler := station.get_node("Cooler")
	cooler.get_node("Glass").get_child(0).hide()
	for x in [-0.67,0.0,0.67]:
		box(Vector3(x,0.92,0.47),Vector3(0.045,1.22,0.08),"9caaa5",cooler)
	for y in [0.4,0.8,1.2]:
		box(Vector3(0,y,0.46),Vector3(1.3,0.035,0.1),"bcc7be",cooler)
		for i in 7:
			cylinder(Vector3(-0.54+i*0.18,y+0.13,0.45),0.05,0.23,["a0b7a1","c5944f","7ba6a3"][i%3],cooler)
	for x in [-0.60,0.60]:
		box(Vector3(x,0.95,0.54),Vector3(0.022,1.03,0.025),"b6efea",cooler,true)
	box(Vector3(0,1.67,0.1),Vector3(1.5,0.18,0.78),"1a4b50",cooler)
	sign_text("KALT / 4 °C",Vector3(0,1.67,0.51),1.15,cooler)
	var shelf := station.get_node("Shelf")
	for x in [-0.86,0.86]:
		box(Vector3(x,0.72,0),Vector3(0.055,1.42,0.65),"a3aaa0",shelf)
	for item in shelf.get_children():
		if item is StaticBody3D and str(item.name).begins_with("Stock"):
			box(Vector3(0,0.01,0.105),Vector3(0.13,0.10,0.01),"ddd4b3",item)
	box(Vector3(0,1.5,0),Vector3(1.8,0.19,0.66),"286663",shelf)
	sign_text("GETRÄNKE",Vector3(0,1.5,0.34),1.4,shelf)
	var till := station.get_node("Register")
	box(Vector3(0,1.02,0),Vector3(1.94,0.08,1.04),"adb0a1",till)
	box(Vector3(0,0.17,0.46),Vector3(1.8,0.19,0.04),"253b3b",till)
	for x in [-0.72,-0.36,0.0,0.36,0.72]:
		box(Vector3(x,0.6,0.46),Vector3(0.025,0.64,0.03),"ab9977",till)
	box(Vector3(0,1.23,0.21),Vector3(0.36,0.16,0.025),"7ac4ac",till,true)
	box(Vector3(0,1.1,0.31),Vector3(0.4,0.03,0.19),"172b2c",till)
	box(Vector3(0.64,1.12,0),Vector3(0.23,0.17,0.22),"3d4c4d",till)
	sign_text("KASSE",Vector3(0,0.73,0.487),0.65,till)
	# Coffee unit against the back wall, outside all existing task approaches.
	solid(Vector3(0,0.46,-4.18), Vector3(2.0,0.92,0.9))
	box(Vector3(0,0.46,-4.18),Vector3(2.0,0.92,0.9),"52625c")
	box(Vector3(0,0.94,-4.18),Vector3(2.1,0.08,0.96),"b5b5a4")
	box(Vector3(-0.36,1.25,-4.15),Vector3(0.65,0.58,0.53),"263739")
	box(Vector3(-0.36,1.35,-3.87),Vector3(0.30,0.12,0.02),"aed1b3",self,true)
	box(Vector3(-0.36,1.05,-3.82),Vector3(0.48,0.04,0.25),"8e9b94")
	for x in [0.22,0.47,0.72]:
		cylinder(Vector3(x,1.06,-4.0),0.08,0.2,"ddd3b6")
	sign_text("KAFFEE / 24 H",Vector3(0,1.08,-3.68),1.45)
	var board := station.get_node("ShiftBoard")
	box(Vector3(0,0.91,0),Vector3(1.28,0.045,0.78),"b5a586",board)
	box(Vector3(-0.16,0.947,0),Vector3(0.018,0.015,0.29),"304d51",board)
	cylinder(Vector3(0.40,1.02,-0.15),0.075,0.18,"c7c2a7",board)
	sign_text("PERSONAL",Vector3(0,0.68,0.365),0.86,board)
	solid(Vector3(-6.05,0.3,3.7), Vector3(0.5,0.6,0.5))
	cylinder(Vector3(-6.05,0.3,3.7),0.25,0.6,"364c4c")
	cylinder(Vector3(-6.05,0.61,3.7),0.27,0.035,"182b2e")
	# A framed notice has a physical mount instead of floating UI text.
	box(Vector3(-2.5,1.3,-4.77),Vector3(0.64,0.9,0.07),"344443")
	box(Vector3(-2.5,1.3,-4.72),Vector3(0.56,0.82,0.02),"c5b084")
	sign_text("NACHT\nKAFFEE\n2.50",Vector3(-2.5,1.32,-4.70),1.25,self,"314442")

func entrance() -> void:
	box(Vector3(0,0.012,3.9),Vector3(2.4,0.025,1.45),"283637")
	for i in 11:
		box(Vector3(0,0.027,3.3+i*0.12),Vector3(2.25,0.009,0.018),"52615d")
	for x in [-1.13,1.13]:
		box(Vector3(x,0.8,5),Vector3(0.09,1.6,0.22),"8a9d97")
	var panel := station.get_node("Door/Panel")
	for x in [-1.05,1.05]:
		box(Vector3(x,0.75,0.105),Vector3(0.055,1.5,0.04),"9bab9f",panel)
	box(Vector3(0,0.75,0.105),Vector3(2.1,0.07,0.04),"5b9894",panel)
	sign_text("24 H / EINGANG",Vector3(0,1.05,0.12),1.4,panel)
	for x in [-4.075,4.075]:
		box(Vector3(x,0.72,5),Vector3(5.85,0.05,0.38),"80928a")
		for offset in [-2.4,-0.8,0.8,2.4]:
			box(Vector3(x+offset,0.37,5.17),Vector3(0.035,0.62,0.025),"587372")

func forecourt() -> void:
	# Visual ground beyond the retained collision boundary closes the black void.
	box(Vector3(0,-0.22,5),Vector3(35,0.08,32),"101b22")
	box(Vector3(-3.8,0.035,8.3),Vector3(1.7,0.07,1.6),"747b73")
	for x in [-4.45,-3.15]:
		cylinder(Vector3(x,0.4,8.95),0.065,0.8,"b7a15b")
	box(Vector3(-3.8,0.45,8.72),Vector3(0.9,0.36,0.035),"296f70")
	box(Vector3(-3.8,1.68,8.3),Vector3(1.06,0.17,0.88),"296f70")
	sign_text("01 / DIESEL",Vector3(-3.8,1.67,8.76),0.86)
	sign_text("1.829",Vector3(-3.8,1.12,8.765),0.48,self,"acdfbc")
	for i in 9:
		var angle := PI * i / 8.0
		cylinder(Vector3(-3.2+sin(angle)*0.19,1.24-i*0.085,8.65),0.035,0.12,"172529")
	for x in [1.8,4.8]:
		box(Vector3(x,0.009,8.4),Vector3(0.07,0.018,3.4),"b4b2a0")
	box(Vector3(3.3,0.009,9.95),Vector3(3.0,0.018,0.07),"b4b2a0")
	for x in [-5.5,5.5]:
		box(Vector3(x,3.3,8.5),Vector3(0.7,0.10,0.4),"33484d")
		box(Vector3(x,3.23,8.5),Vector3(0.62,0.035,0.32),"c4efeb",self,true)

func solid(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)