extends Control


# 收藏册与明信片展示区域，由本脚本协调显隐。
@onready var collection_book: Control = %CollectionBook
@onready var postcard_showing: Control = %PostcardShowing


# 本脚本管理收藏册与明信片展示区域之间的切换。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与默认界面：_ready 显示收藏册，隐藏明信片展示区域。
# 2. 明信片展示与返回：play_receive_postcard 切换区域并请求展示明信片。
#    PostcardShowing 发出 postcard_showed 后，通过 Main.tscn 中已有的信号连接回到收藏册。
#    入口：play_receive_postcard / _on_postcard_showing_postcard_showed


#region 生命周期与默认界面

func _ready():
    collection_book.show()
    postcard_showing.hide()

#endregion


#region 明信片展示与返回

func play_receive_postcard():
    collection_book.hide()
    postcard_showing.show()
    postcard_showing.show_postcard()


func _on_postcard_showing_postcard_showed() -> void:
    postcard_showing.hide()
    collection_book.show()

#endregion
