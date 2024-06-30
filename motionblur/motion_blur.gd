@tool
extends CompositorEffect
class_name MotionBlurBetter

@export_group("Motion Blur", "motion_blur_")
# diminishing returns over 16
@export_range(4, 64) var motion_blur_samples: int = 8
# you really don't want this over 0.5, but you can if you want to try
@export_range(0, 0.5, 0.001, "or_greater") var motion_blur_intensity: float = 0.25
@export_range(0, 1) var motion_blur_center_fade: float = 0.0

var rd: RenderingDevice

var linear_sampler: RID

var motion_blur_shader: RID
var motion_blur_pipeline: RID

var overlay_shader: RID
var overlay_pipeline: RID

var context: StringName = "MotionBlur"
var texture: StringName = "texture"

func _init():
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_motion_vectors = true
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if linear_sampler.is_valid():
			rd.free_rid(linear_sampler)
		if motion_blur_shader.is_valid():
			rd.free_rid(motion_blur_shader)
		if overlay_shader.is_valid():
			rd.free_rid(overlay_shader)

func _initialize_compute():
	rd = RenderingServer.get_rendering_device()
	if !rd:
		return

	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	linear_sampler = rd.sampler_create(sampler_state)

	var shader_file = load("res://motionblur/motion_blur.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	motion_blur_shader = rd.shader_create_from_spirv(shader_spirv)
	motion_blur_pipeline = rd.compute_pipeline_create(motion_blur_shader)

	shader_file = load("res://motionblur/motion_blur_overlay.glsl")
	shader_spirv = shader_file.get_spirv()
	overlay_shader = rd.shader_create_from_spirv(shader_spirv)
	overlay_pipeline = rd.compute_pipeline_create(overlay_shader)

func get_image_uniform(image: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(image)
	return uniform

func get_sampler_uniform(image: RID, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(linear_sampler)
	uniform.add_id(image)
	return uniform

func _render_callback(p_effect_callback_type, p_render_data):
	if rd and p_effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		var render_scene_data: RenderSceneDataRD = p_render_data.get_render_scene_data()
		if render_scene_buffers and render_scene_data:
			var render_size: Vector2 = render_scene_buffers.get_internal_size()
			if render_size.x == 0.0 or render_size.y == 0.0:
				return

			if render_scene_buffers.has_texture(context, texture):
				var tf: RDTextureFormat = render_scene_buffers.get_texture_format(context, texture)
				if tf.width != render_size.x or tf.height != render_size.y:
					render_scene_buffers.clear_context(context)

			if !render_scene_buffers.has_texture(context, texture):
				var usage_bits: int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
				render_scene_buffers.create_texture(context, texture, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage_bits, RenderingDevice.TEXTURE_SAMPLES_1, render_size, 1, 1, true)

			rd.draw_command_begin_label("Motion Blur", Color(1.0, 1.0, 1.0, 1.0))

			var push_constant: PackedFloat32Array = [
				motion_blur_samples, motion_blur_intensity,
				motion_blur_center_fade, 0.0,
			]

			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				var color_image := render_scene_buffers.get_color_layer(view)
				var velocity_image := render_scene_buffers.get_velocity_layer(view)
				var texture_image = render_scene_buffers.get_texture_slice(context, texture, view, 0, 1, 1)
				rd.draw_command_begin_label("Compute blur " + str(view), Color(1.0, 1.0, 1.0, 1.0))

				var tex_uniform_set := UniformSetCacheRD.get_cache(motion_blur_shader, 0, [
					get_sampler_uniform(color_image, 0),
					get_sampler_uniform(velocity_image, 1),
					get_image_uniform(texture_image, 2),
				])

				var x_groups := floori((render_size.x - 1) / 8 + 1)
				var y_groups := floori((render_size.y - 1) / 8 + 1)

				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, motion_blur_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, tex_uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
				rd.compute_list_end()
				rd.draw_command_end_label()

				rd.draw_command_begin_label("Overlay result " + str(view), Color(1.0, 1.0, 1.0, 1.0))

				tex_uniform_set = UniformSetCacheRD.get_cache(overlay_shader, 0, [
					get_sampler_uniform(texture_image, 0),
					get_image_uniform(color_image, 1),
				])

				compute_list = rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, overlay_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, tex_uniform_set, 0)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
				rd.compute_list_end()
				rd.draw_command_end_label()

			rd.draw_command_end_label()
