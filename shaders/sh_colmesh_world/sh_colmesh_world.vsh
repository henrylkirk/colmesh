//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec3 in_Normal;                  // (x,y,z)     unused in this shader.
attribute vec4 in_Colour;                    // (r,g,b,a)
attribute vec2 in_TextureCoord;              // (u,v)

varying vec2 v_vTexcoord;
varying vec3 v_vColour;
uniform vec3 u_lightDir;

void main()
{
	mat4 V = gm_Matrices[MATRIX_VIEW];
	//Flatten the looking vector
	vec2 a = normalize(vec2(V[0].z, V[1].z));
	V[0].z = a.x;
	V[1].z = a.y;
	V[2].z = 0.;
	//Orthogonalize the two other vectors
	vec2 b = vec2(V[0].x, V[1].x);
	b = normalize(b - a * dot(a, b));
	V[0].x = b.x;
	V[1].x = b.y;
	V[2].x = 0.;
	
	V[0].y = 0.;
	V[1].y = 0.;
	V[2].y = 1.;
	
	
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
    gl_Position = gm_Matrices[MATRIX_PROJECTION] * gm_Matrices[MATRIX_VIEW] * gm_Matrices[MATRIX_WORLD] * object_space_pos;
    
    v_vColour = in_Colour.rgb * max(0.4, 0.75 - 0.5 * dot(in_Normal, u_lightDir));
    v_vTexcoord = in_TextureCoord;
}