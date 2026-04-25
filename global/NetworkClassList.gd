# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name NetworkItemClassList extends CoreClassListDB
## Contains a list of all the classes that can be networked, stored here so they can be found when deserializing a network request


## Init
func _init(p_uuid: String = "", ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	_set_class_name("NetworkItemClassList")


## ready
func _ready() -> void:
	_gbc_index = Data.get_gbc_config(NetworkItem)
	_global_class_tree = {
		"NetworkItem": {
			"NetworkHandler": {
				"NetworkHandler": NetworkHandler
			},
			"NetworkSession": {
				"NetworkSession": NetworkSession,
			},
			"NetworkNode": {
				"NetworkNode": NetworkNode,
			},
			"NetworkItem": NetworkItem
		}
	}
	
	super._ready()
