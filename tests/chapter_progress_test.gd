extends "res://tests/service_runtime_base.gd"

func run() -> void:
	await setup()
	loop.customer_count = 0
	for task in loop.required_tasks:
		loop.tasks[task] = true
	loop.tasks.erase(&"restock")
	for item in loop.inventory.stocks.values():
		item.shelf_units = item.capacity
	loop.interact(&"shelf",world.player)
	check(loop.tasks.has(&"restock"),"An explicit check of full displays completes stock duty without sales")
	check(not loop.can_finish(),"Completed work cannot skip the first story chapter")
	world.player.global_position = world.layout.operator_point.global_position
	world._on_event(loop.definition.events[0])
	await process_frame
	await process_frame
	var phone = world.phone_system
	check(phone.ringing,"The 03:17 call can be presented without a customer at the till")
	world._on_used(&"start")
	check(world.phase == world.Phase.ACTIVE and not loop.dialogue.active,"Pending call does not unlock the chapter wrap-up")
	phone._process(phone.ring_timeout+0.1)
	world._on_used(&"start")
	check(loop.dialogue.active and not loop.can_finish(),"Missing the call still unlocks an explicit story follow-up")
	loop.dialogue.close()
	check(not loop.can_finish(),"Closing the story follow-up does not count as experiencing it")
	world._on_used(&"start")
	while loop.dialogue.active:
		loop.dialogue.advance()
	check(loop.can_finish(),"Completed story follow-up unlocks shift end")
	world._on_used(&"start")
	check(world.phase == world.Phase.COMPLETE,"Shift closes after work and story are complete")
	await finish()
