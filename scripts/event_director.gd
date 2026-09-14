extends Node
signal triggered(event: Resource)
var definitions: Array[Resource] = []
var history: Dictionary = {}
var flags: Dictionary = {}
var attempted: Dictionary = {}
var rng := RandomNumberGenerator.new()

func setup(events: Array[Resource], experienced: Dictionary, story_flags: Dictionary) -> void:
	definitions = events
	history = experienced
	flags = story_flags
	attempted.clear()
	rng.randomize()

func advance(seconds: float, sales: int) -> void:
	for event in definitions:
		if attempted.has(event.event_id) or history.has(event.event_id): continue
		if seconds < event.after_seconds or sales < event.after_sales: continue
		if event.required_flag != &"" and not flags.get(event.required_flag,false): continue
		attempted[event.event_id] = true
		if event.main_event or rng.randf() < event.probability:
			history[event.event_id] = true
			flags[event.event_id] = true
			triggered.emit(event)
