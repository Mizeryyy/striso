// res://shaders/top_face_outline.gdshader
shader_type spatial;
render_mode unshaded, cull_disabled; // Draw on top, no lighting

uniform vec4 outline_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float outline_thickness : hint_range(0.005, 0.2) = 0.05; // Thickness in UV space (0 to 0.5)
// No tile_uv_size needed if we always use a plane scaled to the exact highlight area

void fragment() {
	// UVs go from 0 to 1 across the plane
	// Calculate distance from the edge (0 at edge, 0.5 at center)
	float dist_to_edge_x = min(UV.x, 1.0 - UV.x);
    float dist_to_edge_y = min(UV.y, 1.0 - UV.y);
    float min_dist_to_any_edge = min(dist_to_edge_x, dist_to_edge_y);

    if (min_dist_to_any_edge < outline_thickness && min_dist_to_any_edge >= 0.0) {
        ALBEDO = outline_color.rgb;
        ALPHA = outline_color.a;
    } else {
        ALPHA = 0.0; 
    }
}