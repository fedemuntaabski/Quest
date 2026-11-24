extends SceneTree

## The one test runner: every tests/test_*.gd in its own headless process, a line
## per test, exit code = number of failures. tools/run_tests.ps1/.sh call this.
##   godot --headless --path . --script res://tests/run_all.gd [-- [<name filter>] [-j N]]
## Runs N processes at a time (default 6, -j 1 = one by one), slowest first (times of the
## last run in user://test_logs/times.cfg; a test with no time yet goes first).
## OK  = exit code 0.
## OK* = the test printed its "test_x: OK (" line but the process then crashed on exit
##       (Godot 4.6.2 sometimes segfaults on shutdown): the assertions passed.
## Output of each test: user://test_logs/<test>.log (Godot --log-file, path printed at the end).
## Tests run side by side: each one that writes user:// uses its own file (save slot, port).

const LOG_DIR := "user://test_logs"
const TIMES := "user://test_logs/times.cfg"
const DEFAULT_JOBS := 6


func _initialize() -> void:
	var filter := ""
	var jobs := DEFAULT_JOBS
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a == "-j" and i + 1 < args.size():
			i += 1
			jobs = maxi(1, args[i].to_int())
		elif a.begins_with("-j") and a.substr(2).is_valid_int():
			jobs = maxi(1, a.substr(2).to_int())
		elif a != "":
			filter = a
		i += 1
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var times := ConfigFile.new()
	times.load(TIMES)
	var queue: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd") and (filter == "" or filter in file):
			queue.append(file.get_basename())
	queue.sort_custom(func(a: String, b: String) -> bool:
		var ta: float = times.get_value("s", a, INF)
		var tb: float = times.get_value("s", b, INF)
		return ta > tb if ta != tb else a < b)
	var start := Time.get_ticks_msec()
	var running := {}  # pid -> [name, start msec]
	var failed: Array[String] = []
	var ran := queue.size()
	while not queue.is_empty() or not running.is_empty():
		while not queue.is_empty() and running.size() < jobs:
			var test_name: String = queue.pop_front()
			var pid := _launch(test_name)
			if pid < 0:
				print("FAIL %s (no arrancó)" % test_name)
				failed.append(test_name)
			else:
				running[pid] = [test_name, Time.get_ticks_msec()]
		OS.delay_msec(50)
		for pid: int in running.keys():
			if OS.is_process_running(pid):
				continue
			var test_name: String = running[pid][0]
			var secs: float = (Time.get_ticks_msec() - int(running[pid][1])) / 1000.0
			running.erase(pid)
			times.set_value("s", test_name, snappedf(secs, 0.1))
			var status := _status(test_name, OS.get_process_exit_code(pid))
			print("%s %s (%d s)" % [status, test_name, roundi(secs)])
			if status == "FAIL":
				failed.append(test_name)
	times.save(TIMES)
	failed.sort()
	if not failed.is_empty():
		print("Fallaron: %s" % ", ".join(failed))
	print("--- %d test(s), %d fallo(s) en %d s (de a %d). Logs en %s" % [ran, failed.size(), (Time.get_ticks_msec() - start) / 1000, jobs, ProjectSettings.globalize_path(LOG_DIR)])
	quit(failed.size() if ran > 0 else 1)  # nothing ran is not a pass


func _log_path(test_name: String) -> String:
	return ProjectSettings.globalize_path("%s/%s.log" % [LOG_DIR, test_name])


func _launch(test_name: String) -> int:
	var log_path := _log_path(test_name)
	DirAccess.remove_absolute(log_path)  # no old file: Godot would rotate it into a dated copy
	return OS.create_process(OS.get_executable_path(), PackedStringArray(["--headless", "--log-file", log_path,
		"--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/%s.gd" % test_name]))


func _status(test_name: String, code: int) -> String:
	if code == 0:
		return "OK  "
	# Its own closing line: logs print ": OK (" too (RoomManager.validate_graph).
	var text := FileAccess.get_file_as_string(_log_path(test_name))
	return "OK* " if "%s: OK (" % test_name in text else "FAIL"
