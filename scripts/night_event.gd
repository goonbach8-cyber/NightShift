extends Resource
@export var event_id: StringName
@export var main_event: bool = false
@export var after_seconds: float = 30
@export var after_sales: int = 0
@export_range(0,1) var probability: float = 1
@export var effect: StringName
@export var text: String
@export var required_flag: StringName
