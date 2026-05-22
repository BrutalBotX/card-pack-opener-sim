shader_type canvas_item;

uniform vec2 mouse_pos = vec2(0.0, 0.0); // Set by script
uniform float intensity = 0.03;         // How much it tilts

void fragment() {
    // Parallax logic: offset UVs based on normalized mouse position
    vec2 uv = UV + (mouse_pos * intensity);
    
    // Add a tiny bit of "shimmer" distortion if you still want it
    uv.x += sin(TIME + uv.y * 5.0) * 0.005;
    
    COLOR = texture(TEXTURE, uv);
}