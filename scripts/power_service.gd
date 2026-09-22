extends Node
## Grounded electrical fault workflow. A real circuit loses light, the player reads
## the symptom and resets the matching breaker in the service room.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var fault_pending := false
var fault_circuit := -1
var selected_circuit := 0
var completed := false
var next_fault_at := 72.0
var affected_lights: Array[Light3D] = []
var stored_energy: Array[float] = []

var circuits: Array[Dictionary] = []
var panel: PanelContainer
var title: Label
var status: Label
var details: Label
var help: Label
var switch_sound: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	circuits = [
		{"name":"SHOP","symptom":"Checkout and front-shop lighting offline.","anchor":layout.checkout.global_position,"radius":4.5},
		{"name":"COOLERS","symptom":"Cooler row and rear display lights offline.","anchor":layout.product_nodes[&"energy"].global_position,"radius":4.8},
		{"name":"SERVICE","symptom":"Stockroom and service lighting offline.","anchor":layout.warehouse.global_position+Vector3(2.5,0,-1.0),"radius":5.0}
	]
	_build_ui()
	switch_sound = AudioStreamPlayer.new()
	switch_sound.bus = &"SFX"
	switch_sound.volume_db = -10
	switch_sound.stream = _tone()
	add_child(switch_sound)
	set_process(true)
	_update_prompt()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "BreakerPanelUI"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.34
	panel.anchor_right = 0.66
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -190
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
	if gameplay == null or not gameplay.active or completed or fault_pending:
		return
	# Keep Night 1 clean so the player learns the station first. Night 6 already
	# has its own reality-lighting beat, so this work fault stays out of it.
	if gameplay.career_shifts < 1 or gameplay.career_shifts >= 5:
		return
	if gameplay.elapsed < next_fault_at:
		return
	if is_instance_valid(world.effects) and world.effects.remaining > 0:
		return
	_begin_fault()

func _begin_fault() -> void:
	fault_circuit = (gameplay.career_shifts+1)%circuits.size()
	selected_circuit = 0
	fault_pending = true
	_dim_circuit(fault_circuit)
	_update_prompt()
	world._say("Power fault · "+String(circuits[fault_circuit].symptom),7.0)
	gameplay.changed.emit()

func begin() -> bool:
	if active:
		return true
	if world.phase != world.Phase.ACTIVE or not gameplay.active:
		world._say("Breaker panel is checked during an active shift.")
		return false
	if not fault_pending:
		world._say("All electrical circuits are stable.")
		return false
	if gameplay.dialogue.active:
		return false
	if is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active:
		return false
	if is_instance_valid(world.pump_service) and world.pump_service.active:
		return false
	if is_instance_valid(world.cctv_system) and world.cctv_system.active:
		return false
	active = true
	selected_circuit = 0
	player.controls_locked = true
	player.velocity.x = 0
	player.velocity.z = 0
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	panel.show()
	_refresh_ui()
	world._update_objective()
	return true

func close() -> void:
	if not active:
		return
	active = false
	panel.hide()
	player.controls_locked = gameplay.dialogue.active or (is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active) or (is_instance_valid(world.pump_service) and world.pump_service.active) or (is_instance_valid(world.cctv_system) and world.cctv_system.active)
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			close()
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			selected_circuit = wrapi(selected_circuit-1,0,circuits.size())
			_refresh_ui()
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
			selected_circuit = wrapi(selected_circuit+1,0,circuits.size())
			_refresh_ui()
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_reset_selected()
		_:
			return
	get_viewport().set_input_as_handled()

func _reset_selected() -> void:
	if not fault_pending:
		status.text = "No breaker is currently tripped."
		return
	switch_sound.play()
	if selected_circuit != fault_circuit:
		status.text = String(circuits[selected_circuit].name)+" holds. Nothing changes."
		return
	_restore_lights()
	fault_pending = false
	completed = true
	var restored := String(circuits[fault_circuit].name)
	fault_circuit = -1
	_update_prompt()
	status.text = restored+" circuit restored."
	details.text = "Power is stable again."
	help.text = ""
	gameplay.changed.emit()
	await get_tree().create_timer(0.55).timeout
	close()
	world._say(restored+" circuit restored.",4.0)

func _dim_circuit(index: int) -> void:
	_restore_lights()
	var data: Dictionary = circuits[index]
	var anchor: Vector3 = data.anchor
	var radius: float = float(data.radius)
	var all_lights: Array[Light3D] = []
	_collect_lights(world.get_node("Station"),all_lights)
	for light in all_lights:
		if light.global_position.distance_to(anchor) <= radius:
			affected_lights.append(light)
			stored_energy.append(light.light_energy)
	# Fallback keeps the failure visible even if authored lighting moves later.
	if affected_lights.is_empty():
		for light in all_lights:
			if affected_lights.size() >= 2:
				break
			affected_lights.append(light)
			stored_energy.append(light.light_energy)
	for i in affected_lights.size():
		if is_instance_valid(affected_lights[i]):
			affected_lights[i].light_energy = stored_energy[i]*0.08

func _collect_lights(node: Node, output: Array[Light3D]) -> void:
	if node is Light3D:
		output.append(node)
	for child in node.get_children():
		_collect_lights(child,output)

func _restore_lights() -> void:
	for i in affected_lights.size():
		if is_instance_valid(affected_lights[i]):
			affected_lights[i].light_energy = stored_energy[i]
	affected_lights.clear()
	stored_energy.clear()

func _refresh_ui() -> void:
	if not active:
		return
	title.text = "SERVICE · BREAKER PANEL"
	status.text = String(circuits[fault_circuit].symptom) if fault_pending else "All circuits stable."
	details.text = "Selected breaker: "+String(circuits[selected_circuit].name)
	help.text = "← / → select breaker   ·   [E / ENTER] reset   ·   ESC close"

func _update_prompt() -> void:
	if not is_instance_valid(layout.breaker_panel):
		return
	layout.breaker_panel.prompt = "Reset tripped circuit" if fault_pending else "Electrical breaker panel"

func _tone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.10
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := sin(PI*float(i)/count)
		var sample := (sin(TAU*190.0*t)*0.5+sin(TAU*380.0*t)*0.18)*envelope
		bytes.encode_s16(i*2,int(sample*17000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound

func _exit_tree() -> void:
	_restore_lights()
