extends CharacterBody3D
signal arrived(customer: CharacterBody3D)
var route := PackedVector3Array()
var target: Marker3D
var navigation: Node
var doors: Array[Node3D] = []
var state: StringName = &"shopping"
var has_product: bool = false
var paid: bool = false
var stuck_time: float = 0
var retry_time: float = 0
var walking: bool = false
var destination_version := Vector3.INF
var order: Dictionary = {}
var remaining_products: Array = []
var current_product: StringName
var wait_seconds: float = 0
var patience: float = 240
var move_speed: float = 1.8
var status_text: String = "Kunde"
var abandoned: bool = false

func _ready() -> void:
	add_to_group("customer")
	collision_layer = 4
	collision_mask = 1|2|4
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.2
	collision.shape = capsule
	collision.position.y = 0.65
	add_child(collision)
	# A deliberately simple customer placeholder, visibly distinct from the pixel player.
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.23
	mesh.height = 1.1
	mesh.radial_segments = 8
	mesh.rings = 4
	visual.mesh = mesh
	visual.position.y = 0.6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b0a079")
	visual.material_override = material
	add_child(visual)
	var label := Label3D.new()
	label.name = "Status"
	label.position.y = 1.35
	label.font_size = 32
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func go_to(marker: Marker3D) -> void:
	target = marker
	walking = true
	plan()

func plan(avoid_people: bool = false) -> void:
	if not is_instance_valid(target):
		return
	var obstacles: Array[Vector3] = []
	if avoid_people:
		for person in get_tree().get_nodes_in_group("customer") + get_tree().get_nodes_in_group("player"):
			if person != self:
				obstacles.append(person.global_position)
	route = navigation.path(global_position,target.global_position,obstacles)
	destination_version = target.global_position
	retry_time = 0

func _physics_process(delta: float) -> void:
	$Status.text = status_text
	velocity.y = -2.0
	velocity.x = 0
	velocity.z = 0
	if walking and is_instance_valid(target):
		if not destination_version.is_equal_approx(target.global_position):
			plan()
		for door in doors:
			if global_position.distance_to(door.global_position) < 1.65 and not door.is_open and not door.moving:
				door.interact(self)
		while not route.is_empty() and Vector2(route[0].x-global_position.x,route[0].z-global_position.z).length() < 0.14:
			route.remove_at(0)
		if not route.is_empty():
			var direction := (route[0]-global_position)
			direction.y = 0
			direction = direction.normalized()
			velocity.x = direction.x*move_speed
			velocity.z = direction.z*move_speed
		elif Vector2(global_position.x-target.global_position.x,global_position.z-target.global_position.z).length() < 0.52:
			walking = false
			arrived.emit(self)
		else:
			retry_time += delta
			if retry_time > 1:
				plan(true)
	var before := global_position
	move_and_slide()
	if walking and Vector2(global_position.x-before.x,global_position.z-before.z).length() < 0.002:
		stuck_time += delta
		if stuck_time > 1.5:
			plan(true)
			stuck_time = 0
	else:
		stuck_time = 0
