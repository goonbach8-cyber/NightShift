extends "res://tests/campaign_test.gd"

func speak() -> void:
	var answers: Array[Dictionary] = []
	loop.dialogue.begin(-99,PackedStringArray(["Just a moment, please."]),answers,loop.story_flags)
	await create_timer(0.1).timeout

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await create_timer(0.4).timeout
	world.phase = world.Phase.ACTIVE
	loop.inventory.initialize_shelves()
	player.global_position = layout.warehouse.get_node("Supply").global_position+Vector3(0,0,1)
	await create_timer(0.2).timeout
	check(player.interaction_target == layout.warehouse.get_node("Supply"),"Supply is the real selected interaction")
	await speak()
	var selected: int = loop.supply_selection
	await key(KEY_E)
	await key(KEY_TAB)
	check(loop.inventory.carried_product() == &"" and loop.supply_selection == selected,"Hidden supply actions cannot collect or change goods during dialogue")
	await key(KEY_ESCAPE)
	check(paused,"Pause remains accessible during conversation")
	await key(KEY_ESCAPE)
	await key(KEY_SPACE)
	await key(KEY_E)
	check(loop.inventory.carried_product() == &"water","Supply input returns immediately after conversation")
	player.global_position = layout.product_points[&"water"].global_position
	await create_timer(0.2).timeout
	await speak()
	var before: int = loop.stock.shelf_units
	await key(KEY_E)
	check(loop.stock.shelf_units == before and loop.inventory.carried_product() == &"water","Dialogue cannot silently restock a shelf")
	await key(KEY_SPACE)
	await key(KEY_E)
	check(loop.stock.shelf_units > before,"Restock works after closing dialogue")
	player.global_position = layout.entrance.global_position+Vector3(0,0,-0.8)
	await create_timer(0.2).timeout
	await speak()
	await key(KEY_E)
	check(not layout.entrance.is_open,"Dialogue also blocks direct door interaction before its own handler")
	await key(KEY_SPACE)
	await key(KEY_E)
	await create_timer(0.5).timeout
	check(layout.entrance.is_open,"Door interaction resumes after dialogue")
	player.global_position = layout.radio_point.get_node("Approach").global_position
	await create_timer(0.2).timeout
	await speak()
	var track: int = world.radio.track_index
	var volume: float = world.radio.volume_db
	for code in [KEY_E,KEY_T,KEY_Y,KEY_PLUS,KEY_MINUS]: await key(code)
	check(not world.radio.enabled and world.radio.track_index == track and world.radio.volume_db == volume,"Hidden radio controls cannot interrupt conversation")
	await key(KEY_M)
	check(world.muted,"Global mute remains accessible during dialogue")
	await key(KEY_SPACE)
	await key(KEY_E)
	check(world.radio_tuner.active and player.controls_locked,"World radio interaction resumes after the last dialogue line")
	await key(KEY_T)
	check(world.radio.enabled,"Radio power can be changed in its focused tuner")
	await key(KEY_ESCAPE)
	check(not world.radio_tuner.active and not player.controls_locked,"Closing the tuner restores movement")
	await finish()
