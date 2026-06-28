extends Area3D

const SPEED: float = 80.0
const LIFETIME: float = 2.0
const DAMAGE: int = 10

var shooter_id: int
var direction: Vector3
var age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	age += delta
	if age > LIFETIME:
		queue_free()
		return

	position += direction * SPEED * delta


func _on_body_entered(body: Node) -> void:
	_hit(body)


func _on_area_entered(area: Area3D) -> void:
	_hit(area)


func _hit(node: Node) -> void:
	if not node.has_method("take_damage"):
		queue_free()
		return

	if node.get_multiplayer_authority() == shooter_id:
		return

	var target_owner: int = node.get_multiplayer_authority()
	node.take_damage.rpc_id(target_owner, DAMAGE, shooter_id)
	queue_free()
