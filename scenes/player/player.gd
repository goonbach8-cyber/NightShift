extends CharacterBody3D

@export_group("Movement")
@export_range(0.1, 20.0, 0.1) var move_speed: float = 4.0
@export_range(0.1, 50.0, 0.1) var acceleration: float = 18.0
@export_range(0.1, 50.0, 0.1) var deceleration: float = 24.0
@export_range(0.1, 50.0, 0.1) var gravity: float = 20.0
@export var interaction_distance: float = 1.8

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

var facing: StringName = &"down"
var interaction_target: Node3D


func _ready() -> void:
	add_to_group("player")
	sprite.play(&"idle_down")


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var horizontal := Vector2(velocity.x, velocity.z)
	var rate := acceleration if input_vector != Vector2.ZERO else deceleration
	horizontal = horizontal.move_toward(input_vector * move_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	var previous_position := global_position
	move_and_slide()
	var displacement := global_position - previous_position
	var actual_direction := Vector3(displacement.x, 0.0, displacement.z) / delta
	# Face the intended object when blocked, but keep facing the motion while braking.
	_update_facing(move_direction if input_vector != Vector2.ZERO else actual_direction)
	_update_animation(actual_direction)
	_update_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		_update_interaction()
		if is_instance_valid(interaction_target):
			interaction_target.interact(self)
		get_viewport().set_input_as_handled()


func _update_facing(direction: Vector3) -> void:
	if direction.length_squared() < 0.0025:
		return
	if absf(direction.x) > absf(direction.z):
		facing = &"right" if direction.x > 0.0 else &"left"
	else:
		facing = &"down" if direction.z > 0.0 else &"up"


func _update_animation(actual_velocity: Vector3) -> void:
	var speed := actual_velocity.length()
	var walking := speed > 0.08
	var animation_name := StringName(("walk_" if walking else "idle_") + String(facing))
	if sprite.animation != animation_name:
		var was_walking := String(sprite.animation).begins_with("walk_")
		var old_frame := sprite.frame
		var old_progress := sprite.frame_progress
		sprite.play(animation_name)
		# All four rows share a cycle: quick turns must not reset the stride.
		if walking and was_walking:
			sprite.set_frame_and_progress(old_frame, old_progress)
	sprite.speed_scale = clampf(speed / move_speed, 0.15, 1.0) if walking else 1.0


func _update_interaction() -> void:
	interaction_target = null
	var nearest := interaction_distance
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate is Node3D or not candidate.is_available():
			continue
		var point: Vector3 = candidate.global_position + Vector3.UP * 0.8
		var origin := global_position + Vector3.UP * 0.8
		var distance := origin.distance_to(point)
		if distance >= nearest:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, point, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and not candidate.is_ancestor_of(hit.collider) and hit.collider != candidate:
			continue
		nearest = distance
		interaction_target = candidate
