extends Control


# 手册图层与明信片展示区域，由本脚本协调显隐；旧收藏册保留但始终隐藏。
@onready var hand_book: Control = %HandBook
@onready var layer_cover: Control = $HandBook/LayerCover
@onready var layer_setting: Control = $HandBook/LayerSetting
@onready var layer_collection: Control = $HandBook/LayerCollection
@onready var tab1: TextureButton = $HandBook/Tab1
@onready var tab2: TextureButton = $HandBook/Tab2
@onready var tab3: TextureButton = $HandBook/Tab3
@onready var collection_book: Control = %CollectionBook
@onready var postcard_showing: Control = %PostcardShowing


# 本脚本管理手册封面、设置页、收藏页与明信片展示区域之间的切换，旧收藏册始终隐藏。
#
# 目录（与下方代码分区顺序一致）
# 1. 生命周期与默认界面：_ready 连接三个 Tab 的 pressed 信号，默认打开手册设置页。
# 2. 手册页面切换：Tab1 只显示封面，Tab2 叠加设置页，Tab3 再叠加收藏页。
#    Main 的设置、收藏入口分别沿用 Tab2、Tab3 的显隐规则。
#    入口：show_cover_page / show_setting_page / show_collection_page；核心：_show_handbook_page
# 3. 明信片展示与返回：play_receive_postcard 临时隐藏手册并请求展示明信片。
#    PostcardShowing 发出 postcard_showed 后，通过 Main.tscn 中已有的信号连接返回当前手册页。
#    入口：play_receive_postcard / _on_postcard_showing_postcard_showed


#region 生命周期与默认界面

func _ready():
    tab1.pressed.connect(show_cover_page)
    tab2.pressed.connect(show_setting_page)
    tab3.pressed.connect(show_collection_page)
    show_setting_page()

#endregion


#region 手册页面切换

func show_cover_page() -> void:
    _show_handbook_page(false, false)


func show_setting_page() -> void:
    _show_handbook_page(true, false)


func show_collection_page() -> void:
    _show_handbook_page(true, true)


func _show_handbook_page(show_settings: bool, show_collection: bool) -> void:
    collection_book.hide()
    postcard_showing.hide()
    hand_book.show()
    layer_cover.show()
    layer_setting.visible = show_settings
    layer_collection.visible = show_collection

#endregion


#region 明信片展示与返回

func play_receive_postcard():
    collection_book.hide()
    hand_book.hide()
    postcard_showing.show()
    postcard_showing.show_postcard()


func _on_postcard_showing_postcard_showed() -> void:
    # 手册隐藏期间保留了子图层自身的 visible，返回时恢复原来的图层组合。
    _show_handbook_page(layer_setting.visible, layer_collection.visible)

#endregion
