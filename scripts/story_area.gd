extends Area3D
## Authored room-relative trigger; only the player can occupy it.
@export var area_id: StringName
var director: Node
func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(func(body):
		if body.is_in_group("player") and is_instance_valid(director): director.set_area(area_id,true))
	body_exited.connect(func(body):
		if body.is_in_group("player") and is_instance_valid(director): director.set_area(area_id,false))
