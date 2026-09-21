extends Node
signal changed
signal notice(text: String)
const TASK_LABELS := {&"cooler":"Check refrigeration", &"restock":"Refill a display", &"delivery":"Store delivery", &"service":"Empty waste bin", &"wc":"Check WC", &"depot":"Collect depot order"}
const CUSTOMER = preload("res://scripts/customer.gd")
var layout: Node
var navigation: Node
var inventory: Resource
var stock: Resource # Water alias retained for focused legacy tests.
var customers: Array[CharacterBody3D] = []
var queue: Array[CharacterBody3D] = []
var active: bool = false
var preparing: bool = false
var elapsed: float = 0
var spawn_clock: float = 0
var retry_clock: float = 0
var spawned: int = 0
var served: int = 0
var departed: int = 0
var lost_sales: int = 0
var sold_units: int = 0
var revenue_rappen: int = 0
var customer_count: int = 6
var spawn_interval: float = 8
var tasks: Dictionary = {}
var delivery_ready: bool = false
var delivery_carried: bool = false
var supply_selection: int = 0
var delivery_manifest: Dictionary = {&"water": 6, &"energy": 4, &"chips": 3}
# Demo data; the inventory and customer code do not special-case these products.
var order_patterns: Array[Dictionary] = [{&"water":1},{&"energy":1},{&"chips":1,&"water":1},{&"energy":1,&"chips":1},{&"water":2},{&"energy":1,&"water":1,&"chips":1}]
var completed_orders: Array[Dictionary] = []
var career_revenue: int = 0
var career_shifts: int = 0
var use_loaded_stock: bool = false
var definition: Resource
var required_tasks: Array[StringName] = [&"cooler",&"restock",&"delivery"]
var story_flags: Dictionary = {}
var event_history: Dictionary = {}
var events: Node
var dialogue: Node
var pending_dialogue_seen: StringName
var quick_checkout: bool = false
var scanned_owner: int = 0
var scanned_units: int = 0

func setup(bindings: Node) -> void:
	layout = bindings
	inventory = layout.inventory
	stock = inventory.stocks[&"water"]
	navigation = Node.new()
	navigation.set_script(preload("res://scripts/shop_navigation.gd"))
	add_child(navigation)
	events = Node.new()
	events.set_script(preload("res://scripts/event_director.gd"))
	add_child(events)
	for area in layout.story_areas: area.director = events
	dialogue = Node.new()
	dialogue.set_script(preload("res://scripts/dialogue_session.gd"))
	add_child(dialogue)
	dialogue.changed.connect(_dialogue_progress_changed)
	configure_night(preload("res://scripts/night_catalog.gd").for_night(1))
	inventory.changed.connect(_inventory_changed)
	update_supply_prompt()

func configure_night(config: Resource) -> void:
	definition = config
	customer_count = config.customers
	spawn_interval = config.spawn_seconds
	order_patterns.assign(config.orders)
	delivery_manifest = config.delivery.duplicate()
	required_tasks.assign(config.required_tasks)
	layout.wc_point.available = required_tasks.has(&"wc")
	layout.wc_mark.visible = required_tasks.has(&"wc") and not tasks.has(&"wc")
	if is_instance_valid(layout.service_point):
		layout.service_point.available = required_tasks.has(&"service") and not tasks.has(&"service")
	if layout.has_method("set_service_done"):
		layout.set_service_done(not required_tasks.has(&"service") or tasks.has(&"service"))

func _inventory_changed() -> void:
	update_supply_prompt()
	changed.emit()

