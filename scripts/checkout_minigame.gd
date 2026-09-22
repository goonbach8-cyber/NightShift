extends Node
## In-world checkout interaction. The inventory/sale rules remain in night_shift_loop.gd;
## this node only turns each scan into a short physical interaction at the counter.
const STYLE = preload("res://scripts/ui/station_theme.gd")
const START_X := -0.56
const SCANNER_X := -0.02
const SCAN_HALF_WIDTH := 0.13
const SLIDE_MIN := -0.62
const SLIDE_MAX := 0.14
const SLIDE_SPEED := 0.78
const ROTATE_SPEED := 2.45
const ALIGN_TOLERANCE := deg_to_rad(48.0)

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

var move_left := false
var move_right := false
var rotate_left := false
var rotate_right := false

var counter_root: Node3D
var scanner_plate: MeshInstance3D
var scanner_material: StandardMaterial3D
var terminal_label: Label3D
var card_root: Node3D
var card_material: StandardMaterial3D
var receipt_root: Node3D
var receipt_label: Label3D
var cash_root: Node3D
var cash_note_root: Node3D
var cash_note_label: Label3D
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
	scanner_plate = _box(counter_root,Vector3(SCANNER_X,1.015,0.19),Vector3(0.30,0.025,0.28),Color("1b292b"))
	scanner_material = StandardMaterial3D.new()
	scanner_material.albedo_color = Color("713d39")
	scanner_material.roughness = 0.55
	scanner_plate.material_override = scanner_material
	_box(counter_root,Vector3(SCANNER_X,1.032,0.19),Vector3(0.24,0.008,0.025),Color("b4554e"))

	# Subtle staging mats explain left-to-right movement without becoming an arcade UI.
	_box(counter_root,Vector3(-0.53,1.012,0.19),Vector3(0.34,0.012,0.34),Color("394543"))
	_box(counter_root,Vector3(0.54,1.012,0.19),Vector3(0.38,0.012,0.34),Color("394543"))

	terminal_label = Label3D.new()
	terminal_label.name = "CardTerminalReadout"
	terminal_label.position = Vector3(0.0,1.43,-0.12)
	terminal_label.font_size = 22
	terminal_label.pixel_size = 0.0033
	terminal_label.modulate = Color("cbe3a7")
	terminal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	terminal_label.visible = false
	counter_root.add_child(terminal_label)

	card_root = Node3D.new()
	card_root.name = "CustomerCard"
	card_root.position = Vector3(-0.18,1.06,-0.13)
	card_root.rotation.z = -0.10
	card_root.visible = false
	counter_root.add_child(card_root)
	var card := _box(card_root,Vector3.ZERO,Vector3(0.28,0.018,0.18),Color("405b66"))
	card_material = StandardMaterial3D.new()
	card_material.albedo_color = Color("405b66")
	card_material.roughness = 0.46
	card.material_override = card_material
	_box(card_root,Vector3(-0.07,0.012,0.015),Vector3(0.055,0.006,0.045),Color("c7b782"))

	receipt_root = Node3D.new()
	receipt_root.name = "Receipt"
	receipt_root.position = Vector3(0.47,1.035,-0.18)
	receipt_root.visible = false
	counter_root.add_child(receipt_root)
	_box(receipt_root,Vector3.ZERO,Vector3(0.28,0.012,0.38),Color("e5dfce"))
	receipt_label = Label3D.new()
	receipt_label.position = Vector3(0,0.012,0.02)
	receipt_label.font_size = 12
	receipt_label.pixel_size = 0.0022
	receipt_label.modulate = Color("263235")
	receipt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	receipt_root.add_child(receipt_label)

	cash_root = Node3D.new()
	cash_root.name = "CashTray"
	cash_root.position = Vector3(0.40,1.04,-0.02)
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
		var label := Label3D.new()
		label.text = _money(CASH_VALUES[i])
		label.position = Vector3(-0.30+i*0.12,0.045,0)
		label.font_size = 12
		label.pixel_size = 0.0020
		label.modulate = Color("e7e2d4")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cash_root.add_child(label)
	_update_cash_selection()

	cash_note_root = Node3D.new()
	cash_note_root.name = "CustomerCash"
	cash_note_root.position = Vector3(-0.43,1.04,-0.16)
	cash_note_root.visible = false
	counter_root.add_child(cash_note_root)
	_box(cash_note_root,Vector3.ZERO,Vector3(0.34,0.012,0.18),Color("a8b98e"))
	cash_note_label = Label3D.new()
	cash_note_label.position = Vector3(0,0.015,0)
	cash_note_label.font_size = 13
	cash_note_label.pixel_size = 0.0022
	cash_note_label.modulate = Color("24302c")
	cash_note_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cash_note_root.add_child(cash_note_label)

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
	if not gameplay.checkout_ready() or gameplay.dialogue.active or not layout.at_operator(player):
		return false
	active = true
	phase = &"scan"
	busy = false
	customer = gameplay.queue[0]
	customer.state = &"checkout"
	customer.status_text = "Being served"
	placed_count = int(gameplay.checkout_details().get("scanned",0))
	_clear_item_visuals()
	if customer.has_method("set_checkout_basket_hidden"):
		customer.set_checkout_basket_hidden(true)
	if layout.has_method("set_checkout_product"):
		layout.set_checkout_product(&"",false)
	previous_camera_size = camera.size
	var zoom := create_tween()
	zoom.tween_property(camera,"size",minf(previous_camera_size,6.8),0.22)
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
	if int(gameplay.checkout_details().get("remaining",0)) <= 0:
		_enter_payment()
	else:
		_spawn_next_item()
	_refresh_ui()
	world._update_objective()
	return true

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
	if phase != &"receipt" and (gameplay.queue.is_empty() or not is_instance_valid(customer) or gameplay.queue[0] != customer):
		cancel()
		return
	if phase == &"scan" and not busy and is_instance_valid(current_visual):
		var horizontal := (1.0 if move_right else 0.0) - (1.0 if move_left else 0.0)
		var turning := (1.0 if rotate_right else 0.0) - (1.0 if rotate_left else 0.0)
		slide = clampf(slide+horizontal*SLIDE_SPEED*delta,SLIDE_MIN,SLIDE_MAX)
		item_rotation = wrapf(item_rotation+turning*ROTATE_SPEED*delta,-PI,PI)
		_apply_item_transform()
		var ready := _barcode_aligned() and absf(slide-SCANNER_X) <= SCAN_HALF_WIDTH
		scanner_material.albedo_color = Color("4f8a67") if ready else Color("713d39")
		if ready:
			_scan_current()
	_refresh_ui()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and phase == &"scan" and not busy and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		slide = clampf(slide+event.relative.x*0.0035,SLIDE_MIN,SLIDE_MAX)
		item_rotation = wrapf(item_rotation+event.relative.y*0.012,-PI,PI)
		_apply_item_transform()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and phase == &"scan":
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			item_rotation = wrapf(item_rotation-0.24,-PI,PI)
			_apply_item_transform()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			item_rotation = wrapf(item_rotation+0.24,-PI,PI)
			_apply_item_transform()
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventKey:
		return
	var key := event.physical_keycode
	var pressed := event.pressed and not event.echo
	if pressed and key == KEY_ESCAPE:
		cancel()
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
		if key in [KEY_LEFT,KEY_A]:
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
	elif key in [KEY_A,KEY_LEFT]:
		move_left = event.pressed
	elif key in [KEY_D,KEY_RIGHT]:
		move_right = event.pressed
	elif key in [KEY_W,KEY_UP]:
		rotate_left = event.pressed
	elif key in [KEY_S,KEY_DOWN]:
		rotate_right = event.pressed
	elif phase == &"card_retry" and pressed:
		if key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:
			phase = &"card"
			_confirm_payment()
		elif key == KEY_C:
			_enter_cash(int(gameplay.checkout_details().get("total",0)))
		else:
			return
	elif pressed and key in [KEY_E,KEY_ENTER,KEY_KP_ENTER] and phase == &"card":
		_confirm_payment()
	elif key in [KEY_F,KEY_TAB,KEY_T,KEY_Y,KEY_SPACE,KEY_1,KEY_2,KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_BACKSPACE,KEY_C]:
		# Work/dialogue shortcuts must not leak into the world during checkout focus.
		pass
	else:
		return
	get_viewport().set_input_as_handled()

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
	current_visual.position = Vector3(slide,1.11,0.19)
	current_visual.rotation.y = item_rotation
	counter_root.add_child(current_visual)

