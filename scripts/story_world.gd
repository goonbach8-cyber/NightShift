extends Node3D
## Small physical story locations, all relative to the existing station anchors.
var world: Node3D
var loop: Node
var layout: Node
var model = preload("res://scripts/product_display.gd").new()
var road: Node3D
var crack: Node3D
var construction: Node3D
var branding: Label3D
var alternate: Node3D
var intrusions: Node3D
var depot: Node3D
var josh: Node3D
var configured_night := 0
var pending_read: StringName
var pending_handover := false
var pending_depot := false
var in_depot := false
var trip_busy := false
var ending_started := false
var travel_return := Vector3.ZERO
var resume_shift := false
var overlay: ColorRect

func setup(owner_world: Node3D) -> void:
	world = owner_world
	loop = world.gameplay
	layout = world.layout
	add_child(model)
	road = Node3D.new()
	road.name = "AccessRoad"
	add_child(road)
	var forecourt: Vector3 = to_local(layout.entrance.global_position)+Vector3(4,0,3)
	road.position = forecourt
	model.box(road,Vector3(3,-0.06,0),Vector3(7,0.1,2.6),Color("333e40"))
	for x in 6: model.box(road,Vector3(x,0.002,0),Vector3(0.5,0.012,0.06),Color("dedac1"))
	label(road,"DEPOT →",Vector3(0,1.1,-1),24)
	point(self,"route",forecourt-Vector3(0.6,0,0),"Navigation / Depot route")
	crack = Node3D.new()
	crack.name = "AsphaltCrack"
	crack.position = to_local(layout.entrance.global_position)+Vector3(1.8,0,1.2)
	add_child(crack)
	for i in 5:
		model.box(crack,Vector3(i*0.17,0.013,sin(i)*0.13),Vector3(0.24,0.018,0.055),Color("111b1c"))
	construction = Node3D.new()
	construction.name = "ConstructionNotice"
	construction.position = forecourt+Vector3(-0.8,0,0.9)
	add_child(construction)
	model.box(construction,Vector3(0,0.65,0),Vector3(0.1,1.3,0.1),Color("747c7a"))
	model.box(construction,Vector3(0,1.35,0),Vector3(1.3,0.75,0.07),Color("dbc995"))
	label(construction,"REDWATER\nNEW ACCESS ROAD",Vector3(0,1.45,0.06),25)
	# A small alternate plan with an offset road and extra building footprint.
	for x in 3: model.box(construction,Vector3(-0.35+x*0.3,1.14,0.06),Vector3(0.18,0.13,0.02),Color("667879"))
	model.box(construction,Vector3(0,1.0,0.06),Vector3(0.95,0.04,0.02),Color("526760"))
	point(construction,"construction",Vector3(0,0,-0.5),"Read construction notice")
	branding = label(self,"REDWOOD SERVICE",to_local(layout.entrance.global_position)+Vector3(2,1.1,-0.15),30)
	alternate = Node3D.new()
	alternate.name = "RedwaterDetails"
	add_child(alternate)
	intrusions = Node3D.new()
	intrusions.name = "RedwaterIntrusions"
	add_child(intrusions)
	var sign_at := to_local(layout.radio_point.global_position)
	label(intrusions,"REDWATER\n14 SERVICE ROAD",sign_at+Vector3(-0.8,1.6,0),28)
	model.box(intrusions,sign_at+Vector3(-0.8,1.3,0),Vector3(0.8,0.12,0.25),Color("547c85"))
	# The alternative keeps the station's footprint but changes the surroundings.
	model.box(alternate,forecourt+Vector3(-2,-0.03,3),Vector3(8,0.04,1.8),Color("455658"))
	for i in 3:
		model.box(alternate,forecourt+Vector3(-5+i*3,1.1,5),Vector3(1.8,2.2,1.5),Color("60777c"))
	label(intrusions,"RIVERLINE DRINKS",to_local(layout.product_nodes[&"energy"].global_position)+Vector3(0,1.8,0.3),28)
	label(intrusions,"REDWATER DISTRIBUTION",to_local(layout.warehouse.global_position)+Vector3(9,1.7,-4),28)
	var sites = [layout.checkout,layout.product_nodes[&"chips"],layout.warehouse.get_node("Supply"),layout.radio_point]
	var ids: Array[StringName] = [&"accident",&"map",&"missing",&"redwater"]
	var offsets := [Vector3(-1.4,0,0.4),Vector3(-0.9,0,-1.2),Vector3(1.2,0,0.2),Vector3(-1.4,0,0.4)]
	for i in ids.size():
		var reader := point(self,ids[i],to_local(sites[i].global_position)+offsets[i],"Read "+preload("res://scripts/clue_catalog.gd").ENTRIES[ids[i]].title)
		model.box(reader,Vector3(0,0.9,0),Vector3(0.32,0.015,0.25),Color("d0c9ad"))
	depot = Node3D.new()
	depot.name = "Depot"
	depot.position = Vector3(24,0,0)
	add_child(depot)
	floor_box(depot,Vector3(0,-0.1,0),Vector3(6,0.2,6))
	floor_box(depot,Vector3(0,1,-2.9),Vector3(6,2,0.2))
	# Compact enclosed collection yard: the player cannot walk off its floor.
	for x in [-2.9,2.9]: floor_box(depot,Vector3(x,0.5,0),Vector3(0.2,1,6))
	floor_box(depot,Vector3(0,0.5,2.9),Vector3(6,1,0.2))
	floor_box(depot,Vector3(1,0.5,-1.8),Vector3(2,1,0.7))
	label(depot,"DEPOT / COLLECTIONS",Vector3(0,1.8,-2.6),32)
	person(depot,Vector3(1,0,-2.3))
	point(depot,"depot_clerk",Vector3(1,0,-1),"Talk to depot clerk")
	point(depot,"depot_ledger",Vector3(-1,0,-1.8),"Read depot ledger")
	model.box(depot,Vector3(-1,0.85,-1.8),Vector3(0.5,0.05,0.35),Color("cfbea0"))
	point(depot,"return",Vector3(0,0,1.8),"Return to station")
	var light := OmniLight3D.new()
	light.position = Vector3(0,3,0)
	light.omni_range = 7
	light.light_energy = 1.4
	depot.add_child(light)
	loop.dialogue.changed.connect(dialogue_changed)
	apply_night()

