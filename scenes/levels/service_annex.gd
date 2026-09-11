extends Node3D
## Small east-side extension. Visual helpers share the shop's material palette.
const DOOR = preload("res://scenes/interactions/door.tscn")
const INTERACTABLE = preload("res://scenes/interactions/interactable.gd")
const PRODUCTS = {
	&"water": preload("res://data/products/water.tres"),
	&"coffee": preload("res://data/products/coffee.tres"),
	&"snack": preload("res://data/products/snack.tres")
}
var reserve_units: int = 24
var carried_units: int = 0
var shop_units: int = 0
var d: Node3D
var doors: Array[Node3D] = []
var sounds: Array[AudioStreamPlayer3D] = []
var previous_motion: Dictionary = {}

func _ready() -> void:
	d = get_parent().get_node("StationDressing")
	build_rooms()
	stockroom()
	washroom()
	delivery_yard()
	forecourt()
	setup_sound()

func box(at: Vector3, size: Vector3, color: String, solid: bool = false) -> MeshInstance3D:
	var mesh: MeshInstance3D = d.box(at,size,color,self)
	if solid:
		var body := StaticBody3D.new()
		body.position = at
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return mesh

func door(node_name: String, at: Vector3, width: float, turn: float, label: String) -> Node3D:
	var item := DOOR.instantiate()
	item.name = node_name
	item.position = at
	item.rotation.y = turn
	item.scale.x = width / 2.2
	add_child(item)
	item.get_node("Panel/Mesh").material_override = d.mat("65746a")
	d.sign_text(label,Vector3(0,1.1,0.12),minf(1.6,maxf(0.4,label.length()*0.11)),item.get_node("Panel"))
	item.blocked.connect(func(): get_node("../../")._say("Der Durchgang muss frei bleiben."))
	doors.append(item)
	return item

func build_rooms() -> void:
	var wall := get_node("../../PrototypeRoom/EastWall")
	wall.get_node("MeshInstance3D").hide()
	wall.get_node("CollisionShape3D").disabled = true
	# Existing decorative wall strips must not span the new opening.
	for child in d.get_children():
		if child is MeshInstance3D and is_equal_approx(child.position.x,6.82):
			if child.mesh is BoxMesh and (child.mesh.size.z > 9 or (child.position.z > -3.3 and child.position.z < -1.1)):
				child.hide()
	box(Vector3(7,1,-4.225),Vector3(0.3,2,1.85),"a2a499",true)
	box(Vector3(7,1,1.95),Vector3(0.3,2,6.1),"a2a499",true)
	box(Vector3(9.5,-0.1,0),Vector3(5,0.2,10),"727b72",true)
	box(Vector3(12,1,0),Vector3(0.2,2,10.2),"a2a499",true)
	box(Vector3(9.5,0.35,5),Vector3(5.2,0.7,0.2),"65746a",true)
	box(Vector3(7.8,1,-5),Vector3(1.6,2,0.2),"a2a499",true)
	box(Vector3(11.1,1,-5),Vector3(1.8,2,0.2),"a2a499",true)
	# WC: 3 x 3.2 m, accessed from the stockroom, away from food handling surfaces.
	box(Vector3(9,0.65,3.4),Vector3(0.15,1.3,3.2),"a2a499",true)
	box(Vector3(8.225,0.65,1.8),Vector3(2.45,1.3,0.15),"a2a499",true)
	box(Vector3(11.275,0.65,1.8),Vector3(1.45,1.3,0.15),"a2a499",true)
	box(Vector3(10.5,0.006,3.4),Vector3(2.8,0.012,3.0),"8e9b94")
	door("StoreDoor",Vector3(7,0,-2.2),2.2,PI/2,"LAGER")
	door("WCEntry",Vector3(10,0,1.8),1.1,0,"WC")
	door("DeliveryDoor",Vector3(9.4,0,-5),1.6,0,"ANLIEFERUNG")
	d.sign_text("LAGER / SERVICE",Vector3(10,1.75,-4.85),2.2,self)
	light(Vector3(9.5,2.5,-1.9),Color("e2dec5"),1.3,6)
	light(Vector3(10.6,2.3,3.3),Color("deebdf"),0.45,3.5)

