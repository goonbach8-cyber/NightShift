extends Resource
## Reservations are owned by customer IDs. A basket commits completely or not at all.
const STOCK = preload("res://scripts/shop_stock.gd")
var products: Dictionary = {}
var stocks: Dictionary = {}
var reservations: Dictionary = {}
var delivery_ids: Dictionary = {}

func add_product(product: Resource, existing: Resource = null) -> void:
	var id: StringName = product.product_id
	products[id] = product
	var item: Resource = existing if existing != null else STOCK.new()
	item.capacity = product.shelf_capacity
	item.warehouse_units = product.initial_warehouse
	stocks[id] = item
	item.changed.connect(_on_stock_changed)

func _on_stock_changed() -> void:
	changed.emit()

func initialize_shelves() -> void:
	for id in stocks:
		stocks[id].shelf_units = mini(products[id].initial_shelf, stocks[id].capacity)
		stocks[id].changed.emit()

func reserve(owner_id: int, id: StringName, quantity: int) -> bool:
	if owner_id <= 0 or not stocks.has(id) or quantity <= 0:
		return false
	var basket: Dictionary = reservations.get(owner_id, {})
	var previous: int = basket.get(id, 0)
	if quantity < previous:
		return false
	var extra := quantity - previous
	var item: Resource = stocks[id]
	if item.shelf_units-item.reserved_units < extra:
		return false
	item.reserved_units += extra
	basket[id] = quantity
	reservations[owner_id] = basket
	item.changed.emit()
	return true

func release(owner_id: int) -> void:
	var basket: Dictionary = reservations.get(owner_id, {})
	reservations.erase(owner_id)
	for id in basket:
		stocks[id].reserved_units -= int(basket[id])
		stocks[id].changed.emit()

func commit(owner_id: int) -> Dictionary:
	var basket: Dictionary = reservations.get(owner_id, {})
	if basket.is_empty():
		return {}
	var total := 0
	var units := 0
	for id in basket:
		var quantity: int = basket[id]
		if stocks[id].reserved_units < quantity or stocks[id].shelf_units < quantity:
			return {}
		total += products[id].line_total(quantity)
		units += quantity
	# Validate every line before modifying any product. Observers see the entire sale.
	for id in basket:
		stocks[id].shelf_units -= int(basket[id])
		stocks[id].reserved_units -= int(basket[id])
		stocks[id].sold_units += int(basket[id])
	reservations.erase(owner_id)
	for id in basket:
		stocks[id].changed.emit()
	return {"total": total, "units": units, "items": basket.duplicate()}

func carried_product() -> StringName:
	for id in stocks:
		if stocks[id].carried_units > 0:
			return id
	return &""

func take_crate(id: StringName) -> bool:
	return stocks.has(id) and carried_product() == &"" and stocks[id].take_crate()

func restock(id: StringName) -> bool:
	return stocks.has(id) and carried_product() == id and stocks[id].restock()

func receive_delivery(delivery_id: StringName, manifest: Dictionary) -> bool:
	if delivery_id == &"" or delivery_ids.has(delivery_id) or manifest.is_empty():
		return false
	for id in manifest:
		if not stocks.has(id) or not manifest[id] is int or manifest[id] <= 0:
			return false
	delivery_ids[delivery_id] = true
	for id in manifest:
		stocks[id].warehouse_units += int(manifest[id])
	for id in manifest:
		stocks[id].changed.emit()
	return true

func basket_text(basket: Dictionary) -> String:
	var lines := PackedStringArray()
	for id in basket:
		lines.append("%d× %s" % [basket[id], products[id].display_name])
	return ", ".join(lines)
