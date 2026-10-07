class_name SafeConfig
extends RefCounted

## SafeConfig (calidad-13): crash-safe ConfigFile IO shared by SaveManager and
## SettingsManager.
## save(): write `path.tmp`, copy the current file to `path.bak`, then rename the
## tmp over `path` — a crash mid-write never leaves a half-written save.
## load_into(): `path`, else `path.bak` (restored over `path`); an unreadable
## `path` is renamed to `path.corrupt` (never overwritten) so it can be reported.

enum Status { OK, MISSING, RESTORED, CORRUPT }


static func save(cfg: ConfigFile, path: String) -> Error:
	var tmp := path + ".tmp"
	var err := cfg.save(tmp)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		return err
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
		DirAccess.remove_absolute(path)  # rename does not replace on every platform
	return DirAccess.rename_absolute(tmp, path)


static func load_into(cfg: ConfigFile, path: String) -> Status:
	var bak := path + ".bak"
	var has_main := FileAccess.file_exists(path)
	if has_main and cfg.load(path) == OK:
		return Status.OK
	var tmp := path + ".tmp"
	if not has_main and FileAccess.file_exists(tmp) and cfg.load(tmp) == OK:
		DirAccess.rename_absolute(tmp, path)  # crashed between remove and rename: tmp is complete
		return Status.OK
	if not has_main and not FileAccess.file_exists(bak):
		return Status.MISSING
	if has_main:
		DirAccess.remove_absolute(path + ".corrupt")
		DirAccess.rename_absolute(path, path + ".corrupt")
	cfg.clear()
	if FileAccess.file_exists(bak) and cfg.load(bak) == OK:
		DirAccess.copy_absolute(bak, path)
		return Status.RESTORED
	cfg.clear()
	return Status.CORRUPT


## Removes `path` and its .tmp/.bak/.corrupt siblings; true if anything existed.
static func remove(path: String) -> bool:
	var any := false
	for p in [path, path + ".tmp", path + ".bak", path + ".corrupt"]:
		if FileAccess.file_exists(p):
			any = true
			DirAccess.remove_absolute(p)
	return any
