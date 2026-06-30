extends CanvasLayer

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var ammo_label: Label = $VBoxContainer/AmmoLabel
@onready var kill_feed: VBoxContainer = $VBoxContainer/KillFeed
@onready var death_screen: Control = $DeathScreen
@onready var reload_label: Label = $VBoxContainer/ReloadLabel
@onready var timer_label: Label = $TopCenterContainer/TimerLabel
@onready var round_label: Label = $TopCenterContainer/RoundLabel
@onready var kill_label: Label = $TopCenterContainer/KillLabel
@onready var round_end_screen: Control = $RoundEndScreen
@onready var round_end_label: Label = $RoundEndScreen/RoundEndLabel
@onready var round_scores_label: Label = $RoundEndScreen/RoundScoresLabel
@onready var game_over_screen: Control = $GameOverScreen
@onready var game_over_label: Label = $GameOverScreen/GameOverLabel
@onready var winner_label: Label = $GameOverScreen/WinnerLabel
@onready var final_scores_label: Label = $GameOverScreen/FinalScoresLabel
@onready var pause_menu: Control = $PauseMenu
@onready var _gm = get_node("/root/GameManager")


func _ready() -> void:
	$PauseMenu/VBoxContainer/ResumeBtn.pressed.connect(_on_resume_pressed)
	$PauseMenu/VBoxContainer/ExitBtn.pressed.connect(_on_exit_pressed)
	var player: Node = get_parent()
	if player.has_signal("health_changed"):
		player.health_changed.connect(_update_health)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_update_ammo)
	if player.has_signal("died"):
		player.died.connect(_on_died)
	if player.has_signal("reloading_changed"):
		player.reloading_changed.connect(_on_reloading_changed)
	if player.has_signal("reloads_changed"):
		player.reloads_changed.connect(_on_reloads_changed)

	_gm.round_started.connect(_on_round_started)
	_gm.round_ended.connect(_on_round_ended)
	_gm.game_ended.connect(_on_game_ended)
	_gm.time_updated.connect(_on_time_updated)
	_gm.scores_updated.connect(_on_scores_updated)

	round_end_screen.visible = false
	game_over_screen.visible = false


func _update_health(new_health: int) -> void:
	health_label.text = "HP: %d/100" % new_health


func _update_ammo(new_ammo: int) -> void:
	ammo_label.text = "Ammo: %d/%d" % [new_ammo, PlayerCharacter.MAX_AMMO]


func _on_reloading_changed(is_reloading: bool) -> void:
	if is_reloading:
		ammo_label.text = "RELOADING..."
	else:
		var player: Node = get_parent()
		ammo_label.text = "Ammo: %d/%d" % [player.ammo, PlayerCharacter.MAX_AMMO]


func _on_reloads_changed(count: int) -> void:
	reload_label.text = "Reloads: %d/%d" % [count, PlayerCharacter.MAX_RELOADS]


func _on_died() -> void:
	death_screen.visible = true
	await get_tree().create_timer(2.0).timeout
	death_screen.visible = false


func _on_time_updated(time_left: float) -> void:
	var seconds: int = int(time_left)
	var mins: int = seconds / 60
	var secs: int = seconds % 60
	timer_label.text = "%02d:%02d" % [mins, secs]


func _on_scores_updated(scores: Dictionary) -> void:
	var my_id: int = multiplayer.get_unique_id()
	var my_kills: int = scores.get(my_id, 0)
	kill_label.text = "Kills: %d" % my_kills


func _on_round_started(round: int) -> void:
	round_label.text = "Round %d/%d" % [round, _gm.MAX_ROUNDS]
	round_end_screen.visible = false
	game_over_screen.visible = false


func _on_round_ended(scores: Dictionary) -> void:
	round_end_screen.visible = true
	var round_num: int = _gm.current_round
	round_end_label.text = "Round %d Selesai!" % round_num

	var score_text: String = ""
	var sorted: Array = []
	for pid in scores:
		sorted.append({"id": pid, "kills": scores[pid]})
	sorted.sort_custom(func(a, b): return a.kills > b.kills)

	for entry in sorted:
		var pname: String = NetworkManager.get_player_name(entry.id)
		score_text += "%s: %d kill" % [pname, entry.kills]
		if entry.kills != 1:
			score_text += "s"
		score_text += "\n"

	if score_text.is_empty():
		score_text = "Tidak ada kill"
	round_scores_label.text = score_text


func _on_game_ended(winner_id: int, final_scores: Dictionary) -> void:
	round_end_screen.visible = false
	game_over_screen.visible = true

	game_over_label.text = "Permainan Selesai!"

	if winner_id == -1:
		winner_label.text = "Tidak ada pemenang"
	else:
		var wname: String = NetworkManager.get_player_name(winner_id)
		winner_label.text = "Pemenang: %s" % wname

	var score_text: String = ""
	var sorted: Array = []
	for pid in final_scores:
		sorted.append({"id": pid, "kills": final_scores[pid]})
	sorted.sort_custom(func(a, b): return a.kills > b.kills)

	for entry in sorted:
		var pname: String = NetworkManager.get_player_name(entry.id)
		score_text += "%s: %d kill" % [pname, entry.kills]
		if entry.kills != 1:
			score_text += "s"
		score_text += "\n"

	if score_text.is_empty():
		score_text = "Tidak ada kill"
	final_scores_label.text = score_text


func toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_menu.visible else Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	pause_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_exit_pressed() -> void:
	NetworkManager.disconnect_from_server()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
