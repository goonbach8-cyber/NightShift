extends Node
## Diegetic counter-phone workflow: incoming work calls, the 03:17 story call,
## a simple keypad and a persistent call log for the current shift.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var mode: StringName = &"idle"
var ringing := false
var ring_elapsed := 0.0
var ring_timeout := 14.0
var incoming_kind: StringName = &""
var incoming_caller := ""
var incoming_number := ""
var call_lines := PackedStringArray()
var call_index := 0
var call_choices: Array[Dictionary] = []
var dial_buffer := ""
var call_log: Array[Dictionary] = []
var work_call_done := false
var next_work_call_at := 62.0

var panel: PanelContainer
var title: Label
var display: Label
var body: Label
var choices_label: Label
var help: Label
var ring_player: AudioStreamPlayer
var key_player: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	_build_ui()
	ring_player = AudioStreamPlayer.new()
	ring_player.bus = &"SFX"
	ring_player.volume_db = -10
	ring_player.stream = _ringtone()
	add_child(ring_player)
	key_player = AudioStreamPlayer.new()
	key_player.bus = &"SFX"
	key_player.volume_db = -13
	key_player.stream = _key_tone()
	add_child(key_player)
	set_process(true)
	_update_phone_display()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "PhonePanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.31
	panel.anchor_right = 0.69
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -235
	panel.offset_bottom = -28
	var column := STYLE.column(panel,6)
	title = STYLE.text(column,18,STYLE.ACCENT)
	display = STYLE.text(column,15,STYLE.MUTED)
	body = STYLE.text(column,18)
	choices_label = STYLE.text(column,14,STYLE.ACCENT)
	help = STYLE.text(column,13,STYLE.MUTED)
	for label in [title,display,body,choices_label,help]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func _process(delta: float) -> void:
	if gameplay == null:
		return
	if gameplay.active and gameplay.career_shifts >= 1 and not work_call_done and not ringing and not active and gameplay.elapsed >= next_work_call_at and world.can_start_interrupt(self):
		_queue_work_call()
	if ringing:
		ring_elapsed += delta
		if ring_elapsed >= ring_timeout:
			_miss_call()

func story_ring() -> void:
	if ringing or gameplay.story_flags.get(&"phone_0317_started",false):
		return
	gameplay.story_flags[&"phone_0317_started"] = true
	_start_incoming(
		&"0317",
		"UNKNOWN",
		"03:17",
		PackedStringArray([
			"There is no voice.",
			"A low room tone comes through the receiver, almost identical to the station around you.",
			"The line disconnects."
		]),
		[]
	)

func _queue_work_call() -> void:
	var night: int = gameplay.career_shifts+1
	var caller := "Riverline Dispatch"
	var number := "4417"
	var lines := PackedStringArray(["Night delivery desk. Is the rear service gate clear for tonight's drop?"])
	var choices: Array[Dictionary] = [
		{"text":"1  Confirm the gate is clear","flag":&"dispatch_gate_confirmed","reply":"Copy. Driver will use the rear yard."},
		{"text":"2  Ask them to call back later","flag":&"dispatch_gate_delayed","reply":"Understood. We'll hold the driver and call again."}
	]
	if night == 3:
		caller = "Maintenance Desk"
		number = "2230"
		lines = PackedStringArray(["Routine refrigeration check. Is the shop cooler still holding at four degrees?"])
		choices = [
			{"text":"1  Confirm 4 °C","flag":&"maintenance_cooler_confirmed","reply":"Logged. No technician needed."},
			{"text":"2  Request a technician","flag":&"maintenance_visit_requested","reply":"Request logged. Earliest slot is tomorrow morning."}
		]
	elif night == 4:
		caller = "Depot Collections"
		number = "6142"
		lines = PackedStringArray(["Collections desk. Your station route is still showing active. Do you need the usual depot handover?"])
		choices = [
			{"text":"1  Confirm collection","flag":&"depot_call_confirmed","reply":"Good. The collection will be waiting."},
			{"text":"2  Ask which station they mean","flag":&"depot_call_questioned","reply":"Station 14. Same account as always."}
		]
	elif night >= 5:
		caller = "Road Works Desk"
		number = "5803"
		lines = PackedStringArray(["Evening. Access works beside the service station are still on schedule. Any obstruction at the forecourt?"])
		choices = [
			{"text":"1  Report forecourt clear","flag":&"roadworks_clear","reply":"Thank you. Crew entry remains scheduled."},
			{"text":"2  Ask when the road opened","flag":&"roadworks_questioned","reply":"Opened? The construction start is logged for today."}
		]
	_start_incoming(&"work",caller,number,lines,choices)

