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
	object_details()
	finishing_details()

func mat(hex: String, glow: bool = false) -> StandardMaterial3D:
	var key := hex + str(glow)
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.72
		if hex in ["9caaa5", "8e9b94", "bcc7be", "a3aaa0", "8a9d97"]:
			m.metallic = 0.65
			m.roughness = 0.32
		elif hex in ["263739", "172b2c", "263d3c", "3d4c4d"]:
			m.roughness = 0.43
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
	# A visible bracket anchors each cutaway ceiling fixture to the nearest wall.
	if at.z < -3.0:
		box(Vector3(at.x,at.y,-4.62),Vector3(0.065,0.08,0.45),"8e9b94")
	else:
		var edge := 6.80 if at.x > 0 else -6.80
		box(Vector3((edge+at.x)*0.5,at.y,at.z),Vector3(absf(edge-at.x),0.055,0.07),"8e9b94")
		box(Vector3(edge,at.y-0.18,at.z),Vector3(0.08,0.4,0.12),"344b4b")

func architecture() -> void:
	box(Vector3(0,0.12,-4.82),Vector3(13.7,0.24,0.08),"344b4b")
	box(Vector3(0,1.2,-4.82),Vector3(13.7,0.08,0.08),"317874")
	for x in [-6.82,6.82]:
		box(Vector3(x,0.12,0),Vector3(0.08,0.24,9.7),"344b4b")
		box(Vector3(x,1.2,0),Vector3(0.08,0.08,9.7),"317874")
	box(Vector3(0,1.61,-4.78),Vector3(3.9,0.61,0.09),"173d40")
	sign_text("NIGHTSHIFT / 24 H",Vector3(0,1.64,-4.72),3.3,self,"99ddd2")
	for x in [-4.5,0.0,4.5]:
		lamp(Vector3(x,2.35,-4.40),x >= 0,x == 0)
	lamp(Vector3(4.6,2.5,1.35),true,true)
	lamp(Vector3(-4.8,2.35,1.6))
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
					package(Vector3(px,y+0.17,side),i,body)
				box(Vector3(0,y+0.025,side*1.5),Vector3(1.28,0.085,0.025),"344b4b",body)
				for px in [-0.45,0.0,0.45]:
					box(Vector3(px,y+0.025,side*1.53),Vector3(0.18,0.045,0.012),"ddd4b3",body)
		box(Vector3(0,1.0,0),Vector3(1.3,0.11,0.18),"246463",body)
		sign_text("SNACKS" if x < 0 else "UNTERWEGS",Vector3(0,1.02,0.10),1.0,body)

