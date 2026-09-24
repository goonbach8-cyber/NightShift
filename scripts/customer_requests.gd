extends Node
## Additional grounded customer-service requests that reuse the existing station
## rather than opening abstract minigames: restroom key, shelf-price check and a
## forecourt fuel-receipt lookup.
var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var completed := false
var task_complete := false
var request_kind: StringName = &""
var request_customer: CharacterBody3D
var target_product: StringName = &""
var target_pump := 0
var request_label := ""
var task_point: Node3D
var price_tag_visual: Node3D
var carried_prop: Node3D

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player

func handle_checkout_use() -> bool:
	if gameplay.career_shifts < 1 or gameplay.career_shifts >= 5 or completed or not gameplay.checkout_ready():
		return false
	if gameplay.served+gameplay.lost_sales < 3:
		return false
	var front: CharacterBody3D = gameplay.queue[0]
	if active:
		if front != request_customer:
			return false
		if task_complete:
			_finish_request()
		else:
			_repeat_request()
		return true
	if not world.can_start_interrupt(self):
		return false
	_start_request(front)
	return true

func _start_request(customer: CharacterBody3D) -> void:
	active = true
	task_complete = false
	request_customer = customer
	request_customer.state = &"customer_request"
	request_customer.status_text = "Waiting for assistance"
	var night: int = gameplay.career_shifts+1
	match night:
		2:
			request_kind = &"wc_key"
			request_label = "restroom key"
			layout.customer_service_key.available = true
			world._say("Customer: Sorry — do you have the restroom key? I can wait here.",7.0)
		3:
			request_kind = &"price_check"
			target_product = &"chips"
			request_label = "chips shelf price"
			_spawn_price_check()
			world._say("Customer: The chips had a different price on the shelf. Could you check the tag?",7.0)
		4:
			request_kind = &"fuel_receipt"
			target_pump = 2
			request_label = "Pump 02 fuel receipt"
			world._say("Customer: Could you print me a fuel receipt for Pump 02 before I pay?",7.0)
		5:
			request_kind = &"price_check"
			target_product = &"energy"
			request_label = "energy-drink shelf price"
			_spawn_price_check()
			world._say("Customer: Can you check the shelf price on the energy drink? I think the tag is wrong.",7.0)
		_:
			request_kind = &"wc_key"
			request_label = "restroom key"
			layout.customer_service_key.available = true
			world._say("Customer: Could I get the restroom key?",6.0)
	if is_instance_valid(world.pump_service):
		world.pump_service._update_terminal_prompt()
	gameplay.changed.emit()
	world._update_objective()

func handle_action(action: StringName) -> bool:
	if not active or task_complete:
		return false
	if action == &"customer_service_key" and request_kind == &"wc_key":
		layout.customer_service_key.available = false
		task_complete = true
		_show_carried_prop(&"key")
		world._say("Restroom key taken. Bring it to the customer at the till.",5.0)
		gameplay.changed.emit()
		world._update_objective()
		return true
	return false

func handle_pump_terminal() -> bool:
	if not active or task_complete or request_kind != &"fuel_receipt":
		return false
	task_complete = true
	if is_instance_valid(world.pump_service):
		world.pump_service._update_terminal_prompt()
	_show_carried_prop(&"receipt")
	world._say("Pump %02d receipt printed. Bring it back to the customer." % target_pump,5.0)
	gameplay.story_flags[StringName("fuel_receipt_lookup_night_%d" % (gameplay.career_shifts+1))] = true
	gameplay.changed.emit()
	world._update_objective()
	return true

func _spawn_price_check() -> void:
	_clear_task_point()
	task_point = Node3D.new()
	task_point.name = "CustomerPriceCheck"
	task_point.set_script(preload("res://scenes/interactions/interactable.gd"))
	task_point.action_id = &"customer_price_check"
	task_point.prompt = "Check shelf price"
	task_point.selection_bias = -0.25
	var product_node: Node3D = layout.product_nodes[target_product]
	# Keep the shelf tag attached to its product bay, while placing its interaction
	# point in the open customer approach. A ray to a child of the shelf otherwise
	# hits the shelf's own collision before reaching the tag.
	world.add_child(task_point)
	task_point.global_position = layout.product_points[target_product].global_position
	task_point.used.connect(_on_price_check_used)
	price_tag_visual = Node3D.new()
	price_tag_visual.name = "CustomerPriceTagVisual"
	product_node.add_child(price_tag_visual)
	price_tag_visual.position = Vector3(0,1.18,0.46)
	var panel := _box(price_tag_visual,Vector3.ZERO,Vector3(0.34,0.18,0.035),Color("d5c68b"))
	var label := Label3D.new()
	label.text = _price_text(target_product)
	label.position = Vector3(0,0,0.025)
	label.font_size = 12
	label.pixel_size = 0.0022
	label.modulate = Color("2b3330")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	price_tag_visual.add_child(label)

