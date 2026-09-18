extends Node3D
enum Phase { NOT_STARTED, ACTIVE, COMPLETE }
var phase: Phase = Phase.NOT_STARTED
var completed: Dictionary = {}
var message_time: float = 0
var muted: bool = false
var gameplay: Node
var layout: Node
var checkpoint = preload("res://scripts/shift_save.gd").new()
var radio: AudioStreamPlayer
var effects: Node
var menu: CanvasLayer
var story_label: Label
var story_time := 0.0
var story_cooldown := 0.0
var pending_events: Array[Resource] = []
var dialogue_label: Label
var dialogue_backdrop: Panel
var checkout_label: Label
var checkout_backdrop: Panel
var story_world: Node3D
@onready var player: CharacterBody3D = $Player
@onready var objective: Label = $HUD/Objective
@onready var prompt: Label = $HUD/Prompt
@onready var message: Label = $HUD/Message
@onready var ambience: AudioStreamPlayer = $Ambience
@onready var feedback: AudioStreamPlayer = $Feedback

func _ready() -> void:
	var settings = preload("res://scripts/game_settings.gd").new()
	settings.load_settings()
	route_audio(self)
	menu = preload("res://scripts/game_menu.gd").new()
	menu.world = self
	add_child(menu)
	layout = Node.new()
	layout.name = "GameplayLayout"
	layout.set_script(preload("res://scripts/gameplay_layout.gd"))
	add_child(layout)
	gameplay = Node.new()
	gameplay.name = "ShiftLoop"
	gameplay.set_script(preload("res://scripts/night_shift_loop.gd"))
	add_child(gameplay)
	gameplay.setup(layout)
	gameplay.notice.connect(_say)
	gameplay.changed.connect(_update_objective)
	radio = AudioStreamPlayer.new()
	radio.set_script(preload("res://scripts/shop_radio.gd"))
	add_child(radio)
	radio.bus = &"Radio"
	ambience.bus = &"Ambience"
	feedback.bus = &"SFX"
	effects = Node.new()
	effects.set_script(preload("res://scripts/event_effects.gd"))
	add_child(effects)
	gameplay.events.triggered.connect(_on_event)
	story_label = Label.new()
	story_label.position = Vector2(24,390)
	story_label.size = Vector2(900,110)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.add_theme_font_size_override("font_size",24)
	story_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	story_label.add_theme_constant_override("shadow_offset_x",2)
	story_label.add_theme_constant_override("shadow_offset_y",2)
	$HUD.add_child(story_label)
	checkout_backdrop = Panel.new()
	checkout_backdrop.position = Vector2(12,213)
	checkout_backdrop.size = Vector2(454,174)
	checkout_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_backdrop.hide()
	var checkout_style := StyleBoxFlat.new()
	checkout_style.bg_color = Color(0.025,0.04,0.05,0.94)
	checkout_style.set_corner_radius_all(5)
	checkout_backdrop.add_theme_stylebox_override("panel",checkout_style)
	$HUD.add_child(checkout_backdrop)
	checkout_label = Label.new()
	checkout_label.hide()
	checkout_label.position = Vector2(24,225)
	checkout_label.size = Vector2(430,150)
	checkout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	checkout_label.add_theme_font_size_override("font_size",22)
	checkout_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	checkout_label.add_theme_constant_override("shadow_offset_x",2)
	checkout_label.add_theme_constant_override("shadow_offset_y",2)
	$HUD.add_child(checkout_label)
	dialogue_backdrop = Panel.new()
	dialogue_backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_backdrop.offset_left = 12
	dialogue_backdrop.offset_right = -12
	dialogue_backdrop.offset_top = -332
	dialogue_backdrop.offset_bottom = -168
	dialogue_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_backdrop.add_theme_stylebox_override("panel",checkout_style.duplicate())
	dialogue_backdrop.hide()
	$HUD.add_child(dialogue_backdrop)
	dialogue_label = Label.new()
	dialogue_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_label.offset_left = 24
	dialogue_label.offset_right = -24
	dialogue_label.offset_top = -320
	dialogue_label.offset_bottom = -180
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size",20)
	dialogue_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	dialogue_label.add_theme_constant_override("shadow_offset_x",2)
	dialogue_label.add_theme_constant_override("shadow_offset_y",2)
	dialogue_label.hide()
	$HUD.add_child(dialogue_label)
	for object in get_tree().get_nodes_in_group("interactable"):
		object.used.connect(_on_used)
	$Station/Door.blocked.connect(func(): _say("Keep the doorway clear."))
	ambience.stream = _tone(true)
	feedback.stream = _tone(false)
	ambience.play()
	$HUD/ObjectiveBackdrop.offset_right = 440
	$HUD/ObjectiveBackdrop.offset_bottom = 180
	objective.offset_right = 425
	objective.offset_bottom = 172
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size",15)
	layout.checkout.prompt = "Scan item / Take payment"
	$HUD/Controls.text = "WASD Move  E Interact  F Talk  Space Continue  TAB Warehouse product  ESC Pause"
	$HUD/Controls.add_theme_font_size_override("font_size",13)
	if get_tree().has_meta("nightshift_checkpoint_path"):
		checkpoint.path = get_tree().get_meta("nightshift_checkpoint_path")
	if get_tree().get_meta("nightshift_continue",false):
		get_tree().remove_meta("nightshift_continue")
		if not checkpoint.load_checkpoint(gameplay): _say("Checkpoint could not be loaded. Start a new shift.")
	story_world = preload("res://scripts/story_world.gd").new()
	add_child(story_world)
	story_world.setup(self)
	if gameplay.career_shifts >= 6:
		story_world.enter_ending()
		menu.show_page("ending")
	_update_objective()

