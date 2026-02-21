# 角色状态定义资源

extends Resource
class_name CharacterStateDef

## 角色状态定义资源，包含状态枚举、持续时间、优先级等信息
@export var state: CharacterStates.CharacterState = CharacterStates.CharacterState.RESTING
    
## 状态之间的间隔时间，单位秒，0 表示没有间隔
@export var gap: float = 0.0

## 持续时间，单位秒，0 表示不占用 active 或瞬时
@export var duration: float = 0.0

@export var priority: int = 0
@export var can_interrupt: bool = true