# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name NetworkItem extends Node
## Base class for all NetworkItems in the NetworkManager system


## Emitted when the user-defined name of this object changes.
signal name_changed()

## Emitted when this object is to be deleted (freed from memory). 
@warning_ignore("unused_signal")
signal delete_requested()


## The user-defined name of this object. The variable name can be arbitrary.
var _name: String

## The UUID of this object. The variable name can be arbitrary.
var _uuid: String

## The class name of this object. Must be set by any class that extends this base class.
var _class_name: String

## The inheritance tree of this object. Defaults to include this class.
var _class_tree: Array[String]

## The SettingsManager instance associated with this object. Variable name can be arbitrary.
var _settings: SettingsManager = SettingsManager.new()


## init.
func _init(p_uuid: String = UUID.v4()) -> void:
	_uuid = p_uuid
	_set_class_name("NetworkNode")
	
	_settings.set_owner(self)
	_settings.set_inheritance_array(_class_tree)


## Returns the user-defined name of this object.
func get_uname() -> String:
	return _name


## Returns the UUID of this object.
func get_uuid() -> String:
	return _uuid


## Returns the class name of this object.
func get_class_name() -> String:
	return _class_name


## Returns a copy of the inheritance tree for this object.
func get_class_tree() -> Array[String]:
	return _class_tree.duplicate()


## Returns the SettingsManager for this object.
func get_settings() -> SettingsManager:
	return _settings


## Sets the name of this object. If p_no_signal is true, the name_changed signal is not emitted.
func set_uname(p_name: String, p_no_signal: bool = false) -> void:
	_name = p_name
	
	if not p_no_signal:
		name_changed.emit(_name)


## Returns a JSON-compliant dictionary containing a serialized version of this object.
func serialize(p_flags: Data.SerializationFlags) -> Dictionary[String, Variant]:
	return {
		"name": _name,
		"class_name": _class_name,
	}.merged({} if p_flags & Data.SerializationFlags.NO_UUID else {
		"uuid": _uuid,
	})


## Deserializes data either read from disk or returned by serialize().
func deserialize(p_serialized_data: Dictionary, p_flags: Data.SerializationFlags) -> void:
	set_uname(type_convert(p_serialized_data.get("name", _name), TYPE_STRING), true)
	
	if not p_flags & Data.SerializationFlags.NO_UUID:
		_uuid = type_convert(p_serialized_data.get("uuid", _uuid), TYPE_STRING)


## Sets the class name for this object and appends it to the inheritance tree.
func _set_class_name(p_class_name: String) -> void:
	_class_name = p_class_name
	_class_tree.append(p_class_name)
