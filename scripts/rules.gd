class_name ForgeRules
extends RefCounted

# StaffDesign, StaffState, SpellStats and RunState are JSON-compatible
# dictionaries. No scene object participates in their rules or serialization.
var balance: Dictionary
var chronicle = preload("res://scripts/chronicle.gd").new()

func _init() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))

func default_design() -> Dictionary:
	return {"material": 0, "head": 0, "element": 0, "rune": 1,
		"length": 1.2, "thickness": 0.035, "color": "#a78d6c"}

func new_run(seed_value: int = 0, previous: Dictionary = {}) -> Dictionary:
	var memory: Dictionary = previous.get("campaign", chronicle.fresh()).duplicate(true)
	if not previous.is_empty():
		memory.loop += 1
	var rng := RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	return {"version": 1, "day": 1, "misses": 0, "offer": 0, "materials": 0,
		"unclaimed": int(balance.daily_materials), "staffs": [], "relics": [],
		"active_id": -1, "next_id": 1, "blueprint": default_design(),
		"rng_state": str(rng.state), "status": "playing", "tutorial_step": 0,
		"history": [], "play_seconds": 0.0, "campaign": memory}

func design_valid(d: Variant) -> bool:
	if not d is Dictionary:
		return false
	for key in ["material", "head", "element", "rune"]:
		if not d.has(key) or not (d[key] is int or d[key] is float):
			return false
		if d[key] != int(d[key]):
			return false
		var count := 2 if key == "rune" else 3
		if int(d[key]) < 0 or int(d[key]) >= count:
			return false
	for key in ["length", "thickness"]:
		if not d.has(key) or not (d[key] is float or d[key] is int):
			return false
		if not is_finite(float(d[key])):
			return false
	if d.length < balance.length_min or d.length > balance.length_max:
		return false
	if d.thickness < balance.thickness_min or d.thickness > balance.thickness_max:
		return false
	return d.get("color", null) is String and d.color.is_valid_html_color()

func active(run: Dictionary) -> Dictionary:
	for staff in run.staffs:
		if int(staff.id) == int(run.active_id) and staff.alive:
			return staff
	return {}

func usable(run: Dictionary) -> Array:
	return run.staffs.filter(func(s): return s.alive)

func value(run: Dictionary, staff: Dictionary) -> int:
	if staff.is_empty() or not staff.alive:
		return 0
	var multiplier := 1.25 if "value" in run.relics else 1.0
	return int(round(float(balance.base_value) * pow(float(balance.value_multiplier), int(staff.level)) * multiplier))

func stats(design: Dictionary, level: int = 0, tree: Array = []) -> Dictionary:
	var material: Dictionary = balance.materials[int(design.material)]
	var length_ratio := float(design.length) / 1.2
	var width_ratio := float(design.thickness) / 0.035
	var cooldown := 0.95 * float(material.cooldown) * sqrt(length_ratio * width_ratio)
	cooldown *= 0.78 if int(design.rune) == 0 else 1.08
	var damage := 24.0 * float(material.damage) * length_ratio * (1.0 + float(level) * 0.17)
	var mode: String = balance.heads[int(design.head)].mode
	var radius := 1.45
	if mode == "scatter":
		damage *= 0.55
		radius = 1.15
	elif mode == "area":
		damage *= 0.72
		radius = 2.8
	else:
		damage *= 1.2
	var result := {"damage": snappedf(damage, 0.1), "cooldown": snappedf(cooldown, 0.01),
		"stability": float(material.stability) * width_ratio,
		"radius": radius * sqrt(length_ratio), "mode": mode,
		"element": balance.elements[int(design.element)].id}
	for i in range(tree.size()):
		var tier: Dictionary = chronicle.data.tiers[i]
		if level >= int(tier.level):
			for node in tier.nodes:
				if node.id == tree[i]:
					for key in node.multipliers:
						result[key] *= float(node.multipliers[key])
	return result

func threshold(run: Dictionary) -> int:
	return 4 if "charge" in run.relics else int(balance.charge_threshold)

func infusion_interval(run: Dictionary) -> float:
	return float(balance.infusion_cooldown) * (0.75 if "speed" in run.relics else 1.0)

