extends RefCounted
## Night 1 and a configurable following-night template; not final story content.
const NIGHT = preload("res://scripts/night_definition.gd")
const EVENT = preload("res://scripts/night_event.gd")

static func for_night(number: int) -> Resource:
	var night := NIGHT.new()
	night.title = "Night %d" % number
	night.customers = 6 if number == 1 else 8
	night.spawn_seconds = 8 if number == 1 else 6
	night.orders.assign([{&"water":1},{&"energy":1},{&"chips":1,&"water":1},{&"energy":1,&"chips":1},{&"water":2},{&"energy":1,&"water":1,&"chips":1}])
	night.delivery = {&"water":6,&"energy":4,&"chips":3}
	if number >= 2:
		night.required_tasks.append(&"service")
	var main := EVENT.new()
	main.event_id = StringName("night_%d_main" % number)
	main.main_event = true
	main.after_seconds = 22
	main.effect = &"message" if number == 1 else &"radio_interrupt"
	main.text = "The maintenance log mentions a call at 03:17. The clock has not reached 03:17 yet."
	night.events.append(main)
	var variable := EVENT.new()
	variable.event_id = StringName("night_%d_light" % number)
	variable.after_seconds = 45
	variable.after_sales = 1
	variable.probability = 0.5
	variable.effect = &"light_dip"
	variable.text = "The cooler light fades for a moment. It settles again."
	night.events.append(variable)
	if number == 3:
		night.customers = 7
		night.spawn_seconds = 9
		night.title = "Night 3 — The return call"
		main.after_sales = 1
		main.effect = &"message"
		main.text = "The customer places a blank receipt on the counter.\n‘I was told you would remember the number.’\n[F] Talk"
		var parcel := EVENT.new()
		parcel.event_id = &"night_3_store_parcel"
		parcel.main_event = true
		parcel.after_seconds = 0
		parcel.required_event = &"night_3_main"
		parcel.required_area = &"stockroom"
		parcel.at_checkout = false
		parcel.effect = &"world_state"
		parcel.effect_target = &"stockroom_parcel"
		parcel.text = "A carton slides off the shelf. Nothing else moves."
		night.events.append(parcel)
	return night
