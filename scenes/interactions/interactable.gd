extends Node3D

signal used(action_id: StringName)

@export var action_id: StringName
@export var prompt: String = "Untersuchen"
@export var available: bool = true


func _ready() -> void:
	add_to_group("interactable")


func is_available() -> bool:
	return available

func interaction_bias() -> float:
	return 0.0


func interact(_player: Node3D) -> void:
	used.emit(action_id)
