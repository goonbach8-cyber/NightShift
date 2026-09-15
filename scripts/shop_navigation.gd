extends Node
## A small flat-world navigation grid sampled from actual floor and obstacle colliders.
## No shop dimensions or route coordinates live here. Rebuild after layout changes.
var grid := AStarGrid2D.new()
var cell: float = 0.2
var space: PhysicsDirectSpaceState3D
var door_exclusions: Array[RID] = []
var probe := CapsuleShape3D.new()
var ready_for_paths: bool = false

func rebuild(world: Node3D, doors: Array[Node3D]) -> void:
	ready_for_paths = false
	space = world.get_world_3d().direct_space_state
	door_exclusions.clear()
	for door in doors:
		door_exclusions.append(door.get_node("Panel").get_rid())
	var floors: Array[AABB] = []
	find_floors(world,floors)
	if floors.is_empty():
		return
	var bounds := floors[0]
	for floor_box in floors:
		bounds = bounds.merge(floor_box)
	var start := Vector2i(floori(bounds.position.x/cell),floori(bounds.position.z/cell))
	var end := Vector2i(ceili(bounds.end.x/cell),ceili(bounds.end.z/cell))
	grid.region = Rect2i(start,end-start+Vector2i.ONE)
	grid.cell_size = Vector2.ONE*cell
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	# Include clearance for the player's 0.32 m capsule as well as customers.
	probe.radius = 0.36
	probe.height = 1.2
	for x in range(start.x,end.x+1):
		for y in range(start.y,end.y+1):
			var point := Vector3(x*cell,0,y*cell)
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.18,point-Vector3.UP*0.35,1)
			ray.exclude = door_exclusions
			var floor_hit := space.intersect_ray(ray)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = probe
			# Probe down to shoe height; low plinths can block a CharacterBody too.
			query.transform.origin = point + Vector3.UP*0.61
			query.collision_mask = 1
			query.exclude = door_exclusions
			grid.set_point_solid(Vector2i(x,y),floor_hit.is_empty() or not space.intersect_shape(query,1).is_empty())
	ready_for_paths = true

func find_floors(node: Node, result: Array[AABB]) -> void:
	if node is CollisionShape3D and not node.disabled and node.shape is BoxShape3D:
		var size: Vector3 = node.shape.size
		if size.y <= 0.4 and size.x >= 2 and size.z >= 2:
			result.append(node.global_transform * AABB(-size/2,size))
	for child in node.get_children():
		find_floors(child,result)

func nearest(point: Vector3) -> Vector2i:
	var center := Vector2i(roundi(point.x/cell),roundi(point.z/cell))
	var best := center
	var distance := INF
	for x in range(-3,4):
		for y in range(-3,4):
			var candidate := center+Vector2i(x,y)
			if grid.region.has_point(candidate) and not grid.is_point_solid(candidate):
				var d := Vector2(candidate.x*cell-point.x,candidate.y*cell-point.z).length_squared()
				if d < distance:
					distance = d
					best = candidate
	return best

func path(from: Vector3, to: Vector3, avoid: Array[Vector3] = []) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not ready_for_paths:
		return result
	var start := nearest(from)
	var end := nearest(to)
	var temporary: Array[Vector2i] = []
	for obstacle in avoid:
		var center := Vector2i(roundi(obstacle.x/cell),roundi(obstacle.z/cell))
		var extent := ceili(0.72/cell)
		for x in range(-extent,extent+1):
			for y in range(-extent,extent+1):
				var id := center+Vector2i(x,y)
				var cell_position := Vector2(id.x*cell,id.y*cell)
				var near_obstacle := cell_position.distance_to(Vector2(obstacle.x,obstacle.z)) < 0.72
				# Bodies can already be inside the planning margin while a queue advances.
				# Permit movement out of that margin, never closer to the other body.
				var origin := Vector2(from.x,from.z)
				var obstacle_position := Vector2(obstacle.x,obstacle.z)
				var initial_distance := origin.distance_to(obstacle_position)
				var escaping := initial_distance < 0.72 and cell_position.distance_to(origin) < 0.9 and cell_position.distance_to(obstacle_position) >= initial_distance
				if near_obstacle and not escaping and id != start and id != end and grid.region.has_point(id) and not grid.is_point_solid(id):
					grid.set_point_solid(id,true)
					temporary.append(id)
	if grid.region.has_point(start) and grid.region.has_point(end) and not grid.is_point_solid(start) and not grid.is_point_solid(end):
		for point in grid.get_point_path(start,end):
			result.append(Vector3(point.x,0,point.y))
	for id in temporary:
		grid.set_point_solid(id,false)
	# The actor is already in the start cell. Returning to its centre can make a
	# queue leader back into the following customer instead of advancing.
	if result.size() > 1 and result[0].distance_to(Vector3(from.x,0,from.z)) <= cell*0.8:
		result.remove_at(0)
	# Preserve authored approach positions instead of stopping at the grid's rounded cell.
	if not result.is_empty() and result[-1].distance_to(Vector3(to.x,0,to.z)) <= cell*0.8:
		result.append(Vector3(to.x,0,to.z))
	return result
