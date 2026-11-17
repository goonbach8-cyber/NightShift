extends Node
## In-world checkout interaction. The inventory/sale rules remain in night_shift_loop.gd;
## this node only turns each scan into a short physical interaction at the counter.
const STYLE = preload("res://scripts/ui/station_theme.gd")
const START_X := -0.56
const SCANNER_X := -0.02

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D
var camera: Camera3D
var active := false
var phase: StringName = &"idle"
var busy := false
var current_id: StringName = &""
var current_visual: Node3D
var current_barcode_angle := 0.0
var slide := START_X
var item_rotation := 0.0
var placed_count := 0
var placed_items: Array[Node3D] = []
var customer: CharacterBody3D
var previous_camera_size := 8.5
var previous_camera_position := Vector3.ZERO
var camera_tween: Tween
var session := 0
var feedback_text := ""
var feedback_remaining := 0.0


var counter_root: Node3D
var scanner_plate: MeshInstance3D
var scanner_material: StandardMaterial3D
var terminal_label: MeshInstance3D
var card_root: Node3D
var card_material: StandardMaterial3D
var receipt_root: Node3D
var receipt_label: MeshInstance3D
var cash_root: Node3D
var cash_note_root: Node3D
var cash_note_label: MeshInstance3D
var change_tray: Node3D
var change_visuals: Array[Node3D] = []
var cash_materials: Array[StandardMaterial3D] = []
var cash_selection := 0
var cash_added := 0
var cash_due := 0
var cash_given := 0
var cash_history: Array[int] = []
var card_attempts := 0
var card_decline_pending := false
var printer_jam_pending := false
var printer_alignment := 0.0
var pending_receipt_total := 0
var pending_receipt_method := ""
const CASH_VALUES: Array[int] = [200,100,50,20,10,5]

var panel: PanelContainer
var title: Label
var status: Label
var progress: Label
var help: Label
var beep: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	camera = player.get_node("CameraRig/Camera3D")
	_build_counter()
	_build_ui()
	beep = AudioStreamPlayer.new()
	beep.bus = &"SFX"
	beep.volume_db = -8
	beep.stream = _make_beep()
	add_child(beep)
	set_process(true)

