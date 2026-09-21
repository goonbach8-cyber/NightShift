extends Node3D
## Deterministic physical story change. It remains where it lands and adds a local impact,
## avoiding unstable rigid-body simulation while still reading as a real event.
@export var target_id: StringName
@export var settled_offset := Vector3(0, -0.8, 0.25)
@export var settled_roll: float = 0.24
var changed_state := false
var impact: AudioStreamPlayer3D

func _ready() -> void:
	add_to_group("story_prop")
	impact = AudioStreamPlayer3D.new()
	impact.bus = &"SFX"
	impact.volume_db = -10
	impact.max_distance = 9
	impact.stream = make_impact()
	add_child(impact)

func apply_state() -> void:
	if changed_state:
		return
	changed_state = true
	var motion := create_tween()
	motion.set_parallel(true)
	motion.tween_property(self,"position",position+settled_offset,0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(self,"rotation:z",settled_roll,0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.finished.connect(func():
		if is_instance_valid(impact):
			impact.play())

func make_impact() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate*0.42)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 317
	var filtered := 0.0
	for i in count:
		var t := float(i)/rate
		filtered = lerpf(filtered,rng.randf_range(-1.0,1.0),0.18)
		var envelope := pow(maxf(0.0,1.0-t/0.42),2.4)
		var low := sin(TAU*78.0*t)*0.52+sin(TAU*116.0*t)*0.24
		var sample := (low+filtered*0.55)*envelope
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*22000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
