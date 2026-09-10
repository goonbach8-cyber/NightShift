extends Node3D

enum Phase { NOT_STARTED, ACTIVE, COMPLETE }
var phase: Phase = Phase.NOT_STARTED
var completed: Dictionary = {}
var message_time: float = 0.0
var muted: bool = false

@onready var player: CharacterBody3D = $Player
@onready var objective: Label = $HUD/Objective
@onready var prompt: Label = $HUD/Prompt
@onready var message: Label = $HUD/Message
@onready var ambience: AudioStreamPlayer = $Ambience
@onready var feedback: AudioStreamPlayer = $Feedback


func _ready() -> void:
	for object in get_tree().get_nodes_in_group("interactable"):
		object.used.connect(_on_used)
	$Station/Door.blocked.connect(func(): _say("Der Durchgang muss frei bleiben."))
	ambience.stream = _tone(true)
	feedback.stream = _tone(false)
	ambience.play()
	_update_objective()


func _process(delta: float) -> void:
	var target: Node3D = player.interaction_target
	prompt.text = "[E]  " + target.prompt if is_instance_valid(target) else ""
	message_time = maxf(0.0, message_time - delta)
	message.visible = message_time > 0.0


func _exit_tree() -> void:
	# Release synthesized streams explicitly on scene reload and shutdown.
	ambience.stop()
	feedback.stop()
	ambience.stream = null
	feedback.stream = null


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute_audio"):
		muted = not muted
		ambience.volume_db = -80.0 if muted else -30.0
		feedback.volume_db = -80.0 if muted else -22.0
		_say("Ton aus" if muted else "Ton an")
	if event.is_action_pressed("restart_shift") and phase == Phase.COMPLETE:
		get_tree().reload_current_scene()


func _on_used(action_id: StringName) -> void:
	if phase == Phase.COMPLETE:
		_say("Kontrollrunde erledigt. Mit R erneut spielen.")
		return
	if action_id == &"start":
		if phase == Phase.NOT_STARTED:
			phase = Phase.ACTIVE
			_say("23:40. Kühlung prüfen und Getränke auffüllen. Danach an der Kasse bestätigen.")
		else:
			_say("Kühlung und Getränke kontrollieren, danach zur Kasse.")
	elif phase == Phase.NOT_STARTED:
		_say("Lies zuerst den Schichtzettel neben dem Eingang.")
	elif action_id in [&"cooler", &"shelf"]:
		if completed.has(action_id):
			_say("Bereits erledigt.")
		else:
			completed[action_id] = true
			_say("Kühlung: 4 °C. Alles in Ordnung." if action_id == &"cooler" else "Getränke aufgefüllt. Das Regal ist bereit.")
	elif action_id == &"finish":
		if completed.size() == 2:
			phase = Phase.COMPLETE
			_say("00:05. Kontrollrunde abgeschlossen. Einen ruhigen Dienst!", 8.0)
		else:
			_say("Es fehlen noch Aufgaben auf deinem Schichtzettel.")
	_update_objective()


func _update_objective() -> void:
	if phase == Phase.NOT_STARTED:
		objective.text = "NIGHTSHIFT  /  23:40\nLies den Schichtzettel links neben dem Eingang."
	elif phase == Phase.ACTIVE:
		objective.text = "NIGHTSHIFT  /  KONTROLLRUNDE\n%s Kühlung prüfen    %s Getränke auffüllen\nDanach: an der Kasse bestätigen." % ["[x]" if completed.has(&"cooler") else "[ ]", "[x]" if completed.has(&"shelf") else "[ ]"]
	else:
		objective.text = "NIGHTSHIFT  /  00:05\nKontrollrunde abgeschlossen.  [R] Erneut spielen"


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
