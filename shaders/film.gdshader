shader_type canvas_item;
uniform float intensity = 0.025;
uniform float trauma = 0.0;
uniform bool reduced = false;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
float hash(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
void fragment() {
    float grain = hash(FRAGCOORD.xy + fract(TIME)*271.0);
    vec2 q = UV * (1.0-UV.yx);
    float vignette = 1.0-pow(clamp(q.x*q.y*16.0,0.0,1.0),.23);
    float fx = reduced ? .12 : 1.0;
    vec3 c=texture(screen_texture,SCREEN_UV).rgb;
    c=mix(c,vec3(dot(c,vec3(.23,.64,.13))),.10*fx);
    c*=1.0-vignette*.35;
    c+=(grain-.5)*.014*fx;
    c*=1.0-sin(FRAGCOORD.y*3.14159)*.006*fx;
    COLOR = vec4(c*(1.0-trauma*.08),1.0);
}
