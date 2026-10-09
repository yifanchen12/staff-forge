extends RefCounted

var g: Node
var clues: Array[Dictionary] = []
var memory_label: Label3D
var echo: StaffVisual
var door_light: OmniLight3D
var fissures: Array[MeshInstance3D] = []

func _init(game: Node) -> void:
	g = game

func build() -> void:
	var bronze: Material = g.mat("#a58250", 0.72)
	var paper: Material = g.mat("#c9b78d")
	var ink: Material = g.mat("#40342f")
	var wood: Material = g.wood_material("#3e3028")
	var art = load("res://scripts/gothic_scene.gd").new(g)
	for entry in g.rules.chronicle.data.clues:
		var a: Array = entry.position
		var at := Vector3(a[0], a[1], a[2])
		var root := Node3D.new()
		root.name = "Clue_" + str(entry.id)
		root.position = at
		g.world.add_child(root)
		# Small pedestals stay clear of the central walkway and workbench approaches.
		if entry.id != "scar":
			g.box(Vector3(0.82, 0.07, 0.65), at - Vector3(0, 0.06, 0), wood, true)
			for side in [-1.0, 1.0]:
				g.box(Vector3(0.07, at.y - 0.13, 0.48), Vector3(at.x + side * 0.32, (at.y - 0.13) * 0.5, at.z), wood)
			g.box(Vector3(0.79, 0.02, 0.025), at + Vector3(0, -0.015, 0.30), bronze)
		match entry.kind:
			"book", "letter":
				var book: MeshInstance3D = g.box(Vector3(0.43, 0.045, 0.32), Vector3(0, 0.01, 0), g.mat("#45333a"), false, root)
				book.rotation.y = -0.16
				g.box(Vector3(0.39, 0.007, 0.29), Vector3(0, 0.04, 0), paper, false, root)
				for row in range(7):
					g.box(Vector3(0.25 - (row % 3) * 0.035, 0.003, 0.005), Vector3(-0.025, 0.045, -0.10 + row * 0.028), ink, false, root)
				g.box(Vector3(0.006, 0.006, 0.29), Vector3(0.012, 0.047, 0), bronze, false, root)
			"scar":
				for i in range(12):
					var cut: MeshInstance3D = g.box(Vector3(0.005, 0.007, 0.10), Vector3(i * 0.025 - 0.15, 0.03, 0), bronze, false, root)
					cut.rotation.y = 0.2
			"mirror":
				var mirror := SphereMesh.new()
				mirror.radius = 0.2
				mirror.height = 0.4
				var surface: MeshInstance3D = g.mesh_part(mirror, Vector3(0, 0.24, 0), g.mat("#729baf", 0.92, 0.12), root)
				surface.scale = Vector3(1, 1.35, 0.12)
				var frame: MeshInstance3D = g.ring(0.22, 0.015, at + Vector3(0, 0.24, 0), bronze)
				frame.rotation.x = PI / 2
				frame.scale.z = 1.35
				g.box(Vector3(0.06, 0.14, 0.08), Vector3(0, 0.06, 0), bronze, false, root)
			"astrolabe":
				for i in range(3):
					var ring: MeshInstance3D = g.ring(0.23 + i * 0.035, 0.009, at + Vector3(0, 0.33, 0), bronze)
					ring.rotation = Vector3(i * 0.7, 0.5, 0.8)
				g.mesh_part(StaffVisual.crystal_mesh(0.065, 0.2), Vector3(0, 0.33, 0), g.mat("#a392d0", 0.3, 0.3), root)
				g.box(Vector3(0.04, 0.25, 0.04), Vector3(0, 0.13, 0), bronze, false, root)
			"bottle":
				bottle(at, 0.13, "#528a82")
				g.box(Vector3(0.04, 0.16, 0.02), Vector3(0, 0.12, 0.11), paper, false, root)
		var mote: Sprite3D = art.glow(at + Vector3(0, 0.16, 0), Color("#9abed0"), 0.30, 0.22)
		clues.append({"entry": entry, "position": at, "root": root, "mote": mote})
	# A full apparatus bench: retorts, racks, scale, tubing and annotated manuscripts.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 5.6, 0, 0.45)
		g.box(Vector3(1.75, 0.10, 0.64), at + Vector3(0, 0.88, 0), wood, true)
		for x in [-0.72, 0.72]:
			g.box(Vector3(0.08, 0.84, 0.49), at + Vector3(x, 0.42, 0), bronze)
		for i in range(5):
			bottle(at + Vector3(-0.65 + i * 0.3, 0.94, 0), 0.065 + (i % 2) * 0.025, ["#598c8a", "#937748", "#75598e"][i % 3])
		art.candles(at + Vector3(0.73, 0.96, 0.1), 1)
		for i in range(3):
			g.box(Vector3(0.26, 0.02, 0.31), at + Vector3(-0.3 + i * 0.25, 0.3 + i * 0.035, 0), paper)
	# Copper plumbing makes the altar read as machinery assembled over many lives.
	for side in [-1.0, 1.0]:
		for y in [0.7, 1.0]:
			art.beam(Vector3(side * 3.1, y, 8.65), Vector3(side * 6.5, y, 8.65), 0.045, bronze, g.world)
			for x in [3.5, 4.5, 5.5, 6.4]:
				var valve: MeshInstance3D = g.ring(0.10, 0.012, Vector3(side * x, y, 8.57), bronze)
				valve.rotation.x = PI / 2
		for i in range(6):
			var mark: MeshInstance3D = g.box(Vector3(0.035, 0.43, 0.02), Vector3(side * (0.16 + i * 0.12), 2.35 + i * 0.10, 8.60), g.mat("#90c8cb", 0.1, 0.45))
			mark.rotation.z = side * 0.5
			fissures.append(mark)
	memory_label = g.label3d("", Vector3(0, 3.80, 8.15), Color("#b1c9cf"), 25)
	memory_label.remove_from_group("workshop_signs")
	echo = StaffVisual.new()
	echo.position = Vector3(-2.2, 1.15, 8.1)
	echo.scale = Vector3.ONE * 0.62
	g.world.add_child(echo)
	g.cylinder(0.33, 1.08, Vector3(-2.2, 0.54, 8.1), g.mat("#242935", 0.4))
	g.ring(0.35, 0.016, Vector3(-2.2, 1.10, 8.1), bronze)
	door_light = g.light(Vector3(0, 2.9, 7.9), "#83c8d5", 0.5, 3.5)
	refresh()

