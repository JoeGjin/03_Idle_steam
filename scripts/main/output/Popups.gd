extends HBoxContainer

@onready var sticker_controller: StickerController = %StickerController
@onready var b1: TextureButton = $"1/1"
@onready var b2: TextureButton = $"2/2"

signal memory_chose(chosen: String, unchosen: String) # 选择了哪个记忆，参数为被选择的贴图key和未被选择的贴图key


func popup():
	var pool := sticker_controller.sticker_popup_pool
	var i := randi() % pool.size()
	b1.texture_normal = pool[i]
	b2.texture_normal = pool[(i + 1 + randi() % (pool.size() - 1)) % pool.size()]   
	show()


func _ready() -> void:
	# hide() # 初始状态隐藏，等需要显示时再调用 show()
	popup()


func _on_1_pressed() -> void:
	emit_signal("memory_chose", b1.texture_normal.resource_path.get_file().get_basename(), b2.texture_normal.resource_path.get_file().get_basename())
	hide()


func _on_2_pressed() -> void:
	emit_signal("memory_chose", b2.texture_normal.resource_path.get_file().get_basename(), b1.texture_normal.resource_path.get_file().get_basename())
	hide()
