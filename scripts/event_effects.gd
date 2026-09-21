extends Node
var lights: Array[Light3D] = []
var energies: Array[float] = []
var remaining: float = 0
var duration: float = 0
var minimum_factor: float = 0.55
var one_shot: AudioStreamPlayer

func _ready() -> void:
	one_shot = AudioStreamPlayer.new()
	one_shot.bus = &"SFX"
	one_shot.volume_db = -9
	add_child(one_shot)

func light_dip() -> void:
	begin_light_pulse(2.5,0.55)

func reality_overlap() -> void:
	begin_light_pulse(3.17,0.18)
	one_shot.stream = make_tone(53.0,79.5,1.35,false)
	one_shot.play()

func phone_ring() -> void:
	one_shot.stream = make_tone(640.0,820.0,1.15,true)
	one_shot.play()

func navigation_chime() -> void:
	one_shot.stream = make_tone(520.0,780.0,0.42,false)
	one_shot.play()

func begin_light_pulse(seconds: float, floor_factor: float) -> void:
	if remaining > 0:
		return
	lights.clear()
	energies.clear()
	for node in get_tree().get_nodes_in_group("night_event_light"):
		if node is Light3D:
			lights.append(node)
			energies.append(node.light_energy)
	duration = seconds
	remaining = seconds
	minimum_factor = floor_factor

func _process(delta: float) -> void:
	if remaining <= 0:
		return
	remaining = maxf(0,remaining-delta)
	var phase := 1.0-remaining/maxf(duration,0.001)
	var valley := absf(phase*2.0-1.0)
	var factor := lerpf(minimum_factor,1.0,valley)
	for i in lights.size():
		if is_instance_valid(lights[i]):
			lights[i].light_energy = energies[i]*factor
	if remaining == 0:
		restore()

func restore() -> void:
	for i in lights.size():
		if is_instance_valid(lights[i]):
			lights[i].light_energy = energies[i]
	lights.clear()
	energies.clear()

func make_tone(a: float, b: float, seconds: float, pulsed: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate*seconds)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var t := float(i)/rate
		var edge := minf(1.0,minf(t/0.025,(seconds-t)/0.04))
		var pulse := (1.0 if int(t*7.0)%2 == 0 else 0.12) if pulsed else 1.0
		var sample := (sin(TAU*a*t)*0.55+sin(TAU*b*t)*0.28)*edge*pulse
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*19000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func _exit_tree() -> void:
	restore()
	if is_instance_valid(one_shot):
		one_shot.stop()
		one_shot.stream = null
