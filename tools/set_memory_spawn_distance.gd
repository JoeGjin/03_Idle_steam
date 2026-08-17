@tool
extends EditorScript

## 按资源名称末尾三位编号，批量修改 Component Memory 的生成距离倍率。
## 在脚本编辑器中修改 SPAWN_DISTANCE_RATIO_RANGES 后，按 Ctrl+Shift+X 手动执行。

const TARGET_DIRECTORY := "res://scripts/main/controllers/memory/defs/component"

# NOTE: Vector2i 的 x 是起始编号、y 是结束编号，匹配时包含起点和终点。
# 例如 Vector2i(100, 105) 会匹配 CP100.tres 至 CP105.tres。
const SPAWN_DISTANCE_RATIO_RANGES: Dictionary[Vector2i, float] = {
	Vector2i(1, 8): 2.0,
	Vector2i(305, 311): 2.0,
    Vector2i(318, 320): 1.5,
	Vector2i(701, 707): 2.5,
    Vector2i(713, 714): 2.5,
}
const UNCONFIGURED_VALUE := -1.0


func _run() -> void:
	if not _validate_ranges():
		return

	var directory := DirAccess.open(TARGET_DIRECTORY)
	if directory == null:
		push_error("无法打开目标目录：%s" % TARGET_DIRECTORY)
		return

	var changed_count := 0
	var unchanged_count := 0
	var unconfigured_count := 0
	var skipped_count := 0
	var failed_count := 0

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "tres":
			var resource_path := TARGET_DIRECTORY.path_join(file_name)
			var resource_number := _get_resource_number(file_name)
			var target_value: float = _get_target_value(resource_number)

			if resource_number < 0:
				skipped_count += 1
				push_warning("资源名称末尾不是三位数字，已跳过：%s" % resource_path)
			elif target_value == UNCONFIGURED_VALUE:
				unconfigured_count += 1
			else:
				var resource := ResourceLoader.load(resource_path)
				var memory_def := resource as MemoryDef

				if memory_def == null:
					skipped_count += 1
					push_warning("跳过非 MemoryDef 资源：%s" % resource_path)
				elif is_equal_approx(memory_def.spawn_distance_ratio, target_value):
					unchanged_count += 1
				else:
					memory_def.spawn_distance_ratio = target_value
					var error := ResourceSaver.save(memory_def, resource_path)
					if error == OK:
						changed_count += 1
					else:
						failed_count += 1
						push_error("保存失败：%s，错误码：%s" % [resource_path, error])

		file_name = directory.get_next()
	directory.list_dir_end()

	print(
		"spawn_distance_ratio 批量修改完成：修改=%d，未变化=%d，未配置=%d，跳过=%d，失败=%d"
		% [changed_count, unchanged_count, unconfigured_count, skipped_count, failed_count]
	)


func _get_resource_number(file_name: String) -> int:
	var number_text := file_name.get_basename().right(3)
	if number_text.length() != 3 or not number_text.is_valid_int():
		return -1

	return number_text.to_int()


func _get_target_value(resource_number: int) -> float:
	for number_range: Vector2i in SPAWN_DISTANCE_RATIO_RANGES:
		if resource_number >= number_range.x and resource_number <= number_range.y:
			return SPAWN_DISTANCE_RATIO_RANGES[number_range]

	return UNCONFIGURED_VALUE


func _validate_ranges() -> bool:
	var ranges: Array[Vector2i] = []

	for number_range: Vector2i in SPAWN_DISTANCE_RATIO_RANGES:
		var target_value := SPAWN_DISTANCE_RATIO_RANGES[number_range]
		if number_range.x > number_range.y:
			push_error("编号范围起点不能大于终点：%s" % number_range)
			return false
		if target_value < 0.0:
			push_error("spawn_distance_ratio 不能小于 0：%s -> %s" % [number_range, target_value])
			return false
		ranges.append(number_range)

	for index in ranges.size():
		for other_index in range(index + 1, ranges.size()):
			var current := ranges[index]
			var other := ranges[other_index]
			if current.x <= other.y and other.x <= current.y:
				push_error("编号范围不能重叠：%s 与 %s" % [current, other])
				return false

	return true
