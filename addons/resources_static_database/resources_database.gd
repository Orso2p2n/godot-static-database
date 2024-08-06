@tool
extends EditorPlugin

class_name ResDbPlugin

const GEN_FOLDER_PATH = "res://addons/resources_static_database/gen"

const ROOT_FOLDER_SETTING_PATH = "addons/resources_static_database/root_folder"
const DATABASE_NAME_SETTING_PATH = "addons/resources_static_database/database_name"

var dock

var old_db_name = ""

var root_holder : ResDbHolder

func _enter_tree():
	# Set project settings for database
	ProjectSettings.set_setting(ROOT_FOLDER_SETTING_PATH, "res://test/resources")
	ProjectSettings.set_as_internal(ROOT_FOLDER_SETTING_PATH, true)

	ProjectSettings.set_setting(DATABASE_NAME_SETTING_PATH, "Data")
	ProjectSettings.set_as_internal(DATABASE_NAME_SETTING_PATH, true)

	# Instantiate dock
	dock = preload("res://addons/resources_static_database/scenes/resdb_dock.tscn").instantiate() as ResDbDock
	dock.generate_button.pressed.connect(build_database)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)

func _exit_tree():
	# Remove everything when plugin is disabled
	remove_old_autoload()
	remove_control_from_docks(dock)
	dock.free()

	ProjectSettings.set_setting(ROOT_FOLDER_SETTING_PATH, null)
	ProjectSettings.set_setting(DATABASE_NAME_SETTING_PATH, null)

func remove_old_autoload(print = false):
	if (old_db_name != ""):
		remove_autoload_singleton(old_db_name)

func build_database():
	print_rich("---\n[b]Generating Static Database...\n")

	var folder = ProjectSettings.get_setting(ROOT_FOLDER_SETTING_PATH)
	var db_name = ProjectSettings.get_setting(DATABASE_NAME_SETTING_PATH)

	if (old_db_name != ""):
		print_rich("Removing old Autoload [code]%s[/code]." % [old_db_name])

	# Await a frame to remove the old autoload after the print
	await get_tree().process_frame

	remove_old_autoload()

	print_rich("Clearing old generated database.")
	clear_database()

	# Force godot scan of files
	force_scan()

	if (db_name == ""):
		printerr("Database Name is empty.")
		return;

	# Scan the root folder
	if (!scan_dir(db_name, folder)):
		return
	
	# Write the main file
	var file_name = root_holder.name_class.to_lower() + ".gd"
	print_rich("[color=light_green]Creating file [code]%s[/code] of class [code]%s[/code]." % [file_name, root_holder.name_class])
	var gen_file_path = GEN_FOLDER_PATH + "/" + file_name
	var file = FileAccess.open(gen_file_path, FileAccess.WRITE)
	var text = root_holder.get_final_text()
	file.store_string(text)

	# Force godot scan of files
	force_scan()

	# Add autoload
	var autoload_path = GEN_FOLDER_PATH + "/" + file_name
	print_rich("Adding Autoload [code]%s[/code] with path [code]%s[/code]." % [db_name, autoload_path])

	await get_tree().process_frame

	add_autoload_singleton(db_name, autoload_path)

	# Done!
	print_rich("\n[color=light_green][b]Static Database generated![/b][/color]\n---")

	old_db_name = db_name


func force_scan():
	get_editor_interface().get_resource_filesystem().scan()
	while (get_editor_interface().get_resource_filesystem().is_scanning()):
		continue

func clear_database():
	root_holder = null

	# Delete old generated files
	var dir = DirAccess.open(GEN_FOLDER_PATH)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			dir.remove(file)


func scan_dir(dir_name : String, dir_path : String, parent_dir_name = "", depth = 0) -> bool:
	# Prevent this from scanning stuff inside .godot
	if (dir_path.contains(".godot")):
		return false

	# Prevent user from selecting a folder outside of res://
	if (!dir_path.begins_with("res://")):
		printerr("Root folder must be inside of res://")
		return false
	
	# Stuff for prints
	var indent_text = ""
	for i in depth:
		indent_text += "[indent]"

	# Open folder
	print_rich("%s[color=sky_blue]- Scanning folder [code]%s[/code]..." % [indent_text, dir_path])
	var dir = DirAccess.open(dir_path)
	var error = DirAccess.get_open_error()
	if (error != OK):
		printerr("%s- Could not scan folder %s. Error: %s." % [indent_text, dir_path, error])
		return false

	# Create a holder for the current folder
	create_holder(dir_name, parent_dir_name)

	# Scan all the files in folder
	dir.list_dir_begin()
	var next = dir.get_next()
	while next != "":
		var next_path = dir_path + "/" + next

		# If it's a directory, recursive call
		if (dir.dir_exists(next)):
			scan_dir(next, next_path, dir_name, depth + 1)
		# Else, check if it's a resource
		elif (ResourceLoader.exists(next_path)):
			# Get all needed info
			var res = ResourceLoader.load(next_path)
			var split = next.split(".")
			var name = split[0].to_snake_case()
			var extension = split[1]

			var type = res.get_class()
			var script = res.get_script()
			var uncertain_csharp_type = false
			if (script != null):
				var global_name = script.get_global_name()
				if (global_name != ""):
					type = global_name

			# Some types are illegal
			if (!check_if_type_is_legal(type)):
				next = dir.get_next()
				continue

			print_rich("[indent]%s[color=light_cyan]- Found resource [code]%s.%s[/code], of type [code]%s[/code], script %s." % [indent_text, name, extension, type, script])
			
			# Create entry for the resource
			create_entry(name, extension, type, next_path, dir_name, uncertain_csharp_type)

		next = dir.get_next()

	return true


func check_if_type_is_legal(class_str : String) -> bool :
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
		name_class = parent_holder.name_class + "_" + name.to_pascal_case()
	else:
		name_class = name + "Tree"

	var holder = ResDbHolder.new()

	holder.name = name
	holder.name_class = name_class
	holder.is_root = is_root

	if (!is_root):
		parent_holder.add_sub_holder(holder)
	else:
		root_holder = holder


func create_entry(entry_name : String, entry_extension : String, entry_type : String, entry_path : String, in_holder : String, uncertain_csharp_type : bool):
	var holder = get_holder(in_holder)
	if (holder == null):
		return
	
	holder.add_entry(entry_name, entry_extension, entry_type, entry_path, uncertain_csharp_type)


func get_holder(name : String) -> ResDbHolder:
	if (name == ""):
		return null

	if (root_holder == null):
		return null

	if (root_holder.name == name):
		return root_holder

	for holder in root_holder.sub_holders:
		if (holder.name == name):
			return holder
	
	return null