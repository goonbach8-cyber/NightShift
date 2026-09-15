extends Node
signal triggered(event: Resource)
var definitions: Array[Resource] = []
var history: Dictionary = {}
var flags: Dictionary = {}
var attempted: Dictionary = {}
var rng := RandomNumberGenerator.new()
var minimum_interval: float = 0
var last_trigger_seconds: float = -INF
var occupied_areas: Dictionary = {}

func setup(events: Array[Resource], experienced: Dictionary, story_flags: Dictionary) -> void:
	definitions = events
	history = experienced
	flags = story_flags
	attempted.clear()
	last_trigger_seconds = -INF
	rng.randomize()

func set_area(id: StringName, occupied: bool) -> void:
	if occupied: occupied_areas[id] = true
	else: occupied_areas.erase(id)

func advance(seconds: float, sales: int, tasks: Dictionary = {}) -> void:
	if seconds-last_trigger_seconds < minimum_interval: return
	for event in definitions:
		if attempted.has(event.event_id) or history.has(event.event_id): continue
		if seconds < event.after_seconds or sales < event.after_sales: continue
		if event.required_flag != &"" and not flags.get(event.required_flag,false): continue
		if event.required_task != &"" and not tasks.get(event.required_task,false): continue
		if event.required_event != &"" and not history.get(event.required_event,false): continue
		if event.required_area != &"" and not occupied_areas.has(event.required_area): continue
		attempted[event.event_id] = true
		if event.main_event or rng.randf() < event.probability:
			history[event.event_id] = true
			flags[event.event_id] = true
			last_trigger_seconds = seconds
			triggered.emit(event)
			# A routine frame must not launch several unrelated effects together.
			return
