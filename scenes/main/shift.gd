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
var dialogue_label: Label
@onready var player: CharacterBody3D = $Player
@onready var objective: Label = $HUD/Objective
@onready var prompt: Label = $HUD/Prompt
@onready var message: Label = $HUD/Message
@onready var ambience: AudioStreamPlayer = $Ambience
@onready var feedback: AudioStreamPlayer = $Feedback

func _ready() -> void:
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
	effects = Node.new()
	effects.set_script(preload("res://scripts/event_effects.gd"))
	add_child(effects)
	gameplay.events.triggered.connect(_on_event)
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
	$HUD/ObjectiveBackdrop.offset_right = 980
	$HUD/ObjectiveBackdrop.offset_bottom = 212
	objective.offset_right = 960
	objective.offset_bottom = 215
	objective.add_theme_font_size_override("font_size",18)
	layout.checkout.prompt = "Kassieren / Schicht abschließen"
	$HUD/Controls.text = "WASD Move  E Scan/Pay  TAB Stock  F Talk  Space Continue  T Radio  Y Track  +/- Volume  M Mute"
	$HUD/Controls.add_theme_font_size_override("font_size",13)
	if get_tree().has_meta("nightshift_checkpoint_path"):
		checkpoint.path = get_tree().get_meta("nightshift_checkpoint_path")
	if get_tree().get_meta("nightshift_continue",false):
		get_tree().remove_meta("nightshift_continue")
		if not checkpoint.load_checkpoint(gameplay): _say("Checkpoint could not be loaded. Start a new shift.")
	_update_objective()

func _on_event(event: Resource) -> void:
	_say(event.text,8)
	match event.effect:
		&"light_dip": effects.light_dip()
		&"radio_interrupt": radio.interrupt_briefly()

func _process(delta: float) -> void:
	var target: Node3D = player.interaction_target
	prompt.text = "[E]  " + target.prompt if is_instance_valid(target) else ""
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
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_T:
				radio.toggle()
				_say("Radio on" if radio.enabled else "Radio off")
			KEY_Y:
				radio.next_track()
				_say("Radio track %d" % (radio.track_index+1))
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: radio.change_volume(3)
			KEY_MINUS, KEY_KP_SUBTRACT: radio.change_volume(-3)
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
		gameplay.cycle_supply()
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
	if phase == Phase.COMPLETE:
		_say("Schicht beendet. Mit R erneut spielen.")
		return
	if action == &"start":
		if phase == Phase.NOT_STARTED:
			phase = Phase.ACTIVE
			gameplay.start()
		else:
			_say("Kunden bedienen, Wasser nachfüllen, Kühlung und Lieferung erledigen.")
	elif phase == Phase.NOT_STARTED:
		_say("Lies zuerst den Schichtzettel am Mitarbeiterplatz.")
	elif not gameplay.preparing:
		gameplay.interact(action,player)
		if action == &"finish" and layout.at_operator(player) and gameplay.can_finish():
			phase = Phase.COMPLETE
			gameplay.active = false
			_say("Die Nachtschicht ist abgeschlossen. Gute Heimfahrt!",8)
	completed = gameplay.tasks
	_update_objective()

func _update_objective() -> void:
	if phase == Phase.NOT_STARTED:
		objective.text = "NIGHTSHIFT / SCHICHTBEGINN\nLies den Schichtzettel hinter der Kasse. [F9] Spielstand laden\nAbgeschlossene Schichten: %d | Gesamtumsatz CHF %.2f" % [gameplay.career_shifts,float(gameplay.career_revenue)/100]
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
