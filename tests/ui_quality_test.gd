extends "res://tests/campaign_test.gd"
## Real scene/state + internal input, without desktop interaction or a renderer.
var snapshots: Dictionary = {}

func settle() -> void:
	for i in 5: await process_frame
	await create_timer(0.05).timeout

func snapshot(id: String) -> void:
	await settle()
	var nodes: Array = []
	collect_ui(world.hud,nodes)
	snapshots[id] = {"viewport":[root.get_visible_rect().size.x,root.get_visible_rect().size.y],"nodes":nodes}

func collect_ui(node: Node, output: Array) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is PanelContainer or node is Label:
		var rect: Rect2 = node.get_global_rect()
		var record := {"kind":"panel" if node is PanelContainer else "text","rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]}
		if node is Label:
			record.text = node.text
			record.font_size = node.get_theme_font_size("font_size")
			record.color = node.get_theme_color("font_color").to_html()
			record.align = node.horizontal_alignment
		else:
			var style: StyleBoxFlat = node.get_theme_stylebox("panel")
			record.color = style.bg_color.to_html()
			record.border = style.border_color.to_html()
		output.append(record)
	for child in node.get_children(): collect_ui(child,output)

func fits(node: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).encloses(node.get_global_rect()) and node.get_minimum_size().y <= node.size.y+1

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await settle()
	var ui = world.hud
	var dialogue = ui.conversation
	await snapshot("normal")
	check(not dialogue.frame.visible and not dialogue.document.visible and not ui.checkout_panel.visible,"Normal play has no stale modal or checkout panel")
	check(not world.get_node("HUD/Controls").visible and not ui.debug.visible,"Permanent key dashboard and developer data are absent")
	player.global_position = world.get_node("Station/ShiftBoard").global_position+Vector3(0,0,1)
	await settle()
	await key(KEY_F)
	check(dialogue.document.visible and dialogue.document_body.text == loop.definition.briefing and world.phase == world.Phase.NOT_STARTED,"Staff notes retain the briefing on demand without starting the shift")
	await key(KEY_ENTER)
	world.story_world.interact(&"josh")
	while not loop.dialogue.lines[loop.dialogue.index].contains("don't answer it"): loop.dialogue.advance()
	await settle()
	check(dialogue.speaker.text == "Josh" and dialogue.body.text.contains("03:17"),"Josh warning has a separate player-facing speaker and intact line")
	check(not ui.objective_panel.visible and not ui.prompt_panel.visible and not ui.carry.visible,"Conversation removes work HUD and prompts")
	var before: Vector3 = player.global_position
	Input.action_press("move_right")
	await create_timer(0.2).timeout
	Input.action_release("move_right")
	check(player.global_position.distance_to(before) < 0.02,"Dialogue locks movement without pausing the world")
	await snapshot("josh")
	while loop.dialogue.index < loop.dialogue.lines.size()-1: loop.dialogue.advance()
	await key(KEY_ENTER)
	check(not loop.dialogue.active and not player.controls_locked,"Enter closes handover and releases movement lock")
	var content = preload("res://scripts/dialogue_catalog.gd").for_context({&"night_1_main":true},{},1)
	loop.dialogue.begin(123,content.lines,content.choices,loop.story_flags)
	while loop.dialogue.index < loop.dialogue.lines.size()-1: loop.dialogue.advance()
	await settle()
	check(dialogue.answers.get_child_count() == 2 and dialogue.selection == 0,"Choice panel starts with two answers and a visible selection")
	await key(KEY_DOWN)
	check(dialogue.selection == 1,"Down changes the selected answer")
	await snapshot("choices")
	await key(KEY_E)
	check(loop.story_flags.get(&"denied_call",false) and loop.dialogue.active and loop.dialogue.choices.is_empty(),"E confirms only the selected answer and keeps the reply open")
	await key(KEY_ENTER)
	loop.dialogue.begin(123,content.lines,content.choices,loop.story_flags)
	while loop.dialogue.index < loop.dialogue.lines.size()-1: loop.dialogue.advance()
	await key(KEY_1)
	check(loop.story_flags.get(&"asked_about_call",false),"Number fallback still applies the existing story flag")
	loop.dialogue.close(true)
	world.story_world.interact(&"accident")
	await settle()
	check(dialogue.document.visible and not dialogue.frame.visible and dialogue.document_body.text.contains("03:17"),"Newspaper uses a separate paper view with the complete article")
	check(not loop.story_flags.get(&"clue_accident",false),"Opening a document does not prematurely mark it completed")
	await snapshot("document")
	await key(KEY_ENTER)
	check(loop.story_flags.get(&"clue_accident",false) and not dialogue.document.visible,"Closing the read article retains existing clue tracking")
	loop.inventory.initialize_shelves()
	world.phase = world.Phase.ACTIVE
	loop.order_patterns.assign([{&"water":1,&"energy":1,&"chips":1}])
	loop.spawn_customer()
	var customer = loop.customers[0]
	customer.set_physics_process(false)
	customer.walking = false
	customer.state = &"queued"
	customer.global_position = layout.queue_points[0].global_position
	loop.queue.append(customer)
	for id in customer.order: loop.inventory.reserve(customer.get_instance_id(),id,customer.order[id])
	player.global_position = layout.operator_point.global_position
	await settle()
	check(ui.checkout_panel.visible and ui.checkout_progress.text.contains("0 / 3"),"Waiting basket opens a clean contextual checkout")
	await use()
	await snapshot("scan")
	check(ui.checkout_title.text.contains("scanned") and ui.checkout_progress.text.contains("2 remaining") and ui.checkout_amount.text == "CHF 2.20","Scan shows article, remaining count and exact subtotal in separate levels")
	await use()
	await use()
	await snapshot("payment")
	check(ui.checkout_title.text == "TOTAL" and ui.checkout_amount.text == "CHF 8.60" and ui.prompt.text.contains("Accept payment"),"Final item enables one primary payment action with full total")
	await key(KEY_ESCAPE)
	await key(KEY_E)
	check(paused and loop.revenue_rappen == 0,"Pause blocks payment while retaining the transaction")
	await key(KEY_ESCAPE)
	await use()
	check(loop.revenue_rappen == 860 and not ui.checkout_panel.visible,"Payment commits once and removes checkout panel")
	loop.inventory.take_crate(&"energy")
	player.global_position = layout.product_nodes[&"energy"].global_position+Vector3(0,0,1.3)
	await snapshot("restock")
	check(ui.carry.visible and ui.carry.text.contains("Energy"),"Carried stock has a small contextual indicator")
	check(not ui.carry_panel.get_global_rect().intersects(ui.prompt_panel.get_global_rect()),"Carried-stock panel does not overlap the primary interaction")
	await snapshot("objective")
	var empty: Array[Dictionary] = []
	loop.inventory.restock(&"energy")
	loop.delivery_ready = true
	layout.delivery.available = true
	player.global_position = layout.delivery.global_position+Vector3(-1,0,0)
	await settle()
	await use()
	await snapshot("delivery")
	check(loop.delivery_carried and ui.message.text.contains("DELIVERY") and ui.message.text.contains("×6") and ui.message.text.contains("×4") and ui.message.text.contains("×3"),"Actual delivery pickup shows the mixed manifest")
	world.message_time = 0
	await settle()
	check(not ui.notice_panel.visible,"Delivery manifest disappears after its reading window")
	for night in range(1,7):
		loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(night))
		world.phase = world.Phase.NOT_STARTED
		await settle()
		check(not loop.definition.handover.is_empty() or not ui.objective.text.contains("Josh"),"Night %d without a handover never points at an absent Josh" % night)
	world.phase = world.Phase.ACTIVE
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = resolution
		loop.dialogue.begin(123,PackedStringArray(["One more thing. If the phone rings at 03:17... don't answer it. ".repeat(4)]),content.choices,{}, {"speaker":"Night service depot worker"})
		await settle()
		check(fits(dialogue.frame) and fits(dialogue.body) and fits(dialogue.speaker) and fits(dialogue.answers),"Long dialogue, speaker and choices stay within safe area at "+str(resolution))
		await snapshot("long_"+str(resolution.x))
		loop.dialogue.close()
		await settle()
		check(fits(ui.objective_panel) and fits(ui.prompt_panel),"Objective and prompt fit at "+str(resolution))
	root.size = Vector2i(960,540)
	loop.dialogue.begin(-80,PackedStringArray(["A routine maintenance note. ".repeat(120)]),empty,{}, {"kind":&"document","title":"Long service report"})
	await settle()
	await key(KEY_DOWN)
	check(dialogue.document_scroll.scroll_vertical > 0 and fits(dialogue.document),"Long documents remain inside the window and scroll with keyboard")
	await key(KEY_ENTER)
	check(not dialogue.document.visible and not player.controls_locked,"Document close clears its panel and input lock")
	for page in ["pause","settings","complete"]:
		world.menu.show_page(page)
		await settle()
		check(fits(world.menu.column.get_parent()),page+" menu uses an on-screen scroll area at small window size")
		world.menu.close()
	var file := FileAccess.open("user://ui-layout-snapshots.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshots,"\t"))
	file.close()
	print("UI LAYOUT SNAPSHOTS: "+ProjectSettings.globalize_path("user://ui-layout-snapshots.json"))
	await finish()
