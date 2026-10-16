shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D courtyard : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D dirt : source_color, filter_linear_mipmap;
uniform bool daytime=false;
uniform bool obscured=false;
uniform vec3 facade_normal=vec3(0.0,0.0,1.0);
uniform vec3 facade_right=vec3(1.0,0.0,0.0);
uniform vec3 scene_center=vec3(0.0,1.5,0.0);
uniform float scene_width=42.0;
uniform float scene_depth=8.0;
uniform float vertical_anchor=.67;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 ray=normalize(world_position-CAMERA_POSITION_WORLD);
 // Project the existing fixed image along this facade's actual normal, including
 // east/west panes. Never stretch a clamped top/bottom texture row at grazing angles.
 float incidence=max(.20,abs(dot(ray,facade_normal)));
 vec3 distant=world_position+ray*(scene_depth/incidence);
 vec2 image_size=vec2(textureSize(courtyard,0));
 float aspect=image_size.x/(image_size.y*.5);
 float u=.5+dot(distant-scene_center,facade_right)/scene_width;
 float v=vertical_anchor-(distant.y-scene_center.y)/(scene_width/aspect);
 vec3 backdrop=daytime?vec3(.19,.24,.26):vec3(.003,.006,.01);
 if(v>1.0)backdrop=daytime?vec3(.06,.075,.055):vec3(.002,.003,.002);
 float inside=step(0.0,u)*step(u,1.0)*step(0.0,v)*step(v,1.0);
 vec2 sample_uv=vec2(clamp(u,.001,.999),clamp(v,.003,.997)*.495+(daytime?0.0:.5));
 vec3 scene=mix(backdrop,textureLod(courtyard,sample_uv,obscured?3.0:0.0).rgb,inside);
 ALBEDO=scene*(daytime?.75:.50)+texture(dirt,UV).rgb*.018;
 ROUGHNESS=.98;
}
