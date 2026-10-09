extends RefCounted

# Room art only. The workshop controller still owns stations and collisions.
var g: Node
var world: Node3D
var bronze: Material
var dark: Material
var pale: Material

func _init(workshop: Node) -> void:
	g = workshop
	world = workshop.world
	bronze = g.mat("#9c7944", 0.72)
	dark = g.mat("#191e27", 0.35)
	pale = g.mat("#d8bd85", 0.1)

func beam(a: Vector3, b: Vector3, width: float, material: Material, parent: Node3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, a.distance_to(b), width)
	var node: MeshInstance3D = g.mesh_part(mesh, (a + b) * 0.5, material, parent)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func arch(parent: Node3D, span: float, rise: float, material: Material, width: float) -> void:
	var previous := Vector3(-span * 0.5, 0, 0)
	for i in range(1, 33):
		var t := -1.0 + float(i) / 16.0
		var point := Vector3(t * span * 0.5, rise * sqrt(maxf(0, 1.0 - absf(t))), 0)
		beam(previous, point, width, material, parent)
		previous = point

func glow(at: Vector3, color: Color, diameter: float, opacity: float = 0.23, parent: Node3D = world) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/particles/light_01.png")
	sprite.pixel_size = diameter / float(sprite.texture.get_width())
	sprite.position = at
	sprite.modulate = Color(color, opacity)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	parent.add_child(sprite)
	return sprite

func window(at: Vector3, yaw: float, span: float = 1.65, rise: float = 2.8) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	world.add_child(root)
	var glass := ShaderMaterial.new()
	glass.shader = load("res://assets/stained_glass.gdshader")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(32):
		var t1 := -1.0 + float(i) / 16.0
		var t2 := -1.0 + float(i + 1) / 16.0
		var a := Vector3(t1 * span * 0.5, rise * sqrt(maxf(0, 1.0 - absf(t1))), 0)
		var b := Vector3(t2 * span * 0.5, rise * sqrt(maxf(0, 1.0 - absf(t2))), 0)
		for vertex in [Vector3.ZERO, b, a]:
			surface.set_uv(Vector2(vertex.x / span + 0.5, vertex.y / rise))
			surface.add_vertex(vertex)
	surface.generate_normals()
	g.mesh_part(surface.commit(), Vector3(0, 0, 0.01), glass, root)
	arch(root, span, rise, bronze, 0.065)
	beam(Vector3(-span * 0.5, 0, 0), Vector3(span * 0.5, 0, 0), 0.08, bronze, root)
	beam(Vector3(0, 0, 0.02), Vector3(0, rise, 0.02), 0.045, bronze, root)
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * span * 0.25, rise * 0.05, 0.03)
		root.add_child(leaf)
		arch(leaf, span * 0.43, rise * 0.63, bronze, 0.028)
		for y in [0.42, 0.83, 1.24]:
			beam(Vector3(side * span * 0.46, y, 0.05), Vector3(0, y + 0.24, 0.05), 0.016, bronze, root)
	var circle_mesh := TorusMesh.new()
	circle_mesh.inner_radius = span * 0.16
	circle_mesh.outer_radius = span * 0.18
	circle_mesh.rings = 32
	circle_mesh.ring_segments = 6
	var rose: MeshInstance3D = g.mesh_part(circle_mesh, Vector3(0, rise * 0.71, 0.045), bronze, root)
	rose.rotation.x = PI * 0.5
	glow(Vector3(0, rise * 0.68, 0.07), Color("#76a6d9"), 1.15, 0.1, root)

func candles(at: Vector3, count: int = 3) -> void:
	for i in range(count):
		var offset := Vector3((float(i) - float(count - 1) * 0.5) * 0.16, 0.0, 0)
		var height := 0.17 + float(i % 3) * 0.055
		g.cylinder(0.055, 0.035, at + offset, bronze)
		g.cylinder(0.029, height, at + offset + Vector3(0, height * 0.5, 0), pale)
		var flame := SphereMesh.new()
		flame.radius = 0.021
		flame.height = 0.075
		flame.radial_segments = 8
		flame.rings = 4
		g.mesh_part(flame, at + offset + Vector3(0, height + 0.038, 0), g.mat("#ffcb82", 0, 0.7))
		glow(at + offset + Vector3(0, height + 0.03, 0), Color("#ffb85f"), 0.34, 0.32)
	var lamp: OmniLight3D = g.light(at + Vector3(0, 0.35, 0), "#ffbc76", 0.8, 3.2)
	g.lights.append(lamp)

