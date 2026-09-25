extends SceneTree
## Loads every script, scene, and resource under src to catch broken dependencies.

var _checked: int = 0
var _failed: int = 0


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void: push_error("RESOURCE TIMEOUT"); quit(2))
	call_deferred("_run")


func _run() -> void:
	_scan("res://src")
	if _failed > 0:
		push_error("RESOURCE FAIL: %d of %d files failed to load" % [_failed, _checked])
		quit(1)
		return
	print("RESOURCE PASS: %d scripts, scenes, and resources loaded" % _checked)
	quit(0)


func _scan(directory_path: String) -> void:
	var directory := DirAccess.open(ProjectSettings.globalize_path(directory_path))
	if directory == null:
		push_error("Could not open " + directory_path)
		_failed += 1
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan(path)
		elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
			_checked += 1
			var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			var invalid_script := false
			if resource is Script and not resource.is_abstract():
				invalid_script = not resource.can_instantiate()
			if resource == null or invalid_script:
				push_error("Could not load " + path)
				_failed += 1
		entry = directory.get_next()
	directory.list_dir_end()
