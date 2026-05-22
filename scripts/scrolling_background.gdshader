shader_type canvas_item;

uniform float scroll_speed = 0.05;
uniform float distortion_strength = 0.02;

void fragment() {
    // Offset the UV coordinates based on time
    vec2 uv = UV;
    uv.x += TIME * scroll_speed;
    uv.y += TIME * (scroll_speed * 0.5);
    
    // Add a slight distortion for a "flowing" feel
    uv.x += sin(TIME + uv.y * 10.0) * distortion_strength;
    
    // Sample the texture with the modified coordinates
    COLOR = texture(TEXTURE, uv);
}