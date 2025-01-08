//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

uniform vec3 u_LightForward;

void main()
{
	vec4 color = texture2D( gm_BaseTexture, v_vTexcoord );
	if (color.a < 0.1) {discard;}
	float illumination    = -dot(v_vNormal, u_LightForward);
    gl_FragColor = v_vColour * color;
	gl_FragColor.rgb *= illumination * .3 + .7;
}
