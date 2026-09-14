extends Node
var lights: Array[Light3D] = []
var energies: Array[float] = []
var remaining: float = 0

func light_dip() -> void:
	if remaining > 0: return
	for node in get_tree().get_nodes_in_group("night_event_light"):
		if node is Light3D:
			lights.append(node)
			energies.append(node.light_energy)
	remaining = 2.5

func _process(delta: float) -> void:
	if remaining <= 0: return
	remaining = maxf(0,remaining-delta)
	var factor := 0.55 + 0.45*absf(remaining-1.25)/1.25
	for i in lights.size():
		if is_instance_valid(lights[i]): lights[i].light_energy = energies[i]*factor
	if remaining == 0: restore()

func restore() -> void:
	for i in lights.size():
		if is_instance_valid(lights[i]): lights[i].light_energy = energies[i]
	lights.clear()
	energies.clear()

func _exit_tree() -> void:
	restore()
