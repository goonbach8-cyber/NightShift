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
var dialogue_backdrop: PanelContainer
var checkout_label: Label
var checkout_backdrop: PanelContainer
var story_world: Node3D
var hud: Control
var checkout_minigame: Node
var pump_service: Node
var cctv_system: Node
var power_service: Node
var delivery_check: Node
var phone_system: Node
var customer_assistance: Node
var spill_service: Node
var radio_tuner: Node
var device_service: Node
var customer_requests: Node
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
	hud = preload("res://scripts/ui/shift_hud.gd").new()
	hud.world = self
	$HUD.add_child(hud)
	for old_name in ["ObjectiveBackdrop","Objective","Prompt","Message","Controls"]:
		$HUD.get_node(old_name).hide()
	objective = hud.objective
	prompt = hud.prompt
	message = hud.message
	story_label = hud.story
	dialogue_label = hud.conversation.body
	dialogue_backdrop = hud.conversation.frame
	checkout_label = hud.checkout_progress
	checkout_backdrop = hud.checkout_panel
	checkout_minigame = preload("res://scripts/checkout_minigame.gd").new()
	checkout_minigame.name = "CheckoutMinigame"
	checkout_minigame.world = self
	add_child(checkout_minigame)
	pump_service = preload("res://scripts/pump_service.gd").new()
	pump_service.name = "PumpService"
	pump_service.world = self
	add_child(pump_service)
	cctv_system = preload("res://scripts/cctv_system.gd").new()
	cctv_system.name = "CCTVSystem"
	cctv_system.world = self
	add_child(cctv_system)
	power_service = preload("res://scripts/power_service.gd").new()
	power_service.name = "PowerService"
	power_service.world = self
	add_child(power_service)
	delivery_check = preload("res://scripts/delivery_check.gd").new()
	delivery_check.name = "DeliveryCheck"
	delivery_check.world = self
	add_child(delivery_check)
	phone_system = preload("res://scripts/phone_system.gd").new()
	phone_system.name = "PhoneSystem"
	phone_system.world = self
	add_child(phone_system)
	customer_assistance = preload("res://scripts/customer_assistance.gd").new()
	customer_assistance.name = "CustomerAssistance"
	customer_assistance.world = self
	add_child(customer_assistance)
	spill_service = preload("res://scripts/spill_service.gd").new()
	spill_service.name = "SpillService"
	spill_service.world = self
	add_child(spill_service)
	radio_tuner = preload("res://scripts/radio_tuner.gd").new()
	radio_tuner.name = "RadioTuner"
	radio_tuner.world = self
	add_child(radio_tuner)
	device_service = preload("res://scripts/device_service.gd").new()
	device_service.name = "DeviceService"
	device_service.world = self
	add_child(device_service)
	customer_requests = preload("res://scripts/customer_requests.gd").new()
	customer_requests.name = "CustomerRequests"
	customer_requests.world = self
	add_child(customer_requests)
	gameplay.dialogue.changed.connect(_dialogue_changed)
	for object in get_tree().get_nodes_in_group("interactable"):
		object.used.connect(_on_used)
	$Station/Door.blocked.connect(func(): _say("Keep the doorway clear."))
	ambience.stream = _tone(true)
	feedback.stream = _tone(false)
	ambience.play()
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
	var customer_ready: bool = gameplay.checkout_ready()
	story_cooldown = maxf(0,story_cooldown-delta)
	var ready_event := -1
	for i in pending_events.size():
		var candidate: Resource = pending_events[i]
		var in_area: bool = candidate.required_area == &"" or gameplay.events.occupied_areas.has(candidate.required_area)
		if in_area and (not candidate.at_checkout or (layout.at_operator(player) and customer_ready)):
			ready_event = i
			break
	var checkout_busy: bool = is_instance_valid(checkout_minigame) and checkout_minigame.active
	var pump_busy: bool = is_instance_valid(pump_service) and pump_service.active
	var cctv_busy: bool = is_instance_valid(cctv_system) and cctv_system.active
	var power_busy: bool = is_instance_valid(power_service) and power_service.active
	var delivery_busy: bool = is_instance_valid(delivery_check) and delivery_check.active
	var phone_busy: bool = is_instance_valid(phone_system) and phone_system.active
	var spill_busy: bool = is_instance_valid(spill_service) and spill_service.active
	var radio_busy: bool = is_instance_valid(radio_tuner) and radio_tuner.active
	var device_busy: bool = is_instance_valid(device_service) and device_service.active
	if ready_event >= 0 and story_time <= 0 and story_cooldown <= 0 and not gameplay.dialogue.active and not checkout_busy and not pump_busy and not cctv_busy and not power_busy and not delivery_busy and not phone_busy and not spill_busy and not radio_busy and not device_busy:
		var event: Resource = pending_events[ready_event]
		pending_events.remove_at(ready_event)
		story_label.text = event.text
		if not event.show_caption or event.effect in [&"world_state",&"light_dip"]: story_label.text = ""
		story_time = 16
		story_cooldown = gameplay.definition.event_spacing_seconds
		if event.effect == &"light_dip" and not (is_instance_valid(power_service) and power_service.fault_pending): effects.light_dip()
		if event.effect == &"radio_interrupt": radio.interrupt_briefly()
		if event.effect == &"phone_ring":
			if is_instance_valid(phone_system): phone_system.story_ring()
			else: effects.phone_ring()
		if event.effect == &"navigation_chime": effects.navigation_chime()
		if event.effect == &"reality_overlap":
			effects.reality_overlap()
			if is_instance_valid(story_world): story_world.start_overlap()
		if event.effect == &"world_state":
			for prop in get_tree().get_nodes_in_group("story_prop"):
				if prop.target_id == event.effect_target: prop.apply_state()
		if event.event_id == &"night_1_main":
			gameplay.story_flags[&"noticed_call"] = true
		gameplay.story_flags[StringName("presented_"+String(event.event_id))] = true
		gameplay.changed.emit()
	# A conversation hides this caption; keep its remaining reading time intact.
	if not gameplay.dialogue.active:
		story_time = maxf(0, story_time-delta)
	story_label.visible = story_time > 0 and not gameplay.dialogue.active
	get_node("Station/ShiftBoard").prompt = "Finish shift" if phase == Phase.ACTIVE and gameplay.can_finish() else "Shift notes / Start night"
	message_time = maxf(0,message_time-delta)
	hud.update()
	radio.globally_muted = muted