func shop_fittings() -> void:
	var cooler := station.get_node("Cooler")
	cooler.get_node("Glass").get_child(0).hide()
	cooler.get_node("Body").get_child(0).hide()
	box(Vector3(0,0.88,-0.32),Vector3(1.48,1.5,0.12),"172b2c",cooler)
	for x in [-0.70,0.70]:
		bevel(Vector3(x,0.85,0),Vector3(0.1,1.6,0.8),"9caaa5",cooler)
	bevel(Vector3(0,0.17,0),Vector3(1.5,0.34,0.8),"263739",cooler)
	for y in [0.10,0.16,0.22]:
		box(Vector3(0,y,0.408),Vector3(1.28,0.018,0.016),"8e9b94",cooler)
	for x in [-0.67,0.0,0.67]:
		box(Vector3(x,0.92,0.47),Vector3(0.045,1.22,0.08),"9caaa5",cooler)
	for y in [0.4,0.8,1.2]:
		box(Vector3(0,y,0.07),Vector3(1.3,0.035,0.68),"bcc7be",cooler)
		for i in 7:
			bottle(Vector3(-0.54+i*0.18,y+0.13,0.27),["557b69","b58c45","577d90"][i%3],cooler,0.8)
	for x in [-0.08,0.08]:
		bevel(Vector3(x,0.94,0.57),Vector3(0.035,0.39,0.05),"bcc7be",cooler)
	# Subtle glass panes stay behind the player's walkable area.
	for x in [-0.335,0.335]:
		var pane := box(Vector3(x,0.94,0.505),Vector3(0.60,1.05,0.008),"7eaaa8",cooler)
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.45,0.72,0.72,0.09)
		glass.roughness = 0.15
		pane.material_override = glass
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in [-0.60,0.60]:
		box(Vector3(x,0.95,0.54),Vector3(0.022,1.03,0.025),"b6efea",cooler,true)
	box(Vector3(0,1.67,0.1),Vector3(1.5,0.18,0.78),"1a4b50",cooler)
	sign_text("KALT / 4 °C",Vector3(0,1.67,0.51),1.15,cooler)
	var shelf := station.get_node("Shelf")
	for x in [-0.86,0.86]:
		box(Vector3(x,0.72,0),Vector3(0.055,1.42,0.65),"a3aaa0",shelf)
	for item in shelf.get_children():
		if item is StaticBody3D and item.get_child_count() > 0:
			var visual := item.get_child(0) as MeshInstance3D
			if visual and visual.mesh is BoxMesh and visual.mesh.size.is_equal_approx(Vector3(0.16,0.27,0.2)):
				visual.hide()
				bottle(Vector3.ZERO,"7d9670",item)
	for y in [0.15,0.65,1.15]:
		box(Vector3(0,y,0.34),Vector3(1.78,0.075,0.03),"344b4b",shelf)
		for x in [-0.6,0.0,0.6]:
			box(Vector3(x,y,0.36),Vector3(0.22,0.045,0.015),"ddd4b3",shelf)
	box(Vector3(0,1.5,0),Vector3(1.8,0.19,0.66),"286663",shelf)
	sign_text("GETRÄNKE",Vector3(0,1.5,0.34),1.4,shelf)
	var till := station.get_node("Register")
	till.get_node("Terminal").get_child(0).hide()
	bevel(Vector3(0,1.02,0),Vector3(1.94,0.09,1.04),"7e8981",till)
	box(Vector3(0,0.17,0.46),Vector3(1.8,0.19,0.04),"253b3b",till)
	for x in [-0.72,-0.36,0.0,0.36,0.72]:
		box(Vector3(x,0.6,0.46),Vector3(0.025,0.64,0.03),"ab9977",till)
	bevel(Vector3(-0.22,1.10,-0.05),Vector3(0.65,0.09,0.38),"263739",till)
	box(Vector3(-0.22,1.22,-0.12),Vector3(0.10,0.27,0.09),"8e9b94",till)
	var monitor := Node3D.new()
	monitor.position = Vector3(-0.22,1.43,-0.10)
	monitor.rotation.x = deg_to_rad(-15)
	till.add_child(monitor)
	bevel(Vector3.ZERO,Vector3(0.63,0.39,0.08),"263739",monitor)
	box(Vector3(0,0,0.045),Vector3(0.53,0.29,0.012),"244d50",monitor,true)
	for row in 3:
		box(Vector3(-0.08,0.075-row*0.065,0.055),Vector3(0.29-row*0.045,0.014,0.004),"82b8aa",monitor,true)
	bevel(Vector3(0.56,1.15,0.16),Vector3(0.23,0.16,0.34),"263739",till)
	box(Vector3(0.56,1.235,0.09),Vector3(0.16,0.008,0.10),"80b6a8",till,true)
	for row in 3:
		for col in 3:
			box(Vector3(0.50+col*0.06,1.237,0.18+row*0.045),Vector3(0.037,0.014,0.024),"9caaa5",till)
	bevel(Vector3(-0.65,1.12,0.12),Vector3(0.24,0.11,0.3),"263739",till)
	box(Vector3(-0.65,1.18,0.18),Vector3(0.15,0.008,0.14),"ddd4b3",till)
	box(Vector3(0,0.88,0.48),Vector3(0.55,0.14,0.025),"263739",till)
	box(Vector3(0,0.89,0.50),Vector3(0.20,0.025,0.025),"8e9b94",till)
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
	box(Vector3(0,0.75,-3.716),Vector3(1.1,0.20,0.025),"173d40")
	sign_text("KAFFEE / 24 H",Vector3(0,0.75,-3.696),0.96)
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
	panel.get_node("Mesh").hide()
	var pane := box(Vector3(0,0.81,0),Vector3(2.04,1.28,0.025),"173d40",panel)
	pane.material_override = window_material()
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [0.08,1.48]:
		bevel(Vector3(0,y,0),Vector3(2.2,0.09,0.15),"8a9d97",panel)
	box(Vector3(0,0.27,0),Vector3(2.1,0.3,0.06),"344b4b",panel)
	box(Vector3(0,1.05,0.08),Vector3(1.65,0.18,0.045),"173d40",panel)
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

