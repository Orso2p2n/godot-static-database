@tool
extends Control

@export var root_folder_line_edit : LineEdit
@export var root_folder_button : Button
@export var db_name_line_edit : LineEdit
@export var language_option_button : OptionButton
@export var generate_button : Button

var cur_root_folder : String
var cur_db_name : String

var file_dialog : EditorFileDialog

func _enter_tree():
	var root_folder = ProjectSettings.get_setting(ResDbPlugin.ROOT_FOLDER_SETTING_PATH)
	set_root_folder(root_folder)

	var db_name = ProjectSettings.get_setting(ResDbPlugin.DATABASE_NAME_SETTING_PATH)
	set_db_name(db_name)

	root_folder_button.pressed.connect(_on_root_folder_button_pressed)

	root_folder_line_edit.text_changed.connect(_on_root_folder_line_edit_text_changed)
	db_name_line_edit.text_changed.connect(_on_db_name_line_edit_text_changed)

	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.dir_selected.connect(_on_dir_selected)

	var viewport = EditorInterface.get_base_control()
	viewport.add_child(file_dialog)

func _exit_tree():
	file_dialog.queue_free()

func _on_root_folder_button_pressed():
	file_dialog.popup_centered_ratio()

func _on_dir_selected(dir):
	set_root_folder(dir)

func _on_root_folder_line_edit_text_changed(new_text : String):
	set_root_folder(new_text)

func _on_db_name_line_edit_text_changed(new_text : String):
	set_db_name(new_text)

func set_root_folder(path : String):
	if root_folder_line_edit.text != path:
		root_folder_line_edit.text = path

	ProjectSettings.set_setting(ResDbPlugin.ROOT_FOLDER_SETTING_PATH, path)
	cur_root_folder = path

func set_db_name(name : String):
	if db_name_line_edit.text != name:
		db_name_line_edit.text = name

	ProjectSettings.set_setting(ResDbPlugin.DATABASE_NAME_SETTING_PATH, name)
	cur_db_name = name

