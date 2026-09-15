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
var shelf: Node3D
var checkout: Node3D
var warehouse: Node3D
var entrance: Node3D
var shelf_point: Marker3D
var operator_point: Marker3D
var spawn_point: Marker3D
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

func _ready() -> void:
	shelf = get_node(shelf_path)
	checkout = get_node(checkout_path)
	warehouse = get_node(warehouse_path)
	entrance = get_node(entrance_path)
	shelf_point = marker(shelf,"CustomerApproach",shelf_approach)
	operator_point = marker(checkout,"Operator",operator_offset)
	spawn_point = marker(entrance,"CustomerSpawn",spawn_offset)
	for i in 4:
		queue_points.append(marker(checkout,"Queue%d" % i,customer_offset+queue_step*i))
	doors.append(entrance)
	for item in warehouse.doors:
		doors.append(item)
	delivery = Node3D.new()
	delivery.name = "DeliveryParcel"
	delivery.set_script(preload("res://scenes/interactions/interactable.gd"))
	delivery.action_id = &"delivery"
	delivery.prompt = "Lieferung aufnehmen"
	delivery.available = false
	warehouse.get_node("DeliveryDoor").add_child(delivery)
	# Parent door root is scaled for its opening; keep the parcel at physical size.
	delivery.scale.x = 1.0/delivery.get_parent().scale.x
	delivery.position = Vector3(1.5/delivery.get_parent().scale.x,0,-1.3)
	delivery_visual = MeshInstance3D.new()
	var parcel := BoxMesh.new()
	parcel.size = Vector3(0.6,0.5,0.5)
	delivery_visual.mesh = parcel
	delivery_visual.position.y = 0.55
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
	shelf.add_child(stock_label)
	warehouse.stock.changed.connect(sync_stock)
	sync_stock()
	inventory = preload("res://scripts/shop_inventory.gd").new()
	inventory.add_product(preload("res://data/products/water.tres"),warehouse.stock)
	inventory.add_product(preload("res://data/products/energy.tres"))
	inventory.add_product(preload("res://data/products/chips.tres"))
	product_nodes[&"water"] = shelf
	product_points[&"water"] = shelf_point
	product_labels[&"water"] = stock_label
	var cooler := shelf.get_parent().get_node("Cooler")
	bind_product(&"energy",cooler,Vector3(0,0,1.3))
	var snacks := shelf.get_parent().get_node("StationDressing/SnackIsland")
	snacks.set_script(preload("res://scenes/interactions/interactable.gd"))
	snacks.add_to_group("interactable")
	snacks.action_id = &"stock_chips"
	bind_product(&"chips",snacks,Vector3(0,0,1.5))
	# Dynamic inventory geometry is created after static map batching.
	for config in [{"id": &"energy", "kind": "can", "origin": Vector3(-0.44,0.54,0.44), "spacing": Vector3(0.43,0.4,0)}, {"id": &"chips", "kind": "bag", "origin": Vector3(-0.42,0.5,0.5), "spacing": Vector3(0.42,0.45,0)}]:
		var display = preload("res://scripts/product_display.gd").new()
		display.name = "ProductStock"
		product_nodes[config.id].add_child(display)
		display.bind(inventory.stocks[config.id],config.kind,inventory.stocks[config.id].capacity,config.origin,config.spacing)
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
	service.name = "ServicePoint"
	service.set_script(preload("res://scenes/interactions/interactable.gd"))
	service.action_id = &"service"
	service.prompt = "Waste bin / Service check"
	shelf.get_parent().add_child(service)
	service.position = Vector3(-6.05,0,3.95)
	marker(service,"Approach",Vector3(0.7,0,0))
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
	warehouse.get_node("Supply").add_child(prop)
	prop.position = Vector3(0.7,1.05,0.6)
	model.box(prop,Vector3.ZERO,Vector3(0.38,0.36,0.36),Color("b59a73"))
	model.box(prop,Vector3(0,0.185,0),Vector3(0.07,0.01,0.36),Color("e0cc9f"))

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
		product_nodes[id].prompt = "%s auffüllen (%d/%d)" % [title,item.shelf_units,item.capacity]
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
	shelf.prompt = "Wasser auffüllen (%d/%d)" % [warehouse.stock.shelf_units,warehouse.stock.capacity]

func at_operator(player: Node3D) -> bool:
	return player.global_position.distance_to(operator_point.global_position) < 0.85
