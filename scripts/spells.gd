class_name SpellLab
extends Node3D

signal report_changed(text: String)
var targets: Array[Dictionary] = []
var time_passed := 0.0
var last_report := "训练靶会缓慢移动。冰霜将真实减慢它们的运动。"
var totals := {"damage": 0.0, "hits": 0, "burn_ticks": 0, "slow_applications": 0, "chains": 0, "casts": 0}
var font: Font
var casts_since_reset := 0
var effects: Node3D

func configure(font_value: Font) -> void:
	font = font_value
	effects = Node3D.new()
	effects.name = "SpellEffects"
	add_child(effects)
	for i in range(5):
		var body := Node3D.new()
		var home := Vector3((float(i) - 2.0) * 1.6, 1.35, -7.5 - absf(float(i) - 2.0) * 0.3)
		body.position = home
		add_child(body)
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.38
		mesh.bottom_radius = 0.38
		mesh.height = 0.14
		mesh.radial_segments = 24
		disc.mesh = mesh
		disc.rotation.x = PI / 2.0
		var mat := StaffVisual.material(Color("#42525a"), 0.4)
		disc.material_override = mat
		body.add_child(disc)
		for r in [0.12, 0.25, 0.37]:
			var circle := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = r - 0.009
			torus.outer_radius = r + 0.009
			torus.rings = 24
			torus.ring_segments = 6
			circle.mesh = torus
			circle.rotation.x = PI / 2.0
			circle.position.z = 0.075
			circle.material_override = StaffVisual.material(Color("#c3a56b"), 0.65, 0.1)
			body.add_child(circle)
		var stand := MeshInstance3D.new()
		var pole := CylinderMesh.new()
		pole.top_radius = 0.035
		pole.bottom_radius = 0.07
		pole.height = 1.3
		stand.mesh = pole
		stand.position.y = -0.65
		stand.material_override = StaffVisual.material(Color("#454a4c"), 0.6)
		body.add_child(stand)
		var label := Label3D.new()
		label.font = font
		label.font_size = 40
		label.pixel_size = 0.003
		label.outline_size = 6
		label.position = Vector3(0, 0.63, 0)
		label.text = "靶 %d" % (i + 1)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(label)
		targets.append({"node": body, "home": home, "phase": float(i) * 0.8,
			"material": mat, "label": label, "damage": 0.0,
			"burn": 0.0, "burn_tick": 0.0, "burn_damage": 0.0, "slow": 0.0, "flash": 0.0})

func advance(delta: float) -> void:
	time_passed += delta
	for target in targets:
		var slowed: bool = target.slow > 0.0
		target.phase += delta * 0.8 * (0.18 if slowed else 1.0)
		target.node.position.x = target.home.x + sin(target.phase) * 0.25
		target.slow = maxf(0.0, float(target.slow) - delta)
		target.flash = maxf(0.0, float(target.flash) - delta)
		if target.burn > 0.0:
			var burn_delta := minf(float(target.burn), delta)
			target.burn -= burn_delta
			target.burn_tick += burn_delta
			while target.burn_tick >= 0.5:
				target.burn_tick -= 0.5
				hit(target, float(target.burn_damage), "灼烧", Color("#ff9d5c"))
				totals.burn_ticks += 1
		var tint := Color("#78d9fa") if target.slow > 0.0 else (Color("#ff9d5c") if target.burn > 0.0 else Color("#42525a"))
		target.material.albedo_color = tint
		target.material.emission_enabled = target.flash > 0.0
		target.material.emission = tint
		target.material.emission_energy_multiplier = float(target.flash) * 1.8
		target.label.text = "靶 %d · %.0f" % [targets.find(target) + 1, target.damage]
		if target.slow > 0.0:
			target.label.text += "\n减速 82%"
		elif target.burn > 0.0:
			target.label.text += "\n灼烧 %.1fs" % target.burn

func reset_targets() -> void:
	for effect in effects.get_children():
		effect.queue_free()
	for target in targets:
		target.damage = 0.0
		target.burn = 0.0
		target.slow = 0.0
		target.burn_tick = 0.0
		target.flash = 0.0
	totals = {"damage": 0.0, "hits": 0, "burn_ticks": 0, "slow_applications": 0, "chains": 0, "casts": 0}
	advance(0.0)
	casts_since_reset = 0
	last_report = "训练靶已重置。不同法杖可以直接比较。"
	report_changed.emit(last_report)

