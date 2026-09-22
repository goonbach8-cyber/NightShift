extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	loop.career_shifts = 2
	loop.served = 3
	var actor = customer()
	world.player.global_position = world.layout.operator_point.global_position
	check(world.phone_system.begin(),"Phone takes focus")
	check(not world.checkout_minigame.begin(),"Checkout cannot steal phone focus")
	world.pump_service.request_pending = true
	check(not world.pump_service.begin(),"Pump terminal cannot steal phone focus")
	world.pump_service.request_pending = false
	check(not world.customer_assistance.handle_checkout_use(),"Lost item cannot interrupt phone conversation")
	world.phone_system.close()
	# Explicit pending-state fixtures exercise arbitration independently of timers.
	for entry in [[world.pump_service,"request_pending"],[world.pump_service,"fault_pending"],[world.cctv_system,"motion_pending"],[world.power_service,"fault_pending"],[world.phone_system,"ringing"],[world.spill_service,"spill_pending"],[world.radio_tuner,"drift_pending"],[world.device_service,"fault_pending"]]:
		entry[0].set(entry[1],true)
		check(not world.can_start_interrupt(),"Pending %s excludes another interruption" % entry[1])
		entry[0].set(entry[1],false)
	check(world.can_start_interrupt(),"Resolved interruption permits next request")
	loop.abandon_customer(actor)
	await finish()
