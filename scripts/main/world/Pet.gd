extends AnimatedSprite2D


@onready var _landform_4: ManualParallax = %Landform_4
@onready var _world_assembler: WorldAssembler = %WorldAssembler
@onready var _body_shape: CollisionShape2D = $body/CollisionShape2D

@export var mouse_in_body: bool = false
## 最大垂直跟随速度；调低可减缓地形交接时的升降，调高可更快贴地。
@export_range(1.0, 2000.0, 1.0, "or_greater", "suffix:px/s") var vertical_follow_speed: float = 300.0


signal mouse_entered_body
signal mouse_exited_body



func _ready() -> void:
	# 地形完成本帧滚动后再采样，避免高度跟随落后一帧。
	process_priority = _landform_4.process_priority + 1


func _process(delta: float) -> void:
	var capsule := _body_shape.shape as CapsuleShape2D
	if capsule == null:
		return

	# 使用碰撞体最低点的实际位置，让节点偏移与当前 Pet 缩放一并生效。
	var body_bottom := _body_shape.to_global(Vector2(0.0, capsule.height * 0.5))
	var ground_y: Variant = _landform_4.get_ground_y(body_bottom.x)
	if ground_y == null:
		return

	# 小起伏直接贴合，大高度差按帧时间限速过渡，避免地形交接时瞬移。
	var target_bottom_y := float(ground_y) + _world_assembler.pet_ground_sink
	var target_y := global_position.y + target_bottom_y - body_bottom.y
	global_position.y = move_toward(global_position.y, target_y, vertical_follow_speed * delta)


func _on_body_mouse_exited() -> void:
	mouse_in_body = false
	mouse_exited_body.emit()


func _on_body_mouse_entered() -> void:
	mouse_in_body = true
	mouse_entered_body.emit()