func bottle(at: Vector3, radius: float, color: String) -> void:
	var material: Material = g.mat(color, 0.4, 0.09)
	var bulb := SphereMesh.new()
	bulb.radius = radius
	bulb.height = radius * 2.2
	bulb.radial_segments = 12
	bulb.rings = 8
	g.mesh_part(bulb, at + Vector3(0, radius, 0), material)
	g.cylinder(radius * 0.35, radius * 1.2, at + Vector3(0, radius * 2.0, 0), material)
	g.cylinder(radius * 0.39, 0.045, at + Vector3(0, radius * 2.65, 0), g.mat("#ac8755", 0.5))

func refresh() -> void:
	var meta: Dictionary = g.run.campaign
	for item in clues:
		item.mote.visible = g.rules.chronicle.available(meta, item.entry) and not item.entry.id in meta.clues
		item.root.visible = item.entry.id != "door" or meta.chapters.size() >= 3
	for i in range(fissures.size()):
		fissures[i].visible = i < meta.chapters.size() * 3
	door_light.light_color = Color("#e4b974") if meta.ending == "dawn" else Color("#83c8d5")
	door_light.light_energy = 0.5 + meta.chapters.size() * 0.32
	memory_label.text = "第 %d 次归来   /   记忆 %d / 4" % [meta.loop, meta.chapters.size()]
	if not meta.last_echo.is_empty():
		memory_label.text += "\n上次回声：" + meta.last_echo
	echo.visible = not meta.last_echo.is_empty()
	if echo.visible:
		var design: Dictionary = g.rules.default_design()
		design.element = 1 if meta.last_echo.begins_with("霜蓝") else (2 if meta.last_echo.begins_with("紫电") else 0)
		echo.rebuild(design, clampi(int(meta.last_echo.get_slice("+", 1)), 0, 12))