func label(parent: Node3D, text: String, at: Vector3, size: int) -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.position = at
	sign.font_size = size
	sign.pixel_size = 0.004
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(sign)
	return sign

func floor_box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	model.box(parent,at,size,Color("66716b"))
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.position = at
	body.add_child(collider)
	parent.add_child(body)

func point(parent: Node3D, id: StringName, at: Vector3, prompt: String) -> Node3D:
	var node := Node3D.new()
	node.name = String(id)
	node.set_script(preload("res://scenes/interactions/interactable.gd"))
	node.action_id = id
	node.prompt = prompt
	node.position = at
	parent.add_child(node)
	node.used.connect(interact)
	return node

func person(parent: Node3D, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	model.box(node,Vector3(0,0.65,0),Vector3(0.38,0.7,0.25),Color("748a91"))
	model.box(node,Vector3(0,1.15,0),Vector3(0.26,0.28,0.25),Color("cbb496"))
	return node

func apply_night() -> void:
	configured_night = loop.career_shifts+1
	if is_instance_valid(josh): josh.queue_free()
	if not loop.definition.handover.is_empty() and not loop.story_flags.get(handover_flag(),false):
		# Meet Mike near his arrival position, clear of stock and checkout prompts.
		josh = person(self,to_local(world.player.global_position)+Vector3(1.4,0,-0.3))
		point(josh,&"josh",Vector3.ZERO,"Talk to Josh")
		label(josh,"Josh",Vector3(0,1.45,0),24)

func handover_flag() -> StringName:
	return StringName("josh_handover_%d" % configured_night)

func dialogue_changed() -> void:
	if loop.dialogue.active: return
	if pending_read != &"":
		if loop.dialogue.completed:
			loop.story_flags[StringName("clue_"+String(pending_read))] = true
		pending_read = &""
	if pending_depot:
		if loop.dialogue.completed: loop.tasks[&"depot"] = true
		pending_depot = false
	if pending_handover:
		pending_handover = false
		if not loop.dialogue.completed: return
		loop.story_flags[handover_flag()] = true
		if is_instance_valid(josh):
			josh.get_node("josh").available = false
			loop.navigation.rebuild(world,layout.doors)
			var path: PackedVector3Array = loop.navigation.path(josh.global_position,layout.spawn_point.global_position)
			var motion := create_tween()
			for position in path: motion.tween_property(josh,"global_position",position,0.15)
			motion.tween_callback(josh.queue_free)

func interact(id: StringName) -> void:
	if loop.dialogue.active or trip_busy: return
	var choices: Array[Dictionary] = []
	if preload("res://scripts/clue_catalog.gd").ENTRIES.has(id):
		if configured_night < preload("res://scripts/clue_catalog.gd").FIRST_NIGHT[id]: return
		var entry: Dictionary = preload("res://scripts/clue_catalog.gd").ENTRIES[id]
		pending_read = id
		loop.dialogue.begin(-20,PackedStringArray(entry.lines),choices,loop.story_flags)
	elif id == &"josh":
		if loop.story_flags.get(handover_flag(),false): return
		pending_handover = true
		loop.dialogue.begin(-10,loop.definition.handover,choices,loop.story_flags)
	elif id == &"construction" and construction.visible:
		loop.dialogue.begin(-30,PackedStringArray(["Construction of new access road — works begin today.","The map says Redwater. Its road bends behind a building that isn't on Mike's map."]),choices,loop.story_flags)
		loop.story_flags[&"construction_read"] = true
	elif id == &"route":
		if configured_night == 4: travel(true)
		elif road.visible: world._say("The access is closed.")
	elif id == &"depot_clerk" and in_depot:
		pending_depot = true
		loop.dialogue.begin(-40,PackedStringArray(["Depot clerk: The station collection? It's ready, same as every week.","Take the usual road back. Your delivery account has been here for years."]),choices,loop.story_flags)
	elif id == &"return" and in_depot:
		if loop.tasks.has(&"depot"): travel(false)
		else: world._say("Collect the delivery from the clerk first.")

func travel(outbound: bool) -> void:
	trip_busy = true
	world._say("Navigation: Continue for 2.4 km." if outbound else "Navigation: Return to the service station.",6)
	if outbound:
		travel_return = world.player.global_position
		resume_shift = loop.active
		loop.active = false
	world.player.velocity = Vector3.ZERO
	world.player.set_physics_process(false)
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade)
	await get_tree().create_timer(0.6).timeout
	world.player.global_position = depot.global_position+Vector3(0,0.05,1) if outbound else travel_return+Vector3.UP*0.05
	in_depot = outbound
	await get_tree().create_timer(0.4).timeout
	canvas.queue_free()
	world.player.set_physics_process(true)
	if not outbound: loop.active = resume_shift
	trip_busy = false

