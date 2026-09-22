extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var actor = customer()
	world.player.global_position = world.layout.operator_point.global_position
	var game = world.checkout_minigame
	check(game.begin(),"Checkout starts staged basket")
	game.item_rotation = -PI
	game.slide = game.SCANNER_X
	game._apply_item_transform()
	game._scan_current()
	key(game,KEY_ESCAPE)
	await create_timer(0.35).timeout
	check(not game.active and game.phase == &"idle" and not world.player.controls_locked,"Cancel during scan animation stays cancelled")
	check(loop.scanned_units == 0 and loop.scanned_owner == 0 and loop.queue[0] == actor,"Cancel clears staged scan without losing queue owner")
	check(loop.inventory.reservations.has(actor.get_instance_id()) and loop.revenue_rappen == 0,"Cancelled basket remains reserved and unpaid")
	check(game.begin(),"Cancelled basket can be restarted")
	game.item_rotation = -PI
	game.slide = game.SCANNER_X
	game._apply_item_transform()
	game._scan_current()
	await create_timer(0.28).timeout
	game._enter_cash(220)
	game._add_cash(200)
	game._confirm_cash()
	check(loop.revenue_rappen == 0,"Incorrect cash change cannot complete sale")
	game._add_cash(100)
	game._remove_cash()
	check(game.cash_added == 200,"Undo removes last coin")
	game._add_cash(50)
	game._add_cash(20)
	game._add_cash(10)
	game.printer_jam_pending = true
	game._confirm_cash()
	check(game.phase == &"printer_jam" and loop.revenue_rappen == 220,"Sale commits once before paper jam")
	game._feed_printer()
	check(game.phase == &"printer_jam","Crooked paper cannot print receipt")
	game.printer_alignment = 0
	game._feed_printer()
	await create_timer(0.95).timeout
	check(not game.active and not world.player.controls_locked and loop.revenue_rappen == 220,"Paper feed completes receipt without duplicate payment")
	await finish()
