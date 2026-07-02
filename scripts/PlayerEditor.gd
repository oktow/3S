extends Control

const HATS := [
	{"name": "Tanpa Topi", "icon": null},
	{"name": "Topi Koboy", "icon": null},
	{"name": "Top Hat", "icon": null},
]

const HAT_NONE := 0
const HAT_COWBOY := 1
const HAT_TOPHAT := 2

const WEAPONS := [
	{"name": "Tanpa Senjata", "scene": null, "icon": null},
	{"name": "Pistol", "scene": null, "icon": null},
]

# Camera orbit
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _cam_distance: float = 2.5
var _is_dragging: bool = false
var _drag_mouse_pos: Vector2

const CAM_PITCH_MIN: float = -deg_to_rad(80.0)
const CAM_PITCH_MAX: float = deg_to_rad(80.0)
const CAM_ORBIT_SPEED: float = 0.005

var current_hat_index: int = 1
var current_weapon_index: int = 1

@onready var player: PlayerCharacter = $SubViewportContainer/SubViewport/Player
@onready var preview_container: Control = $SubViewportContainer
@onready var camera: Camera3D = $SubViewportContainer/SubViewport/Camera3D
@onready var hat_slot: Panel = $Panel/VBoxContainer/HatSlot
@onready var hat_icon: TextureRect = $Panel/VBoxContainer/HatSlot/HBoxContainer/HatIcon
@onready var hat_name_label: Label = $Panel/VBoxContainer/HatSlot/HBoxContainer/HatNameLabel
@onready var hat_popup: PopupPanel = $Panel/VBoxContainer/HatPopup
@onready var hat_options: VBoxContainer = $Panel/VBoxContainer/HatPopup/PopupVBox

@onready var weapon_slot: Panel = $Panel/VBoxContainer/WeaponSlot
@onready var weapon_icon: TextureRect = $Panel/VBoxContainer/WeaponSlot/HBoxContainer/WeaponIcon
@onready var weapon_name_label: Label = $Panel/VBoxContainer/WeaponSlot/HBoxContainer/WeaponNameLabel
@onready var weapon_popup: PopupPanel = $Panel/VBoxContainer/WeaponPopup
@onready var weapon_options: VBoxContainer = $Panel/VBoxContainer/WeaponPopup/WeaponPopupVBox


func _ready() -> void:
	# Pastikan Player dalam mode editor, bukan mode game
	player.editor_mode = true
	# Lepaskan mouse capture dari game sebelumnya
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_setup_camera()
	_setup_hat_popup()
	_setup_weapon_popup()
	_update_ui()
	_apply_hat(current_hat_index)
	_apply_weapon(current_weapon_index)


func _setup_camera() -> void:
	# Inisialisasi posisi awal kamera (dari belakang)
	_cam_yaw = 0.0
	_cam_pitch = 0.0
	_cam_distance = 2.5
	_update_camera()


func _update_camera() -> void:
	if not is_instance_valid(player):
		return
	var target: Vector3 = player.global_position + Vector3(0, 0.9, 0)
	
	# Spherical to cartesian: orbit di sekitar target
	var pos: Vector3 = Vector3(
		sin(_cam_yaw) * cos(_cam_pitch),
		sin(_cam_pitch),
		cos(_cam_yaw) * cos(_cam_pitch)
	) * _cam_distance
	
	camera.position = target + pos
	camera.look_at(target)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Mulai drag hanya jika mouse di area preview 3D
				if preview_container.get_global_rect().has_point(event.position):
					_is_dragging = true
					_drag_mouse_pos = event.position
			else:
				_is_dragging = false
	
	if event is InputEventMouseMotion and _is_dragging:
		var delta: Vector2 = event.position - _drag_mouse_pos
		_cam_yaw -= delta.x * CAM_ORBIT_SPEED
		_cam_pitch -= delta.y * CAM_ORBIT_SPEED
		_cam_pitch = clamp(_cam_pitch, CAM_PITCH_MIN, CAM_PITCH_MAX)
		_drag_mouse_pos = event.position
		_update_camera()


func _setup_hat_popup() -> void:
	for i in HATS.size():
		var btn := Button.new()
		btn.text = HATS[i]["name"]
		btn.pressed.connect(_on_hat_selected.bind(i))
		hat_options.add_child(btn)


func _setup_weapon_popup() -> void:
	for i in WEAPONS.size():
		var btn := Button.new()
		btn.text = WEAPONS[i]["name"]
		btn.pressed.connect(_on_weapon_selected.bind(i))
		weapon_options.add_child(btn)


func _on_hat_selected(index: int) -> void:
	current_hat_index = index
	hat_popup.hide()
	_update_ui()
	_apply_hat(index)


func _on_weapon_selected(index: int) -> void:
	current_weapon_index = index
	weapon_popup.hide()
	_update_ui()
	_apply_weapon(index)


func _update_ui() -> void:
	hat_name_label.text = HATS[current_hat_index]["name"]
	hat_icon.texture = HATS[current_hat_index]["icon"]
	weapon_name_label.text = WEAPONS[current_weapon_index]["name"]
	weapon_icon.texture = WEAPONS[current_weapon_index]["icon"]


func _apply_hat(index: int) -> void:
	if not is_instance_valid(player):
		return
	
	# Hide both hats first
	if is_instance_valid(player.hat_node):
		player.hat_node.visible = false
	if is_instance_valid(player.hat_tophat_node):
		player.hat_tophat_node.visible = false
	
	# Show the selected hat
	match index:
		HAT_COWBOY:
			if is_instance_valid(player.hat_node):
				player.hat_node.visible = true
		HAT_TOPHAT:
			if is_instance_valid(player.hat_tophat_node):
				player.hat_tophat_node.visible = true
		# HAT_NONE: both are already hidden


func _apply_weapon(index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.weapon_node):
		return
	
	player.weapon_node.visible = (index == 1)


func _on_hat_slot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect: Rect2 = hat_slot.get_global_rect()
		hat_popup.popup(Rect2i(rect.position, rect.size))


func _on_weapon_slot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect: Rect2 = weapon_slot.get_global_rect()
		weapon_popup.popup(Rect2i(rect.position, rect.size))


func _on_save_pressed() -> void:
	# Simpan pilihan ke GameManager agar terbawa ke scene game
	var gm = get_node("/root/GameManager")
	if gm:
		gm.selected_hat = current_hat_index
		gm.selected_weapon = current_weapon_index
	print("Karakter disimpan: ", HATS[current_hat_index]["name"], ", ", WEAPONS[current_weapon_index]["name"])
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