func probabilities(run: Dictionary, staff: Dictionary) -> Dictionary:
	if staff.is_empty():
		return {}
	var spell := stats(staff.design, int(staff.level), staff.get("tree", []))
	var risk := float(staff.level) * float(balance.break_per_level) / maxf(0.1, spell.stability)
	risk *= 1.1 if int(staff.design.rune) == 0 else 0.75
	if "ward" in run.relics:
		risk *= 0.8
	if staff.resonance > 0.0 or int(staff.charge) >= threshold(run):
		risk = 0.0
	risk = clampf(risk, 0.0, 0.8)
	var result := {"break": risk}
	for key in balance.remaining_weights:
		result[key] = (1.0 - risk) * float(balance.remaining_weights[key])
	return result

func fail(message: String) -> Dictionary:
	return {"ok": false, "message": message}

func claim(run: Dictionary) -> Dictionary:
	if run.status != "playing" or int(run.unclaimed) <= 0:
		return fail("今天的材料已经领取。")
	run.materials += int(run.unclaimed)
	var amount := int(run.unclaimed)
	run.unclaimed = 0
	run.tutorial_step = maxi(int(run.tutorial_step), 1)
	return {"ok": true, "message": "领取 %d 份灵木与晶核。材料会保留到次日。" % amount}

func craft(run: Dictionary, design: Dictionary) -> Dictionary:
	if run.status != "playing" or int(run.materials) <= 0:
		return fail("没有制作材料，请到材料架领取。")
	if not design_valid(design):
		return fail("设计参数无效，材料未消耗。")
	var staff := {"id": int(run.next_id), "design": design.duplicate(true), "level": 0,
		"charge": 0, "resonance": 0.0, "cooldown": 0.0, "alive": true, "protected": false, "tree": []}
	run.staffs.append(staff)
	run.next_id += 1
	run.materials -= 1
	run.active_id = staff.id
	run.blueprint = design.duplicate(true)
	run.tutorial_step = maxi(int(run.tutorial_step), 2)
	return {"ok": true, "staff_id": staff.id, "message": "法杖 #%02d 组装完成。蓝图已保存。" % staff.id}

func select_staff(run: Dictionary, id: int) -> Dictionary:
	for staff in run.staffs:
		if int(staff.id) == id and staff.alive:
			run.active_id = id
			return {"ok": true, "message": "已装备法杖 #%02d。" % id}
	return fail("这根法杖已经无法使用。")

func infuse(run: Dictionary) -> Dictionary:
	var staff := active(run)
	if run.status != "playing" or staff.is_empty():
		return fail("先选择一根可用的法杖。")
	if staff.cooldown > 0.0001:
		return fail("灌注尚未完成。")
	if int(staff.level) >= int(balance.max_level):
		return fail("已达到 +12 封印神器形态。可以试法、交付或留作收藏。")
	var previous_level := int(staff.level)
	var activated := false
	if int(staff.charge) >= threshold(run) and staff.resonance <= 0.0:
		staff.charge = 0
		staff.resonance = float(balance.resonance_seconds) + (1.5 if "duration" in run.relics else 0.0)
		activated = true
	var probabilities_now := probabilities(run, staff)
	var rng := RandomNumberGenerator.new()
	rng.state = int(run.rng_state)
	var ticket := rng.randf()
	run.rng_state = str(rng.state)
	var outcome := "break"
	var cumulative := 0.0
	for key in ["break", "success", "great", "hold", "damage"]:
		cumulative += float(probabilities_now[key])
		if ticket <= cumulative:
			outcome = key
			break
	var shielded := false
	if outcome == "break" and "shield" in run.relics and not staff.protected:
		staff.protected = true
		outcome = "damage"
		shielded = true
	match outcome:
		"success": staff.level = mini(int(balance.max_level), int(staff.level) + 1)
		"great": staff.level = mini(int(balance.max_level), int(staff.level) + 2)
		"damage": staff.level = maxi(0, int(staff.level) - 1)
		"break":
			staff.alive = false
			staff.resonance = 0.0
			staff.charge = 0
			choose_next(run)
	staff.cooldown = infusion_interval(run)
	if staff.alive and staff.resonance <= 0.0:
		staff.charge = mini(threshold(run), int(staff.charge) + 1)
	run.tutorial_step = maxi(int(run.tutorial_step), 3)
	var names := {"success": "灌注成功", "great": "大成功！", "hold": "能量停滞", "damage": "晶核受损", "break": "法杖破碎"}
	var message: String = names[outcome]
	if shielded:
		message = "护罩挡下破碎，法杖降级"
	if activated:
		message = "共鸣开启！ " + message
	if outcome == "break":
		message += " · 蓝图保留，可重新组装"
	else:
		message += " · +%d → +%d" % [previous_level, staff.level]
	return {"ok": true, "outcome": outcome, "activated": activated,
		"shielded": shielded, "previous_level": previous_level, "level": staff.level, "message": message}

