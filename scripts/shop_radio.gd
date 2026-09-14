extends AudioStreamPlayer
var enabled: bool = false
var level_db: float = -30
var track_index: int = 0
var interrupted: float = 0
var globally_muted: bool = false
var tracks: Array[AudioStream] = []

func _ready() -> void:
	for base in [110.0,146.83]:
		tracks.append(make_track(base))
	stream = tracks[0]
	volume_db = level_db

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

func toggle() -> void:
	enabled = not enabled
	if enabled: play()
	else: stop()

func next_track() -> void:
	track_index = (track_index+1) % tracks.size()
	stream = tracks[track_index]
	if enabled: play()

func change_volume(amount: float) -> void:
	level_db = clampf(level_db+amount,-45,-15)

func interrupt_briefly() -> void:
	interrupted = 2.5

func _process(delta: float) -> void:
	interrupted = maxf(0,interrupted-delta)
	volume_db = -80 if globally_muted or interrupted > 0 else level_db

func _exit_tree() -> void:
	stop()
	stream = null
	tracks.clear()
