extends "res://tests/campaign_test.gd"
func run() -> void:
	world = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	bind_world()
	loop.inventory.initialize_shelves()
	loop.inventory.take_crate(&"water")
	var energy: Resource = loop.inventory.stocks[&"energy"]
	var before: int = energy.shelf_units
	loop.interact(&"cooler",player)
	check(not loop.tasks.has(&"cooler"),"Wrong-product attempt cannot silently complete refrigeration task")
	check(energy.shelf_units == before and loop.inventory.carried_product() == &"water","Wrong load changes neither shelf nor carried stock")
	loop.inventory.restock(&"water")
	loop.inventory.take_crate(&"energy")
	var carried: int = energy.carried_units
	loop.interact(&"cooler",player)
	check(world.message.text.contains("Restocked %d" % carried) and world.message.text.contains("%d/%d on display" % [energy.shelf_units,energy.capacity]),"Restock feedback names the transferred quantity and resulting display stock")
	check(energy.shelf_units > before and loop.inventory.carried_product() == &"","Correct load restocks the cooler")
	check(not loop.tasks.has(&"cooler"),"Restocking does not pretend the temperature was checked")
	check(loop.interaction_prompt(layout.product_nodes[&"energy"],player).begins_with("Check refrigeration"),"Empty-handed follow-up offers the real temperature check")
	loop.interact(&"cooler",player)
	check(loop.tasks.has(&"cooler"),"Explicit inspection completes refrigeration task")
	var count: int = loop.tasks.size()
	loop.interact(&"cooler",player)
	check(loop.tasks.size() == count,"Repeated inspection cannot duplicate task completion")
	await finish()
