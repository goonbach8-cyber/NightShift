extends Control
## Presentation only. DialogueSession still owns progression, choices and flags.
const STYLE = preload("res://scripts/ui/station_theme.gd")
var session: Node
var frame: PanelContainer
var speaker: Label
var body: Label
var indicator: Label
var answers: VBoxContainer
var selection := 0
var signature := ""
var document: PanelContainer
var document_title: Label
var document_body: Label
var document_footer: Label
var document_scroll: ScrollContainer
var document_owner := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = STYLE.make()
	frame = PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	frame.anchor_left = 0.08
	frame.anchor_right = 0.92
	frame.offset_top = -240
	frame.offset_bottom = -28
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var column := STYLE.column(frame,12)
	speaker = STYLE.text(column,18,STYLE.ACCENT)
	column.add_child(HSeparator.new())
	body = STYLE.text(column,24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var choice_surface := PanelContainer.new()
	var choice_style := STYLE.surface()
	choice_style.bg_color = Color("202d30")
	choice_style.shadow_size = 0
	choice_style.content_margin_top = 10
	choice_style.content_margin_bottom = 10
	choice_surface.add_theme_stylebox_override("panel",choice_style)
	column.add_child(choice_surface)
	answers = STYLE.column(choice_surface,6)
	indicator = STYLE.text(column,15,STYLE.MUTED)
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	document = PanelContainer.new()
	document.add_theme_stylebox_override("panel",STYLE.surface(true))
	add_child(document)
	document.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	document.anchor_left = 0.21
	document.anchor_right = 0.79
	document.anchor_top = 0.13
	document.anchor_bottom = 0.87
	var paper := STYLE.column(document,20)
	var heading := STYLE.text(paper,14,Color("5c645e"))
	heading.text = "03:17  /  ARCHIVE"
	document_title = STYLE.text(paper,28,STYLE.INK)
	paper.add_child(HSeparator.new())
	document_scroll = ScrollContainer.new()
	document_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	document_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(document_scroll)
	document_body = STYLE.text(document_scroll,22,STYLE.INK)
	document_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	document_footer = STYLE.text(paper,15,Color("5c645e"))
	document_footer.text = "Space / Enter — Close"
	frame.hide()
	document.hide()

func _process(_delta: float) -> void:
	# Wrapped minimum sizes settle after the first container layout pass.
	# Re-evaluate them instead of retaining a height measured at width zero.
	if frame.visible:
		frame.offset_top = -28-maxf(218,frame.get_combined_minimum_size().y)
		frame.offset_bottom = -28
	if document.visible:
		document_footer.text = ("↑ ↓  Scroll   ·   " if document_scroll.get_v_scroll_bar().max_value > document_scroll.size.y else "")+"Space / Enter — Close"

func bind(model: Node) -> void:
	session = model
	session.changed.connect(refresh)
	refresh()

func has_answers() -> bool:
	return session.active and session.index == session.lines.size()-1 and not session.choices.is_empty()

func refresh() -> void:
	var reading: bool = session.active and session.presentation == &"document"
	frame.visible = session.active and not reading
	document.visible = reading
	body.visible = frame.visible
	if not session.active:
		signature = ""
		return
	if reading:
		if document_owner != session.owner_id or document_title.text != session.document_title:
			document_scroll.scroll_vertical = 0
			document_owner = session.owner_id
		document_title.text = session.document_title
		document_body.text = "\n\n".join(session.lines)
		return
	var line: String = session.lines[session.index]
	speaker.text = session.speaker
	for name in ["Josh","Mike","Customer","Depot clerk","Depot Worker"]:
		if line.begins_with(name+":"):
			speaker.text = "Depot Worker" if name == "Depot clerk" else name
			line = line.trim_prefix(name+":").strip_edges()
			break
	body.text = line
	var next_signature := str(session.owner_id)+":"+str(session.index)+":"+str(session.choices)
	if next_signature != signature:
		selection = 0
		signature = next_signature
		for child in answers.get_children():
			answers.remove_child(child)
			child.queue_free()
		if has_answers():
			for answer in session.choices:
				var row := STYLE.text(answers,21)
				row.text = answer.text
	answers.visible = has_answers()
	answers.get_parent().visible = answers.visible
	for i in answers.get_child_count():
		var row: Label = answers.get_child(i)
		row.text = ("›  " if i == selection else "   ")+String(session.choices[i].text)
		row.add_theme_color_override("font_color",STYLE.ACCENT if i == selection else STYLE.MUTED)
	indicator.text = "↑ ↓  Choose   ·   Enter / E  Confirm" if has_answers() else "Space / Enter  " + ("▼" if session.index+1 < session.lines.size() else "Close")
	# Containers expand for long lines; the bottom stays inside the safe area.
	frame.offset_top = -maxf(218,frame.get_combined_minimum_size().y)

func handle(event: InputEvent) -> bool:
	if not session.active or not event is InputEventKey or not event.pressed or event.echo: return false
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if session.presentation == &"document":
		if code in [KEY_UP,KEY_DOWN,KEY_PAGEUP,KEY_PAGEDOWN]:
			document_scroll.scroll_vertical += -120 if code in [KEY_UP,KEY_PAGEUP] else 120
			return true
		if code in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
			session.close(true)
			return true
		return code in [KEY_E,KEY_F,KEY_TAB,KEY_1,KEY_2]
	if has_answers():
		if code in [KEY_UP,KEY_DOWN]:
			selection = posmod(selection+(-1 if code == KEY_UP else 1),session.choices.size())
			refresh()
		elif code in [KEY_ENTER,KEY_KP_ENTER,KEY_E,KEY_SPACE]: session.choose(selection)
		elif code in [KEY_1,KEY_2]: session.choose(0 if code == KEY_1 else 1)
		else: return false
		return true
	if code in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
		session.advance()
		return true
	return false
