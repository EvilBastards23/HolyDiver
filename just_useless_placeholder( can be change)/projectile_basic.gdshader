shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_test_disabled, diffuse_burley, specular_schlick_ggx;

// Shader parameters
uniform float speed = 2.0;
uniform float glow_intensity = 2.0;
uniform vec4 bullet_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.4, 0.0, 1.0);
uniform float trail_length = 0.8;
uniform float bullet_width = 0.3;
uniform bool enable_sparkle = true;
uniform float sparkle_intensity = 1.0;
uniform bool billboard = true;

varying vec2 uv_coords;
varying vec3 world_position;
varying vec3 local_position;

// Noise function for sparkle effect
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void vertex() {
    uv_coords = UV;

    
    // Get world position BEFORE billboard transformation
    
    // Billboard effect - makes quad always face camera while preserving world position
    if (billboard) {
        // Extract scale from model matrix
        vec3 scale = vec3(
            length(MODEL_MATRIX[0].xyz),
            length(MODEL_MATRIX[1].xyz),
            length(MODEL_MATRIX[2].xyz)
        );
        
        // Create billboard matrix that faces camera but keeps world position
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
            vec4(scale.x, 0.0, 0.0, 0.0),
            vec4(0.0, scale.y, 0.0, 0.0),
            vec4(0.0, 0.0, scale.z, 0.0),
            MODEL_MATRIX[3] // Keep original world position
        );
    }
}

void fragment() {
    vec2 uv = uv_coords;
    vec2 centered_uv = uv - 0.5;
    
    // Use world position for consistent effects across rotations
    float time_offset = world_position.x * 0.1 + world_position.z * 0.1;
    float animated_time = TIME * speed + time_offset;
    
    // Create bullet shape (elongated along x-axis)
    float bullet_dist = length(vec2(centered_uv.x / bullet_width, centered_uv.y));
    float bullet_mask = 1.0 - smoothstep(0.15, 0.25, bullet_dist);
    
    // Create trail effect
    float trail_mask = 0.0;
    if (uv.x < 0.5) {
        float trail_dist = abs(centered_uv.y);
        float trail_fade = smoothstep(0.5, 0.0, uv.x) * trail_length;
        trail_mask = (1.0 - smoothstep(0.05, 0.2, trail_dist)) * trail_fade;
    }
    
    // Combine bullet and trail
    float total_mask = max(bullet_mask, trail_mask * 0.6);
    
    // Glow effect
    float glow_dist = length(centered_uv);
    float glow_mask = 1.0 - smoothstep(0.1, 0.5, glow_dist);
    glow_mask *= glow_intensity;
    
    // Sparkle effect using world position for consistency
    float sparkle = 0.0;
    if (enable_sparkle) {
        vec2 sparkle_coords = world_position.xz * 0.5 + uv * 20.0;
        float sparkle_noise = noise(sparkle_coords + animated_time * 2.0);
        sparkle = smoothstep(0.7, 0.9, sparkle_noise) * sparkle_intensity;
        sparkle *= total_mask;
    }
    
    // Color mixing
    vec3 final_color = bullet_color.rgb;
    
    // Add glow
    final_color = mix(final_color, glow_color.rgb, glow_mask * 0.3);
    
    // Add sparkle
    final_color += vec3(sparkle);
    
    // Apply brightness based on position (brighter at front)
    float brightness_gradient = smoothstep(0.0, 1.0, uv.x);
    final_color *= (0.8 + brightness_gradient * 0.4);
    
    // Final alpha
    float final_alpha = total_mask + glow_mask * 0.2;
    final_alpha = clamp(final_alpha, 0.0, 1.0);
    
    ALBEDO = final_color;
    ALPHA = final_alpha * bullet_color.a;
    EMISSION = final_color * 0.5; // Make it glow
}