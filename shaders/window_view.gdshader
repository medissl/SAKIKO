shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D courtyard : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap;
uniform bool daytime = false;
uniform float room_center = -16.0;
uniform float outside_side = -1.0;
uniform bool obscured = false;
uniform float view_offset = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec3 ray=normalize(world_position-CAMERA_POSITION_WORLD);
 float travel=8.0/max(.12,abs(ray.z));
 vec3 distant=world_position+ray*travel;
 // Project onto a distant plane with the panorama's true 6:1 aspect ratio.
 float u=.5+(distant.x-room_center)/42.0+view_offset;
 float height=clamp(.67-(distant.y-1.5)/7.0,.015,.985);
 u+=sin(TIME*.31+distant.x*.13)*.0006*smoothstep(.65,.15,height);
 float v=height*.495+(daytime?0.0:.5);
 vec3 scene=textureLod(courtyard,vec2(u,v),obscured?4.0:0.0).rgb;
 vec3 grime = texture(dirt,UV*vec2(1.4,1.0)).rgb;
 float edge = smoothstep(0.0,.07,min(UV.x,1.0-UV.x));
 if(obscured) scene=mix(scene,vec3(daytime?.19:.012),.50);
 ALBEDO = scene*(daytime ? .75 : .50)*mix(.82,1.0,edge) + grime*(obscured?.10:.028);
 ROUGHNESS = .98;
}