func tick(run: Dictionary, delta: float) -> void:
	if run.status != "playing":
		return
	run.play_seconds += delta
	for staff in run.staffs:
		staff.cooldown = maxf(0.0, float(staff.cooldown) - delta)
		staff.resonance = maxf(0.0, float(staff.resonance) - delta)

func choose_next(run: Dictionary) -> void:
	var available := usable(run)
	run.active_id = -1 if available.is_empty() else int(available[0].id)

func offer_staff(run: Dictionary) -> Dictionary:
	var staff := active(run)
	if run.status != "playing" or staff.is_empty():
		return fail("没有可交付的法杖。")
	var story: Dictionary = chronicle.offer(run.campaign, staff)
	var amount := value(run, staff)
	run.offer += amount
	staff.alive = false
	staff["removed_reason"] = "offered"
	choose_next(run)
	run.tutorial_step = maxi(int(run.tutorial_step), 5)
	return {"ok": true, "story": story, "message": "封印吸收 %d 灵值。交付的法杖已消耗。" % amount}

func buy_relic(run: Dictionary, relic_id: String) -> Dictionary:
	if run.status != "playing":
		return fail("契约已结束。")
	if relic_id in run.relics:
		return fail("已经持有这件遗物。")
	if run.relics.size() >= 3:
		return fail("遗物槽已满，最多持有3件。")
	var definition: Dictionary = {}
	for relic in balance.relics:
		if relic.id == relic_id:
			definition = relic
	if definition.is_empty():
		return fail("遗物不存在。")
	var staff := active(run)
	if value(run, staff) < int(definition.price):
		return fail("当前法杖价值不足 %d，交换不会消耗它。" % definition.price)
	staff.alive = false
	staff["removed_reason"] = "exchanged"
	run.relics.append(relic_id)
	choose_next(run)
	return {"ok": true, "message": "获得「%s」。整根法杖用于交换，无找零。" % definition.name}

func settle(run: Dictionary) -> Dictionary:
	if run.status != "playing":
		return fail("契约已结束。")
	var quota := int(balance.quotas[int(run.day) - 1])
	var paid := int(run.offer) >= quota
	if not paid:
		run.misses += 1
	run.history.append({"day": run.day, "offer": run.offer, "quota": quota, "paid": paid})
	var message := "今日供能完成，封印趋于稳定。" if paid else "供能不足，封印出现一道裂隙。"
	if int(run.misses) >= 3:
		run.status = "lost"
		message = "三道裂隙撕开封印。契约失败。"
	elif int(run.day) >= int(balance.days):
		run.status = "won"
		message = "你守住了五夜封印。契约完成！"
	else:
		run.day += 1
		run.offer = 0
		run.unclaimed = int(balance.daily_materials)
		for staff in run.staffs:
			staff.resonance = 0.0
			staff.cooldown = 0.0
	return {"ok": true, "paid": paid, "message": message, "status": run.status}

