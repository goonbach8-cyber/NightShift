extends Control
## Contextual presentation, deliberately separate from the shift's rules.
const STYLE = preload("res://scripts/ui/station_theme.gd")
var world: Node
var conversation: Control
var objective_panel: PanelContainer
var objective_title: Label
var objective: Label
var progress: Label
var prompt_panel: PanelContainer
var prompt: Label
var secondary: Label
var checkout_panel: PanelContainer
var checkout_title: Label
var checkout_progress: Label
var checkout_amount: Label
var checkout_amount_caption: Label
var checkout_next: Label
var carry: Label
var carry_panel: PanelContainer
var notice_panel: PanelContainer
var message: Label
var story_panel: PanelContainer
var story: Label
var debug: Label

func card(left: float, top: float, right: float, bottom: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.anchor_left = left
	panel.anchor_top = top
	panel.anchor_right = right
	panel.anchor_bottom = bottom
	return panel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = STYLE.make()
	objective_panel = card(0,0,0.29,0)
	objective_panel.offset_left = 28
	objective_panel.offset_top = 28
	var column := STYLE.column(objective_panel,6)
	objective_title = STYLE.text(column,14,STYLE.ACCENT)
	objective = STYLE.text(column,20)
	progress = STYLE.text(column,14,STYLE.MUTED)
	checkout_panel = card(0.73,0.18,1,0.18)
	checkout_panel.offset_right = -28
	column = STYLE.column(checkout_panel,10)
	checkout_title = STYLE.text(column,20,STYLE.ACCENT)
	checkout_progress = STYLE.text(column,16,STYLE.MUTED)
	column.add_child(HSeparator.new())
	checkout_amount_caption = STYLE.text(column,13,STYLE.MUTED)
	checkout_amount = STYLE.text(column,28)
	checkout_next = STYLE.text(column,16,STYLE.MUTED)
	prompt_panel = card(0.5,1,0.5,1)
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_panel.offset_top = -113
	prompt_panel.offset_bottom = -28
	column = STYLE.column(prompt_panel,5)
	prompt = STYLE.text(column,20)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secondary = STYLE.text(column,14,STYLE.MUTED)
	secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_panel = card(0.32,0.12,0.68,0.12)
	message = STYLE.text(notice_panel,18)
	story_panel = card(0.32,0.29,0.68,0.29)
	story = STYLE.text(story_panel,21)
	carry_panel = card(0,1,0,1)
	carry_panel.offset_left = 28
	carry_panel.offset_right = 310
	carry_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var carry_style := STYLE.surface()
	carry_style.content_margin_left = 12
	carry_style.content_margin_right = 12
	carry_style.content_margin_top = 10
	carry_style.content_margin_bottom = 10
	carry_panel.add_theme_stylebox_override("panel",carry_style)
	carry = STYLE.text(carry_panel,16,STYLE.ACCENT)
	debug = STYLE.text(self,14)
	debug.position = Vector2(28,190)
	debug.size = Vector2(410,330)
	debug.visible = "--dev-debug" in OS.get_cmdline_user_args()
	conversation = preload("res://scripts/ui/conversation_ui.gd").new()
	add_child(conversation)
	conversation.bind(world.gameplay.dialogue)

func objective_text() -> String:
	var loop: Node = world.gameplay
	if world.phase == world.Phase.NOT_STARTED:
		return "Meet Josh at the staff notes" if not loop.definition.handover.is_empty() and not loop.story_flags.get(world.story_world.handover_flag(),false) else "Start your shift at the staff notes"
	if world.phase == world.Phase.COMPLETE: return "Shift complete"
	if loop.preparing: return "Preparing the shop…"
	if loop.can_finish(): return "Finish at the staff notes"
	if loop.delivery_carried: return "Store the delivery in the warehouse"
	if is_instance_valid(world.customer_assistance) and world.customer_assistance.request_active:
		return world.customer_assistance.objective_text()
	if is_instance_valid(world.pump_service) and world.pump_service.fault_pending: return "Reset pump %02d outside" % world.pump_service.fault_pump
	if is_instance_valid(world.pump_service) and world.pump_service.request_pending: return "Authorize the waiting fuel pump"
	if is_instance_valid(world.power_service) and world.power_service.fault_pending: return "Reset the tripped electrical circuit"
	if is_instance_valid(world.phone_system) and world.phone_system.ringing: return "Answer or ignore the ringing phone"
	if is_instance_valid(world.cctv_system) and world.cctv_system.motion_pending: return "Review the CCTV motion alert"
	var carried: StringName = loop.inventory.carried_product()
	if carried != &"": return "Restock "+String(loop.inventory.products[carried].display_name)
	if loop.served+loop.lost_sales == loop.customer_count and loop.definition.required_story.any(func(id): return not loop.story_flags.get(StringName("presented_"+String(id)),false)):
		return "Check the stockroom before leaving"
	if loop.checkout_ready(): return "Serve the customer at the till"
	for task in loop.required_tasks:
		if not loop.tasks.has(task): return loop.TASK_LABELS.get(task,String(task).capitalize())
	return "Keep the shop ready" if loop.served+loop.lost_sales < loop.customer_count else "Wait for the last customer to leave"

func update() -> void:
	var loop: Node = world.gameplay
	var checkout_focus: bool = is_instance_valid(world.checkout_minigame) and world.checkout_minigame.active
	var pump_focus: bool = is_instance_valid(world.pump_service) and world.pump_service.active
	var cctv_focus: bool = is_instance_valid(world.cctv_system) and world.cctv_system.active
	var power_focus: bool = is_instance_valid(world.power_service) and world.power_service.active
	var delivery_focus: bool = is_instance_valid(world.delivery_check) and world.delivery_check.active
	var phone_focus: bool = is_instance_valid(world.phone_system) and world.phone_system.active
	var modal: bool = loop.dialogue.active or world.menu.page != "" or checkout_focus or pump_focus or cctv_focus or power_focus or delivery_focus or phone_focus
	objective_title.text = "NIGHT %d" % (loop.career_shifts+1)
	objective.text = objective_text()
	progress.text = "%d served" % loop.served + (" · %d left unserved" % loop.lost_sales if loop.lost_sales > 0 else "")
	progress.visible = world.phase == world.Phase.ACTIVE
	objective_panel.visible = not modal
	var assistance_blocking: bool = is_instance_valid(world.customer_assistance) and world.customer_assistance.request_active and loop.checkout_ready() and not loop.queue.is_empty() and loop.queue[0] == world.customer_assistance.request_customer
	checkout_panel.visible = loop.checkout_ready() and world.layout.at_operator(world.player) and not modal and not assistance_blocking
	if checkout_panel.visible:
		var detail: Dictionary = loop.checkout_details()
		checkout_title.text = "TOTAL" if detail.remaining == 0 else (String(detail.last)+" scanned" if detail.scanned else "Ready to scan")
		checkout_progress.text = "%d / %d scanned · %d remaining" % [detail.scanned,detail.count,detail.remaining]
		checkout_amount.text = "CHF %.2f" % (float(detail.subtotal)/100)
		checkout_amount_caption.text = "AMOUNT DUE" if detail.remaining == 0 else "SUBTOTAL"
		checkout_next.text = "All items scanned" if detail.remaining == 0 else "Next: "+String(detail.next)
	var target: Node3D = world.player.interaction_target if is_instance_valid(world.player.interaction_target) else null
	prompt.text = ""
	secondary.text = ""
	if not modal and target != null:
		prompt.text = "[E]  "+compact_prompt(target)
		secondary.add_theme_color_override("font_color",STYLE.MUTED)
		for id in world.layout.product_nodes:
			if target == world.layout.product_nodes[id]:
				var stock: Resource = loop.inventory.stocks[id]
				secondary.text = "%d / %d on shelf" % [stock.shelf_units,stock.capacity]
		if target == world.layout.warehouse.get_node("Supply"):
			secondary.text = "%d in storage   ·   [TAB] Select stock" % loop.inventory.stocks[loop.selected_product()].warehouse_units if not loop.delivery_carried else "Mixed delivery · Store all items"
		elif target == world.layout.radio_point: secondary.text = "[Y] Next track   ·   [+ / −] Volume"
		elif target == world.layout.pump_terminal and is_instance_valid(world.pump_service):
			secondary.text = "Pump %02d · %s" % [world.pump_service.request_pump,world.pump_service._money(world.pump_service.request_limit)] if world.pump_service.request_pending else "Forecourt clear"
		elif target == world.layout.cctv_terminal and is_instance_valid(world.cctv_system):
			secondary.text = "Motion alert · "+String(world.cctv_system.channels[world.cctv_system.motion_channel].area).capitalize() if world.cctv_system.motion_pending else "4 live camera feeds"
		elif target == world.layout.breaker_panel and is_instance_valid(world.power_service):
			secondary.text = String(world.power_service.circuits[world.power_service.fault_circuit].symptom) if world.power_service.fault_pending else "All circuits stable"
		elif target == world.layout.phone_point and is_instance_valid(world.phone_system):
			secondary.text = ("Incoming · "+world.phone_system.incoming_number) if world.phone_system.ringing else "Dial numbers or review this shift's call log"
		elif target == world.get_node("Station/ShiftBoard"): secondary.text = "[F] Read shift notes"
		if target == world.layout.checkout and loop.checkout_ready() and world.layout.at_operator(world.player):
			var content: Dictionary = preload("res://scripts/dialogue_catalog.gd").for_context(loop.event_history,loop.story_flags,loop.career_shifts+1)
			var special: bool = content.has("seen_flag") or not content.choices.is_empty()
			secondary.text = "[F] Talk · About the phone call" if special else "[F] Talk"
			secondary.add_theme_color_override("font_color",STYLE.ACCENT if special else STYLE.MUTED)
	prompt_panel.visible = not prompt.text.is_empty()
	secondary.visible = not secondary.text.is_empty()
	var font: Font = prompt.get_theme_font("font")
	var width: float = clampf(maxf(font.get_string_size(prompt.text,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x,font.get_string_size(secondary.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)+48,240,minf(620,size.x-64))
	prompt_panel.offset_left = -width/2
	prompt_panel.offset_right = width/2
	prompt_panel.offset_top = -28-(88 if secondary.visible else 64)
	prompt_panel.offset_bottom = -28
	var carried: StringName = loop.inventory.carried_product()
	carry.text = "Carrying: Delivery → warehouse" if loop.delivery_carried else ("Carrying: "+String(loop.inventory.products[carried].display_name) if carried != &"" else "")
	carry.visible = not modal and not carry.text.is_empty()
	carry_panel.visible = carry.visible
	carry_panel.offset_bottom = -40-(prompt_panel.size.y if prompt_panel.visible else 0)
	carry_panel.offset_top = carry_panel.offset_bottom-maxf(44,carry_panel.get_combined_minimum_size().y)
	notice_panel.visible = not modal and world.message_time > 0 and not message.text.is_empty()
	message.visible = notice_panel.visible
	story_panel.visible = not modal and world.story_time > 0 and not story.text.is_empty()
	story.visible = story_panel.visible
	if story_panel.visible: notice_panel.hide()
	debug.visible = not modal and "--dev-debug" in OS.get_cmdline_user_args()
	if debug.visible: debug.text = loop.status_text()

func show_notice(text: String) -> void:
	if text.begins_with("Carrying delivery."):
		var manifest := PackedStringArray(["DELIVERY"])
		for id in world.gameplay.delivery_manifest:
			manifest.append("%s ×%d" % [world.gameplay.inventory.products[id].display_name,world.gameplay.delivery_manifest[id]])
		manifest.append("Bring to warehouse supply")
		message.text = "\n".join(manifest)
	elif text.begins_with("A customer left unserved"):
		message.text = "Customer left without being served"
	elif text.contains(" scanned · CHF "):
		# The till already shows this; don't echo every scan in the middle of the world.
		message.text = ""
	else: message.text = text

func compact_prompt(target: Node3D) -> String:
	var loop: Node = world.gameplay
	var carried: StringName = loop.inventory.carried_product()
	if target == world.layout.checkout:
		if not world.layout.at_operator(world.player): return "Use the staff side"
		if not loop.checkout_ready(): return "Checkout · Waiting for customer"
		if is_instance_valid(world.customer_assistance) and world.customer_assistance.request_active and not loop.queue.is_empty() and loop.queue[0] == world.customer_assistance.request_customer:
			return "Return "+world.customer_assistance.item_label if world.customer_assistance.item_found else "Customer needs help"
		return "Accept payment" if loop.checkout_details().remaining == 0 else "Scan item"
	for id in world.layout.product_nodes:
		if target != world.layout.product_nodes[id]: continue
		if loop.inventory.stocks[id].shelf_units >= loop.inventory.stocks[id].capacity and not (target.action_id == &"cooler" and carried == &""):
			return "Check "+String(loop.inventory.products[id].display_name)+" · Full"
		if carried == id: return "Restock "+String(loop.inventory.products[id].display_name)
		if carried != &"": return "Check shelf · Wrong product"
		return "Check refrigeration" if target.action_id == &"cooler" else "Check "+String(loop.inventory.products[id].display_name)
	if target == world.layout.warehouse.get_node("Supply"):
		if loop.delivery_carried: return "Store delivery"
		if carried != &"": return "Restock your display first"
		if loop.inventory.stocks[loop.selected_product()].warehouse_units == 0: return "Check stock · Warehouse empty"
		if loop.inventory.stocks[loop.selected_product()].shelf_units == loop.inventory.stocks[loop.selected_product()].capacity: return "Check stock · Display full"
		return "Collect "+String(loop.inventory.products[loop.selected_product()].display_name)
	if target == world.layout.delivery: return "Inspect delivery" if carried == &"" else "Restock your display first"
	if target == world.layout.pump_terminal:
		if is_instance_valid(world.pump_service) and world.pump_service.fault_pending: return "Pump fault · Reset outside"
		return "Open pump control" if is_instance_valid(world.pump_service) and world.pump_service.request_pending else "Pump control · No requests"
	if target == world.layout.cctv_terminal:
		return "Review CCTV alert" if is_instance_valid(world.cctv_system) and world.cctv_system.motion_pending else "View security cameras"
	if target == world.layout.breaker_panel:
		return "Reset tripped circuit" if is_instance_valid(world.power_service) and world.power_service.fault_pending else "Check breaker panel"
	if target == world.layout.phone_point:
		return "Answer phone" if is_instance_valid(world.phone_system) and world.phone_system.ringing else "Use counter phone"
	for id in world.layout.pump_reset_points:
		if target == world.layout.pump_reset_points[id]:
			return "Reset pump %02d" % int(id)
	if target == world.layout.radio_point: return "Radio · "+("Switch off" if world.radio.enabled else "Switch on")
	return target.prompt
