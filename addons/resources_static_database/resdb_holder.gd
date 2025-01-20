extends RefCounted

class_name ResDbHolder

var entries : Array[ResDbEntry] = []
var sub_holders : Array[ResDbHolder] = []

var name : String
var name_class_gd : String
var name_class_cs : String

var is_root = false

func add_entry(entry_name : String, entry_extension : String, entry_type_gd : String, entry_type_cs : String, entry_path : String):
    var new_entry = ResDbEntry.new()
    new_entry.name = entry_name
    new_entry.extension = entry_extension
    new_entry.type_gd = entry_type_gd
    new_entry.type_cs = entry_type_cs
    new_entry.path = entry_path

    for entry in entries:
        if (entry.name == new_entry.name):
            entry.name = entry.name + "_" + entry.extension
            new_entry.name = new_entry.name + "_" + new_entry.extension
            break

    entries.append(new_entry)

func add_sub_holder(sub_holder : ResDbHolder):
    sub_holders.append(sub_holder)

func get_sub_holder(name : String) -> ResDbHolder :
    for sub_holder in sub_holders:
        if (sub_holder.name == name):
            return sub_holder
        
        var subsub_holder = sub_holder.get_sub_holder(name)
        if (subsub_holder != null):
            return subsub_holder

    return null

# GDScript
func get_final_text_gd() -> String:
    var text = ""
    var prefix = ""

    if (is_root):
        text += "extends Node\n\n"
    else:
        text +="class %s:\n"  % [name_class_cs]
        text += "\textends RefCounted\n\n"
        prefix = "\t"

    for holder in sub_holders:
        text += prefix + "var %s : %s = %s.new()\n" % [holder.name, holder.name_class_gd, holder.name_class_gd]

    for entry in entries:
        text += prefix + "var %s : %s = preload(\"%s\")\n" % [entry.name, entry.type_gd, entry.path]

    if (is_root):
        text += get_sub_holders_text_gd()

    return text

func get_sub_holders_text_gd() -> String:
    var text = "\n"

    for sub_holder in sub_holders:
        text += sub_holder.get_final_text_gd()
        text += sub_holder.get_sub_holders_text_gd()

    return text

# GDScript
func get_final_text_cs() -> String:
    var text = ""
    var keyword = ""

    if (is_root):
        text += "using Godot;\n"
        text += "using System;\n\n"
        keyword = "static "

    text += "public class %s\n{\n" % [name_class_cs]

    for holder in sub_holders:
        text += "\tpublic %sreadonly %s %s = new();\n" % [keyword, holder.name_class_cs, holder.name.to_pascal_case()]

    for entry in entries:
        text += "\tpublic %sreadonly %s %s = ResourceLoader.Load<%s>(\"%s\");\n" % [keyword, entry.type_cs, entry.name.to_pascal_case(), entry.type_cs, entry.path]

    text += "}\n"

    if (is_root):
        text += get_sub_holders_text_cs()

    return text

func get_sub_holders_text_cs() -> String:
    var text = "\n"

    for sub_holder in sub_holders:
        text += sub_holder.get_final_text_cs()
        text += sub_holder.get_sub_holders_text_cs()

    return text