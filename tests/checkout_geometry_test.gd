extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var game = world.checkout_minigame
	for id in [&"water",&"energy",&"chips"]:
		var product: Node3D = game._product_visual(id)
		var barcode: Node3D = product.get_node("Barcode")
		check(barcode.get_child_count() == 5,"Only ink stripes remain on "+String(id))
		for stripe in barcode.get_children():
			# Mesh dimensions are stored as float32; allow only rounding error.
			check(stripe is MeshInstance3D and stripe.mesh.size.x <= 0.00401 and stripe.mesh.size.y <= 0.03501 and stripe.mesh.size.z <= 0.0011,"Barcode ink is thin, bounded and has no white backing block")
			check(absf(stripe.position.x)+stripe.mesh.size.x/2 < 0.03,"Barcode width fits the narrow product face")
		product.free()
	var positions: Array[Vector3] = []
	for i in 4:
		var at: Vector3 = game._placed_position(i)
		check(at.z >= 0.5,"Scanned merchandise stays away from card/cash controls")
		for other in positions: check(at.distance_to(other) >= 0.18,"Scanned products have distinct placement slots")
		positions.append(at)
	game._enter_printer_jam()
	check(game.receipt_root.position.y >= 1.10,"Jammed paper sits above the counter rather than intersecting its interior")
	await finish()
