class_name SaveStore
extends RefCounted

var folder: String
var notice := ""
var rules: ForgeRules

func _init(rules_value: ForgeRules, folder_value: String = "user://") -> void:
	rules = rules_value
	folder = folder_value

func path(name: String) -> String:
	return folder.path_join(name)

func write_json(file_path: String, contents: Dictionary) -> bool:
	var temporary := file_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		notice = "无法写入存档。请检查文件夹写入权限。"
		return false
	file.store_string(JSON.stringify(contents, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		notice = "存档写入失败，原存档已保留。"
		return false
	var result := DirAccess.rename_absolute(temporary, file_path)
	if result != OK:
		notice = "无法替换存档，原存档已保留。"
		return false
	return true

func save_run(run: Dictionary) -> bool:
	if not rules.validate_run(run):
		notice = "当前状态未通过存档检查，原存档已保留。"
		return false
	var destination := path("run.json")
	if FileAccess.file_exists(destination):
		var previous: Variant = read_json(destination)
		if rules.validate_run(previous):
			DirAccess.copy_absolute(destination, path("run.backup.json"))
	return write_json(destination, run)

func read_json(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return null
	return parser.data

func load_run() -> Dictionary:
	var primary: Variant = read_json(path("run.json"))
	if rules.validate_run(primary):
		return rules.migrate_run(primary)
	var backup: Variant = read_json(path("run.backup.json"))
	if rules.validate_run(backup):
		notice = "主存档损坏，已恢复上一次有效备份。"
		_preserve_corrupt()
		return rules.migrate_run(backup)
	if FileAccess.file_exists(path("run.json")):
		notice = "存档无法读取。损坏文件已保留，开始新契约。"
		_preserve_corrupt()
	return {}

func _preserve_corrupt() -> void:
	if FileAccess.file_exists(path("run.json")):
		DirAccess.copy_absolute(path("run.json"), path("run.corrupt.%d.json" % Time.get_unix_time_from_system()))

func default_settings() -> Dictionary:
	return {"volume": 0.55, "sensitivity": 0.0024, "fullscreen": false, "shake": true}

func load_settings() -> Dictionary:
	var settings := default_settings()
	var saved: Variant = read_json(path("settings.json"))
	if saved is Dictionary:
		for key in ["volume", "sensitivity"]:
			if saved.get(key) is float or saved.get(key) is int:
				if is_finite(float(saved[key])):
					settings[key] = clampf(float(saved[key]), 0.0 if key == "volume" else 0.0005, 1.0 if key == "volume" else 0.006)
		for key in ["fullscreen", "shake"]:
			if saved.get(key) is bool:
				settings[key] = saved[key]
	return settings

func save_settings(settings: Dictionary) -> bool:
	return write_json(path("settings.json"), settings)
