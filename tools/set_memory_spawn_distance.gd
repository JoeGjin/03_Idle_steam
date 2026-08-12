@tool
extends EditorScript

## 批量修改 Component Memory 资源的生成距离倍率。
## 在脚本编辑器中修改 TARGET_VALUE 后，按 Ctrl+Shift+X 手动执行。

const TARGET_DIRECTORY := "res://scripts/main/controllers/memory/defs/component"
const TARGET_VALUE: float = 1.5


func _run() -> void:
	if TARGET_VALUE < 0.0:
		push_error("spawn_distance_ratio 不能小于 0，当前值：%s" % TARGET_VALUE)
		return

	var directory := DirAccess.open(TARGET_DIRECTORY)
	if directory == null:
		push_error("无法打开目标目录：%s" % TARGET_DIRECTORY)
		return

	var changed_count := 0
	var unchanged_count := 0
	var skipped_count := 0
	var failed_count := 0

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.get_extension().to_lower() == "tres":
			var resource_path := TARGET_DIRECTORY.path_join(file_name)
			var resource := ResourceLoader.load(resource_path)
			var memory_def := resource as MemoryDef

			if memory_def == null:
				skipped_count += 1
				push_warning("跳过非 MemoryDef 资源：%s" % resource_path)
			elif is_equal_approx(memory_def.spawn_distance_ratio, TARGET_VALUE):
				unchanged_count += 1
			else:
				memory_def.spawn_distance_ratio = TARGET_VALUE
				var error := ResourceSaver.save(memory_def, resource_path)
				if error == OK:
					changed_count += 1
				else:
					failed_count += 1
					push_error("保存失败：%s，错误码：%s" % [resource_path, error])

		file_name = directory.get_next()
	directory.list_dir_end()

	print(
		"spawn_distance_ratio 批量修改完成：目标值=%s，修改=%d，未变化=%d，跳过=%d，失败=%d"
		% [TARGET_VALUE, changed_count, unchanged_count, skipped_count, failed_count]
	)
