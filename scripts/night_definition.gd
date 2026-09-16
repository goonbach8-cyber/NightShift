extends Resource
@export var title: String = "Night 1"
@export_multiline var briefing: String = "Read the staff shift notes before starting."
@export var reality: StringName = &"redwood"
@export var world_states: Array[StringName] = []
@export var handover: PackedStringArray = []
@export var required_story: Array[StringName] = []
@export var customers: int = 6
@export var spawn_seconds: float = 8
@export var orders: Array[Dictionary] = []
@export var customer_profiles: Array[Dictionary] = []
@export var delivery: Dictionary = {}
@export var required_tasks: Array[StringName] = [&"cooler",&"restock",&"delivery"]
@export var events: Array[Resource] = []
@export_range(0,120) var event_spacing_seconds: float = 35
