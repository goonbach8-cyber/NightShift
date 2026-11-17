extends Node
## Short receiving workflow for the yard delivery. The player compares the
## carton labels with the manifest before carrying the goods into storage.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var selected := 0
var order: Array[StringName] = []
var actual_manifest: Dictionary = {}
var verified: Dictionary = {}
var discrepancies: Dictionary = {}

var panel: PanelContainer
var title: Label
var manifest_label: Label
var carton_label: Label
var status: Label
var help: Label
var clipboard_root: Node3D
var clipboard_label: MeshInstance3D
var paper_sound: AudioStreamPlayer
var cartons: Dictionary = {}
var carton_materials: Dictionary = {}
var carton_labels: Dictionary = {}
var camera: Camera3D
var camera_tween: Tween
var camera_position := Vector3.ZERO
var camera_size := 8.5

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	camera = player.get_node("CameraRig/Camera3D")
	_build_clipboard()
	_build_ui()
	paper_sound = AudioStreamPlayer.new()
	paper_sound.bus = &"SFX"
	paper_sound.volume_db = -12
	paper_sound.stream = _tone()
	add_child(paper_sound)
	set_process(true)

func _build_clipboard() -> void:
	clipboard_root = Node3D.new()
	clipboard_root.name = "DeliveryClipboard"
	clipboard_root.position = layout.delivery_visual.position+Vector3(-0.05,0.27,0)
	layout.delivery.add_child(clipboard_root)
	var model := preload("res://scripts/product_display.gd").new()
	clipboard_root.add_child(model)
	model.box(model,Vector3.ZERO,Vector3(0.34,0.035,0.46),Color("715e47"))
	model.box(model,Vector3(0,0.025,0),Vector3(0.29,0.012,0.38),Color("ded7c4"))
	clipboard_label = preload("res://scripts/printed_surface.gd").make(clipboard_root,"DELIVERY",Vector3(0,0.032,0),Vector2(0.27,0.35),Color("283234"),Color("ded7c4"),true)
	model.box(clipboard_root,Vector3(0,0.039,-0.20),Vector3(0.10,0.015,0.035),Color("a7aea4"))
	clipboard_root.hide()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DeliveryCheckPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.035
	panel.anchor_right = 0.34
	panel.anchor_top = 0.10
	panel.anchor_bottom = 0.87
	var column := STYLE.column(panel,8)
	title = STYLE.text(column,18,STYLE.ACCENT)
	manifest_label = STYLE.text(column,16)
	manifest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(HSeparator.new())
	carton_label = STYLE.text(column,21)
	carton_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status = STYLE.text(column,15,STYLE.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help = STYLE.text(column,13,STYLE.MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for action in ["Match","Mismatch","Accept"]:
		var button := Button.new()
		button.text = action
		actions.add_child(button)
		if action == "Accept": button.pressed.connect(_accept)
		else: button.pressed.connect(func(): _verify_selected(action == "Match"))
	panel.hide()

func _actual_delivery() -> Dictionary:
	var result: Dictionary = gameplay.delivery_manifest.duplicate()
	var night: int = gameplay.career_shifts+1
	if night == 3 and result.has(&"chips"): result[&"chips"] = maxi(0,int(result[&"chips"])-1)
	elif night == 5 and result.has(&"energy"): result[&"energy"] = int(result[&"energy"])+1
	return result

func _present_cartons() -> void:
	var manifest := _actual_delivery()
	var model := preload("res://scripts/product_display.gd").new()
	for id in manifest:
		if not cartons.has(id):
			var parcel := Node3D.new()
			parcel.name = "Carton_"+String(id)
			layout.delivery.add_child(parcel)
			var index := cartons.size()
			parcel.position = Vector3(-0.20+(index%3)*0.34,0.86,-0.35+int(index/3)*0.36)
			var box: MeshInstance3D = model.box(parcel,Vector3.ZERO,Vector3(0.30,0.26,0.30),Color("b18c5c"))
			carton_materials[id] = box.material_override
			carton_labels[id] = preload("res://scripts/printed_surface.gd").make(parcel,"",Vector3(0,0.133,0),Vector2(0.26,0.22),Color("263235"),Color("d5c6a3"),true)
			cartons[id] = parcel
		cartons[id].visible = gameplay.delivery_ready and not gameplay.delivery_carried
		carton_labels[id].text = "%s\nx%d%s" % [String(id).to_upper(),manifest[id]," !" if discrepancies.has(id) else (" OK" if verified.has(id) else "")]
		carton_materials[id].albedo_color = Color("b68e52") if discrepancies.has(id) else (Color("71947b") if verified.has(id) else (Color("c8b78a") if active and not order.is_empty() and order[selected] == id else Color("9b8059")))
	model.free()
	layout.delivery_visual.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(gameplay):
		return
	clipboard_root.visible = gameplay.delivery_ready and not gameplay.delivery_carried
	if clipboard_root.visible:
		clipboard_label.text = "DELIVERY\n"+_manifest_text(false)
	_present_cartons()

func begin() -> bool:
	if active:
		return true
	if world.has_interaction_focus(self):
		return false
	if world.phase != world.Phase.ACTIVE or not gameplay.active:
		world._say("The delivery can be checked during the shift.")
		return false
	if not gameplay.delivery_ready:
		world._say("No delivery is waiting in the yard.")
		return false
	if gameplay.inventory.carried_product() != &"":
		world._say("Restock the carried product before receiving the delivery.")
		return false
	if gameplay.dialogue.active:
		return false
	active = true
	selected = 0
	verified.clear()
	discrepancies.clear()
	actual_manifest = _actual_delivery()
	order.clear()
	for id in actual_manifest.keys():
		order.append(id)
	# Cartons are not presented in the same order as the office manifest.
	if order.size() > 1:
		var rotate_by: int = (gameplay.career_shifts+1)%order.size()
		for i in rotate_by:
			order.push_back(order.pop_front())
	player.controls_locked = true
	player.velocity.x = 0
	player.velocity.z = 0
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	panel.show()
	_present_cartons()
	if not camera_tween or not camera_tween.is_running():
		camera_position = camera.position
		camera_size = camera.size
	if camera_tween: camera_tween.kill()
	var focus: Vector3 = layout.delivery.to_global(Vector3(0.08,0.95,-0.35))
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(camera,"position",camera.get_parent().to_local(focus+camera.global_basis.z*8),0.20)
	camera_tween.tween_property(camera,"size",3.2,0.20)
	_refresh_ui()
	world._update_objective()
	return true

func close() -> void:
	if not active:
		return
	active = false
	panel.hide()
	if camera_tween: camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(camera,"position",camera_position,0.20)
	camera_tween.tween_property(camera,"size",camera_size,0.20)
	player.controls_locked = world.has_interaction_focus(self)
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not active or world.has_interaction_focus(self):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position):
		for id in cartons:
			var center: Vector2 = camera.unproject_position(cartons[id].to_global(Vector3(0,0.13,0)))
			if center.distance_to(event.position) < 36:
				selected = order.find(id)
				_refresh_ui()
				get_viewport().set_input_as_handled()
				break
		return
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			close()
		KEY_LEFT, KEY_A:
			selected = wrapi(selected-1,0,order.size())
			_refresh_ui()
		KEY_RIGHT, KEY_D:
			selected = wrapi(selected+1,0,order.size())
			_refresh_ui()
		KEY_E:
			_verify_selected(true)
		KEY_R:
			_verify_selected(false)
		KEY_ENTER, KEY_KP_ENTER:
			_accept()
		_:
			return
	get_viewport().set_input_as_handled()

func _verify_selected(mark_as_match: bool) -> void:
	if order.is_empty():
		return
	var id: StringName = order[selected]
	var expected := int(gameplay.delivery_manifest.get(id,0))
	var actual := int(actual_manifest.get(id,0))
	var really_matches := actual == expected
	paper_sound.play()
	if mark_as_match != really_matches:
		status.text = "%s: compare the quantities again." % gameplay.inventory.products[id].display_name
		return
	verified[id] = true
	if really_matches:
		discrepancies.erase(id)
		status.text = "%s checked · %d units" % [gameplay.inventory.products[id].display_name,actual]
	else:
		discrepancies[id] = {"expected":expected,"actual":actual}
		status.text = "%s discrepancy logged · manifest %d / carton %d" % [gameplay.inventory.products[id].display_name,expected,actual]
	_refresh_ui()
	_present_cartons()
	status.text = "%s: %d received / %d ordered%s" % [gameplay.inventory.products[id].display_name,actual,expected," · discrepancy recorded" if not really_matches else " · checked"]

func _accept() -> void:
	if verified.size() < order.size():
		status.text = "Check every carton before accepting the delivery."
		return
	if not gameplay.accept_delivery(actual_manifest):
		status.text = "Delivery cannot be accepted while your hands are full."
		return
	if not discrepancies.is_empty():
		gameplay.story_flags[StringName("delivery_discrepancy_night_%d" % (gameplay.career_shifts+1))] = true
		world._say("Delivery accepted with %d logged discrepancy." % discrepancies.size(),5.0)
	clipboard_root.hide()
	paper_sound.play()
	close()

func _refresh_ui() -> void:
	if not active or order.is_empty():
		return
	title.text = "DELIVERY · RECEIVING CHECK"
	manifest_label.text = "MANIFEST\n"+_manifest_text(true)
	var id: StringName = order[selected]
	var checked: bool = verified.get(id,false)
	var mark := "  !" if discrepancies.has(id) else ("  ✓" if checked else "")
	carton_label.text = "%s\nCARTON LABEL: ×%d%s" % [gameplay.inventory.products[id].display_name,int(actual_manifest[id]),mark]
	if checked:
		status.text = "Discrepancy logged." if discrepancies.has(id) else "This carton has been checked."
	elif status.text.is_empty() or status.text.begins_with("This carton"):
		status.text = "Compare the carton label with the manifest."
	help.text = "Click carton / ← → select\nE match · R mismatch · Enter accept · ESC close"

func _manifest_text(mark_checked: bool) -> String:
	var lines := PackedStringArray()
	for id in gameplay.delivery_manifest:
		var mark := ""
		if mark_checked and verified.get(id,false):
			mark = " !" if discrepancies.has(id) else " ✓"
		lines.append("%s ×%d%s" % [gameplay.inventory.products[id].display_name,int(gameplay.delivery_manifest[id]),mark])
	return "\n".join(lines)

func _tone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.09
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := sin(PI*float(i)/count)
		var sample := (sin(TAU*310.0*t)*0.34+sin(TAU*620.0*t)*0.14)*envelope
		bytes.encode_s16(i*2,int(sample*13000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
