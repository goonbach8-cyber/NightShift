extends Node
## Occasional shop-floor spill. The player fetches the cleaning kit, then physically
## sweeps the mop across the stain before returning the kit to the service room.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var spill_pending := false
var kit_carried := false
var return_required := false
var completed := false
var next_spill_at := 88.0
var area_label := "snack aisle"
var spill_root: Node3D
var spill_point: Node3D
var carried_mop: Node3D
var work_mop: Node3D
var stain_visuals: Array[MeshInstance3D] = []

var sweep_position := -0.34
var sweep_left := false
var sweep_right := false
var sweep_passes := 0
var last_edge := -1
const REQUIRED_PASSES := 4

var panel: PanelContainer
var title: Label
var status: Label
var progress: Label
var help: Label
var scrub_sound: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	_build_ui()
	scrub_sound = AudioStreamPlayer.new()
	scrub_sound.bus = &"SFX"
	scrub_sound.volume_db = -14
	scrub_sound.stream = _scrub_tone()
	add_child(scrub_sound)
	set_process(true)
	_update_station_prompt()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "SpillCleanupPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.32
	panel.anchor_right = 0.68
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -170
	panel.offset_bottom = -28
	var column := STYLE.column(panel,5)
	title = STYLE.text(column,18,STYLE.ACCENT)
	status = STYLE.text(column,16)
	progress = STYLE.text(column,14,STYLE.MUTED)
	help = STYLE.text(column,13,STYLE.MUTED)
	for label in [title,status,progress,help]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func _process(delta: float) -> void:
	if gameplay == null:
		return
	if gameplay.active and not completed and not spill_pending and not return_required and gameplay.career_shifts >= 1 and gameplay.career_shifts < 5 and gameplay.elapsed >= next_spill_at and gameplay.served+gameplay.lost_sales >= 1 and world.can_start_interrupt(self):
		_spawn_spill()
	if not active:
		return
	var direction := (1.0 if sweep_right else 0.0)-(1.0 if sweep_left else 0.0)
	if direction == 0:
		return
	sweep_position = clampf(sweep_position+direction*0.72*delta,-0.36,0.36)
	if is_instance_valid(work_mop):
		work_mop.position.x = sweep_position
	if sweep_position >= 0.34 and last_edge != 1:
		last_edge = 1
		_register_pass()
	elif sweep_position <= -0.34 and last_edge != -1:
		last_edge = -1
		_register_pass()

func _spawn_spill() -> void:
	spill_pending = true
	var night := gameplay.career_shifts+1
	var target: StringName = &"chips"
	if night == 3:
		target = &"energy"
		area_label = "cold drinks"
	elif night == 4:
		target = &"water"
		area_label = "water display"
	else:
		target = &"chips"
		area_label = "snack aisle"
	var base := layout.product_points[target].global_position+Vector3(0.48,0.015,-0.18)
	spill_root = Node3D.new()
	spill_root.name = "ShopFloorSpill"
	world.add_child(spill_root)
	spill_root.global_position = base
	for config in [
		{"at":Vector3(-0.18,0,0.04),"r":0.23},
		{"at":Vector3(0.08,0,0.00),"r":0.28},
		{"at":Vector3(0.27,0,-0.08),"r":0.17}
	]:
		var visual := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = config.r
		mesh.bottom_radius = config.r
		mesh.height = 0.008
		mesh.radial_segments = 18
		visual.mesh = mesh
		visual.position = config.at
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.24,0.30,0.25,0.72)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.18
		visual.material_override = mat
		spill_root.add_child(visual)
		stain_visuals.append(visual)
	spill_point = Node3D.new()
	spill_point.name = "SpillInteraction"
	spill_point.set_script(preload("res://scenes/interactions/interactable.gd"))
	spill_point.action_id = &"spill_cleanup"
	spill_point.prompt = "Clean spill"
	spill_root.add_child(spill_point)
	spill_point.position = Vector3.ZERO
	spill_point.used.connect(func(_id): handle_action(&"spill_cleanup"))
	_update_station_prompt()
	world._say("A drink has spilled near the %s." % area_label,6.0)
	gameplay.changed.emit()
	world._update_objective()

func handle_action(action: StringName) -> bool:
	if action == &"cleaning_kit":
		if return_required and kit_carried:
			_return_kit()
			return true
		if spill_pending and not kit_carried:
			_take_kit()
			return true
		if kit_carried:
			world._say("You already have the cleaning kit.")
			return true
		world._say("The cleaning kit is stocked and ready.")
		return true
	if action == &"spill_cleanup":
		if not spill_pending:
			return false
		if not kit_carried:
			world._say("Get the mop from the service room first.")
			return true
		begin_cleanup()
		return true
	return false

func _take_kit() -> void:
	kit_carried = true
	_show_carried_mop()
	_update_station_prompt()
	world._say("Cleaning kit taken. Mop the spill near the %s." % area_label,5.0)
	gameplay.changed.emit()
	world._update_objective()

func begin_cleanup() -> bool:
	if active:
		return true
	if not spill_pending or not kit_carried or not is_instance_valid(spill_root):
		return false
	if _other_focus_active():
		return false
	active = true
	sweep_position = -0.34
	sweep_passes = 0
	last_edge = -1
	sweep_left = false
	sweep_right = false
	_clear_carried_mop()
	_build_work_mop()
	player.controls_locked = true
	player.velocity = Vector3.ZERO
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	panel.show()
	_refresh_ui()
	world._update_objective()
	return true

