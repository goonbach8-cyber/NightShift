extends Node
## One grounded customer-assistance interruption per later shift. It temporarily
## blocks the front customer's checkout until the player retrieves a small lost item.
var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var request_active := false
var item_found := false
var completed := false
var request_customer: CharacterBody3D
var item_node: Node3D
var carried_item: Node3D
var item_kind: StringName = &"keys"
var item_label := "keys"
var area_label := "cold drinks"
var target_product: StringName = &"energy"

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player

func handle_checkout_use() -> bool:
	if gameplay.career_shifts < 1 or completed or not gameplay.checkout_ready():
		return false
	var front: CharacterBody3D = gameplay.queue[0]
	if request_active:
		if front != request_customer:
			return false
		if item_found:
			_return_item()
		else:
			world._say("Customer: I think I dropped my %s near the %s." % [item_label,area_label],5.0)
		return true
	if gameplay.served+gameplay.lost_sales < 1:
		return false
	_start_request(front)
	return true

func _start_request(customer: CharacterBody3D) -> void:
	request_active = true
	item_found = false
	request_customer = customer
	request_customer.state = &"assistance"
	request_customer.status_text = "Waiting for lost item"
	var night := gameplay.career_shifts+1
	match night:
		2:
			item_kind = &"keys"
			item_label = "keys"
			area_label = "cold drinks"
			target_product = &"energy"
		3:
			item_kind = &"wallet"
			item_label = "wallet"
			area_label = "snack aisle"
			target_product = &"chips"
		4:
			item_kind = &"keycard"
			item_label = "work card"
			area_label = "water display"
			target_product = &"water"
		5:
			item_kind = &"keys"
			item_label = "keys"
			area_label = "snack aisle"
			target_product = &"chips"
		_:
			item_kind = &"wallet"
			item_label = "wallet"
			area_label = "cold drinks"
			target_product = &"energy"
	_spawn_item()
	world._say("Customer: Sorry — I dropped my %s near the %s. Could you check?" % [item_label,area_label],7.0)
	gameplay.changed.emit()
	world._update_objective()

func _spawn_item() -> void:
	_clear_world_item()
	item_node = Node3D.new()
	item_node.name = "LostCustomerItem"
	item_node.set_script(preload("res://scenes/interactions/interactable.gd"))
	item_node.action_id = &"lost_customer_item"
	item_node.prompt = "Pick up customer's "+item_label
	world.add_child(item_node)
	var point: Node3D = layout.product_points[target_product]
	item_node.global_position = point.global_position+Vector3(0,0.04,0.18)
	item_node.used.connect(_on_item_used)
	_build_item_visual(item_node,item_kind)

func _on_item_used(_action: StringName) -> void:
	if not request_active or item_found:
		return
	item_found = true
	_show_carried_item()
	_clear_world_item()
	world._say("Found the customer's %s. Bring it back to the till." % item_label,5.0)
	gameplay.changed.emit()
	world._update_objective()

func _return_item() -> void:
	if not request_active or not item_found or not is_instance_valid(request_customer):
		return
	request_customer.state = &"queued"
	request_customer.status_text = "Waiting at checkout"
	item_found = false
	request_active = false
	completed = true
	_clear_carried_item()
	gameplay.story_flags[StringName("customer_assistance_night_%d" % (gameplay.career_shifts+1))] = true
	world._say("Customer: That's it. Thank you — I thought I'd lost it.",5.0)
	gameplay.changed.emit()
	world._update_objective()

func objective_text() -> String:
	if not request_active:
		return ""
	if item_found:
		return "Return the customer's %s at the till" % item_label
	return "Find the customer's %s near the %s" % [item_label,area_label]

func _show_carried_item() -> void:
	_clear_carried_item()
	carried_item = Node3D.new()
	carried_item.name = "CarriedLostItem"
	player.add_child(carried_item)
	carried_item.position = Vector3(0.30,0.72,0.06)
	carried_item.rotation = Vector3(0.0,-0.25,0.10)
	_build_item_visual(carried_item,item_kind)

func _build_item_visual(parent: Node3D, kind: StringName) -> void:
	if kind == &"keys":
		var ring_visual := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.055
		ring.outer_radius = 0.075
		ring.rings = 12
		ring.ring_segments = 8
		ring_visual.mesh = ring
		ring_visual.rotation.x = PI/2.0
		ring_visual.position.y = 0.035
		ring_visual.material_override = _material(Color("b9a36d"),0.45)
		parent.add_child(ring_visual)
		_box(parent,Vector3(0.08,0.02,0),Vector3(0.13,0.025,0.035),Color("b9a36d"))
		_box(parent,Vector3(0.14,0.02,0.025),Vector3(0.035,0.025,0.035),Color("b9a36d"))
	elif kind == &"keycard":
		_box(parent,Vector3.ZERO,Vector3(0.20,0.025,0.13),Color("587786"))
		_box(parent,Vector3(0,0.016,0.03),Vector3(0.12,0.006,0.025),Color("d4d2bf"))
	else:
		_box(parent,Vector3.ZERO,Vector3(0.20,0.055,0.14),Color("6d4d3e"))
		_box(parent,Vector3(0,0.032,0.03),Vector3(0.13,0.008,0.035),Color("c8b98d"))

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = _material(color,0.75)
	parent.add_child(visual)
	return visual

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.25 if roughness < 0.6 else 0.0
	return material

func _clear_world_item() -> void:
	if is_instance_valid(item_node):
		item_node.queue_free()
	item_node = null

func _clear_carried_item() -> void:
	if is_instance_valid(carried_item):
		carried_item.queue_free()
	carried_item = null

func _exit_tree() -> void:
	_clear_world_item()
	_clear_carried_item()
