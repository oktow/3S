extends Node

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal player_names_updated(names: Dictionary)

const DEFAULT_PORT: int = 2456
const DISCOVERY_PORT: int = 2457
const MAX_PLAYERS: int = 8

var player_name: String = "Player"
var player_names: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", DEFAULT_PORT)


func join(ip: String, port: int = DEFAULT_PORT) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_client(ip, port)
	multiplayer.multiplayer_peer = peer
	print("Joining ", ip, ":", port)


func disconnect_from_server() -> void:
	multiplayer.multiplayer_peer = null


func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)
	player_connected.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("Peer disconnected: ", peer_id)
	player_disconnected.emit(peer_id)
	if multiplayer.is_server() and player_names.has(peer_id):
		player_names.erase(peer_id)
		_broadcast_player_names.rpc(player_names)


func _on_connected_to_server() -> void:
	print("Connected to server")


func _on_connection_failed() -> void:
	print("Connection failed")


func _on_server_disconnected() -> void:
	print("Server disconnected")
	server_disconnected.emit()


func register_player_name(pid: int, pname: String) -> void:
	if not multiplayer.is_server():
		return
	player_names[pid] = pname
	_broadcast_player_names.rpc(player_names)


func get_player_name(pid: int) -> String:
	return player_names.get(pid, "Player %d" % pid)


@rpc("any_peer", "call_local", "reliable")
func _receive_player_name(pid: int, pname: String) -> void:
	if not multiplayer.is_server():
		return
	register_player_name(pid, pname)


@rpc("authority", "call_local", "reliable")
func _broadcast_player_names(names: Dictionary) -> void:
	player_names = names
	player_names_updated.emit(names)
