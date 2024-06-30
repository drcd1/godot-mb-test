extends Camera3D

@export var decay: float=1.0
@export var rot_decay: float=1.0
@export var vel_scale: float=1.0
@export var rot_scale: float = 1.0

var rot = Vector2(0.0,0.0)
var rot_vel = Vector2(0.0,0.0)
var vel = Vector3(0.0,0.0,0.0)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var tv= Vector3(0.0,0.0,0.0);
	tv.z-=Input.get_axis("backward","forward")
	tv.x+=Input.get_axis("left","right")
	
	var rd = Vector2(0.0,0.0);
	rd.y = Input.get_axis("rot_down","rot_up")
	rd.x = Input.get_axis("rot_left","rot_right")
	
	var t = 1.0-exp(-delta*rot_decay)
	rot_vel = rot_vel*(1.0-t)+rd*t*rot_scale
	rot=rot+rot_vel*delta;
	
	t = 1.0-exp(-delta*decay)
	vel = vel*(1.0-t)+tv*vel_scale*t
	
	transform.basis = Basis()
	rotate(Vector3(1,0,0),rot.y);
	rotate(Vector3(0,-1,0),rot.x);
	transform.origin = transform.origin + transform.basis*vel*delta;
	
	
