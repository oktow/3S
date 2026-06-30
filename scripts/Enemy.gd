extends StaticBody3D

const MAX_HEALTH: int = 100
var health: int = MAX_HEALTH

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var health_label: Label3D = $HealthLabel

var material: StandardMaterial3D


func _ready() -> void:
	add_to_group("enemy")
	material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.8, 0.8)
	mesh_instance.material_override = material
	_update_label()


func take_damage(amount: int, attacker_id: int) -> void:
	if health <= 0:
		return

	health = max(0, health - amount)
	_update_label()
	_flash_hit()

	if health <= 0:
		_die()


func _flash_hit() -> void:
	material.albedo_color = Color.RED
	await get_tree().create_timer(0.1).timeout
	if not is_inside_tree():
		return
	material.albedo_color = Color(0.8, 0.8, 0.8)


func _update_label() -> void:
	if health_label:
		health_label.text = "Enemy: %d/100 HP" % health


func _die() -> void:
	hide()
	health_label.visible = false
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	health = MAX_HEALTH
	show()
	health_label.visible = true
	_update_label()