func _exit_tree() -> void:
	ambience.stop()
	feedback.stop()
	ambience.stream = null
	feedback.stream = null

func _dialogue_changed() -> void:
	player.controls_locked = gameplay.dialogue.active or (is_instance_valid(checkout_minigame) and checkout_minigame.active) or (is_instance_valid(pump_service) and pump_service.active) or (is_instance_valid(cctv_system) and cctv_system.active) or (is_instance_valid(power_service) and power_service.active) or (is_instance_valid(delivery_check) and delivery_check.active) or (is_instance_valid(phone_system) and phone_system.active) or (is_instance_valid(spill_service) and spill_service.active) or (is_instance_valid(radio_tuner) and radio_tuner.active) or (is_instance_valid(device_service) and device_service.active)
	player.velocity.x = 0
	player.velocity.z = 0
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	hud.update()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(gameplay) or not gameplay.dialogue.active or menu.page != "": return
	if hud.conversation.handle(event):
		get_viewport().set_input_as_handled()
		return
	var work_shortcut: bool = event is InputEventKey and event.pressed and event.physical_keycode in [KEY_F,KEY_TAB,KEY_T,KEY_Y,KEY_EQUAL,KEY_PLUS,KEY_KP_ADD,KEY_MINUS,KEY_KP_SUBTRACT]
	if event.is_action_pressed("interact") or work_shortcut:
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if menu.page != "": return
	if is_instance_valid(checkout_minigame) and checkout_minigame.active: return
	if is_instance_valid(pump_service) and pump_service.active: return
	if is_instance_valid(cctv_system) and cctv_system.active: return
	if is_instance_valid(power_service) and power_service.active: return
	if is_instance_valid(delivery_check) and delivery_check.active: return
	if is_instance_valid(phone_system) and phone_system.active: return
	if is_instance_valid(spill_service) and spill_service.active: return
	if is_instance_valid(radio_tuner) and radio_tuner.active: return
	if is_instance_valid(device_service) and device_service.active: return
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
				if player.interaction_target == get_node("Station/ShiftBoard"):
					var no_choices: Array[Dictionary] = []
					gameplay.dialogue.begin(-60,PackedStringArray([gameplay.definition.briefing]),no_choices,gameplay.story_flags,{"kind":&"document","title":gameplay.definition.title+" / Shift notes"})
				elif phase == Phase.ACTIVE and layout.at_operator(player): gameplay.talk()
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
	if action == &"customer_service_key":
		customer_requests.handle_action(action)
		return
	if action == &"service_tools":
		device_service.handle_action(action)
		return
	if action == &"cooler" and is_instance_valid(device_service) and device_service.handle_action(action):
		return
	if action in [&"cleaning_kit",&"spill_cleanup"]:
		spill_service.handle_action(action)
		return
	if action == &"phone":
		phone_system.begin()
		return
	if action == &"delivery" and DisplayServer.get_name() != "headless":
		if delivery_check.begin():
			return
	if action == &"breaker_panel":
		power_service.begin()
		return
	if action == &"cctv_terminal":
		cctv_system.begin()
		return
	if String(action).begins_with("pump_reset_"):
		var pump_number := int(String(action).trim_prefix("pump_reset_"))
		pump_service.reset_fault(pump_number)
		return
	if action == &"pump_terminal":
		if is_instance_valid(customer_requests) and customer_requests.handle_pump_terminal():
			return
		if is_instance_valid(checkout_minigame) and checkout_minigame.active:
			return
		pump_service.begin()
		return
	# Later-shift customers can ask for grounded station help before the sale continues.
	if action == &"finish" and phase == Phase.ACTIVE and gameplay.checkout_ready() and layout.at_operator(player) and is_instance_valid(customer_requests):
		if customer_requests.handle_checkout_use():
			return
	# One customer per shift can also lose a personal item in the shop.
	if action == &"finish" and phase == Phase.ACTIVE and gameplay.checkout_ready() and layout.at_operator(player) and is_instance_valid(customer_assistance):
		if customer_assistance.handle_checkout_use():
			return
	# Rendererless automation keeps the direct checkout path. In the actual game,
	# the same inventory/payment rules are driven by the physical checkout interaction.
	if action == &"finish" and phase == Phase.ACTIVE and gameplay.checkout_ready() and layout.at_operator(player) and not gameplay.quick_checkout and DisplayServer.get_name() != "headless":
		if checkout_minigame.begin():
			_update_objective()
			return
	if action == &"radio":
		radio_tuner.begin()
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