func nearest(aim: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for target in targets:
		var d: float = target.node.global_position.distance_to(aim)
		if d < distance:
			distance = d
			best = target
	return best

func hit(target: Dictionary, damage: float, tag: String, color: Color) -> void:
	target.damage += damage
	target.flash = 0.4
	totals.damage += damage
	totals.hits += 1
	var label := Label3D.new()
	label.font = font
	label.font_size = 48
	label.pixel_size = 0.004
	label.text = "%.0f %s" % [damage, tag]
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = target.node.global_position + Vector3(0, 0.1, 0.3)
	effects.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(label.queue_free)

func cast(spell: Dictionary, origin: Vector3, aim: Vector3) -> Dictionary:
	totals.casts += 1
	casts_since_reset += 1
	var center := nearest(aim)
	if center.is_empty():
		return {"hits": 0}
	var hits_before: int = totals.hits
	var damage_before: float = totals.damage
	var element: String = spell.element
	var color := Color("#ff9d5c") if element == "fire" else (Color("#78d9fa") if element == "ice" else Color("#b7a0ff"))
	var destinations: Array[Dictionary] = []
	if spell.mode == "scatter":
		var sorted := targets.duplicate()
		sorted.sort_custom(func(a, b): return a.node.global_position.distance_to(aim) < b.node.global_position.distance_to(aim))
		for i in range(mini(3, sorted.size())):
			destinations.append(sorted[i])
	else:
		destinations.append(center)
	var all_hit: Array[Dictionary] = []
	for target in destinations:
		beam(origin, target.node.global_position, color, element == "lightning")
		if spell.mode == "area" or element == "fire":
			burst(target.node.global_position, float(spell.radius), color)
			for other in targets:
				if other.node.global_position.distance_to(target.node.global_position) <= float(spell.radius):
					if not other in all_hit:
						all_hit.append(other)
		elif not target in all_hit:
			all_hit.append(target)
	for target in all_hit:
		hit(target, float(spell.damage), "命中", color)
		match element:
			"fire":
				target.burn = 3.0
				target.burn_tick = 0.0
				target.burn_damage = float(spell.damage) * 0.12
			"ice":
				target.slow = 4.0
				totals.slow_applications += 1
			"lightning":
				pass
	if element == "lightning":
		var previous: Dictionary = center
		var visited := all_hit.duplicate()
		for i in range(2):
			var next_target: Dictionary = {}
			var best_distance := 3.0
			for target in targets:
				var d: float = previous.node.global_position.distance_to(target.node.global_position)
				if not target in visited and d < best_distance:
					best_distance = d
					next_target = target
			if next_target.is_empty():
				break
			beam(previous.node.global_position, next_target.node.global_position, color, true)
			hit(next_target, float(spell.damage) * pow(0.65, i + 1), "连锁", color)
			totals.chains += 1
			visited.append(next_target)
			previous = next_target
	var hit_count: int = totals.hits - hits_before
	var damage_done: float = totals.damage - damage_before
	var effect_name := "爆炸 / 灼烧3秒" if element == "fire" else ("减速82% / 4秒" if element == "ice" else "最多2次连锁 / 65%递减")
	last_report = "第 %d 次试法 · %d 靶命中 · 即时伤害 %.1f\n%s · 作用半径 %.1fm · 间隔 %.2fs" % [casts_since_reset, hit_count, damage_done, effect_name, spell.radius, spell.cooldown]
	report_changed.emit(last_report)
	return {"hits": hit_count, "damage": damage_done, "element": element}

func beam(from: Vector3, to: Vector3, color: Color, electric: bool) -> void:
	var points: Array[Vector3] = [from]
	for i in range(1, 7):
		var p := from.lerp(to, float(i) / 7.0)
		if electric:
			p += Vector3(sin(float(i) * 9.0 + time_passed) * 0.12, cos(float(i) * 5.0) * 0.09, 0)
		points.append(p)
	points.append(to)
	var root := Node3D.new()
	effects.add_child(root)
	for i in range(points.size() - 1):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.010 if electric else 0.022
		mesh.bottom_radius = mesh.top_radius
		mesh.height = points[i].distance_to(points[i + 1])
		var segment := MeshInstance3D.new()
		segment.mesh = mesh
		segment.material_override = StaffVisual.material(color, 0, 0.65)
		segment.position = (points[i] + points[i + 1]) * 0.5
		root.add_child(segment)
		if segment.position.distance_to(points[i + 1]) > 0.001:
			segment.look_at(points[i + 1], Vector3.UP)
			segment.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3(0.98, 0.98, 0.98), 0.22)
	tween.tween_callback(root.queue_free)
	sparks(to, color)

func burst(at: Vector3, radius: float, color: Color) -> void:
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	sphere.mesh = mesh
	var mat := StaffVisual.material(Color(color, 0.17), 0, 1.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material_override = mat
	sphere.position = at
	sphere.scale = Vector3.ONE * 0.1
	effects.add_child(sphere)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(sphere, "scale", Vector3.ONE * radius * 2.0, 0.35)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.38)
	tween.chain().tween_callback(sphere.queue_free)

func sparks(at: Vector3, color: Color) -> void:
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.one_shot = true
	particles.amount = 24
	particles.lifetime = 0.65
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 180
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.9
	particles.gravity = Vector3(0, -1.0, 0)
	particles.scale_amount_min = 0.015
	particles.scale_amount_max = 0.045
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var particle_material := StaffVisual.material(color, 0, 1.8)
	particle_material.albedo_texture = load("res://assets/particles/light_01.png")
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_material.billboard_keep_scale = true
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = particle_material
	particles.mesh = mesh
	effects.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)
