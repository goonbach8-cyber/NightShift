extends "res://scenes/interactions/interactable.gd"

signal blocked

@onready var panel: AnimatableBody3D = $Panel
@onready var clearance: Area3D = $Clearance
var is_open: bool = false
var moving: bool = false


func _ready() -> void:
	super._ready()
	# Surface-mounted sliding leaf: clear the wall instead of vanishing into it.
	panel.position.z = 0.30
	var rail := MeshInstance3D.new()
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(4.6,0.08,0.10)
	rail.mesh = rail_mesh
	rail.position = Vector3(1.15,1.58,0.30)
	var rail_material := StandardMaterial3D.new()
	rail_material.albedo_color = Color("74817c")
	rail_material.metallic = 0.5
	rail.material_override = rail_material
	add_child(rail)
	clearance.set_collision_mask_value(3, true)
	_update_prompt()


func is_available() -> bool:
	return not moving

func interaction_bias() -> float:
	# An already open passage should not steal E from nearby work surfaces.
	return 0.25 if is_open else 0.0


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
		if body.is_in_group("player") or body.is_in_group("customer"):
			return true
	return false


func _update_prompt() -> void:
	prompt = "Close sliding door" if is_open else "Open sliding door"
