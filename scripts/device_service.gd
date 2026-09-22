extends Node
## One grounded equipment-maintenance interruption per mid-game shift. A cooler
## develops an airflow/controller fault; the player retrieves tools, opens the
## service panel, loosens its fasteners, resets the controller, then returns tools.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var fault_pending := false
var toolkit_carried := false
var return_required := false
var completed := false
var next_fault_at := 104.0

var selected_screw := 0
var screw_turns: Array[int] = [0,0,0]
var panel_open := false
var cooler_panel: Node3D
var screw_materials: Array[StandardMaterial3D] = []
var controller_material: StandardMaterial3D
var carried_toolkit: Node3D

var panel: PanelContainer
var title: Label
var status: Label
var progress: Label
var help: Label
var tool_sound: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	_build_cooler_panel()
	_build_ui()
	tool_sound = AudioStreamPlayer.new()
	tool_sound.bus = &"SFX"
	tool_sound.volume_db = -11
	tool_sound.stream = _tool_tone()
	add_child(tool_sound)
	set_process(true)
	_update_prompts()

func _build_cooler_panel() -> void:
	var cooler: Node3D = layout.product_nodes[&"energy"]
	cooler_panel = Node3D.new()
	cooler_panel.name = "CoolerServicePanel"
	cooler.add_child(cooler_panel)
	cooler_panel.position = Vector3(-0.58,0.82,0.32)
	var body := _box(cooler_panel,Vector3.ZERO,Vector3(0.34,0.46,0.06),Color("394846"))
	body.rotation.y = 0.0
	for i in 3:
		var screw := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.035
		mesh.bottom_radius = 0.035
		mesh.height = 0.018
		mesh.radial_segments = 12
		screw.mesh = mesh
		screw.rotation.x = PI/2.0
		screw.position = Vector3(0,0.14-i*0.14,0.045)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("8a918d")
		mat.metallic = 0.55
		mat.roughness = 0.35
		screw.material_override = mat
		screw_materials.append(mat)
		cooler_panel.add_child(screw)
	var controller := _box(cooler_panel,Vector3(0.0,-0.15,0.045),Vector3(0.16,0.08,0.02),Color("793f3a"))
	controller_material = controller.material_override
	cooler_panel.hide()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DeviceServicePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.32
	panel.anchor_right = 0.68
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -190
	panel.offset_bottom = -28
	var column := STYLE.column(panel,5)
	title = STYLE.text(column,18,STYLE.ACCENT)
	status = STYLE.text(column,16)
	progress = STYLE.text(column,14,STYLE.MUTED)
	help = STYLE.text(column,13,STYLE.MUTED)
	for label in [title,status,progress,help]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func _process(_delta: float) -> void:
	if gameplay == null or not gameplay.active or completed or fault_pending or return_required:
		return
	# Keep the first two nights focused on the basic systems and keep Night 6 free
	# for the reality-shift finale.
	if gameplay.career_shifts < 2 or gameplay.career_shifts >= 5:
		return
	if gameplay.elapsed < next_fault_at or gameplay.served+gameplay.lost_sales < 2:
		return
	if world.can_start_interrupt(self):
		_begin_fault()

func _begin_fault() -> void:
	fault_pending = true
	panel_open = false
	selected_screw = 0
	screw_turns = [0,0,0]
	cooler_panel.show()
	controller_material.albedo_color = Color("a34f45")
	_update_screw_visuals()
	_update_prompts()
	world._say("Cooler alarm · airflow controller fault. Maintenance tools required.",7.0)
	gameplay.changed.emit()
	world._update_objective()

func handle_action(action: StringName) -> bool:
	if action == &"service_tools":
		if return_required and toolkit_carried:
			_return_tools()
			return true
		if fault_pending and not toolkit_carried:
			_take_tools()
			return true
		if toolkit_carried:
			world._say("You already have the maintenance toolkit.")
			return true
		world._say("Maintenance tools are stored here.")
		return true
	if action == &"cooler":
		if not fault_pending:
			return false
		if not toolkit_carried:
			world._say("The cooler controller needs tools from the stockroom.")
			return true
		begin_service()
		return true
	return false

func _take_tools() -> void:
	toolkit_carried = true
	_show_carried_tools()
	_update_prompts()
	world._say("Maintenance toolkit taken. Open the cooler service panel.",5.0)
	gameplay.changed.emit()
	world._update_objective()

func begin_service() -> bool:
	if active:
		return true
	if not fault_pending or not toolkit_carried or _other_focus_active():
		return false
	active = true
	panel_open = true
	selected_screw = 0
	player.controls_locked = true
	player.velocity = Vector3.ZERO
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	panel.show()
	_refresh_ui()
	_update_screw_visuals()
	world._update_objective()
	return true

func close() -> void:
	if not active:
		return
	active = false
	panel.hide()
	player.controls_locked = gameplay.dialogue.active or _other_focus_active()
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT, KEY_A:
			selected_screw = wrapi(selected_screw-1,0,screw_turns.size())
			_update_screw_visuals()
			_refresh_ui()
		KEY_RIGHT, KEY_D:
			selected_screw = wrapi(selected_screw+1,0,screw_turns.size())
			_update_screw_visuals()
			_refresh_ui()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_turn_selected_screw()
		KEY_R:
			_reset_controller()
		_:
			return
	get_viewport().set_input_as_handled()

