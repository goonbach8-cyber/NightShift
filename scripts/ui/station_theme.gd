extends RefCounted
## Quiet enamel / warm paper palette shared by in-world UI and menus.
const INK := Color("141e22")
const PAPER := Color("e7e2d4")
const MUTED := Color("a3b3ae")
const ACCENT := Color("c7b782")

static func surface(paper: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e3dece") if paper else Color(0.055,0.085,0.10,0.97)
	box.border_color = Color("9b947f") if paper else Color("6c7b76")
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 24
	box.content_margin_right = 24
	box.content_margin_top = 18
	box.content_margin_bottom = 18
	box.shadow_color = Color(0,0,0,0.3)
	box.shadow_size = 6
	return box

static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color","Label",PAPER)
	theme.set_color("font_color","Button",PAPER)
	theme.set_color("font_hover_color","Button",Color.WHITE)
	theme.set_color("font_focus_color","Button",Color.WHITE)
	theme.set_color("font_disabled_color","Button",Color("727c79"))
	theme.set_stylebox("panel","PanelContainer",surface())
	theme.set_stylebox("panel","Panel",surface())
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box := surface()
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		box.shadow_size = 0
		if state in ["hover","pressed"]: box.bg_color = Color("293b3e")
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = ACCENT
			box.set_border_width_all(2)
		theme.set_stylebox(state,"Button",box)
	for state in ["slider","grabber_area","grabber_area_highlight"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color("344448") if state == "slider" else ACCENT
		track.set_corner_radius_all(2)
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		theme.set_stylebox(state,"HSlider",track)
	var handle := Image.create(10,18,false,Image.FORMAT_RGBA8)
	handle.fill(ACCENT)
	var texture := ImageTexture.create_from_image(handle)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		theme.set_icon(state,"HSlider",texture)
	return theme

static func text(parent: Node, size: int = 20, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)
	return label

static func column(parent: Node, gap: int = 10) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",gap)
	parent.add_child(box)
	return box
