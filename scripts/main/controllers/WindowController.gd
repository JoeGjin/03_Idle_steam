# 本脚为窗口裁剪控制器

extends Node
class_name WindowController

@export var target:Node2D # not used currently, reserved for future use
@export var frame:Polygon2D
@export var world_root: Node2D


func update_crop_to_frame() -> void:
	var win := get_window()
	# 1) frame polygon -> window(viewport) coords
	var bbox := _polygon_bbox_in_window_space(frame)
	if bbox.size.x <= 1.0 or bbox.size.y <= 1.0:
		return
	# 2) Move content so bbox top-left becomes (0,0) in the new window
	world_root.position -= bbox.position
	# 3) Resize/move window: screen_pos += bbox.position, size = bbox.size
	# win.position is screen coordinates for the main window ([Window docs](https://docs.godotengine.org/en/stable/classes/class_window.html))
	win.position = win.position + Vector2i(bbox.position)
	win.size = Vector2i(bbox.size)

static func _polygon_bbox_in_window_space(poly: Polygon2D) -> Rect2:
	var pts := poly.polygon
	if pts.is_empty():
		return Rect2(Vector2.ZERO, Vector2.ZERO)
	var p0 := poly.to_global(pts[0])
	var min_v := p0
	var max_v := p0
	for i in range(1, pts.size()):
		var p := poly.to_global(pts[i])
		min_v = min_v.min(p)
		max_v = max_v.max(p)
	return Rect2(min_v, max_v - min_v)

