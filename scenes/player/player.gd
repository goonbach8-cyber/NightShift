extends CharacterBody3D

@export_group("Movement")
@export_range(0.1, 20.0, 0.1) var move_speed: float = 4.0
@export_range(0.1, 50.0, 0.1) var acceleration: float = 18.0
@export_range(0.1, 50.0, 0.1) var deceleration: float = 24.0
@export_range(0.1, 50.0, 0.1) var gravity: float = 20.0

@export_group("Animation")
@export_range(1.0, 20.0, 0.5) var walk_animation_fps: float = 10.0

@onready var sprite: Sprite3D = $Sprite3D

# Sprite-sheet rows:
# 0 = front/down, 1 = right, 2 = left, 3 = back/up
const FRAMES_PER_DIRECTION: int = 8

var facing_row: int = 0
var animation_frame: int = 0
var animation_timer: float = 0.0


func _ready() -> void:
	_apply_sprite_frame()


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

	_update_sprite_animation(move_direction, delta)
	move_and_slide()


func _update_sprite_animation(move_direction: Vector3, delta: float) -> void:
	if move_direction.length_squared() < 0.0025:
		animation_frame = 0
		animation_timer = 0.0
		_apply_sprite_frame()
		return

	if absf(move_direction.x) > absf(move_direction.z):
		facing_row = 1 if move_direction.x > 0.0 else 2
	else:
		facing_row = 0 if move_direction.z > 0.0 else 3

	animation_timer += delta
	var frame_duration := 1.0 / walk_animation_fps

	while animation_timer >= frame_duration:
		animation_timer -= frame_duration
		animation_frame = (animation_frame + 1) % FRAMES_PER_DIRECTION

	_apply_sprite_frame()


func _apply_sprite_frame() -> void:
	sprite.frame = facing_row * FRAMES_PER_DIRECTION + animation_frame