func bottle(at: Vector3, color: String, parent: Node3D, scale_factor: float = 1.0) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * scale_factor
	parent.add_child(root)
	cylinder(Vector3(0,-0.018,0),0.07,0.23,color,root)
	cylinder(Vector3(0,0.12,0),0.036,0.08,color,root)
	cylinder(Vector3(0,0.163,0),0.039,0.025,"ddd4b3",root)
	cylinder(Vector3(0,-0.015,0),0.071,0.085,"c5ba96",root)

func package(at: Vector3, variant: int, parent: Node3D) -> void:
	if variant % 2 == 0:
		cylinder(at,0.085,0.27,["a97344","beaa70","557b69","965647"][variant],parent)
		cylinder(at+Vector3(0,0.14,0),0.085,0.015,"9caaa5",parent)
		cylinder(at,0.086,0.09,"d7cdb0",parent)
	else:
		bevel(at,Vector3(0.19,0.27,0.21),["a97344","beaa70","557b69","965647"][variant],parent)
		box(at+Vector3(0,0.143,0),Vector3(0.14,0.018,0.16),"c5ba96",parent)
		box(at+Vector3(0,0.01,0.112),Vector3(0.13,0.09,0.012),"d7cdb0",parent)

func bevel(at: Vector3, size: Vector3, color: String, parent: Node3D = self) -> MeshInstance3D:
	# Four octagonal rings produce actual bevel faces, without modifiers or textures.
	var b := minf(0.035,minf(size.x,minf(size.y,size.z))*0.2)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for level in 4:
		var inset := b if level == 0 or level == 3 else 0.0
		var x := size.x*0.5-inset
		var z := size.z*0.5-inset
		var y: float = [-size.y*0.5,-size.y*0.5+b,size.y*0.5-b,size.y*0.5][level]
		rings.append(PackedVector3Array([Vector3(-x+b,y,-z),Vector3(x-b,y,-z),Vector3(x,y,-z+b),Vector3(x,y,z-b),Vector3(x-b,y,z),Vector3(-x+b,y,z),Vector3(-x,y,z-b),Vector3(-x,y,-z+b)]))
	for level in 3:
		for i in 8:
			var j := (i+1)%8
			triangle(surface,rings[level][i],rings[level+1][j],rings[level][j])
			triangle(surface,rings[level][i],rings[level+1][i],rings[level+1][j])
	for i in range(1,7):
		triangle(surface,rings[0][0],rings[0][i],rings[0][i+1])
		triangle(surface,rings[3][0],rings[3][i+1],rings[3][i])
	surface.generate_normals()
	var item := MeshInstance3D.new()
	item.mesh = surface.commit()
	item.material_override = mat(color)
	item.position = at
	parent.add_child(item)
	return item

func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.set_smooth_group(-1)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(b)

