extends Node
signal changed
signal notice(text: String)
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
	dialogue = Node.new()
	dialogue.set_script(preload("res://scripts/dialogue_session.gd"))
	add_child(dialogue)
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
	active = true
	preparing = false
	spawn_clock = spawn_interval
	notice.emit("Schicht gestartet. TAB wählt Nachfüllware, E bedient Kasse und Regale.")
	changed.emit()

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	events.advance(elapsed,served)
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
		notice.emit("Lieferung im Hof: "+inventory.basket_text(delivery_manifest))
		changed.emit()
	for customer in customers.duplicate():
		# A reachable approach marker has a small browsing radius, avoiding a pile-up
		# when another shopper is standing directly at the same shelf.
		if customer.state == &"shopping" and customer.global_position.distance_to(layout.product_points[customer.current_product].global_position) < 0.8:
			select_product(customer)
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
	customer.doors = layout.doors
	customer.order = order_patterns[spawned % order_patterns.size()].duplicate()
	customer.remaining_products = customer.order.keys()
	customer.move_speed = 1.65 + (spawned % 3)*0.15
	customer.patience = 240 + (spawned % 3)*30
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
		select_product(customer)
	elif customer.state == &"leaving":
		customers.erase(customer)
		departed += 1
		customer.queue_free()
		changed.emit()

func select_product(customer: CharacterBody3D) -> void:
	if customer.state != &"shopping" and customer.state != &"stock_wait":
		return
	var id: StringName = customer.current_product
	if inventory.reserve(customer.get_instance_id(),id,customer.order[id]):
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
	if scanned_owner == customer.get_instance_id():
		scanned_owner = 0
		scanned_units = 0
	if dialogue.owner_id == customer.get_instance_id(): dialogue.close()
	queue.erase(customer)
	customer.abandoned = true
	lost_sales += 1
	customer.state = &"leaving"
	customer.status_text = "Zu lange gewartet"
	customer.go_to(layout.spawn_point)
	update_queue()
	notice.emit("Ein Kunde geht unbedient. Reservierte Ware ist wieder frei.")
	changed.emit()

func customer_removed(owner_id: int) -> void:
	# Also runs if an NPC is removed externally, not only through normal checkout.
	inventory.release(owner_id)
	if scanned_owner == owner_id:
		scanned_owner = 0
		scanned_units = 0
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

func checkout() -> bool:
	if queue.is_empty():
		return false
	var customer := queue[0]
	if customer.walking or customer.paid or customer.global_position.distance_to(layout.queue_points[0].global_position) > 0.6:
		return false
	if dialogue.active:
		notice.emit("Finish the conversation with Space or choose an answer.")
		return false
	if scanned_owner != customer.get_instance_id():
		scanned_owner = customer.get_instance_id()
		scanned_units = 0
	var total_units := 0
	var total_price := 0
	for id in customer.order:
		total_units += int(customer.order[id])
		total_price += inventory.products[id].line_total(customer.order[id])
	if not quick_checkout and scanned_units < total_units:
		scanned_units += 1
		notice.emit("Scanned %d/%d articles. Total CHF %.2f. [E] %s" % [scanned_units,total_units,float(total_price)/100,"Take payment" if scanned_units == total_units else "Scan next"])
		changed.emit()
		return true
	var receipt: Dictionary = inventory.commit(customer.get_instance_id())
	if receipt.is_empty():
		return false
	queue.pop_front()
	customer.paid = true
	customer.state = &"leaving"
	customer.status_text = "Danke!"
	revenue_rappen += int(receipt.total)
	sold_units += int(receipt.units)
	served += 1
	completed_orders.append(receipt)
	scanned_owner = 0
	scanned_units = 0
	customer.go_to(layout.spawn_point)
	update_queue()
	notice.emit("%s — CHF %.2f" % [inventory.basket_text(receipt.items),float(receipt.total)/100])
	changed.emit()
	return true

func cycle_supply() -> void:
	supply_selection = (supply_selection+1) % inventory.products.size()
	update_supply_prompt()
	notice.emit("Nachfüllware gewählt: "+inventory.products[selected_product()].display_name)
	changed.emit()

func selected_product() -> StringName:
	return inventory.products.keys()[supply_selection]

func update_supply_prompt() -> void:
	var id := selected_product()
	layout.warehouse.get_node("Supply").prompt = "Lieferung einlagern" if delivery_carried else "%s holen (Lager %d) — TAB wechseln" % [inventory.products[id].display_name,inventory.stocks[id].warehouse_units]

