extends "res://tests/service_runtime_base.gd"
## Project actual counter coordinates through the gameplay camera, then send
## in-engine pointer events. No OS input or renderer is required for hit mapping.
var game

func mouse_button(at: Vector2, button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame

func drag_to(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await process_frame

func screen(at: Vector3) -> Vector2:
	return game.camera.unproject_position(game.counter_root.to_global(at))

func run() -> void:
	root.size = Vector2i(1280,720)
	await setup()
	game = world.checkout_minigame
	var actor = customer()
	world.player.global_position = world.layout.operator_point.global_position
	var original_position: Vector3 = game.camera.position
	var original_size: float = game.camera.size
	check(game.begin(),"Pointer checkout opens")
	await create_timer(0.26).timeout
	check(game.camera.size < original_size and game._barcode_aligned(),"Focused counter presents a ready-to-scan product")
	# A deliberately misoriented item still requires correction, not a free scan.
	game.item_rotation = 0
	game.slide = game.SCANNER_X
	game._process(0.01)
	check(loop.scanned_units == 0,"A barcode facing away cannot scan")
	game.slide = game.START_X
	game.item_rotation = -PI
	game._apply_item_transform()
	await mouse_button(Vector2(20,20),MOUSE_BUTTON_LEFT,true)
	await drag_to(screen(Vector3(game.SCANNER_X,1.11,0.19)))
	check(loop.scanned_units == 0,"Dragging empty space cannot move or scan merchandise")
	await mouse_button(Vector2(20,20),MOUSE_BUTTON_LEFT,false)
	var grab := screen(Vector3(game.START_X,1.26,0.19))
	await mouse_button(grab,MOUSE_BUTTON_LEFT,true)
	check(game.dragging,"Clicking the visible product grabs it")
	# Preserve the grab offset; sweep past the scanner in one frame.
	await drag_to(grab+screen(Vector3(game.SLIDE_MAX,1.11,0.19))-screen(Vector3(game.START_X,1.11,0.19)))
	await mouse_button(grab,MOUSE_BUTTON_LEFT,false)
	await create_timer(0.26).timeout
	check(loop.scanned_units == 1 and game.phase == &"card" and loop.revenue_rappen == 0,"Fast pointer sweep scans once without charging")
	var card: Vector2 = game.camera.unproject_position(game.card_root.global_position)
	await mouse_button(card,MOUSE_BUTTON_LEFT,true)
	await mouse_button(card,MOUSE_BUTTON_LEFT,false)
	await create_timer(1.15).timeout
	check(actor.paid and loop.revenue_rappen == 220 and not game.active,"Clicking the physical card animates payment and commits exactly once")
	await create_timer(0.25).timeout
	check(game.camera.position.is_equal_approx(original_position) and is_equal_approx(game.camera.size,original_size),"Checkout restores the gameplay camera")

	loop.served = 2
	customer()
	check(game.begin(),"Cash basket opens")
	await create_timer(0.26).timeout
	# Use the accessible keyboard route to scan this basket.
	var event := InputEventKey.new()
	event.physical_keycode = KEY_D
	event.pressed = true
	Input.parse_input_event(event)
	await create_timer(0.75).timeout
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	check(game.phase == &"cash","Keyboard sweep reaches the same cash workflow")
	await mouse_button(screen(Vector3(0.43,1.055,0.33)),MOUSE_BUTTON_LEFT,true)
	await mouse_button(screen(Vector3(0.43,1.055,0.33)),MOUSE_BUTTON_LEFT,false)
	await create_timer(0.15).timeout
	check(loop.revenue_rappen == 220 and game.status.text.contains("short"),"Premature cash handover is rejected with feedback that survives refresh")
	await mouse_button(screen(Vector3(0.10,1.075,-0.02)),MOUSE_BUTTON_LEFT,true)
	await mouse_button(screen(Vector3(0.10,1.075,-0.02)),MOUSE_BUTTON_LEFT,false)
	check(game.cash_added == 200,"Clicking the two-franc compartment adds its denomination")
	await mouse_button(Vector2(20,20),MOUSE_BUTTON_RIGHT,true)
	check(game.cash_added == 0,"Right-click corrects change without losing the transaction")
	for code in [KEY_1,KEY_3,KEY_4,KEY_5]: key(game,code)
	check(game.cash_added == 280,"Direct denomination keys build exact change without cycling")
	await mouse_button(screen(Vector3(0.43,1.055,0.33)),MOUSE_BUTTON_LEFT,true)
	await mouse_button(screen(Vector3(0.43,1.055,0.33)),MOUSE_BUTTON_LEFT,false)
	await create_timer(1.15).timeout
	check(loop.revenue_rappen == 440 and not game.active,"Cash handover commits only exact change")
	await create_timer(0.25).timeout
	check(loop.collect_stock(&"water"),"Replenishment fixture collects real warehouse stock")
	loop.fill_shelf(&"water")
	customer()
	check(game.begin(),"Another basket can open after cash")
	await create_timer(0.26).timeout
	game.slide = game.SCANNER_X
	game._apply_item_transform()
	await create_timer(0.26).timeout
	check(game.phase == &"card","Cancellation fixture reaches card payment")
	card = game.camera.unproject_position(game.card_root.global_position)
	await mouse_button(card,MOUSE_BUTTON_LEFT,true)
	await mouse_button(card,MOUSE_BUTTON_LEFT,false)
	check(game.busy,"Card tap has started before cancellation")
	key(game,KEY_ESCAPE)
	check(game.begin(),"Checkout can reopen while the previous card animation is ending")
	await create_timer(0.30).timeout
	check(game.phase == &"scan" and loop.revenue_rappen == 440,"An old card tap cannot pay or advance a new checkout session")
	key(game,KEY_ESCAPE)
	await create_timer(0.26).timeout
	check(game.camera.position.is_equal_approx(original_position) and is_equal_approx(game.camera.size,original_size),"Rapid cancel/reopen still restores the original camera")
	await finish()
