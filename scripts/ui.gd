class_name ForgeUI
extends CanvasLayer

signal requested(action: String, payload: Variant)
signal design_changed(design: Dictionary)

const INK := Color("#101a21")
const GOLD := Color("#e0ba79")
const MINT := Color("#8ee4df")
const TEXT := Color("#f3eee4")
const MUTED := Color("#b3b9c4")
const RED := Color("#f18c79")

var game: Node
var root: Control
var hud: Control
var overlay: Control
var left_panel: VBoxContainer
var right_panel: VBoxContainer
var title_label: Label
var contract_label: Label
var staff_label: Label
var objective_label: Label
var prompt_label: Label
var toast_label: Label
var resonance_label: Label
var probability_label: Label
var stats_label: Label
var infusion_button: Button
var cast_button: Button
var toast_time := 0.0
var mode := "menu"
var design: Dictionary
var font: Font
var rebuilding := false
var evolution_label: Label
var stage_label: Label
var log_lines: Array[String] = []

func configure(game_value: Node, font_value: Font) -> void:
	game = game_value
	font = font_value
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme_value := Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 18
	theme_value.set_color("font_color", "Label", TEXT)
	theme_value.set_color("font_color", "Button", TEXT)
	theme_value.set_color("font_hover_color", "Button", MINT)
	theme_value.set_color("font_disabled_color", "Button", Color("#627078"))
	theme_value.set_stylebox("normal", "Button", box(Color("#1b2b33"), Color("#425559"), 6, 14))
	theme_value.set_stylebox("hover", "Button", box(Color("#253d43"), MINT, 6, 14))
	theme_value.set_stylebox("pressed", "Button", box(Color("#31534e"), GOLD, 6, 14))
	theme_value.set_stylebox("disabled", "Button", box(Color("#182126"), Color("#2e3d42"), 6, 14))
	theme_value.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 6, 14))
	theme_value.set_stylebox("normal", "OptionButton", box(Color("#213139"), Color("#425559"), 5, 12))
	theme_value.set_color("font_color", "OptionButton", TEXT)
	theme_value.set_stylebox("panel", "PopupMenu", box(INK, GOLD, 6, 10))
	theme_value.set_stylebox("background", "ProgressBar", box(Color("#25343b"), Color("#32484c"), 2, 0))
	theme_value.set_stylebox("fill", "ProgressBar", box(MINT, MINT, 2, 0))
	root.theme = theme_value
	build_hud()

