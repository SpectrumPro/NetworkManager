# Copyright (c) 2026 Liam Sherwin, All rights reserved.
# This file is part of the NetworkManager Utility, licensed under the GPL v3.
# See the LICENSE file for details.

class_name NetworkManager extends Node
## Manages NetworkHandlers


## Emitted when a command is recieved
signal command_recieved(p_from: NetworkNode, p_type: Variant.Type, p_command: Variant)


## Enum for MessageType
enum MessageType {
	NONE		= 0, ## Unknown message
	COMMAND		= 1, ## Command message
	SIGNAL		= 2, ## Signal message
	RESPONSE	= 3, ## Command response message
}


## The max time in seconds that this node will wait for a response from another node
const ResponseMaxWaitTime: float = 10


## All NetworkHandlers currently loaded in the engine
var _active_handlers: Dictionary[String, NetworkHandler]

## Dict containg all NetworkItems sorted by classname
var _registered_items: Dictionary[String, Array]

## Contains all network objects, RefMap for "id": SettingsManager
var _registered_network_objects: RefMap = RefMap.new()

## Stores all lamba functions that are connected to an objects signals for each SettingsManager
var _networked_objects_signal_connections: Dictionary[SettingsManager, Dictionary]

## Contains all Promises awaiting a responce from the network
var _awaiting_responces: Dictionary[String, Promise]

## The SettingsManager for NetworkManager
var _settings: SettingsManager = SettingsManager.new()


## Init
func _init() -> void:
	_settings.set_owner(self)
	_settings.set_inheritance_array(["NetworkManager"])
	
	_settings.register_control("StartAll", Data.Type.ACTION, start_all, Callable(), [])
	_settings.register_control("StopAll", Data.Type.ACTION, stop_all, Callable(), [])
	
	NetworkConfig.load_config("res://NetworkConfig.gd")


## Ready
func _ready() -> void:
	for handler_name: String in NetworkConfig.available_handlers:
		var new_handler: NetworkHandler =  NetworkConfig.available_handlers[handler_name].new()
		
		new_handler.node_found.connect(NetworkConfig.network_item_object_db.register_component)
		new_handler.session_created.connect(NetworkConfig.network_item_object_db.register_component)
		new_handler.command_recieved.connect(_on_command_recieved)
		
		NetworkConfig.network_item_object_db.register_component(new_handler)
		add_child(new_handler)
		
		_active_handlers[handler_name] = new_handler


## Process
func _process(_p_delta: float) -> void:
	for msg_id: String in _awaiting_responces.duplicate():
		var promise: Promise = _awaiting_responces[msg_id]
		
		if Time.get_unix_time_from_system() - promise.get_created_time() >= ResponseMaxWaitTime:
			promise.reject([ERR_TIMEOUT])
			_awaiting_responces.erase(msg_id)


## Gets the SettingsManager
func get_settings() -> SettingsManager:
	return _settings


## Starts all the NetworkHandlers
func start_all() -> void:
	for handler: NetworkHandler in _active_handlers.values():
		handler.start_node()


## Stop all the NetworkHandlers
func stop_all() -> void:
	for handler: NetworkHandler in _active_handlers.values():
		handler.stop_node()


## Sends a message to the session, using p_node_filter as the NodeFilter
func send_message(p_command: Variant, p_node_filter: NetworkSession.NodeFilter = NetworkSession.NodeFilter.AUTO, p_nodes: Array[NetworkNode] = []) -> Error:
	return _active_handlers["Constellation"].send_command(p_command, p_node_filter, p_nodes)


## Sends a MessageType.COMMAND to the network
func send_command(p_for: String, p_call: String, p_args: Array = [], p_flags: Data.NetworkFlags = Data.NetworkFlags.NONE, p_node_filter: NetworkSession.NodeFilter = NetworkSession.NodeFilter.AUTO, p_nodes: Array[NetworkNode] = []) -> Promise:
	var msg_id: String = UUID.v4()
	var promise: Promise = Promise.new()
	var message: Dictionary = {
		"type": MessageType.COMMAND,
		"msg_id": msg_id,
		"for": p_for,
		"call": p_call,
		"args": var_to_str(serialize_objects(p_args, p_flags))
	}
	
	var error: Error = send_message(message, p_node_filter, p_nodes)
	if error:
		return promise.auto_reject([error])
	
	_awaiting_responces[msg_id] = promise
	return promise


