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
var overlap_echo: Node3D
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
var checkout_display: Node3D
var overlap_remaining := 0.0

func setup(owner_world: Node3D) -> void:
	world = owner_world
	loop = world.gameplay
	layout = world.layout
	add_child(model)
	road = preload("res://scripts/access_road.gd").new()
	road.name = "AccessRoad"
	# Start inside the established carriageway (its centre is ~z 14.2), not beside it.
	# The branch then curves away, so it reads as a newly appeared junction.
	var forecourt: Vector3 = to_local(layout.entrance.global_position)+Vector3(4.0,0,9.2)
	road.position = forecourt
	add_child(road)
	point(self,"route",forecourt+Vector3(4.8,0,6.1),"Navigation / Depot collection")
	crack = Node3D.new()
	crack.name = "AsphaltCrack"
	crack.position = to_local(layout.entrance.global_position)+Vector3(1.8,0,1.2)
	add_child(crack)
	var crack_points := PackedVector3Array([
		Vector3(-0.55,0.013,-0.10),
		Vector3(-0.31,0.013,0.04),
		Vector3(-0.08,0.013,-0.07),
		Vector3(0.17,0.013,0.08),
		Vector3(0.42,0.013,-0.03),
		Vector3(0.68,0.013,0.12)
	])
	for i in range(crack_points.size()-1):
		var a := crack_points[i]
		var b := crack_points[i+1]
		var segment := model.box(crack,(a+b)/2,Vector3(0.045,0.018,a.distance_to(b)),Color("101617"))
		segment.rotation.y = atan2((b-a).x,(b-a).z)

	# A freestanding checkout display becomes the first undeniable Night-3 incident.
	# It has no collision, so its fallen state cannot soft-lock the queue.
	checkout_display = preload("res://scripts/story_prop.gd").new()
	checkout_display.name = "CheckoutDisplay"
	checkout_display.target_id = &"checkout_display"
	checkout_display.settled_offset = Vector3(0.36,-0.06,0.12)
	checkout_display.settled_roll = -1.18
	checkout_display.position = to_local(layout.checkout.global_position)+Vector3(1.08,0.02,-0.62)
	add_child(checkout_display)
	model.box(checkout_display,Vector3(0,0.46,0),Vector3(0.56,0.06,0.42),Color("777f78"))
	model.box(checkout_display,Vector3(-0.23,0.24,0),Vector3(0.06,0.48,0.36),Color("5f6965"))
	model.box(checkout_display,Vector3(0.23,0.24,0),Vector3(0.06,0.48,0.36),Color("5f6965"))
	for x in [-0.16,0.0,0.16]:
		model.box(checkout_display,Vector3(x,0.58,0),Vector3(0.12,0.18,0.18),Color("a16e42"))

	construction = Node3D.new()
	construction.name = "ConstructionNotice"
	construction.position = forecourt+Vector3(0,0,1.9)
	add_child(construction)
	# Sign sits on the shoulder; barriers and disturbed ground occupy the branch itself.
	model.box(construction,Vector3(-2.75,0.65,-0.15),Vector3(0.1,1.3,0.1),Color("747c7a"))
	model.box(construction,Vector3(-2.75,1.35,-0.15),Vector3(1.3,0.75,0.07),Color("dbc995"))
	label(construction,"REDWATER\nNEW ACCESS ROAD",Vector3(-2.75,1.45,-0.09),25)
	for x in 3:
		model.box(construction,Vector3(-3.10+x*0.3,1.14,-0.09),Vector3(0.18,0.13,0.02),Color("667879"))
	model.box(construction,Vector3(-2.75,1.0,-0.09),Vector3(0.95,0.04,0.02),Color("526760"))
	model.box(construction,Vector3(0,-0.005,0.7),Vector3(4.6,0.018,1.35),Color("4f4a40"))
	for x in [-1.8,-0.6,0.6,1.8]:
		model.box(construction,Vector3(x,0.34,1.15),Vector3(0.10,0.68,0.10),Color("d27a35"))
		model.box(construction,Vector3(x,0.68,1.15),Vector3(0.34,0.08,0.08),Color("e4d7b3"))
	for x in [-1.2,1.2]:
		model.box(construction,Vector3(x,0.56,0.55),Vector3(1.55,0.12,0.10),Color("d7c9aa"))
		model.box(construction,Vector3(x,0.56,0.61),Vector3(0.34,0.12,0.11),Color("c66c32"))
	point(construction,"construction",Vector3(-2.75,0,-0.75),"Read construction notice")
	branding = label(self,"REDWOOD SERVICE",to_local(layout.entrance.global_position)+Vector3(2,1.1,-0.15),30)
	alternate = Node3D.new()
	alternate.name = "RedwaterDetails"
	add_child(alternate)
	intrusions = Node3D.new()
	intrusions.name = "RedwaterIntrusions"
	add_child(intrusions)
	overlap_echo = Node3D.new()
	overlap_echo.name = "RealityOverlapEcho"
	add_child(overlap_echo)
	overlap_echo.hide()
	var sign_at := to_local(layout.radio_point.global_position)
	label(intrusions,"REDWATER\n14 SERVICE ROAD",sign_at+Vector3(-0.8,1.6,0),28)
	model.box(intrusions,sign_at+Vector3(-0.8,1.3,0),Vector3(0.8,0.12,0.25),Color("547c85"))
	# Redwater is a normal alternate town, not an "evil" filter: recognizable footprint,
	# but different civic furniture, road geometry and nearby structures.
	model.box(alternate,forecourt+Vector3(-2,-0.03,3.6),Vector3(8,0.04,1.8),Color("455658"))
	for i in 3:
		var building := forecourt+Vector3(-5+i*3.1,1.1,5.4)
		model.box(alternate,building,Vector3(1.8,2.2,1.5),Color("60777c" if i != 1 else "56696c"))
		model.box(alternate,building+Vector3(0,0.15,-0.76),Vector3(0.65,0.42,0.04),Color("b6c8b6"))
	# A bus shelter exists in Redwater where Redwood has only verge.
	var shelter_at := to_local(layout.entrance.global_position)+Vector3(-5.4,0,-11.5)
	model.box(alternate,shelter_at+Vector3(0,0.06,0),Vector3(2.2,0.12,1.0),Color("4b5755"))
	for x in [-0.95,0.95]:
		model.box(alternate,shelter_at+Vector3(x,1.0,0.35),Vector3(0.08,2.0,0.08),Color("82908a"))
	model.box(alternate,shelter_at+Vector3(0,2.0,0.35),Vector3(2.2,0.12,1.0),Color("536461"))
	model.box(alternate,shelter_at+Vector3(0,0.55,0.30),Vector3(1.45,0.12,0.42),Color("82755e"))
	label(alternate,"REDWATER BUS",shelter_at+Vector3(0,1.55,0.39),22)
	# Different roadside utility cabinet and municipal sign are visible from the forecourt.
	model.box(alternate,forecourt+Vector3(-5.6,0.65,4.2),Vector3(0.9,1.3,0.65),Color("52635f"))
	label(alternate,"R-14",forecourt+Vector3(-5.6,1.15,3.86),20)
	model.box(alternate,forecourt+Vector3(5.3,0.85,4.5),Vector3(0.10,1.7,0.10),Color("78837c"))
	model.box(alternate,forecourt+Vector3(5.3,1.65,4.5),Vector3(1.25,0.52,0.07),Color("557983"))
	label(alternate,"REDWATER",forecourt+Vector3(5.3,1.67,4.44),20)

	# At 03:17 a few Redwood objects coexist briefly with the Redwater set.
	var echo_at := to_local(layout.entrance.global_position)+Vector3(-2.8,0,6.4)
	model.box(overlap_echo,echo_at+Vector3(0,0.8,0),Vector3(0.09,1.6,0.09),Color("6d7772"))
	model.box(overlap_echo,echo_at+Vector3(0,1.55,0),Vector3(1.5,0.55,0.08),Color("334d4d"))
	label(overlap_echo,"REDWOOD\nSERVICE ROAD",echo_at+Vector3(0,1.58,-0.05),22)
	for x in [-1.4,1.4]:
		model.box(overlap_echo,echo_at+Vector3(x,0.12,1.25),Vector3(1.9,0.16,0.22),Color("73786d"))
	label(intrusions,"RIVERLINE DRINKS",to_local(layout.product_nodes[&"energy"].global_position)+Vector3(0,1.8,0.3),28)
	label(intrusions,"REDWATER DISTRIBUTION",to_local(layout.warehouse.global_position)+Vector3(9,1.7,-4),28)
	# Optional clues now live on surfaces that already belong in the shop instead of four random freestanding stands.
	var sites = [layout.checkout,layout.product_nodes[&"chips"],layout.warehouse.get_node("Supply"),layout.radio_point]
	var ids: Array[StringName] = [&"accident",&"map",&"missing",&"redwater"]
	var offsets := [
		Vector3(-0.72,1.10,-0.08), # local paper at the till
		Vector3(0.05,1.20,1.15),   # local paper on the snack end
		Vector3(1.05,0.82,0.18),   # stockroom delivery paperwork
		Vector3(-0.52,0.90,0.02)   # clipping beside the radio
	]
	for i in ids.size():
		var reader := point(self,ids[i],to_local(sites[i].global_position)+offsets[i],"Read "+preload("res://scripts/clue_catalog.gd").ENTRIES[ids[i]].title)
		model.box(reader,Vector3.ZERO,Vector3(0.32,0.018,0.24),Color("d0c9ad"))
		model.box(reader,Vector3(0,0.012,-0.07),Vector3(0.24,0.006,0.018),Color("66706a"))
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
	model.box(depot,Vector3(-1,0.83,-1.8),Vector3(0.7,0.05,0.5),Color("67736b"))
	for x in [-1.25,-0.75]: model.box(depot,Vector3(x,0.4,-1.8),Vector3(0.06,0.8,0.35),Color("53615c"))
	model.box(depot,Vector3(-1,0.865,-1.8),Vector3(0.5,0.02,0.35),Color("cfbea0"))
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
		loop.dialogue.begin(-20,PackedStringArray(entry.lines),choices,loop.story_flags,{"kind":&"document","title":entry.title})
	elif id == &"josh":
		if loop.story_flags.get(handover_flag(),false): return
		pending_handover = true
		loop.dialogue.begin(-10,loop.definition.handover,choices,loop.story_flags,{"speaker":"Josh"})
	elif id == &"construction" and construction.visible:
		loop.dialogue.begin(-30,PackedStringArray(["Construction of new access road — works begin today.","The map says Redwater. Its road bends behind a building that isn't on Mike's map."]),choices,loop.story_flags,{"kind":&"document","title":"Construction of new access road"})
		loop.story_flags[&"construction_read"] = true
	elif id == &"route":
		if configured_night == 4: travel(true)
		elif road.visible: world._say("The access is closed.")
	elif id == &"depot_clerk" and in_depot:
		pending_depot = true
		loop.dialogue.begin(-40,PackedStringArray(["Depot clerk: The station collection? It's ready, same as every week.","Take the usual road back. Your delivery account has been here for years."]),choices,loop.story_flags,{"speaker":"Depot Worker"})
	elif id == &"depot_ledger" and in_depot:
		loop.dialogue.begin(-41,PackedStringArray(["Station 14 — weekly collection route.","The first dated entry is eleven years old. The road name is the same one the navigation unit used tonight."]),choices,loop.story_flags,{"kind":&"document","title":"Depot route ledger"})
		loop.story_flags[&"depot_ledger_read"] = true
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
	fade.color = Color(0,0,0,0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade)
	var fade_out := create_tween()
	fade_out.tween_property(fade,"color:a",1.0,0.35)
	await fade_out.finished
	world.player.global_position = depot.global_position+Vector3(0,0.05,1) if outbound else travel_return+Vector3.UP*0.05
	in_depot = outbound
	await get_tree().create_timer(0.18).timeout
	var fade_in := create_tween()
	fade_in.tween_property(fade,"color:a",0.0,0.38)
	await fade_in.finished
	canvas.queue_free()
	world.player.set_physics_process(true)
	if not outbound: loop.active = resume_shift
	trip_busy = false