func start() -> void:
	if active or preparing:
		return
	preparing = true
	await get_tree().physics_frame
	navigation.rebuild(get_parent(),layout.doors)
	if not use_loaded_stock:
		inventory.initialize_shelves()
	events.setup(definition.events,event_history,story_flags)
	events.minimum_interval = definition.event_spacing_seconds
	active = true
	preparing = false
	spawn_clock = spawn_interval
	notice.emit("Shift started. Serve customers and check the task list.")
	changed.emit()

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	events.advance(elapsed,served,tasks)
	spawn_clock += delta
	retry_clock += delta
	if spawn_clock >= spawn_interval and spawned < customer_count and customers.size() < layout.queue_points.size():
		var clear := true
		for customer in customers:
			if customer.global_position.distance_to(layout.spawn_point.global_position) < 1.0:
				clear = false
		if clear:
			spawn_customer()
			spawn_clock = 0
	if elapsed >= 18 and not delivery_ready and not delivery_carried and not tasks.has(&"delivery"):
		delivery_ready = true
		layout.delivery.available = true
		layout.delivery_visual.show()
		notice.emit("Delivery in the yard: "+inventory.basket_text(delivery_manifest))
		changed.emit()
	for customer in customers.duplicate():
		# A reachable approach marker has a small browsing radius, avoiding a pile-up
		# when another shopper is standing directly at the same shelf.
		if customer.state == &"shopping" and customer.global_position.distance_to(layout.product_points[customer.current_product].global_position) < 0.8:
			begin_browsing(customer)
		if customer.state == &"browsing":
			customer.browse_remaining -= delta
			if customer.browse_remaining <= 0: select_product(customer)
		if (customer.state == &"stock_wait" or customer.state == &"queued") and dialogue.owner_id != customer.get_instance_id():
			customer.wait_seconds += delta
			if customer.wait_seconds >= customer.patience:
				abandon_customer(customer)
	if retry_clock >= 1:
		retry_clock = 0
		for customer in customers.duplicate():
			if customer.state == &"stock_wait":
				select_product(customer)
		changed.emit()

func spawn_customer() -> void:
	var customer := CharacterBody3D.new()
	customer.set_script(CUSTOMER)
	customer.name = "Customer%d" % (spawned+1)
	customer.navigation = navigation
	customer.entrance = layout.entrance
	customer.arrival_origin = layout.spawn_point
	customer.entry_wait_point = layout.entry_wait_point
	customer.doors = layout.doors
	customer.order = order_patterns[spawned % order_patterns.size()].duplicate()
	customer.remaining_products = customer.order.keys()
	customer.move_speed = 1.65 + (spawned % 3)*0.15
	customer.patience = 240 + (spawned % 3)*30
	if not definition.customer_profiles.is_empty():
		var profile: Dictionary = definition.customer_profiles[spawned % definition.customer_profiles.size()]
		customer.profile_id = profile.get("id",&"regular")
		customer.greeting = profile.get("greeting","")
		customer.clothing_color = profile.get("color",Color("b0a079"))
	# Browsing needs to read as choosing a product, not as a navigation hiccup.
	customer.browse_seconds = 1.65 + float(spawned % 4)*0.45
	get_parent().add_child(customer)
	customer.global_position = layout.spawn_point.global_position + Vector3.UP*0.05
	customer.arrived.connect(customer_arrived)
	var owner_id := customer.get_instance_id()
	customer.tree_exiting.connect(func(): customer_removed(owner_id))
	customers.append(customer)
	spawned += 1
	visit_next_product(customer)
	changed.emit()

func visit_next_product(customer: CharacterBody3D) -> void:
	if customer.remaining_products.is_empty():
		customer.has_product = true
		customer.state = &"queued"
		customer.wait_seconds = 0
		var quantity := 0
		for amount in customer.order.values(): quantity += int(amount)
		customer.status_text = "%d Artikel" % quantity
		if not queue.has(customer):
			queue.append(customer)
		update_queue()
		return
	customer.current_product = customer.remaining_products[0]
	customer.state = &"shopping"
	customer.status_text = "Sucht "+inventory.products[customer.current_product].display_name
	customer.go_to(layout.product_points[customer.current_product])

func customer_arrived(customer: CharacterBody3D) -> void:
	if customer.state == &"shopping":
		begin_browsing(customer)
	elif customer.state == &"leaving":
		customers.erase(customer)
		departed += 1
		customer.queue_free()
		changed.emit()

func begin_browsing(customer: CharacterBody3D) -> void:
	if customer.state != &"shopping": return
	customer.state = &"browsing"
	customer.walking = false
	customer.velocity = Vector3.ZERO
	customer.browse_remaining = customer.browse_seconds
	customer.status_text = "Choosing "+inventory.products[customer.current_product].display_name

func select_product(customer: CharacterBody3D) -> void:
	if customer.state != &"shopping" and customer.state != &"browsing" and customer.state != &"stock_wait":
		return
	var id: StringName = customer.current_product
	if inventory.reserve(customer.get_instance_id(),id,customer.order[id]):
		if customer.has_method("add_basket_item"):
			customer.add_basket_item(id,int(customer.order[id]))
		customer.remaining_products.pop_front()
		customer.wait_seconds = 0
		visit_next_product(customer)
	else:
		customer.walking = false
		customer.state = &"stock_wait"
		customer.status_text = "Wartet: "+inventory.products[id].display_name
	changed.emit()

