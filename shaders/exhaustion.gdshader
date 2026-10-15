shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float fatigue=0.0;
uniform bool reduced=false;
void fragment(){
    vec3 c=textureLod(screen_texture,SCREEN_UV,0.0).rgb;
    float edge=smoothstep(.05,.65,length(UV-.5));
    if(!reduced && fatigue>.01){
        vec3 blur=textureLod(screen_texture,SCREEN_UV,1.4).rgb;
        c=mix(c,blur,fatigue*edge*.26);
    }
    c=mix(c,vec3(dot(c,vec3(.22,.68,.1))),fatigue*.12);
    COLOR=vec4(c,1.0);
}
