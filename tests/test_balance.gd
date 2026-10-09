extends SceneTree

const Rules = preload("res://scripts/rules.gd")

func simulate(rules: ForgeRules, seed_value: int, strategy: String) -> Dictionary:
	var run := rules.new_run(seed_value)
	var hits := 0
	var broken := 0
	while run.status == "playing":
		rules.claim(run)
		var quota: int = rules.balance.quotas[int(run.day) - 1]
		while run.materials > 0:
			if strategy == "conservative" and run.offer >= quota:
				break
			var design := rules.default_design()
			design.material = 1 if strategy == "conservative" else 0
			rules.craft(run, design)
			var staff := rules.active(run)
			var remaining: int = maxi(0, quota - int(run.offer))
			var target_value: float = maxf(80.0, float(remaining) / float(int(run.materials) + 1))
			var max_hits := 100
			while staff.alive and max_hits > 0:
				var stop := rules.value(run, staff) >= target_value if strategy == "conservative" else int(staff.level) >= 9
				if stop:
					break
				var result := rules.infuse(run)
				if result.ok:
					hits += 1
					max_hits -= 1
				rules.tick(run, rules.infusion_interval(run))
			if staff.alive:
				rules.offer_staff(run)
			else:
				broken += 1
		rules.settle(run)
	return {"won": run.status == "won", "hits": hits, "broken": broken, "misses": run.misses}

func _initialize() -> void:
	var rules := Rules.new()
	var report := {"runs_per_strategy": 200, "seed_start": 1, "initial_balance_unchanged": true, "strategies": {}}
	for strategy in ["conservative", "greedy"]:
		var wins := 0
		var hits := 0
		var broken := 0
		var misses := 0
		for seed_value in range(1, 201):
			var result := simulate(rules, seed_value, strategy)
			wins += int(result.won)
			hits += int(result.hits)
			broken += int(result.broken)
			misses += int(result.misses)
		report.strategies[strategy] = {"win_rate": float(wins) / 200.0,
			"average_infusions": float(hits) / 200.0, "average_broken": float(broken) / 200.0,
			"average_deficits": float(misses) / 200.0}
		print("BALANCE %s: %.1f%% wins, %.1f infusions, %.1f broken" % [strategy, float(wins) / 2.0, float(hits) / 200.0, float(broken) / 200.0])
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file := FileAccess.open("res://artifacts/balance-test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit()
