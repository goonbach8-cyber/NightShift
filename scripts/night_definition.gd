extends Resource
@export var title: String = "Night 1"
@export var customers: int = 6
@export var spawn_seconds: float = 8
@export var orders: Array[Dictionary] = []
@export var delivery: Dictionary = {}
@export var required_tasks: Array[StringName] = [&"cooler",&"restock",&"delivery"]
@export var events: Array[Resource] = []
@export_range(0,120) var event_spacing_seconds: float = 35
