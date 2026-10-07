extends Logger
class_name ErrorProbe

## ErrorProbe (calidad-13): counts every engine/script ERROR and WARNING while
## installed (OS.add_logger), so smoke tests can assert a clean console.
##   var probe := ErrorProbe.install()
##   ... ; probe.uninstall(); expect probe.messages.is_empty()
## `allow` substrings are ignored (expected noise, e.g. Steam not running).

var messages: Array[String] = []
var allow: Array[String] = []
var _mutex := Mutex.new()


static func install(p_allow: Array[String] = []) -> ErrorProbe:
	var probe := ErrorProbe.new()
	probe.allow = p_allow
	OS.add_logger(probe)
	return probe


func uninstall() -> void:
	OS.remove_logger(self)


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind := "WARNING" if error_type == ERROR_TYPE_WARNING else "ERROR"
	var text := "%s: %s %s (%s:%d %s)" % [kind, code, rationale, file, line, function]
	for a in allow:
		if a in text:
			return
	_mutex.lock()
	messages.append(text)
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
