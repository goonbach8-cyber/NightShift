extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var requests = world.customer_requests
	var actor = customer()
	loop.served = 3
	for night in [2,3,4,5]:
		loop.career_shifts = night-1
		requests.completed = false
		check(requests.handle_checkout_use(),"Customer starts request in Night %d" % night)
		check(actor.state == &"customer_request","Request holds customer at checkout")
		match requests.request_kind:
			&"wc_key":
				check(world.layout.customer_service_key.available,"Staff-area key becomes available")
				world._on_used(&"customer_service_key")
				check(is_instance_valid(requests.carried_prop),"Restroom key is physically carried")
			&"price_check":
				check(is_instance_valid(requests.task_point),"Price check has a shelf interaction")
				requests.task_point.used.emit(&"price_check")
				check(requests.task_complete,"Actual shelf price is read")
			&"fuel_receipt":
				world._on_used(&"pump_terminal")
				check(requests.task_complete and is_instance_valid(requests.carried_prop) and not world.pump_service.active,"Receipt terminal serves request without opening pump service")
		requests.handle_checkout_use()
		check(requests.completed and not requests.active and actor.state == &"queued","Request return unblocks checkout")
	check(loop.checkout() and loop.checkout() and actor.paid,"Requested services preserve customer's basket")
	await finish()