func _product_visual(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Current_"+String(id)
	var material := StandardMaterial3D.new()
	material.roughness = 0.72
	var barcode_radius := 0.09
	var barcode_y := 0.0
	match id:
		&"water":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.065
			mesh.bottom_radius = 0.08
			mesh.height = 0.36
			mesh.radial_segments = 12
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.position.y = 0.18
			material.albedo_color = Color("7d9670")
			visual.material_override = material
			root.add_child(visual)
			current_barcode_angle = PI
			barcode_radius = 0.082
			barcode_y = 0.18
		&"energy":
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.075
			mesh.bottom_radius = 0.075
			mesh.height = 0.25
			mesh.radial_segments = 12
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.position.y = 0.125
			material.albedo_color = Color("439d8d")
			visual.material_override = material
			root.add_child(visual)
			current_barcode_angle = PI/2.0
			barcode_radius = 0.078
			barcode_y = 0.12
		&"chips":
			var mesh := PrismMesh.new()
			mesh.size = Vector3(0.24,0.31,0.17)
			var visual := MeshInstance3D.new()
			visual.mesh = mesh
			visual.position.y = 0.155
			material.albedo_color = Color("c97435")
			visual.material_override = material
			root.add_child(visual)
			current_barcode_angle = 0.0
			barcode_radius = 0.09
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
	_box(barcode,Vector3.ZERO,Vector3(0.13,0.085,0.008),Color("e7e2d4"))
	for i in range(5):
		var width := 0.010 if i%2 == 0 else 0.006
		_box(barcode,Vector3(-0.045+i*0.022,0,0.006),Vector3(width,0.070,0.006),Color("172124"))

func _barcode_aligned() -> bool:
	var facing := wrapf(item_rotation+current_barcode_angle,-PI,PI)
	return absf(facing) <= ALIGN_TOLERANCE

func _apply_item_transform() -> void:
	if not is_instance_valid(current_visual):
		return
	current_visual.position.x = slide
	current_visual.rotation.y = item_rotation

func _scan_current() -> void:
	if busy or not is_instance_valid(current_visual):
		return
	busy = true
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
	tween.set_parallel(true)
	tween.tween_property(item,"position",target,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(item,"rotation:y",0.0,0.20)
	await tween.finished
	placed_items.append(item)
	placed_count += 1
	status.text = String(gameplay.inventory.products[scanned_id].display_name)+" scanned"
	busy = false
	if int(gameplay.checkout_details().get("remaining",0)) <= 0:
		_enter_payment()
	else:
		_spawn_next_item()

func _placed_position(index: int) -> Vector3:
	var column := index%2
	var row := int(index/2)
	return Vector3(0.45+column*0.16,1.10,0.26-row*0.14)

func _enter_payment() -> void:
	busy = false
	if is_instance_valid(current_visual):
		current_visual.queue_free()
		current_visual = null
	var detail: Dictionary = gameplay.checkout_details()
	var transaction_number := gameplay.served+gameplay.lost_sales+1
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
		card_root.show()
		cash_root.hide()
		cash_note_root.hide()
	scanner_material.albedo_color = Color("394543")
	_refresh_ui()

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
	cash_history.append(value)
	_spawn_change_coin(value)
	_refresh_ui()

func _remove_cash() -> void:
	if phase != &"cash" or cash_history.is_empty():
		return
	cash_added -= cash_history.pop_back()
	if not change_visuals.is_empty():
		var visual := change_visuals.pop_back()
		if is_instance_valid(visual):
			visual.queue_free()
	_refresh_ui()

func _confirm_cash() -> void:
	if phase != &"cash" or busy:
		return
	var change := cash_given-cash_due
	if cash_added != change:
		status.text = "Change is "+("short" if cash_added < change else "too high")+" · need "+_money(change)
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
	coin.position = Vector3(0.30+column*0.085,1.055,0.28-row*0.08)
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
	busy = true
	var detail: Dictionary = gameplay.checkout_details()
	if phase == &"card" and card_decline_pending and card_attempts == 0:
		card_attempts += 1
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
	receipt_root.position = Vector3(0.47,0.98,-0.18)
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
		status.text = "Paper is still crooked in the feed slot."
		return
	printer_jam_pending = false
	receipt_root.rotation.y = 0.0
	_print_receipt()

func _print_receipt() -> void:
	phase = &"receipt"
	receipt_label.text = "NIGHTSHIFT\n%s\nCHF %.2f\nTHANK YOU" % [pending_receipt_method,float(pending_receipt_total)/100.0]
	receipt_root.show()
	var start := Vector3(0.47,1.035,-0.18)
	receipt_root.position = start+Vector3(0,-0.10,0)
	var tween := create_tween()
	tween.tween_property(receipt_root,"position",start,0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.85).timeout
	_end_mode()

func _refresh_ui() -> void:
	if not active or not is_instance_valid(panel):
		return
	var detail: Dictionary = gameplay.checkout_details()
	if phase == &"scan":
		title.text = "CHECKOUT · SCAN"
		var name := String(gameplay.inventory.products[current_id].display_name) if current_id != &"" else "Item"
		status.text = "Move "+name+" across the scanner"
		if is_instance_valid(current_visual) and absf(slide-SCANNER_X) <= 0.24 and not _barcode_aligned():
			status.text = "Rotate "+name+" — barcode is not facing the scanner"
		progress.text = "%d / %d scanned" % [detail.get("scanned",0),detail.get("count",0)]
		help.text = "A / D move   ·   W / S rotate   ·   drag mouse   ·   wheel rotates"
	elif phase == &"card":
		title.text = "CARD TERMINAL"
		status.text = "Present card · CHF %.2f" % (float(detail.get("total",0))/100.0)
		progress.text = "%d items scanned" % detail.get("count",0)
		help.text = "[E / ENTER]  Confirm card payment"
	elif phase == &"cash":
		var change := cash_given-cash_due
		title.text = "CASH · CHANGE"
		status.text = "Customer gives %s · Return %s" % [_money(cash_given),_money(change)]
		progress.text = "Tray: %s / %s" % [_money(cash_added),_money(change)]
		help.text = "← / → choose coin   ·   E add   ·   Backspace undo   ·   Enter confirm"
	elif phase == &"card_retry":
		title.text = "CARD DECLINED"
		status.text = "Customer has another card."
		progress.text = "No sale has been charged."
		help.text = "[E / ENTER] Try another card   ·   [C] Pay cash"
	elif phase == &"printer_jam":
		title.text = "RECEIPT PRINTER · PAPER JAM"
		status.text = "Straighten the receipt paper in the feed slot."
		progress.text = "Alignment: %d%%" % roundi((1.0-clampf(absf(printer_alignment)/0.6,0.0,1.0))*100.0)
		help.text = "← / → align paper   ·   [E / ENTER] feed paper"
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
	_clear_item_visuals()
	active = false
	phase = &"idle"
	busy = false
	current_id = &""
	terminal_label.hide()
	card_root.hide()
	receipt_root.hide()
	cash_root.hide()
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
	move_left = false
	move_right = false
	rotate_left = false
	rotate_right = false
	var restore := create_tween()
	restore.tween_property(camera,"size",previous_camera_size,0.22)
	player.controls_locked = gameplay.dialogue.active
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
