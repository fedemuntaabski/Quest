extends SceneTree

## The one test runner: every tests/test_*.gd in its own headless process, a line
## per test, exit code = number of failures. tools/run_tests.ps1/.sh call this.
##   godot --headless --path . --script res://tests/run_all.gd [-- <name filter>]
## OK  = exit code 0.
## OK* = the test printed its "test_x: OK (" line but the process then crashed on exit
##       (Godot 4.6.2 sometimes segfaults on shutdown): the assertions passed.
## Output of each test: user://test_logs/<test>.log (path printed at the end).

const LOG_DIR := "user://test_logs"


func _initialize() -> void:
	var filter: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var failed: Array[String] = []
	var start := Time.get_ticks_msec()
	var names := DirAccess.get_files_at("res://tests")
	names.sort()
	var ran := 0
	for file in names:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or (filter != "" and filter not in file):
			continue
		ran += 1
		var status := _run(file)
		print("%s %s" % [status, file.get_basename()])
		if status == "FAIL":
			failed.append(file.get_basename())
	print("--- %d test(s), %d fallo(s) en %d s. Logs en %s" % [ran, failed.size(), (Time.get_ticks_msec() - start) / 1000, ProjectSettings.globalize_path(LOG_DIR)])
	quit(failed.size() if ran > 0 else 1)  # nothing ran is not a pass


func _run(file: String) -> String:
	var output := []
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/%s" % file])
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = output[0] if not output.is_empty() else ""
	var log_file := FileAccess.open("%s/%s.log" % [LOG_DIR, file.get_basename()], FileAccess.WRITE)
	if log_file:
		log_file.store_string(text)
	if code == 0:
		return "OK  "
	# Its own closing line: logs print ": OK (" too (RoomManager.validate_graph).
	return "OK* " if "%s: OK (" % file.get_basename() in text else "FAIL"