func _turn_selected_screw() -> void:
	if screw_turns[selected_screw] >= 2:
		status.text = "That fastener is already loose."
		return
	screw_turns[selected_screw] += 1
	tool_sound.play()
	_update_screw_visuals()
	_refresh_ui()

func _reset_controller() -> void:
	if not _all_screws_open():
		status.text = "Open all three service-panel fasteners first."
		return
	tool_sound.play()
	controller_material.albedo_color = Color("78a77d")
	status.text = "Controller reset · airflow restored."
	progress.text = "Close up and return the maintenance toolkit."
	help.text = ""
	await get_tree().create_timer(0.55).timeout
	_finish_repair()

func _finish_repair() -> void:
	fault_pending = false
	return_required = true
	active = false
	panel_open = false
	panel.hide()
	cooler_panel.hide()
	player.controls_locked = gameplay.dialogue.active or _other_focus_active()
	_update_prompts()
	gameplay.changed.emit()
	world._update_objective()
	world._say("Cooler running normally. Return the maintenance toolkit.",5.0)

func _return_tools() -> void:
	toolkit_carried = false
	return_required = false
	completed = true
	_clear_carried_tools()
	gameplay.story_flags[StringName("cooler_service_night_%d" % (gameplay.career_shifts+1))] = true
	_update_prompts()
	gameplay.changed.emit()
	world._update_objective()
	world._say("Maintenance toolkit returned.",3.0)

func objective_text() -> String:
	if return_required:
		return "Return the maintenance toolkit"
	if fault_pending and not toolkit_carried:
		return "Get maintenance tools from the stockroom"
	if fault_pending:
		return "Service the cooler controller"
	return ""

func _refresh_ui() -> void:
	if not active:
		return
	title.text = "COOLER · SERVICE PANEL"
	status.text = "Airflow controller fault · loosen each fastener twice."
	var states := PackedStringArray()
	for i in screw_turns.size():
		states.append("%d:%s" % [i+1,"OPEN" if screw_turns[i] >= 2 else ("%d/2" % screw_turns[i])])
	progress.text = "   ".join(states)+"   ·   selected %d" % (selected_screw+1)
	help.text = "← / → select fastener   ·   [E] turn screwdriver   ·   [R] reset controller"

func _all_screws_open() -> bool:
	for turns in screw_turns:
		if turns < 2:
			return false
	return true

func _update_screw_visuals() -> void:
	for i in screw_materials.size():
		if screw_turns[i] >= 2:
			screw_materials[i].albedo_color = Color("61706a")
		elif i == selected_screw and active:
			screw_materials[i].albedo_color = Color("d5b76f")
		else:
			screw_materials[i].albedo_color = Color("8a918d")

func _update_prompts() -> void:
	if is_instance_valid(layout.service_tool_station):
		if return_required and toolkit_carried:
			layout.service_tool_station.prompt = "Return maintenance toolkit"
		elif fault_pending and not toolkit_carried:
			layout.service_tool_station.prompt = "Take maintenance toolkit"
		else:
			layout.service_tool_station.prompt = "Maintenance tools"
	var cooler: Node3D = layout.product_nodes.get(&"energy")
	if is_instance_valid(cooler):
		if fault_pending and not toolkit_carried:
			cooler.prompt = "Cooler fault · Tools required"
		elif fault_pending:
			cooler.prompt = "Open cooler service panel"
		else:
			cooler.prompt = "Check refrigeration"

func _show_carried_tools() -> void:
	_clear_carried_tools()
	carried_toolkit = Node3D.new()
	carried_toolkit.name = "CarriedToolkit"
	player.add_child(carried_toolkit)
	carried_toolkit.position = Vector3(0.34,0.68,0.08)
	carried_toolkit.rotation = Vector3(0,-0.20,0.08)
	_box(carried_toolkit,Vector3.ZERO,Vector3(0.38,0.22,0.26),Color("7a403b"))
	_box(carried_toolkit,Vector3(0,0.14,0),Vector3(0.26,0.05,0.08),Color("a04d42"))

func _clear_carried_tools() -> void:
	if is_instance_valid(carried_toolkit):
		carried_toolkit.queue_free()
	carried_toolkit = null

func _other_focus_active() -> bool:
	return (is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active) or (is_instance_valid(world.pump_service) and world.pump_service.active) or (is_instance_valid(world.cctv_system) and world.cctv_system.active) or (is_instance_valid(world.power_service) and world.power_service.active) or (is_instance_valid(world.delivery_check) and world.delivery_check.active) or (is_instance_valid(world.phone_system) and world.phone_system.active) or (is_instance_valid(world.spill_service) and world.spill_service.active) or (is_instance_valid(world.radio_tuner) and world.radio_tuner.active)

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.75
	visual.material_override = mat
	parent.add_child(visual)
	return visual

func _tool_tone() -> AudioStreamWAV:
	var rate := 16000
	var seconds := 0.09
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var env := sin(PI*float(i)/count)
		var sample := (sin(TAU*220.0*t)*0.30+sin(TAU*440.0*t)*0.12)*env
		bytes.encode_s16(i*2,int(sample*14000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound

func _exit_tree() -> void:
	_clear_carried_tools()
