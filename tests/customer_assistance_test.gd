extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var service = world.customer_assistance
	var actor = customer()
	loop.served = 1
	check(not service.handle_checkout_use(),"First night does not require lost-item assistance")
	for night in [2,3,4]:
		loop.career_shifts = night-1
		service.completed = false
		check(service.handle_checkout_use(),"Later customer requests lost item")
		check(actor.state == &"assistance" and is_instance_valid(service.item_node),"Customer waits while lost item exists in shop")
		var before: float = actor.wait_seconds
		loop.customer_count = loop.spawned
		loop._process(5.0)
		check(actor.wait_seconds == before,"Assisted customer does not lose patience")
		service.item_node.used.emit(&"lost_customer_item")
		check(service.item_found and is_instance_valid(service.carried_item),"Lost item can be carried")
		service.handle_checkout_use()
		check(actor.state == &"queued" and service.completed and not service.request_active,"Returning item restores normal queue state")
	check(loop.checkout() and loop.checkout() and actor.paid,"Checkout works after assistance")
	await finish()