func _on_event(event: Resource) -> void:
	pending_events.append(event)

func _process(delta: float) -> void:
	var content: Dictionary = preload("res://scripts/dialogue_catalog.gd").for_context(gameplay.event_history,gameplay.story_flags,gameplay.career_shifts+1)
	var special: bool = content.has("seen_flag") or not content.choices.is_empty()
	var customer_ready: bool = gameplay.checkout_ready()
	checkout_label.visible = customer_ready and layout.at_operator(player) and not gameplay.dialogue.active
	checkout_backdrop.visible = checkout_label.visible
	checkout_label.text = gameplay.checkout_text() if checkout_label.visible else ""
	story_cooldown = maxf(0,story_cooldown-delta)
	var ready_event := -1
	for i in pending_events.size():
		var candidate: Resource = pending_events[i]
		var in_area: bool = candidate.required_area == &"" or gameplay.events.occupied_areas.has(candidate.required_area)
		if in_area and (not candidate.at_checkout or (layout.at_operator(player) and customer_ready)):
			ready_event = i
			break
	if ready_event >= 0 and story_time <= 0 and story_cooldown <= 0 and not gameplay.dialogue.active:
		var event: Resource = pending_events[ready_event]
		pending_events.remove_at(ready_event)
		story_label.text = "The customer pauses.\n“You answered the phone earlier, didn't you?”\n[F] Talk" if event.main_event and gameplay.career_shifts == 0 else event.text
		story_time = 16
		story_cooldown = gameplay.definition.event_spacing_seconds
		if event.effect == &"light_dip": effects.light_dip()
		if event.effect == &"radio_interrupt": radio.interrupt_briefly()
		if event.effect == &"world_state":
			for prop in get_tree().get_nodes_in_group("story_prop"):
				if prop.target_id == event.effect_target: prop.apply_state()
		gameplay.story_flags[&"noticed_call"] = true
		gameplay.story_flags[StringName("presented_"+String(event.event_id))] = true
		gameplay.changed.emit()
	# A conversation hides this caption; keep its remaining reading time intact.
	if not gameplay.dialogue.active:
		story_time = maxf(0, story_time-delta)
	story_label.visible = story_time > 0 and not gameplay.dialogue.active
	get_node("Station/ShiftBoard").prompt = "Finish shift" if phase == Phase.ACTIVE and gameplay.can_finish() else "Shift notes / Start night"
	var target: Node3D = player.interaction_target if is_instance_valid(player.interaction_target) else null
	prompt.text = "[E]  " + gameplay.interaction_prompt(target,player) if is_instance_valid(target) and not gameplay.dialogue.active else ""
	if customer_ready and layout.at_operator(player) and not gameplay.dialogue.active:
		prompt.text += "   [F] Talk" + (" — About the phone call" if special else "")
	message_time = maxf(0,message_time-delta)
	message.visible = message_time > 0
	dialogue_label.visible = gameplay.dialogue.active
	dialogue_backdrop.visible = dialogue_label.visible
	dialogue_label.text = gameplay.dialogue.display_text()
	radio.globally_muted = muted

func _exit_tree() -> void:
	ambience.stop()
	feedback.stop()
	ambience.stream = null
	feedback.stream = null

