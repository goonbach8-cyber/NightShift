extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var game = world.checkout_minigame
	world.player.global_position = world.layout.operator_point.global_position
	check(game.begin() and game.phase == &"waiting","Empty checkout can remain ready")
	var camera_position: Vector3
	await create_timer(0.25).timeout
	camera_position = game.camera.position
	var revenue := 0
	for i in 5:
		if loop.inventory.stocks[&"water"].shelf_units == 0:
			loop.collect_stock(&"water")
			loop.fill_shelf(&"water")
		var actor = customer()
		await process_frame
		await process_frame
		check(game.active and game.phase == &"scan" and game.customer == actor,"Arriving basket starts without re-entering: %d" % i)
		key(game,KEY_E)
		key(game,KEY_E)
		await create_timer(0.25).timeout
		check(loop.scanned_units == 1,"Repeated input during animation cannot double-scan")
		if game.phase == &"cash":
			for value in [200,50,20,10]: game._add_cash(value)
			key(game,KEY_ENTER)
		else:
			key(game,KEY_E)
		await create_timer(0.65).timeout
		revenue += 220
		check(actor.paid and loop.revenue_rappen == revenue and game.active and game.phase == &"waiting","Consecutive sale retains workstation and exact money: %d" % i)
		check(game.camera.position.is_equal_approx(camera_position),"No inter-customer camera reset")
	check(loop.served == 5 and loop.inventory.reservations.is_empty(),"Five baskets commit exactly once without orphan reservations")
	world.phone_system.story_ring()
	await process_frame
	await process_frame
	check(not game.active and not world.player.controls_locked,"Waiting cashier yields to an incoming story call")
	await finish()
