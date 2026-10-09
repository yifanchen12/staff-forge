extends RefCounted

var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chronicle.json"))

func fresh() -> Dictionary:
	return {"loop": 1, "clues": [], "chapters": [], "chapter_loops": [], "ending": "", "last_echo": ""}

func valid(meta: Variant) -> bool:
	if not meta is Dictionary:
		return false
	if not (meta.get("loop") is int or meta.get("loop") is float):
		return false
	if not is_finite(float(meta.loop)) or meta.loop != int(meta.loop) or meta.loop < 1:
		return false
	if not meta.get("clues") is Array or not meta.get("chapters") is Array or not meta.get("chapter_loops") is Array:
		return false
	if not meta.get("ending") in ["", "keeper", "dawn"] or not meta.get("last_echo") is String:
		return false
	var seen := {}
	for id in meta.clues:
		if not id is String or seen.has(id) or not data.clues.any(func(c): return c.id == id):
			return false
		seen[id] = true
	if meta.chapters.size() > data.chapters.size() or meta.chapters.size() != meta.chapter_loops.size():
		return false
	for i in range(meta.chapters.size()):
		if meta.chapters[i] != data.chapters[i].id or not data.chapters[i].clue in meta.clues:
			return false
		var n: Variant = meta.chapter_loops[i]
		if not (n is int or n is float) or not is_finite(float(n)) or n != int(n) or n < 1 or n > meta.loop:
			return false
		if i > 0 and (n < meta.chapter_loops[i - 1] or (data.chapters[i].later and n <= meta.chapter_loops[i - 1])):
			return false
	return (meta.ending == "") == (meta.chapters.size() < 4)

func tree_valid(tree: Variant) -> bool:
	if not tree is Array or tree.size() > data.tiers.size():
		return false
	for i in range(tree.size()):
		if not tree[i] is String or not data.tiers[i].nodes.any(func(n): return n.id == tree[i]):
			return false
	return true

func clue(id: String) -> Dictionary:
	for entry in data.clues:
		if entry.id == id:
			return entry
	return {}

func available(meta: Dictionary, entry: Dictionary) -> bool:
	if entry.is_empty() or meta.chapters.size() < int(entry.chapter):
		return false
	return not entry.later or (int(entry.chapter) > 0 and int(meta.loop) > int(meta.chapter_loops[int(entry.chapter) - 1]))

func discover(run: Dictionary, id: String) -> Dictionary:
	var entry := clue(id)
	if not available(run.campaign, entry):
		return {"ok": false, "message": "这里只剩无法辨认的痕迹。也许另一轮的你能读懂它。"}
	if id in run.campaign.clues:
		return {"ok": false, "message": "这条线索已记入手记。", "reread": true}
	run.campaign.clues.append(id)
	return {"ok": true, "message": "发现线索：「%s」。按 J 重读。" % entry.name, "title": entry.name, "text": entry.text}

func matches(staff: Dictionary, conditions: Dictionary) -> bool:
	for key in conditions:
		if key == "level":
			if int(staff.level) < int(conditions[key]):
				return false
		elif int(staff.design[key]) != int(conditions[key]):
			return false
	return true

func offer(meta: Dictionary, staff: Dictionary) -> Dictionary:
	meta.last_echo = "%s · +%d" % [["烬火", "霜蓝", "紫电"][int(staff.design.element)], int(staff.level)]
	var index: int = meta.chapters.size()
	if index >= data.chapters.size():
		return {}
	var chapter: Dictionary = data.chapters[index]
	if not chapter.clue in meta.clues or (chapter.later and int(meta.loop) <= int(meta.chapter_loops[index - 1])):
		return {}
	var ending := ""
	if index == 3:
		if matches(staff, {"element": 1, "head": 2, "rune": 1, "level": 6}):
			ending = "keeper"
		elif matches(staff, {"element": 0, "head": 0, "rune": 0, "level": 9}):
			ending = "dawn"
		else:
			return {}
	elif not matches(staff, chapter.conditions):
		return {}
	meta.chapters.append(chapter.id)
	meta.chapter_loops.append(int(meta.loop))
	meta.ending = ending
	var content: Dictionary = chapter if ending.is_empty() else data.endings[ending]
	return {"title": content.title, "text": content.text}

func hint(meta: Dictionary) -> String:
	if meta.chapters.size() >= 4:
		return "已完成：" + str(data.endings[meta.ending].title) + "。记忆会随你进入后续轮回。"
	return str(data.chapters[meta.chapters.size()].hint)

func offer_hint(meta: Dictionary, staff: Dictionary) -> String:
	if staff.is_empty():
		return "先装备一根作品，再查看它能否唤醒记忆。"
	var copy := meta.duplicate(true)
	var result := offer(copy, staff)
	if not result.is_empty():
		return "此作品将触发：" + str(result.title)
	return "此作品仅计入供能。\n" + hint(meta)

func tree_name(tree: Array, level: int) -> String:
	var names: Array[String] = []
	for i in range(tree.size()):
		if level >= int(data.tiers[i].level):
			for node in data.tiers[i].nodes:
				if node.id == tree[i]:
					names.append(node.name)
	return " → ".join(names) if not names.is_empty() else "尚未刻下分支"
