extends Node
## Test-fixture only: logs events received by Godot, never injects keyboard input.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("INPUT AUDIT: window focused=",get_window().has_focus())
	get_window().focus_entered.connect(func(): print("INPUT AUDIT: focus entered"))
	get_window().focus_exited.connect(func(): print("INPUT AUDIT: focus exited"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		print("INPUT AUDIT: key=",event.keycode," physical=",event.physical_keycode," device=",event.device," pressed=",event.pressed," E-match=",event.is_action_pressed("interact")," focused=",get_window().has_focus())
