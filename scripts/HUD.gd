extends CanvasLayer

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var ammo_label: Label = $VBoxContainer/AmmoLabel
@onready var kill_feed: VBoxContainer = $VBoxContainer/KillFeed
@onready var death_screen: Control = $DeathScreen


func _ready() -> void:
	var player: Node = get_parent()
	if player.has_signal("health_changed"):
		player.health_changed.connect(_update_health)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_update_ammo)
	if player.has_signal("died"):
		player.died.connect(_on_died)
	if player.has_signal("reloading_changed"):
		player.reloading_changed.connect(_on_reloading_changed)


func _update_health(new_health: int) -> void:
	health_label.text = "HP: %d/100" % new_health


func _update_ammo(new_ammo: int) -> void:
	ammo_label.text = "Ammo: %d/30" % new_ammo


func _on_reloading_changed(is_reloading: bool) -> void:
	if is_reloading:
		ammo_label.text = "RELOADING..."
	else:
		var player: Node = get_parent()
		ammo_label.text = "Ammo: %d/30" % player.ammo


func _on_died() -> void:
	death_screen.visible = true
	await get_tree().create_timer(2.0).timeout
	death_screen.visible = false