func _start_incoming(kind: StringName, caller: String, number: String, lines: PackedStringArray, choices: Array[Dictionary]) -> void:
	incoming_kind = kind
	incoming_caller = caller
	incoming_number = number
	call_lines = lines
	call_choices = choices.duplicate(true)
	call_index = 0
	ringing = true
	ring_elapsed = 0.0
	mode = &"ringing"
	if not ring_player.playing:
		ring_player.play()
	_update_phone_display()
	gameplay.changed.emit()

func begin() -> bool:
	if active:
		return true
	if world.has_interaction_focus(self):
		return false
	if world.phase != world.Phase.ACTIVE or not gameplay.active:
		world._say("The counter phone is used during the shift.")
		return false
	if gameplay.dialogue.active:
		return false
	if _other_focus_active():
		return false
	active = true
	player.controls_locked = true
	player.velocity = Vector3.ZERO
	for action in ["move_left","move_right","move_forward","move_backward"]:
		Input.action_release(action)
	if ringing:
		mode = &"ringing"
	else:
		mode = &"dial"
		dial_buffer = ""
	_lift_handset(true)
	panel.show()
	_refresh_ui()
	world._update_objective()
	return true

func close() -> void:
	if not active:
		return
	active = false
	panel.hide()
	if mode != &"call":
		_lift_handset(false)
	mode = &"ringing" if ringing else &"idle"
	player.controls_locked = world.has_interaction_focus(self)
	_update_phone_display()
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key == KEY_ESCAPE:
		if mode == &"call":
			_end_call(false)
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if mode == &"ringing":
		if key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:
			_answer()
		elif key in [KEY_X,KEY_BACKSPACE]:
			_ignore()
		else:
			return
	elif mode == &"call":
		if not call_choices.is_empty() and call_index >= call_lines.size()-1:
			if key == KEY_1:
				_choose(0)
			elif key == KEY_2 and call_choices.size() > 1:
				_choose(1)
			elif key in [KEY_E,KEY_ENTER,KEY_KP_ENTER]:
				_refresh_ui()
			else:
				return
		elif key in [KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:
			_advance_call()
		else:
			return
	elif mode == &"dial":
		var digit := _digit_for_key(key)
		if digit != "":
			if dial_buffer.length() < 8:
				dial_buffer += digit
				key_player.play()
				_refresh_ui()
		elif key == KEY_BACKSPACE:
			if not dial_buffer.is_empty():
				dial_buffer = dial_buffer.left(dial_buffer.length()-1)
				key_player.play()
				_refresh_ui()
		elif key in [KEY_ENTER,KEY_KP_ENTER,KEY_E]:
			_dial()
		elif key == KEY_L:
			mode = &"log"
			_refresh_ui()
		else:
			return
	elif mode == &"log":
		if key in [KEY_E,KEY_ENTER,KEY_KP_ENTER,KEY_L]:
			mode = &"dial"
			_refresh_ui()
		else:
			return
	get_viewport().set_input_as_handled()

func _answer() -> void:
	if not ringing:
		return
	ringing = false
	ring_player.stop()
	ring_elapsed = 0.0
	mode = &"call"
	call_index = 0
	_lift_handset(true)
	call_log.push_front({"caller":incoming_caller,"number":incoming_number,"result":"answered"})
	if incoming_kind == &"0317":
		gameplay.story_flags[&"answered_0317"] = true
	gameplay.changed.emit()
	_update_phone_display()
	_refresh_ui()

func _ignore() -> void:
	if not ringing:
		return
	call_log.push_front({"caller":incoming_caller,"number":incoming_number,"result":"ignored"})
	if incoming_kind == &"0317":
		gameplay.story_flags[&"ignored_0317"] = true
	else:
		work_call_done = true
	_clear_incoming()
	close()
	_update_phone_display()
	gameplay.changed.emit()

func _miss_call() -> void:
	if not ringing:
		return
	call_log.push_front({"caller":incoming_caller,"number":incoming_number,"result":"missed"})
	if incoming_kind == &"0317":
		gameplay.story_flags[&"missed_0317"] = true
	else:
		work_call_done = true
	_clear_incoming()
	# An open incoming-call panel must not retain its now-unanswerable mode.
	close()
	_update_phone_display()
	gameplay.changed.emit()

func _advance_call() -> void:
	if call_lines.is_empty():
		_end_call(true)
		return
	if call_index < call_lines.size()-1:
		call_index += 1
		_refresh_ui()
	elif call_choices.is_empty():
		_end_call(true)

func _choose(index: int) -> void:
	if index < 0 or index >= call_choices.size():
		return
	var choice: Dictionary = call_choices[index]
	var flag: StringName = choice.get("flag",&"")
	if flag != &"":
		gameplay.story_flags[flag] = true
	var reply := String(choice.get("reply",""))
	call_choices.clear()
	if not reply.is_empty():
		call_lines = PackedStringArray([reply])
		call_index = 0
		_refresh_ui()
		await get_tree().create_timer(0.65).timeout
	_end_call(true)

func _end_call(completed: bool) -> void:
	if incoming_kind == &"work":
		work_call_done = true
		if gameplay.story_flags.get(&"dispatch_gate_delayed",false):
			work_call_done = false
			next_work_call_at = gameplay.elapsed+38.0
	if incoming_kind == &"0317" and completed:
		gameplay.story_flags[&"completed_0317_call"] = true
	_clear_incoming()
	_lift_handset(false)
	active = false
	panel.hide()
	mode = &"idle"
	player.controls_locked = world.has_interaction_focus(self)
	_update_phone_display()
	gameplay.changed.emit()
	world._update_objective()

func _dial() -> void:
	if dial_buffer.is_empty():
		body.text = "Enter a number first."
		return
	key_player.play()
	var number := dial_buffer
	dial_buffer = ""
	if number == "0317":
		gameplay.story_flags[&"dialed_0317"] = true
		incoming_kind = &"outgoing"
		incoming_caller = "03:17"
		incoming_number = number
		call_lines = PackedStringArray([
			"The line rings once.",
			"Through the receiver you hear the counter phone ringing in the same room, a fraction of a second early.",
			"Then the connection drops."
		])
		call_choices.clear()
		call_index = 0
		mode = &"call"
		call_log.push_front({"caller":"03:17","number":number,"result":"outgoing"})
		_refresh_ui()
		return
	if number == "4417":
		_begin_outgoing("Riverline Dispatch",number,PackedStringArray(["Riverline night desk. No new messages for your station."]))
		return
	if number == "6142":
		_begin_outgoing("Depot Collections",number,PackedStringArray(["Collections desk. Station 14 account is active."]))
		return
	body.text = "NUMBER NOT IN SERVICE"
	display.text = number
	help.text = "Backspace edit   ·   type another number   ·   [L] call log   ·   ESC hang up"

func _begin_outgoing(caller: String, number: String, lines: PackedStringArray) -> void:
	incoming_kind = &"outgoing"
	incoming_caller = caller
	incoming_number = number
	call_lines = lines
	call_choices.clear()
	call_index = 0
	mode = &"call"
	call_log.push_front({"caller":caller,"number":number,"result":"outgoing"})
	_refresh_ui()

func _clear_incoming() -> void:
	ringing = false
	ring_player.stop()
	ring_elapsed = 0.0
	incoming_kind = &""
	incoming_caller = ""
	incoming_number = ""
	call_lines = PackedStringArray()
	call_choices.clear()
	call_index = 0

func _refresh_ui() -> void:
	if not active:
		return
	if mode == &"ringing":
		title.text = "COUNTER PHONE · INCOMING"
		display.text = incoming_number+"  ·  "+incoming_caller
		body.text = "The phone is ringing."
		choices_label.text = ""
		help.text = "[E / ENTER] answer   ·   [X / BACKSPACE] ignore   ·   ESC step away"
	elif mode == &"call":
		title.text = "CALL · "+incoming_caller
		display.text = incoming_number
		body.text = call_lines[call_index] if not call_lines.is_empty() else "..."
		if not call_choices.is_empty() and call_index >= call_lines.size()-1:
			var lines := PackedStringArray()
			for i in call_choices.size():
				lines.append(String(call_choices[i].text))
			choices_label.text = "\n".join(lines)
			help.text = "[1 / 2] respond   ·   ESC hang up"
		else:
			choices_label.text = ""
			help.text = "[E / ENTER] continue   ·   ESC hang up"
	elif mode == &"log":
		title.text = "PHONE · CALL LOG"
		display.text = "%d calls this shift" % call_log.size()
		var lines := PackedStringArray()
		for i in mini(call_log.size(),5):
			var item: Dictionary = call_log[i]
			lines.append("%s  %s  ·  %s" % [item.number,item.caller,String(item.result).to_upper()])
		body.text = "\n".join(lines) if not lines.is_empty() else "No calls logged."
		choices_label.text = ""
		help.text = "[E / L] return to keypad   ·   ESC hang up"
	else:
		title.text = "COUNTER PHONE · KEYPAD"
		display.text = dial_buffer if not dial_buffer.is_empty() else "_ _ _ _"
		body.text = "Enter a number or review the call log."
		choices_label.text = ""
		help.text = "0–9 dial   ·   Backspace edit   ·   [ENTER] call   ·   [L] call log   ·   ESC hang up"

func _update_phone_display() -> void:
	if not is_instance_valid(layout.phone_display):
		return
	layout.phone_point.selection_bias = -0.35 if ringing else 0.4
	if ringing:
		layout.phone_display.text = "INCOMING\n"+incoming_number
		layout.phone_display.modulate = Color("e1b36e")
		layout.phone_point.prompt = "Answer phone · "+incoming_number
	elif not call_log.is_empty() and String(call_log[0].result) == "missed":
		layout.phone_display.text = "MISSED\n"+String(call_log[0].number)
		layout.phone_display.modulate = Color("d98676")
		layout.phone_point.prompt = "Counter phone · Missed call"
	else:
		layout.phone_display.text = "READY"
		layout.phone_display.modulate = Color("cbe3a7")
		layout.phone_point.prompt = "Counter phone"

func _lift_handset(lifted: bool) -> void:
	if not is_instance_valid(layout.phone_handset):
		return
	var target := Vector3(0,0.16,0.03) if lifted else Vector3.ZERO
	var angle := -0.18 if lifted else 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(layout.phone_handset,"position",target,0.16)
	tween.tween_property(layout.phone_handset,"rotation:z",angle,0.16)

func _other_focus_active() -> bool:
	return world.has_interaction_focus(self)

func _digit_for_key(key: Key) -> String:
	match key:
		KEY_0, KEY_KP_0: return "0"
		KEY_1, KEY_KP_1: return "1"
		KEY_2, KEY_KP_2: return "2"
		KEY_3, KEY_KP_3: return "3"
		KEY_4, KEY_KP_4: return "4"
		KEY_5, KEY_KP_5: return "5"
		KEY_6, KEY_KP_6: return "6"
		KEY_7, KEY_KP_7: return "7"
		KEY_8, KEY_KP_8: return "8"
		KEY_9, KEY_KP_9: return "9"
	return ""

func _ringtone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 1.4
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var pulse := 1.0 if (t < 0.28 or (t > 0.48 and t < 0.76)) else 0.0
		var sample := (sin(TAU*640.0*t)*0.42+sin(TAU*790.0*t)*0.20)*pulse
		bytes.encode_s16(i*2,int(clampf(sample,-1.0,1.0)*17000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = count
	return sound

func _key_tone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.07
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var env := sin(PI*float(i)/count)
		var sample := (sin(TAU*697.0*t)+sin(TAU*1209.0*t))*0.20*env
		bytes.encode_s16(i*2,int(sample*15000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
