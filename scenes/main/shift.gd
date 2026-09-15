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
var checkout_label: Label
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
	radio.bus = &"Music"
	ambience.bus = &"SFX"
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
	checkout_label = Label.new()
	checkout_label.position = Vector2(24,225)
	checkout_label.size = Vector2(640,140)
	checkout_label.add_theme_font_size_override("font_size",22)
	checkout_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	checkout_label.add_theme_constant_override("shadow_offset_x",2)
	checkout_label.add_theme_constant_override("shadow_offset_y",2)
	$HUD.add_child(checkout_label)
	dialogue_label = Label.new()
	dialogue_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_label.offset_left = 24
	dialogue_label.offset_right = -24
	dialogue_label.offset_top = -320
	dialogue_label.offset_bottom = -170
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size",20)
	dialogue_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	dialogue_label.add_theme_constant_override("shadow_offset_x",2)
	dialogue_label.add_theme_constant_override("shadow_offset_y",2)
	$HUD.add_child(dialogue_label)
	for object in get_tree().get_nodes_in_group("interactable"):
		object.used.connect(_on_used)
	$Station/Door.blocked.connect(func(): _say("Der Durchgang muss frei bleiben."))
	ambience.stream = _tone(true)
	feedback.stream = _tone(false)
	ambience.play()
	$HUD/ObjectiveBackdrop.offset_right = 440
	$HUD/ObjectiveBackdrop.offset_bottom = 180
	objective.offset_right = 425
	objective.offset_bottom = 185
	objective.add_theme_font_size_override("font_size",15)
	layout.checkout.prompt = "Scan item / Take payment"
	$HUD/Controls.text = "WASD Move  E Interact  F Talk  Space Continue  TAB Warehouse product  ESC Pause"
	$HUD/Controls.add_theme_font_size_override("font_size",13)
	if get_tree().has_meta("nightshift_checkpoint_path"):
		checkpoint.path = get_tree().get_meta("nightshift_checkpoint_path")
	if get_tree().get_meta("nightshift_continue",false):
		get_tree().remove_meta("nightshift_continue")
		if not checkpoint.load_checkpoint(gameplay): _say("Checkpoint could not be loaded. Start a new shift.")
	_update_objective()

func _on_event(event: Resource) -> void:
	pending_events.append(event)

func _process(delta: float) -> void:
	var special: bool = not gameplay.event_history.is_empty() and not gameplay.story_flags.get(&"asked_about_call",false) and not gameplay.story_flags.get(&"denied_call",false)
	var customer_ready: bool = not gameplay.queue.is_empty() and not gameplay.queue[0].walking
	checkout_label.visible = customer_ready and layout.at_operator(player) and not gameplay.dialogue.active
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
		gameplay.changed.emit()
	# A conversation hides this caption; keep its remaining reading time intact.
	if not gameplay.dialogue.active:
		story_time = maxf(0, story_time-delta)
	story_label.visible = story_time > 0 and not gameplay.dialogue.active
	get_node("Station/ShiftBoard").prompt = "Finish shift" if phase == Phase.ACTIVE and gameplay.can_finish() else "Shift notes / Start night"
	var target: Node3D = player.interaction_target
	prompt.text = "[E]  " + target.prompt if is_instance_valid(target) else ""
	if customer_ready and layout.at_operator(player) and not gameplay.dialogue.active:
		prompt.text += "   [F] Talk" + (" — Ask about the phone call" if special else "")
	message_time = maxf(0,message_time-delta)
	message.visible = message_time > 0
	dialogue_label.visible = gameplay.dialogue.active
	dialogue_label.text = gameplay.dialogue.display_text()
	radio.globally_muted = muted

func _exit_tree() -> void:
	ambience.stop()
	feedback.stop()
	ambience.stream = null
	feedback.stream = null

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
		_say("Schicht gespeichert." if phase == Phase.COMPLETE and checkpoint.write_checkpoint(gameplay) else "Speichern ist nur nach abgeschlossener Schicht möglich.")
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F9:
		if phase == Phase.NOT_STARTED and checkpoint.load_checkpoint(gameplay):
			_say("Bestände geladen. Nächste Schicht am Schichtzettel starten.")
			_update_objective()
		else:
			_say("Kein gültiger Spielstand oder Schicht bereits gestartet.")
	if event.is_action_pressed("mute_audio"):
		muted = not muted
		ambience.volume_db = -80 if muted else -30
		feedback.volume_db = -80 if muted else -22
		_say("Ton aus" if muted else "Ton an")
	if event.is_action_pressed("restart_shift") and phase == Phase.COMPLETE:
		get_tree().reload_current_scene()

func _on_used(action: StringName) -> void:
	if action == &"radio":
		radio.toggle()
		_say("Radio on" if radio.enabled else "Radio off")
		return
	if phase == Phase.COMPLETE:
		_say("Schicht beendet. Mit R erneut spielen.")
		return
	if action == &"start":
		if phase == Phase.ACTIVE and gameplay.can_finish():
			phase = Phase.COMPLETE
			gameplay.active = false
			if get_tree().get_meta("nightshift_menu_session",false): menu.show_page("complete")
			_say("Night complete. Your summary is ready.",8)
		elif phase == Phase.NOT_STARTED:
			phase = Phase.ACTIVE
			gameplay.start()
		else:
			_say("Kunden bedienen, Wasser nachfüllen, Kühlung und Lieferung erledigen.")
	elif phase == Phase.NOT_STARTED:
		_say("Lies zuerst den Schichtzettel am Mitarbeiterplatz.")
	elif not gameplay.preparing:
		gameplay.interact(action,player)
	completed = gameplay.tasks
	_update_objective()

func _update_objective() -> void:
	if phase == Phase.NOT_STARTED:
		objective.text = "NIGHT %d / SHIFT START\nRead the shift notes behind the counter.\nCompleted nights: %d | Total CHF %.2f" % [gameplay.career_shifts+1,gameplay.career_shifts,float(gameplay.career_revenue)/100]
	elif phase == Phase.ACTIVE:
		objective.text = "Kundenwege werden vorbereitet …" if gameplay.preparing else gameplay.status_text()
	else:
		objective.text = "SCHICHT BEENDET\n%d Kunden | %d verloren | %d Artikel | CHF %.2f | %d Aufgaben\n[N] Save & next night  [F5] Save  [R] Restart  [F9 at start] Load" % [gameplay.served,gameplay.lost_sales,gameplay.sold_units,float(gameplay.revenue_rappen)/100,gameplay.tasks.size()]

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
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D: node.bus = &"SFX"
	for child in node.get_children(): route_audio(child)
