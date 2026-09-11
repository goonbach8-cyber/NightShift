class_name ShopProduct
extends Resource
## Immutable product definition. Prices use integer Swiss rappen, never floats.
@export var product_id: StringName
@export var display_name: String
@export var category: StringName
@export_range(0, 100000) var price_rappen: int = 0

func line_total(quantity: int) -> int:
	return price_rappen * maxi(0, quantity)
