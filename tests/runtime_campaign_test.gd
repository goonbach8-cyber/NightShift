extends "res://tests/campaign_test.gd"
## The campaign safety net with the real focused checkout/delivery services.
## All input is injected inside Godot; no OS input or desktop window is used.

func use() -> void:
	if is_instance_valid(player.interaction_target) and player.interaction_target.action_id == &"delivery" and loop.delivery_ready:
		check(world.delivery_check.begin(),"Campaign opens receiving clipboard")
		var delivery = world.delivery_check
		for i in delivery.order.size():
			var id: StringName = delivery.order[delivery.selected]
			await key(KEY_E if delivery.actual_manifest[id] == loop.delivery_manifest[id] else KEY_R)
			await key(KEY_RIGHT)
		await key(KEY_ENTER)
		return
	await super.use()
