# Copyright (c) 2026 Liam Sherwin. All rights reserved.
# This file is part of the Spectrum Lighting Engine, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name NetworkNode extends NetworkItem
## Base class for all NetworkNodes

@warning_ignore_start("unused_signal", "unused_parameter", "unused_private_class_variable")


## Emitted when the connection state is changed
signal connection_state_changed(connection_state: ConnectionState)

## Emittes when the current session is changed, or left
signal session_changed(session: NetworkSession)

## Emitted when the Node joins a NetworkSession
signal session_joined(session: NetworkSession)

## Emitted when the node leaves the current session
signal session_left()

## Emitted when this node has connected to the session master and is ready to send data. Only emitted on the local node
signal connected_to_session_master()

## Emitted if this node becomes the master of its session
signal is_now_session_master()

## Emitted if this node is no longer the master of its session
signal is_no_longer_session_master()

## Emitted when the last seen time is changed, IE the node was just seen
signal last_seen_changed(last_seen: float)


## State Enum for remote node
enum ConnectionState {
	UNKNOWN,			## No state assigned yet
	OFFLINE,			## Node is offline
	DISCOVERED,			## Node was found via discovery
	CONNECTING,			## Attempting to establish connection
	CONNECTED,			## Successfully connected and active
	LOST_CONNECTION,	## Node timed out or disconnected unexpectedly
}

## Enum for node flags
enum NodeFlags {
	NONE				= 0,		## Default state
	UNKNOWN				= 1 << 0,	## This node is a unknown node
	LOCAL_NODE			= 2 << 0,	## This node is a Local node
}


## Current state of the remote node local connection
var _connection_state: ConnectionState = ConnectionState.UNKNOWN

## Node Flags
var _node_flags: int = NodeFlags.NONE

## Session master state
var _is_session_master: bool = false

## Unknown node state, node has not been found on the network yet
var _is_unknown: bool = false

## The Session
var _session: NetworkSession

## UNIX timestamp of the last time this node was seen on the network
var _last_seen: float = 0


## Creates a new ConstellationNode in LocalNode mode
static func create_local_node() -> NetworkNode:
	var node: NetworkNode = NetworkNode.new()
	
	return node


## Creates an unknown node
static func create_unknown_node(p_node_id: String) -> NetworkNode:
	var node: NetworkNode = NetworkNode.new()
	
	node._mark_as_unknown(true)
	node._set_node_name("UnknownNode")
	
	return node


## init
func _init(p_uuid: String = UUID.v4()) -> void:
	super._init(p_uuid)
	_set_class_name("NetworkNode")


## Joins the given session
func join_session(p_session: NetworkSession) -> bool:
	return false


## Leavs the current session
func leave_session() -> bool:
	return false


## Closes this nodes local object
func close() -> void:
	pass


## Gets the connection state
func get_connection_state() -> ConnectionState:
	return _connection_state


## Gets the human readable connection state
func get_connection_state_human() -> String:
	return ConnectionState.keys()[_connection_state].capitalize()


## Gets the Node's Session
func get_session() -> NetworkSession:
	return _session


## Gets the current session ID, or ""
func get_session_id() -> String:
	if _session:
		return _session.get_session_id()
	
	return ""


## Returns the last time this node was seen on the network
func get_last_seen_time() -> float:
	return _last_seen


## Gets the name of this NetworkNode
func get_node_name() -> String:
	return _name


## Sends a message to set the name of this node on the network
func set_node_name(p_name: String) -> void:
	pass


## Sets the session
func set_session(p_session: NetworkSession) -> bool:
	if is_instance_valid(p_session):
		return join_session(p_session)
	else:
		return leave_session()


## Returns True if this node is local
func is_local() -> bool:
	return _node_flags & NodeFlags.LOCAL_NODE


## Returns true if this node is unknown
func is_unknown() -> bool:
	return _node_flags & NodeFlags.UNKNOWN


## Returns true if this node is the master of its session
func is_sesion_master() -> bool:
	return _is_session_master
