extends Node3D
enum Phase { NOT_STARTED, ACTIVE, COMPLETE }
var phase: Phase = Phase.NOT_STARTED
var completed: Dictionary = {}
var message_time: float = 0
var muted: bool = false
var gameplay: Node
var layout: Node
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
	_update_objective()

func _process(delta: float) -> void:
	var target: Node3D = player.interaction_target
	prompt.text = "[E]  " + target.prompt if is_instance_valid(target) else ""
	message_time = maxf(0,message_time-delta)
	message.visible = message_time > 0

func _exit_tree() -> void:
	ambience.stop()
	feedback.stop()
	ambience.stream = null
	feedback.stream = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB and phase == Phase.ACTIVE:
		gameplay.cycle_supply()
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
		objective.text = "NIGHTSHIFT / SCHICHTBEGINN\nLies den Schichtzettel am Mitarbeiterplatz hinter der Kasse."
	elif phase == Phase.ACTIVE:
		objective.text = "Kundenwege werden vorbereitet …" if gameplay.preparing else gameplay.status_text()
	else:
		objective.text = "SCHICHT BEENDET\n%d Kunden | %d verloren | %d Artikel | CHF %.2f | %d Aufgaben\n[R] Neue Schicht" % [gameplay.served,gameplay.lost_sales,gameplay.sold_units,float(gameplay.revenue_rappen)/100,gameplay.tasks.size()]

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
