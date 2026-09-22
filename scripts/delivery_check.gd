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
var clipboard_label: Label3D
var paper_sound: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
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
	clipboard_root.position = Vector3(-0.30,1.10,-0.18)
	layout.delivery.add_child(clipboard_root)
	var model := preload("res://scripts/product_display.gd").new()
	clipboard_root.add_child(model)
	model.box(model,Vector3.ZERO,Vector3(0.34,0.035,0.46),Color("715e47"))
	model.box(model,Vector3(0,0.025,0),Vector3(0.29,0.012,0.38),Color("ded7c4"))
	clipboard_label = Label3D.new()
	clipboard_label.position = Vector3(0,0.045,0)
	clipboard_label.font_size = 12
	clipboard_label.pixel_size = 0.0020
	clipboard_label.modulate = Color("283234")
	clipboard_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	clipboard_root.add_child(clipboard_label)
	clipboard_root.hide()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DeliveryCheckPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.27
	panel.anchor_right = 0.73
	panel.anchor_top = 0.18
	panel.anchor_bottom = 0.82
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
	panel.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(gameplay):
		return
	clipboard_root.visible = gameplay.delivery_ready and not gameplay.delivery_carried
	if clipboard_root.visible:
		clipboard_label.text = "DELIVERY\n"+_manifest_text(false)

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
	actual_manifest = gameplay.delivery_manifest.duplicate()
	# Some later shifts contain an ordinary receiving discrepancy. The player must
	# actually compare the carton label instead of confirming every line by habit.
	var night: int = gameplay.career_shifts+1
	if night == 3 and actual_manifest.has(&"chips"):
		actual_manifest[&"chips"] = maxi(0,int(actual_manifest[&"chips"])-1)
	elif night == 5 and actual_manifest.has(&"energy"):
		actual_manifest[&"energy"] = int(actual_manifest[&"energy"])+1
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
	_refresh_ui()
	world._update_objective()
	return true

func close() -> void:
	if not active:
		return
	active = false
	panel.hide()
	player.controls_locked = world.has_interaction_focus(self)
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey:
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
	help.text = "← / → carton   ·   [E] quantities match   ·   [R] mismatch   ·   [ENTER] accept after all checked"

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
