@tool
extends EditorPlugin

class_name ResDbPlugin

const GEN_FOLDER_PATH = "res://addons/resources_static_database/gen"

const ROOT_FOLDER_SETTING_PATH = "addons/resources_static_database/root_folder"
const DATABASE_NAME_SETTING_PATH = "addons/resources_static_database/database_name"

var dock

var old_db_name = ""

var holders : Array

func _enter_tree():
	ProjectSettings.set_setting(ROOT_FOLDER_SETTING_PATH, "res://test/resources")
	ProjectSettings.set_as_internal(ROOT_FOLDER_SETTING_PATH, true)

	ProjectSettings.set_setting(DATABASE_NAME_SETTING_PATH, "Data")
	ProjectSettings.set_as_internal(DATABASE_NAME_SETTING_PATH, true)

	dock = preload("res://addons/resources_static_database/scenes/resdb_dock.tscn").instantiate() as ResDbDock
	dock.generate_button.pressed.connect(build_database)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)

	# ProjectSettings.settings_changed.connect(on_project_settings_changed)

func _exit_tree():
	remove_control_from_docks(dock)
	dock.free()

	ProjectSettings.set_setting(ROOT_FOLDER_SETTING_PATH, null)
	ProjectSettings.set_setting(DATABASE_NAME_SETTING_PATH, null)

func build_database():
	var folder = ProjectSettings.get_setting(ROOT_FOLDER_SETTING_PATH)
	var db_name = ProjectSettings.get_setting(DATABASE_NAME_SETTING_PATH)

	if (old_db_name != ""):
		remove_autoload_singleton(old_db_name)

	clear_database()

	get_editor_interface().get_resource_filesystem().scan()
	while (get_editor_interface().get_resource_filesystem().is_scanning()):
		continue

	if (db_name == ""):
		return;

	if (!scan_dir(db_name, folder)):
		return

	for holder in holders:
		var gen_file_path = GEN_FOLDER_PATH + "/" + holder.name_class.to_lower() + ".gd"
		var file = FileAccess.open(gen_file_path, FileAccess.WRITE)
		var text = holder.get_final_text()
		file.store_string(text)

	get_editor_interface().get_resource_filesystem().scan()
	while (get_editor_interface().get_resource_filesystem().is_scanning()):
		continue

	var autoload_path = GEN_FOLDER_PATH + "/" + db_name.to_lower() + "tree.gd"
	print("Add autoload %s at path %s" % [db_name, autoload_path])
	add_autoload_singleton(db_name, autoload_path)

	old_db_name = db_name


func clear_database():
	holders = []
	var dir = DirAccess.open(GEN_FOLDER_PATH)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			dir.remove(file)


func scan_dir(dir_name : String, dir_path : String, parent_dir_name = "") -> bool:
	if (dir_path.contains(".godot")):
		return false

	print("Scanning folder %s" % [dir_path])
	var dir = DirAccess.open(dir_path)
	var error = DirAccess.get_open_error()
	if (error != OK):
		printerr("Could not scan folder %s. Error: %s" % [dir_path, error])
		return false

	create_holder(dir_name, parent_dir_name)

	dir.list_dir_begin()
	var next = dir.get_next()
	while next != "":
		var next_path = dir_path + "/" + next

		if (dir.dir_exists(next)):
			scan_dir(next, next_path, dir_name)
		elif (ResourceLoader.exists(next_path)):
			var res = ResourceLoader.load(next_path)
			var split = next.split(".")
			var name = split[0]
			var extension = split[1]
			var type = res.get_class()

			if (!check_type(type)):
				next = dir.get_next()
				continue

			create_entry(name, extension, type, next_path, dir_name)

		next = dir.get_next()

	return true


func check_type(class_str : String) -> bool :
	match class_str:
		"TextFile":
			return false
		_:
			return true 


func create_holder(name : String, in_holder = ""):
	var name_class = ""
	var parent_holder = get_holder(in_holder)
	var is_root = parent_holder == null
	if (!is_root):
		name_class = parent_holder.name_class + "_" + name
	else:
		name_class = name + "Tree"

	var holder = ResDbHolder.new()

	holder.name = name
	holder.name_class = name_class
	holder.is_root = is_root

	if (!is_root):
		parent_holder.add_sub_holder(holder)

	holders.append(holder)


func create_entry(entry_name : String, entry_extension : String, entry_type : String, entry_path : String, in_holder : String):
	var holder = get_holder(in_holder)
	if (holder == null):
		return
	
	holder.add_entry(entry_name, entry_extension, entry_type, entry_path)


func get_holder(name : String) -> ResDbHolder:
	if (name == ""):
		return null;

	for holder in holders:
		if (holder.name == name):
			return holder
	return null