func abandon_customer(customer: CharacterBody3D) -> void:
	if customer.paid or customer.abandoned:
		return
	inventory.release(customer.get_instance_id())
	if customer.has_method("clear_basket"):
		customer.clear_basket()
	if scanned_owner == customer.get_instance_id():
		scanned_owner = 0
		scanned_units = 0
		if layout.has_method("set_checkout_product"):
			layout.set_checkout_product(&"",false)
	if dialogue.owner_id == customer.get_instance_id(): dialogue.close()
	queue.erase(customer)
	customer.abandoned = true
	lost_sales += 1
	customer.state = &"leaving"
	customer.status_text = "Zu lange gewartet"
	customer.go_to(layout.spawn_point)
	update_queue()
	notice.emit("A customer left unserved. Their reserved stock is available again.")
	changed.emit()

func customer_removed(owner_id: int) -> void:
	# Also runs if an NPC is removed externally, not only through normal checkout.
	inventory.release(owner_id)
	if scanned_owner == owner_id:
		scanned_owner = 0
		scanned_units = 0
		if layout.has_method("set_checkout_product"):
			layout.set_checkout_product(&"",false)
	if dialogue.owner_id == owner_id: dialogue.close()
	if not is_inside_tree() or get_parent().is_queued_for_deletion():
		return
	for customer in customers.duplicate():
		if customer.get_instance_id() == owner_id:
			customers.erase(customer)
			queue.erase(customer)
			departed += 1
			if not customer.paid and not customer.abandoned:
				lost_sales += 1
	update_queue()
	changed.emit()

func update_queue() -> void:
	for i in queue.size():
		var point: Marker3D = layout.queue_points[i]
		if queue[i].target != point or queue[i].global_position.distance_to(point.global_position) > 0.5:
			queue[i].go_to(point)

func checkout_details() -> Dictionary:
	if queue.is_empty(): return {}
	var customer := queue[0]
	var items: Array[StringName] = []
	for id in customer.order:
		for unit in int(customer.order[id]): items.append(id)
	var count := mini(scanned_units,items.size()) if scanned_owner == customer.get_instance_id() else 0
	var subtotal := 0
	var total := 0
	for i in items.size():
		var price: int = inventory.products[items[i]].line_total(1)
		total += price
		if i < count: subtotal += price
	return {"scanned":count,"count":items.size(),"remaining":items.size()-count,"subtotal":subtotal,"total":total,"last":inventory.products[items[count-1]].display_name if count > 0 else "","next":inventory.products[items[count]].display_name if count < items.size() else "","last_id":items[count-1] if count > 0 else &"","next_id":items[count] if count < items.size() else &""}

func checkout_text() -> String:
	var detail := checkout_details()
	if detail.is_empty(): return "Checkout ready"
	var heading: String = "%s scanned" % detail.last if detail.scanned > 0 else "Ready to scan"
	var action: String = "All items scanned · Accept payment" if detail.remaining == 0 else "Next: "+detail.next
	var amount_label := "Total" if detail.remaining == 0 else "Subtotal"
	return "%s\n%d / %d items · %d remaining\n%s: CHF %.2f\n%s" % [heading,detail.scanned,detail.count,detail.remaining,amount_label,float(detail.subtotal)/100,action]

func checkout_ready() -> bool:
	if queue.is_empty() or not is_instance_valid(queue[0]): return false
	var customer := queue[0]
	return not customer.walking and not customer.paid and customer.global_position.distance_to(layout.queue_points[0].global_position) <= 0.6

func checkout() -> bool:
	if not checkout_ready(): return false
	var customer := queue[0]
	if dialogue.active:
		notice.emit("Finish the conversation with Space or choose an answer.")
		return false
	if scanned_owner != customer.get_instance_id():
		scanned_owner = customer.get_instance_id()
		scanned_units = 0
	var total_units: int = checkout_details().count
	if not quick_checkout and scanned_units < total_units:
		scanned_units += 1
		var scanned := checkout_details()
		if layout.has_method("set_checkout_product"):
			layout.set_checkout_product(scanned.last_id,true)
		notice.emit("%s scanned · CHF %.2f" % [scanned.last,float(scanned.subtotal)/100])
		changed.emit()
		return true
	var receipt: Dictionary = inventory.commit(customer.get_instance_id())
	if receipt.is_empty():
		return false
	queue.pop_front()
	customer.paid = true
	customer.state = &"leaving"
	customer.status_text = "Thank you!"
	revenue_rappen += int(receipt.total)
	sold_units += int(receipt.units)
	served += 1
	completed_orders.append(receipt)
	scanned_owner = 0
	scanned_units = 0
	if layout.has_method("set_checkout_product"):
		layout.set_checkout_product(&"",false)
	customer.go_to(layout.spawn_point)
	update_queue()
	notice.emit("Payment accepted · %d items · CHF %.2f" % [receipt.units,float(receipt.total)/100])
	changed.emit()
	return true

