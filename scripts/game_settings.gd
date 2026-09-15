extends RefCounted
var path := "user://nightshift_settings.cfg"
var values := {"Master": 0.8, "Music": 0.7, "SFX": 0.8, "fullscreen": false}

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		for key in values:
			var value: Variant = config.get_value("settings", key, values[key])
			if key == "fullscreen":
				if value is bool: values[key] = value
			elif (value is float or value is int) and is_finite(float(value)):
				values[key] = clampf(float(value), 0, 1)
	apply()

func apply() -> void:
	for bus in ["Master", "Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(values[bus]))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save() -> Error:
	apply()
	var config := ConfigFile.new()
	for key in values: config.set_value("settings", key, values[key])
	return config.save(path)