func _on_price_check_used(_action: StringName) -> void:
	if not active or request_kind != &"price_check" or task_complete:
		return
	task_complete = true
	var price: int = gameplay.inventory.products[target_product].price_rappen
	gameplay.story_flags[StringName("price_check_night_%d" % (gameplay.career_shifts+1))] = true
	_clear_task_point()
	_show_carried_prop(&"note")
	world._say("Shelf tag checked: %s · CHF %.2f. Tell the customer." % [gameplay.inventory.products[target_product].display_name,float(price)/100.0],6.0)
	gameplay.changed.emit()
	world._update_objective()

func _repeat_request() -> void:
	match request_kind:
		&"wc_key":
			world._say("Customer: The restroom key should be with the staff supplies.",5.0)
		&"price_check":
			world._say("Customer: Could you check the price tag on the %s?" % gameplay.inventory.products[target_product].display_name,5.0)
		&"fuel_receipt":
			world._say("Customer: I need the receipt for Pump %02d." % target_pump,5.0)

func _finish_request() -> void:
	if not active or not task_complete or not is_instance_valid(request_customer):
		return
	request_customer.state = &"queued"
	request_customer.status_text = "Waiting at checkout"
	gameplay.story_flags[StringName("customer_request_night_%d" % (gameplay.career_shifts+1))] = true
	match request_kind:
		&"wc_key":
			world._say("Customer: Perfect, thanks. I'll bring the key back on my way out.",5.0)
		&"price_check":
			world._say("Customer: Thanks for checking. That's the price I saw.",5.0)
		&"fuel_receipt":
			world._say("Customer: That's the one. Thanks.",4.0)
	_clear_all()
	completed = true
	gameplay.changed.emit()
	world._update_objective()

func objective_text() -> String:
	if not active:
		return ""
	if task_complete:
		return "Return to the customer at the till"
	match request_kind:
		&"wc_key":
			return "Get the restroom key from staff supplies"
		&"price_check":
			return "Check the %s" % request_label
		&"fuel_receipt":
			return "Print the %s at the pump terminal" % request_label
	return "Help the waiting customer"

func blocks_checkout() -> bool:
	return active and is_instance_valid(request_customer) and not gameplay.queue.is_empty() and gameplay.queue[0] == request_customer

func _price_text(id: StringName) -> String:
	var product = gameplay.inventory.products[id]
	return "%s\nCHF %.2f" % [product.display_name,float(product.price_rappen)/100.0]

func _show_carried_prop(kind: StringName) -> void:
	_clear_carried_prop()
	carried_prop = Node3D.new()
	carried_prop.name = "CustomerRequestItem"
	player.add_child(carried_prop)
	carried_prop.position = Vector3(0.30,0.72,0.05)
	carried_prop.rotation = Vector3(0,-0.22,0.08)
	match kind:
		&"key":
			var ring := MeshInstance3D.new()
			var mesh := TorusMesh.new()
			mesh.inner_radius = 0.055
			mesh.outer_radius = 0.075
			mesh.rings = 12
			mesh.ring_segments = 8
			ring.mesh = mesh
			ring.rotation.x = PI/2.0
			ring.material_override = _material(Color("b9a36d"),0.45)
			carried_prop.add_child(ring)
			_box(carried_prop,Vector3(0.10,0,0),Vector3(0.16,0.025,0.04),Color("b9a36d"))
		&"receipt":
			_box(carried_prop,Vector3.ZERO,Vector3(0.22,0.018,0.34),Color("e3dcc8"))
			var label := Label3D.new()
			label.text = "PUMP %02d\nFUEL RECEIPT" % target_pump
			label.position = Vector3(0,0.012,0)
			label.font_size = 10
			label.pixel_size = 0.0019
			label.modulate = Color("2a3232")
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			carried_prop.add_child(label)
		_:
			_box(carried_prop,Vector3.ZERO,Vector3(0.22,0.018,0.16),Color("d5c68b"))

func _clear_all() -> void:
	active = false
	task_complete = false
	if is_instance_valid(layout.customer_service_key):
		layout.customer_service_key.available = false
	_clear_task_point()
	_clear_carried_prop()
	request_customer = null
	request_kind = &""
	target_product = &""
	target_pump = 0
	request_label = ""
	if is_instance_valid(world.pump_service):
		world.pump_service._update_terminal_prompt()

func _clear_task_point() -> void:
	if is_instance_valid(task_point):
		task_point.queue_free()
	task_point = null
	if is_instance_valid(price_tag_visual):
		price_tag_visual.queue_free()
	price_tag_visual = null

func _clear_carried_prop() -> void:
	if is_instance_valid(carried_prop):
		carried_prop.queue_free()
	carried_prop = null

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = _material(color,0.78)
	parent.add_child(visual)
	return visual

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _exit_tree() -> void:
	_clear_task_point()
	_clear_carried_prop()
