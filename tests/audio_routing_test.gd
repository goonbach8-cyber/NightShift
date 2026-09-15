extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	check(world.radio.bus == &"Radio","Radio has dedicated bus")
	check(world.ambience.bus == &"Ambience" and world.feedback.bus == &"SFX","Room ambience and interaction effects use separate buses")
	var ambient_count := 0
	for sound in layout.warehouse.sounds:
		if sound.has_meta("audio_category"):
			ambient_count += 1
			check(sound.bus == &"Ambience","Spatial cooler, warehouse and wind use Ambience")
		else: check(sound.bus == &"SFX","Door motion uses SFX")
	check(ambient_count == 3,"All three spatial ambience emitters are routed")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Radio")) == &"Music","Legacy radio volume setting remains compatible")
	await finish()
