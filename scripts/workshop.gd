extends Node3D

const Rules = preload("res://scripts/rules.gd")
const Store = preload("res://scripts/save_store.gd")
const Visual = preload("res://scripts/staff_visual.gd")
const Lab = preload("res://scripts/spells.gd")
const Interface = preload("res://scripts/ui.gd")

var rules: ForgeRules
var store: SaveStore
var run: Dictionary
var settings: Dictionary
var design: Dictionary
var ui: ForgeUI
var spells: SpellLab
var world: Node3D
var player: CharacterBody3D
var head: Node3D
var player_camera: Camera3D
var station_camera: Camera3D
var held_staff: StaffVisual
var assembly_staff: StaffVisual
var infusion_staff: StaffVisual
var showcase_staff: StaffVisual
var stations: Array[Dictionary] = []
var lights: Array[OmniLight3D] = []
var sound_players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer
var sound_cursor := 0
var font: Font
var mode := "menu"
var paused := false
var started := false
var has_save := false
var cast_cooldown := 0.0
var yaw := 0.0
var pitch := 0.0
var elapsed := 0.0
var save_timer := 0.0
var shake_time := 0.0
var step_timer := 0.0
var nearest_station := ""
var smoke_mode := false
var smoke_report := {"checks": [], "failures": [], "frames_ms": []}
var last_frame_time := 0
var smoke_save_folder := ""
var exiting := false
var ritual_orbits: Array[Node3D] = []
var ritual_lamp: OmniLight3D
var infusion_feedback := ""
var infusion_feedback_color := Color("#d8bd85")
var feedback_time := 0.0
var environmental_story: RefCounted
var nearest_clue := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	rules = Rules.new()
	smoke_mode = "--smoke-test" in OS.get_cmdline_user_args()
	var folder := "user://"
	if smoke_mode:
		smoke_save_folder = ProjectSettings.globalize_path("res://artifacts/smoke-save") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir().path_join("verification/smoke-save")
		DirAccess.make_dir_recursive_absolute(smoke_save_folder)
		folder = smoke_save_folder
	store = Store.new(rules, folder)
	settings = store.load_settings()
	run = store.load_run()
	has_save = not run.is_empty()
	if run.is_empty() or smoke_mode:
		run = rules.new_run(20261009 if smoke_mode else 0)
		has_save = false if smoke_mode else has_save
	design = run.blueprint.duplicate(true)
	var font_variation := FontVariation.new()
	font_variation.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	font_variation.variation_opentype = {2003265652: 500.0} # OpenType "wght" axis.
	font = font_variation
	build_world()
	build_player()
	build_audio()
	ui = Interface.new()
	add_child(ui)
	ui.configure(self, font)
	ui.requested.connect(_on_action)
	ui.design_changed.connect(_on_design_changed)
	spells.report_changed.connect(func(_text): ui.update_live())
	refresh_visuals()
	apply_settings()
	main_menu()
	if not store.notice.is_empty():
		ui.toast(store.notice, false)
	if smoke_mode:
		call_deferred("run_smoke_test")