func cycle_supply() -> void:
	supply_selection = (supply_selection+1) % inventory.products.size()
	update_supply_prompt()
	notice.emit("Selected stock: "+inventory.products[selected_product()].display_name)
	changed.emit()

func selected_product() -> StringName:
	return inventory.products.keys()[supply_selection]

func interaction_prompt(target: Node3D, player: Node3D) -> String:
	if target == layout.checkout:
		if not layout.at_operator(player): return "Checkout — use the staff side"
		if not checkout_ready(): return "Checkout — waiting for a customer"
		var details := checkout_details()
		if details.remaining == 0: return "Accept payment · CHF %.2f" % (float(details.total)/100)
		return "Scan %s" % details.next
	var carried: StringName = inventory.carried_product()
	for id in layout.product_nodes:
		if target != layout.product_nodes[id]: continue
		var item: Resource = inventory.stocks[id]
		var title: String = inventory.products[id].display_name
		var stock_text := "%s · %d/%d" % [title,item.shelf_units,item.capacity]
		if target.action_id == &"cooler" and carried == &"": return "Check refrigeration · "+stock_text
		if carried == id and item.shelf_units < item.capacity: return "Restock "+stock_text
		if item.shelf_units == item.capacity: return "Check "+stock_text+" · Full"
		if carried != &"": return "Check "+stock_text+" · Carrying "+inventory.products[carried].display_name
		return "Check "+stock_text+" · Stock from warehouse"
	if target == layout.warehouse.get_node("Supply"):
		if delivery_carried: return "Store delivery · "+inventory.basket_text(delivery_manifest)
		if carried != &"": return "Carrying %s · Refill its display first" % inventory.products[carried].display_name
		var selected: Resource = inventory.stocks[selected_product()]
		var title: String = inventory.products[selected_product()].display_name
		if selected.warehouse_units == 0: return "Check %s · Warehouse empty · [TAB] Select product" % title
		if selected.shelf_units == selected.capacity: return "Check %s · Display full · [TAB] Select product" % title
	if target == layout.delivery:
		if carried != &"": return "Delivery · Refill %s first" % inventory.products[carried].display_name
		return "Collect delivery · "+inventory.basket_text(delivery_manifest)
	return target.prompt

func update_supply_prompt() -> void:
	var id := selected_product()
	layout.warehouse.get_node("Supply").prompt = "Store delivery" if delivery_carried else "Collect %s (warehouse %d) — TAB select" % [inventory.products[id].display_name,inventory.stocks[id].warehouse_units]
	if layout.has_method("set_carry_state"):
		layout.set_carry_state(delivery_carried,inventory.carried_product())

func fill_shelf(id: StringName) -> void:
	var before: int = inventory.stocks[id].shelf_units
	if inventory.restock(id):
		tasks[&"restock"] = true
		var item: Resource = inventory.stocks[id]
		notice.emit("Restocked %d × %s · %d/%d on display." % [item.shelf_units-before,inventory.products[id].display_name,item.shelf_units,item.capacity])
	else:
		var carried: StringName = inventory.carried_product()
		if carried != &"" and carried != id:
			notice.emit("Wrong shelf · Carrying %s, needs %s." % [inventory.products[carried].display_name,inventory.products[id].display_name])
		elif inventory.stocks[id].shelf_units >= inventory.stocks[id].capacity:
			notice.emit("This display is already full.")
		else:
			notice.emit("Collect matching stock in the warehouse. [TAB] selects a product there.")

