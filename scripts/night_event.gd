extends Resource
@export var event_id: StringName
@export var main_event: bool = false
@export var after_seconds: float = 30
@export var after_sales: int = 0
@export_range(0,1) var probability: float = 1
@export var effect: StringName
@export var text: String
@export var required_flag: StringName
@export var required_task: StringName
@export var required_event: StringName
@export var required_area: StringName
@export var at_checkout: bool = true
@export var effect_target: StringName
