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
		night.handover = PackedStringArray(["Josh: First shift, Mike? The till's ready. Stock is out back.","Josh: One more thing. If the phone rings at 03:17… don't answer it.","Mike: You still hang the keys where Lea used to leave them.","Josh: Yeah. Good to have you back, Mike."])
		night.title = "Night 1 — The warning"
		night.briefing = "Your first shift. Speak with Josh, then read the staff notes."
	elif number == 2:
		night.handover = PackedStringArray(["Mike: About what you said yesterday. The phone at 03:17.","Josh: What? I never said that.","Josh: Sorry, Mike. I really don't remember giving you a warning.","Josh: I'll leave the key by the till. Like I always do."])
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
	variable.required_event = main.event_id
	night.events.append(variable)
	night.required_story.append(main.event_id)
	if number == 1:
		night.personal_goal = "Find out why Josh warned you about the phone."
		night.chapter_steps.assign([{
			"id":&"mike_first_note","location":&"board","after_event":main.event_id,"after_flag":&"phone_0317_resolved",
			"wait":"Check the phone from the staff side of the till.",
			"prompt":"Write down what happened at 03:17","speaker":"Mike",
			"lines":["03:17. The phone rang just like Josh said it would.","I let Lea's call ring once. I still think about it. I'll ask Josh tomorrow."]
		}])
	if number == 2:
		night.personal_goal = "Check whether Josh remembers the same shift."
		night.chapter_steps.assign([{
			"id":&"mike_checked_contradiction","location":&"board","after_event":main.event_id,
			"wait":"Keep the shop running and listen for the local broadcast.",
			"prompt":"Record the contradiction in the shift notes","speaker":"Mike",
			"lines":["Josh left the key by the till tonight. Last night it was on the hook.","He sounded certain. So did the voice on the radio. I'll check the next delivery against what I can actually see."]
		}])
	if number == 3:
		night.required_story.append(&"night_3_store_parcel")
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
		night.personal_goal = "Check the damage and ask Josh what he remembers about Lea."
		night.chapter_steps.assign([{
			"id":&"josh_confessed","location":&"board","after_event":parcel.event_id,
			"wait":"Return to the staff side of the till, then check the stockroom.",
			"prompt":"Talk to Josh at the staff notes","speaker":"Josh","actor":true,
			"lines":["I told you Lea never reached me. She did, Mike.","I said you were on your way. I hadn't spoken to you. I thought she'd wait if I sounded sure.","I don't know why she left. I should have told you what I said."]
		}])
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
		night.personal_goal = "Take the new road to the depot and find out who uses it."
		night.chapter_steps.assign([{
			"id":&"heard_lea_at_depot","location":&"depot","after_task":&"depot",
			"wait":"Take the access road and check in with the depot clerk.",
			"prompt":"Take the call at the depot desk","speaker":"Lea · depot phone",
			"lines":["Mike? Is that you? Did I leave my spare key there? I need it for the early run.","You sound exactly like you did the last time you forgot to pick me up.","I'll be at Station 14 tomorrow. Can you check the back door for me?"]
		}])
	if number == 5:
		night.title = "Night 5 — Road works"
		night.briefing = "Road works beside the station. Deliveries are still scheduled as normal."
		night.world_states.append(&"construction")
		main.text = "Radio: ‘Road works begin today on the new Redwater access road.’"
		main.effect = &"radio_interrupt"
		main.at_checkout = false
		main.required_flag = &"construction_read"
		night.personal_goal = "Find out why the road to Lea is closed again."
		night.chapter_steps.assign([{
			"id":&"entered_redwater","location":&"route","after_event":main.event_id,"after_work":true,
			"wait":"Read the construction notice and finish the shift tasks before leaving.",
			"prompt":"Follow the Redwater route","speaker":"Mike",
			"lines":["I drove this road yesterday. The sign says it's only being built now.","Lea said she'd wait at Station 14. I can see its light from here."]
		}])
	if number == 6:
		night.customer_profiles.assign([
			{"id":&"regular_driver","color":Color("b0a079"),"greeting":"Evening, Mike. You saved me a trip again."},
			{"id":&"redwater_courier","color":Color("8d748d"),"greeting":"Last delivery in Redwater tonight. Just something for the road."}
		])
		night.title = "Night 6 — Redwater"
		night.briefing = "Redwater Service. The rota has your name on every previous week."
		night.reality = &"redwater"
		night.world_states.append(&"redwater")
		night.handover = PackedStringArray(["Josh: Morning, Mike. Same routine as always?","Mike: Have you heard of Redwood? Or anything about 03:17?","Josh: Redwood? No. Is that another station? You've worked here longer than I have.","Josh: I'll leave the key by the till. Like I always do."])
		main.text = ""
		main.show_caption = false
		main.effect = &"reality_overlap"
		main.required_flag = &"met_lea"
		main.at_checkout = false
		night.personal_goal = "Speak to Lea, then find the way back to Josh."
		night.chapter_steps.assign([{
			"id":&"met_lea","location":&"board","prompt":"Talk to Lea at the staff notes","speaker":"Lea","actor":true,
			"lines":["I came for the key. You look like you haven't slept.","Mike: That night, I saw your call and let it ring. I've wanted to say I'm sorry for years.","Lea: I waited for you to say that the next morning. I went on with my life, Mike. I'm glad you said it now."]
		},{
			"id":&"returned_redwood","location":&"route","after_event":main.event_id,"after_work":true,
			"wait":"Finish the shift tasks and wait for the overlap to reveal the route.",
			"prompt":"Confirm the way back to Josh","speaker":"Mike",
			"lines":["Josh, don't move yet. I'm looking for the marked post on your side.","There it is. I can see you now. I'm here."]
		}])
	return night
