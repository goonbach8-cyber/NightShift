extends MeshInstance3D
## Ink or LCD pixels on an opaque, lit surface. No camera-facing text or viewport.
const GLYPHS = preload("res://assets/ui/print_glyphs.png")
static var textures: Dictionary = {}
var print_size := Vector2(1.0,0.18)
var paper := Color("203a3c")
var modulate := Color("e4dfc9"):
	set(value):
		if modulate == value: return
		modulate = value
		_refresh()
var text := "":
	set(value):
		if text == value: return
		text = value
		_refresh()
var print_texture: ImageTexture

static func make(parent: Node3D, content: String, at: Vector3, size: Vector2, ink := Color("e4dfc9"), background := Color("203a3c"), horizontal := false):
	var surface = load("res://scripts/printed_surface.gd").new()
	surface.print_size = size
	surface.paper = background
	surface.modulate = ink
	surface.position = at
	if horizontal: surface.rotation.x = -PI/2.0
	parent.add_child(surface)
	surface.text = content
	return surface

func _ready() -> void:
	var board := QuadMesh.new()
	board.size = print_size
	mesh = board
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_refresh()

func _refresh() -> void:
	if not is_inside_tree(): return
	var key := "%s|%s|%s|%s" % [text,print_size,modulate,paper]
	if not textures.has(key):
		var words := text.replace("×","x").replace("°","o").replace("—","-").replace("…","...")
		var lines := words.split("\n")
		var longest := 1
		for line in lines: longest = maxi(longest,line.length())
		var ink_image := Image.create(longest*20+12,lines.size()*40,false,Image.FORMAT_RGBA8)
		ink_image.fill(Color.TRANSPARENT)
		var atlas := GLYPHS.get_image()
		for row in lines.size():
			for column in lines[row].length():
				var glyph := clampi(lines[row].unicode_at(column)-32,0,94)
				ink_image.blit_rect(atlas,Rect2i((glyph%16)*32,(glyph/16)*40,32,40),Vector2i(column*20,row*40))
		var width := 384
		var height := clampi(roundi(width*print_size.y/print_size.x),32,768)
		var scale := minf((width-24.0)/ink_image.get_width(),(height-8.0)/ink_image.get_height())
		ink_image.resize(maxi(1,roundi(ink_image.get_width()*scale)),maxi(1,roundi(ink_image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
		var image := Image.create(width,height,false,Image.FORMAT_RGBA8)
		image.fill(paper)
		var offset := Vector2i((width-ink_image.get_width())/2,(height-ink_image.get_height())/2)
		for y in ink_image.get_height():
			for x in ink_image.get_width():
				var coverage := ink_image.get_pixel(x,y).a
				if coverage > 0:
					image.set_pixel(x+offset.x,y+offset.y,Color(paper.lerp(modulate,coverage),1.0))
		image.generate_mipmaps()
		if textures.size() >= 128: textures.erase(textures.keys()[0])
		textures[key] = ImageTexture.create_from_image(image)
	print_texture = textures[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = print_texture
	material.roughness = 0.88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material_override = material
