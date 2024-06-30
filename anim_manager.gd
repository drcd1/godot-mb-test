extends Node

@export var record_specific:bool=false
@export var prev= 8.8
@export var next= 9.0
@export var steps = 5
@export var env:WorldEnvironment
@export var output_file:String="out.exr"
@export var ground_truth_file:String="gt.exr"
@export var shutter_open:Vector2=Vector2(0.0,1.0)
@export var exposure_curve:Curve

var time = 0.0
var started_capture = false

@onready var svp:SubViewport = get_node("../SubViewport")

var player:AnimationPlayer;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_node("../mbtest/AnimationPlayer")
	player.play("Animation")
	player.pause()
	started_capture = false


func capture_current():
	player.seek(prev,true);
	await get_tree().process_frame
	player.seek(next,true);
	await get_tree().process_frame
	var image =  svp.get_texture().get_image()	
	image.save_exr(output_file)
	

func acc_texture(dst:Image,src:Image,factor:float):
	for i in range(src.get_width()):
		for j in range(src.get_height()):
			var help = dst.get_pixel(i,j)+src.get_pixel(i,j)*factor
			dst.set_pixel(i,j,help)
	
	

func capture_ground_truth():
	await get_tree().process_frame
	env.compositor.compositor_effects[0].enabled = false
	
	var factor = 1.0/(steps-1);
	var vt = svp.get_texture();
	var viewport_dims = Vector2i(vt.get_width(),vt.get_height())
	print(viewport_dims)
	var dst_img = Image.create(viewport_dims.x,viewport_dims.y,false,Image.FORMAT_RGBH)
	dst_img.fill(Color(0.,0.,0.,1.0))
	
	var sum = 0.0
	#todo: it would be better to importance
	# sample the curve
	for i in range(steps):
		var t = float(i)*factor
		sum+=exposure_curve.sample(t);
	
	for i in range(steps):
		var t = (float(i)*factor)*(shutter_open.y-shutter_open.x) + shutter_open.x;
		var time = prev+(next-prev)*t
		
		player.seek(prev+(next-prev)*t,true);
		await get_tree().process_frame
		var image_texture = svp.get_texture()
		acc_texture(dst_img,image_texture.get_image(),exposure_curve.sample(t)/sum)
	dst_img.save_exr(ground_truth_file)
	print("saved Image")
	
	env.compositor.compositor_effects[0].enabled = true
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not record_specific:
		player.seek(time,true)
		#time+=delta
	time+=delta
	#give a bit of time to initialize GI
	if record_specific && time>1.0:
		if not started_capture:
			started_capture = true
			await capture_current()
			await capture_ground_truth()
			
		