func validate_run(candidate: Variant) -> bool:
	if not candidate is Dictionary:
		return false
	var required := ["version", "day", "misses", "offer", "materials", "unclaimed",
		"staffs", "relics", "active_id", "next_id", "blueprint", "rng_state",
		"status", "history", "tutorial_step", "play_seconds"]
	for key in required:
		if not candidate.has(key):
			return false
	if candidate.version != 1 or not candidate.status in ["playing", "won", "lost"]:
		return false
	for key in ["day", "misses", "offer", "materials", "unclaimed", "active_id", "next_id", "tutorial_step"]:
		if not (candidate[key] is int or candidate[key] is float) or not is_finite(float(candidate[key])) or candidate[key] != int(candidate[key]):
			return false
	if candidate.day < 1 or candidate.day > 5 or candidate.misses < 0 or candidate.misses > 3:
		return false
	if candidate.materials < 0 or candidate.materials > 15 or candidate.unclaimed < 0 or candidate.unclaimed > 3 or candidate.offer < 0:
		return false
	if candidate.next_id < 1 or candidate.next_id > 16 or candidate.tutorial_step < 0 or candidate.tutorial_step > 5:
		return false
	if not candidate.rng_state is String or not candidate.rng_state.is_valid_int():
		return false
	if not candidate.play_seconds is float and not candidate.play_seconds is int:
		return false
	if not is_finite(float(candidate.play_seconds)) or candidate.play_seconds < 0:
		return false
	if not candidate.staffs is Array or candidate.staffs.size() > 15 or not candidate.relics is Array or candidate.relics.size() > 3 or not candidate.history is Array:
		return false
	if candidate.history.size() > 5:
		return false
	for day in candidate.history:
		if not day is Dictionary or not day.get("paid") is bool:
			return false
		for key in ["day", "offer", "quota"]:
			if not (day.get(key) is int or day.get(key) is float) or not is_finite(float(day[key])) or day[key] != int(day[key]):
				return false
		if day.day < 1 or day.day > 5 or day.offer < 0 or day.quota < 0:
			return false
	if not design_valid(candidate.blueprint):
		return false
	var ids := {}
	for staff in candidate.staffs:
		if not staff is Dictionary:
			return false
		for key in ["id", "design", "level", "charge", "resonance", "cooldown", "alive", "protected"]:
			if not staff.has(key):
				return false
		if not chronicle.tree_valid(staff.get("tree", [])):
			return false
		if not design_valid(staff.design) or not staff.alive is bool or not staff.protected is bool:
			return false
		for key in ["id", "level", "charge"]:
			if not (staff[key] is float or staff[key] is int) or not is_finite(float(staff[key])) or staff[key] != int(staff[key]):
				return false
		if staff.id < 1 or staff.id >= candidate.next_id or ids.has(int(staff.id)) or staff.level < 0 or staff.level > balance.max_level or staff.charge < 0 or staff.charge > balance.charge_threshold:
			return false
		for key in ["resonance", "cooldown"]:
			if not (staff[key] is float or staff[key] is int) or not is_finite(float(staff[key])) or staff[key] < 0 or staff[key] > 6.0:
				return false
		ids[int(staff.id)] = true
	var relic_ids := {}
	for relic in candidate.relics:
		if not relic is String or relic_ids.has(relic):
			return false
		if not balance.relics.any(func(d): return d.id == relic):
			return false
		relic_ids[relic] = true
	if candidate.has("campaign") and not chronicle.valid(candidate.campaign):
		return false
	if candidate.active_id != -1 and active(candidate).is_empty():
		return false
	return true

func migrate_run(state: Dictionary) -> Dictionary:
	if not state.has("campaign"):
		state.campaign = chronicle.fresh()
	for staff in state.staffs:
		if not staff.has("tree"):
			staff.tree = []
	return state

func choose_branch(run: Dictionary, node_id: String) -> Dictionary:
	var staff := active(run)
	if run.status != "playing" or staff.is_empty():
		return fail("先装备一根可用法杖。")
	var tree: Array = staff.get("tree", [])
	var index := tree.size()
	if index >= chronicle.data.tiers.size():
		return fail("这根法杖已完成全部分支选择。")
	var tier: Dictionary = chronicle.data.tiers[index]
	if int(staff.level) < int(tier.level):
		return fail("先灌注至 +%d，才能刻下这一层分支。" % tier.level)
	for node in tier.nodes:
		if node.id == node_id:
			tree.append(node_id)
			staff.tree = tree
			return {"ok": true, "message": "刻下「%s」。外观与属性已经改变。" % node.name}
	return fail("此分支不属于当前层级，选择未改变。")