func object_details() -> void:
	var desk := station.get_node("ShiftBoard")
	desk.get_node("Desk").get_child(0).hide()
	box(Vector3(0,0.68,0.345),Vector3(1.1,0.18,0.025),"344b4b",desk)
	for x in [-0.5,0.5]:
		for z in [-0.26,0.26]:
			box(Vector3(x,0.43,z),Vector3(0.07,0.86,0.07),"8e9b94",desk)
	bevel(Vector3(0.23,0.70,0),Vector3(0.50,0.32,0.65),"52625c",desk)
	box(Vector3(0.23,0.72,0.335),Vector3(0.20,0.035,0.04),"bcc7be",desk)
	box(Vector3(-0.25,0.15,0),Vector3(0.06,0.06,0.6),"8e9b94",desk)
	for i in 4:
		box(Vector3(0,0.941,-0.08+i*0.04),Vector3(0.29-i*0.025,0.003,0.007),"61706a",desk)
	# Coffee dispenser: beans, spouts and draining grid reveal its function.
	cylinder(Vector3(-0.36,1.64,-4.18),0.19,0.2,"4c463b")
	cylinder(Vector3(-0.36,1.75,-4.18),0.21,0.03,"263739")
	for x in [-0.47,-0.25]:
		cylinder(Vector3(x,1.17,-3.84),0.027,0.13,"8e9b94")
	for i in 7:
		box(Vector3(-0.56+i*0.065,1.077,-3.82),Vector3(0.015,0.008,0.2),"263739")
	for x in [-0.53,0.53]:
		box(Vector3(x,0.44,-3.716),Vector3(0.96,0.48,0.025),"65746a")
		box(Vector3(x,0.61,-3.69),Vector3(0.26,0.035,0.04),"8e9b94")
	# Pump panels and recessed controls fit the original collision footprint.
	station.get_node("Pump").get_child(0).hide()
	station.get_node("PumpDisplay").get_child(0).hide()
	bevel(Vector3(-3.8,0.8,8.3),Vector3(1,1.6,0.8),"9caaa5")
	bevel(Vector3(-3.8,1.15,8.73),Vector3(0.78,0.53,0.08),"263739")
	box(Vector3(-3.8,1.23,8.78),Vector3(0.59,0.19,0.012),"173d40",self,true)
	sign_text("1.829 / L",Vector3(-3.8,1.23,8.80),0.49,self,"acdfbc")
	for i in 3:
		box(Vector3(-4.02+i*0.21,1.04,8.78),Vector3(0.09,0.05,0.015),"9caaa5")
	box(Vector3(-3.8,0.31,8.713),Vector3(0.72,0.20,0.025),"263739")
	for i in 4:
		box(Vector3(-3.8,0.25+i*0.04,8.73),Vector3(0.64,0.012,0.012),"8e9b94")
	bevel(Vector3(-3.21,1.24,8.63),Vector3(0.11,0.27,0.09),"263739")
	box(Vector3(-3.21,1.39,8.58),Vector3(0.05,0.05,0.18),"8e9b94")

func window_material() -> StandardMaterial3D:
	if not materials.has("window"):
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.24,0.47,0.49,0.18)
		glass.roughness = 0.18
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials["window"] = glass
	return materials["window"]

func finishing_details() -> void:
	# Glazing sits over the existing low walls, with the doorway and sliding pocket retained.
	for center in [-4.1,4.1]:
		var pane := box(Vector3(center,1.11,5),Vector3(5.7,0.72,0.02),"173d40")
		pane.material_override = window_material()
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(Vector3(center,1.49,5),Vector3(5.7,0.055,0.09),"8a9d97")
		for offset in [-2.7,-0.9,0.9,2.7]:
			box(Vector3(center+offset,1.12,5),Vector3(0.045,0.73,0.09),"8a9d97")
	# Wall service details remain shallow and outside circulation space.
	for x in [-3.45,3.45]:
		box(Vector3(x,0.8,-4.79),Vector3(0.18,0.25,0.035),"bcc7be")
		for y in [0.74,0.86]:
			box(Vector3(x,y,-4.764),Vector3(0.06,0.022,0.008),"263739")
		box(Vector3(x,0.41,-4.79),Vector3(0.024,0.6,0.024),"8e9b94")
	box(Vector3(2.25,1.42,-4.76),Vector3(0.85,0.66,0.06),"263739")
	box(Vector3(2.25,1.42,-4.72),Vector3(0.77,0.58,0.025),"bca477")
	sign_text("FRISCH\nFÜR DIE NACHT",Vector3(2.25,1.43,-4.697),1.4,self,"263739")
	# Service cabinet seams distinguish doors from one solid mass.
	for x in [-6.78,6.78]:
		for z in [-3.8,-1.8,0.2,2.2,4.2]:
			box(Vector3(x,0.64,z),Vector3(0.025,0.91,0.018),"72817b")
	# The bin gains a metal rim, open mouth and foot pedal.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.19
	torus.outer_radius = 0.27
	torus.rings = 16
	torus.ring_segments = 8
	rim.mesh = torus
	rim.material_override = mat("8e9b94")
	rim.position = Vector3(-6.05,0.63,3.7)
	rim.scale.y = 0.4
	add_child(rim)
	box(Vector3(-6.05,0.065,3.98),Vector3(0.19,0.045,0.10),"8e9b94")
	# A rubber edge gives the entrance mat thickness without adding a trip collider.
	for x in [-1.18,1.18]:
		box(Vector3(x,0.029,3.9),Vector3(0.055,0.02,1.45),"172b2c")
	# Visible light diffusers on the existing forecourt poles.
	for x in [-5.5,5.5]:
		box(Vector3(x,3.28,8.71),Vector3(0.55,0.065,0.022),"c4efeb",self,true)
