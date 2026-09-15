extends RefCounted
var path := "user://nightshift_settings.cfg"
var values := {"Master": 0.8, "Music": 0.7, "SFX": 0.8, "Ambience": 0.7, "fullscreen": false}

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
	for bus in ["Master", "Music", "SFX", "Ambience", "Radio"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		# Music is the legacy saved key; the dedicated radio bus inherits its gain.
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), 0 if bus == "Radio" else linear_to_db(values[bus]))
	AudioServer.set_bus_send(AudioServer.get_bus_index("Radio"),"Music")
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save() -> Error:
	apply()
	var config := ConfigFile.new()
	for key in values: config.set_value("settings", key, values[key])
	return config.save(path)