func _input(event: InputEvent) -> void:
	if not is_instance_valid(gameplay) or not gameplay.dialogue.active: return
	# Consume hidden work actions before interactables (including doors) see them.
	var work_shortcut: bool = event is InputEventKey and event.pressed and event.physical_keycode in [KEY_TAB,KEY_T,KEY_Y,KEY_EQUAL,KEY_PLUS,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT]
	if event.is_action_pressed("interact") or work_shortcut:
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if menu.page != "": return
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_T:
				if player.interaction_target != layout.radio_point: return
				radio.toggle()
				_say("Radio on" if radio.enabled else "Radio off")
			KEY_Y:
				if player.interaction_target != layout.radio_point: return
				radio.next_track()
				_say("Radio track %d" % (radio.track_index+1))
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				if player.interaction_target == layout.radio_point: radio.change_volume(3)
			KEY_MINUS, KEY_KP_SUBTRACT:
				if player.interaction_target == layout.radio_point: radio.change_volume(-3)
			KEY_F:
				if phase == Phase.ACTIVE and layout.at_operator(player): gameplay.talk()
			KEY_SPACE: gameplay.dialogue.advance()
			KEY_1: gameplay.dialogue.choose(0)
			KEY_2: gameplay.dialogue.choose(1)
			KEY_N:
				if phase == Phase.COMPLETE:
					if checkpoint.write_checkpoint(gameplay):
						get_tree().set_meta("nightshift_checkpoint_path",checkpoint.path)
						get_tree().set_meta("nightshift_continue",true)
						get_tree().reload_current_scene()
					else: _say("Save failed. The previous checkpoint is retained.")
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB and phase == Phase.ACTIVE:
		if player.interaction_target == layout.warehouse.get_node("Supply"): gameplay.cycle_supply()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F5:
		_say("Night saved." if phase == Phase.COMPLETE and checkpoint.write_checkpoint(gameplay) else "Saving is available between completed nights.")
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F9:
		if phase == Phase.NOT_STARTED and checkpoint.load_checkpoint(gameplay):
			_say("Checkpoint loaded. Start at the staff notes.")
			_update_objective()
		else:
			_say("No valid checkpoint, or the shift has already started.")
	if event.is_action_pressed("mute_audio"):
		muted = not muted
		ambience.volume_db = -80 if muted else -30
		feedback.volume_db = -80 if muted else -22
		_say("Audio muted" if muted else "Audio on")
	if event.is_action_pressed("restart_shift") and phase == Phase.COMPLETE:
		get_tree().reload_current_scene()

func _on_used(action: StringName) -> void:
	if action == &"radio":
		radio.toggle()
		_say("Radio on" if radio.enabled else "Radio off")
		return
	if phase == Phase.COMPLETE:
		_say("Night complete. Continue from the summary.")
		return
	if action == &"start":
		if phase == Phase.ACTIVE and gameplay.can_finish():
			phase = Phase.COMPLETE
			gameplay.active = false
			if get_tree().get_meta("nightshift_menu_session",false): menu.show_page("complete")
			_say("Night complete. Your summary is ready.",8)
		elif phase == Phase.NOT_STARTED:
			if get_tree().get_meta("nightshift_menu_session",false) and not gameplay.definition.handover.is_empty() and not gameplay.story_flags.get(story_world.handover_flag(),false):
				story_world.interact(&"josh")
				return
			phase = Phase.ACTIVE
			gameplay.start()
		else:
			_say("Serve customers, restock products and complete the shift tasks.")
	elif phase == Phase.NOT_STARTED:
		_say("First read the shift notes behind the counter.")
	elif not gameplay.preparing:
		gameplay.interact(action,player)
	completed = gameplay.tasks
	_update_objective()

func _update_objective() -> void:
	if phase == Phase.NOT_STARTED:
		objective.text = "%s\n%s\nStart at the staff notes behind the counter.\nCompleted nights: %d | Total CHF %.2f" % [gameplay.definition.title,gameplay.definition.briefing,gameplay.career_shifts,float(gameplay.career_revenue)/100]
	elif phase == Phase.ACTIVE:
		objective.text = "Preparing customer routes …" if gameplay.preparing else gameplay.status_text()
	else:
		objective.text = "NIGHT COMPLETE\n%d customers | %d lost | %d items | CHF %.2f | %d tasks\n[N] Save & next night  [F5] Save  [R] Restart  [F9 at start] Load" % [gameplay.served,gameplay.lost_sales,gameplay.sold_units,float(gameplay.revenue_rappen)/100,gameplay.tasks.size()]

func _say(text: String, seconds: float = 4.5) -> void:
	message.text = text
	message_time = seconds
	feedback.play()

func _tone(looping: bool) -> AudioStreamWAV:
	# Small original synthesized placeholders, generated once; no external assets.
	var rate := 22050
	var count := rate if looping else int(rate * 0.16)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / rate
		var sample := sin(TAU * (60.0 if looping else 660.0) * t)
		if looping:
			sample = sample * 0.6 + sin(TAU * 120.0 * t) * 0.15
		else:
			sample *= sin(PI * float(i) / count) * 0.4
		bytes.encode_s16(i * 2, int(sample * 12000.0))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = bytes
	if looping:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_end = count
	return audio

func route_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.bus = node.get_meta("audio_category",&"SFX")
	for child in node.get_children(): route_audio(child)
