extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	loop.career_shifts = 1
	loop.served = 3
	# Isolate the existing restroom-key request from the independent lost-item
	# request, not from its gating, input focus or inventory rules.
	world.customer_assistance.completed = true
	var game = world.checkout_minigame
	world.player.global_position = world.layout.operator_point.global_position
	check(game.begin() and game.phase == &"waiting","Cashier waits for a later-night customer")
	var actor = customer()
	await process_frame
	await process_frame
	var requests = world.customer_requests
	check(requests.active and not game.active and not world.player.controls_locked,"A real assistance request hands control back to the world")
	check(not actor.paid and loop.inventory.reservations.has(actor.get_instance_id()) and loop.revenue_rappen == 0,"Handoff does not scan, sell or release the waiting basket")
	requests.handle_action(&"customer_service_key")
	requests.handle_checkout_use()
	check(requests.completed and not requests.active,"Existing physical assistance workflow completes normally")
	check(game.begin() and game.phase == &"scan" and game.customer == actor,"The same customer can be served after assistance")
	game.cancel()
	await finish()
