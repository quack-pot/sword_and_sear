shader_type spatial;

global uniform vec3 player_position;
global uniform vec3 camera_position;
global uniform vec3 camera_forward;

group_uniforms surface;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform sampler2D texture_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

uniform float specular : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D texture_ao : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;

uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);

group_uniforms cutout;
uniform bool orthographic_camera = true;
uniform float hole_radius : hint_range(0.0, 10.0) = 2.0;
uniform float hole_softness : hint_range(0.0, 5.0) = 0.7;
uniform float front_offset : hint_range(-10.0, 10.0) = 5.0;
uniform bool use_dither = true;
group_uniforms;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float dither_noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	vec3 view_dir = orthographic_camera
		? normalize(camera_forward)
		: normalize(world_pos - camera_position);
	
	vec3 to_player = player_position - world_pos;
	float along = dot(to_player, view_dir);
	float dist = length(to_player - view_dir * along);
	
	float edge = max(hole_softness, 0.001);
	float visibility = smoothstep(hole_radius - edge, hole_radius, dist);
	
	if (along > -front_offset) {
		float threshold = use_dither ? dither_noise(FRAGCOORD.xy) : 0.5;
		if (visibility <= threshold) {
			discard;
		}
	}
	
	vec2 base_uv = UV * uv_scale + uv_offset;
	
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	
	METALLIC = metallic * texture(texture_metallic, base_uv).r;
	ROUGHNESS = roughness * texture(texture_roughness, base_uv).r;
	SPECULAR = specular;
	
	NORMAL_MAP = texture(texture_normal, base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	
	AO = texture(texture_ao, base_uv).r;
	AO_LIGHT_AFFECT = ao_light_affect;
}
