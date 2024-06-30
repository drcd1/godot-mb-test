#[compute]
#version 450

layout(set = 0, binding = 0) uniform sampler2D color_sampler;
layout(set = 0, binding = 1) uniform sampler2D vector_sampler;
layout(rgba16f, set = 0, binding = 2) uniform writeonly image2D output_image;

layout(push_constant, std430) uniform Params {
	vec2 samples_intensity;
	vec2 fade_padding;
} params;

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
void main() {
	ivec2 render_size = ivec2(textureSize(color_sampler, 0));
	ivec2 uvi = ivec2(gl_GlobalInvocationID.xy);
	if ((uvi.x >= render_size.x) || (uvi.y >= render_size.y)) {
		return;
	}
	vec2 uvn = (vec2(uvi) + 0.5) / render_size;

	int iteration_count = int(params.samples_intensity.x);
	vec2 velocity = textureLod(vector_sampler, uvn, 0.0).xy;
	vec2 sample_step = velocity * params.samples_intensity.y;
	sample_step /= max(1.0, params.samples_intensity.x - 1.0);

	float d = 1.0 - min(1.0, 2.0 * distance(uvn, vec2(0.5)));
	sample_step *= 1.0 - d * params.fade_padding.x;

	vec4 base = textureLod(color_sampler, uvn, 0.0);

	// No motion, early out
	if (length(velocity) <= 0.0001) {
		imageStore(output_image, uvi, base);
		return;
	}

	float total_weight = 1.0;
	vec2 offset = vec2(0.0);
	vec4 col = base;
	for (int i = 1; i < iteration_count; i++) {
		offset += sample_step;
		vec2 uvo = uvn + offset;
		if (any(notEqual(uvo, clamp(uvo, vec2(0.0), vec2(1.0))))) {
			break;
		}

		vec2 step_velocity = textureLod(vector_sampler, uvo, 0.0).xy;
		// Attempt to prevent ghosting caused by surfaces with significantly different velocities
		float sample_weight = clamp(dot(step_velocity, velocity) / dot(velocity, velocity), 0.0, 1.0);
		if (sample_weight <= 0.0) {
			continue;
		}
		total_weight += sample_weight;
		col += textureLod(color_sampler, uvo, 0.0) * sample_weight;
	}

	col /= total_weight;

	imageStore(output_image, uvi, col);
}
