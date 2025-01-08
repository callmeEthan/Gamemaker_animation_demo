//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec3 in_Normal;                  // (x,y,z)     unused in this shader.
attribute vec2 in_TextureCoord;           // (u,v)
attribute vec4 in_Colour;                   // (r,g,b,a) blend bone
attribute vec4 in_Colour2;                   // (r,g,b,a) blend weight

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

const int AnimMaxBone = 128;
uniform vec4 u_boneDQ[2*AnimMaxBone];
uniform float u_highlight;

vec4 blendReal, blendDual;
vec3 blendTranslation;
void anim_init(ivec4 bone, vec4 weight)
{
	bone *= 2;
	blendReal  =  u_boneDQ[bone[0]]   * weight[0] + u_boneDQ[bone[1]]   * weight[1] + u_boneDQ[bone[2]]   * weight[2] + u_boneDQ[bone[3]]   * weight[3];
	blendDual  =  u_boneDQ[bone[0]+1] * weight[0] + u_boneDQ[bone[1]+1] * weight[1] + u_boneDQ[bone[2]+1] * weight[2] + u_boneDQ[bone[3]+1] * weight[3];
	//Normalize resulting dual quaternion
	float blendNormReal = 1.0 / length(blendReal);
	blendReal *= blendNormReal;
	blendDual = (blendDual - blendReal * dot(blendReal, blendDual)) * blendNormReal;
	blendTranslation = 2. * (blendReal.w * blendDual.xyz - blendDual.w * blendReal.xyz + cross(blendReal.xyz, blendDual.xyz));
}
vec3 anim_rotate(vec3 v)
{
	return v + 2. * cross(blendReal.xyz, cross(blendReal.xyz, v) + blendReal.w * v);
}
vec3 anim_transform(vec3 v)
{
	return anim_rotate(v) + blendTranslation;
}

void main()
{
	/*///////////////////////////////////////////////////////////////////////////////////////////
	Initialize the animation system, and transform the vertex position and normal
	/*///////////////////////////////////////////////////////////////////////////////////////////
	ivec4 boneInd = ivec4(floor(in_Colour * 255.0));
	vec4 boneWeight = in_Colour2;
	
	anim_init(boneInd, boneWeight);
	if (max(max(boneWeight.x, boneWeight.y), max(boneWeight.z, boneWeight.w))==0.) {
		blendReal = vec4(0.,0.,0.,1.); blendTranslation = vec3(0.);}	
	vec4 objectSpacePos = vec4(anim_transform(in_Position), 1.0);
	vec4 animNormal = vec4(anim_rotate(in_Normal), 0.);
	/////////////////////////////////////////////////////////////////////////////////////////////
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * objectSpacePos;
	v_vNormal = normalize((gm_Matrices[MATRIX_WORLD] * animNormal).xyz);
    v_vTexcoord = in_TextureCoord;
    v_vColour = vec4(1.);
}