func can_start_interrupt(source: Node = null) -> bool:
	if phase != Phase.ACTIVE or not gameplay.active or gameplay.dialogue.active or story_time > 0:
		return false
	for system in [checkout_minigame,pump_service,cctv_system,power_service,delivery_check,phone_system,spill_service,radio_tuner,device_service]:
		if system != source and is_instance_valid(system) and bool(system.get("active")):
			return false
	if source != pump_service and is_instance_valid(pump_service) and (pump_service.request_pending or pump_service.fault_pending):
		return false
	if source != cctv_system and is_instance_valid(cctv_system) and cctv_system.motion_pending:
		return false
	if source != power_service and is_instance_valid(power_service) and power_service.fault_pending:
		return false
	if source != phone_system and is_instance_valid(phone_system) and phone_system.ringing:
		return false
	if source != spill_service and is_instance_valid(spill_service) and (spill_service.spill_pending or spill_service.return_required):
		return false
	if source != radio_tuner and is_instance_valid(radio_tuner) and radio_tuner.drift_pending:
		return false
	if source != device_service and is_instance_valid(device_service) and (device_service.fault_pending or device_service.return_required):
		return false
	if is_instance_valid(customer_assistance) and customer_assistance.request_active:
		return false
	if is_instance_valid(customer_requests) and customer_requests.active:
		return false
	return true

func _update_objective() -> void:
	if is_instance_valid(hud) and is_instance_valid(story_world): hud.update()

func _say(text: String, seconds: float = 4.5) -> void:
	hud.show_notice(text)
	message_time = 2.2 if text.begins_with("Wrong shelf") else seconds
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
