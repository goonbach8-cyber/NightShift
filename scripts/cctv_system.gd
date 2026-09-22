extends Node
## Diegetic CCTV workstation. It shares the station World3D so the monitor shows
## actual live geometry rather than an abstract menu. Motion checks are short work
## interruptions and can later host story anomalies without changing the workflow.
const STYLE = preload("res://scripts/ui/station_theme.gd")

var world: Node
var gameplay: Node
var layout: Node
var player: CharacterBody3D

var active := false
var selected_channel := 0
var view_time := 0.0
var zoom_fov := 68.0
var motion_pending := false
var motion_channel := -1
var checks_completed := 0
var next_check_at := 42.0
var max_checks := 1

var channels: Array[Dictionary] = []
var viewport: SubViewport
var feed_camera: Camera3D
var feed_texture: TextureRect
var panel: PanelContainer
var channel_label: Label
var timestamp_label: Label
var status: Label
var help: Label
var alert_sound: AudioStreamPlayer

func _ready() -> void:
	if world == null:
		return
	gameplay = world.gameplay
	layout = world.layout
	player = world.player
	_build_channels()
	_build_feed()
	_build_ui()
	alert_sound = AudioStreamPlayer.new()
	alert_sound.bus = &"SFX"
	alert_sound.volume_db = -12
	alert_sound.stream = _tone()
	add_child(alert_sound)
	set_process(true)
	_update_terminal_prompt()

func _build_channels() -> void:
	var entrance := layout.entrance.global_position
	var checkout := layout.checkout.global_position
	var warehouse := layout.warehouse.global_position
	channels = [
		{"name":"CAM 01 · FORECOURT","area":"forecourt","eye":entrance+Vector3(0,5.2,7.6),"target":entrance+Vector3(0,0.7,4.2)},
		{"name":"CAM 02 · ENTRANCE","area":"entrance","eye":entrance+Vector3(-4.8,3.0,-0.6),"target":entrance+Vector3(0,0.9,-1.2)},
		{"name":"CAM 03 · SHOP","area":"shop floor","eye":checkout+Vector3(-4.6,4.4,-1.8),"target":checkout+Vector3(-2.6,0.8,-2.2)},
		{"name":"CAM 04 · SERVICE YARD","area":"service yard","eye":warehouse+Vector3(3.6,4.2,5.0),"target":warehouse+Vector3(0,0.8,1.0)}
	]