func stockroom() -> void:
	for z in [-3.4,-0.3]:
		box(Vector3(11.4,0.75,z),Vector3(0.85,1.5,1.8),"344b4b",true)
		for y in [0.25,0.85,1.45]:
			box(Vector3(11.38,y,z),Vector3(0.94,0.055,1.9),"8e9b94")
			for dz in [-0.56,0.0,0.56]:
				box(Vector3(11.3,y+0.20,z+dz),Vector3(0.68,0.34,0.43),"a18a61")
				box(Vector3(10.951,y+0.20,z+dz),Vector3(0.014,0.13,0.22),"d9cba7")
				box(Vector3(11.3,y+0.38,z+dz),Vector3(0.1,0.02,0.43),"d9cba7")
				box(Vector3(11.3,y+0.20,z+dz+0.22),Vector3(0.25,0.12,0.01),"d9cba7")
	for z in [-4.1,0.7]:
		box(Vector3(8.0,0.18,z),Vector3(0.95,0.36,0.62),"286663",true)
		for i in 4:
			d.bottle(Vector3(7.68+i*0.21,0.4,z),"7d9670",self,0.7)
	var supply := Node3D.new()
	supply.name = "Supply"
	supply.set_script(INTERACTABLE)
	supply.action_id = &"supply"
	supply.prompt = "Getränkekiste nehmen (8 Flaschen)"
	supply.position = Vector3(8,0,-4.1)
	add_child(supply)
	d.sign_text("NACHFÜLLWARE",Vector3(8,0.83,-4.1),1.15,self)
	box(Vector3(7.7,0.8,3.6),Vector3(0.8,1.6,0.7),"52625c",true)
	d.sign_text("REINIGUNG",Vector3(7.7,1.35,3.97),0.7,self)
	box(Vector3(8.4,0.85,4.25),Vector3(0.045,1.65,0.045),"a18a61")
	box(Vector3(8.4,0.07,4.25),Vector3(0.5,0.12,0.15),"344b4b")
	d.cylinder(Vector3(8.15,0.18,4.5),0.2,0.36,"8e9b94",self)

func washroom() -> void:
	box(Vector3(11.25,0.55,2.2),Vector3(0.65,1.1,0.32),"d9ded1",true)
	box(Vector3(11.25,0.24,2.66),Vector3(0.55,0.48,0.72),"d9ded1",true)
	var seat := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.28
	ring.rings = 16
	ring.ring_segments = 8
	seat.mesh = ring
	seat.material_override = d.mat("d9ded1")
	seat.position = Vector3(11.25,0.51,2.70)
	seat.scale = Vector3(1,0.4,1.35)
	add_child(seat)
	box(Vector3(11.25,0.498,2.70),Vector3(0.34,0.008,0.40),"344b4b")
	box(Vector3(9.55,0.75,4.3),Vector3(0.75,0.14,0.5),"d9ded1",true)
	box(Vector3(9.55,0.825,4.3),Vector3(0.46,0.012,0.30),"8e9b94")
	box(Vector3(9.55,0.96,4.5),Vector3(0.05,0.3,0.05),"8e9b94")
	box(Vector3(9.55,1.10,4.43),Vector3(0.05,0.04,0.18),"8e9b94")
	box(Vector3(9.55,1.45,4.78),Vector3(0.68,0.60,0.035),"8e9b94")
	box(Vector3(10.1,1.0,4.75),Vector3(0.15,0.27,0.10),"ddd4b3")
	d.cylinder(Vector3(11.8,0.72,2.7),0.09,0.17,"ddd4b3",self).rotation.z = PI/2

func delivery_yard() -> void:
	box(Vector3(9.5,-0.12,-6.5),Vector3(5,0.24,3),"3c4849",true)
	for x in [7.0,12.0]:
		box(Vector3(x,0.4,-6.5),Vector3(0.15,0.8,3),"344b4b",true)
	box(Vector3(9.5,0.4,-8),Vector3(5,0.8,0.15),"344b4b",true)
	box(Vector3(11.05,0.13,-6.65),Vector3(1.25,0.26,0.9),"a18a61",true)
	for x in [10.58,10.82,11.06,11.30,11.54]:
		box(Vector3(x,0.28,-6.65),Vector3(0.19,0.04,0.9),"c0a779")
	box(Vector3(11.05,0.51,-6.65),Vector3(0.86,0.43,0.65),"a18a61",true)
	box(Vector3(7.65,0.5,-7.1),Vector3(0.85,1.0,0.7),"286663",true)
	box(Vector3(7.65,1.02,-7.1),Vector3(0.9,0.08,0.77),"263739")
	light(Vector3(9.4,2.4,-5.35),Color("ffd7a6"),1.0,4)

