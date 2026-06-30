extends Control

@onready var player_list: VBoxContainer = $CenterContainer/VBoxContainer/PlayerList
@onready var start_btn: Button = $CenterContainer/VBoxContainer/StartBtn
@onready var cancel_btn: Button = $CenterContainer/VBoxContainer/CancelBtn
@onready var countdown_label: Label = $CenterContainer/VBoxContainer/CountdownLabel
@onready var status_label: Label = $CenterContainer/VBoxContainer/StatusLabel

var _timer: Timer
var countdown_time: float = 10.0
var is_counting: bool = false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)

	start_btn.visible = multiplayer.is_server()
	cancel_btn.visible = false
	cancel_btn.disabled = true
	countdown_label.visible = false
	status_label.text = "Menunggu pemain lain..."

	_refresh_player_list()

	NetworkManager.player_connected.connect(_on_player_joined)
	NetworkManager.player_disconnected.connect(_on_player_left)

	if multiplayer.is_server():
		NetworkManager.register_player_name(multiplayer.get_unique_id(), NetworkManager.player_name)
	else:
		NetworkManager._receive_player_name.rpc_id(1, multiplayer.get_unique_id(), NetworkManager.player_name)


func _refresh_player_list() -> void:
	for child in player_list.get_children():
		child.queue_free()

	var sorted_ids: Array = []
	for pid in NetworkManager.player_names:
		sorted_ids.append(pid)
	sorted_ids.sort()

	for pid in sorted_ids:
		var label: Label = Label.new()
		var p_name: String = NetworkManager.get_player_name(pid)
		if pid == 1:
			label.text = "%s (Host)" % p_name
		else:
			label.text = p_name
		player_list.add_child(label)

	if sorted_ids.is_empty():
		var label: Label = Label.new()
		label.text = "(tidak ada pemain)"
		player_list.add_child(label)


func _on_player_joined(_pid: int) -> void:
	_refresh_player_list()


func _on_player_left(_pid: int) -> void:
	_refresh_player_list()


func _on_start_pressed() -> void:
	if not multiplayer.is_server():
		return
	is_counting = true
	countdown_time = 10.0
	_timer.start()
	_sync_start_countdown.rpc()


func _on_cancel_pressed() -> void:
	if not multiplayer.is_server():
		return
	is_counting = false
	_timer.stop()
	_sync_cancel_countdown.rpc()


func _on_timer_tick() -> void:
	countdown_time -= 1.0
	var display: int = int(ceil(countdown_time))
	_sync_countdown_tick.rpc(display)
	if countdown_time <= 0:
		is_counting = false
		_timer.stop()
		_sync_start_game.rpc()


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/World.tscn")


@rpc("authority", "call_local", "reliable")
func _sync_start_countdown() -> void:
	is_counting = true
	countdown_time = 10.0
	start_btn.visible = false
	cancel_btn.visible = multiplayer.is_server()
	cancel_btn.disabled = false
	countdown_label.visible = true
	status_label.text = ""
	countdown_label.text = "Mulai dalam 10 detik..."
	if not multiplayer.is_server():
		status_label.text = "Permainan akan segera dimulai..."


@rpc("authority", "call_local", "reliable")
func _sync_cancel_countdown() -> void:
	is_counting = false
	start_btn.visible = multiplayer.is_server()
	cancel_btn.visible = false
	cancel_btn.disabled = true
	countdown_label.visible = false
	status_label.text = "Countdown dibatalkan."


@rpc("authority", "call_local", "reliable")
func _sync_countdown_tick(display: int) -> void:
	countdown_time = display
	countdown_label.text = "Mulai dalam %d detik..." % display


@rpc("authority", "call_local", "reliable")
func _sync_start_game() -> void:
	_start_game()
