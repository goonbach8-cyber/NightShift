extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var receiving = world.delivery_check
	for night in [3,5]:
		loop.career_shifts = night-1
		loop.delivery_ready = true
		world.layout.delivery.available = true
		world.layout.delivery_visual.show()
		check(receiving.begin(),"Night %d opens delivery inspection" % night)
		var target: StringName = &"chips" if night == 3 else &"energy"
		check(receiving.actual_manifest[target] != loop.delivery_manifest[target],"Night %d carton differs from manifest" % night)
		for index in receiving.order.size():
			receiving.selected = index
			var id: StringName = receiving.order[index]
			var match: bool = receiving.actual_manifest[id] == loop.delivery_manifest[id]
			receiving._verify_selected(not match)
			check(not receiving.verified.has(id),"Incorrect assessment is rejected for %s" % id)
			receiving._verify_selected(match)
		check(receiving.discrepancies.size() == 1,"Exactly one discrepancy is logged")
		var actual: Dictionary = receiving.actual_manifest.duplicate()
		receiving._accept()
		check(loop.delivery_carried and loop.carried_delivery_manifest == actual,"Carried delivery uses real quantities")
		var before: Dictionary = {}
		for id in actual: before[id] = loop.inventory.stocks[id].warehouse_units
		loop.interact(&"supply",world.player)
		for id in actual:
			check(loop.inventory.stocks[id].warehouse_units == before[id]+actual[id],"Warehouse gets actual %s quantity" % id)
		check(loop.carried_delivery_manifest.is_empty() and loop.story_flags.get(StringName("delivery_discrepancy_night_%d" % night),false),"Manifest clears and discrepancy flag persists")
		if night == 3:
			world.queue_free()
			await create_timer(0.2).timeout
			await setup()
			receiving = world.delivery_check
	await finish()
