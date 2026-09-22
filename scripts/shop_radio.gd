extends AudioStreamPlayer
## In-world radio audio backend. Frequency tuning lives in radio_tuner.gd; this
## node owns the audible station/static mix and remains usable by story events.
var enabled: bool = false
var level_db: float = -30
var track_index: int = 0
var interrupted: float = 0
var globally_muted: bool = false
var tracks: Array[AudioStream] = []
var station_frequencies: Array[float] = [91.7,96.3,103.1,101.7]
var station_names: Array[String] = ["LOCAL FM","NIGHTLINE","ROAD / WEATHER","UNLISTED"]
var hidden_station_enabled := false
var tuned_frequency := 91.7
var signal_strength := 1.0
var static_player: AudioStreamPlayer
var burst_player: AudioStreamPlayer

func _ready() -> void:
	for base in [110.0,146.83,123.47,174.20]:
		tracks.append(make_track(base))
	stream = tracks[0]
	volume_db = level_db
	static_player = AudioStreamPlayer.new()
	static_player.bus = &"Radio"
	static_player.stream = make_static(true)
	static_player.volume_db = -80
	add_child(static_player)
	static_player.play()
	burst_player = AudioStreamPlayer.new()
	burst_player.bus = &"Radio"
	burst_player.stream = make_static(false)
	burst_player.volume_db = -21
	add_child(burst_player)
	set_frequency(tuned_frequency)

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

func make_static(looping: bool) -> AudioStreamWAV:
	var rate := 22050
	var seconds := 1.35
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31717 if looping else 31718
	var filtered := 0.0
	for i in count:
		var t := float(i)/rate
		filtered = lerpf(filtered,rng.randf_range(-1.0,1.0),0.28)
		var envelope := 1.0 if looping else minf(1.0,minf(t/0.04,(seconds-t)/0.08))
		var sample := (filtered*0.75+sin(TAU*97.0*t)*0.12)*envelope
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*18000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = bytes
	if looping:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = count
	return sound

func toggle() -> void:
	enabled = not enabled
	if enabled:
		if not playing:
			play()
	else:
		stop()

func next_track() -> void:
	var available := _available_indices()
	var current := nearest_station_index()
	var position := available.find(current)
	if position < 0:
		position = 0
	else:
		position = (position+1)%available.size()
	set_frequency(station_frequencies[available[position]])

func set_frequency(value: float) -> void:
	tuned_frequency = clampf(snappedf(value,0.1),88.0,108.0)
	var nearest := nearest_station_index()
	var distance := absf(tuned_frequency-station_frequencies[nearest])
	signal_strength = clampf(1.0-distance/0.8,0.0,1.0)
	if distance <= 0.45:
		if track_index != nearest or stream != tracks[nearest]:
			track_index = nearest
			stream = tracks[track_index]
			if enabled:
				play()
	elif enabled and not playing:
		play()

func nearest_station_index() -> int:
	var available := _available_indices()
	var best := available[0]
	var best_distance := INF
	for i in available:
		var distance := absf(tuned_frequency-station_frequencies[i])
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

func _available_indices() -> Array[int]:
	var result: Array[int] = [0,1,2]
	if hidden_station_enabled:
		result.append(3)
	return result

func set_hidden_station_enabled(value: bool) -> void:
	if hidden_station_enabled == value:
		return
	hidden_station_enabled = value
	set_frequency(tuned_frequency)

func station_name() -> String:
	var index := nearest_station_index()
	return station_names[index] if absf(tuned_frequency-station_frequencies[index]) <= 0.45 else "STATIC"

func change_volume(amount: float) -> void:
	level_db = clampf(level_db+amount,-45,-15)

func interrupt_briefly() -> void:
	interrupted = 2.5
	if is_instance_valid(burst_player):
		burst_player.play()

func _process(delta: float) -> void:
	interrupted = maxf(0,interrupted-delta)
	var muted := globally_muted or not enabled
	var station_gain := linear_to_db(maxf(0.02,signal_strength))
	volume_db = -80 if muted or interrupted > 0 else clampf(level_db+station_gain,-55,-15)
	if is_instance_valid(static_player):
		var noise_strength := 1.0-signal_strength
		static_player.volume_db = -80 if muted else lerpf(-52.0,-18.0,noise_strength)
	if is_instance_valid(burst_player):
		burst_player.volume_db = -80 if globally_muted else clampf(level_db+7,-28,-15)

func _exit_tree() -> void:
	stop()
	stream = null
	tracks.clear()
	if is_instance_valid(static_player):
		static_player.stop()
		static_player.stream = null
	if is_instance_valid(burst_player):
		burst_player.stop()
		burst_player.stream = null