func forecourt() -> void:
	# Cutaway canopy: structural fascia and light strips, open for the game camera.
	for x in [-5.0,-2.6]:
		box(Vector3(x,1.6,7.25),Vector3(0.14,3.2,0.14),"8e9b94",true)
	for z in [6.9,9.65]:
		box(Vector3(-3.8,3.25,z),Vector3(3.6,0.24,0.15),"286663")
	for x in [-5.6,-2.0]:
		box(Vector3(x,3.25,8.275),Vector3(0.15,0.24,2.9),"286663")
	d.box(Vector3(-3.8,3.15,7.4),Vector3(1.8,0.05,0.14),"dce9d3",self,true)
	light(Vector3(-3.8,2.9,8.2),Color("dce9d3"),1.0,4)
	box(Vector3(0,-0.08,13.2),Vector3(22,0.12,4),"20272d")
	for x in range(-10,11,3):
		box(Vector3(x,0.001,13.2),Vector3(1.6,0.01,0.065),"b4b2a0")
	box(Vector3(5.6,1.05,9.9),Vector3(0.95,2.1,0.18),"173d40",true)
	d.sign_text("NIGHTSHIFT",Vector3(5.6,1.8,10.0),0.78,self)
	d.sign_text("DIESEL",Vector3(5.6,1.35,10.0),0.68,self)
	d.sign_text("1.829",Vector3(5.6,0.98,10.0),0.72,self)
	d.sign_text("CHF / L",Vector3(5.6,0.63,10.0),0.50,self)

func light(at: Vector3, color: Color, energy: float, distance: float) -> void:
	d.box(at,Vector3(0.6,0.07,0.16),"dce9d3",self,true)
	var lamp := OmniLight3D.new()
	lamp.position = at - Vector3(0,0.1,0)
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = distance
	add_child(lamp)

func take_crate() -> bool:
	if carried_units != 0 or reserve_units < 8:
		return false
	reserve_units -= 8
	carried_units = 8
	return true

func restock() -> bool:
	if carried_units != 8:
		return false
	shop_units += carried_units
	carried_units = 0
	return true

func setup_sound() -> void:
	var listener := AudioListener3D.new()
	get_node("../../Player").add_child(listener)
	listener.position.y = 0.8
	listener.make_current()
	ambient(Vector3(-4.8,0.9,-3.6),false,-30.0,6.0)
	ambient(Vector3(10,1,-3),false,-35.0,5.0)
	ambient(Vector3(9.5,1,-7),true,-28.0,8.0)
	for item in doors + [get_parent().get_node("Door")]:
		var sound := AudioStreamPlayer3D.new()
		sound.stream = synth(false,false)
		sound.volume_db = -22
		sound.max_distance = 7
		item.add_child(sound)
		sound.set_meta("base_volume",-22.0)
		sounds.append(sound)
		previous_motion[item] = false
		item.set_meta("motion_sound",sound)

func ambient(at: Vector3, wind: bool, volume: float, distance: float) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.position = at
	sound.stream = synth(wind,true)
	sound.volume_db = volume
	sound.max_distance = distance
	sound.set_meta("base_volume",volume)
	add_child(sound)
	sounds.append(sound)
	sound.play()

func _process(_delta: float) -> void:
	var muted: bool = get_node("../../").muted
	for sound in sounds:
		sound.volume_db = -80.0 if muted else float(sound.get_meta("base_volume"))
	for item in previous_motion:
		if item.moving and not previous_motion[item]:
			item.get_meta("motion_sound").play()
		previous_motion[item] = item.moving

func _exit_tree() -> void:
	for sound in sounds:
		sound.stop()
		sound.stream = null

func synth(wind: bool, looping: bool) -> AudioStreamWAV:
	var rate := 16000
	var count := rate * 4 if looping else int(rate * 0.45)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 410
	var filtered := 0.0
	for i in count:
		var t := float(i) / rate
		filtered = lerpf(filtered,rng.randf_range(-1,1),0.06)
		var value := filtered * (0.55 + 0.2*sin(TAU*t/4)) if wind else sin(TAU*100*t)*0.16+sin(TAU*200*t)*0.04
		if wind and looping:
			value *= minf(1.0,minf(t/0.08,(4.0-t)/0.08))
		if not looping:
			value = (filtered*0.8+sin(TAU*180*t)*0.08)*sin(PI*float(i)/count)
		bytes.encode_s16(i*2,int(clampf(value,-1,1)*24000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
