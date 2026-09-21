extends RefCounted
## Six compact story prototypes; pacing and dialogue are not final production content.
const NIGHT = preload("res://scripts/night_definition.gd")
const EVENT = preload("res://scripts/night_event.gd")

static func for_night(number: int) -> Resource:
	var night := NIGHT.new()
	night.customer_profiles.assign([
		{"id":&"regular_driver","color":Color("b0a079"),"greeting":"Evening. Just stopped on the way home."},
		{"id":&"local_worker","color":Color("6c8796"),"greeting":"Long day. Glad you're still open."}
	])
	night.title = "Night %d" % number
	if number == 1:
		night.handover = PackedStringArray(["Josh: First shift, Mike? The till's ready. Stock is out back.","Josh: One more thing. If the phone rings at 03:17… don't answer it.","Josh: Anyway. See you tomorrow."])
		night.title = "Night 1 — The warning"
		night.briefing = "Your first shift. Speak with Josh, then read the staff notes."
	elif number == 2:
		night.handover = PackedStringArray(["Mike: About what you said yesterday. The phone at 03:17.","Josh: What? I never said that.","Josh: Sorry, Mike. I really don't remember giving you a warning."])
		night.title = "Night 2 — The contradiction"
		night.briefing = "Josh is finishing up. Take over when you're ready."
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
	main.effect = &"phone_ring" if number == 1 else &"radio_interrupt"
	main.text = "The counter phone rings. Its display reads 03:17."
	if number == 2:
		main.text = "Radio: ‘...local time, 03:17.’ The station clock is nowhere near it."
		main.at_checkout = false
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
		night.required_story.assign([&"night_3_store_parcel"])
		night.required_tasks.erase(&"service")
		night.required_tasks.append(&"wc")
		night.customers = 7
		night.spawn_seconds = 9
		night.title = "Night 3 — Reality changes"
		night.briefing = "Shift notes: check the WC and put away the delivery."
		# Required physical story must remain reachable even if customers leave unpaid.
		main.after_sales = 0
		# The first undeniable event now happens physically beside the staffed checkout.
		main.effect = &"world_state"
		main.effect_target = &"checkout_display"
		main.show_caption = false
		main.text = ""
		var parcel := EVENT.new()
		parcel.event_id = &"night_3_store_parcel"
		parcel.main_event = true
		parcel.after_seconds = 0
		parcel.required_event = &"night_3_main"
		parcel.required_area = &"stockroom"
		parcel.at_checkout = false
		parcel.effect = &"world_state"
		parcel.effect_target = &"stockroom_parcel"
		parcel.text = "The small stock rack tips over beside you. Its contents stay where they fall."
		night.events.append(parcel)
	if number >= 4:
		night.world_states.assign([&"road",&"crack"])
		night.customers = 6
		night.spawn_seconds = 10
		night.required_tasks.erase(&"service")
	if number == 4:
		night.title = "Night 4 — The route"
		night.briefing = "Manager: Collect the replacement stock from the depot. The route is on the navigation unit."
		night.required_tasks.append(&"depot")
		main.text = "Navigation: route history found — station collections logged here for years."
		main.effect = &"navigation_chime"
		main.required_task = &"depot"
		main.at_checkout = false
	if number == 5:
		night.title = "Night 5 — Road works"
		night.briefing = "Road works beside the station. Deliveries are still scheduled as normal."
		night.world_states.append(&"construction")
		main.text = "Radio: ‘Road works begin today on the new Redwater access road.’"
		main.effect = &"radio_interrupt"
		main.at_checkout = false
	if number == 6:
		night.customer_profiles.assign([
			{"id":&"regular_driver","color":Color("b0a079"),"greeting":"Evening, Mike. You saved me a trip again."},
			{"id":&"redwater_courier","color":Color("8d748d"),"greeting":"Last delivery in Redwater tonight. Just something for the road."}
		])
		night.title = "Night 6 — Redwater"
		night.briefing = "Redwater Service. The rota has your name on every previous week."
		night.reality = &"redwater"
		night.world_states.append(&"redwater")
		night.handover = PackedStringArray(["Josh: Morning, Mike. Same routine as always?","Mike: Have you heard of Redwood? Or anything about 03:17?","Josh: Redwood? No. Is that another station? You've worked here longer than I have."])
		main.text = ""
		main.show_caption = false
		main.effect = &"reality_overlap"
		main.after_sales = 2
		main.at_checkout = false
	return night
