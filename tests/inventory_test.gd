extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures += 1
func run() -> void:
	var inv = load("res://scripts/shop_inventory.gd").new()
	for path in ["water","energy","chips"]:
		inv.add_product(load("res://data/products/%s.tres" % path))
	inv.initialize_shelves()
	check(inv.stocks.size() == 3,"Three independent product stocks")
	check(not inv.reserve(0,&"water",1) and not inv.reserve(1,&"unknown",1) and not inv.reserve(1,&"water",-1),"Invalid reservation rejected")
	check(inv.reserve(1,&"water",1) and inv.reserve(1,&"water",1) and inv.stocks.water.reserved_units == 1,"Repeated request is idempotent per customer")
	check(inv.reserve(2,&"water",1) and not inv.reserve(3,&"water",1),"Only one customer gets the last available unit")
	check(inv.reserve(1,&"chips",1) and inv.stocks.energy.reserved_units == 0,"Basket reserves products independently")
	inv.release(2)
	inv.release(2)
	check(inv.stocks.water.reserved_units == 1,"Repeated cancellation cannot release another customer's reservation")
	var receipt: Dictionary = inv.commit(1)
	check(receipt.total == 510 and receipt.units == 2,"Basket total uses all product prices in integer rappen")
	check(inv.stocks.water.shelf_units == 1 and inv.stocks.chips.shelf_units == 0 and inv.stocks.energy.shelf_units == 1,"Only bought products leave shelves")
	check(inv.commit(1).is_empty() and inv.stocks.water.sold_units == 1,"Basket cannot be sold twice")
	check(not inv.reserve(3,&"chips",1),"Empty shelf blocks reservation")
	check(inv.take_crate(&"chips") and not inv.take_crate(&"water"),"Only one product load can be carried")
	check(not inv.restock(&"water") and inv.restock(&"chips"),"Load goes only to matching shelf")
	check(inv.stocks.chips.shelf_units == 6 and inv.stocks.chips.warehouse_units == 6,"Restocking conserves stock and respects capacity")
	check(not inv.take_crate(&"chips"),"Full shelf cannot remove warehouse goods")
	inv.stocks.energy.warehouse_units = 0
	inv.stocks.energy.shelf_units = 0
	check(not inv.take_crate(&"energy") and not inv.reserve(4,&"energy",1),"Empty warehouse and shelf reject pickup and reservation")
	check(not inv.receive_delivery(&"bad",{&"water":3,&"unknown":1}) and inv.stocks.water.warehouse_units == 24,"Invalid manifest changes no stock")
	check(not inv.receive_delivery(&"bad",{&"water":-1}),"Negative delivery rejected")
	check(inv.receive_delivery(&"d1",{&"water":6,&"energy":4,&"chips":3}),"Mixed delivery accepted")
	check(not inv.receive_delivery(&"d1",{&"water":6}) and inv.stocks.water.warehouse_units == 30 and inv.stocks.energy.warehouse_units == 4 and inv.stocks.chips.warehouse_units == 9,"Delivery token prevents duplicate inventory")
	check(inv.reserve(7,&"water",1) and inv.reserve(7,&"chips",2),"Multi-quantity basket reserves correctly")
	inv.release(7)
	check(inv.reservations.is_empty() and inv.stocks.water.reserved_units == 0 and inv.stocks.chips.reserved_units == 0,"Aborted basket releases all lines")
	print("INVENTORY TESTS: %d failure(s)" % failures)
	quit(failures)
