class_name StaffVisual
extends Node3D

var crystal: Node3D
var glow: OmniLight3D
var design: Dictionary
var element_color := Color("#ff9d5c")
var tip_position := Vector3.ZERO
var animation_time := 0.0
var pulse := 0.0
var spin := true
var visible_level := 0
var evolution := 0
var orbits: Array[Node3D] = []
var halo: Sprite3D
var luminous: StandardMaterial3D

static func evolution_stage(level: int) -> int:
	return clampi(int(level / 3.0), 0, 4)

static func evolution_name(level: int) -> String:
	return ["素木原型", "符文觉醒", "晶簇冠冕", "悬浮星环", "封印神器"][evolution_stage(level)]

static func next_evolution(level: int) -> String:
	if level >= 12:
		return "已抵达最终形态"
	var next_level := (evolution_stage(level) + 1) * 3
	return "+%d · %s" % [next_level, evolution_name(next_level)]

static func material(color: Color, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.3 if metallic > 0.0 else 0.65
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func part(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance

func cylinder(radius: float, height: float, pos: Vector3, mat: Material, top: float = -1.0, segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = segments
	return part(mesh, pos, mat)

func ring(radius: float, tube: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 24
	mesh.ring_segments = 8
	return part(mesh, pos, mat)

static func crystal_mesh(radius: float, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		var next := float(i + 1) * TAU / 6.0
		var a := Vector3(cos(angle) * radius, -height * 0.12, sin(angle) * radius)
		var b := Vector3(cos(next) * radius, -height * 0.12, sin(next) * radius)
		for vertex in [Vector3(0, height * 0.55, 0), b, a, Vector3(0, -height * 0.45, 0), a, b]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

func rod(from: Vector3, to: Vector3, radius: float, mat: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.7
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	var segment := part(mesh, (from + to) * 0.5, mat, parent)
	segment.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return segment

func rebuild(design_value: Dictionary, level: int = 0, tree: Array = []) -> void:
	orbits.clear()
	visible_level = clampi(level, 0, 12)
	evolution = evolution_stage(visible_level)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	design = design_value.duplicate(true)
	var colors := [Color("#86664b"), Color("#524944"), Color("#b4b8a6")]
	var element_colors := [Color("#f28b49"), Color("#58c7e8"), Color("#ad83e3")]
	element_color = element_colors[int(design.element)]
	var length_value := float(design.length)
	var radius := float(design.thickness) * 0.5
	var wood := material(colors[int(design.material)].lerp(Color(design.color), 0.4))
	if ResourceLoader.exists("res://assets/textures/wood_diffuse.jpg"):
		wood.albedo_texture = load("res://assets/textures/wood_diffuse.jpg")
		wood.uv1_scale = Vector3(1.0, 3.0, 1.0)
	var bronze := material(Color("#ba9656").lerp(Color("#e9c788"), float(evolution) * 0.17), 0.8)
	var dark := material(Color("#292e30"), 0.2)
	luminous = material(element_color, 0.05, 0.16 + float(level) * 0.022)
	if ResourceLoader.exists("res://assets/wood.gdshader"):
		var grain := ShaderMaterial.new()
		grain.shader = load("res://assets/wood.gdshader")
		grain.set_shader_parameter("wood_color", wood.albedo_color)
		cylinder(radius * 0.76, length_value, Vector3(0, length_value * 0.5, 0), grain, radius)
	else:
		cylinder(radius * 0.76, length_value, Vector3(0, length_value * 0.5, 0), wood, radius)
	cylinder(radius * 1.23, 0.045, Vector3(0, 0.025, 0), bronze)
	cylinder(radius * 1.15, length_value * 0.22, Vector3(0, length_value * 0.24, 0), dark)
	for i in range(10):
		ring(radius * 1.17, 0.0018, Vector3(0, length_value * 0.14 + float(i) * length_value * 0.022, 0), bronze)
	for y in [length_value * 0.12, length_value * 0.36, length_value * 0.82, length_value]:
		cylinder(radius * 1.28, 0.015, Vector3(0, y, 0), bronze)
	cylinder(radius * 1.7, 0.10, Vector3(0, length_value + 0.025, 0), bronze, radius * 1.1)
	var center := Vector3(0, length_value + 0.18, 0)
	if int(design.head) == 0:
		var outer := ring(0.115, 0.010, center, bronze)
		outer.rotation.x = PI * 0.5
		var inner := ring(0.09, 0.0035, center, luminous)
		inner.rotation.x = PI * 0.5
		for sign_value in [-1.0, 1.0]:
			var prong := cylinder(0.013, 0.12, center + Vector3(sign_value * 0.055, -0.09, 0), bronze, 0.009)
			prong.rotation.z = sign_value * -0.4
	elif int(design.head) == 1:
		for i in range(3):
			var angle := float(i) * TAU / 3.0
			var offset := Vector3(cos(angle) * 0.085, 0, sin(angle) * 0.085)
			cylinder(0.018, 0.26, center + offset, bronze, 0.001, 5)
		ring(0.085, 0.012, center + Vector3(0, -0.09, 0), bronze)
		ring(0.09, 0.003, center, luminous)
	else:
		for i in range(4):
			var cage := ring(0.125, 0.007, center, bronze)
			cage.rotation = Vector3(PI * 0.5, float(i) * PI / 4.0, 0.0)
		ring(0.13, 0.008, center, luminous)
	crystal = Node3D.new()
	crystal.position = center
	add_child(crystal)
	var gem := crystal_mesh(0.065 + float(level) * 0.0025, 0.22 + float(evolution) * 0.04)
	var core_material := ShaderMaterial.new()
	core_material.shader = load("res://assets/crystal.gdshader")
	core_material.set_shader_parameter("gem_color", element_color)
	part(gem, Vector3.ZERO, core_material, crystal)
	for i in range(2 + level):
		var rune := ring(radius * 1.45, 0.0024, Vector3(0, length_value * (0.44 + float(i) * 0.44 / float(1 + level)), 0), luminous)
		rune.rotation.z = 0.3 if int(design.rune) == 0 else -0.3
	# A level always changes geometry; major crowns appear at +3/+6/+9/+12.
	var ornament := Node3D.new()
	ornament.name = "Evolution"
	ornament.position = center
	add_child(ornament)
	if evolution >= 1 and tree.is_empty():
		for side in [-1.0, 1.0]:
			rod(Vector3(side * 0.065, -0.2, 0), Vector3(side * 0.13, 0.05, 0), 0.009, bronze, ornament)
			rod(Vector3(side * 0.13, 0.05, 0), Vector3(side * 0.09, 0.17, 0), 0.007, bronze, ornament)
		var collar := ring(0.055, 0.004, Vector3(0, -0.14, 0), luminous)
		collar.rotation.z = 0.25
	if evolution >= 2 and tree.size() < 2:
		for i in range(3 + evolution):
			var angle := float(i) * TAU / float(3 + evolution)
			var offset := Vector3(cos(angle), 0, sin(angle))
			rod(offset * 0.07 + Vector3(0, -0.20, 0), offset * 0.15 + Vector3(0, 0.05, 0), 0.008, bronze, ornament)
			var shard := part(crystal_mesh(0.026, 0.13), offset * 0.16 + Vector3(0, 0.08, 0), luminous, ornament)
			shard.rotation.z = -cos(angle) * 0.35
	if evolution >= 3 and tree.size() < 3:
		for i in range(evolution - 1):
			var orbit := Node3D.new()
			orbit.position = center
			orbit.rotation = Vector3(0.7 + float(i) * 0.75, 0, 0.35)
			add_child(orbit)
			orbits.append(orbit)
			var radius_value := 0.20 + float(i) * 0.055
			var orbit_mesh := TorusMesh.new()
			orbit_mesh.inner_radius = radius_value - 0.003
			orbit_mesh.outer_radius = radius_value + 0.003
			orbit_mesh.rings = 40
			orbit_mesh.ring_segments = 6
			part(orbit_mesh, Vector3.ZERO, bronze if i == 0 else luminous, orbit)
			for j in range(4):
				var angle := float(j) * TAU / 4.0
				part(crystal_mesh(0.019, 0.065), Vector3(cos(angle), 0, sin(angle)) * radius_value, luminous, orbit)
	if evolution >= 4 and tree.is_empty():
		for i in range(12):
			var angle := float(i) * TAU / 12.0
			var direction := Vector3(cos(angle), sin(angle), 0)
			rod(direction * 0.20, direction * (0.29 if i % 3 == 0 else 0.25), 0.006, bronze, ornament)
		rod(Vector3(0, 0.14, 0), Vector3(0, 0.38, 0), 0.012, bronze, ornament)
		for side in [-1.0, 1.0]:
			rod(Vector3(0, 0.18, 0), Vector3(side * 0.055, 0.28, 0), 0.007, bronze, ornament)
	build_branches(tree, level, length_value, center, bronze, core_material)
	halo = Sprite3D.new()
	halo.texture = load("res://assets/particles/light_01.png")
	halo.pixel_size = (0.36 + float(evolution) * 0.08) / float(halo.texture.get_width())
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.modulate = Color(element_color, 0.14 + float(evolution) * 0.025)
	halo.position = center
	halo.shaded = false
	add_child(halo)
	glow = OmniLight3D.new()
	glow.position = center
	glow.light_color = element_color
	glow.light_energy = 0.5 + float(evolution) * 0.18
	glow.omni_range = 1.0 + float(evolution) * 0.25
	glow.shadow_enabled = false
	add_child(glow)
	tip_position = center + Vector3(0, 0.07, 0)

func _process(delta: float) -> void:
	animation_time += delta
	pulse = maxf(0.0, pulse - delta * 2.5)
	if is_instance_valid(crystal) and spin:
		crystal.rotation.y += delta * 0.55
	if is_instance_valid(glow):
		glow.light_energy = 0.5 + float(evolution) * 0.18 + sin(animation_time * 2.0) * 0.1 + pulse * 1.6
	for i in range(orbits.size()):
		orbits[i].rotate_y(delta * (0.25 if i % 2 == 0 else -0.32))
	if is_instance_valid(halo):
		halo.modulate.a = 0.14 + float(evolution) * 0.025 + pulse * 0.06

func flash(amount: float = 1.0) -> void:
	pulse = amount

func tip_global() -> Vector3:
	return to_global(tip_position)

func build_branches(tree: Array, level: int, length_value: float, center: Vector3, bronze: Material, magic: Material) -> void:
	for tier in range(tree.size()):
		if level < (tier + 1) * 3:
			continue
		var root := Node3D.new()
		root.name = "Branch_" + str(tree[tier])
		root.position = center
		add_child(root)
		match tree[tier]:
			"lance":
				for side in [-1.0, 1.0]:
					rod(Vector3(side * 0.09, -0.2, 0), Vector3(side * 0.24, 0.32, 0), 0.022, bronze, root)
					rod(Vector3(side * 0.24, 0.32, 0), Vector3(side * 0.09, 0.53, 0), 0.014, magic, root)
				part(crystal_mesh(0.035, 0.36), Vector3(0, 0.4, 0), magic, root)
			"censer":
				for i in range(6):
					var a := float(i) * TAU / 6.0
					var d := Vector3(cos(a), 0, sin(a))
					rod(d * 0.04 + Vector3(0, -0.25, 0), d * 0.25, 0.013, bronze, root)
					rod(d * 0.25, d * 0.05 + Vector3(0, 0.30, 0), 0.013, bronze, root)
					for j in range(4):
						part(crystal_mesh(0.013, 0.045), d * 0.22 + Vector3(0, -0.15 - j * 0.055, 0), magic, root)
				root.rotation.y = 0.3
			"astrolabe":
				for i in range(2):
					var orbit := Node3D.new()
					root.add_child(orbit)
					orbit.rotation.z = float(i) * PI / 2.0 + 0.4
					orbits.append(orbit)
					var torus := TorusMesh.new()
					torus.inner_radius = 0.31 + i * 0.04
					torus.outer_radius = torus.inner_radius + 0.012
					part(torus, Vector3.ZERO, bronze, orbit)
					rod(Vector3(-0.38, 0, 0), Vector3(0.38, 0, 0), 0.012, magic, orbit)
			"thorns":
				for i in range(22):
					var a := float(i) * 0.75
					var y := -0.34 - float(i) * length_value * 0.022
					var d := Vector3(cos(a), 0, sin(a))
					var next := Vector3(cos(a + 0.75) * 0.04, y - length_value * 0.022, sin(a + 0.75) * 0.04)
					rod(d * 0.04 + Vector3(0, y, 0), next, 0.012, bronze, root)
					if i % 3 == 0:
						rod(d * 0.04 + Vector3(0, y, 0), d * 0.12 + Vector3(0, y + 0.08, 0), 0.012, magic, root)
			"prism":
				for i in range(3):
					var y := -0.38 - float(i) * length_value * 0.18
					part(crystal_mesh(0.055, 0.18), Vector3(0, y, 0), magic, root)
					for side in [-1.0, 1.0]:
						rod(Vector3(side * 0.075, y - 0.12, 0), Vector3(side * 0.075, y + 0.12, 0), 0.011, bronze, root)
						rod(Vector3(0, y - 0.12, 0), Vector3(side * 0.075, y, 0), 0.01, bronze, root)
			"satellites":
				var satellites := Node3D.new()
				root.add_child(satellites)
				orbits.append(satellites)
				for i in range(6):
					var a := float(i) * TAU / 6.0
					var d := Vector3(cos(a) * 0.40, sin(a * 2.0) * 0.12, sin(a) * 0.40)
					part(crystal_mesh(0.045, 0.19), d, magic, satellites)
					rod(d + Vector3(0, -0.12, 0), d + Vector3(0, 0.14, 0), 0.008, bronze, satellites)
			"wings":
				for side in [-1.0, 1.0]:
					rod(Vector3(side * 0.08, -0.10, 0), Vector3(side * 0.48, 0.27, 0), 0.018, bronze, root)
					for i in range(5):
						var start := Vector3(side * (0.13 + i * 0.07), 0.02 + i * 0.06, 0)
						rod(start, start + Vector3(side * 0.1, -0.21 - i * 0.025, 0), 0.016, magic, root)
		if level >= 12 and tier == 0:
			for i in range(3):
				var crown := part(crystal_mesh(0.04, 0.18), Vector3((i - 1) * 0.15, 0.60 - absf(i - 1) * 0.1, 0), magic, root)
				crown.rotation.z = (i - 1) * -0.35
