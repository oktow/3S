extends CharacterBody3D

signal died
signal health_changed(new_health: int)
signal ammo_changed(new_ammo: int)
signal reloading_changed(is_reloading: bool)

const SPEED: float = 5.0
const BULLET_SPEED: float = 80.0
const MOUSE_SENSITIVITY: float = 0.002
const MAX_HEALTH: int = 100
const MAX_AMMO: int = 30
const DAMAGE_PER_SHOT: int = 10

var health: int = MAX_HEALTH
var ammo: int = MAX_AMMO
var is_dead: bool = false
var is_reloading: bool = false

const RELOAD_TIME: float = 1.5

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var muzzle: Marker3D = $Head/Camera3D/Muzzle
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var syncer: MultiplayerSynchronizer = $MultiplayerSynchronizer


func _ready() -> void:
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	NetworkManager.player_disconnected.connect(_on_player_left)

	syncer.set_process(false)
	await get_tree().process_frame
	syncer.set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -deg_to_rad(90), deg_to_rad(90))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event.is_action_pressed("reload"):
		_start_reload()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return

	var input_dir: Vector2 = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")

	var direction: Vector3 = (head.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if not is_on_floor():
		velocity.y -= 9.8 * delta * 2

	move_and_slide()

	if Input.is_action_just_pressed("shoot"):
		_shoot_local()


func _shoot_local() -> void:
	if is_dead or is_reloading or ammo <= 0:
		return

	ammo -= 1
	ammo_changed.emit(ammo)

	if ammo == 0:
		_start_reload()

	if not audio_stream_player.playing:
		audio_stream_player.play()

	_spawn_bullet()


func _start_reload() -> void:
	if is_reloading or ammo == MAX_AMMO:
		return

	is_reloading = true
	reloading_changed.emit(true)

	await get_tree().create_timer(RELOAD_TIME).timeout

	ammo = MAX_AMMO
	is_reloading = false
	ammo_changed.emit(ammo)
	reloading_changed.emit(false)


func _spawn_bullet() -> void:
	var bullet: Area3D = bullet_scene.instantiate()
	bullet.shooter_id = multiplayer.get_unique_id()
	bullet.direction = -camera.global_basis.z
	bullet.position = muzzle.global_position
	get_tree().current_scene.add_child(bullet)


@rpc("any_peer", "call_local")
func take_damage(amount: int, attacker_id: int) -> void:
	if is_dead:
		return

	health = max(0, health - amount)
	health_changed.emit(health)

	if health <= 0:
		_die.rpc(attacker_id)


@rpc("authority", "call_local", "reliable")
func _die(_attacker_id: int) -> void:
	is_dead = true
	died.emit()
	hide()

	await get_tree().create_timer(3.0).timeout

	health = MAX_HEALTH
	ammo = MAX_AMMO
	is_dead = false
	show()


func _on_player_left(peer_id: int) -> void:
	if peer_id == get_multiplayer_authority():
		queue_free()
