extends Node
## The only adapter between the current map and gameplay. Replace these bindings
## or provide named child markers in a future authored scene; the loop stays unchanged.
@export var shelf_path: NodePath = ^"../Station/Shelf"
@export var checkout_path: NodePath = ^"../Station/Register"
@export var warehouse_path: NodePath = ^"../Station/ServiceAnnex"
@export var entrance_path: NodePath = ^"../Station/Door"
@export var shelf_approach := Vector3(0,0,1.3)
@export var operator_offset := Vector3(-0.3,0,-1.0)
@export var customer_offset := Vector3(0,0,1.0)
@export var queue_step := Vector3(-1.0,0,0)
@export var spawn_offset := Vector3(0,0,2.7)
@export var entry_wait_offset := Vector3(0.95,0,2.7)
var shelf: Node3D
var checkout: Node3D
var warehouse: Node3D
var entrance: Node3D
var shelf_point: Marker3D
var operator_point: Marker3D
var spawn_point: Marker3D
var entry_wait_point: Marker3D
var queue_points: Array[Marker3D] = []
var doors: Array[Node3D] = []
var delivery: Node3D
var delivery_visual: MeshInstance3D
var radio_point: Node3D
var displays: Dictionary = {}
var stock_label: Label3D
var inventory: Resource
var product_points: Dictionary = {}
var product_nodes: Dictionary = {}
var product_labels: Dictionary = {}
var story_areas: Array[Area3D] = []
var wc_point: Node3D
var wc_mark: MeshInstance3D
var carried_visual: Node3D
var carried_crate: MeshInstance3D
var carried_material: StandardMaterial3D
var service_waste: MeshInstance3D
var service_point: Node3D
var checkout_item: MeshInstance3D
var checkout_item_material: StandardMaterial3D
var pump_terminal: Node3D
var pump_reset_points: Dictionary = {}

