extends RefCounted

class_name ResDbHolder

var entries : Array[ResDbEntry] = []
var sub_holders : Array[ResDbHolder] = []

var name : String
var name_class : String

var is_root = false

func add_entry(entry_name : String, entry_extension : String, entry_type : String, entry_path : String):
    var new_entry = ResDbEntry.new()
    new_entry.name = entry_name
    new_entry.extension = entry_extension
    new_entry.type = entry_type
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

func get_final_text() -> String:
    var text = ""
    var prefix = ""

    if (is_root):
        text += prefix + "extends Node\n\n"
        text += "class_name %s\n\n" % [name_class]
    else:
        text +="class %s:\n"  % [name_class]
        text += "\textends RefCounted\n\n"
        prefix = "\t"

    print(name_class + " sub_holders" + str(sub_holders.size()))
    for holder in sub_holders:
        text += prefix + "var %s : %s = %s.new()\n" % [holder.name, holder.name_class, holder.name_class]

    print(name_class + " entries " + str(entries.size()))
    for entry in entries:
        text += prefix + "var %s : %s = preload(\"%s\")\n" % [entry.name, entry.type, entry.path]

    if (is_root):
        text += get_sub_holders_text()

    return text

func get_sub_holders_text() -> String:
    var text = "\n"

    for sub_holder in sub_holders:
        text += sub_holder.get_final_text()
        text += sub_holder.get_sub_holders_text()

    return text