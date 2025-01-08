//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec3 in_Normal;                  // (x,y,z)     unused in this shader.
attribute vec2 in_TextureCoord;           // (u,v)
attribute vec4 in_Colour;                   // (r,g,b,a)
attribute vec4 in_Colour2;                   // (r,g,b,a)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

uniform float u_highlight;

void main()
{
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	//if (u_highlight == in_TextureCoord1.x) {v_vColour.rgb = vec3(1., 0., 0.);}
	float highlight = 0.;
	for(int i=0; i<4; i++)
	{
		if (u_highlight == in_Colour[i]*255.) highlight+=in_Colour2[i];
	}
    v_vColour = mix(vec4(0.9, 0.9, 0.9, 1.0), vec4(1., 0., 0., 1.), clamp(highlight, 0., 1.));
    v_vTexcoord = in_TextureCoord;
	v_vNormal = in_Normal;
}
