extends "res://scenes/interactions/interactable.gd"

signal blocked

@onready var panel: AnimatableBody3D = $Panel
@onready var clearance: Area3D = $Clearance
var is_open: bool = false
var moving: bool = false


func _ready() -> void:
	super._ready()
	_update_prompt()


func is_available() -> bool:
	return not moving


func interact(_player: Node3D) -> void:
	if moving:
		return
	if is_open and _occupied():
		blocked.emit()
		return
	moving = true
	# Collision is restored only after a completed, unobstructed close.
	panel.collision_layer = 0
	var opening := not is_open
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(panel, "position:x", 2.3 if opening else 0.0, 0.5)
	await tween.finished
	if not opening and _occupied():
		var reopen := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		reopen.tween_property(panel, "position:x", 2.3, 0.5)
		await reopen.finished
		is_open = true
		blocked.emit()
	else:
		is_open = opening
		if not is_open:
			panel.collision_layer = 1
	moving = false
	_update_prompt()


func _occupied() -> bool:
	for body in clearance.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _update_prompt() -> void:
	prompt = "Schiebetür schliessen" if is_open else "Schiebetür öffnen"
