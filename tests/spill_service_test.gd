extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var spill = world.spill_service
	loop.career_shifts = 1
	spill._spawn_spill()
	check(spill.spill_pending and is_instance_valid(spill.spill_point),"Spill creates physical cleanup point")
	check(not spill.begin_cleanup(),"Cannot clean without mop")
	world._on_used(&"cleaning_kit")
	check(spill.kit_carried,"Cleaning kit is carried")
	world._on_used(&"spill_cleanup")
	check(spill.active and world.player.controls_locked,"Cleanup begins with movement locked")
	var first = spill.stain_visuals[0]
	for i in spill.REQUIRED_PASSES:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_D if i%2 == 0 else KEY_A
		event.pressed = true
		spill._input(event)
		spill._process(1.1)
		event.pressed = false
		spill._input(event)
		if i == 0: check(first.scale.x < 1,"First sweep visibly shrinks puddle")
	await create_timer(0.55).timeout
	check(not spill.spill_pending and spill.return_required and not spill.active,"Required sweeps finish cleanup")
	check(not world.player.controls_locked,"Cleanup releases controls")
	world._on_used(&"cleaning_kit")
	check(spill.completed and not spill.return_required and not spill.kit_carried,"Returning mop resets service")
	check(loop.story_flags.get(&"spill_cleaned_night_2",false),"Cleanup completion flag is stored")
	await finish()
