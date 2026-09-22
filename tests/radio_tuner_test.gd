extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var tuner = world.radio_tuner
	var radio = world.radio
	tuner._process(0.01)
	for i in 9:
		radio.next_track()
		check(not is_equal_approx(radio.tuned_frequency,101.7),"Early-night next track excludes unlisted station")
	radio.set_frequency(120)
	check(is_equal_approx(radio.tuned_frequency,108),"Frequency upper bound")
	radio.set_frequency(70)
	check(is_equal_approx(radio.tuned_frequency,88),"Frequency lower bound")
	for frequency in [91.7,96.3,103.1]:
		radio.set_frequency(frequency)
		check(radio.signal_strength > 0.9,"Normal station has clear signal")
	check(tuner.begin(),"Radio tuner opens at station")
	key(tuner,KEY_RIGHT)
	check(is_equal_approx(radio.tuned_frequency,103.2),"Fine tuning uses 0.1 MHz steps")
	key(tuner,KEY_DOWN)
	check(is_equal_approx(radio.tuned_frequency,102.2),"Coarse tuning uses 1 MHz steps")
	var enabled: bool = radio.enabled
	key(tuner,KEY_T)
	check(radio.enabled != enabled,"T toggles radio power")
	key(tuner,KEY_T)
	tuner.close()
	loop.career_shifts = 1
	radio.set_frequency(96.3)
	tuner._trigger_drift()
	check(tuner.drift_pending and not is_equal_approx(radio.tuned_frequency,96.3),"Drift moves away from previous frequency")
	tuner.begin()
	key(tuner,KEY_E)
	check(tuner.drift_pending,"Wrong frequency does not complete drift")
	tuner.begin()
	radio.set_frequency(96.3)
	key(tuner,KEY_E)
	check(not tuner.drift_pending and tuner.drift_done,"Original frequency resolves drift")
	loop.career_shifts = 3
	tuner._process(0.01)
	radio.set_frequency(101.7)
	radio.enabled = true
	tuner.begin()
	tuner._process(1.3)
	check(radio.station_name() == "UNLISTED" and loop.story_flags.get(&"found_unlisted_radio",false),"Later-night hidden station records discovery")
	tuner.close()
	check(not world.player.controls_locked,"Radio releases player controls")
	await finish()
