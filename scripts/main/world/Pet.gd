extends AnimatedSprite2D


# 贴地采样来源、下沉配置来源与角色胶囊碰撞体。
@onready var _landform_4: ManualParallax = %Landform_4
@onready var _world_assembler: WorldAssembler = %WorldAssembler
@onready var _body_shape: CollisionShape2D = $body/CollisionShape2D

# 悬停状态与贴地跟随参数。
@export var mouse_in_body: bool = false
## 最大垂直跟随速度；调低可减缓地形交接时的升降，调高可更快贴地。
@export_range(1.0, 2000.0, 1.0, "or_greater", "suffix:px/s") var vertical_follow_speed: float = 300.0


# 由场景中 body 的鼠标信号触发，再转发给 Main 等监听者。
signal mouse_entered_body
signal mouse_exited_body


# 本脚本使角色跟随第 4 组地表，并记录和转发身体区域的鼠标悬停变化。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与处理顺序：_ready 将处理顺序放在 Landform_4 滚动之后，避免采样落后一帧。
# 2. 每帧贴地跟随
#    按胶囊最低点的实际世界位置查询地表，加上 pet_ground_sink 后限速修正角色全局高度。
#    没有胶囊形状或对应地表时跳过；节点偏移与当前缩放参与最低点计算。
#    入口：_process；主要参数：vertical_follow_speed 与 WorldAssembler.pet_ground_sink。
# 3. 身体区域鼠标事件
#    更新 mouse_in_body，并发出 mouse_entered_body / mouse_exited_body。
#    入口：_on_body_mouse_entered / _on_body_mouse_exited，已在 Main.tscn 中绑定。


#region 生命周期与处理顺序

func _ready() -> void:
	# 地形完成本帧滚动后再采样，避免高度跟随落后一帧。
	process_priority = _landform_4.process_priority + 1

#endregion


#region 每帧贴地跟随

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

#endregion


#region 身体区域鼠标事件

func _on_body_mouse_exited() -> void:
	mouse_in_body = false
	mouse_exited_body.emit()


func _on_body_mouse_entered() -> void:
	mouse_in_body = true
	mouse_entered_body.emit()

#endregion
