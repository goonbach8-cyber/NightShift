extends Resource
## Mutable per-shift stock; product definitions stay immutable.
var capacity: int = 8
var warehouse_units: int = 24
var shelf_units: int = 0
var carried_units: int = 0
var reserved_units: int = 0
var sold_units: int = 0

func reserve() -> bool:
	if shelf_units - reserved_units <= 0:
		return false
	reserved_units += 1
	changed.emit()
	return true

func release() -> void:
	reserved_units = maxi(0,reserved_units-1)
	changed.emit()

func purchase() -> bool:
	if reserved_units < 1 or shelf_units < 1:
		return false
	reserved_units -= 1
	shelf_units -= 1
	sold_units += 1
	changed.emit()
	return true

func take_crate() -> bool:
	if carried_units != 0:
		return false
	var amount := mini(8,mini(warehouse_units,capacity-shelf_units))
	if amount <= 0:
		return false
	warehouse_units -= amount
	carried_units = amount
	changed.emit()
	return true

func restock() -> bool:
	var amount := mini(carried_units,capacity-shelf_units)
	if amount <= 0:
		return false
	carried_units -= amount
	shelf_units += amount
	changed.emit()
	return true

func receive_delivery(amount: int) -> void:
	warehouse_units += maxi(0,amount)
	changed.emit()