func _register_pass() -> void:
	if sweep_passes >= REQUIRED_PASSES:
		return
	sweep_passes += 1
	if not scrub_sound.playing:
		scrub_sound.play()
	var remaining := 1.0-float(sweep_passes)/float(REQUIRED_PASSES)
	for visual in stain_visuals:
		if is_instance_valid(visual):
			visual.scale = Vector3(0.55+remaining*0.45,1.0,0.55+remaining*0.45)
			var mat := visual.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = 0.18+remaining*0.54
	_refresh_ui()
	if sweep_passes >= REQUIRED_PASSES:
		_finish_cleanup()

func _finish_cleanup() -> void:
	spill_pending = false
	return_required = true
	if is_instance_valid(spill_point):
		spill_point.available = false
	status.text = "Floor clean."
	progress.text = "Return the mop to the service room."
	help.text = ""
	await get_tree().create_timer(0.45).timeout
	if is_instance_valid(spill_root):
		spill_root.queue_free()
	spill_root = null
	spill_point = null
	stain_visuals.clear()
	_clear_work_mop()
	active = false
	panel.hide()
	_show_carried_mop()
	player.controls_locked = gameplay.dialogue.active or _other_focus_active()
	_update_station_prompt()
	gameplay.changed.emit()
	world._update_objective()
	world._say("Spill cleaned. Return the mop to the service room.",5.0)

func _return_kit() -> void:
	kit_carried = false
	return_required = false
	completed = true
	_clear_carried_mop()
	_update_station_prompt()
	gameplay.story_flags[StringName("spill_cleaned_night_%d" % (gameplay.career_shifts+1))] = true
	gameplay.changed.emit()
	world._update_objective()
	world._say("Cleaning kit returned.",3.0)

func objective_text() -> String:
	if return_required:
		return "Return the mop to the service room"
	if spill_pending and not kit_carried:
		return "Get the mop from the service room"
	if spill_pending and kit_carried:
		return "Clean the spill near the %s" % area_label
	return ""

func _build_work_mop() -> void:
	_clear_work_mop()
	work_mop = Node3D.new()
	work_mop.name = "ActiveMop"
	spill_root.add_child(work_mop)
	work_mop.position = Vector3(sweep_position,0.06,0)
	_box(work_mop,Vector3(0,0,0),Vector3(0.42,0.06,0.16),Color("465b58"))
	var handle := _box(work_mop,Vector3(0,0.65,0),Vector3(0.045,1.30,0.045),Color("9b8057"))
	handle.rotation.z = -0.24

func _show_carried_mop() -> void:
	_clear_carried_mop()
	carried_mop = Node3D.new()
	carried_mop.name = "CarriedMop"
	player.add_child(carried_mop)
	carried_mop.position = Vector3(0.34,0.68,0.04)
	carried_mop.rotation = Vector3(0,0,-0.30)
	_box(carried_mop,Vector3(0,0.18,0),Vector3(0.34,0.07,0.14),Color("465b58"))
	_box(carried_mop,Vector3(0,0.88,0),Vector3(0.04,1.45,0.04),Color("9b8057"))

func _update_station_prompt() -> void:
	if not is_instance_valid(layout.cleaning_station):
		return
	if return_required and kit_carried:
		layout.cleaning_station.prompt = "Return cleaning kit"
	elif spill_pending and not kit_carried:
		layout.cleaning_station.prompt = "Take mop for spill"
	elif kit_carried:
		layout.cleaning_station.prompt = "Cleaning kit in use"
	else:
		layout.cleaning_station.prompt = "Cleaning kit"

func _refresh_ui() -> void:
	if not active:
		return
	title.text = "CLEANING · SHOP FLOOR"
	status.text = "Sweep the mop across the whole spill."
	progress.text = "%d / %d passes" % [sweep_passes,REQUIRED_PASSES]
	help.text = "A / D or ← / → sweep   ·   alternate sides until the floor is clean"

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
		return
	var key := event.physical_keycode
	if key in [KEY_A,KEY_LEFT]:
		sweep_left = event.pressed
	elif key in [KEY_D,KEY_RIGHT]:
		sweep_right = event.pressed
	else:
		return
	get_viewport().set_input_as_handled()

func _other_focus_active() -> bool:
	return (is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active) or (is_instance_valid(world.pump_service) and world.pump_service.active) or (is_instance_valid(world.cctv_system) and world.cctv_system.active) or (is_instance_valid(world.power_service) and world.power_service.active) or (is_instance_valid(world.delivery_check) and world.delivery_check.active) or (is_instance_valid(world.phone_system) and world.phone_system.active)

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	visual.material_override = mat
	parent.add_child(visual)
	return visual

func _clear_carried_mop() -> void:
	if is_instance_valid(carried_mop):
		carried_mop.queue_free()
	carried_mop = null

func _clear_work_mop() -> void:
	if is_instance_valid(work_mop):
		work_mop.queue_free()
	work_mop = null

func _scrub_tone() -> AudioStreamWAV:
	var rate := 16000
	var seconds := 0.16
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 317
	var filtered := 0.0
	for i in count:
		filtered = lerpf(filtered,rng.randf_range(-1.0,1.0),0.16)
		var env := sin(PI*float(i)/count)
		bytes.encode_s16(i*2,int(clampf(filtered*env,-1.0,1.0)*8500))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound

func _exit_tree() -> void:
	_clear_carried_mop()
	_clear_work_mop()
	if is_instance_valid(spill_root):
		spill_root.queue_free()
