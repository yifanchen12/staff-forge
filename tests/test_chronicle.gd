extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Store = preload("res://scripts/save_store.gd")
const Visual = preload("res://scripts/staff_visual.gd")
var checks := 0
var failures := 0
var rules := Rules.new()

func check(condition: bool, caption: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(caption)

func staff_for(run: Dictionary, changes: Dictionary, level: int) -> Dictionary:
	var design := rules.default_design()
	for key in changes:
		design[key] = changes[key]
	check(rules.craft(run, design).ok, "craft story fixture")
	var staff := rules.active(run)
	staff.level = level
	return staff

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	for ending in ["keeper", "dawn"]:
		var run := rules.new_run(42)
		check(rules.validate_run(run), "new memory validates")
		check(not rules.chronicle.discover(run, "mirror").ok, "later clue gated")
		check(rules.chronicle.discover(run, "scar").ok, "optional workshop carving")
		check(rules.chronicle.discover(run, "ledger").ok, "ledger discovered")
		check(not rules.chronicle.discover(run, "ledger").ok and run.campaign.clues.size() == 2, "clue idempotent")
		rules.claim(run)
		staff_for(run, {"element": 1}, 3)
		var result := rules.offer_staff(run)
		check(result.story.is_empty() and run.campaign.chapters.is_empty() and rules.usable(run).is_empty(), "wrong attribute only supplies seal")
		staff_for(run, {}, 2)
		check(rules.offer_staff(run).story.is_empty(), "underlevel cannot trigger")
		staff_for(run, {}, 3)
		result = rules.offer_staff(run)
		check(not result.story.is_empty() and run.campaign.chapters.size() == 1, "ember triggered atomically with offer")
		check(not rules.offer_staff(run).ok, "duplicate offering refused")
		check(rules.chronicle.discover(run, "letter").ok, "optional bottle note")
		check(not rules.chronicle.discover(run, "mirror").ok, "same loop mirror unreadable")
		var echo: String = run.campaign.last_echo
		run = rules.new_run(43, run)
		check(run.campaign.loop == 2 and run.campaign.chapters.size() == 1 and run.staffs.is_empty() and run.campaign.last_echo == echo, "new loop remembers only campaign")
		check(rules.chronicle.discover(run, "mirror").ok, "mirror readable next loop")
		rules.claim(run)
		staff_for(run, {"material": 1, "element": 1, "head": 0}, 6)
		check(not rules.offer_staff(run).story.is_empty(), "frost triggered")
		check(not rules.chronicle.discover(run, "coil").ok, "coil waits another loop")
		run = rules.new_run(44, run)
		rules.claim(run)
		check(rules.chronicle.discover(run, "coil").ok, "coil third loop")
		staff_for(run, {"material": 2, "element": 2, "rune": 0}, 6)
		check(not rules.offer_staff(run).story.is_empty(), "thunder triggered")
		check(rules.chronicle.discover(run, "door").ok, "final letter appears")
		if ending == "keeper":
			staff_for(run, {"element": 1, "head": 2, "rune": 1}, 6)
		else:
			staff_for(run, {"element": 0, "head": 0, "rune": 0}, 9)
		check(rules.chronicle.offer_hint(run.campaign, rules.active(run)).contains("此作品将触发"), "preview matches actual predicate")
		result = rules.offer_staff(run)
		check(run.campaign.ending == ending and not result.story.is_empty(), "ending " + ending)
		check(rules.validate_run(run), "complete campaign valid")
		check(run.campaign.clues.size() == 6, "all six clues collectible")
		var restored: Dictionary = JSON.parse_string(JSON.stringify(run))
		check(rules.validate_run(restored) and restored.campaign.ending == ending, "memory JSON roundtrip")
		run = rules.new_run(45, restored)
		check(run.campaign.ending == ending and run.campaign.loop == 4, "ending retained on further return")
		rules.claim(run)
		staff_for(run, {}, 9)
		check(rules.offer_staff(run).story.is_empty() and run.campaign.chapters.size() == 4, "story never duplicates after ending")
	var run := rules.new_run(2)
	rules.claim(run)
	var staff := staff_for(run, {}, 2)
	check(not rules.choose_branch(run, "lance").ok, "branch level gate")
	staff.level = 3
	check(not rules.choose_branch(run, "wings").ok, "branch prerequisite gate")
	check(rules.choose_branch(run, "lance").ok, "first branch")
	check(not rules.choose_branch(run, "censer").ok and staff.tree == ["lance"], "cannot reselect first tier")
	staff.level = 6
	check(rules.choose_branch(run, "prism").ok, "second branch")
	staff.level = 9
	check(rules.choose_branch(run, "wings").ok, "third branch")
	check(not rules.choose_branch(run, "satellites").ok, "complete tree immutable")
	var base := rules.stats(staff.design, 9)
	var enhanced := rules.stats(staff.design, 9, staff.tree)
	check(enhanced.damage > base.damage and enhanced.stability > base.stability and enhanced.cooldown < base.cooldown, "shared stats apply branch effects")
	var old_probs := rules.probabilities(run, staff)
	var clone := staff.duplicate(true)
	clone.tree = []
	check(old_probs["break"] < rules.probabilities(run, clone)["break"], "stability branch changes real infusion odds")
	check(rules.stats(staff.design, 2, staff.tree) == rules.stats(staff.design, 2), "downgrade suspends all unavailable perks")
	var visual := Visual.new()
	root.add_child(visual)
	for first in ["lance", "censer", "astrolabe"]:
		for second in ["thorns", "prism"]:
			for third in ["satellites", "wings"]:
				var tree := [first, second, third]
				visual.rebuild(staff.design, 12, tree)
				check(visual.has_node("Branch_" + first) and visual.has_node("Branch_" + second) and visual.has_node("Branch_" + third), "distinct geometry " + str(tree))
				visual.rebuild(staff.design, 5, tree)
				check(visual.has_node("Branch_" + first) and not visual.has_node("Branch_" + second) and not visual.has_node("Branch_" + third), "downgrade geometry " + str(tree))
	visual.queue_free()
	var folder := "res://artifacts/chronicle-save"
	DirAccess.make_dir_recursive_absolute(folder)
	var store := Store.new(rules, folder)
	check(store.save_run(run), "save tree")
	check(store.load_run().staffs[0].tree == staff.tree, "restore tree")
	var old := run.duplicate(true)
	old.erase("campaign")
	old.staffs[0].erase("tree")
	check(store.write_json(store.path("run.json"), old), "legacy fixture written")
	var migrated := store.load_run()
	check(migrated.campaign.loop == 1 and migrated.staffs[0].tree.is_empty() and migrated.staffs[0].level == 9, "v0.2 migration preserves item")
	var bad := run.duplicate(true)
	bad.campaign.chapters = ["frost"]
	check(not rules.validate_run(bad), "malformed chapter order refused")
	bad = run.duplicate(true)
	bad.staffs[0].tree = ["wings"]
	check(not rules.validate_run(bad), "malformed branch refused")
	bad = run.duplicate(true)
	bad.campaign.loop = -1
	check(not rules.validate_run(bad), "malformed loop refused")
	var out := FileAccess.open("res://artifacts/chronicle-test.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	out.close()
	await process_frame
	print("CHRONICLE TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