## Sends a MessageType.SIGNAL
func send_signal(p_from: String, p_signal: String, p_args: Array = [], p_flags: Data.NetworkFlags = Data.NetworkFlags.NONE, p_node_filter: NetworkSession.NodeFilter = NetworkSession.NodeFilter.AUTO, p_nodes: Array[NetworkNode] = []) -> Error:
	return send_message({
		"type": MessageType.SIGNAL,
		"for": p_from,
		"call": p_signal,
		"args": var_to_str(serialize_objects(p_args, p_flags)), 
	}, p_node_filter, p_nodes)


## Sends a MessageType.RESPONSE
func send_responce(p_id: String, p_args: Array = [], p_flags: Data.NetworkFlags = Data.NetworkFlags.NONE, p_node_filter: NetworkSession.NodeFilter = NetworkSession.NodeFilter.AUTO, p_nodes: Array[NetworkNode] = []) -> Error:
	return send_message({
		"type": MessageType.RESPONSE,
		"msg_id": p_id,
		"args": var_to_str(serialize_objects(p_args, p_flags)), 
	}, p_node_filter, p_nodes)


## Rgegisters a network object
func register_network_object(p_id: String, p_settings_manager: SettingsManager) -> void:
	if _registered_network_objects.has_left(p_id) or not is_instance_valid(p_settings_manager):
		return;
	
	for p_signal_name: String in p_settings_manager.get_networked_signals():
		var p_signal: Signal = p_settings_manager.get_networked_signal(p_signal_name)
		var method: Callable = func (...args) -> void: send_signal(p_id, p_signal_name, args, p_settings_manager.get_signal_network_flags(p_signal_name))
		p_signal.connect(method)
		
		_networked_objects_signal_connections.get_or_add(p_settings_manager, {})[p_signal] = method
	
	if not p_settings_manager.get_delete_signal().is_null():
		p_settings_manager.get_delete_signal().connect(deregister_network_object.bind(p_settings_manager), CONNECT_ONE_SHOT)
	
	_registered_network_objects.map(p_id, p_settings_manager)


## Deregister a network object
func deregister_network_object(p_settings_manager: SettingsManager) -> void:
	if not _registered_network_objects.has_right(p_settings_manager):
		return
	
	for p_signal: Signal in _networked_objects_signal_connections.get(p_settings_manager, []):
		p_signal.disconnect(_networked_objects_signal_connections[p_settings_manager][p_signal])
	
	_registered_network_objects.erase_right(p_settings_manager)
	_networked_objects_signal_connections.erase(p_settings_manager)


## Gets an active handler by its class name
func get_active_handler_by_name(p_classname: String) -> NetworkHandler:
	return _active_handlers.get(p_classname, null)


## Returns all active NetworkHandlers
func get_all_active_handlers() -> Dictionary[String, NetworkHandler]:
	return _active_handlers.duplicate()


## Gets all the NetworkItems by classname
func get_items_by_classname(p_classname: String) -> Array:
	return _registered_items.get(p_classname, [])


## Replaces any object in the given data with uuid refernces. Checks sub arrays and dictionarys
func serialize_objects(p_data: Variant, p_flags: int = Data.NetworkFlags.NONE) -> Variant:
	match typeof(p_data):
		TYPE_OBJECT when NetworkConfig.networkable_object_db.has_component(p_data):
			return {
					"_object_ref": p_data.get_uuid(),
				}.merged({
					"_serialized_object": p_data.serialize(Data.SerializationFlags.NONE),
					"_class_name": p_data.get_class_name(),
				} if p_flags & Data.NetworkFlags.ALLOW_SERIALIZE else {})
		
		TYPE_OBJECT:
			return str(p_data)
		
		TYPE_DICTIONARY:
			var new_dict: Dictionary = {}
			
			for key: Variant in p_data.keys():
				new_dict[key] = serialize_objects(p_data[key], p_flags)
			
			return new_dict
		
		TYPE_ARRAY:
			var new_array: Array = []
			
			for item in p_data:
				new_array.append(serialize_objects(item, p_flags))
			
			return new_array
	
	return p_data


