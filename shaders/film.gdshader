shader_type canvas_item;
uniform float intensity = 0.025;
uniform float trauma = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
void fragment() {
    float grain = hash(FRAGCOORD.xy + fract(TIME)*271.0);
    vec2 q = UV * (1.0-UV.yx);
    float vignette = 1.0-pow(clamp(q.x*q.y*16.0,0.0,1.0),.23);
    COLOR = vec4(vec3(grain*.11), clamp(vignette*.48 + grain*intensity + trauma*.1,0.0,.65));
}
