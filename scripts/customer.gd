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
var replan_elapsed: float = 0
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
var profile_id: StringName = &"regular"
var greeting: String = ""
var clothing_color := Color("b0a079")
var browse_seconds: float = 0.75
var browse_remaining: float = 0.0
var entrance: Node3D
var arrival_origin: Marker3D
var entry_wait_point: Marker3D
var yielding_at_entry := false
var visual_root: Node3D

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
	# Low-poly but human-readable customer silhouette. It stays deliberately simple,
	# yet no longer looks like a physics capsule/debug placeholder.
	visual_root = Node3D.new()
	visual_root.name = "CustomerVisual"
	add_child(visual_root)
	visual_box(visual_root,Vector3(0,0.72,0),Vector3(0.42,0.62,0.26),clothing_color)
	visual_box(visual_root,Vector3(-0.12,0.28,0),Vector3(0.15,0.45,0.17),clothing_color.darkened(0.18))
	visual_box(visual_root,Vector3(0.12,0.28,0),Vector3(0.15,0.45,0.17),clothing_color.darkened(0.18))
	visual_box(visual_root,Vector3(-0.28,0.72,0),Vector3(0.11,0.55,0.13),clothing_color.darkened(0.08))
	visual_box(visual_root,Vector3(0.28,0.72,0),Vector3(0.11,0.55,0.13),clothing_color.darkened(0.08))
	visual_sphere(visual_root,Vector3(0,1.22,0),0.18,Color("c9aa8c"))
	# Small front badge gives the simple silhouette a readable facing direction.
	visual_box(visual_root,Vector3(0,0.78,0.145),Vector3(0.17,0.12,0.018),Color("d5d0b1"))
	var label := Label3D.new()
	label.name = "Status"
	label.position.y = 1.35
	label.font_size = 32
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visible = "--dev-debug" in OS.get_cmdline_user_args()
	add_child(label)

func visual_box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	visual.material_override = material
	parent.add_child(visual)
	return visual

func visual_sphere(parent: Node3D, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	visual.mesh = mesh
	visual.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	visual.material_override = material
	parent.add_child(visual)
	return visual

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
	route = navigation.path(global_position,destination(),obstacles)
	destination_version = destination()
	retry_time = 0

func destination() -> Vector3:
	return entry_wait_point.global_position if yielding_at_entry else target.global_position

func should_yield_at_entry() -> bool:
	if state != &"shopping" or not is_instance_valid(entrance) or not is_instance_valid(entry_wait_point): return false
	var outward := (arrival_origin.global_position-entrance.global_position).normalized()
	if (global_position-entrance.global_position).dot(outward) < -0.8: return false
	for person in get_tree().get_nodes_in_group("customer"):
		if person != self and person.state == &"leaving": return true
	return false

func _physics_process(delta: float) -> void:
	if $Status.visible:
		$Status.text = "%s\n%s | path %d | wait %.0f" % [state,target.name if is_instance_valid(target) else "none",route.size(),wait_seconds]
	velocity.y = -2.0
	velocity.x = 0
	velocity.z = 0
	if walking and is_instance_valid(target):
		var give_way := should_yield_at_entry()
		if give_way != yielding_at_entry:
			yielding_at_entry = give_way
			plan(true)
		replan_elapsed += delta
		if replan_elapsed >= 1.2:
			plan(true)
			replan_elapsed = 0
		if not destination_version.is_equal_approx(destination()):
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
		elif Vector2(global_position.x-destination().x,global_position.z-destination().z).length() < 0.52:
			if not yielding_at_entry:
				walking = false
				arrived.emit(self)
		else:
			retry_time += delta
			if retry_time > 1:
				plan(true)
	var horizontal := Vector2(velocity.x,velocity.z)
	if is_instance_valid(visual_root) and horizontal.length() > 0.05:
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y,atan2(horizontal.x,horizontal.y),clampf(delta*8.0,0.0,1.0))
	var before := global_position
	move_and_slide()
	if walking and Vector2(global_position.x-before.x,global_position.z-before.z).length() < 0.002:
		stuck_time += delta
		if stuck_time > 1.5:
			plan(true)
			stuck_time = 0
	else:
		stuck_time = 0
