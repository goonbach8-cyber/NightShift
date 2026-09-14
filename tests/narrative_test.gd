extends SceneTree
var failures := 0
var fired: Array[StringName] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func run() -> void:
	var world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	var loop = world.gameplay
	var main = load("res://scripts/night_event.gd").new()
	main.event_id = &"test_main"
	main.main_event = true
	main.probability = 0
	main.after_seconds = 2
	main.after_sales = 1
	var optional = load("res://scripts/night_event.gd").new()
	optional.event_id = &"test_optional"
	optional.after_seconds = 0
	optional.probability = 0
	var gated = load("res://scripts/night_event.gd").new()
	gated.event_id = &"test_choice"
	gated.after_seconds = 0
	gated.required_flag = &"asked"
	var definitions: Array[Resource] = [main,optional,gated]
	loop.events.setup(definitions,loop.event_history,loop.story_flags)
	loop.events.triggered.connect(func(event): fired.append(event.event_id))
	loop.events.advance(1,1)
	check(fired.is_empty(),"Main event waits for time; optional zero-probability event does not fire")
	loop.events.advance(3,0)
	check(fired.is_empty(),"Main event also waits for sales condition")
	loop.events.advance(3,1)
	loop.events.advance(30,9)
	check(fired == [&"test_main"],"Main event guaranteed once regardless of probability")
	var answers: Array[Dictionary] = [{"text":"Ask","flag":&"asked","reply":"Perhaps I was mistaken."}]
	check(loop.dialogue.begin(42,PackedStringArray(["Hello.","Do you remember?"]),answers,loop.story_flags),"Dialogue starts")
	loop.dialogue.choose(0)
	check(not loop.story_flags.has(&"asked"),"Choice unavailable before final dialogue line")
	loop.dialogue.advance()
	loop.dialogue.choose(4)
	check(not loop.story_flags.has(&"asked"),"Invalid response index does not change flags")
	loop.dialogue.choose(0)
	check(loop.story_flags.get(&"asked",false) and loop.dialogue.display_text().contains("mistaken"),"Response stores flag and displays reply")
	loop.dialogue.advance()
	check(not loop.dialogue.active and loop.dialogue.owner_id == 0,"Dialogue releases speaker after closing")
	loop.events.advance(4,1)
	check(fired.has(&"test_choice"),"Dialogue flag unlocks conditional event")
	check(not get_nodes_in_group("night_event_light").is_empty(),"Map binds actual lights through event group")
	var lamp: Light3D = get_nodes_in_group("night_event_light")[0]
	var energy := lamp.light_energy
	world.effects.light_dip()
	await create_timer(1.2).timeout
	check(lamp.light_energy < energy,"Subtle event changes real light")
	await create_timer(1.5).timeout
	check(is_equal_approx(lamp.light_energy,energy),"Light event restores original energy")
	world.radio.toggle()
	check(world.radio.playing and world.radio.enabled,"Radio plays original placeholder audio")
	var first: AudioStream = world.radio.stream
	world.radio.next_track()
	check(world.radio.stream != first and world.radio.playing,"Next track preserves radio state")
	world.radio.change_volume(100)
	check(world.radio.level_db == -15,"Radio volume has upper limit")
	world.radio.interrupt_briefly()
	await create_timer(0.1).timeout
	check(world.radio.volume_db == -80 and world.radio.enabled,"Mystery interruption silences without switching radio off")
	world.muted = true
	await create_timer(2.6).timeout
	check(world.radio.volume_db == -80,"Event cannot override global mute")
	world.muted = false
	await create_timer(0.1).timeout
	check(world.radio.volume_db == world.radio.level_db,"Radio restores player volume after interruption")
	world.radio.toggle()
	check(not world.radio.playing,"Radio off stops playback")
	first = null
	world.queue_free()
	await create_timer(0.3).timeout
	print("NARRATIVE TESTS: %d failure(s)" % failures)
	quit(failures)
