extends CharacterBody3D

@export_group("Movement")
@export_range(0.1, 20.0, 0.1) var move_speed: float = 4.0
@export_range(0.1, 50.0, 0.1) var acceleration: float = 18.0
@export_range(0.1, 50.0, 0.1) var deceleration: float = 24.0
@export_range(0.1, 50.0, 0.1) var gravity: float = 20.0

@onready var sprite: Sprite3D = $Sprite3D


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var move_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var target_velocity := move_direction * move_speed
	var horizontal_change := acceleration if move_direction != Vector3.ZERO else deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, horizontal_change * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, horizontal_change * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	_update_sprite_direction(move_direction)
	move_and_slide()


func _update_sprite_direction(move_direction: Vector3) -> void:
	if absf(move_direction.x) > 0.05:
		sprite.flip_h = move_direction.x < 0.0
