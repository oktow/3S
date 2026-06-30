class_name PlayerCharacter
extends CharacterBody3D

signal died
signal health_changed(new_health: int)
signal ammo_changed(new_ammo: int)
signal reloading_changed(is_reloading: bool)
signal reloads_changed(count: int)
signal kills_changed(count: int)

const SPEED: float = 5.0
const RUN_SPEED: float = 8.0
const MOUSE_SENSITIVITY: float = 0.002
const MAX_HEALTH: int = 100
const MAX_AMMO: int = 6
const MAX_RELOADS: int = 5
const DAMAGE_PER_SHOT: int = 10
const RELOAD_TIME: float = 3.0

var health: int = MAX_HEALTH
var ammo: int = MAX_AMMO
var is_dead: bool = false
var is_reloading: bool = false
var reloads_used: int = 0

var bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")

@onready var camera_arm: SpringArm3D = $CameraArm
@onready var camera: Camera3D = $CameraArm/Camera3D
@onready var anim_player: AnimationPlayer = $YBot/AnimationPlayer
@onready var ybot: Node3D = $YBot
@onready var weapon_pivot: BoneAttachment3D = $YBot/Armature/Skeleton3D/WeaponPivot
@onready var muzzle: Marker3D = $YBot/Armature/Skeleton3D/WeaponPivot/Muzzle
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var syncer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _gm = get_node("/root/GameManager")

var last_anim: String = "idle"


func _ready() -> void:
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	NetworkManager.player_disconnected.connect(_on_player_left)

	syncer.set_process(false)
	await get_tree().process_frame
	syncer.set_process(true)

	if is_multiplayer_authority():
		if multiplayer.is_server():
			NetworkManager.register_player_name(multiplayer.get_unique_id(), NetworkManager.player_name)
		else:
			NetworkManager._receive_player_name.rpc_id(1, multiplayer.get_unique_id(), NetworkManager.player_name)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_arm.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_arm.rotation.x = clamp(camera_arm.rotation.x, -deg_to_rad(60), deg_to_rad(60))

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

	var is_running = Input.is_action_pressed("sprint")
	var speed = RUN_SPEED if is_running else SPEED
	var is_moving = input_dir.length() > 0.1

	if is_moving:
		var cam_basis = camera.global_basis
		var direction: Vector3 = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		direction.y = 0
		if direction.length() > 0:
			direction = direction.normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	if not is_on_floor():
		velocity.y -= 9.8 * delta * 2

	move_and_slide()
	_update_animation(input_dir, is_running)

	if Input.is_action_just_pressed("shoot"):
		_shoot_local()


func _update_animation(input_dir: Vector2, is_running: bool) -> void:
	if is_reloading:
		return

	var target_anim = "idle"

	if input_dir.length() > 0.1:
		if input_dir.x > 0.5:
			target_anim = "strafe_right"
		elif input_dir.x < -0.5:
			target_anim = "strafe_left"
		elif is_running:
			target_anim = "run_forward"
		else:
			target_anim = "walk_pistol"

	if target_anim != last_anim:
		anim_player.play(target_anim, 0.15)
		last_anim = target_anim


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
	if is_reloading or ammo == MAX_AMMO or reloads_used >= MAX_RELOADS:
		return

	is_reloading = true
	reloads_used += 1
	reloads_changed.emit(reloads_used)
	reloading_changed.emit(true)
	anim_player.play("reload")
	last_anim = "reload"

	await get_tree().create_timer(RELOAD_TIME).timeout

	ammo = MAX_AMMO
	is_reloading = false
	ammo_changed.emit(ammo)
	reloading_changed.emit(false)


func _spawn_bullet() -> void:
	var bullet: Area3D = bullet_scene.instantiate()
	bullet.shooter_id = multiplayer.get_unique_id()

	var space_state = get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	var cam_fwd = -camera.global_basis.z
	var hit = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + cam_fwd * 1000.0))
	var target = hit.position if hit else cam_pos + cam_fwd * 1000.0
	bullet.direction = (target - muzzle.global_position).normalized()
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
func _die(attacker_id: int) -> void:
	if multiplayer.is_server():
		_gm.register_kill(attacker_id, get_multiplayer_authority())

	is_dead = true
	died.emit()
	hide()


func reset_for_new_round() -> void:
	health = MAX_HEALTH
	ammo = MAX_AMMO
	is_dead = false
	is_reloading = false
	reloads_used = 0
	show()

	health_changed.emit(health)
	ammo_changed.emit(ammo)
	reloads_changed.emit(reloads_used)
	reloading_changed.emit(false)

	var world: Node = get_tree().current_scene
	if world and world.has_method("get_spawn_point"):
		position = world.get_spawn_point(get_multiplayer_authority())


func _on_player_left(peer_id: int) -> void:
	if peer_id == get_multiplayer_authority():
		queue_free()
