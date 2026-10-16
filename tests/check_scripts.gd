extends Node
## Loads every script so parse errors surface (autoloads available).
## Run: godot --headless --path . res://tests/check.tscn

func _ready() -> void:
	var bad := 0
	for path in _scan("res://scripts"):
		var s = load(path)
		if s == null or not s.can_instantiate():
			print("BROKEN: ", path)
			bad += 1
	print("checked scripts, broken: ", bad)
	get_tree().quit(1 if bad > 0 else 0)

func _scan(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _scan(dir + "/" + sub)
	return out
