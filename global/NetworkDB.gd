# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Controller, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name NetworkItemDB extends CoreObjectDB
## Validates objects are NetworkItems


## init
func _init(p_uuid: String = "", ...p_args: Array[Variant]) -> void:
	super._init(p_uuid, p_args)
	_set_class_name("NetworkItemDB")


## Returns true if the given component is allowed in this ObjectDB
func is_component_allowed(p_component: Object) -> bool:
	return p_component is NetworkItem
