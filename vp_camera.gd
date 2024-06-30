@tool
extends Camera3D
@export var target:Camera3D




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	fov = target.fov
	global_transform = target.global_transform
	
