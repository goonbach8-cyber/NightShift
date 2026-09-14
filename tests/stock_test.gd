extends SceneTree
var failures := 0
func check(condition: bool, text: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+text)
	if not condition:
		failures += 1
func _initialize() -> void:
	var stock = load("res://scripts/shop_stock.gd").new()
	check(not stock.purchase(),"Cannot charge unreserved stock")
	check(not stock.reserve(),"Empty stock cannot be reserved")
	stock.shelf_units = 1
	check(stock.reserve() and not stock.reserve(),"Reservations cannot exceed shelf quantity")
	check(stock.purchase() and not stock.purchase() and stock.shelf_units == 0,"Purchase consumes a reservation exactly once")
	stock.shelf_units = 7
	check(stock.take_crate() and stock.carried_units == 1 and stock.warehouse_units == 23,"Pickup respects remaining shelf capacity")
	check(not stock.take_crate(),"Only one carried load")
	check(stock.restock() and stock.shelf_units == 8 and stock.carried_units == 0,"Restock cannot overflow the shelf")
	check(not stock.take_crate(),"Full shelf does not remove warehouse stock")
	stock.receive_delivery(-8)
	check(stock.warehouse_units == 23,"Invalid delivery cannot remove stock")
	stock.receive_delivery(8)
	check(stock.warehouse_units == 31,"Delivery adds stock once per accepted action")
	stock.reserve()
	stock.release()
	check(stock.reserved_units == 0 and stock.shelf_units == 8,"Released reservation returns availability without changing stock")
	var fresh = load("res://scripts/shop_stock.gd").new()
	check(fresh.warehouse_units == 24 and fresh.shelf_units == 0,"New shift stock is independent")
	print("STOCK TESTS: %d failure(s)" % failures)
	quit(failures)
