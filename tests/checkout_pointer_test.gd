extends "res://tests/service_runtime_base.gd"
var game

func click(at: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	await setup()
	game = world.checkout_minigame
	var actor = customer()
	world.player.global_position = world.layout.operator_point.global_position
	var origin: Vector3 = game.camera.position
	var size: float = game.camera.size
	check(game.begin(),"Cashier workstation opens")
	await create_timer(0.25).timeout
	await click(Vector2(10,10))
	check(loop.scanned_units == 0,"Clicking empty space cannot scan")
	var item: Vector2 = game.camera.unproject_position(game.current_visual.to_global(Vector3(0,0.15,0)))
	await click(item)
	await create_timer(0.25).timeout
	check(loop.scanned_units == 1 and game.phase == &"card" and loop.revenue_rappen == 0,"One product click scans once without charging")
	await click(game.camera.unproject_position(game.card_root.global_position))
	await create_timer(0.65).timeout
	check(actor.paid and loop.revenue_rappen == 220 and game.active and game.phase == &"waiting","Card tap commits once and keeps cashier mode open")
	game.cancel()
	await create_timer(0.25).timeout
	check(game.camera.position.is_equal_approx(origin) and is_equal_approx(game.camera.size,size),"Deliberate exit restores the gameplay camera")
	loop.served = 2
	customer()
	check(game.begin(),"Cash basket opens")
	key(game,KEY_E)
	await create_timer(0.25).timeout
	check(game.phase == &"cash","Direct keyboard scan reaches cash payment")
	key(game,KEY_ENTER)
	await create_timer(0.15).timeout
	check(loop.revenue_rappen == 220 and game.status.text.contains("short"),"Short change remains unpaid with persistent feedback")
	for code in [KEY_1,KEY_3,KEY_4,KEY_5]: key(game,code)
	check(game.cash_added == 280,"Direct denominations build exact change")
	key(game,KEY_BACKSPACE)
	check(game.cash_added == 270,"Undo corrects the change tray")
	key(game,KEY_5)
	key(game,KEY_ENTER)
	await create_timer(0.45).timeout
	check(loop.revenue_rappen == 440 and game.active,"Exact cash commits through the same inventory authority")
	game.cancel()
	check(loop.collect_stock(&"water"),"Fixture replenishes real stock")
	loop.fill_shelf(&"water")
	customer()
	game.begin()
	key(game,KEY_E)
	key(game,KEY_ESCAPE)
	game.begin()
	await create_timer(0.3).timeout
	check(game.phase == &"scan" and loop.revenue_rappen == 440,"Cancelled scan cannot advance a reopened transaction")
	key(game,KEY_E)
	await create_timer(0.25).timeout
	key(game,KEY_E)
	key(game,KEY_ESCAPE)
	game.begin()
	await create_timer(0.3).timeout
	check(game.phase == &"scan" and loop.revenue_rappen == 440,"Cancelled card tap cannot pay a reopened transaction")
	game.cancel()
	await finish()
