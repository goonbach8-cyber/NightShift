extends RefCounted
## A between-shift checkpoint. Never serializes NPCs, reservations or scene paths.
var path: String = "user://nightshift_checkpoint.json"

func whole(value: Variant, maximum: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 0 and value <= maximum

func valid(data: Variant, inventory: Resource) -> bool:
	if not data is Dictionary:
		return false
	if not whole(data.get("version"),1) or int(data.version) != 1:
		return false
	if not whole(data.get("revenue")) or not whole(data.get("shifts")) or not data.get("stocks") is Dictionary:
		return false
	for key in ["flags","events"]:
		if not data.get(key,{}) is Dictionary: return false
		for flag in data.get(key,{}):
			if (not flag is String and not flag is StringName) or not data[key][flag] is bool: return false
	for id in inventory.stocks:
		var row: Variant = data.stocks.get(String(id))
		if not row is Dictionary or not whole(row.get("warehouse"),100000) or not whole(row.get("shelf"),inventory.stocks[id].capacity):
			return false
	return true

func snapshot(loop: Node) -> Dictionary:
	var rows: Dictionary = {}
	for id in loop.inventory.stocks:
		var item: Resource = loop.inventory.stocks[id]
		# Any unplaced load is returned to warehouse at the shift boundary.
		rows[String(id)] = {"warehouse":item.warehouse_units+item.carried_units,"shelf":item.shelf_units}
	return {"version":1,"revenue":loop.career_revenue+loop.revenue_rappen,"shifts":loop.career_shifts+1,"stocks":rows,"flags":loop.story_flags.duplicate(),"events":loop.event_history.duplicate()}

func write_checkpoint(loop: Node) -> bool:
	if loop.active or loop.preparing or not loop.can_finish() or not loop.customers.is_empty() or not loop.inventory.reservations.is_empty():
		return false
	return store_data(snapshot(loop),loop.inventory)

func store_data(data: Dictionary, inventory: Resource) -> bool:
	if not valid(data,inventory):
		return false
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	# Preserve the previous valid checkpoint before replacement.
	if FileAccess.file_exists(path):
		var previous: Variant = read_data(path)
		if valid(previous,inventory) and DirAccess.copy_absolute(path,path+".bak") != OK:
			return false
	return DirAccess.rename_absolute(temporary,path) == OK

func load_checkpoint(loop: Node) -> bool:
	if loop.active or loop.preparing or loop.spawned > 0:
		return false
	var data: Variant = null
	for candidate in [path,path+".bak"]:
		if FileAccess.file_exists(candidate):
			var parsed: Variant = read_data(candidate)
			if valid(parsed,loop.inventory):
				data = parsed
				break
	if data == null:
		return false
	for id in loop.inventory.stocks:
		var item: Resource = loop.inventory.stocks[id]
		item.warehouse_units = int(data.stocks[String(id)].warehouse)
		item.shelf_units = int(data.stocks[String(id)].shelf)
		item.carried_units = 0
		item.reserved_units = 0
		item.sold_units = 0
	loop.career_revenue = int(data.revenue)
	loop.career_shifts = int(data.shifts)
	loop.story_flags = data.get("flags",{}).duplicate()
	loop.event_history = data.get("events",{}).duplicate()
	loop.configure_night(preload("res://scripts/night_catalog.gd").for_night(loop.career_shifts+1))
	loop.use_loaded_stock = true
	for item in loop.inventory.stocks.values(): item.changed.emit()
	return true

func read_data(candidate: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
		return null
	return parser.data
