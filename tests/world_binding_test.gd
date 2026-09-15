extends "res://tests/campaign_test.gd"

func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	await create_timer(0.5).timeout
	loop.customer_count = 0
	world._on_used(&"start")
	while loop.preparing: await process_frame
	for id in loop.inventory.stocks:
		var stock: Resource = loop.inventory.stocks[id]
		var slots: Array = world.get_node("Station").restock_items if id == &"water" else layout.displays[id].slots
		for amount in [stock.capacity,2,0,stock.capacity]:
			stock.shelf_units = amount
			stock.changed.emit()
			var visible := 0
			for slot in slots:
				if slot.visible: visible += 1
			check(visible == amount,"%s stock %d controls exact visible count" % [id,amount])
			await walk(layout.product_points[id].global_position)
			await capture("%s-stock-%d" % [id,amount])
		for other in loop.inventory.stocks:
			if id == other: continue
			stock.shelf_units = 0
			loop.inventory.stocks[other].carried_units = 1
			check(not loop.inventory.restock(id) and stock.shelf_units == 0,"Reject %s load at %s" % [other,id])
			await use()
			check(world.message.text.contains("carrying") and stock.shelf_units == 0,"Wrong-product interaction explains mismatch at %s" % id)
			loop.inventory.stocks[other].carried_units = 0
		stock.carried_units = 1
		check(loop.inventory.restock(id) and stock.shelf_units == 1,"Matching load accepted at %s" % id)
	for first in layout.product_points:
		for second in layout.product_points:
			if first != second:
				check(layout.product_points[first].global_position.distance_to(layout.product_points[second].global_position)>2,"Product approaches separate: %s/%s" % [first,second])
	await walk(layout.operator_point.global_position)
	await key(KEY_T)
	check(not world.radio.enabled,"Radio cannot be operated remotely")
	await walk(layout.radio_point.get_node("Approach").global_position)
	check(player.interaction_target == layout.radio_point,"Physical radio selects its own prompt")
	await use()
	check(world.radio.enabled,"E operates physical radio")
	await key(KEY_Y)
	check(world.radio.track_index == 1,"Track changes at radio")
	await capture("physical-radio")
	await finish()