func box(color: Color, border: Color, radius: int = 8, padding: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func label(text_value: String, size: int = 18, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

func small_heading(parent: Node, text_value: String) -> Label:
	var result := label(text_value, 14, GOLD)
	parent.add_child(result)
	return result

func button(parent: Node, text_value: String, action: String, payload: Variant = null, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text_value
	result.clip_text = true
	result.custom_minimum_size.y = 46
	if primary:
		result.add_theme_stylebox_override("normal", box(Color("#31564f"), MINT, 6, 14))
	result.pressed.connect(func(): requested.emit(action, payload))
	parent.add_child(result)
	return result

func spacer(parent: Node, height: float = 10) -> void:
	var node := Control.new()
	node.custom_minimum_size.y = height
	parent.add_child(node)

func panel(parent: Control, position_value: Vector2, size_value: Vector2) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.position = position_value
	shell.size = size_value
	shell.add_theme_stylebox_override("panel", box(Color("#111d25"), Color("#43504d"), 10, 22))
	parent.add_child(shell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	shell.add_child(column)
	return column

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	title_label = label("封 印 工 坊", 26, GOLD)
	title_label.position = Vector2(42, 25)
	title_label.size = Vector2(300, 45)
	hud.add_child(title_label)
	var subtitle := label("STAFF FORGE  /  FIVE NIGHTS", 12, MUTED)
	subtitle.position = Vector2(44, 70)
	subtitle.size = Vector2(300, 25)
	hud.add_child(subtitle)
	contract_label = label("", 18, TEXT)
	contract_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	contract_label.offset_left = -490
	contract_label.offset_top = 30
	contract_label.offset_right = -40
	contract_label.offset_bottom = 110
	contract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(contract_label)
	staff_label = label("", 17, GOLD)
	staff_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	staff_label.offset_left = -480
	staff_label.offset_top = -114
	staff_label.offset_right = -40
	staff_label.offset_bottom = -38
	staff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(staff_label)
	objective_label = label("", 16, MUTED)
	objective_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	objective_label.offset_left = 44
	objective_label.offset_top = -98
	objective_label.offset_right = 684
	objective_label.offset_bottom = -26
	hud.add_child(objective_label)
	prompt_label = label("", 20, TEXT)
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_label.offset_left = -250
	prompt_label.offset_top = 35
	prompt_label.offset_right = 250
	prompt_label.offset_bottom = 125
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt_label)
	var crosshair := label("·", 34, MINT)
	crosshair.name = "Crosshair"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -10
	crosshair.offset_top = -25
	crosshair.offset_right = 10
	crosshair.offset_bottom = 25
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(crosshair)
	toast_label = label("", 19, MINT)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -460
	toast_label.offset_top = -158
	toast_label.offset_right = 460
	toast_label.offset_bottom = -104
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(toast_label)

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		root.remove_child(overlay)
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	left_panel = null
	right_panel = null
	probability_label = null
	resonance_label = null
	stats_label = null
	infusion_button = null
	cast_button = null
	evolution_label = null
	stage_label = null

func show_menu(has_save: bool, confirmation: bool = false) -> void:
	mode = "menu"
	hud.visible = false
	clear_overlay()
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.05, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var column := panel(overlay, Vector2(92, 128), Vector2(495, 640))
	small_heading(column, "一份五夜契约   /   A FIVE-NIGHT PACT")
	column.add_child(label("铸杖模拟器", 48, TEXT))
	column.add_child(label("封 印 工 坊", 28, GOLD))
	spacer(column, 10)
	column.add_child(label("让木与晶核共鸣。\n再灌注一次，还是就此收手？", 23, MUTED))
	spacer(column, 18)
	if confirmation:
		column.add_child(label("新契约将替换本局进度。\n已发现的线索与剧情记忆会保留。", 18, RED))
		button(column, "确认开启新契约", "new_run", null, true)
		button(column, "返回", "menu")
	else:
		if has_save:
			button(column, "继续契约  ·  第 %d 夜" % game.run.day, "continue", null, true)
		button(column, "开启新契约", "new_confirm" if has_save else "new_run", null, not has_save)
		button(column, "设置", "settings")
		button(column, "离开工坊", "quit")
	spacer(column, 10)
	column.add_child(label("单人体验  /  中文界面  /  自动存档\nWASD 移动 · E 调查 · J 手记 · T 进化树", 15, MUTED))
	if not game.store.notice.is_empty():
		column.add_child(label(game.store.notice, 15, RED))
	var version_label := label("DEMO 0.3  ·  轮回调查 / 法杖进化树", 13, GOLD)
	version_label.position = Vector2(94, 838)
	version_label.size = Vector2(650, 28)
	overlay.add_child(version_label)

func show_walk() -> void:
	mode = "walk"
	hud.visible = true
	clear_overlay()
	update_live()

func inventory(parent: VBoxContainer) -> void:
	small_heading(parent, "当前作品   /   INVENTORY")
	var available: Array = game.rules.usable(game.run)
	parent.add_child(label("%d 根可用法杖 · %d 份材料" % [available.size(), game.run.materials], 17, MUTED))
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size.y = 260
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroller)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroller.add_child(list)
	for staff in available:
		var prefix := "◆ " if staff.id == game.run.active_id else "   "
		var text_value := "%s#%02d  %s  +%d\n%s  ·  %d 灵值" % [prefix, staff.id, game.rules.balance.materials[int(staff.design.material)].name, staff.level, game.rules.balance.elements[int(staff.design.element)].name, game.rules.value(game.run, staff)]
		var item := button(list, text_value, "select", int(staff.id))
		item.custom_minimum_size.y = 66
		item.add_theme_font_size_override("font_size", 16)
	if available.is_empty():
		list.add_child(label("还没有作品。\n在组装台将灵木与晶核结合。", 17, MUTED))
	spacer(parent, 5)
	small_heading(parent, "遗物   /   RELICS  %d / 3" % game.run.relics.size())
	for relic_id in game.run.relics:
		for relic in game.rules.balance.relics:
			if relic.id == relic_id:
				parent.add_child(label("◇ " + relic.name + "\n" + relic.description, 16, GOLD))
	if game.run.relics.is_empty():
		parent.add_child(label("到遗物柜，用一根法杖交换。", 16, MUTED))

func show_station(station: String) -> void:
	mode = station
	hud.visible = true
	prompt_label.text = ""
	clear_overlay()
	var names := {"assembly": "01 / 组装台", "infusion": "02 / 灌注台",
		"lab": "03 / 试法长廊", "relic": "04 / 遗物柜", "seal": "05 / 封印祭台",
		"supply": "材料架", "inventory": "作品库存"}
	var header := label(names.get(station, station), 24, GOLD)
	header.position = Vector2(44, 112)
	header.size = Vector2(650, 40)
	overlay.add_child(header)
	var close_button := button(overlay, "返回工坊  [Esc]", "close")
	close_button.position = Vector2(1360, 112)
	close_button.size = Vector2(196, 46)
	if station == "lab":
		build_lab()
		return
	left_panel = panel(overlay, Vector2(44, 164), Vector2(400, 588))
	right_panel = panel(overlay, Vector2(1235, 174), Vector2(320, 570))
	inventory(right_panel)
	match station:
		"assembly": build_assembly()
		"infusion": build_infusion()
		"relic": build_relics()
		"seal": build_seal()
		"supply": build_supply()
		"inventory":
			small_heading(left_panel, "装备与蓝图")
			stats_label = label("", 20, TEXT)
			left_panel.add_child(stats_label)
			left_panel.add_child(label("选择右侧作品即可装备。\n组装台可重新使用保存的蓝图。", 18, MUTED))
	update_live()

func selector(parent: VBoxContainer, caption: String, entries: Array, key: String) -> void:
	small_heading(parent, caption)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 40
	for entry in entries:
		option.add_item(entry.name)
	option.select(int(design[key]))
	parent.add_child(option)
	var description := label(entries[int(design[key])].description, 14, MUTED)
	parent.add_child(description)
	option.item_selected.connect(func(index):
		design[key] = index
		description.text = entries[index].description
		design_changed.emit(design.duplicate(true))
		update_design_stats())

func slider(parent: VBoxContainer, caption: String, key: String, minimum: float, maximum: float, step: float, scale_value: float) -> void:
	var text := label("", 15, GOLD)
	parent.add_child(text)
	var control := HSlider.new()
	control.min_value = minimum
	control.max_value = maximum
	control.step = step
	control.value = float(design[key])
	control.custom_minimum_size.y = 24
	parent.add_child(control)
	var update := func(value: float):
		text.text = "%s  %.0f cm" % [caption, value * scale_value]
	update.call(control.value)
	control.value_changed.connect(func(value):
		design[key] = value
		update.call(value)
		design_changed.emit(design.duplicate(true))
		update_design_stats())

func build_assembly() -> void:
	design = game.design.duplicate(true)
	var scroller := ScrollContainer.new()
	scroller.custom_minimum_size.y = 390
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroller)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	scroller.add_child(controls)
	selector(controls, "灵木 / 杖身", game.rules.balance.materials, "material")
	selector(controls, "构型 / 杖头", game.rules.balance.heads, "head")
	selector(controls, "元素 / 晶核", game.rules.balance.elements, "element")
	selector(controls, "刻印 / 符文", game.rules.balance.runes, "rune")
	slider(controls, "长度", "length", 0.8, 1.6, 0.01, 100.0)
	slider(controls, "粗细", "thickness", 0.02, 0.05, 0.001, 100.0)
	var color_button := ColorPickerButton.new()
	color_button.text = "选择木色"
	color_button.color = Color(design.color)
	color_button.custom_minimum_size.y = 34
	controls.add_child(color_button)
	color_button.color_changed.connect(func(color):
		design.color = "#" + color.to_html(false)
		design_changed.emit(design.duplicate(true))
		update_design_stats())
	stats_label = label("", 16, MINT)
	left_panel.add_child(stats_label)
	var craft_button := button(left_panel, "组装法杖  ·  消耗1份材料", "craft", null, true)
	craft_button.disabled = game.run.materials <= 0
	var hint := label("中央模型实时预览 · 鼠标拖动可旋转", 15, MUTED)
	hint.position = Vector2(566, 727)
	hint.size = Vector2(575, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(hint)
	update_design_stats()

func update_design_stats() -> void:
	if not is_instance_valid(stats_label):
		return
	var spell: Dictionary = game.rules.stats(design)
	stats_label.text = "基础威力 %.1f  /  间隔 %.2fs\n稳定度 %.2f  /  半径 %.1fm" % [spell.damage, spell.cooldown, spell.stability, spell.radius]

func build_infusion() -> void:
	small_heading(left_panel, "THE TRANSMUTATION / 冒险与蜕变")
	left_panel.add_child(label("让法杖进化", 28, TEXT))
	left_panel.add_child(label("概率升级：成功 +1，大成功 +2。\n每级增添刻印，+3/+6/+9 选择分支。", 16, MUTED))
	stats_label = label("", 20, GOLD)
	left_panel.add_child(stats_label)
	stage_label = label("", 14, MINT)
	left_panel.add_child(stage_label)
	spacer(left_panel)
	probability_label = label("", 18, TEXT)
	left_panel.add_child(probability_label)
	resonance_label = label("", 20, MINT)
	left_panel.add_child(resonance_label)
	spacer(left_panel)
	infusion_button = button(left_panel, "灌注  [空格]", "infuse", null, true)
	infusion_button.custom_minimum_size.y = 64
	button(left_panel, "查看进化树  [T]", "tree")
	evolution_label = label("", 24, GOLD)
	evolution_label.position = Vector2(483, 677)
	evolution_label.size = Vector2(706, 72)
	evolution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evolution_label.add_theme_constant_override("outline_size", 5)
	evolution_label.add_theme_color_override("font_outline_color", Color("#0d121b"))
	overlay.add_child(evolution_label)

func build_relics() -> void:
	left_panel.add_child(label("舍弃作品，改写运气。", 22, TEXT))
	left_panel.add_child(label("整根法杖交换，无找零。\n每件只能持有一次，最多3件。", 16, MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 405
	left_panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 9)
	scroll.add_child(column)
	for relic in game.rules.balance.relics:
		var held: bool = relic.id in game.run.relics
		var relic_button := button(column, "%s  %s  /  %d\n%s" % ["◆" if held else "◇", relic.name, relic.price, relic.description], "buy", relic.id)
		relic_button.add_theme_font_size_override("font_size", 16)
		relic_button.custom_minimum_size.y = 72
		relic_button.disabled = held or game.run.relics.size() >= 3

func build_seal() -> void:
	left_panel.add_child(label("封印需要你的作品。", 25, TEXT))
	probability_label = label("", 20, MINT)
	left_panel.add_child(probability_label)
	stats_label = label("", 18, GOLD)
	left_panel.add_child(stats_label)
	spacer(left_panel, 15)
	button(left_panel, "交付当前法杖", "offer", null, true)
	left_panel.add_child(label("交付立即消耗法杖并记入今日供能。\n尚未交付的作品保留到次日。", 17, MUTED))
	spacer(left_panel, 18)
	button(left_panel, "敲响封印钟  ·  结束今日", "settle_confirm")
	left_panel.add_child(label("供能不足会增加一道裂隙。累计3次则失败。", 15, RED))
	left_panel.add_child(label(game.rules.chronicle.offer_hint(game.run.campaign, game.rules.active(game.run)), 16, MINT))
	button(left_panel, "调查手记  [J]", "journal")

func build_supply() -> void:
	left_panel.add_child(label("灵木与晶核", 28, TEXT))
	left_panel.add_child(label("每天获得3份完整制作材料。\n任何构型消耗1份；剩余材料保留。\n试法不消耗材料。", 19, MUTED))
	spacer(left_panel, 25)
	stats_label = label("", 23, GOLD)
	left_panel.add_child(stats_label)
	var claim_button := button(left_panel, "领取今日材料", "claim", null, true)
	claim_button.disabled = game.run.unclaimed <= 0

func build_lab() -> void:
	var column := panel(overlay, Vector2(1090, 583), Vector2(465, 170))
	small_heading(column, "施法结果 / TRAINING LOG")
	stats_label = label(game.spells.last_report, 17, TEXT)
	column.add_child(stats_label)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	cast_button = button(actions, "施法 [空格]", "cast", null, true)
	cast_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset_button := button(actions, "重置靶标 [R]", "reset_targets")
	reset_button.custom_minimum_size.x = 160
	var hint := label("点击训练靶瞄准 · 左键 / 空格施法 · 不消耗材料", 18, GOLD)
	hint.position = Vector2(390, 770)
	hint.size = Vector2(800, 36)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(hint)

func show_pause() -> void:
	mode = "pause"
	hud.visible = true
	clear_overlay()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.04, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var column := panel(overlay, Vector2(585, 240), Vector2(430, 420))
	small_heading(column, "PAUSED / 共鸣计时已冻结")
	column.add_child(label("片刻宁静", 32, GOLD))
	button(column, "返回工坊", "resume", null, true)
	button(column, "设置", "settings")
	button(column, "调查手记  [J]", "journal")
	button(column, "操作与契约", "help")
	button(column, "保存并返回主菜单", "save_menu")
	button(column, "保存并退出", "quit")

func show_settings() -> void:
	mode = "settings"
	clear_overlay()
	var column := panel(overlay, Vector2(550, 170), Vector2(500, 530))
	column.add_child(label("工坊设置", 32, GOLD))
	var settings: Dictionary = game.settings.duplicate(true)
	for definition in [{"key": "volume", "name": "总音量", "min": 0.0, "max": 1.0, "step": 0.01},
			{"key": "sensitivity", "name": "鼠标灵敏度", "min": 0.0005, "max": 0.006, "step": 0.0001}]:
		small_heading(column, definition.name)
		var control := HSlider.new()
		control.min_value = definition.min
		control.max_value = definition.max
		control.step = definition.step
		control.value = settings[definition.key]
		control.custom_minimum_size.y = 40
		column.add_child(control)
		control.value_changed.connect(func(value): requested.emit("setting", {"key": definition.key, "value": value}))
	for definition in [{"key": "fullscreen", "name": "全屏模式"}, {"key": "shake", "name": "轻微镜头震动"}]:
		var control := CheckButton.new()
		control.text = definition.name
		control.button_pressed = settings[definition.key]
		control.custom_minimum_size.y = 50
		column.add_child(control)
		control.toggled.connect(func(value): requested.emit("setting", {"key": definition.key, "value": value}))
	spacer(column, 15)
	button(column, "完成", "settings_done", null, true)
	column.add_child(label("设置即时生效并保存。\n工位暂停时，共鸣不会流失。", 16, MUTED))

func show_help() -> void:
	mode = "help"
	clear_overlay()
	var column := panel(overlay, Vector2(440, 100), Vector2(720, 675))
	column.add_child(label("五夜契约", 34, GOLD))
	column.add_child(label("01  材料架：每天领取3份材料。\n02  组装台：决定元素、释放方式与稳定度。\n03  灌注台：强化提高价值，6次充能后的下一次\n      灌注开启3秒共鸣；共鸣免于破碎。\n04  试法长廊：免费试法，观察灼烧、减速和连锁。\n05  遗物柜：消耗作品换取构筑，最多3件。\n06  封印祭台：交付作品，再敲钟结束今日。\n\n供能不足增加裂隙；第三次不足契约失败。\n坚持到第五夜结束即完成契约。\n\nWASD 移动 · 鼠标观察 · E 交互 · Tab 库存\nEsc 返回/暂停 · 空格 灌注/试法 · R 重置训练靶\n\n本局自动保存。开启新契约替换物品进度，保留轮回记忆。", 20, TEXT))
	button(column, "明白了", "help_done", null, true)

func show_settle_confirmation() -> void:
	mode = "confirm"
	clear_overlay()
	var column := panel(overlay, Vector2(535, 265), Vector2(530, 320))
	var quota: int = game.rules.balance.quotas[int(game.run.day) - 1]
	var enough: bool = game.run.offer >= quota
	column.add_child(label("结束第 %d 夜？" % game.run.day, 30, GOLD))
	column.add_child(label("供能 %d / %d\n%s" % [game.run.offer, quota, "供能充足，封印可以安然入夜。" if enough else "供能不足，将增加一道裂隙。"], 22, MINT if enough else RED))
	button(column, "敲响封印钟", "settle", null, enough)
	button(column, "继续制作", "back_to_seal")

func show_ending() -> void:
	mode = "ending"
	hud.visible = false
	clear_overlay()
	var column := panel(overlay, Vector2(500, 180), Vector2(600, 520))
	var won: bool = game.run.status == "won"
	small_heading(column, "CONTRACT COMPLETE" if won else "THE SEAL IS BROKEN")
	column.add_child(label("五夜封印已守住" if won else "封印破裂", 38, MINT if won else RED))
	column.add_child(label("你的作品撑过了黑暗。\n工坊重新属于你。" if won else "下一份契约，记得适时收手。\n稳定度与遗物能改变命运。", 23, TEXT))
	var total_offer := 0
	for day in game.run.history:
		total_offer += int(day.offer)
	column.add_child(label("累计供能 %d  ·  裂隙 %d / 3\n本局用时 %.1f 分钟" % [total_offer, game.run.misses, float(game.run.play_seconds) / 60.0], 19, GOLD))
	for day in game.run.history:
		column.add_child(label("第%d夜    %d / %d    %s" % [day.day, day.offer, day.quota, "完成" if day.paid else "不足"], 16, MUTED))
	column.add_child(label("轮回记忆保留。按手记指引，在下一轮继续调查。", 17, MINT))
	button(column, "查看调查手记", "journal")
	button(column, "再开一份契约", "new_confirm", null, true)
	button(column, "返回主菜单", "menu")

func toast(message: String, successful: bool = true) -> void:
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", MINT if successful else RED)
	toast_time = 4.5
	log_lines.append(message)
	if log_lines.size() > 12:
		log_lines.pop_front()

func update_live() -> void:
	if not game or game.run.is_empty():
		return
	var run: Dictionary = game.run
	var rules: ForgeRules = game.rules
	var quota: int = rules.balance.quotas[int(run.day) - 1]
	contract_label.text = "轮回 %d · 第 %d / 5 夜    ·    裂隙 %d / 3\n今日供能  %d / %d" % [run.campaign.loop, run.day, run.misses, run.offer, quota]
	var staff := rules.active(run)
	staff_label.text = "未装备法杖\nTab 作品库存" if staff.is_empty() else "#%02d  %s  +%d\n%d 灵值    ·    Tab 库存" % [staff.id, rules.balance.elements[int(staff.design.element)].name, staff.level, rules.value(run, staff)]
	var objectives := ["先到材料架，领取今天的灵木与晶核。", "到组装台，制作第一根法杖。", "到灌注台，尝试让晶核共鸣。", "到试法长廊，验证你的作品。", "到封印祭台交付，或先换取遗物。", "准备好后，在封印祭台敲钟结束今日。"]
	objective_label.text = objectives[clampi(int(run.tutorial_step), 0, 5)] + "\nWASD 移动 · E 调查 · J 手记 · T 进化树"
	objective_label.visible = mode == "walk"
	hud.get_node("Crosshair").visible = mode == "walk" or mode == "lab"
	if mode == "infusion":
		if not staff.is_empty():
			var probabilities: Dictionary = rules.probabilities(run, staff)
			probability_label.text = "成功       %5.1f%%\n大成功   %5.1f%%\n停滞       %5.1f%%\n降级       %5.1f%%\n破碎       %5.1f%%" % [probabilities.success * 100, probabilities.great * 100, probabilities.hold * 100, probabilities.damage * 100, probabilities["break"] * 100]
			if staff.level >= 12:
				probability_label.text = "强化已经封顶。\n封印神器不再接受灌注。\n\n可以留用、试法或交付。"
			stats_label.text = "+%d · %s\n%d 灵值 / 稳定度 %.2f" % [staff.level, StaffVisual.evolution_name(staff.level), rules.value(run, staff), rules.stats(staff.design, int(staff.level), staff.get("tree", [])).stability]
			stage_label.text = rules.chronicle.tree_name(staff.get("tree", []), int(staff.level))
			resonance_label.text = "共鸣剩余 %.1fs · 不会破碎" % staff.resonance if staff.resonance > 0.0 else ("充能 %d / %d%s" % [staff.charge, rules.threshold(run), " · 下一次开启共鸣" if staff.charge >= rules.threshold(run) else ""])
			if "shield" in run.relics and not staff.protected:
				resonance_label.text += "\n护罩待命 · 首次破碎改降级"
			infusion_button.disabled = staff.cooldown > 0.01 or staff.level >= 12
			infusion_button.text = "最终形态 · 去试法吧" if staff.level >= 12 else ("灌注中… %.1fs" % staff.cooldown if staff.cooldown > 0.01 else "灌注  [空格]")
		else:
			stats_label.text = "没有可用的法杖"
			probability_label.text = "选择库存中的作品，\n或到组装台重新制作。"
			resonance_label.text = ""
			stage_label.text = ""
			infusion_button.disabled = true
		if game.feedback_time > 0.0:
			evolution_label.text = game.infusion_feedback
			evolution_label.add_theme_color_override("font_color", game.infusion_feedback_color)
		else:
			evolution_label.text = "" if staff.is_empty() else StaffVisual.evolution_name(staff.level)
			evolution_label.add_theme_color_override("font_color", GOLD)
	elif mode == "seal":
		probability_label.text = "今日供能 %d / %d\n裂隙 %d / 3" % [run.offer, quota, run.misses]
		stats_label.text = "当前作品可供能 %d 灵值" % rules.value(run, staff)
	elif mode == "supply":
		stats_label.text = "今日待领取 %d 份\n库存材料 %d 份" % [run.unclaimed, run.materials]
	elif mode == "inventory" and not staff.is_empty():
		var spell: Dictionary = rules.stats(staff.design, int(staff.level), staff.get("tree", []))
		stats_label.text = "威力 %.1f\n施法间隔 %.2fs\n稳定度 %.2f\n作用半径 %.1fm\n价值 %d 灵值" % [spell.damage, spell.cooldown, spell.stability, spell.radius, rules.value(run, staff)]
	elif mode == "lab":
		stats_label.text = game.spells.last_report
		cast_button.disabled = game.cast_cooldown > 0.01 or staff.is_empty()
		cast_button.text = "冷却 %.1fs" % game.cast_cooldown if game.cast_cooldown > 0.01 else "施法 [空格]"

func _process(delta: float) -> void:
	toast_label.visible = mode != "infusion" or game.feedback_time <= 0.0
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = minf(1.0, maxf(0.0, toast_time))
	else:
		toast_label.modulate.a = 0.0

func show_story(title: String, text_value: String, return_action: String = "close") -> void:
	mode = "story"
	hud.visible = false
	clear_overlay()
	var column := panel(overlay, Vector2(400, 175), Vector2(800, 550))
	small_heading(column, "ECHOES / 记忆已写入轮回")
	column.add_child(label(title, 32, GOLD))
	spacer(column, 16)
	column.add_child(label(text_value, 23, TEXT))
	spacer(column, 16)
	column.add_child(label("线索与章节可随时在 J 调查手记中重读。", 16, MUTED))
	button(column, "记住它", return_action, null, true)

func show_journal() -> void:
	mode = "journal"
	hud.visible = false
	clear_overlay()
	var meta: Dictionary = game.run.campaign
	var lore = game.rules.chronicle
	var nav := panel(overlay, Vector2(60, 90), Vector2(420, 715))
	small_heading(nav, "THE PALIMPSEST / 被反复擦写的过去")
	nav.add_child(label("轮回调查", 38, GOLD))
	nav.add_child(label("第 %d 次归来\n线索 %d / 6  ·  章节 %d / 4" % [meta.loop, meta.clues.size(), meta.chapters.size()], 22, TEXT))
	nav.add_child(label(lore.hint(meta), 21, MINT))
	nav.add_child(label("每轮完成或失败后可重开；也可在暂停菜单保存返回主菜单，再开新契约。物品清空，记忆保留。", 17, MUTED))
	spacer(nav, 10)
	button(nav, "返回工坊  [Esc]", "close", null, true)
	var body := panel(overlay, Vector2(505, 90), Vector2(1035, 715))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	scroll.add_child(column)
	for entry in lore.data.clues:
		if entry.id in meta.clues:
			column.add_child(label("◇ " + entry.name, 24, GOLD))
			column.add_child(label(entry.text, 19, TEXT))
		else:
			column.add_child(label("？ " + entry.where, 20, MUTED))
			column.add_child(label("可以调查" if lore.available(meta, entry) else "尚未显现；推进记忆或在后续轮回返回。", 16, MINT if lore.available(meta, entry) else MUTED))
	for i in range(meta.chapters.size()):
		var entry: Dictionary = lore.data.chapters[i]
		if i == 3:
			entry = lore.data.endings[meta.ending]
		column.add_child(label("第 %d 轮 · %s" % [meta.chapter_loops[i], entry.title], 25, GOLD))
		column.add_child(label(entry.text, 20, TEXT))

func show_tree() -> void:
	mode = "tree"
	hud.visible = false
	clear_overlay()
	var staff: Dictionary = game.rules.active(game.run)
	var head := panel(overlay, Vector2(50, 65), Vector2(1500, 140))
	head.add_child(label("法杖进化树  /  每层只刻下一条道路", 32, GOLD))
	if staff.is_empty():
		head.add_child(label("先制作或装备法杖。", 20, TEXT))
	else:
		var stats: Dictionary = game.rules.stats(staff.design, int(staff.level), staff.get("tree", []))
		head.add_child(label("#%02d  +%d  ·  威力 %.1f  /  间隔 %.2fs  /  稳定 %.2f  /  范围 %.2fm" % [staff.id, staff.level, stats.damage, stats.cooldown, stats.stability, stats.radius], 21, MINT))
	var tree: Array = staff.get("tree", [])
	for i in range(3):
		var tier: Dictionary = game.rules.chronicle.data.tiers[i]
		var column := panel(overlay, Vector2(50 + i * 510, 235), Vector2(480, 465))
		column.add_theme_constant_override("separation", 5)
		small_heading(column, "+%d  /  %s" % [tier.level, tier.name])
		for entry in tier.nodes:
			var selected: bool = tree.size() > i and tree[i] == entry.id
			var state := "已刻下" if selected else ("未选择" if tree.size() <= i else "另一道路")
			column.add_child(label(("◆ " if selected else "◇ ") + entry.name + " · " + state, 20, MINT if selected else TEXT))
			column.add_child(label(entry.look + "\n" + entry.effect, 15, MUTED))
			var choice := button(column, "刻下此分支" if not selected else ("生效中" if int(staff.level) >= int(tier.level) else "休眠：等级不足"), "branch", entry.id, selected)
			choice.name = "BranchChoice_" + str(entry.id)
			choice.custom_minimum_size.y = 34
			choice.add_theme_font_size_override("font_size", 16)
			for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
				choice.add_theme_stylebox_override(style_name, box(Color("#20333b"), MINT if selected else Color("#425559"), 6, 6))
			choice.disabled = staff.is_empty() or tree.size() != i or int(staff.get("level", 0)) < int(tier.level)
		if i < 2:
			var arrow := label("→", 26, GOLD)
			arrow.position = Vector2(533 + i * 510, 420)
			arrow.size = Vector2(30, 50)
			overlay.add_child(arrow)
	var foot := panel(overlay, Vector2(50, 715), Vector2(1500, 145))
	foot.add_child(label("+12 · 神器冠冕：沿你的道路完成最终加冕。三层共 12 种组合，兼容全部元素与杖头。", 21, GOLD))
	foot.add_child(label("选择永久绑定这根法杖；降级时对应部件与属性休眠，恢复等级后自动重现。破碎不保留分支。", 17, MUTED))
	button(foot, "返回灌注台，查看实物  [Esc]", "back_to_infusion", null, true)
