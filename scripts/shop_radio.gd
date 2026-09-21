extends AudioStreamPlayer
var enabled: bool = false
var level_db: float = -30
var track_index: int = 0
var interrupted: float = 0
var globally_muted: bool = false
var tracks: Array[AudioStream] = []
var static_player: AudioStreamPlayer

func _ready() -> void:
	for base in [110.0,146.83]:
		tracks.append(make_track(base))
	stream = tracks[0]
	volume_db = level_db
	static_player = AudioStreamPlayer.new()
	static_player.bus = &"Radio"
	static_player.stream = make_static()
	static_player.volume_db = -21
	add_child(static_player)

func make_track(base: float) -> AudioStreamWAV:
	# Original quiet musical placeholders, no third-party recordings.
	var rate := 22050
	var count := rate*4
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var envelope := pow(sin(PI*t/4),2)
		var sample := (sin(TAU*base*t)+0.3*sin(TAU*base*1.5*t))*envelope*0.18
		bytes.encode_s16(i*2,int(sample*20000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_end = count
	return sound

func make_static() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 1.35
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31717
	var filtered := 0.0
	for i in count:
		var t := float(i)/rate
		filtered = lerpf(filtered,rng.randf_range(-1.0,1.0),0.28)
		var envelope := minf(1.0,minf(t/0.04,(seconds-t)/0.08))
		var sample := (filtered*0.75+sin(TAU*97.0*t)*0.12)*envelope
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*18000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	return sound

func toggle() -> void:
	enabled = not enabled
	if enabled:
		play()
	else:
		stop()

func next_track() -> void:
	track_index = (track_index+1) % tracks.size()
	stream = tracks[track_index]
	if enabled:
		play()

func change_volume(amount: float) -> void:
	level_db = clampf(level_db+amount,-45,-15)

func interrupt_briefly() -> void:
	interrupted = 2.5
	if is_instance_valid(static_player):
		static_player.play()

func _process(delta: float) -> void:
	interrupted = maxf(0,interrupted-delta)
	volume_db = -80 if globally_muted or interrupted > 0 else level_db
	if is_instance_valid(static_player):
		static_player.volume_db = -80 if globally_muted else clampf(level_db+7,-28,-15)

func _exit_tree() -> void:
	stop()
	stream = null
	tracks.clear()
	if is_instance_valid(static_player):
		static_player.stop()
		static_player.stream = null