func _ready() -> void:
	shelf = get_node(shelf_path)
	checkout = get_node(checkout_path)
	warehouse = get_node(warehouse_path)
	entrance = get_node(entrance_path)
	shelf_point = marker(shelf,"CustomerApproach",shelf_approach)
	operator_point = marker(checkout,"Operator",operator_offset)
	spawn_point = marker(entrance,"CustomerSpawn",spawn_offset)
	entry_wait_point = marker(entrance,"CustomerEntryWait",entry_wait_offset)
	for i in 4:
		queue_points.append(marker(checkout,"Queue%d" % i,customer_offset+queue_step*i))
	doors.append(entrance)
	for item in warehouse.doors:
		doors.append(item)
	delivery = Node3D.new()
	delivery.name = "DeliveryParcel"
	delivery.set_script(preload("res://scenes/interactions/interactable.gd"))
	delivery.action_id = &"delivery"
	delivery.prompt = "Collect delivery"
	delivery.available = false
	warehouse.get_node("DeliveryDoor").add_child(delivery)
	# Parent door root is scaled for its opening; keep the parcel at physical size.
	delivery.scale.x = 1.0/delivery.get_parent().scale.x
	delivery.position = Vector3(1.5/delivery.get_parent().scale.x,0,-1.3)
	delivery_visual = MeshInstance3D.new()
	var parcel := BoxMesh.new()
	parcel.size = Vector3(0.6,0.5,0.5)
	delivery_visual.mesh = parcel
	# The removable parcel sits on the existing pallet stack, not inside it.
	delivery_visual.position = Vector3(0.15,0.98,-0.35)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("c6a46d")
	delivery_visual.material_override = material
	delivery.add_child(delivery_visual)
	delivery_visual.hide()
	stock_label = Label3D.new()
	stock_label.position = Vector3(0,2.0,0)
	stock_label.pixel_size = 0.004
	stock_label.font_size = 32
	stock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stock_label.visible = false
	shelf.add_child(stock_label)
	warehouse.stock.changed.connect(sync_stock)
	sync_stock()
	inventory = preload("res://scripts/shop_inventory.gd").new()
	inventory.add_product(preload("res://data/products/water.tres"),warehouse.stock)
	inventory.add_product(preload("res://data/products/energy.tres"))
	inventory.add_product(preload("res://data/products/chips.tres"))
	setup_carried_visual()
	setup_checkout_visual()
	setup_pump_terminal()
	setup_pump_reset_points()
	product_nodes[&"water"] = shelf
	product_points[&"water"] = shelf_point
	product_labels[&"water"] = stock_label
	var cooler := shelf.get_parent().get_node("Cooler")
	bind_product(&"energy",cooler,Vector3(0,0,1.3))
	var snacks := shelf.get_parent().get_node("StationDressing/SnackIsland")
	snacks.set_script(preload("res://scenes/interactions/interactable.gd"))
	snacks.add_to_group("interactable")
	snacks.action_id = &"stock_chips"
	bind_product(&"chips",snacks,Vector3(0,0,2.25))
	# Dynamic inventory geometry is created after static map batching.
	for config in [{"id": &"energy", "kind": "can", "origin": Vector3(-0.335,0.549,0.29), "spacing": Vector3(0.67,0.4,0), "columns":2}, {"id": &"chips", "kind": "bag", "origin": Vector3(-0.42,0.5,0.5), "spacing": Vector3(0.42,0.45,0), "columns":3}]:
		var display = preload("res://scripts/product_display.gd").new()
		display.name = "ProductStock"
		product_nodes[config.id].add_child(display)
		display.bind(inventory.stocks[config.id],config.kind,inventory.stocks[config.id].capacity,config.origin,config.spacing,config.columns)
		displays[config.id] = display
	radio_point = Node3D.new()
	radio_point.name = "Radio"
	radio_point.set_script(preload("res://scenes/interactions/interactable.gd"))
	radio_point.action_id = &"radio"
	radio_point.prompt = "Radio on/off  |  [Y] Track  [+/-] Volume"
	shelf.get_parent().add_child(radio_point)
	radio_point.position = Vector3(6.05,0,-4.6)
	var model = preload("res://scripts/product_display.gd").new()
	radio_point.add_child(model)
	model.box(model,Vector3(0,1.05,0),Vector3(0.55,0.32,0.20),Color("283b3c"))
	model.box(model,Vector3(0,0.85,0),Vector3(0.75,0.05,0.45),Color("80867b"))
	model.box(model,Vector3(-0.12,1.05,0.11),Vector3(0.22,0.23,0.01),Color("101d22"))
	model.box(model,Vector3(0.15,1.09,0.11),Vector3(0.17,0.06,0.01),Color("b8cf90"))
	marker(radio_point,"Approach",Vector3(0,0,1))
	inventory.changed.connect(sync_products)
	sync_products()
	var service := Node3D.new()
	service_point = service
	service.name = "ServicePoint"
	service.set_script(preload("res://scenes/interactions/interactable.gd"))
	service.action_id = &"service"
	service.prompt = "Waste bin / Service check"
	shelf.get_parent().add_child(service)
	service.position = Vector3(-6.05,0,3.95)
	marker(service,"Approach",Vector3(0.7,0,0))
	# The station dressing already provides the physical open bin at z=3.7.
	# Only add removable waste inside it; duplicating a second bin here caused clipping.
	var service_model = preload("res://scripts/product_display.gd").new()
	service.add_child(service_model)
	service_waste = service_model.box(service,Vector3(0,0.52,-0.25),Vector3(0.20,0.18,0.18),Color("171d1e"))
	register_event_lights(shelf.get_parent())
	var area = preload("res://scripts/story_area.gd").new()
	area.name = "StockroomStoryArea"
	area.area_id = &"stockroom"
	warehouse.get_node("Supply").add_child(area)
	area.position = Vector3(0,1,1)
	var region := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2,2,2)
	region.shape = shape
	area.add_child(region)
	story_areas.append(area)
	var prop = preload("res://scripts/story_prop.gd").new()
	prop.name = "LooseCarton"
	prop.target_id = &"stockroom_parcel"
	prop.settled_roll = 1.0
	warehouse.get_node("Supply").add_child(prop)
	prop.position = Vector3(0.7,1.05,0.6)
	model.box(prop,Vector3.ZERO,Vector3(0.38,0.36,0.36),Color("b59a73"))
	model.box(prop,Vector3(0,0.185,0),Vector3(0.07,0.01,0.36),Color("e0cc9f"))
	# A small loaded service rack tips with the parcel; its state remains visible.
	for x in [-0.32,0.32]:
		model.box(prop,Vector3(x,0.28,0),Vector3(0.035,0.58,0.36),Color("798581"))
	for y in [0.02,0.55]:
		model.box(prop,Vector3(0,y,0),Vector3(0.68,0.035,0.4),Color("919c96"))
	wc_point = Node3D.new()
	wc_point.name = "WCService"
	wc_point.set_script(preload("res://scenes/interactions/interactable.gd"))
	wc_point.action_id = &"wc"
	wc_point.prompt = "Clean floor / Check WC"
	wc_point.available = false
	warehouse.add_child(wc_point)
	wc_point.position = warehouse.get_node("WCEntry").position+Vector3(-0.3,0,1.2)
	marker(wc_point,"Approach",Vector3(0,0,-0.25))
	wc_mark = MeshInstance3D.new()
	var spill := CylinderMesh.new()
	spill.top_radius = 0.32
	spill.bottom_radius = 0.32
	spill.height = 0.006
	wc_mark.mesh = spill
	wc_mark.position.y = 0.014
	var damp := StandardMaterial3D.new()
	damp.albedo_color = Color("555b4a")
	damp.roughness = 0.25
	wc_mark.material_override = damp
	wc_point.add_child(wc_mark)
	wc_mark.hide()

func setup_carried_visual() -> void:
	carried_visual = Node3D.new()
	carried_visual.name = "CarriedWorkItem"
	get_node("../Player").add_child(carried_visual)
	carried_visual.position = Vector3(0.34,0.72,0.10)
	carried_visual.rotation = Vector3(0.08,-0.28,0.06)
	carried_crate = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.44,0.34,0.32)
	carried_crate.mesh = mesh
	carried_material = StandardMaterial3D.new()
	carried_material.albedo_color = Color("b18c5c")
	carried_material.roughness = 0.9
	carried_crate.material_override = carried_material
	carried_visual.add_child(carried_crate)
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(0.07,0.345,0.325)
	band.mesh = band_mesh
	var band_material := StandardMaterial3D.new()
	band_material.albedo_color = Color("d0bc91")
	band.material_override = band_material
	carried_visual.add_child(band)
	carried_visual.hide()

func set_carry_state(delivery: bool, product: StringName) -> void:
	if not is_instance_valid(carried_visual):
		return
	carried_visual.visible = delivery or product != &""
	if not carried_visual.visible:
		return
	if delivery:
		carried_material.albedo_color = Color("b18c5c")
	else:
		match product:
			&"water": carried_material.albedo_color = Color("6e918a")
			&"energy": carried_material.albedo_color = Color("3f8f80")
			&"chips": carried_material.albedo_color = Color("b96e36")
			_: carried_material.albedo_color = Color("8b8878")

func set_service_done(done: bool) -> void:
	if is_instance_valid(service_waste):
		service_waste.visible = not done

func setup_pump_terminal() -> void:
	pump_terminal = Node3D.new()
	pump_terminal.name = "PumpTerminal"
	pump_terminal.set_script(preload("res://scenes/interactions/interactable.gd"))
	pump_terminal.action_id = &"pump_terminal"
	pump_terminal.prompt = "Fuel pump control"
	checkout.add_child(pump_terminal)
	pump_terminal.position = Vector3(-0.54,0,-0.03)
	marker(pump_terminal,"Approach",Vector3(-0.1,0,-0.82))
	var model := preload("res://scripts/product_display.gd").new()
	pump_terminal.add_child(model)
	model.box(model,Vector3(0,1.18,0),Vector3(0.42,0.28,0.30),Color("263d3c"))
	model.box(model,Vector3(0,1.20,0.16),Vector3(0.31,0.15,0.02),Color("102426"))
	model.box(model,Vector3(-0.10,1.04,0.16),Vector3(0.06,0.035,0.02),Color("c7b782"))
	model.box(model,Vector3(0.0,1.04,0.16),Vector3(0.06,0.035,0.02),Color("6f8d88"))
	model.box(model,Vector3(0.10,1.04,0.16),Vector3(0.06,0.035,0.02),Color("8c5e58"))

