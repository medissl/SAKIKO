shader_type canvas_item;
uniform float closure = 0.0;
void fragment(){
    vec2 p=UV*2.0-1.0;
    float aperture=(1.0-closure)*1.6;
    float edge=abs(p.y)+p.x*p.x*.23;
    float a=smoothstep(aperture-.05,aperture+.02,edge);
    COLOR=vec4(0.0,0.0,0.0,a);
}
