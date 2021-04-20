//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying float v_vShade;

uniform vec4 u_color;

void main()
{
    gl_FragColor = u_color * texture2D(gm_BaseTexture, v_vTexcoord);
	gl_FragColor.rgb *= v_vShade;
}