func mat(color: String, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	return Visual.material(Color(color), metal, emission)

func stone(color: String, tiles: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/stone.gdshader")
	material.set_shader_parameter("stone_color", Color(color))
	material.set_shader_parameter("tiles", tiles)
	return material

func wood_material(color: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/wood.gdshader")
	material.set_shader_parameter("wood_color", Color(color))
	return material

func mesh_part(mesh: Mesh, at: Vector3, material: Material, parent: Node3D = world) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func box(size_value: Vector3, at: Vector3, material: Material, solid: bool = false, parent: Node3D = world) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var result := mesh_part(mesh, at, material, parent)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size_value
		shape.shape = collision
		body.add_child(shape)
		body.position = at
		parent.add_child(body)
	return result

func cylinder(radius: float, height: float, at: Vector3, material: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 24
	return mesh_part(mesh, at, material)

func ring(radius: float, tube: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 32
	mesh.ring_segments = 8
	return mesh_part(mesh, at, material)

func label3d(text_value: String, at: Vector3, color: Color, size_value: int = 40) -> Label3D:
	var text := Label3D.new()
	text.text = text_value
	text.font = font
	text.font_size = size_value
	text.pixel_size = 0.0035
	text.outline_size = 5
	text.modulate = color
	text.position = at
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.add_to_group("workshop_signs")
	world.add_child(text)
	return text

func light(at: Vector3, color: String, energy: float, range_value: float = 5.0) -> OmniLight3D:
	var node := OmniLight3D.new()
	node.position = at
	node.light_color = Color(color)
	node.light_energy = energy
	node.omni_range = range_value
	node.omni_attenuation = 1.2
	node.shadow_enabled = false
	world.add_child(node)
	return node

func build_world() -> void:
	world = Node3D.new()
	world.name = "WorkshopWorld"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	load("res://scripts/gothic_scene.gd").new(self).build()
	build_stations(wood_material("#59402b"), mat("#b89357", 0.78))
	environmental_story = load("res://scripts/environmental_story.gd").new(self)
	environmental_story.build()
	spells = Lab.new()
	world.add_child(spells)
	spells.configure(font)
	station_camera = Camera3D.new()
	station_camera.fov = 43
	station_camera.near = 0.05
	add_child(station_camera)

func import_model(model_name: String, at: Vector3, scale_value: Vector3, yaw_value: float, material: Material) -> Node3D:
	var path_value := "res://assets/models/" + model_name + ".glb"
	if not ResourceLoader.exists(path_value):
		return null
	var scene: PackedScene = load(path_value)
	var model := scene.instantiate() as Node3D
	model.position = at
	model.scale = scale_value
	model.rotation.y = yaw_value
	world.add_child(model)
	override_material(model, material)
	return model

func override_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		override_material(child, material)

func add_station(id: String, name_value: String, position_value: Vector3, color: String, number: String) -> void:
	stations.append({"id": id, "name": name_value, "position": position_value})
	label3d(number + "  " + name_value, position_value + Vector3(0, 2.4, 0), Color(color), 42)
	var floor_ring := ring(0.8, 0.018, position_value + Vector3(0, 0.025, 0), mat(color, 0, 0.4))
	floor_ring.scale.y = 0.2

func workbench(at: Vector3, wood: Material, metal: Material) -> void:
	box(Vector3(2.7, 0.16, 1.4), at + Vector3(0, 0.92, 0), wood, true)
	box(Vector3(2.66, 0.026, 1.38), at + Vector3(0, 1.015, 0), metal)
	box(Vector3(2.56, 0.032, 1.28), at + Vector3(0, 1.04, 0), wood)
	box(Vector3(2.7, 0.25, 0.1), at + Vector3(0, 0.73, 0.64), mat("#25272d", 0.3))
	for x in [-1.26, 1.26]:
		box(Vector3(0.025, 0.006, 1.25), at + Vector3(x, 1.058, 0), metal)
	for x in [-1.05, 1.05]:
		for z in [-0.48, 0.48]:
			box(Vector3(0.16, 0.90, 0.16), at + Vector3(x, 0.45, z), wood)
			box(Vector3(0.2, 0.07, 0.2), at + Vector3(x, 0.12, z), metal)
	box(Vector3(2.5, 0.12, 0.15), at + Vector3(0, 0.22, -0.48), wood)
	for z in [-0.57, 0.57]:
		box(Vector3(2.5, 0.008, 0.018), at + Vector3(0, 1.062, z), metal)

func build_stations(wood: Material, metal: Material) -> void:
	var assembly_at := Vector3(-4.5, 0, -1.5)
	workbench(assembly_at, wood, metal)
	add_station("assembly", "组装台", assembly_at, "#d1b67d", "01")
	cylinder(0.3, 0.12, assembly_at + Vector3(0, 1.1, 0), metal)
	assembly_staff = Visual.new()
	assembly_staff.position = assembly_at + Vector3(0, 1.15, 0)
	world.add_child(assembly_staff)
	for i in range(3):
		var gem := SphereMesh.new()
		gem.radius = 0.075
		gem.height = 0.14
		gem.radial_segments = 5
		gem.rings = 2
		mesh_part(gem, assembly_at + Vector3(-0.8 + i * 0.24, 1.14, 0.15), mat(["#ff9d5c", "#78d9fa", "#b7a0ff"][i], 0.3, 0.7))
	import_model("books", assembly_at + Vector3(0.9, 1.07, -0.2), Vector3(0.8, 0.8, 0.8), 0.3, mat("#8b8461"))
	light(assembly_at + Vector3(0, 2.8, 0.4), "#fce0ad", 1.4, 4.0)
	var infusion_at := Vector3(4.5, 0, -1.5)
	var altar_collision := StaticBody3D.new()
	var altar_shape := CollisionShape3D.new()
	var altar_volume := CylinderShape3D.new()
	altar_volume.radius = 0.90
	altar_volume.height = 1.20
	altar_shape.shape = altar_volume
	altar_collision.position = infusion_at + Vector3(0, 0.60, 0)
	altar_collision.add_child(altar_shape)
	world.add_child(altar_collision)
	add_station("infusion", "灌注台", infusion_at, "#89ded0", "02")
	var obsidian := stone("#222831", 6)
	obsidian.set_shader_parameter("polish", 0.35)
	cylinder(1.08, 0.16, infusion_at + Vector3(0, 0.08, 0), obsidian)
	cylinder(0.90, 0.12, infusion_at + Vector3(0, 0.20, 0), metal)
	cylinder(0.68, 0.80, infusion_at + Vector3(0, 0.66, 0), obsidian, 0.53)
	cylinder(0.77, 0.06, infusion_at + Vector3(0, 1.09, 0), metal)
	cylinder(0.74, 0.08, infusion_at + Vector3(0, 1.16, 0), obsidian)
	for radius_value in [0.64, 0.48, 0.27]:
		ring(radius_value, 0.008, infusion_at + Vector3(0, 1.205, 0), mat("#71c4bf", 0.45, 0.3))
	for i in range(12):
		var angle := float(i) * TAU / 12.0
		var glyph := box(Vector3(0.026, 0.008, 0.075), infusion_at + Vector3(cos(angle) * 0.57, 1.208, sin(angle) * 0.57), metal)
		glyph.rotation.y = -angle
	for i in range(3):
		var angle := float(i) * TAU / 3.0 + PI * 0.5
		var offset := Vector3(cos(angle) * 0.89, 0, sin(angle) * 0.89)
		cylinder(0.11, 1.34, infusion_at + offset + Vector3(0, 0.9, 0), obsidian, 0.07)
		cylinder(0.13, 0.06, infusion_at + offset + Vector3(0, 1.56, 0), metal)
		mesh_part(Visual.crystal_mesh(0.048, 0.16), infusion_at + offset + Vector3(0, 1.70, 0), mat("#70c7cd", 0.3, 0.45))
	for i in range(2):
		var orbit := Node3D.new()
		orbit.position = infusion_at + Vector3(0, 1.30 + float(i) * 0.18, 0)
		orbit.rotation.x = 0.13 if i == 0 else -0.16
		world.add_child(orbit)
		ritual_orbits.append(orbit)
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.87 + float(i) * 0.1
		mesh.outer_radius = mesh.inner_radius + 0.013
		mesh.rings = 48
		mesh.ring_segments = 6
		mesh_part(mesh, Vector3.ZERO, metal if i == 0 else mat("#60b4ba", 0.45, 0.3), orbit)
	infusion_staff = Visual.new()
	infusion_staff.position = infusion_at + Vector3(0, 1.25, 0)
	world.add_child(infusion_staff)
	ritual_lamp = light(infusion_at + Vector3(0, 2.8, 1.1), "#ffcd91", 1.6, 4.2)
	ritual_lamp.shadow_enabled = true
	light(infusion_at + Vector3(-1.0, 2.1, -0.5), "#91cde8", 0.8, 2.7)
	var room_art = load("res://scripts/gothic_scene.gd").new(self)
	room_art.candles(infusion_at + Vector3(1.25, 0.16, -0.6), 3)
	room_art.candles(assembly_at + Vector3(-0.98, 1.065, -0.42), 3)
	var supply_at := Vector3(-6.5, 0, 3.4)
	workbench(supply_at, wood, metal)
	add_station("supply", "材料架", supply_at, "#d3bb8c", "·")
	for i in range(7):
		var pole := cylinder(0.035, 0.75, supply_at + Vector3(-0.85 + float(i) * 0.12, 1.13, 0.15), wood)
		pole.rotation.z = PI * 0.5
	box(Vector3(0.65, 0.3, 0.6), supply_at + Vector3(0.75, 1.19, 0), metal)
	var relic_at := Vector3(6.5, 0, 3.4)
	workbench(relic_at, wood, metal)
	add_station("relic", "遗物柜", relic_at, "#c3a4e5", "04")
	box(Vector3(2.1, 1.1, 0.25), relic_at + Vector3(0, 1.58, -0.44), mat("#252a34"), true)
	for i in range(6):
		var x := (float(i % 3) - 1.0) * 0.55
		var y := 1.38 + float(i / 3) * 0.44
		var artifact_ring := ring(0.10, 0.014, relic_at + Vector3(x, y, -0.24), mat("#d6b78a", 0.8, 0.35))
		artifact_ring.rotation.x = PI * 0.5
	light(relic_at + Vector3(0, 2.6, 0), "#c0a0ec", 1.2, 4)
	var seal_at := Vector3(0, 0, 6.8)
	add_station("seal", "封印祭台", seal_at, "#85dbcf", "05")
	cylinder(1.1, 0.22, seal_at + Vector3(0, 0.11, 0), mat("#3b4549"), 1.0)
	cylinder(0.65, 0.85, seal_at + Vector3(0, 0.62, 0), mat("#3b4549", 0.3), 0.48)
	ring(0.75, 0.018, seal_at + Vector3(0, 1.13, 0), mat("#85dbcf", 0, 1.0))
	for r in [0.35, 0.55, 0.7]:
		var orbit := ring(r, 0.012, seal_at + Vector3(0, 1.95, 0), mat("#d4b77a", 0.8, 0.3))
		orbit.rotation = Vector3(PI * 0.5, r, r * 0.8)
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	mesh_part(sphere, seal_at + Vector3(0, 1.95, 0), mat("#8ad5c7", 0.2, 1.1))
	light(seal_at + Vector3(0, 2.0, 0), "#7addd2", 1.5, 5)
	add_station("lab", "试法长廊", Vector3(0, 0, -4.6), "#93cce6", "03")
	for x in [-4.5, 4.5]:
		cylinder(0.18, 3.6, Vector3(x, 1.8, -4.5), mat("#414c51"))
		cylinder(0.3, 0.18, Vector3(x, 3.64, -4.5), metal)
	light(Vector3(0, 3.8, -8.8), "#9cc8e4", 0.5, 6)
	label3d("火 · 霜 · 雷\n试验你的造物", Vector3(0, 3.6, -10.7), Color("#95afbe"), 45)
	showcase_staff = Visual.new()
	showcase_staff.position = Vector3(-0.2, 0.5, -1.1)
	showcase_staff.rotation.z = -0.2
	world.add_child(showcase_staff)
	cylinder(0.45, 0.3, Vector3(-0.2, 0.15, -1.1), mat("#2d3b41", 0.4))

func build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.02, 3.8)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.72
	collider.shape = capsule
	collider.position.y = 0.86
	player.add_child(collider)
	add_child(player)
	head = Node3D.new()
	head.position.y = 1.65
	player.add_child(head)
	player_camera = Camera3D.new()
	player_camera.fov = 68
	player_camera.near = 0.025
	head.add_child(player_camera)
	held_staff = Visual.new()
	held_staff.position = Vector3(0.39, -0.91, -0.53)
	held_staff.rotation = Vector3(-0.08, 0.0, -0.18)
	held_staff.scale = Vector3.ONE * 0.64
	held_staff.process_mode = Node.PROCESS_MODE_PAUSABLE
	player_camera.add_child(held_staff)

func build_audio() -> void:
	for i in range(5):
		var node := AudioStreamPlayer.new()
		node.volume_db = -12.0
		add_child(node)
		sound_players.append(node)
	ambient_player = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/ambience.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	ambient_player.stream = stream
	ambient_player.volume_db = -22.0
	ambient_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(ambient_player)
	ambient_player.play()

func sound(kind: String, pitch_value: float = 1.0) -> void:
	var path_value := "res://assets/audio/" + kind + ".ogg"
	if ResourceLoader.exists(path_value):
		var node := sound_players[sound_cursor % sound_players.size()]
		sound_cursor += 1
		node.stream = load(path_value)
		node.pitch_scale = pitch_value
		node.play()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.00001, float(settings.volume))))
	if not smoke_mode:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or mode != "walk" else Input.MOUSE_MODE_CAPTURED

func save() -> bool:
	run.blueprint = design.duplicate(true)
	var success := store.save_run(run)
	if not success and is_instance_valid(ui):
		ui.toast(store.notice, false)
	return success

func commit(action: Callable) -> Dictionary:
	var before := run.duplicate(true)
	var result: Dictionary = action.call()
	if result.ok and not save():
		run = before
		result = rules.fail("自动保存失败，本次操作已撤回。")
	ui.toast(result.message, result.ok)
	return result

func main_menu() -> void:
	mode = "menu"
	set_lab_labels(false)
	started = false
	set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	showcase_staff.visible = true
	for sign_node in get_tree().get_nodes_in_group("workshop_signs"):
		sign_node.visible = false
	station_camera.position = Vector3(3.2, 2.05, 3.4)
	station_camera.look_at(Vector3(-0.1, 1.3, -1.1))
	station_camera.current = true
	ui.show_menu(has_save)

func begin_game(new_game: bool) -> void:
	if new_game:
		var previous := run.duplicate(true)
		run = rules.new_run(20261009 if smoke_mode else 0, run if has_save else {})
		design = run.blueprint.duplicate(true)
		if not save():
			run = previous
			design = run.blueprint.duplicate(true)
			return
		has_save = true
	started = true
	set_paused(false)
	showcase_staff.visible = false
	player.position = Vector3(0, 0.02, 3.8)
	yaw = 0
	pitch = 0
	if run.status != "playing":
		mode = "ending"
		ui.show_ending()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	close_station()
	refresh_visuals()
	if new_game:
		ui.toast("五夜契约开始。先到左侧材料架领取材料。")

func close_station() -> void:
	if run.status != "playing":
		mode = "ending"
		set_paused(true)
		ui.show_ending()
		return
	mode = "walk"
	set_paused(false)
	player_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if smoke_mode else Input.MOUSE_MODE_CAPTURED
	ui.show_walk()
	for sign_node in get_tree().get_nodes_in_group("workshop_signs"):
		sign_node.visible = true
	refresh_visuals()

func open_station(station: String) -> void:
	mode = station
	set_lab_labels(station == "lab")
	set_paused(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for sign_node in get_tree().get_nodes_in_group("workshop_signs"):
		sign_node.visible = false
	match station:
		"assembly":
			station_camera.position = Vector3(-3.50, 2.42, 2.75)
			station_camera.look_at(Vector3(-4.5, 1.91, -1.5))
		"infusion":
			station_camera.position = Vector3(5.75, 2.50, 2.80)
			station_camera.look_at(Vector3(4.5, 2.0, -1.5))
		"lab":
			station_camera.position = Vector3(0, 1.8, -2.0)
			station_camera.look_at(Vector3(0, 1.4, -7.5))
		"seal":
			station_camera.position = Vector3(0, 2.5, 3.4)
			station_camera.look_at(Vector3(0, 1.65, 6.8))
		"relic":
			station_camera.position = Vector3(6.5, 2.0, 6.65)
			station_camera.look_at(Vector3(6.5, 1.5, 3.4))
		"supply":
			station_camera.position = Vector3(-6.5, 2.0, 6.65)
			station_camera.look_at(Vector3(-6.5, 1.3, 3.4))
		"inventory":
			station_camera.global_transform = player_camera.global_transform
	station_camera.current = true
	refresh_visuals()
	ui.show_station(station)

func refresh_visuals() -> void:
	assembly_staff.rebuild(design)
	var staff := rules.active(run)
	var show_design: Dictionary = design if staff.is_empty() else staff.design
	var level_value := 0 if staff.is_empty() else int(staff.level)
	var tree: Array = staff.get("tree", [])
	infusion_staff.rebuild(show_design, level_value, tree)
	infusion_staff.visible = not staff.is_empty()
	held_staff.rebuild(show_design, level_value, tree)
	held_staff.visible = not staff.is_empty()
	showcase_staff.rebuild(show_design, maxi(9, level_value), tree)
	environmental_story.refresh()

func _on_design_changed(design_value: Dictionary) -> void:
	if rules.design_valid(design_value):
		design = design_value.duplicate(true)
		assembly_staff.rebuild(design)

func _on_action(action: String, payload: Variant = null) -> void:
	if exiting:
		return
	if action != "infuse" and action != "cast":
		sound("click", 1.05)
	match action:
		"new_confirm":
			mode = "menu"
			set_paused(true)
			ui.show_menu(true, true)
		"new_run": begin_game(true)
		"continue": begin_game(false)
		"menu": main_menu()
		"save_menu":
			if save():
				has_save = true
				main_menu()
		"quit":
			if not started or save():
				shutdown(0)
		"close", "resume": close_station()
		"settings":
			set_paused(true)
			ui.show_settings()
		"setting":
			settings[payload.key] = payload.value
			apply_settings()
			if not store.save_settings(settings):
				ui.toast(store.notice, false)
		"settings_done", "help_done":
			if started:
				mode = "pause"
				ui.show_pause()
			else:
				main_menu()
		"help":
			set_paused(true)
			ui.show_help()
		"claim":
			var result := commit(func(): return rules.claim(run))
			if result.ok:
				open_station("supply")
		"craft":
			var result := commit(func(): return rules.craft(run, design))
			if result.ok:
				refresh_visuals()
				sound("bell", 1.6)
				ui.show_station(mode)
		"select":
			var result := commit(func(): return rules.select_staff(run, int(payload)))
			if result.ok:
				refresh_visuals()
				ui.show_station(mode)
		"infuse":
			var result := commit(func(): return rules.infuse(run))
			if result.ok:
				refresh_visuals()
				infusion_staff.flash(1.5 if result.outcome == "great" or result.activated else 0.75)
				animate_infusion(result)
				sound("break" if result.outcome == "break" else "infuse", 0.75 + float(result.level) * 0.035)
				shake_time = 0.3 if settings.shake else 0.0
				ui.show_station(mode)
		"journal":
			mode = "journal"
			set_paused(true)
			ui.show_journal()
		"tree":
			open_station("infusion")
			mode = "tree"
			set_paused(true)
			ui.show_tree()
		"branch":
			var result := commit(func(): return rules.choose_branch(run, str(payload)))
			if result.ok:
				refresh_visuals()
				ui.show_tree()
		"back_to_infusion": open_station("infusion")
		"inspect":
			var entry: Dictionary = rules.chronicle.clue(str(payload))
			var result := commit(func(): return rules.chronicle.discover(run, str(payload)))
			if result.ok or result.get("reread", false):
				environmental_story.refresh()
				mode = "story"
				set_paused(true)
				ui.show_story(entry.name, entry.text)
		"cast": cast_spell()
		"reset_targets": spells.reset_targets()
		"buy":
			var result := commit(func(): return rules.buy_relic(run, str(payload)))
			if result.ok:
				refresh_visuals()
				ui.show_station(mode)
				sound("bell", 1.2)
		"offer":
			var result := commit(func(): return rules.offer_staff(run))
			if result.ok:
				refresh_visuals()
				ui.show_station(mode)
				sound("bell", 0.85)
				if not result.get("story", {}).is_empty():
					mode = "story"
					set_paused(true)
					ui.show_story(result.story.title, result.story.text)
		"settle_confirm":
			mode = "confirm"
			set_paused(true)
			ui.show_settle_confirmation()
		"back_to_seal": open_station("seal")
		"settle":
			var result := commit(func(): return rules.settle(run))
			if result.ok:
				sound("bell", 0.7)
				set_paused(false)
				if run.status == "playing":
					close_station()
					ui.toast("第 %d 夜到来。新的材料已放上材料架。" % run.day)
				else:
					mode = "ending"
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					ui.show_ending()

func animate_infusion(result: Dictionary) -> void:
	var colors := {"success": infusion_staff.element_color, "great": Color("#f2cd85"),
		"hold": Color("#9da8be"), "damage": Color("#ec826c"), "break": Color("#c14c64")}
	var color: Color = colors[result.outcome]
	infusion_feedback_color = color
	feedback_time = 2.8
	if result.outcome == "break":
		infusion_feedback = "晶核崩解\n蓝图仍在 · 重新组装即可"
	else:
		var titles := {"success": "灌注成功", "great": "大成功 · 双阶跃升", "hold": "能量停滞", "damage": "晶核受损"}
		infusion_feedback = "%s\n+%d → +%d · %s" % [titles[result.outcome], result.previous_level, result.level, Visual.evolution_name(result.level)]
	var center := Vector3(4.5, 2.55, -1.5)
	spells.sparks(center, color)
	var arc_count := 0 if result.outcome == "hold" else (1 if result.outcome == "damage" else 3)
	for i in range(arc_count):
		var angle := float(i) * TAU / 3.0 + PI * 0.5
		spells.beam(Vector3(4.5 + cos(angle) * 0.89, 1.70, -1.5 + sin(angle) * 0.89), center, color, true)
	var wave := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.65
	mesh.outer_radius = 0.663
	mesh.rings = 64
	mesh.ring_segments = 6
	wave.mesh = mesh
	var material := mat("#ffffff", 0.3, 0.4)
	material.albedo_color = Color(color, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = material
	wave.position = Vector3(4.5, 1.25, -1.5)
	world.add_child(wave)
	var tween := wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3(1.85, 0.5, 1.85), 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.70)
	tween.chain().tween_callback(wave.queue_free)
	if result.outcome == "great":
		spells.sparks(center + Vector3(0, 0.2, 0), Color("#ffedc6"))
	elif result.outcome == "break":
		for i in range(9):
			var fragment := MeshInstance3D.new()
			fragment.mesh = Visual.crystal_mesh(0.025, 0.14)
			fragment.position = center + Vector3(0, -float(i % 4) * 0.22, 0)
			fragment.rotation = Vector3(float(i), float(i) * 0.4, 0)
			var shard_material := mat("#bc5b68", 0.2, 0.25)
			shard_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fragment.material_override = shard_material
			world.add_child(fragment)
			var scatter := fragment.create_tween().set_parallel(true)
			var angle := float(i) * TAU / 9.0
			scatter.tween_property(fragment, "position", fragment.position + Vector3(cos(angle) * 0.7, -0.65, sin(angle) * 0.7), 0.65)
			scatter.tween_property(shard_material, "albedo_color:a", 0.0, 0.70)
			scatter.chain().tween_callback(fragment.queue_free)

func cast_spell(aim_override: Variant = null) -> Dictionary:
	if cast_cooldown > 0.01 or mode != "lab":
		return {"ok": false}
	var staff := rules.active(run)
	if staff.is_empty():
		ui.toast("没有法杖。先在组装台制作一根。", false)
		return {"ok": false}
	var spell := rules.stats(staff.design, int(staff.level), staff.get("tree", []))
	var aim := Vector3(0, 1.35, -7.5)
	if aim_override is Vector3:
		aim = aim_override
	else:
		var mouse := get_viewport().get_mouse_position()
		var from := station_camera.project_ray_origin(mouse)
		var direction := station_camera.project_ray_normal(mouse)
		if absf(direction.z) > 0.001:
			aim = from + direction * ((-7.5 - from.z) / direction.z)
	var outcome := spells.cast(spell, station_camera.global_position + Vector3(0.3, -0.35, -0.5), aim)
	cast_cooldown = float(spell.cooldown)
	run.tutorial_step = maxi(int(run.tutorial_step), 4)
	save()
	sound("infuse", 1.8 if spell.element == "lightning" else (1.45 if spell.element == "ice" else 0.85))
	shake_time = 0.18 if settings.shake else 0.0
	ui.update_live()
	outcome["ok"] = true
	return outcome

func set_lab_labels(visible_value: bool) -> void:
	for target in spells.targets:
		target.label.visible = visible_value
	for effect in spells.effects.get_children():
		if effect is Label3D:
			effect.visible = visible_value

func _process(delta: float) -> void:
	if smoke_mode:
		var now := Time.get_ticks_usec()
		if last_frame_time > 0:
			smoke_report.frames_ms.append(float(now - last_frame_time) / 1000.0)
		last_frame_time = now
	if paused:
		return
	elapsed += delta
	feedback_time = maxf(0, feedback_time - delta)
	for i in range(lights.size()):
		lights[i].light_energy = 0.8 + sin(elapsed * 3.1 + float(i)) * 0.07
	for i in range(ritual_orbits.size()):
		ritual_orbits[i].rotate_y(delta * (0.35 if i == 0 else -0.25))
	if not started or run.status != "playing":
		return
	rules.tick(run, delta)
	spells.advance(delta)
	set_lab_labels(mode == "lab")
	cast_cooldown = maxf(0.0, cast_cooldown - delta)
	save_timer += delta
	if save_timer >= 2.0:
		save_timer = 0.0
		save()
	if shake_time > 0.0:
		shake_time = maxf(0, shake_time - delta)
		var active_camera := get_viewport().get_camera_3d()
		active_camera.rotation.z = sin(elapsed * 82.0) * shake_time * 0.012
	else:
		station_camera.rotation.z = 0.0
		player_camera.rotation.z = 0.0
	ui.update_live()
	if mode == "walk":
		update_prompt()

func _physics_process(delta: float) -> void:
	if not started or paused or mode != "walk" or run.status != "playing":
		return
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	input = input.normalized()
	var direction := player.transform.basis * Vector3(input.x, 0, input.y)
	var speed := 3.1
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y - 9.8 * delta
	player.move_and_slide()
	if input.length() > 0.1:
		step_timer -= delta
		if step_timer <= 0:
			step_timer = 0.55
			sound("step", 0.85)
		held_staff.position.y = -0.91 + sin(elapsed * 9.0) * 0.016

func update_prompt() -> void:
	nearest_station = ""
	nearest_clue = ""
	var nearest_distance := 2.65
	var forward := -player.global_basis.z
	for station in stations:
		var offset: Vector3 = station.position - player.position
		offset.y = 0
		var distance := offset.length()
		if distance < nearest_distance and forward.dot(offset.normalized()) > 0.2:
			nearest_station = station.id
			nearest_distance = distance
			ui.prompt_label.text = "[ E ]  " + station.name
	if nearest_station.is_empty():
		ui.prompt_label.text = ""
	for item in environmental_story.clues:
		var offset: Vector3 = item.position - player.position
		offset.y = 0
		if offset.length() < 1.35 and forward.dot(offset.normalized()) > 0.55:
			nearest_clue = item.entry.id
			ui.prompt_label.text = "[ E ]  调查 · " + str(item.entry.name)
			break

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if mode == "walk":
				mode = "pause"
				set_paused(true)
				save()
				ui.show_pause()
			elif ui.mode in ["settings", "help"]:
				_on_action("settings_done")
			elif mode == "pause":
				close_station()
			elif mode == "tree":
				open_station("infusion")
			elif mode in ["journal", "story", "assembly", "infusion", "lab", "supply", "relic", "seal", "inventory", "confirm"]:
				close_station()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E and mode == "walk":
			if not nearest_clue.is_empty():
				_on_action("inspect", nearest_clue)
			elif not nearest_station.is_empty():
				open_station(nearest_station)
		elif event.keycode == KEY_J and started and mode != "menu":
			if mode == "journal":
				close_station()
			else:
				_on_action("journal")
		elif event.keycode == KEY_T and started and mode not in ["menu", "ending", "story"]:
			if mode == "tree":
				open_station("infusion")
			else:
				_on_action("tree")
		elif event.keycode == KEY_TAB and started and not paused:
			close_station() if mode == "inventory" else open_station("inventory")
		elif event.keycode == KEY_SPACE and not paused:
			if mode == "infusion":
				_on_action("infuse")
			elif mode == "lab":
				cast_spell(Vector3(0, 1.35, -7.5))
		elif event.keycode == KEY_R and mode == "lab" and not paused:
			spells.reset_targets()
	if paused:
		return
	if event is InputEventMouseMotion:
		if mode == "walk" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			yaw -= event.relative.x * float(settings.sensitivity)
			pitch = clampf(pitch - event.relative.y * float(settings.sensitivity), -1.2, 1.2)
			player.rotation.y = yaw
			head.rotation.x = pitch
		elif mode == "assembly" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			assembly_staff.rotation.y += event.relative.x * 0.01
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and mode == "lab":
		cast_spell()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(ui):
		_on_action("quit")

func shutdown(exit_code: int) -> void:
	if exiting:
		return
	exiting = true
	set_paused(true)
	ambient_player.stop()
	ambient_player.stream = null
	for audio in sound_players:
		audio.stop()
		audio.stream = null
	# Give the native audio mixer a frame to release its playback references.
	await get_tree().create_timer(0.12, true).timeout
	get_tree().quit(exit_code)

func smoke_check(condition: bool, caption: String) -> void:
	smoke_report.checks.append({"name": caption, "passed": condition})
	if not condition:
		smoke_report.failures.append(caption)
		push_error("SMOKE FAIL: " + caption)

func smoke_capture(name_value: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://artifacts/screenshots")
	if not OS.has_feature("editor"):
		folder = OS.get_executable_path().get_base_dir().path_join("verification/screenshots")
	DirAccess.make_dir_recursive_absolute(folder)
	var image := get_viewport().get_texture().get_image()
	image.save_png(folder.path_join(name_value + ".png"))
	var labels: Array = []
	inspect_labels(ui.root, labels)
	var metadata := FileAccess.open(folder.path_join(name_value + "-layout.json"), FileAccess.WRITE)
	metadata.store_string(JSON.stringify(labels, "\t"))
	metadata.close()

func inspect_labels(node: Node, result: Array) -> void:
	if node is Label and node.is_visible_in_tree():
		result.append({"text": node.text, "rect": str(node.get_global_rect()),
			"minimum": str(node.get_combined_minimum_size()), "color": str(node.get_theme_color("font_color")),
			"modulate": str(node.modulate), "clip": node.clip_text})
	for child in node.get_children():
		inspect_labels(child, result)

func smoke_choose_outcome(staff: Dictionary, desired: String) -> void:
	var odds := rules.probabilities(run, staff)
	var lower := 0.0
	for key in ["break", "success", "great", "hold", "damage"]:
		var upper := lower + float(odds[key])
		if key == desired:
			for seed_value in range(1, 1000):
				var rng := RandomNumberGenerator.new()
				rng.seed = seed_value
				var before := str(rng.state)
				var ticket := rng.randf()
				if ticket > lower and ticket < upper:
					run.rng_state = before
					return
		lower = upper
	smoke_check(false, "cannot select deterministic " + desired + " ticket")

func run_smoke_test() -> void:
	await get_tree().create_timer(0.4).timeout
	await smoke_capture("01-menu")
	smoke_check(ui.overlay.get_children().any(func(n): return n is PanelContainer), "main menu exists")
	_on_action("new_run")
	smoke_check(mode == "walk" and started, "new contract starts")
	var initial_position := player.position
	var walking := InputEventKey.new()
	walking.physical_keycode = KEY_W
	walking.keycode = KEY_W
	walking.pressed = true
	Input.parse_input_event(walking)
	await get_tree().create_timer(0.3).timeout
	walking = InputEventKey.new()
	walking.physical_keycode = KEY_W
	walking.keycode = KEY_W
	walking.pressed = false
	Input.parse_input_event(walking)
	smoke_check(player.position.z < initial_position.z - 0.3, "WASD movement advances character")
	player.position = Vector3(-6.5, 0.02, 5.2)
	player.rotation.y = 0
	update_prompt()
	smoke_check(nearest_station == "supply", "proximity finds material station")
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.pressed = true
	_unhandled_input(interact)
	smoke_check(mode == "supply", "E enters nearest station")
	open_station("supply")
	_on_action("claim")
	smoke_check(run.materials == 3, "station claim materials")
	_on_action("claim")
	smoke_check(run.materials == 3, "UI repeated claim safe")
	open_station("assembly")
	_on_action("craft")
	smoke_check(rules.usable(run).size() == 1, "station crafts")
	await get_tree().create_timer(0.25).timeout
	smoke_check(ui.stats_label.size.y > 25, "assembly stats text visible")
	await smoke_capture("02-assembly")
	open_station("infusion")
	_on_action("infuse")
	smoke_check(rules.active(run).cooldown > 0.0, "station infusion starts")
	smoke_check(spells.effects.is_visible_in_tree(), "shared infusion sparks stay visible outside spell lab")
	var old_rng: String = run.rng_state
	_on_action("infuse")
	smoke_check(run.rng_state == old_rng, "UI double infusion no reroll")
	var staff := rules.active(run)
	staff.charge = 6
	staff.cooldown = 0.0
	_on_action("infuse")
	smoke_check(staff.resonance > 0.0, "station activates resonance")
	mode = "pause"
	set_paused(true)
	var remaining: float = staff.resonance
	await get_tree().create_timer(0.3, true).timeout
	smoke_check(staff.resonance == remaining, "pause freezes resonance")
	ui.show_pause()
	await smoke_capture("03-pause")
	set_paused(false)
	open_station("infusion")
	await get_tree().process_frame
	await get_tree().process_frame
	smoke_check(ui.probability_label.size.y > 90, "probabilities text visible")
	await smoke_capture("04-infusion")
	var saved_staff := staff.duplicate(true)
	var saved_rng: String = run.rng_state
	staff.level = 0
	feedback_time = 0.0
	refresh_visuals()
	ui.show_station("infusion")
	await smoke_capture("10-evolution-00")
	for target_level in [3, 6, 9, 12]:
		staff.level = target_level - 1
		staff.cooldown = 0.0
		staff.resonance = 0.0
		staff.charge = 0
		# Select a documented deterministic success ticket; still call the real random rule.
		smoke_choose_outcome(staff, "success")
		_on_action("infuse")
		await get_tree().create_timer(0.32).timeout
		smoke_check(staff.level == target_level and infusion_staff.visible_level == target_level, "random upgrade updates model to +%d" % target_level)
		smoke_check(infusion_staff.evolution == Visual.evolution_stage(target_level), "correct visible evolution +%d" % target_level)
		await smoke_capture("10-evolution-%02d" % target_level)
	staff.level = 6
	staff.cooldown = 0.0
	staff.resonance = 0.0
	staff.charge = 0
	smoke_choose_outcome(staff, "damage")
	_on_action("infuse")
	smoke_check(staff.level == 5 and infusion_staff.evolution == 1, "random downgrade removes crystal crown")
	await get_tree().create_timer(0.25).timeout
	await smoke_capture("11-downgrade")
	staff.cooldown = 0.0
	staff.resonance = 0.0
	staff.charge = 0
	smoke_choose_outcome(staff, "break")
	_on_action("infuse")
	smoke_check(not staff.alive and rules.active(run).is_empty(), "random break removes staff from scene inventory")
	await get_tree().create_timer(0.25).timeout
	smoke_check(infusion_feedback.contains("晶核崩解"), "break presents dedicated visual feedback")
	await smoke_capture("11-break")
	for key in saved_staff:
		staff[key] = saved_staff[key]
	run.active_id = staff.id
	run.rng_state = saved_rng
	feedback_time = 0.0
	refresh_visuals()
	# Exercise all 9 element/head combinations with the same canonical stats.
	open_station("lab")
	for element in range(3):
		for head_value in range(3):
			staff.design.element = element
			staff.design.head = head_value
			cast_cooldown = 0.0
			spells.reset_targets()
			var result := cast_spell(Vector3(0, 1.35, -7.5))
			smoke_check(result.ok and result.hits > 0, "spell element%d head%d hits" % [element, head_value])
			if element == 0:
				spells.advance(0.6)
				smoke_check(spells.totals.burn_ticks > 0, "fire applies damage over time")
			elif element == 1:
				smoke_check(spells.totals.slow_applications > 0 and spells.targets.any(func(t): return t.slow > 0), "ice applies movement slow")
				if head_value == 0:
					var slowed_target: Dictionary = spells.targets.filter(func(t): return t.slow > 0)[0]
					var prior_phase: float = slowed_target.phase
					spells.advance(0.01)
					smoke_check(is_equal_approx(slowed_target.phase - prior_phase, 0.00144), "ice reduces motion speed by 82 percent")
			elif head_value == 0:
				smoke_check(spells.totals.chains > 0, "lightning chains")
			if head_value == 0:
				await smoke_capture("05-spell-%d" % element)
			await get_tree().create_timer(0.05).timeout
	staff.design = rules.default_design()
	staff.level = 5
	open_station("relic")
	_on_action("buy", "ward")
	smoke_check("ward" in run.relics and not staff.alive, "station exchange consumes staff")
	await smoke_capture("06-relics")
	open_station("assembly")
	_on_action("craft")
	staff = rules.active(run)
	staff.level = 5
	open_station("seal")
	_on_action("offer")
	smoke_check(run.offer > 0 and not staff.alive, "station offer consumes staff")
	await smoke_capture("07-seal")
	_on_action("settle")
	smoke_check(run.day == 2, "day advancement")
	smoke_check(save() and rules.validate_run(store.load_run()), "full scene save restores")
	open_station("assembly")
	_on_action("craft")
	smoke_check(not rules.active(run).is_empty(), "benchmark has an equipped staff")
	open_station("lab")
	# A real-render benchmark, without a fixed frame rate or preloaded frame count.
	var start_benchmark := Time.get_ticks_msec()
	smoke_report.frames_ms = []
	var benchmark_frames := 0
	var benchmark_casts := 0
	while Time.get_ticks_msec() - start_benchmark < 3000:
		if benchmark_frames % 50 == 0 and not rules.active(run).is_empty():
			cast_cooldown = 0.0
			cast_spell(Vector3(0, 1.35, -7.5))
			benchmark_casts += 1
		benchmark_frames += 1
		await get_tree().process_frame
	var benchmark_seconds := float(Time.get_ticks_msec() - start_benchmark) / 1000.0
	smoke_report["measured_fps"] = float(benchmark_frames) / benchmark_seconds
	smoke_report["benchmark_seconds"] = benchmark_seconds
	smoke_report["benchmark_casts"] = benchmark_casts
	smoke_report["window_size"] = str(DisplayServer.window_get_size())
	smoke_report["rendered_image_size"] = str(get_viewport().get_texture().get_size())
	smoke_report["renderer"] = RenderingServer.get_video_adapter_name()
	smoke_report["graphics_api"] = RenderingServer.get_video_adapter_api_version()
	smoke_report["engine"] = Engine.get_version_info().string
	smoke_report["resolution"] = str(get_viewport().get_visible_rect().size)
	smoke_report["processor"] = OS.get_processor_name()
	smoke_report["memory"] = OS.get_memory_info()
	# Endings are reached through the same public station action.
	for day in range(2, 6):
		run.offer = rules.balance.quotas[day - 1]
		_on_action("settle")
	smoke_check(run.status == "won", "five-day ending through scene")
	await smoke_capture("08-victory")
	var winning_save := run.duplicate(true)
	_on_action("new_run")
	for day in range(3):
		_on_action("settle")
	smoke_check(run.status == "lost" and run.misses == 3, "failure ending through scene")
	await smoke_capture("09-failure")
	await smoke_chronicle()
	run = winning_save
	design = run.blueprint.duplicate(true)
	save()
	var folder := ProjectSettings.globalize_path("res://artifacts")
	if not OS.has_feature("editor"):
		folder = OS.get_executable_path().get_base_dir().path_join("verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var output := FileAccess.open(folder.path_join("smoke-test.json"), FileAccess.WRITE)
	set_process(false)
	smoke_report.erase("frames_ms")
	output.store_string(JSON.stringify(smoke_report, "\t"))
	output.close()
	await get_tree().create_timer(1.3).timeout
	print("SCENE SMOKE: %d checks, %d failures, %.1f measured FPS" % [smoke_report.checks.size(), smoke_report.failures.size(), smoke_report.measured_fps])
	shutdown(0 if smoke_report.failures.is_empty() else 1)

func smoke_story_staff(changes: Dictionary, level_value: int) -> void:
	close_station()
	if int(run.unclaimed) > 0:
		_on_action("claim")
	design = rules.default_design()
	for key in changes:
		design[key] = changes[key]
	open_station("assembly")
	_on_action("craft")
	rules.active(run).level = level_value
	refresh_visuals()

func smoke_chronicle() -> void:
	run = rules.new_run(111)
	has_save = false
	_on_action("new_run")
	player.position = Vector3(-5.15, 0.02, 4.7)
	player.rotation.y = 0
	update_prompt()
	smoke_check(nearest_clue == "ledger", "environment proximity finds hidden ledger")
	var interact := InputEventKey.new()
	interact.keycode = KEY_E
	interact.pressed = true
	_unhandled_input(interact)
	smoke_check("ledger" in run.campaign.clues and mode == "story" and paused, "E discovers and pauses clue reading")
	await smoke_capture("12-clue")
	close_station()
	_on_action("inspect", "ledger")
	smoke_check(run.campaign.clues.size() == 1, "reread clue does not duplicate")
	await smoke_story_staff({}, 3)
	open_station("seal")
	# A failed write must roll back the offering AND its chapter in one transaction.
	var good_folder := store.folder
	store.folder = store.folder.path_join("nonexistent-directory")
	_on_action("offer")
	store.folder = good_folder
	smoke_check(run.offer == 0 and run.campaign.chapters.is_empty() and not rules.active(run).is_empty(), "failed save rolls back offering and story together")
	_on_action("offer")
	smoke_check(run.campaign.chapters == ["ember"] and mode == "story", "offering opens chapter in scene")
	await smoke_capture("13-story")
	_on_action("new_run")
	smoke_check(run.campaign.loop == 2 and "ember" in run.campaign.chapters and run.staffs.is_empty(), "scene new loop retains memory")
	_on_action("inspect", "mirror")
	smoke_check("mirror" in run.campaign.clues, "second-loop scene clue unlocked")
	await smoke_story_staff({"material": 1, "element": 1}, 6)
	open_station("seal")
	_on_action("offer")
	smoke_check(run.campaign.chapters.size() == 2, "ice offering advances second chapter")
	_on_action("new_run")
	_on_action("inspect", "coil")
	await smoke_story_staff({"material": 2, "element": 2, "rune": 0}, 12)
	_on_action("tree")
	await smoke_capture("14-tree-choices")
	for choice in ui.overlay.find_children("BranchChoice_*", "Button", true, false):
		smoke_check(choice.get_global_rect().end.y < 715, "tree button unobscured " + choice.name)
	_on_action("branch", "astrolabe")
	_on_action("branch", "prism")
	_on_action("branch", "satellites")
	smoke_check(rules.active(run).tree == ["astrolabe", "prism", "satellites"], "tree UI commits ordered choices")
	smoke_check(infusion_staff.has_node("Branch_satellites") and held_staff.has_node("Branch_prism"), "altar and held staff share branch geometry")
	await smoke_capture("14-tree-selected")
	open_station("infusion")
	feedback_time = 0
	await get_tree().create_timer(0.25).timeout
	await smoke_capture("15-branch-astrolabe")
	open_station("lab")
	cast_cooldown = 0
	var spell: Dictionary = rules.stats(rules.active(run).design, 12, rules.active(run).tree)
	cast_spell(Vector3(0, 1.35, -7.5))
	smoke_check(is_equal_approx(cast_cooldown, float(spell.cooldown)), "branch stats control real spell cooldown")
	open_station("seal")
	_on_action("offer")
	smoke_check(run.campaign.chapters.size() == 3, "third-loop lightning offering opens letter")
	_on_action("inspect", "door")
	smoke_check("door" in run.campaign.clues, "final letter discoverable")
	await smoke_story_staff({"element": 0, "rune": 0}, 12)
	_on_action("tree")
	for id in ["lance", "thorns", "wings"]:
		_on_action("branch", id)
	open_station("infusion")
	await smoke_capture("15-branch-lance")
	# Inspect the other first-tier silhouette on the same fixture; restore before commit.
	var tree: Array = rules.active(run).tree.duplicate()
	rules.active(run).tree = ["censer", "prism", "satellites"]
	refresh_visuals()
	await smoke_capture("15-branch-censer")
	rules.active(run).tree = tree
	open_station("seal")
	await smoke_capture("16-seal-ready")
	_on_action("offer")
	smoke_check(run.campaign.ending == "dawn", "final attribute offering chooses dawn ending")
	await smoke_capture("17-dawn")
	_on_action("journal")
	smoke_check(paused and ui.mode == "journal", "journal accessible after narrative ending")
	await smoke_capture("18-journal")
	smoke_check(save() and store.load_run().campaign.ending == "dawn", "story reload preserves ending")
	close_station()
	ui.hud.visible = false
	for sign_node in get_tree().get_nodes_in_group("workshop_signs"):
		sign_node.visible = false
	station_camera.position = Vector3(3.5, 2.25, 4.2)
	station_camera.look_at(Vector3(0, 2, 8.2))
	station_camera.current = true
	await smoke_capture("19-memory-room")
	station_camera.position = Vector3(-3.0, 1.8, 1.0)
	station_camera.look_at(Vector3(-5.4, 1.05, 0.1))
	await smoke_capture("19-alchemy-detail")
	_on_action("new_run")
	smoke_check(run.campaign.ending == "dawn" and run.campaign.loop == 4, "scene subsequent return remembers ending")
