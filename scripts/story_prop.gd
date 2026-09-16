extends Node3D
## Deterministic small prop movement, without unstable rigid-body simulation.
@export var target_id: StringName
@export var settled_offset := Vector3(0, -0.8, 0.25)
@export var settled_roll: float = 0.24
var changed_state := false
func _ready() -> void:
	add_to_group("story_prop")
func apply_state() -> void:
	if changed_state: return
	changed_state = true
	var motion := create_tween()
	motion.set_parallel(true)
	motion.tween_property(self,"position",position+settled_offset,0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_property(self,"rotation:z",settled_roll,0.65)
