extends Node
## Small diegetic tuning interaction for the shop radio. The player can fine-tune
## frequencies and occasionally correct signal drift without leaving the fiction.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D
var radio: AudioStreamPlayer

var active := false
var selected_frequency := 91.7
var drift_pending := false
var drift_target := 0.0
var next_drift_at := 78.0
var drift_done := false
var hidden_listen_time := 0.0

var panel: PanelContainer
var title: Label
var frequency_label: Label
var station_label: Label
var strength_label: Label
var help: Label

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	radio = world.radio
	_build_ui()
	set_process(true)
	_update_prompt()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "RadioTunerPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.34
	panel.anchor_right = 0.66
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -185
	panel.offset_bottom = -28
	var column := STYLE.column(panel,5)
	title = STYLE.text(column,18,STYLE.ACCENT)
	frequency_label = STYLE.text(column,30)
	station_label = STYLE.text(column,16)
	strength_label = STYLE.text(column,14,STYLE.MUTED)
	help = STYLE.text(column,13,STYLE.MUTED)
	for label in [title,frequency_label,station_label,strength_label,help]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func _process(delta: float) -> void:
	if gameplay == null:
		return
	radio.set_hidden_station_enabled(gameplay.career_shifts >= 3 and gameplay.career_shifts < 6)
	if not gameplay.active:
		return
	if active and gameplay.career_shifts >= 3 and absf(radio.tuned_frequency-101.7) <= 0.12 and radio.signal_strength > 0.75 and radio.enabled and not gameplay.story_flags.get(&"found_unlisted_radio",false):
		hidden_listen_time += delta
		if hidden_listen_time >= 1.2:
			gameplay.story_flags[&"found_unlisted_radio"] = true
			world._say("Radio: ‘...Redwater traffic bulletin. Service Road 14 remains open...’",7.0)
			gameplay.changed.emit()
	else:
		hidden_listen_time = 0.0
	if gameplay.career_shifts < 1 or gameplay.career_shifts >= 5 or drift_done or drift_pending:
		return
	if gameplay.elapsed >= next_drift_at and world.can_start_interrupt(self):
		_trigger_drift()

func _trigger_drift() -> void:
	var current: float = radio.tuned_frequency
	drift_target = current
	var offset := 1.3 if (gameplay.career_shifts+1)%2 == 0 else -1.1
	radio.set_frequency(current+offset)
	drift_pending = true
	radio.interrupt_briefly()
	_update_prompt()
	world._say("The shop radio drifts into static. Retune the station.",6.0)
	gameplay.changed.emit()

func begin() -> bool:
	if active:
		return true
	if world.phase != world.Phase.ACTIVE or not gameplay.active:
		world._say("The radio is available during the shift.")
		return false
	if gameplay.dialogue.active or _other_focus_active():
		return false
	active = true
	hidden_listen_time = 0.0
	selected_frequency = radio.tuned_frequency
	player.controls_locked = true
	player.velocity = Vector3.ZERO
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
	player.controls_locked = gameplay.dialogue.active or _other_focus_active()
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or event.echo:
		return
	var key: Key = event.physical_keycode
	if key == KEY_ESCAPE and event.pressed:
		close()
	elif key in [KEY_LEFT,KEY_A]:
		if event.pressed:
			selected_frequency = clampf(snappedf(selected_frequency-0.1,0.1),88.0,108.0)
			radio.set_frequency(selected_frequency)
			_refresh_ui()
	elif key in [KEY_RIGHT,KEY_D]:
		if event.pressed:
			selected_frequency = clampf(snappedf(selected_frequency+0.1,0.1),88.0,108.0)
			radio.set_frequency(selected_frequency)
			_refresh_ui()
	elif key in [KEY_UP,KEY_W]:
		if event.pressed:
			selected_frequency = clampf(snappedf(selected_frequency+1.0,0.1),88.0,108.0)
			radio.set_frequency(selected_frequency)
			_refresh_ui()
	elif key in [KEY_DOWN,KEY_S]:
		if event.pressed:
			selected_frequency = clampf(snappedf(selected_frequency-1.0,0.1),88.0,108.0)
			radio.set_frequency(selected_frequency)
			_refresh_ui()
	elif key == KEY_T and event.pressed:
		radio.toggle()
		_refresh_ui()
	elif key in [KEY_E,KEY_ENTER,KEY_KP_ENTER] and event.pressed:
		_confirm()
	else:
		return
	get_viewport().set_input_as_handled()

func _confirm() -> void:
	if drift_pending and absf(radio.tuned_frequency-drift_target) <= 0.15:
		drift_pending = false
		drift_done = true
		gameplay.story_flags[StringName("radio_retuned_night_%d" % (gameplay.career_shifts+1))] = true
		_update_prompt()
		world._say("Radio signal restored.",4.0)
		gameplay.changed.emit()
	close()

func _refresh_ui() -> void:
	if not active:
		return
	title.text = "SHOP RADIO · TUNER"
	frequency_label.text = "%.1f FM" % selected_frequency
	station_label.text = "UNLISTED / REDWATER TRAFFIC" if radio.hidden_station_enabled and absf(selected_frequency-101.7) <= 0.12 else radio.station_name()
	strength_label.text = "Signal %d%% · %s" % [roundi(radio.signal_strength*100.0),"ON" if radio.enabled else "OFF"]
	help.text = "← / → fine tune   ·   ↑ / ↓ coarse tune   ·   [T] power   ·   [E] confirm"

func _update_prompt() -> void:
	if not is_instance_valid(layout.radio_point):
		return
	if drift_pending:
		layout.radio_point.prompt = "Radio static · Retune station"
	else:
		layout.radio_point.prompt = "Radio tuner"

func objective_text() -> String:
	return "Retune the shop radio" if drift_pending else ""

func _other_focus_active() -> bool:
	return (is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active) or (is_instance_valid(world.pump_service) and world.pump_service.active) or (is_instance_valid(world.cctv_system) and world.cctv_system.active) or (is_instance_valid(world.power_service) and world.power_service.active) or (is_instance_valid(world.delivery_check) and world.delivery_check.active) or (is_instance_valid(world.phone_system) and world.phone_system.active) or (is_instance_valid(world.spill_service) and world.spill_service.active) or (is_instance_valid(world.device_service) and world.device_service.active)

