extends RefCounted

class_name ResDbHolder

var entries : Array[ResDbEntry]
var sub_holders : Array[ResDbHolder]

var name : String
var name_class : String

var is_root = false

func add_entry(entry_name : String, entry_extension : String, entry_type : String, entry_path : String, uncertain_csharp_type : bool):
    var new_entry = ResDbEntry.new()
    new_entry.name = entry_name
    new_entry.extension = entry_extension
    new_entry.type = entry_type
    new_entry.uncertain_csharp_type = uncertain_csharp_type
    new_entry.path = entry_path

    for entry in entries:
        if (entry.name == new_entry.name):
            entry.name = entry.name + "_" + entry.extension
            new_entry.name = new_entry.name + "_" + new_entry.extension
            break

    entries.append(new_entry)

func add_sub_holder(sub_holder : ResDbHolder):
    sub_holders.append(sub_holder)

func get_final_text() -> String:
    var text = ""
    var prefix = ""

    if (is_root):
        text += "class_name %s\n\n" % [name_class]
    else:
        text +="class %s:\n"  % [name_class]
        prefix = "\t"

    text += prefix + "extends Node\n\n"

    for holder in sub_holders:
        text += prefix + "var %s : %s = %s.new()\n" % [holder.name, holder.name_class, holder.name_class]

    for entry in entries:
        text += prefix + "var %s : %s = preload(\"%s\")\n" % [entry.name, entry.type, entry.path]

    if (is_root):
        text += add_sub_holders_text()

    return text

func add_sub_holders_text() -> String:
    var text = "\n"

    for sub_holder in sub_holders:
        text += sub_holder.get_final_text()
        text += sub_holder.add_sub_holders_text()

    return text