## Checks for uuid refernces left by serialize_objects(). If one is found the corrisponding object will be created or found via ComponentDB
func deserialize_objects(p_data: Variant, p_flags: int = Data.NetworkFlags.NONE) -> Variant:
	match typeof(p_data):
		TYPE_DICTIONARY when p_data.has("_object_ref") and typeof(p_data._object_ref) == TYPE_STRING:
			if _registered_network_objects.has_left(p_data._object_ref):
				return _registered_network_objects.left(p_data._object_ref).get_owner()
				
			elif p_data.has("_class_name") and typeof(p_data._class_name) == TYPE_STRING and p_flags & Data.NetworkFlags.ALLOW_DESERIALIZE:
				if NetworkConfig.networkable_class_list.has_class(p_data._class_name):
					var initialized_object: Object = NetworkConfig.networkable_class_list.get_class_script(p_data._class_name).new(p_data._object_ref)
					
					if p_data.has("_serialized_object") and typeof(p_data._serialized_object) == TYPE_DICTIONARY:
						initialized_object.deserialize(p_data._serialized_object, Data.SerializationFlags.NONE)
						
					return initialized_object
				
				elif p_flags & Data.NetworkFlags.ALLOW_UNRESOLVED:
					return p_data._object_ref
			
			elif p_flags & Data.NetworkFlags.ALLOW_UNRESOLVED:
				return p_data._object_ref
			
			else:
				return null
		
		TYPE_DICTIONARY:
			var new_dict: Dictionary = {}
			
			for key: Variant in p_data.keys():
				new_dict[key] = deserialize_objects(p_data[key], p_flags)
			
			return new_dict
		
		TYPE_ARRAY:
			var new_array: Array = []
			
			for item: Variant in p_data:
				new_array.append(deserialize_objects(item, p_flags))
			
			return new_array
	
	return p_data


## Emitted when a command is recieved
func _on_command_recieved(p_from: NetworkNode, p_type: Variant.Type, p_command: Variant) -> void:
	print_verbose("Got command: ", p_command, " from: ", p_from.get_node_name())
	
	if p_command is Dictionary:
		var object_id: String = type_convert(p_command.get("for", ""), TYPE_STRING)
		var for_method: String = type_convert(p_command.get("call", ""), TYPE_STRING)
		var msg_id: String = type_convert(p_command.get("msg_id", ""), TYPE_STRING)
		var args: Variant = str_to_var(type_convert(p_command.get("args", "[]"), TYPE_STRING))
		
		if typeof(args) != TYPE_ARRAY:
			return
		
		match p_command.get("type", 0):
			MessageType.COMMAND:
				if _registered_network_objects.has_left(object_id):
					var manager: SettingsManager = _registered_network_objects.left(object_id)
					args = deserialize_objects(args, manager.get_method_network_flags(for_method))
					
					var result: Variant = manager.get_networked_method(for_method).callv(args)
					send_responce(msg_id, [result], manager.get_method_network_flags(for_method), NetworkSession.NodeFilter.MANUAL, [p_from])
				
			MessageType.SIGNAL:
				if _registered_network_objects.has_left(object_id):
					var manager: SettingsManager = _registered_network_objects.left(object_id)
					args = deserialize_objects(args, manager.get_callback_network_flags(for_method))
					
					manager.get_networked_callback(for_method).callv(args)
				
			MessageType.RESPONSE:
				if _awaiting_responces.has(msg_id):
					args = deserialize_objects(args, Data.NetworkFlags.ALLOW_DESERIALIZE)
					_awaiting_responces[msg_id].resolve(args)
					_awaiting_responces.erase(msg_id)
	
	command_recieved.emit(p_from, p_type, p_command)


## Stores config for NetworkManager
class NetworkConfig extends Object:
	## The instance of ClassListDB asigned to the networkable class 
	static var networkable_class_list: ClassListDB
	
	## The instance of ObjectDB asigned to the networkable class 
	static var networkable_object_db: ObjectDB
	
	## The instacne of ClassListDB for NetworkItems
	static var network_item_class_list: ClassListDB
	
	## The instance of ObjectDB for NetworkItems
	static var network_item_object_db: ObjectDB
	
	## All available NetworkHandlers that can be loaded
	static var available_handlers: Dictionary = {}
	
	
	## Loads config from a file
	static func load_config(p_path: String) -> bool:
		var script: Variant = load(p_path)
		
		if script is not GDScript or script.get("config") is not Dictionary:
			return false
		
		var config: Dictionary = script.get("config")
		
		networkable_class_list = config.networkable_class_list
		networkable_object_db = config.networkable_object_db
		
		network_item_class_list = config.network_item_class_list
		network_item_object_db = config.network_item_object_db
		
		available_handlers = config.available_handlers
		
		return true
