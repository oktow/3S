extends Control

const HATS := [
	{"name": "Tanpa Topi", "scene": null, "icon": null},
	{"name": "Topi Koboy", "scene": preload("res://assets/3d/cowboyhat.glb"), "icon": null},
]

var current_hat_index: int = 1

@onready var hat_pivot: BoneAttachment3D = $SubViewportContainer/SubViewport/YBot/Armature/Skeleton3D/HatPivot
@onready var hat_slot: Panel = $Panel/VBoxContainer/HatSlot
@onready var hat_icon: TextureRect = $Panel/VBoxContainer/HatSlot/HBoxContainer/HatIcon
@onready var hat_name_label: Label = $Panel/VBoxContainer/HatSlot/HBoxContainer/HatNameLabel
@onready var hat_popup: PopupPanel = $Panel/VBoxContainer/HatPopup
@onready var hat_options: VBoxContainer = $Panel/VBoxContainer/HatPopup/PopupVBox


func _ready() -> void:
	_setup_camera()
	_setup_animation()
	_setup_hat_popup()
	_update_ui()
	_apply_hat(current_hat_index)


func _setup_camera() -> void:
	var cam: Camera3D = $SubViewportContainer/SubViewport/Camera3D
	cam.look_at(Vector3(0, 0.9, 0))


func _setup_animation() -> void:
	var ap: AnimationPlayer = $SubViewportContainer/SubViewport/YBot/AnimationPlayer
	if ap and ap.has_animation("idle"):
		ap.play("idle")


func _setup_hat_popup() -> void:
	for i in HATS.size():
		var btn := Button.new()
		btn.text = HATS[i]["name"]
		btn.pressed.connect(_on_hat_selected.bind(i))
		hat_options.add_child(btn)


func _on_hat_selected(index: int) -> void:
	current_hat_index = index
	hat_popup.hide()
	_update_ui()
	_apply_hat(index)


func _update_ui() -> void:
	hat_name_label.text = HATS[current_hat_index]["name"]
	hat_icon.texture = HATS[current_hat_index]["icon"]


func _apply_hat(index: int) -> void:
	# Clear existing children immediately
	for child in hat_pivot.get_children():
		hat_pivot.remove_child(child)
		child.queue_free()
	
	var scene: PackedScene = HATS[index]["scene"]
	if scene:
		var hat: Node = scene.instantiate()
		hat_pivot.add_child(hat)
		
		# Reset transform
		if hat is Node3D:
			hat.transform = Transform3D.IDENTITY
			# Reset local transform of mesh inside GLB
			for mesh in hat.find_children("*", "MeshInstance3D", true):
				mesh.transform = Transform3D.IDENTITY
		
		print("Hat added to pivot: ", hat.name, " parent: ", hat.get_parent().name)


func _on_hat_slot_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var rect: Rect2 = hat_slot.get_global_rect()
		hat_popup.popup(Rect2i(rect.position, rect.size))


func _on_save_pressed() -> void:
	# Future implementation: save character data
	print("Karakter disimpan: ", HATS[current_hat_index]["name"])
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