func interact(action: StringName, player: Node3D) -> void:
	if String(action).begins_with("stock_"):
		fill_shelf(StringName(String(action).trim_prefix("stock_")))
	else:
		match action:
			&"wc":
				if required_tasks.has(&"wc") and not tasks.has(&"wc"):
					tasks[&"wc"] = true
					layout.wc_mark.hide()
					layout.wc_point.available = false
					notice.emit("WC checked. Floor cleaned.")
			&"service":
				if not required_tasks.has(&"service") or tasks.has(&"service"):
					return
				tasks[&"service"] = true
				if is_instance_valid(layout.service_point):
					layout.service_point.available = false
				if layout.has_method("set_service_done"):
					layout.set_service_done(true)
				notice.emit("Waste bin emptied. Service check complete.")
			&"cooler":
				if inventory.carried_product() != &"":
					fill_shelf(&"energy")
				else:
					tasks[&"cooler"] = true
					notice.emit("Refrigeration checked: 4 °C.")
			&"shelf":
				fill_shelf(&"water")
			&"supply":
				if delivery_carried:
					if inventory.receive_delivery(&"shift_delivery",delivery_manifest):
						delivery_carried = false
						tasks[&"delivery"] = true
						notice.emit("Stored: "+inventory.basket_text(delivery_manifest))
				elif inventory.take_crate(selected_product()):
					notice.emit("Carrying stock: "+inventory.products[selected_product()].display_name)
				else:
					var carried: StringName = inventory.carried_product()
					if carried != &"": notice.emit("You are carrying %s. Refill its display first." % inventory.products[carried].display_name)
					elif inventory.stocks[selected_product()].warehouse_units == 0: notice.emit("No %s left in the warehouse." % inventory.products[selected_product()].display_name)
					else: notice.emit("The %s display is already full." % inventory.products[selected_product()].display_name)
			&"delivery":
				if delivery_ready and inventory.carried_product() == &"":
					delivery_ready = false
					delivery_carried = true
					layout.delivery.available = false
					layout.delivery_visual.hide()
					notice.emit("Carrying delivery. Bring it to warehouse supply.")
				else:
					notice.emit("First put carried stock in its matching display.")
			&"finish":
				if not layout.at_operator(player):
					notice.emit("Use checkout from the staff side.")
				elif not checkout() and not can_finish():
					notice.emit("No customer ready yet. Check your other tasks.")
	update_supply_prompt()
	changed.emit()

func can_finish() -> bool:
	return served+lost_sales == customer_count and departed == customer_count and required_tasks.all(func(id): return tasks.has(id)) and definition.required_story.all(func(id): return story_flags.get(StringName("presented_"+String(id)),false))

func talk() -> void:
	if not checkout_ready(): return
	var content: Dictionary = preload("res://scripts/dialogue_catalog.gd").for_context(event_history,story_flags,career_shifts+1)
	if content.get("routine",false) and not queue[0].greeting.is_empty():
		content.lines.insert(0,queue[0].greeting)
	if dialogue.begin(queue[0].get_instance_id(),content.lines,content.choices,story_flags) and content.has("seen_flag"):
		pending_dialogue_seen = content.seen_flag

func _dialogue_progress_changed() -> void:
	if dialogue.active or pending_dialogue_seen == &"": return
	if dialogue.completed: story_flags[pending_dialogue_seen] = true
	pending_dialogue_seen = &""

func status_text() -> String:
	var progress := "Customers %d/%d" % [served+lost_sales,customer_count]
	if lost_sales > 0: progress += " (%d unserved)" % lost_sales
	var lines := PackedStringArray(["%s | %s | CHF %.2f" % [definition.title,progress,float(revenue_rappen)/100]])
	var pending := PackedStringArray()
	for task in required_tasks:
		if not tasks.has(task): pending.append(TASK_LABELS.get(task,String(task).capitalize()))
	lines.append("Tasks: "+", ".join(pending) if not pending.is_empty() else "Tasks complete")
	var carried: StringName = inventory.carried_product()
	if delivery_carried: lines.append("Carrying delivery → warehouse")
	elif carried != &"": lines.append("Carrying %s ×%d → matching display" % [inventory.products[carried].display_name,inventory.stocks[carried].carried_units])
	elif delivery_ready: lines.append("Delivery waiting in the yard")
	if can_finish(): lines.append("Finish at the staff shift notes")
	elif served+lost_sales == customer_count and definition.required_story.any(func(id): return not story_flags.get(StringName("presented_"+String(id)),false)): lines.append("Check the stockroom before leaving")
	if "--dev-debug" in OS.get_cmdline_user_args():
		for id in inventory.stocks:
			var item: Resource = inventory.stocks[id]
			lines.append("%s shelf=%d reserved=%d warehouse=%d" % [id,item.shelf_units,item.reserved_units,item.warehouse_units])
	return "\n".join(lines)
