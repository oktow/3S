extends Node3D

@onready var spawn_points: Node3D = $SpawnPoints

var player_scene: PackedScene = preload("res://scenes/Player.tscn")
var _gm


func _ready() -> void:
	_gm = get_node("/root/GameManager")
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	if multiplayer.is_server():
		_spawn_for_peer(multiplayer.get_unique_id())
		await get_tree().create_timer(1.0).timeout
		_gm.start_game()


func _spawn_for_peer(peer_id: int) -> void:
	var spawn_pos: Vector3 = get_spawn_point(peer_id)
	_spawn_player_on_all.rpc(peer_id, spawn_pos)


@rpc("authority", "call_local", "reliable")
func _spawn_player_on_all(peer_id: int, spawn_pos: Vector3) -> void:
	var player: Node = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	player.position = spawn_pos
	add_child(player, true)


func get_spawn_point(peer_id: int) -> Vector3:
	var points: Array[Node] = spawn_points.get_children()
	if points.is_empty():
		return Vector3.ZERO
	var index: int = peer_id % points.size()
	return points[index].position


func _on_player_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn_for_peer(peer_id)


func _on_player_disconnected(peer_id: int) -> void:
	var player_path: NodePath = NodePath(str(peer_id))
	if has_node(player_path):
		get_node(player_path).queue_free()


func _on_server_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
