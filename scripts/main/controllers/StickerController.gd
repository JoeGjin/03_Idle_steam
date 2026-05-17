extends Node
class_name StickerController



#    同时对应world id     0        1        2    
# enum StickerTag { MYSTERIOUS, BARREN, VIBRANT } # 贴图标签枚举

var sticker_by_tag: Dictionary = {} # 根据 TAG 分类的贴图列表，格式为 { tag: [sticker_key1, sticker_key2, ...], ... }

const TAG_BY_STICKER: Dictionary = {
	"0_far_0": [StickerTags.StickerTag.MYSTERIOUS],
	"0_far_1": [StickerTags.StickerTag.MYSTERIOUS],
	"0_far_2": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_front_1": [StickerTags.StickerTag.VIBRANT, StickerTags.StickerTag.MYSTERIOUS],
	"0_front_2": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_mid_0": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_mid_1": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_mid_2": [StickerTags.StickerTag.MYSTERIOUS],

	"1_far_0": [StickerTags.StickerTag.BARREN],
	"1_far_2": [StickerTags.StickerTag.BARREN],
	"1_front_0": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"1_front_1": [StickerTags.StickerTag.BARREN],
	"1_front_2": [StickerTags.StickerTag.BARREN],
	"1_mid_0": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"1_mid_1": [StickerTags.StickerTag.BARREN],
	"1_mid_2": [StickerTags.StickerTag.BARREN],

	"2_far_1": [StickerTags.StickerTag.VIBRANT],
	"2_far_2": [StickerTags.StickerTag.VIBRANT],
	"2_front_0": [StickerTags.StickerTag.VIBRANT, StickerTags.StickerTag.MYSTERIOUS],
	"2_front_1": [StickerTags.StickerTag.VIBRANT],
	"2_mid_1": [StickerTags.StickerTag.VIBRANT, StickerTags.StickerTag.BARREN],
	"2_mid_2":  [StickerTags.StickerTag.VIBRANT],
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
