extends SceneTree

const Visual = preload("res://scripts/staff_visual.gd")
const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures := 0

func check(condition: bool, caption: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(caption)

func mesh_count(node: Node) -> int:
	var result := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		result += mesh_count(child)
	return result

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	var rules := Rules.new()
	var design := rules.default_design()
	var staff := Visual.new()
	root.add_child(staff)
	var counts: Array = []
	for level in range(13):
		staff.rebuild(design, level)
		counts.append(mesh_count(staff))
		check(staff.evolution == mini(4, int(level / 3.0)), "level maps to evolution")
		if level > 0:
			check(counts[level] > counts[level - 1], "every level adds geometry")
		check(is_equal_approx(staff.tip_position.y, design.length + 0.25), "tip remains attached")
	for length_value in [0.8, 1.6]:
		for head_value in range(3):
			design.length = length_value
			design.head = head_value
			staff.rebuild(design, 12)
			check(is_equal_approx(staff.get_node("Evolution").position.y, length_value + 0.18), "crown follows shaft size")
			check(staff.orbits.size() == 3, "artifact has moving orbit rings")
	var element_colors: Array = []
	for element in range(3):
		design.element = element
		staff.rebuild(design, 9)
		element_colors.append(staff.element_color)
	check(element_colors[0] != element_colors[1] and element_colors[1] != element_colors[2], "element colors distinct")
	staff.rebuild(rules.default_design(), 9)
	staff.rebuild(rules.default_design(), 2)
	check(staff.evolution == 0 and staff.orbits.is_empty(), "downgrade removes evolved ornaments")
	for expected in ["success", "great", "hold", "damage", "break"]:
		var found := false
		for seed_value in range(1, 500):
			var run := rules.new_run(seed_value)
			rules.claim(run)
			rules.craft(run, rules.default_design())
			var state := rules.active(run)
			state.level = 2
			var outcome := rules.infuse(run)
			if outcome.outcome != expected:
				continue
			check(outcome.previous_level == 2, "probability result keeps prior level")
			var expected_level: int = {"success": 3, "great": 4, "hold": 2, "damage": 1, "break": 2}[expected]
			check(state.level == expected_level, "probabilistic level delta " + expected)
			if expected == "break":
				check(not state.alive and run.blueprint == rules.default_design(), "break keeps only blueprint")
			else:
				staff.rebuild(state.design, state.level)
				check(staff.visible_level == state.level, "result reflected by actual model")
			found = true
			break
		check(found, "all five probabilistic branches reachable")
	var run := rules.new_run(14)
	rules.claim(run)
	rules.craft(run, rules.default_design())
	rules.active(run).level = 12
	var rng_before: String = run.rng_state
	check(not rules.infuse(run).ok and run.rng_state == rng_before, "artifact cap rejects action without reroll")
	var report := {"checks": checks, "failures": failures, "mesh_counts_per_level": counts}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/visuals-test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	staff.queue_free()
	await process_frame
	print("VISUALS TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
