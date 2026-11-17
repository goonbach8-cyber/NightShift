extends "res://tests/service_runtime_base.gd"
func run() -> void:
	await setup()
	var actor = customer()
	actor.attention_target = world.layout.checkout
	actor.state = &"browsing"
	actor._physics_process(0.1)
	check(actor.right_arm.rotation.x < -0.1,"Browsing visibly reaches toward the shelf")
	actor.state = &"checkout"
	actor._physics_process(0.1)
	check(actor.basket_visual.position.y > 0.50,"Customer brings the basket forward when being served")
	actor.react(&"payment_failed")
	actor._physics_process(0.1)
	check(absf(actor.visual_root.rotation.z) > 0.01,"Payment failure has a visible reaction without opening dialogue")
	actor.react(&"thanks")
	actor._physics_process(0.1)
	check(actor.visual_root.rotation.x < 0 and actor.reaction == &"thanks","Success/assistance acknowledgment uses a distinct gesture")
	actor._physics_process(1)
	check(is_zero_approx(actor.visual_root.rotation.x) and is_zero_approx(actor.visual_root.rotation.z),"Reactions settle without delayed callbacks")
	await finish()
