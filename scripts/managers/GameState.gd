extends Node

# Signal emitted when a diamond is collected
signal diamond_collected

# Current diamond count
var diamond_count = 0

func collect_diamond():
	diamond_count += 1
	diamond_collected.emit()
	print("Diamond collected! Total: ", diamond_count)