extends Node

signal round_started(p_round: int)
signal round_ended(scores: Dictionary)
signal game_ended(winner_id: int, final_scores: Dictionary)
signal time_updated(time_left: float)
signal scores_updated(scores: Dictionary)

const ROUND_DURATION: float = 180.0
const MAX_ROUNDS: int = 3
const MAX_RELOADS: int = 5

var current_round: int = 0
var scores: Dictionary = {}
var round_timer: float = 0.0
var game_active: bool = false
var round_active: bool = false

var _timer: Timer
var _alive_players: Dictionary = {}


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)


func start_game() -> void:
	if not multiplayer.is_server():
		return
	scores.clear()
	current_round = 0
	game_active = true
	_start_next_round()


func _start_next_round() -> void:
	current_round += 1
	round_timer = ROUND_DURATION
	round_active = true

	_alive_players.clear()
	var peers = multiplayer.get_peers()
	for pid in peers:
		_alive_players[pid] = true
	_alive_players[multiplayer.get_unique_id()] = true

	round_started.emit(current_round)
	_timer.start()
	_sync_round_state.rpc(current_round, round_timer, scores)
	_reset_all_players.rpc()


func register_kill(killer_id: int, victim_id: int) -> void:
	if not multiplayer.is_server() or not round_active:
		return
	if killer_id == victim_id:
		return

	if not scores.has(killer_id):
		scores[killer_id] = 0
	scores[killer_id] += 1

	_alive_players[victim_id] = false

	_sync_round_state.rpc(current_round, round_timer, scores)
	_check_round_end()


func _check_round_end() -> void:
	var alive_count: int = 0
	for pid in _alive_players:
		if _alive_players[pid]:
			alive_count += 1
	if alive_count <= 1:
		_end_round()


func _on_timer_tick() -> void:
	if not round_active:
		return
	round_timer -= 1.0
	_sync_round_state.rpc(current_round, round_timer, scores)

	if round_timer <= 0:
		_end_round()


func _end_round() -> void:
	round_active = false
	_timer.stop()

	round_ended.emit(scores.duplicate())

	if current_round >= MAX_ROUNDS:
		await get_tree().create_timer(3.0).timeout
		_end_game()
	else:
		await get_tree().create_timer(5.0).timeout
		_start_next_round()


func _end_game() -> void:
	game_active = false
	var winner_id: int = _get_winner()
	game_ended.emit(winner_id, scores.duplicate())


func _get_winner() -> int:
	var best_id: int = -1
	var best_score: int = -1
	for pid in scores:
		if scores[pid] > best_score:
			best_score = scores[pid]
			best_id = pid
	return best_id


func get_kills_for_player(player_id: int) -> int:
	return scores.get(player_id, 0)


func get_local_player_id() -> int:
	return multiplayer.get_unique_id()


@rpc("authority", "call_local", "reliable")
func _sync_round_state(p_round: int, time_left: float, round_scores: Dictionary) -> void:
	current_round = p_round
	round_timer = time_left
	scores = round_scores
	time_updated.emit(time_left)
	scores_updated.emit(round_scores)


@rpc("authority", "call_local", "reliable")
func _reset_all_players() -> void:
	var world: Node = get_tree().current_scene
	if not world:
		return
	for child in world.get_children():
		if child.has_method("reset_for_new_round"):
			child.reset_for_new_round()
