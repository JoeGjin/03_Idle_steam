extends Node
class_name StickerController



#    同时对应world id     0        1        2    
# enum StickerTag { MYSTERIOUS, BARREN, VIBRANT } # 贴图标签枚举

@export var sticker_popup_pool: Array[Texture2D] = []

var sticker_by_tag: Dictionary = {} # 根据 TAG 分类的贴图列表，格式为 { tag: [sticker_key1, sticker_key2, ...], ... }

const TAG_BY_STICKER: Dictionary = {
    "0_far_0": [StickerTags.StickerTag.MYSTERIOUS],
    "0_far_1": [StickerTags.StickerTag.MYSTERIOUS],
    "0_far_2": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
    "0_front_1": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.VIBRANT],
    "0_front_2": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
    "0_mid_0": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
    "0_mid_1": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
    "0_mid_2": [StickerTags.StickerTag.MYSTERIOUS],

    "1_far_0": [StickerTags.StickerTag.BARREN],
    "1_far_2": [StickerTags.StickerTag.BARREN],
    "1_front_0": [StickerTags.StickerTag.BARREN, StickerTags.StickerTag.MYSTERIOUS],
    "1_front_1": [StickerTags.StickerTag.BARREN],
    "1_front_2": [StickerTags.StickerTag.BARREN],
    "1_mid_0": [StickerTags.StickerTag.BARREN, StickerTags.StickerTag.MYSTERIOUS],
    "1_mid_1": [StickerTags.StickerTag.BARREN],
    "1_mid_2": [StickerTags.StickerTag.BARREN],

    "2_far_1": [StickerTags.StickerTag.VIBRANT],
    "2_far_2": [StickerTags.StickerTag.VIBRANT],
    "2_front_0": [StickerTags.StickerTag.VIBRANT, StickerTags.StickerTag.MYSTERIOUS],
    "2_front_1": [StickerTags.StickerTag.VIBRANT],
    "2_mid_1": [StickerTags.StickerTag.VIBRANT, StickerTags.StickerTag.BARREN],
    "2_mid_2":  [StickerTags.StickerTag.VIBRANT],
    }





func tag_calculation(items: Array[String]) -> Dictionary:
    # var result := {
    #     "target_world_id": -1, # 目标世界ID，默认为-1表示未指定
    #     "sub_world_id": -1, # 可选的子世界ID，默认为-1表示未指定
    #     "sub_world_weight": 0.0 # 可选的子世界权重，范围0.0-1.0，默认为0.0表示未指定
    # }

    # 0. 处理标签计算结果，决定发送到哪个世界
    var tag_calc: Dictionary = {} # 贴图标签计数，格式为 { tag: count, ... }
    for item in items:
        # 更新标签计数
        if item == "":
            continue # 跳过空字符串，避免处理未选择的 memory slot
        var item_name_parts: Array = str(item).split("_")
        var sticker_key: String = "_".join(item_name_parts.slice(0, 3))
        var tags: Array = sticker_to_tag(sticker_key)
        for tag in tags:
            if not tag_calc.has(tag):
                tag_calc[tag] = 0
            tag_calc[tag] += 1

    # 1. 得到 tag 的总数 tags_total from tag_calc
    var tags_total: int = 0
    for tag in tag_calc:
        tags_total += tag_calc[tag]
    # 2. 根据 tag_calc 和 tags_total 计算每个 tag 的占比，并乘以对应权重，得到一个 weight
    var world_scores: Dictionary[int, float] = {} # world_id -> weight
    for tag in tag_calc:
        var count: int = tag_calc[tag]
        world_scores[tag] = float(count) / float(tags_total) # 这里假设 tag 的数值就是对应世界的权重，实际可以根据设计调整
    # 3. 根据计算得到的 weight 决定 target_world_id（最高weight），sub_world_id（次高weight）和 sub_world_weight（次高weight占比）
   
    var result := _get_top_two_worlds(world_scores)
    return result


func _get_top_two_worlds(world_scores: Dictionary[int, float]) -> Dictionary:
    var target_world_id_t := -1
    var target_world_weight := -INF
    
    var sub_world_id_t := -1
    var sub_world_weight_t := -INF
    
    for world_id: int in world_scores:
        var weight: float = world_scores[world_id]
        
        if weight > target_world_weight:
            sub_world_id_t = target_world_id_t
            sub_world_weight_t = target_world_weight
            
            target_world_id_t = world_id
            target_world_weight = weight
        
        elif weight > sub_world_weight_t:
            sub_world_id_t = world_id
            sub_world_weight_t = weight
    
    return {
        "target_world_id": target_world_id_t,
        "sub_world_id": sub_world_id_t,
        "sub_world_weight": sub_world_weight_t,
    }




func sticker_to_tag(sticker_key: String) -> Array:
    if TAG_BY_STICKER.has(sticker_key):
        return TAG_BY_STICKER[sticker_key]
    else:
        return [] # 返回空数组表示没有标签


func tag_to_stickers(tag: int) -> Array:
    if sticker_by_tag.has(tag):
        return sticker_by_tag[tag]
    else:
        return [] # 返回空数组表示没有贴图





func _ready() -> void:
    _build_stickers_by_tag()


func _build_stickers_by_tag() -> void:
    sticker_by_tag.clear()
    
    for sticker_key in TAG_BY_STICKER:
        var tags: Array = TAG_BY_STICKER[sticker_key]
        
        for tag in tags:
            if not sticker_by_tag.has(tag):
                sticker_by_tag[tag] = []
            
            sticker_by_tag[tag].append(sticker_key)
