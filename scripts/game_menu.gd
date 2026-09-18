extends CanvasLayer
## One input-owning overlay for startup, pause, settings and night transitions.
var world: Node
var panel: Control
var column: VBoxContainer
var status: Label
var page := ""
var settings = preload("res://scripts/game_settings.gd").new()
var save = preload("res://scripts/shift_save.gd").new()
var inventory = preload("res://scripts/shop_inventory.gd").new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	settings.load_settings()
	if get_tree().has_meta("nightshift_checkpoint_path"):
		save.path = get_tree().get_meta("nightshift_checkpoint_path")
	for product in [preload("res://data/products/water.tres"), preload("res://data/products/energy.tres"), preload("res://data/products/chips.tres")]:
		inventory.add_product(product)
	if world == null: show_page("main")

func has_checkpoint() -> bool:
	for candidate in [save.path, save.path + ".bak"]:
		if FileAccess.file_exists(candidate) and save.valid(save.read_data(candidate), inventory): return true
	return false

func release_controls() -> void:
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action): Input.action_release(action)
	if is_instance_valid(world): world.player.velocity = Vector3.ZERO

func close() -> void:
	if is_instance_valid(panel): panel.queue_free()
	panel = null
	page = ""
	release_controls()
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE)) and is_instance_valid(world):
		if page == "": show_page("pause")
		elif page == "pause": close()
		elif page == "settings": show_page("pause")
		get_viewport().set_input_as_handled()
	elif page != "" and event is InputEventKey:
		# Controls still receive navigation keys, but gameplay never receives them.
		if event.pressed and event.physical_keycode == KEY_N and page == "complete": next_night()

func show_page(next: String) -> void:
	if is_instance_valid(panel):
		remove_child(panel)
		panel.queue_free()
	page = next
	release_controls()
	if is_instance_valid(world): get_tree().paused = true
	panel = ColorRect.new()
	panel.color = Color(0.018, 0.035, 0.043, 0.98)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = preload("res://scripts/ui/station_theme.gd").make()
	add_child(panel)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 460
	column.add_theme_constant_override("separation", 12)
	var surface := PanelContainer.new()
	center.add_child(surface)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520,minf(640,get_viewport().get_visible_rect().size.y-80))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	surface.add_child(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	label("03:17", 36)
	label("24 H / SERVICE STATION", 16)
	match page:
		"main":
			button("NEW GAME", request_new)
			var resume := button("CONTINUE", continue_game)
			resume.disabled = not has_checkpoint()
			button("SETTINGS", func(): show_page("settings"))
			button("QUIT", func(): get_tree().quit())
			if not has_checkpoint() and (FileAccess.file_exists(save.path) or FileAccess.file_exists(save.path + ".bak")):
				label("No readable checkpoint. Your files have been kept.", 16)
		"confirm_new":
			label("Start Night 1? Your previous progress will be replaced.", 17)
			button("CANCEL", func(): show_page("main"))
			button("START NEW GAME", new_game)
		"pause":
			label("PAUSED — progress is saved between nights.", 18)
			button("RESUME", close)
			button("SETTINGS", func(): show_page("settings"))
			button("RETURN TO MAIN MENU", func(): show_page("confirm_leave"))
		"confirm_leave":
			label("Return to the last safe checkpoint?\nThis night's unfinished progress will be lost.", 17)
			button("STAY", func(): show_page("pause"))
			button("RETURN TO MAIN MENU", return_main)
		"settings":
			for bus in ["Master", "Music", "SFX", "Ambience"]:
				label(("Radio" if bus == "Music" else bus) + " volume", 18)
				var slider := HSlider.new()
				slider.min_value = 0
				slider.max_value = 1
				slider.step = 0.05
				slider.value = settings.values[bus]
				column.add_child(slider)
				slider.value_changed.connect(func(value: float): settings.values[bus] = value; settings.save())
			var full := Button.new()
			full.toggle_mode = true
			full.text = "Display: Fullscreen" if settings.values.fullscreen else "Display: Windowed"
			full.custom_minimum_size.y = 46
			full.button_pressed = settings.values.fullscreen
			column.add_child(full)
			full.toggled.connect(func(value: bool):
				full.text = "Display: Fullscreen" if value else "Display: Windowed"
				settings.values.fullscreen = value
				settings.save())
			button("BACK", func(): show_page("pause" if is_instance_valid(world) else "main"))
		"complete":
			label("NIGHT %d COMPLETE" % (world.gameplay.career_shifts + 1), 26)
			label("%d customers / %d items / CHF %.2f" % [world.gameplay.served, world.gameplay.sold_units, world.gameplay.revenue_rappen / 100.0], 20)
			label("Lost customers: %d  |  Tasks completed: %d / %d" % [world.gameplay.lost_sales,world.gameplay.tasks.size(),world.gameplay.required_tasks.size()],18)
			button("CONTINUE TO NEXT NIGHT [N]", next_night)
			button("RETURN TO MAIN MENU", save_and_return)
		"ending":
			panel.color = Color(0.018,0.035,0.043,0.55)
			label("03:17",32)
			label("The station looks familiar again.\nThe roadside sign still says Redwater.",20)
			button("CONTINUE",func(): show_page("josh_call" if preload("res://scripts/clue_catalog.gd").eligible(world.gameplay.story_flags) else "credits"))
		"josh_call":
			label("The phone rings.",22)
			label("Josh: Mike? You noticed the sign, didn't you?\nJosh: I hoped you wouldn't have to ask me about it.\nThe line goes quiet.",20)
			button("CONTINUE",func(): show_page("credits"))
		"credits":
			label("03:17 — END",28)
			label("Thank you for playing this story prototype.",18)
			button("MAIN MENU",return_main)
	status = label("", 16)
	for child in column.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break

func label(text: String, size: int) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size)
	column.add_child(item)
	return item

func button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 46
	item.add_theme_font_size_override("font_size", 20)
	item.pressed.connect(action)
	column.add_child(item)
	return item

func request_new() -> void:
	if FileAccess.file_exists(save.path) or FileAccess.file_exists(save.path + ".bak"): show_page("confirm_new")
	else: new_game()

func new_game() -> void:
	var stocks := {}
	for id in inventory.products:
		var product: Resource = inventory.products[id]
		stocks[String(id)] = {"warehouse": product.initial_warehouse, "shelf": product.initial_shelf}
	if not save.store_data({"version": 1, "shifts": 0, "revenue": 0, "stocks": stocks, "flags": {}, "events": {}}, inventory):
		status.text = "Could not create checkpoint. Previous progress is retained."
		return
	continue_game()

func continue_game() -> void:
	if not has_checkpoint(): return
	get_tree().set_meta("nightshift_checkpoint_path", save.path)
	get_tree().set_meta("nightshift_continue", true)
	get_tree().set_meta("nightshift_menu_session", true)
	close()
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func next_night() -> void:
	if world.gameplay.career_shifts >= 5:
		world.gameplay.story_flags[&"ending_seen"] = true
		if not world.checkpoint.write_checkpoint(world.gameplay):
			status.text = "Save failed. Please try again."
			return
		world.story_world.enter_ending()
		show_page("ending")
		return
	if not world.checkpoint.write_checkpoint(world.gameplay):
		status.text = "Save failed. Please try again."
		return
	save.path = world.checkpoint.path
	continue_game()

func save_and_return() -> void:
	if world.checkpoint.write_checkpoint(world.gameplay): return_main()
	else: status.text = "Save failed. Please try again."

func return_main() -> void:
	close()
	get_tree().change_scene_to_file("res://scenes/main/menu.tscn")