func _process(_delta: float) -> void:
	if not is_instance_valid(loop): return
	if configured_night != loop.career_shifts+1: apply_night()
	if configured_night == 3 and loop.served+loop.lost_sales >= 5 and loop.story_flags.get(&"presented_night_3_store_parcel",false):
		loop.story_flags[&"road_exists"] = true
		loop.story_flags[&"crack_exists"] = true
	road.visible = loop.story_flags.get(&"road_exists",false) or loop.definition.world_states.has(&"road")
	crack.visible = loop.story_flags.get(&"crack_exists",false) or loop.definition.world_states.has(&"crack")
	construction.visible = loop.definition.world_states.has(&"construction")
	var redwater: bool = loop.definition.reality == &"redwater" and not ending_started
	alternate.visible = redwater
	intrusions.visible = configured_night >= 5 and not ending_started
	branding.text = "REDWATER SERVICE" if redwater or ending_started else "REDWOOD SERVICE"
	if configured_night == 6 and loop.event_history.has(&"night_6_main") and not ending_started:
		branding.text = "REDWOOD / REDWATER\n03:17"
	get_node("route").available = road.visible and not in_depot
	for child in depot.get_children():
		if child.has_method("is_available"): child.available = in_depot
	for child in construction.get_children():
		if child.has_method("is_available"): child.available = construction.visible
	for id in preload("res://scripts/clue_catalog.gd").FIRST_NIGHT:
		var reader := get_node_or_null(NodePath(String(id)))
		if reader != null:
			reader.visible = configured_night >= preload("res://scripts/clue_catalog.gd").FIRST_NIGHT[id]
			reader.available = reader.visible

func enter_ending() -> void:
	ending_started = true
	alternate.hide()
	intrusions.hide()
	construction.hide()
	branding.text = "REDWATER SERVICE"