func setup_pump_reset_points() -> void:
	var names := ["Pump","Pump02","Pump03","Pump04"]
	for i in names.size():
		var pump := get_node("../Station/"+names[i])
		var point := Node3D.new()
		point.name = "PumpReset%02d" % (i+1)
		point.set_script(preload("res://scenes/interactions/interactable.gd"))
		point.action_id = StringName("pump_reset_%d" % (i+1))
		point.prompt = "Reset pump %02d" % (i+1)
		point.available = false
		pump.add_child(point)
		point.position = Vector3(0,0,0.62)
		marker(point,"Approach",Vector3(0.9,0,0))
		var model := preload("res://scripts/product_display.gd").new()
		point.add_child(model)
		model.box(model,Vector3(0,1.20,0),Vector3(0.18,0.18,0.07),Color("783f3d"))
		model.box(model,Vector3(0,1.20,0.04),Vector3(0.08,0.08,0.02),Color("d1b36d"))
		pump_reset_points[i+1] = point

func setup_checkout_visual() -> void:
	checkout_item = MeshInstance3D.new()
	checkout_item.name = "ScannedProduct"
	checkout_item.position = Vector3(0.34,1.23,-0.04)
	checkout_item_material = StandardMaterial3D.new()
	checkout_item_material.roughness = 0.72
	checkout_item.material_override = checkout_item_material
	checkout.add_child(checkout_item)
	checkout_item.hide()

func set_checkout_product(id: StringName, visible: bool = true) -> void:
	if not is_instance_valid(checkout_item):
		return
	checkout_item.visible = visible
	if not visible:
		return
	match id:
		&"water":
			var bottle_mesh := CylinderMesh.new()
			bottle_mesh.top_radius = 0.065
			bottle_mesh.bottom_radius = 0.08
			bottle_mesh.height = 0.36
			bottle_mesh.radial_segments = 10
			checkout_item.mesh = bottle_mesh
			checkout_item_material.albedo_color = Color("7d9670")
		&"energy":
			var can_mesh := CylinderMesh.new()
			can_mesh.top_radius = 0.075
			can_mesh.bottom_radius = 0.075
			can_mesh.height = 0.25
			can_mesh.radial_segments = 12
			checkout_item.mesh = can_mesh
			checkout_item_material.albedo_color = Color("439d8d")
		&"chips":
			var bag_mesh := PrismMesh.new()
			bag_mesh.size = Vector3(0.26,0.31,0.18)
			checkout_item.mesh = bag_mesh
			checkout_item_material.albedo_color = Color("c97435")
		_:
			var fallback := BoxMesh.new()
			fallback.size = Vector3(0.2,0.2,0.2)
			checkout_item.mesh = fallback
			checkout_item_material.albedo_color = Color("8b8878")

func register_event_lights(node: Node) -> void:
	if node is Light3D and (node.global_position.distance_to(product_nodes[&"energy"].global_position) < 4 or node.global_position.distance_to(checkout.global_position) < 2.5):
		node.add_to_group("night_event_light")
	for child in node.get_children(): register_event_lights(child)

func bind_product(id: StringName, object: Node3D, approach: Vector3) -> void:
	product_nodes[id] = object
	product_points[id] = marker(object,"CustomerApproach",approach)
	var label := Label3D.new()
	label.position.y = 1.6
	label.pixel_size = 0.004
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	object.add_child(label)
	product_labels[id] = label

func sync_products() -> void:
	for id in inventory.stocks:
		var item: Resource = inventory.stocks[id]
		var title: String = inventory.products[id].display_name
		product_labels[id].visible = false
		product_labels[id].text = "%s%s" % [title," — RESTOCK" if item.shelf_units == 0 else ""]
		product_nodes[id].prompt = "Restock %s (%d/%d)" % [title,item.shelf_units,item.capacity]
	product_nodes[&"energy"].prompt = "Restock Energy" if inventory.carried_product() != &"" else "Check refrigeration"

func marker(parent: Node3D, node_name: String, offset: Vector3) -> Marker3D:
	var existing := parent.get_node_or_null(NodePath(node_name)) as Marker3D
	if existing:
		return existing
	var point := Marker3D.new()
	point.name = node_name
	point.position = offset
	parent.add_child(point)
	return point

func sync_stock() -> void:
	stock_label.text = "Wasser: %d/%d  |  reserviert: %d" % [warehouse.stock.shelf_units,warehouse.stock.capacity,warehouse.stock.reserved_units]
	var items: Array = shelf.get_parent().restock_items
	for i in items.size():
		items[i].visible = i < warehouse.stock.shelf_units
	shelf.prompt = "Restock water (%d/%d)" % [warehouse.stock.shelf_units,warehouse.stock.capacity]

func at_operator(player: Node3D) -> bool:
	return player.global_position.distance_to(operator_point.global_position) < 0.85
