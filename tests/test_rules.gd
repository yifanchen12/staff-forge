extends SceneTree

const Rules = preload("res://scripts/rules.gd")
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var rules := Rules.new()
	var run := rules.new_run(424242)
	check(rules.validate_run(run), "new run valid")
	check(not rules.craft(run, rules.default_design()).ok, "no material craft refused")
	check(rules.claim(run).ok and run.materials == 3, "claim once")
	check(not rules.claim(run).ok and run.materials == 3, "no duplicate materials")
	var invalid := rules.default_design()
	invalid.length = -1
	check(not rules.craft(run, invalid).ok and run.materials == 3, "invalid design no consumption")
	check(rules.craft(run, rules.default_design()).ok and run.materials == 2, "craft consumes one")
	var staff := rules.active(run)
	for level in range(13):
		staff.level = level
		for m in range(3):
			for r in range(2):
				staff.design.material = m
				staff.design.rune = r
				var probabilities: Dictionary = rules.probabilities(run, staff)
				var total := 0.0
				for p in probabilities.values():
					total += float(p)
					check(p >= 0.0 and p <= 1.0, "probability bounded")
				check(absf(total - 1.0) < 0.00001, "probability normalized")
	staff.level = 0
	check(rules.probabilities(run, staff)["break"] == 0, "zero level never shatters")
	staff.level = 6
	staff.design = rules.default_design()
	var base_risk: float = rules.probabilities(run, staff)["break"]
	staff.design.material = 1
	check(rules.probabilities(run, staff)["break"] < base_risk, "ironwood lowers risk")
	staff.design = rules.default_design()
	run.relics = ["ward"]
	check(rules.probabilities(run, staff)["break"] < base_risk, "ward lowers risk")
	run.relics = ["value"]
	check(rules.value(run, staff) == int(round(80 * pow(1.5, 6) * 1.25)), "value relic applies")
	run.relics = []
	staff.charge = 6
	check(rules.probabilities(run, staff)["break"] == 0, "pending resonance probability correct")
	check(rules.infuse(run).activated and staff.resonance == 3.0, "next hit activates resonance")
	check(not rules.infuse(run).ok, "cooldown prevents double infusion")
	rules.tick(run, 0.7)
	var copy: Dictionary = JSON.parse_string(JSON.stringify(run))
	var a: Dictionary = rules.infuse(run)
	var b: Dictionary = rules.infuse(copy)
	check(a.outcome == b.outcome and run.rng_state == copy.rng_state, "RNG survives JSON round trip")
	rules.tick(run, 0.7)
	check(rules.validate_run(run), "infused state valid")
	staff.level = 12
	staff.resonance = 3.0
	staff.cooldown = 0.0
	rules.infuse(run)
	check(staff.level <= 12, "max level clamped")
	staff.level = 5
	staff.resonance = 0.0
	staff.cooldown = 0.0
	staff.charge = 0
	# Search a deterministic seed for a fatal ticket and test protection twice.
	var fatal_state := ""
	for seed_value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var state_before := str(rng.state)
		if rng.randf() < rules.probabilities(run, staff)["break"]:
			fatal_state = state_before
			break
	check(not fatal_state.is_empty(), "fatal test ticket found")
	run.relics = ["shield"]
	run.rng_state = fatal_state
	var protected: Dictionary = rules.infuse(run)
	check(protected.shielded and staff.alive and staff.level == 4, "first fatal hit shielded")
	staff.cooldown = 0.0
	staff.level = 5
	run.rng_state = fatal_state
	var broken: Dictionary = rules.infuse(run)
	check(broken.outcome == "break" and not staff.alive, "protection used only once")
	check(run.blueprint == rules.default_design(), "broken blueprint retained")
	check(rules.validate_run(run), "broken state valid")
	rules.craft(run, rules.default_design())
	staff = rules.active(run)
	check(not rules.buy_relic(run, "value").ok and staff.alive, "insufficient exchange no loss")
	staff.level = 5
	check(rules.buy_relic(run, "value").ok and not staff.alive, "exchange consumes staff")
	check(not rules.buy_relic(run, "value").ok, "duplicate relic refused")
	rules.craft(run, rules.default_design())
	staff = rules.active(run)
	staff.level = 4
	var offered := rules.value(run, staff)
	check(rules.offer_staff(run).ok and run.offer == offered, "offer exact value")
	check(not rules.offer_staff(run).ok and run.offer == offered, "cannot deliver twice")
	var winning := rules.new_run(7)
	for day in range(5):
		winning.offer = rules.balance.quotas[day]
		rules.settle(winning)
	check(winning.status == "won" and winning.day == 5, "five days victory")
	check(not rules.settle(winning).ok, "cannot settle ended run")
	var losing := rules.new_run(7)
	for day in range(3):
		rules.settle(losing)
	check(losing.status == "lost" and losing.misses == 3, "third deficit loses")
	var inherited := rules.new_run(8)
	rules.claim(inherited)
	rules.craft(inherited, rules.default_design())
	inherited.relics = ["ward"]
	inherited.offer = 200
	rules.settle(inherited)
	check(inherited.materials == 2 and inherited.unclaimed == 3 and rules.usable(inherited).size() == 1 and inherited.relics == ["ward"], "inventory carried between days")
	var long_stats := rules.stats(rules.default_design())
	var short_design := rules.default_design()
	short_design.length = 0.8
	var short_stats := rules.stats(short_design)
	check(long_stats.damage > short_stats.damage and long_stats.cooldown > short_stats.cooldown, "length tradeoff")
	var thicker := rules.default_design()
	thicker.thickness = 0.05
	var thick_stats := rules.stats(thicker)
	check(thick_stats.stability > long_stats.stability and thick_stats.cooldown > long_stats.cooldown, "thickness tradeoff")
	var relic_test := rules.new_run(20)
	rules.claim(relic_test)
	rules.craft(relic_test, rules.default_design())
	var relic_staff := rules.active(relic_test)
	var original_interval := rules.infusion_interval(relic_test)
	relic_test.relics = ["speed", "charge", "duration"]
	check(rules.infusion_interval(relic_test) < original_interval, "speed relic interval")
	check(rules.threshold(relic_test) == 4, "charge relic threshold")
	relic_staff.charge = 4
	check(rules.infuse(relic_test).activated and relic_staff.resonance == 4.5, "duration and charge combine")
	relic_staff.level = 8
	check(not rules.buy_relic(relic_test, "ward").ok and relic_staff.alive, "full relic slots refuse without consuming")
	var scatter := rules.default_design()
	scatter.head = 1
	var area := rules.default_design()
	area.head = 2
	check(rules.stats(scatter).damage < long_stats.damage, "scatter shares damage")
	check(rules.stats(area).radius > long_stats.radius, "area expands radius")
	var corrupt: Dictionary = inherited.duplicate(true)
	corrupt.staffs[0].id = 777
	check(not rules.validate_run(corrupt), "malformed ID refused")
	corrupt = inherited.duplicate(true)
	corrupt.blueprint.element = 99
	check(not rules.validate_run(corrupt), "bad enum refused")
	corrupt = inherited.duplicate(true)
	corrupt.history = ["broken"]
	check(not rules.validate_run(corrupt), "malformed history refused")
	var folder := "res://artifacts/test-save"
	DirAccess.make_dir_recursive_absolute(folder)
	var store := Store.new(rules, folder)
	check(store.save_run(inherited), "save written")
	var loaded: Dictionary = store.load_run()
	check(loaded.rng_state == inherited.rng_state and loaded.staffs.size() == 1, "save restored")
	inherited.offer = 100
	check(store.save_run(inherited), "second save rotates backup")
	var damaged := FileAccess.open(folder.path_join("run.json"), FileAccess.WRITE)
	damaged.store_string("{broken")
	damaged.close()
	check(store.load_run().offer == 0 and not store.notice.is_empty(), "corrupt main restores backup")
	var settings: Dictionary = store.default_settings()
	settings.volume = 0.2
	check(store.save_settings(settings) and store.load_settings().volume == 0.2, "settings restored")
	var report := {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string}
	var output := FileAccess.open("res://artifacts/rules-test.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("RULES TEST: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