func _build_feed() -> void:
	viewport = SubViewport.new()
	viewport.name = "CCTVViewport"
	viewport.size = Vector2i(640,360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = world.get_world_3d()
	add_child(viewport)
	feed_camera = Camera3D.new()
	feed_camera.name = "FeedCamera"
	feed_camera.fov = zoom_fov
	feed_camera.near = 0.08
	feed_camera.far = 90.0
	viewport.add_child(feed_camera)
	feed_camera.current = true
	_apply_channel()

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "CCTVPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.hud.add_child(panel)
	panel.anchor_left = 0.14
	panel.anchor_right = 0.86
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation",8)
	panel.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	channel_label = STYLE.text(top,18,STYLE.ACCENT)
	channel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timestamp_label = STYLE.text(top,15,STYLE.MUTED)
	timestamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	feed_texture = TextureRect.new()
	feed_texture.custom_minimum_size = Vector2(640,360)
	feed_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	feed_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	feed_texture.texture = viewport.get_texture()
	feed_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(feed_texture)

	status = STYLE.text(outer,16)
	help = STYLE.text(outer,13,STYLE.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.hide()

func _process(delta: float) -> void:
	if gameplay == null:
		return
	if gameplay.active:
		max_checks = 1 if gameplay.career_shifts == 0 else 2
		if not motion_pending and checks_completed < max_checks and gameplay.elapsed >= next_check_at:
			_queue_motion_check()
	if not active:
		return
	view_time += delta
	timestamp_label.text = "REC  %02d:%02d:%02d" % [3,int(gameplay.elapsed/60.0)%60,int(gameplay.elapsed)%60]
	_refresh_ui()

func _queue_motion_check() -> void:
	motion_channel = (gameplay.career_shifts+checks_completed*2+1)%channels.size()
	motion_pending = true
	view_time = 0.0
	alert_sound.play()
	_update_terminal_prompt()
	world._say("CCTV motion alert · "+String(channels[motion_channel].area).capitalize(),6.0)
	gameplay.changed.emit()

func begin() -> bool:
	if active:
		return true
	if world.phase != world.Phase.ACTIVE or not gameplay.active:
		world._say("CCTV is available during the shift.")
		return false
	if gameplay.dialogue.active:
		return false
	if is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active:
		return false
	if is_instance_valid(world.pump_service) and world.pump_service.active:
		return false
	active = true
	view_time = 0.0
	if motion_pending:
		selected_channel = (motion_channel+channels.size()-1)%channels.size()
	else:
		selected_channel = 0
	zoom_fov = 68.0
	_apply_channel()
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
	player.controls_locked = gameplay.dialogue.active or (is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active) or (is_instance_valid(world.pump_service) and world.pump_service.active)
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
			selected_channel = wrapi(selected_channel-1,0,channels.size())
			view_time = 0.0
			_apply_channel()
		KEY_RIGHT, KEY_D:
			selected_channel = wrapi(selected_channel+1,0,channels.size())
			view_time = 0.0
			_apply_channel()
		KEY_UP, KEY_W:
			zoom_fov = maxf(38.0,zoom_fov-6.0)
			feed_camera.fov = zoom_fov
		KEY_DOWN, KEY_S:
			zoom_fov = minf(82.0,zoom_fov+6.0)
			feed_camera.fov = zoom_fov
		KEY_E, KEY_ENTER, KEY_KP_ENTER:
			_acknowledge()
		_:
			return
	get_viewport().set_input_as_handled()

func _acknowledge() -> void:
	if not motion_pending:
		status.text = "No active motion alert."
		return
	if selected_channel != motion_channel:
		status.text = "No matching alert on this feed."
		return
	if view_time < 0.7:
		status.text = "Watch the feed for a moment before clearing it."
		return
	motion_pending = false
	checks_completed += 1
	next_check_at = gameplay.elapsed + 55.0 + float((checks_completed+gameplay.career_shifts)%2)*15.0
	status.text = "Motion alert reviewed · no action required."
	motion_channel = -1
	alert_sound.play()
	_update_terminal_prompt()
	gameplay.changed.emit()

func _apply_channel() -> void:
	if channels.is_empty() or not is_instance_valid(feed_camera):
		return
	var data: Dictionary = channels[selected_channel]
	feed_camera.position = data.eye
	feed_camera.fov = zoom_fov
	feed_camera.look_at(data.target,Vector3.UP)
	if is_instance_valid(channel_label):
		channel_label.text = data.name

func _refresh_ui() -> void:
	if not active:
		return
	channel_label.text = String(channels[selected_channel].name)
	if motion_pending:
		if selected_channel == motion_channel:
			status.text = "Motion alert source · review this feed."
		else:
			status.text = "Motion alert active · locate the reported area."
		help.text = "← / → camera   ·   ↑ / ↓ zoom   ·   [E / ENTER] clear reviewed alert   ·   ESC close"
	else:
		status.text = "Live security feed · no active alert."
		help.text = "← / → camera   ·   ↑ / ↓ zoom   ·   ESC close"

func _update_terminal_prompt() -> void:
	if not is_instance_valid(layout.cctv_terminal):
		return
	if motion_pending:
		layout.cctv_terminal.prompt = "CCTV motion alert · "+String(channels[motion_channel].area).capitalize()
	else:
		layout.cctv_terminal.prompt = "Security cameras"

func _tone() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.18
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := sin(PI*float(i)/count)
		var sample := (sin(TAU*520.0*t)*0.55+sin(TAU*780.0*t)*0.28)*envelope
		bytes.encode_s16(i*2,int(sample*16000.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound
