extends Node
## Small diegetic fuel-pump workflow. Requests arrive from the forecourt,
## the player authorizes the correct dispenser and prepay limit from the till.
const STYLE = preload("res://scripts/ui/station_theme.gd")
const PRESETS: Array[int] = [3000,5000,8000]
const PUMP_POSITIONS := {
	1: Vector3(-2.9,0,7.25),
	2: Vector3(-2.9,0,9.15),
	3: Vector3(2.9,0,7.25),
	4: Vector3(2.9,0,9.15)
}

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var request_pending := false
var request_pump := 0
var request_limit := 0
var selected_pump := 1
var selected_limit_index := 0
var requests_completed := 0
var next_request_at := 26.0
var max_requests := 2
var request_serial := 0
var busy := false
var fault_pending := false
var fault_pump := 0

var vehicle_root: Node3D
var pump_labels: Dictionary = {}
var panel: PanelContainer
var title: Label
var status: Label
var details: Label
var help: Label
var confirm_sound: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	_build_forecourt_feedback()
	_build_ui()
	confirm_sound = AudioStreamPlayer.new()
	confirm_sound.bus = &"SFX"
	confirm_sound.volume_db = -10
	confirm_sound.stream = _tone()
	add_child(confirm_sound)
	set_process(true)
	_update_terminal_prompt()

func _build_forecourt_feedback() -> void:
	var station: Node3D = world.get_node("Station")
	for pump in range(1,5):
		var label := Label3D.new()
		label.name = "PumpStatus%02d" % pump
		label.position = PUMP_POSITIONS[pump]+Vector3(0,1.30,0.43)
		label.font_size = 15
		label.pixel_size = 0.003
		label.modulate = Color("8fa9a2")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.text = "READY"
		station.add_child(label)
		pump_labels[pump] = label

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "PumpServicePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.31
	panel.anchor_right = 0.69
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -170
	panel.offset_bottom = -28
	var column := STYLE.column(panel,5)
	title = STYLE.text(column,18,STYLE.ACCENT)
	status = STYLE.text(column,17)
	details = STYLE.text(column,14,STYLE.MUTED)
	help = STYLE.text(column,13,STYLE.MUTED)
	for label in [title,status,details,help]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func _process(_delta: float) -> void:
	if gameplay == null or not gameplay.active:
		return
	if not request_pending and requests_completed < max_requests and gameplay.elapsed >= next_request_at and world.can_start_interrupt(self):
		_create_request()

func _create_request() -> void:
	request_serial += 1
	request_pump = ((gameplay.career_shifts*2 + request_serial*3) % 4)+1
	request_limit = PRESETS[(gameplay.career_shifts+request_serial) % PRESETS.size()]
	request_pending = true
	fault_pending = false
	fault_pump = 0
	_set_reset_availability(0)
	selected_pump = 1
	selected_limit_index = 0
	_spawn_vehicle(request_pump)
	_set_pump_status(request_pump,"WAIT",Color("d4b46f"))
	_update_terminal_prompt()
	world._say("Fuel request · Pump %02d · Prepay %s" % [request_pump,_money(request_limit)],6.0)
	gameplay.changed.emit()

func begin() -> bool:
	if active:
		return true
	if not gameplay.active or world.phase != world.Phase.ACTIVE:
		world._say("Pump control is available during the shift.")
		return false
	if not request_pending:
		world._say("No fuel requests are waiting.")
		return false
	if world.gameplay.dialogue.active:
		return false
	active = true
	busy = false
	selected_pump = request_pump
	selected_limit_index = PRESETS.find(request_limit)
	if selected_limit_index < 0:
		selected_limit_index = 0
	player.controls_locked = true
	player.velocity.x = 0
	player.velocity.z = 0
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	panel.show()
	_refresh_ui()
	world._update_objective()
	return true

func cancel() -> void:
	if not active or busy:
		return
	_end_mode()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
		return
	var pressed := event.pressed and not event.echo
	if not pressed:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			cancel()
		KEY_LEFT, KEY_A:
			selected_pump = 4 if selected_pump <= 1 else selected_pump-1
			_refresh_ui()
		KEY_RIGHT, KEY_D:
			selected_pump = 1 if selected_pump >= 4 else selected_pump+1
			_refresh_ui()
		KEY_UP, KEY_W:
			selected_limit_index = wrapi(selected_limit_index+1,0,PRESETS.size())
			_refresh_ui()
		KEY_DOWN, KEY_S:
			selected_limit_index = wrapi(selected_limit_index-1,0,PRESETS.size())
			_refresh_ui()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_authorize()
		_:
			return
	get_viewport().set_input_as_handled()

func _authorize() -> void:
	if busy or not request_pending:
		return
	if selected_pump != request_pump:
		status.text = "Pump %02d has no waiting vehicle." % selected_pump
		return
	if PRESETS[selected_limit_index] != request_limit:
		status.text = "Wrong prepay limit · customer requested %s." % _money(request_limit)
		return
	busy = true
	confirm_sound.play()
	status.text = "AUTHORIZED · Pump %02d" % request_pump
	details.text = "%s limit sent to dispenser" % _money(request_limit)
	help.text = ""
	_set_pump_status(request_pump,"AUTH",Color("8fc59d"))
	await get_tree().create_timer(0.75).timeout
	var should_fault := gameplay.career_shifts >= 1 and request_serial % 2 == 0
	if should_fault:
		_begin_fault(request_pump)
	else:
		_complete_request()

func _begin_fault(pump: int) -> void:
	fault_pending = true
	fault_pump = pump
	_set_pump_status(pump,"FAULT",Color("d67c69"))
	_set_reset_availability(pump)
	_update_terminal_prompt()
	_end_mode()
	world._say("Pump %02d fault · Reset the dispenser outside." % pump,6.0)
	gameplay.changed.emit()

func reset_fault(pump: int) -> bool:
	if not fault_pending or pump != fault_pump:
		world._say("This dispenser is operating normally.")
		return false
	fault_pending = false
	fault_pump = 0
	_set_reset_availability(0)
	_set_pump_status(pump,"READY",Color("8fa9a2"))
	world._say("Pump %02d reset. Fuel authorization restored." % pump,4.0)
	_complete_request()
	return true

func _set_reset_availability(pump: int) -> void:
	if not is_instance_valid(layout):
		return
	for id in layout.pump_reset_points:
		layout.pump_reset_points[id].available = int(id) == pump

func _complete_request() -> void:
	var completed_pump := request_pump
	request_pending = false
	fault_pending = false
	fault_pump = 0
	_set_reset_availability(0)
	requests_completed += 1
	request_pump = 0
	request_limit = 0
	next_request_at = gameplay.elapsed + 38.0 + float((requests_completed+gameplay.career_shifts)%3)*9.0
	_set_pump_status(completed_pump,"READY",Color("8fa9a2"))
	_remove_vehicle()
	_update_terminal_prompt()
	_end_mode()
	world._say("Pump %02d authorized." % completed_pump,3.0)
	gameplay.changed.emit()

func _refresh_ui() -> void:
	if not active:
		return
	title.text = "FORECOURT · PUMP CONTROL"
	status.text = "Request: Pump %02d · %s" % [request_pump,_money(request_limit)]
	details.text = "Selected: Pump %02d · %s" % [selected_pump,_money(PRESETS[selected_limit_index])]
	help.text = "← / → pump   ·   ↑ / ↓ prepay limit   ·   [E / ENTER] authorize   ·   ESC close"

func _update_terminal_prompt() -> void:
	if not is_instance_valid(layout.pump_terminal):
		return
	if fault_pending:
		layout.pump_terminal.prompt = "Pump %02d fault · Reset outside" % fault_pump
	elif request_pending:
		layout.pump_terminal.prompt = "Pump %02d awaiting authorization" % request_pump
	else:
		layout.pump_terminal.prompt = "Fuel pump control · No requests"

func _spawn_vehicle(pump: int) -> void:
	_remove_vehicle()
	vehicle_root = Node3D.new()
	vehicle_root.name = "FuelCustomerVehicle"
	world.get_node("Station").add_child(vehicle_root)
	vehicle_root.position = PUMP_POSITIONS[pump]+Vector3(0.95,0,0)
	var model = preload("res://scripts/product_display.gd").new()
	vehicle_root.add_child(model)
	model.box(model,Vector3(0,0.38,0),Vector3(1.55,0.48,0.78),Color("495c62"))
	model.box(model,Vector3(-0.15,0.72,0),Vector3(0.82,0.32,0.68),Color("35464c"))
	model.box(model,Vector3(-0.15,0.74,0.35),Vector3(0.54,0.18,0.025),Color("263b40"))
	for x in [-0.50,0.50]:
		for z in [-0.34,0.34]:
			var wheel := _cylinder(vehicle_root,Vector3(x,0.19,z),0.15,0.14,Color("161d20"))
			wheel.rotation.x = PI/2.0

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	visual.material_override = material
	parent.add_child(visual)
	return visual

func _remove_vehicle() -> void:
	if is_instance_valid(vehicle_root):
		vehicle_root.queue_free()
	vehicle_root = null

func _set_pump_status(pump: int, text_value: String, color: Color) -> void:
	if not pump_labels.has(pump):
		return
	pump_labels[pump].text = text_value
	pump_labels[pump].modulate = color

func _end_mode() -> void:
	active = false
	busy = false
	panel.hide()
	player.controls_locked = gameplay.dialogue.active or (is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active)
	world._update_objective()

func _money(rappen: int) -> String:
	return "CHF %.2f" % (float(rappen)/100.0)

func _tone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.14
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := sin(PI*float(i)/count)
		var sample := (sin(TAU*840.0*t)+0.35*sin(TAU*1260.0*t))*0.35*envelope
		bytes.encode_s16(i*2,int(sample*18000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