func shelf(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = yaw
	world.add_child(root)
	var wood: Material = g.wood_material("#443023")
	g.box(Vector3(1.7, 2.55, 0.15), Vector3(0, 1.27, -0.29), wood, false, root)
	for side in [-1.0, 1.0]:
		g.box(Vector3(0.12, 2.65, 0.62), Vector3(side * 0.86, 1.325, 0), dark, false, root)
	for y in [0.13, 0.90, 1.65, 2.50]:
		g.box(Vector3(1.8, 0.10, 0.65), Vector3(0, y, 0), wood, false, root)
		g.box(Vector3(1.75, 0.022, 0.02), Vector3(0, y + 0.04, 0.33), bronze, false, root)
	var colors := ["#454751", "#704633", "#45605c", "#887457", "#463b52"]
	for row in range(3):
		for i in range(10):
			var h := 0.34 + float((i * 7 + row * 3) % 5) * 0.045
			var x := -0.70 + float(i) * 0.145
			var y := 0.19 + float(row) * 0.76 + h * 0.5
			g.box(Vector3(0.11, h, 0.35), Vector3(x, y, 0.11), g.mat(colors[(i + row) % 5]), false, root)
			for stripe in [-0.3, 0.3]:
				g.box(Vector3(0.108, 0.014, 0.008), Vector3(x, y + stripe * h, 0.289), bronze, false, root)

func build() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#10151e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8294b1")
	env.ambient_light_energy = 0.23
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#162332")
	env.fog_density = 0.006
	environment.environment = env
	world.add_child(environment)
	var floor_material: ShaderMaterial = g.stone("#353a40", 14)
	floor_material.set_shader_parameter("floor_tiles", true)
	floor_material.set_shader_parameter("polish", 0.43)
	var wall_material: Material = g.stone("#45464a", 8)
	g.box(Vector3(16, 0.25, 20), Vector3(0, -0.125, -1), floor_material, true)
	g.box(Vector3(0.35, 6.4, 20), Vector3(-8, 3.2, -1), wall_material, true)
	g.box(Vector3(0.35, 6.4, 20), Vector3(8, 3.2, -1), wall_material, true)
	g.box(Vector3(16, 6.4, 0.35), Vector3(0, 3.2, -11), wall_material, true)
	g.box(Vector3(16, 6.4, 0.35), Vector3(0, 3.2, 9), wall_material, true)
	g.box(Vector3(16, 0.2, 20), Vector3(0, 6.35, -1), dark)
	for x in [-7.75, 7.75]:
		for y in [0.15, 0.46, 3.92, 5.1]:
			g.box(Vector3(0.18, 0.055 if y > 1 else 0.12, 19.8), Vector3(x, y, -1), bronze)
	for z in [-10.76, 8.76]:
		for y in [0.15, 0.46, 3.92, 5.1]:
			g.box(Vector3(15.6, 0.055 if y > 1 else 0.12, 0.18), Vector3(0, y, z), bronze)
	# Ribbed vaults, stepped columns and pointed windows replace the warehouse grid.
	for z in [-9.0, -4.5, 0.0, 4.5, 8.3]:
		for side in [-1.0, 1.0]:
			var x: float = side * 7.35
			g.box(Vector3(0.65, 0.22, 0.7), Vector3(x, 0.11, z), dark)
			g.cylinder(0.19, 4.05, Vector3(x, 2.16, z), dark)
			for y in [0.34, 1.0, 3.87, 4.18]:
				g.cylinder(0.25, 0.09, Vector3(x, y, z), bronze)
			g.box(Vector3(0.035, 3.2, 0.035), Vector3(x - side * 0.15, 2.17, z + 0.15), bronze)
		var vault := Node3D.new()
		vault.position = Vector3(0, 4.0, z)
		world.add_child(vault)
		arch(vault, 14.7, 2.08, dark, 0.17)
		arch(vault, 14.45, 2.0, bronze, 0.033)
	for x in [-5.85, -2.85, 0.0, 2.85, 5.85]:
		window(Vector3(x, 1.5, -10.79), 0, 2.0, 3.25)
	for side in [-1.0, 1.0]:
		for z in [-6.6, 1.8, 6.6]:
			window(Vector3(side * 7.80, 1.1, z), -side * PI * 0.5)
			var sconce := Vector3(side * 7.4, 1.8, z - 1.1)
			g.box(Vector3(0.35, 0.06, 0.35), sconce, bronze)
			candles(sconce + Vector3(0, 0.04, 0), 2)
	# Brass-bordered carpet and inset mosaic leave a clear central route.
	var carpet: Material = g.mat("#303044", 0.05)
	g.box(Vector3(2.35, 0.006, 11.5), Vector3(0, 0.007, 0.0), carpet)
	for x in [-1.18, 1.18]:
		g.box(Vector3(0.015, 0.008, 11.5), Vector3(x, 0.013, 0), bronze)
	for z in [-5.65, 5.65]:
		g.box(Vector3(2.38, 0.008, 0.02), Vector3(0, 0.013, z), bronze)
	for z in range(-5, 6):
		var diamond: MeshInstance3D = g.box(Vector3(0.16, 0.006, 0.16), Vector3(0, 0.016, z), bronze)
		diamond.rotation.y = PI * 0.25
	for z in [-4.8, 4.7]:
		var ritual: MeshInstance3D = g.ring(1.45, 0.016, Vector3(0, 0.02, z), bronze)
		ritual.scale.y = 0.18
		g.ring(1.25, 0.007, Vector3(0, 0.026, z), g.mat("#4c938e", 0.45, 0.25))
	shelf(Vector3(-6.7, 0, -9.55), 0)
	shelf(Vector3(6.7, 0, -9.55), 0)
	shelf(Vector3(-7.0, 0, -4.1), PI * 0.5)
	shelf(Vector3(7.0, 0, -4.1), -PI * 0.5)
	# Chandelier: one warm light, many visible candles, no forest of dynamic lights.
	g.cylinder(0.018, 1.6, Vector3(0, 5.30, 0.1), bronze)
	g.ring(0.82, 0.025, Vector3(0, 4.50, 0.1), bronze)
	g.ring(0.56, 0.02, Vector3(0, 4.25, 0.1), bronze)
	for i in range(8):
		var angle := float(i) * TAU / 8.0
		var at := Vector3(cos(angle) * 0.82, 4.48, 0.1 + sin(angle) * 0.82)
		g.cylinder(0.028, 0.18, at + Vector3(0, 0.1, 0), pale)
		glow(at + Vector3(0, 0.24, 0), Color("#ffca8b"), 0.3)
		beam(Vector3(0, 4.94, 0.1), at, 0.014, bronze, world)
	g.light(Vector3(0, 4.25, 0), "#ffd2a2", 2.0, 7.5)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#819fca")
	moon.light_energy = 0.32
	moon.rotation_degrees = Vector3(-32, -28, 0)
	moon.shadow_enabled = true
	world.add_child(moon)
	var lantern: OmniLight3D = g.light(Vector3(0, 3.8, -8.3), "#88b6dc", 1.1, 5.5)
	lantern.shadow_enabled = true
	# Closed portal frames the seal without blocking the station approach.
	var door := Node3D.new()
	door.position = Vector3(0, 0.15, 8.70)
	world.add_child(door)
	g.box(Vector3(2.6, 3.7, 0.10), Vector3(0, 1.85, 0), dark, false, door)
	var door_arch := Node3D.new()
	door_arch.position.y = 1.25
	door.add_child(door_arch)
	arch(door_arch, 2.65, 2.7, bronze, 0.13)
	for x in [-1.20, -0.65, 0, 0.65, 1.20]:
		beam(Vector3(x, 0.10, 0.08), Vector3(x, 3.7 - absf(x) * 0.5, 0.08), 0.045, bronze, door)
	for side in [-1.0, 1.0]:
		beam(Vector3(side * 1.2, 0.5, 0.08), Vector3(0, 1.9, 0.08), 0.025, bronze, door)
		beam(Vector3(side * 1.2, 2.9, 0.08), Vector3(0, 1.9, 0.08), 0.025, bronze, door)
	batch_static_frames()

func batch_static_frames() -> void:
	# Merge stationary trim by material; animated staff and altar are built later.
	for material in [bronze, dark, pale]:
		var merged := SurfaceTool.new()
		merged.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sources: Array[MeshInstance3D] = []
		for node in world.find_children("*", "MeshInstance3D", true, false):
			if node.material_override == material and node.mesh.get_surface_count() == 1:
				merged.append_from(node.mesh, 0, world.global_transform.affine_inverse() * node.global_transform)
				sources.append(node)
		if sources.is_empty():
			continue
		g.mesh_part(merged.commit(), Vector3.ZERO, material)
		for source in sources:
			source.get_parent().remove_child(source)
			source.queue_free()
