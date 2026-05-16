extends Node
class_name StickerController



#                     0        1        2    
# enum StickerTag { VIBRANT, BARREN, MYSTERIOUS} # 贴图标签枚举

var TAG_BY_STICKER: Dictionary = {
	"0_far_0": [StickerTags.StickerTag.MYSTERIOUS],
	"0_far_1": [StickerTags.StickerTag.MYSTERIOUS],
	"0_far_2": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_front_1": [StickerTags.StickerTag.VIBRANT, StickerTags.StickerTag.MYSTERIOUS],
	"0_front_2": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_mid_0": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_mid_1": [StickerTags.StickerTag.MYSTERIOUS, StickerTags.StickerTag.BARREN],
	"0_mid_2": [StickerTags.StickerTag.MYSTERIOUS],
	}

var stickers_by_tag: Dictionary = {} # 根据 TAG 分类的贴图列表，格式为 { tag: [sticker_key1, sticker_key2, ...], ... }



func _ready() -> void:
	_build_stickers_by_tag()


func _build_stickers_by_tag() -> void:
	stickers_by_tag.clear()
	
	for sticker_key in TAG_BY_STICKER:
		var tags: Array = TAG_BY_STICKER[sticker_key]
		
		for tag in tags:
			if not stickers_by_tag.has(tag):
				stickers_by_tag[tag] = []
			
			stickers_by_tag[tag].append(sticker_key)