func _build_counter() -> void:
	counter_root = Node3D.new()
	counter_root.name = "CheckoutInteraction"
	layout.checkout.add_child(counter_root)

	# A low scanner plate remains in the world even outside the focused interaction.
	scanner_plate = _box(counter_root,Vector3(SCANNER_X,1.078,0.19),Vector3(0.30,0.025,0.28),Color("1b292b"))
	scanner_material = StandardMaterial3D.new()
	scanner_material.albedo_color = Color("713d39")
	scanner_material.roughness = 0.55
	scanner_plate.material_override = scanner_material
	_box(counter_root,Vector3(SCANNER_X,1.095,0.19),Vector3(0.24,0.008,0.025),Color("b4554e"))

	# Subtle staging mats explain left-to-right movement without becoming an arcade UI.
	_box(counter_root,Vector3(-0.53,1.072,0.19),Vector3(0.34,0.012,0.34),Color("394543"))
	_box(counter_root,Vector3(0.54,1.072,0.19),Vector3(0.38,0.012,0.34),Color("394543"))

	# A fixed LCD belongs to the payment pad, readable from the operator side.
	terminal_label = preload("res://scripts/printed_surface.gd").make(counter_root,"",Vector3(0.56,1.241,0.09),Vector2(0.15,0.095),Color("cbe3a7"),Color("182b27"),true)
	terminal_label.name = "CardTerminalReadout"
	terminal_label.hide()
	card_root = Node3D.new()
	card_root.name = "CustomerCard"
	card_root.position = Vector3(-0.18,1.06,-0.13)
	card_root.rotation.z = -0.10
	card_root.visible = false
	counter_root.add_child(card_root)
	var card := _box(card_root,Vector3.ZERO,Vector3(0.20,0.012,0.12),Color("405b66"))
	card_material = StandardMaterial3D.new()
	card_material.albedo_color = Color("405b66")
	card_material.roughness = 0.46
	card.material_override = card_material
	_box(card_root,Vector3(-0.07,0.012,0.015),Vector3(0.055,0.006,0.045),Color("c7b782"))

	receipt_root = Node3D.new()
	receipt_root.name = "Receipt"
	receipt_root.position = Vector3(-0.55,1.10,-0.27)
	receipt_root.visible = false
	counter_root.add_child(receipt_root)
	_box(receipt_root,Vector3.ZERO,Vector3(0.16,0.008,0.22),Color("e5dfce"))
	receipt_label = preload("res://scripts/printed_surface.gd").make(receipt_root,"",Vector3(0,0.006,0),Vector2(0.145,0.20),Color("263235"),Color("e5dfce"),true)
	cash_root = Node3D.new()
	cash_root.name = "CashTray"
	cash_root.position = Vector3(0.40,1.075,-0.02)
	cash_root.visible = false
	counter_root.add_child(cash_root)
	for i in CASH_VALUES.size():
		var coin := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.055 + i*0.004
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.014
		mesh.radial_segments = 16
		coin.mesh = mesh
		coin.position = Vector3(-0.30+i*0.12,0,0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("9a9072")
		mat.metallic = 0.35
		mat.roughness = 0.48
		coin.material_override = mat
		cash_materials.append(mat)
		cash_root.add_child(coin)
		preload("res://scripts/printed_surface.gd").make(cash_root,_money(CASH_VALUES[i]),Vector3(-0.30+i*0.12,0.010,0),Vector2(0.082,0.056),Color("37372d"),Color("a99b79"),true)
	_update_cash_selection()
	change_tray = Node3D.new()
	change_tray.name = "ChangeHandoverTray"
	change_tray.position = Vector3(0.43,1.055,0.33)
	counter_root.add_child(change_tray)
	_box(change_tray,Vector3.ZERO,Vector3(0.40,0.018,0.28),Color("394543"))
	preload("res://scripts/printed_surface.gd").make(change_tray,"HAND OVER",Vector3(0,0.012,0.105),Vector2(0.32,0.055),Color("d0d7b5"),Color("394543"),true)
	change_tray.hide()

	cash_note_root = Node3D.new()
	cash_note_root.name = "CustomerCash"
	cash_note_root.position = Vector3(-0.43,1.075,-0.16)
	cash_note_root.visible = false
	counter_root.add_child(cash_note_root)
	_box(cash_note_root,Vector3.ZERO,Vector3(0.34,0.012,0.18),Color("a8b98e"))
	cash_note_label = preload("res://scripts/printed_surface.gd").make(cash_note_root,"",Vector3(0,0.008,0),Vector2(0.29,0.14),Color("24302c"),Color("a8b98e"),true)

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "CheckoutMicrogamePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.29
	panel.anchor_right = 0.71
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -176
	panel.offset_bottom = -28
	panel.offset_left = -70
	panel.offset_right = 70
	var column := STYLE.column(panel,5)
	title = STYLE.text(column,18,STYLE.ACCENT)
	status = STYLE.text(column,16)
	progress = STYLE.text(column,14,STYLE.MUTED)
	help = STYLE.text(column,13,STYLE.MUTED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func begin() -> bool:
	if active:
		return true
	if world.has_interaction_focus(self):
		return false
	if world.phase != world.Phase.ACTIVE or gameplay.dialogue.active or not layout.at_operator(player):
		return false
	active = true
	phase = &"waiting"
	busy = false
	_clear_item_visuals()
	if layout.has_method("set_checkout_product"):
		layout.set_checkout_product(&"",false)
	if not camera_tween or not camera_tween.is_running():
		previous_camera_size = camera.size
		previous_camera_position = camera.position
	session += 1
	feedback_remaining = 0.0
	if camera_tween: camera_tween.kill()
	var focus := counter_root.to_global(Vector3(0,1.15,0.12))
	var eye := focus+camera.global_basis.z*8.0
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(camera,"size",2.9,0.22)
	camera_tween.tween_property(camera,"position",camera.get_parent().to_local(eye),0.22)
	player.controls_locked = true
	player.velocity.x = 0
	player.velocity.z = 0
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	panel.show()
	terminal_label.hide()
	card_root.hide()
	receipt_root.hide()
	cash_root.hide()
	cash_note_root.hide()
	_clear_change_visuals()
	cash_added = 0
	cash_history.clear()
	_try_next_customer()
	_refresh_ui()
	world._update_objective()
	return true

func _try_next_customer() -> void:
	if phase != &"waiting" or not gameplay.checkout_ready(): return
	# Let existing assistance systems present their real request before a basket.
	active = false
	var needs_help: bool = world.customer_requests.handle_checkout_use() or world.customer_assistance.handle_checkout_use()
	active = true
	if needs_help:
		_end_mode()
		return
	session += 1
	customer = gameplay.queue[0]
	customer.state = &"checkout"
	customer.status_text = "Being served"
	customer.attention_target = layout.checkout
	customer.react(&"greet")
	phase = &"scan"
	busy = false
	placed_count = int(gameplay.checkout_details().get("scanned",0))
	customer.set_checkout_basket_hidden(true)
	if int(gameplay.checkout_details().get("remaining",0)) <= 0: _enter_payment()
	else: _spawn_next_item()

func _finish_transaction() -> void:
	session += 1
	_clear_item_visuals()
	for prop in [terminal_label,card_root,receipt_root,cash_root,change_tray,cash_note_root]: prop.hide()
	_clear_change_visuals()
	current_id = &""
	customer = null
	phase = &"waiting"
	busy = false
	feedback_remaining = 0.0
	_refresh_ui()

func cancel() -> void:
	if not active or phase in [&"receipt",&"printer_jam"]:
		return
	# Scans are only staged until payment. Leaving the focused checkout restarts
	# the basket cleanly instead of leaving invisible partial scan state behind.
	if is_instance_valid(customer) and gameplay.scanned_owner == customer.get_instance_id():
		gameplay.scanned_owner = 0
		gameplay.scanned_units = 0
		if layout.has_method("set_checkout_product"):
			layout.set_checkout_product(&"",false)
		gameplay.changed.emit()
	if is_instance_valid(customer):
		if not customer.paid:
			customer.state = &"queued"
			customer.status_text = "Waiting at checkout"
		if customer.has_method("set_checkout_basket_hidden"):
			customer.set_checkout_basket_hidden(false)
	_end_mode()

func _process(delta: float) -> void:
	if not active:
		return
	if phase == &"waiting":
		if world.cashier_should_yield():
			cancel()
			return
		_try_next_customer()
	elif phase not in [&"receipt",&"printer_jam"] and (gameplay.queue.is_empty() or not is_instance_valid(customer) or gameplay.queue[0] != customer):
		cancel()
		return
	_refresh_ui()
	feedback_remaining = maxf(0,feedback_remaining-delta)
	if feedback_remaining > 0:
		status.text = feedback_text

func _input(event: InputEvent) -> void:
	if not active or world.has_interaction_focus(self):
		return
	if event is InputEventMouse:
		_pointer_input(event)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key: Key = event.physical_keycode
	var pressed: bool = event.pressed and not event.echo
	if pressed and key == KEY_ESCAPE:
		cancel()
	elif pressed and key == KEY_F and phase in [&"scan",&"waiting"] and not busy:
		cancel()
		gameplay.talk()
	elif phase == &"scan" and pressed and key in [KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
		_scan_current()
	elif phase == &"printer_jam":
		if not pressed:
			return
		if key in [KEY_LEFT,KEY_A]:
			printer_alignment = clampf(printer_alignment-0.1,-0.6,0.6)
			_apply_printer_alignment()
		elif key in [KEY_RIGHT,KEY_D]:
			printer_alignment = clampf(printer_alignment+0.1,-0.6,0.6)
			_apply_printer_alignment()
		elif key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:
			_feed_printer()
		else:
			return
	elif phase == &"cash":
		if not pressed:
			return
		if key >= KEY_1 and key <= KEY_6:
			cash_selection = key-KEY_1
			_update_cash_selection()
			_add_cash(CASH_VALUES[cash_selection])
		elif key in [KEY_LEFT,KEY_A]:
			cash_selection = wrapi(cash_selection-1,0,CASH_VALUES.size())
			_update_cash_selection()
		elif key in [KEY_RIGHT,KEY_D]:
			cash_selection = wrapi(cash_selection+1,0,CASH_VALUES.size())
			_update_cash_selection()
		elif key == KEY_E:
			_add_cash(CASH_VALUES[cash_selection])
		elif key == KEY_BACKSPACE:
			_remove_cash()
		elif key in [KEY_ENTER,KEY_KP_ENTER]:
			_confirm_cash()
		else:
			return
	elif phase == &"card_retry" and pressed:
		if key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:
			phase = &"card"
			_tap_card()
		elif key == KEY_C:
			_enter_cash(int(gameplay.checkout_details().get("total",0)))
		else:
			return
	elif pressed and key in [KEY_E,KEY_ENTER,KEY_KP_ENTER] and phase == &"card":
		_tap_card()
	elif key in [KEY_F,KEY_TAB,KEY_T,KEY_Y,KEY_SPACE,KEY_1,KEY_2,KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_BACKSPACE,KEY_C]:
		# Work/dialogue shortcuts must not leak into the world during checkout focus.
		pass
	else:
		return
	get_viewport().set_input_as_handled()

func _near(screen: Vector2, node: Node3D, offset: Vector3, radius: float) -> bool:
	if not is_instance_valid(node) or not node.is_visible_in_tree(): return false
	var center := node.to_global(offset)
	var edge := center+camera.global_basis.x*radius
	return screen.distance_to(camera.unproject_position(center)) <= maxf(12.0,camera.unproject_position(edge).distance_to(camera.unproject_position(center)))

func _pointer_input(event: InputEventMouse) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				return
			if phase == &"scan" and not busy and _near(event.position,current_visual,Vector3(0,0.15,0),0.23):
				_scan_current()
			elif phase in [&"card",&"card_retry"] and _near(event.position,card_root,Vector3.ZERO,0.22):
				phase = &"card"
				_tap_card()
			elif phase == &"cash" and not busy:
				for i in CASH_VALUES.size():
					if _near(event.position,cash_root,Vector3(-0.30+i*0.12,0,0),0.055):
						cash_selection = i
						_update_cash_selection()
						_add_cash(CASH_VALUES[i])
						return
				if _near(event.position,counter_root,Vector3(0.43,1.055,0.28),0.18):
					_confirm_cash()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			if phase == &"cash": _remove_cash()
			return
	elif event is InputEventMouseMotion and phase == &"cash":
		for i in CASH_VALUES.size():
			if _near(event.position,cash_root,Vector3(-0.30+i*0.12,0,0),0.055):
				cash_selection = i
				_update_cash_selection()
				break

func _spawn_next_item() -> void:
	var detail: Dictionary = gameplay.checkout_details()
	var next_id: StringName = detail.get("next_id",&"")
	if next_id == &"":
		_enter_payment()
		return
	current_id = next_id
	slide = START_X
	item_rotation = 0.0
	current_visual = _product_visual(current_id)
	# Routine products arrive ready to scan; rotation is a correction, not a
	# mandatory repeated search for a barcode on every identical bottle.
	item_rotation = wrapf(-current_barcode_angle,-PI,PI)
	current_visual.position = Vector3(slide,1.11,0.19)
	current_visual.rotation.y = item_rotation
	counter_root.add_child(current_visual)

func _product_visual(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Current_"+String(id)
	var material := StandardMaterial3D.new()
	material.roughness = 0.72
	var model = preload("res://scripts/product_display.gd").new()
	root.add_child(model)
	var barcode_radius := 0.09
	var barcode_y := 0.0
	match id:
		&"water":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.065
			mesh.bottom_radius = 0.08
			mesh.height = 0.25
			mesh.radial_segments = 12
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.position.y = 0.125
			material.albedo_color = Color("7d9670")
			visual.material_override = material
			root.add_child(visual)
			var neck := CylinderMesh.new()
			neck.top_radius = 0.038
			neck.bottom_radius = 0.064
			neck.height = 0.075
			neck.radial_segments = 12
			model.part(root,neck,Vector3(0,0.286,0),Color("7d9670"))
			var cap := CylinderMesh.new()
			cap.top_radius = 0.044
			cap.bottom_radius = 0.044
			cap.height = 0.033
			cap.radial_segments = 12
			model.part(root,cap,Vector3(0,0.335,0),Color("d7ddbe"))
			current_barcode_angle = PI
			barcode_radius = 0.082
			barcode_y = 0.18
		&"energy":
			model.energy_can(root,Vector3(0,0.132,0))
			current_barcode_angle = PI/2.0
			barcode_radius = 0.081
			barcode_y = 0.12
		&"chips":
			model.chip_packet(root,Vector3(0,0.164,0))
			current_barcode_angle = 0.0
			barcode_radius = 0.093
			barcode_y = 0.15
		_:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.20,0.20,0.16)
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.position.y = 0.10
			material.albedo_color = Color("8b8878")
			visual.material_override = material
			root.add_child(visual)
			current_barcode_angle = 0.0
			barcode_y = 0.10
	_add_barcode(root,current_barcode_angle,barcode_radius,barcode_y)
	return root

func _add_barcode(parent: Node3D, angle: float, radius: float, y: float) -> void:
	var barcode := Node3D.new()
	barcode.name = "Barcode"
	barcode.position = Vector3(sin(angle)*radius,y,cos(angle)*radius)
	barcode.rotation.y = angle
	parent.add_child(barcode)
	for i in range(5):
		var width := 0.004 if i%2 == 0 else 0.002
		_box(barcode,Vector3(-0.022+i*0.011,0,0.001),Vector3(width,0.035,0.001),Color("172124"))

func _apply_item_transform() -> void:
	if not is_instance_valid(current_visual):
		return
	current_visual.position.x = slide
	current_visual.position.y = 1.11
	current_visual.rotation.y = item_rotation

func _scan_current() -> void:
	if not active or phase != &"scan" or busy or not is_instance_valid(current_visual):
		return
	busy = true
	var scan_session := session
	var scanned_id := current_id
	var item := current_visual
	current_visual = null
	if not gameplay.checkout():
		current_visual = item
		busy = false
		return
	if layout.has_method("set_checkout_product"):
		layout.set_checkout_product(&"",false)
	beep.play()
	var target := _placed_position(placed_count)
	var tween := create_tween()
	scanner_material.albedo_color = Color("79b797")
	tween.tween_property(item,"position",Vector3(SCANNER_X,1.14,0.19),0.09)
	tween.tween_property(item,"position",target,0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(item,"scale",Vector3.ONE*0.55,0.11)
	await tween.finished
	if not active or session != scan_session or phase != &"scan" or not is_instance_valid(item):
		if is_instance_valid(item): item.queue_free()
		return
	placed_items.append(item)
	if placed_items.size() > 4: placed_items[-5].hide()
	placed_count += 1
	status.text = String(gameplay.inventory.products[scanned_id].display_name)+" scanned"
	busy = false
	scanner_material.albedo_color = Color("394543")
	if int(gameplay.checkout_details().get("remaining",0)) <= 0:
		_enter_payment()
	else:
		_spawn_next_item()

func _placed_position(index: int) -> Vector3:
	var column := index%2
	var row := int((index%4)/2)
	return Vector3(0.40+column*0.19,1.10,0.55+row*0.20)

func _enter_payment() -> void:
	busy = false
	feedback_remaining = 0.0
	if is_instance_valid(current_visual):
		current_visual.queue_free()
		current_visual = null
	var detail: Dictionary = gameplay.checkout_details()
	var transaction_number: int = gameplay.served+gameplay.lost_sales+1
	card_attempts = 0
	card_decline_pending = gameplay.career_shifts >= 1 and transaction_number % 5 == 0
	printer_jam_pending = gameplay.career_shifts >= 2 and transaction_number % 4 == 0
	if transaction_number % 3 == 0:
		_enter_cash(int(detail.get("total",0)))
	else:
		phase = &"card"
		terminal_label.text = "CARD\nCHF %.2f" % (float(detail.get("total",0))/100.0)
		terminal_label.modulate = Color("cbe3a7")
		terminal_label.show()
		card_material.albedo_color = Color("405b66")
		card_root.position = Vector3(-0.18,1.06,-0.13)
		card_root.show()
		cash_root.hide()
		cash_note_root.hide()
	scanner_material.albedo_color = Color("394543")
	_refresh_ui()

func _tap_card() -> void:
	if busy or phase != &"card": return
	busy = true
	var tap_session := session
	var tap := create_tween()
	tap.tween_property(card_root,"position",Vector3(0.56,1.27,0.09),0.18)
	await tap.finished
	if not active or session != tap_session: return
	busy = false
	_confirm_payment()
	if phase == &"card_retry":
		card_root.position = Vector3(-0.18,1.06,-0.13)

func _enter_cash(total: int) -> void:
	phase = &"cash"
	terminal_label.hide()
	card_root.hide()
	cash_due = total
	cash_given = _cash_tender(total)
	cash_added = 0
	cash_history.clear()
	_clear_change_visuals()
	cash_selection = 0
	cash_note_label.text = _money(cash_given)
	cash_note_root.show()
	cash_root.show()
	change_tray.show()
	_update_cash_selection()

func _cash_tender(total: int) -> int:
	var notes := [500,1000,2000,5000,10000]
	for amount in notes:
		if amount > total:
			return amount
	return int(ceil(float(total)/10000.0))*10000+10000

func _add_cash(value: int) -> void:
	if phase != &"cash" or busy:
		return
	cash_added += value
	feedback_remaining = 0.0
	cash_history.append(value)
	_spawn_change_coin(value)
	_refresh_ui()

func _remove_cash() -> void:
	if phase != &"cash" or cash_history.is_empty():
		return
	cash_added -= cash_history.pop_back()
	feedback_remaining = 0.0
	if not change_visuals.is_empty():
		var visual: Node3D = change_visuals.pop_back()
		if is_instance_valid(visual):
			visual.queue_free()
	_refresh_ui()

func _confirm_cash() -> void:
	if phase != &"cash" or busy:
		return
	var change := cash_given-cash_due
	if cash_added != change:
		_feedback("Change is "+("short" if cash_added < change else "too high")+" · need "+_money(change))
		return
	_confirm_payment()

func _update_cash_selection() -> void:
	for i in cash_materials.size():
		cash_materials[i].albedo_color = Color("c7b782") if i == cash_selection else Color("9a9072")

func _spawn_change_coin(value: int) -> void:
	var coin := MeshInstance3D.new()
	coin.name = "Change_"+str(value)
	var mesh := CylinderMesh.new()
	var index := maxi(0,CASH_VALUES.find(value))
	mesh.top_radius = 0.050+index*0.003
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.012
	mesh.radial_segments = 16
	coin.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b6aa86") if value >= 100 else Color("b07f62")
	material.metallic = 0.45
	material.roughness = 0.42
	coin.material_override = material
	var column := change_visuals.size()%4
	var row := int(change_visuals.size()/4)
	coin.position = Vector3(0.30+column*0.085,1.078,0.28-row*0.08)
	counter_root.add_child(coin)
	change_visuals.append(coin)

func _clear_change_visuals() -> void:
	for visual in change_visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	change_visuals.clear()

func _confirm_payment() -> void:
	if phase not in [&"card",&"cash"] or busy:
		return
	feedback_remaining = 0.0
	busy = true
	var detail: Dictionary = gameplay.checkout_details()
	if phase == &"card" and card_decline_pending and card_attempts == 0:
		card_attempts += 1
		if is_instance_valid(customer): customer.react(&"payment_failed")
		terminal_label.text = "DECLINED"
		terminal_label.modulate = Color("e38b78")
		card_material.albedo_color = Color("6b4248")
		phase = &"card_retry"
		busy = false
		_refresh_ui()
		return
	var total: int = int(detail.get("total",0))
	var paying_customer := customer
	if not gameplay.checkout():
		busy = false
		return
	if is_instance_valid(paying_customer) and paying_customer.has_method("clear_basket"):
		paying_customer.clear_basket()
	var method := "CARD" if phase == &"card" else "CASH"
	terminal_label.text = "APPROVED" if phase == &"card" else ""
	terminal_label.modulate = Color("cbe3a7")
	card_root.hide()
	cash_root.hide()
	change_tray.hide()
	cash_note_root.hide()
	pending_receipt_total = total
	pending_receipt_method = method
	if printer_jam_pending:
		_enter_printer_jam()
		return
	_print_receipt()

func _enter_printer_jam() -> void:
	phase = &"printer_jam"
	printer_alignment = -0.5 if (gameplay.served+gameplay.lost_sales)%2 == 0 else 0.5
	receipt_root.show()
	receipt_label.text = "PAPER"
	receipt_root.position = Vector3(0.47,1.10,-0.18)
	_apply_printer_alignment()
	_refresh_ui()

func _apply_printer_alignment() -> void:
	if not is_instance_valid(receipt_root):
		return
	receipt_root.rotation.y = printer_alignment*0.65

func _feed_printer() -> void:
	if phase != &"printer_jam":
		return
	if absf(printer_alignment) > 0.11:
		_feedback("Paper is still crooked in the feed slot.")
		return
	printer_jam_pending = false
	receipt_root.rotation.y = 0.0
	_print_receipt()

func _feedback(text: String) -> void:
	feedback_text = text
	feedback_remaining = 1.4
	status.text = text

func _print_receipt() -> void:
	var receipt_session := session
	feedback_remaining = 0.0
	phase = &"receipt"
	receipt_label.text = "NIGHTSHIFT\n%s\nCHF %.2f\nTHANK YOU" % [pending_receipt_method,float(pending_receipt_total)/100.0]
	receipt_root.show()
	var start := Vector3(-0.55,1.10,-0.27)
	receipt_root.position = start+Vector3(0,-0.10,0)
	var tween := create_tween()
	tween.tween_property(receipt_root,"position",start,0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.35).timeout
	if active and session == receipt_session and phase == &"receipt":
		_finish_transaction()

func _refresh_ui() -> void:
	if not active or not is_instance_valid(panel):
		return
	var detail: Dictionary = gameplay.checkout_details()
	if phase == &"scan":
		title.text = "CHECKOUT · SCAN"
		var name := String(gameplay.inventory.products[current_id].display_name) if current_id != &"" else "Item"
		status.text = "Scan "+name
		progress.text = "%d / %d scanned · CHF %.2f" % [detail.get("scanned",0),detail.get("count",0),float(detail.get("subtotal",0))/100.0]
		help.text = "Click product / E scan   ·   ESC leave workstation"
	elif phase == &"card":
		title.text = "CARD TERMINAL"
		status.text = "Present card · CHF %.2f" % (float(detail.get("total",0))/100.0)
		progress.text = "%d items scanned" % detail.get("count",0)
		help.text = "Click card / E confirm   ·   ESC leave"
	elif phase == &"cash":
		var change := cash_given-cash_due
		title.text = "CASH · CHANGE"
		status.text = "Customer gives %s · Return %s" % [_money(cash_given),_money(change)]
		progress.text = "Tray: %s / %s" % [_money(cash_added),_money(change)]
		help.text = "Click coins / 1–6   ·   right-click undo   ·   Enter hand over   ·   ESC leave"
	elif phase == &"card_retry":
		title.text = "CARD DECLINED"
		status.text = "Customer has another card."
		progress.text = "No sale has been charged."
		help.text = "Click card / E retry   ·   C pay cash   ·   ESC leave"
	elif phase == &"printer_jam":
		title.text = "RECEIPT PRINTER · PAPER JAM"
		status.text = "Straighten the receipt paper in the feed slot."
		progress.text = "Alignment: %d%%" % roundi((1.0-clampf(absf(printer_alignment)/0.6,0.0,1.0))*100.0)
		help.text = "← / → align paper   ·   [E / ENTER] feed paper"
	elif phase == &"waiting":
		title.text = "CASHIER · READY"
		status.text = "Waiting for the next basket."
		progress.text = ""
		help.text = "Remain here to serve arriving customers   ·   ESC leave"
	else:
		title.text = "PAYMENT APPROVED"
		status.text = "Receipt printing…"
		progress.text = ""
		help.text = ""

func _clear_item_visuals() -> void:
	if is_instance_valid(current_visual):
		current_visual.queue_free()
	current_visual = null
	for item in placed_items:
		if is_instance_valid(item):
			item.queue_free()
	placed_items.clear()

func _end_mode() -> void:
	session += 1
	_clear_item_visuals()
	active = false
	phase = &"idle"
	busy = false
	current_id = &""
	terminal_label.hide()
	card_root.hide()
	receipt_root.hide()
	cash_root.hide()
	change_tray.hide()
	cash_note_root.hide()
	_clear_change_visuals()
	cash_added = 0
	cash_history.clear()
	card_attempts = 0
	card_decline_pending = false
	printer_jam_pending = false
	printer_alignment = 0.0
	pending_receipt_total = 0
	pending_receipt_method = ""
	receipt_root.rotation = Vector3.ZERO
	panel.hide()
	scanner_material.albedo_color = Color("713d39")
	if camera_tween: camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(camera,"size",previous_camera_size,0.22)
	camera_tween.tween_property(camera,"position",previous_camera_position,0.22)
	player.controls_locked = world.has_interaction_focus(self)
	world._update_objective()

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	visual.material_override = material
	parent.add_child(visual)
	return visual

func _money(rappen: int) -> String:
	return "CHF %.2f" % (float(rappen)/100.0)

func _make_beep() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.11
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := sin(PI*float(i)/count)
		var sample := (sin(TAU*1180.0*t)*0.72+sin(TAU*1770.0*t)*0.18)*envelope
		bytes.encode_s16(i*2,int(clampf(sample,-1.0,1.0)*18000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
