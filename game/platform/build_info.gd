class_name BuildInfo
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "res://assets/build/build_info.json"
const RELEASE_PLATFORMS := ["windows", "linux", "android", "ios"]
const CONFIGURATIONS := ["release", "debug"]


static func development_info() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"commit": "dev",
		"commit_short": "dev",
		"platform": "editor-%s" % OS.get_name().to_lower(),
		"configuration": "development",
		"built_at_utc": "",
		"dirty": true,
		"embedded": false,
	}


static func load_current(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return development_info()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return development_info()
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return sanitize(parsed)


static func sanitize(value: Variant) -> Dictionary:
	var fallback := development_info()
	if not value is Dictionary:
		return fallback
	var data: Dictionary = value
	var version := str(data.get("version", "")).strip_edges()
	var commit := str(data.get("commit", "")).strip_edges().to_lower()
	var commit_short := str(data.get("commit_short", "")).strip_edges().to_lower()
	var platform := str(data.get("platform", "")).strip_edges().to_lower()
	var configuration := str(data.get("configuration", "")).strip_edges().to_lower()
	var built_at_utc := str(data.get("built_at_utc", "")).strip_edges()
	if (
		int(data.get("schema_version", 0)) != SCHEMA_VERSION
		or version.is_empty()
		or not _is_hex_commit(commit)
		or commit_short.length() != 7
		or commit_short != commit.left(7)
		or platform not in RELEASE_PLATFORMS
		or configuration not in CONFIGURATIONS
		or built_at_utc.is_empty()
		or typeof(data.get("dirty", false)) != TYPE_BOOL
	):
		return fallback
	return {
		"schema_version": SCHEMA_VERSION,
		"version": version,
		"commit": commit,
		"commit_short": commit_short,
		"platform": platform,
		"configuration": configuration,
		"built_at_utc": built_at_utc,
		"dirty": data.dirty,
		"embedded": true,
	}


static func _is_hex_commit(value: String) -> bool:
	if value.length() < 7 or value.length() > 40:
		return false
	for index in range(value.length()):
		if not "0123456789abcdef".contains(value[index]):
			return false
	return true


static func display_label(info: Dictionary) -> String:
	var dirty_suffix := "*" if bool(info.get("dirty", false)) else ""
	var configuration_suffix := " · DEBUG" if info.get("configuration", "") == "debug" else ""
	return "v%s · %s · %s%s%s" % [
		info.get("version", "0.0.0"),
		str(info.get("platform", "unknown")).to_upper(),
		info.get("commit_short", "unknown"),
		dirty_suffix,
		configuration_suffix,
	]
