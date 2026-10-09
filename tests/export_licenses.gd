extends SceneTree

func _initialize() -> void:
	var file := FileAccess.open("res://docs/GODOT_LICENSES.txt", FileAccess.WRITE)
	file.store_line(Engine.get_license_text())
	file.store_line("\nTHIRD-PARTY COPYRIGHT NOTICES\n")
	for component in Engine.get_copyright_info():
		file.store_line(JSON.stringify(component, "\t"))
	file.store_line("\nTHIRD-PARTY LICENSE TEXTS\n")
	var licenses := Engine.get_license_info()
	for name_value in licenses:
		file.store_line("\n" + name_value + "\n" + str(licenses[name_value]))
	file.close()
	print("Engine license notices exported.")
	quit()