func fill_shelf(id: StringName) -> void:
	if inventory.restock(id):
		tasks[&"restock"] = true
		notice.emit(inventory.products[id].display_name+" aufgefüllt.")
	else:
		notice.emit("Passende Nachfüllware im Lager holen (TAB wählt Produkt).")

func interact(action: StringName, player: Node3D) -> void:
	if String(action).begins_with("stock_"):
		fill_shelf(StringName(String(action).trim_prefix("stock_")))
	else:
		match action:
			&"service":
				tasks[&"service"] = true
				notice.emit("Waste bin emptied. Service check complete.")
			&"cooler":
				tasks[&"cooler"] = true
				if inventory.carried_product() == &"energy":
					fill_shelf(&"energy")
				else:
					notice.emit("Kühlung kontrolliert: 4 °C.")
			&"shelf":
				fill_shelf(&"water")
			&"supply":
				if delivery_carried:
					if inventory.receive_delivery(&"shift_delivery",delivery_manifest):
						delivery_carried = false
						tasks[&"delivery"] = true
						notice.emit("Eingelagert: "+inventory.basket_text(delivery_manifest))
				elif inventory.take_crate(selected_product()):
					notice.emit("Nachfüllware dabei: "+inventory.products[selected_product()].display_name)
				else:
					notice.emit("Bereits Ware dabei, Regal voll oder Lagerbestand leer.")
			&"delivery":
				if delivery_ready and inventory.carried_product() == &"":
					delivery_ready = false
					delivery_carried = true
					layout.delivery.available = false
					layout.delivery_visual.hide()
					notice.emit("Lieferung dabei. Zum Lager-Nachfüllpunkt bringen.")
				else:
					notice.emit("Zuerst getragene Ware ins passende Regal füllen.")
			&"finish":
				if not layout.at_operator(player):
					notice.emit("Kasse von der Mitarbeiterseite bedienen.")
				elif not checkout() and not can_finish():
					notice.emit("Noch kein Kunde bereit. Kunden bedienen und Aufgaben abschließen.")
	update_supply_prompt()
	changed.emit()

func can_finish() -> bool:
	return served+lost_sales == customer_count and departed == customer_count and required_tasks.all(func(id): return tasks.has(id))

func talk() -> void:
	if queue.is_empty() or queue[0].walking: return
	var content: Dictionary = preload("res://scripts/dialogue_catalog.gd").for_context(event_history,story_flags)
	dialogue.begin(queue[0].get_instance_id(),content.lines,content.choices,story_flags)

func status_text() -> String:
	var rows := PackedStringArray()
	for id in inventory.stocks:
		var item: Resource = inventory.stocks[id]
		rows.append("%s %d/%d%s" % [inventory.products[id].display_name,item.shelf_units,item.capacity," !" if item.shelf_units-item.reserved_units <= 1 else ""])
	var carried: StringName = inventory.carried_product()
	var carry: String = "Lieferung dabei → Lager" if delivery_carried else ("Dabei: %s ×%d → Regal" % [inventory.products[carried].display_name,inventory.stocks[carried].carried_units] if carried != &"" else "TAB Nachfüllware: "+inventory.products[selected_product()].display_name)
	var till: String = "Kasse frei" if queue.is_empty() else "Kasse: "+inventory.basket_text(queue[0].order)
	if scanned_owner != 0: till += " | scanned %d — [E] scan/pay" % scanned_units
	if required_tasks.has(&"service"): till += " | %s Waste bin" % ("[x]" if tasks.has(&"service") else "[ ]")
	carry = definition.title+" | "+carry
	return "SCHICHT %d/%d bedient | %d verloren | CHF %.2f | %d Artikel\n%s\n%s\n%s Kühlung  %s Nachfüllen  %s Lieferung\n%s\n%s" % [served,customer_count,lost_sales,float(revenue_rappen)/100,sold_units," · ".join(rows),carry,"[x]" if tasks.has(&"cooler") else "[ ]","[x]" if tasks.has(&"restock") else "[ ]","[x]" if tasks.has(&"delivery") else "[ ]",till,"Schichtende an der Kasse bestätigen." if can_finish() else ("Lieferung im Hof abholen." if delivery_ready else "! = knapp / reserviert. Passende Ware nachfüllen.")]