func signal_phone() -> void:
	# Kept as a compatibility hook for older event code; the physical phone now
	# belongs to the dedicated phone system.
	if is_instance_valid(world.phone_system):
		world.phone_system.story_ring()

func start_overlap() -> void:
	overlap_remaining = 3.17

func _process(delta: float) -> void:
	if not is_instance_valid(loop): return
	overlap_remaining = maxf(0.0,overlap_remaining-delta)
	if configured_night != loop.career_shifts+1: apply_night()
	if configured_night == 3 and loop.story_flags.get(&"presented_night_3_store_parcel",false):
		# The crack appears first; the road follows only after more of the shift has passed.
		loop.story_flags[&"crack_exists"] = true
		if loop.served+loop.lost_sales >= 5:
			loop.story_flags[&"road_exists"] = true
	road.visible = loop.story_flags.get(&"road_exists",false) or loop.definition.world_states.has(&"road")
	# Night 4 uses the route; Night 5 construction closes it again; Redwater treats it as normal.
	road.set_open(configured_night == 4 or configured_night == 6)
	crack.visible = loop.story_flags.get(&"crack_exists",false) or loop.definition.world_states.has(&"crack")
	construction.visible = loop.definition.world_states.has(&"construction")
	var redwater: bool = loop.definition.reality == &"redwater" and not ending_started
	alternate.visible = redwater
	intrusions.visible = configured_night >= 5 and not ending_started
	branding.text = "REDWATER SERVICE" if redwater or ending_started else "REDWOOD SERVICE"
	if is_instance_valid(overlap_echo):
		overlap_echo.visible = overlap_remaining > 0 and not ending_started
	if overlap_remaining > 0 and not ending_started:
		branding.text = "REDWOOD / REDWATER\n03:17"
	get_node("route").available = road.visible and not in_depot and configured_night >= 3 and configured_night <= 5
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
