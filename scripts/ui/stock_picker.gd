extends ColorRect
## A view of the existing warehouse inventory, opened at Supply.
const STYLE = preload("res://scripts/ui/station_theme.gd")
var world: Node
var list: Tree
var take: Button
var rows: Dictionary = {}
var active: bool:
	get: return visible

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.015,0.025,0.03,0.72)
	theme = STYLE.make()
	hide()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 586
	center.add_child(panel)
	var column := STYLE.column(panel,12)
	STYLE.text(column,14,STYLE.ACCENT).text = "STATION 14 / STAFF"
	STYLE.text(column,28).text = "Warehouse stock"
	list = Tree.new()
	list.columns = 4
	list.column_titles_visible = true
	list.hide_root = true
	list.select_mode = Tree.SELECT_ROW
	list.custom_minimum_size.y = 164
	list.add_theme_font_size_override("font_size",17)
	column.add_child(list)
	for i in list.columns:
		list.set_column_title(i,["Product","In storage","On shelf","Free slots"][i])
		list.set_column_expand_ratio(i,2 if i == 0 else 1)
	list.item_selected.connect(_refresh_action)
	list.item_activated.connect(_take_selected)
	STYLE.text(column,14,STYLE.MUTED).text = "↑ ↓  Select    ·    Enter  Take    ·    Esc  Close"
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var back := Button.new()
	back.text = "Close"
	back.pressed.connect(close)
	buttons.add_child(back)
	take = Button.new()
	take.custom_minimum_size.x = 208
	take.pressed.connect(_take_selected)
	buttons.add_child(take)
	world.gameplay.inventory.changed.connect(_refresh_rows)

func begin() -> void:
	list.clear()
	rows.clear()
	var root_item := list.create_item()
	for id in world.gameplay.inventory.products:
		var row := list.create_item(root_item)
		row.set_metadata(0,id)
		row.set_text(0,world.gameplay.inventory.products[id].display_name)
		for column in range(1,list.columns):
			row.set_text_alignment(column,HORIZONTAL_ALIGNMENT_CENTER)
		rows[id] = row
	world.player.controls_locked = true
	world.menu.release_controls()
	show()
	_refresh_rows()
	if root_item.get_first_child():
		root_item.get_first_child().select(0)
	_refresh_action()
	list.grab_focus()

func close() -> void:
	hide()
	world.menu.release_controls()
	world.player.controls_locked = world.has_interaction_focus(self)
	world._update_objective()

func _input(event: InputEvent) -> void:
	if not visible or not list.has_focus() or not event is InputEventKey or not event.pressed:
		return
	match event.physical_keycode:
		KEY_UP, KEY_DOWN:
			var row := list.get_selected()
			if row:
				var next := row.get_prev() if event.physical_keycode == KEY_UP else row.get_next()
				if next:
					next.select(0)
					list.scroll_to_item(next)
					_refresh_action()
		KEY_ENTER, KEY_KP_ENTER:
			if not event.echo:
				_take_selected()
		_:
			return
	get_viewport().set_input_as_handled()

func _refresh_rows() -> void:
	if not visible:
		return
	for id in rows:
		var stock: Resource = world.gameplay.inventory.stocks[id]
		var row: TreeItem = rows[id]
		row.set_text(1,str(stock.warehouse_units))
		row.set_text(2,"%d / %d" % [stock.shelf_units,stock.capacity])
		row.set_text(3,str(maxi(0,stock.capacity-stock.shelf_units)))
	_refresh_action()

func _refresh_action() -> void:
	var row := list.get_selected()
	take.disabled = true
	take.text = "Select a product"
	if not row:
		return
	var id: StringName = row.get_metadata(0)
	var stock: Resource = world.gameplay.inventory.stocks[id]
	var units: int = stock.pickup_units()
	take.disabled = units == 0
	if units > 0:
		take.text = "Take %d × %s" % [units,row.get_text(0)]
	else:
		take.text = "Display full" if stock.shelf_units >= stock.capacity else "Out of stock"

func _take_selected() -> void:
	var row := list.get_selected()
	if visible and row and not take.disabled and world.gameplay.collect_stock(row.get_metadata(0)):
		close()
