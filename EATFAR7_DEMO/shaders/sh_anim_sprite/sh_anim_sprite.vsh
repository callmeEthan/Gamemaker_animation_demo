//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec3 in_Normal;                  // (x,y,z)     unused in this shader.
attribute vec2 in_TextureCoord;           // (u,v)
attribute vec4 in_Colour0;                   // (r,g,b,a) blend bone
attribute vec4 in_Colour2;                   // (r,g,b,a) blend weight
attribute vec4 in_Colour3;                   // (r,g,b,a) sprite vector

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

const int AnimMaxBone = 128;
uniform vec4 u_boneDQ[2*AnimMaxBone];
uniform float u_ratio;
uniform mat4 u_invWorld;

const float pi = 3.14159265359;

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
vec4 quat_build(vec3 axis, float angle) 
{ 
	// Source: https://github.com/willis7/OpenGL-SDL/blob/master/Quaternions/Main.cpp
    vec4 quat;
    float result = sin( angle / 2.0 );
    quat.w = cos( angle / 2.0 );
    quat.x = float(axis.x * result);
    quat.y = float(axis.y * result);
    quat.z = float(axis.z * result);
	return quat;
}
vec3 rotate_quaternion(vec3 vec, vec4 q)
{
	return vec + 2.0*cross(cross(vec, q.xyz ) + q.w*vec, q.xyz);
}

vec3 viewSide = vec3(gm_Matrices[MATRIX_VIEW][0][0], gm_Matrices[MATRIX_VIEW][1][0], gm_Matrices[MATRIX_VIEW][2][0]);
vec3 viewUp = - vec3(gm_Matrices[MATRIX_VIEW][0][1], gm_Matrices[MATRIX_VIEW][1][1], gm_Matrices[MATRIX_VIEW][2][1]);
vec3 viewFoward = vec3(gm_Matrices[MATRIX_VIEW][0][2], gm_Matrices[MATRIX_VIEW][1][2], gm_Matrices[MATRIX_VIEW][2][2]);

void main()
{
	/*///////////////////////////////////////////////////////////////////////////////////////////
	Initialize the animation system, and transform the vertex position and normal
	/*///////////////////////////////////////////////////////////////////////////////////////////
	ivec4 boneInd	= ivec4(floor(in_Colour0 * 255.0));
	vec4 boneWeight	= in_Colour2;
	vec3 boneVec	= - normalize(in_Colour3.xyz * 2. - 1.);
	
	anim_init(boneInd, boneWeight);
	vec3 objectSpacePos	= anim_transform(in_Position);
	vec3 SpriteVec		= anim_transform(in_Position + boneVec * in_Normal.z * in_Colour3.a);
	//vec3 Normal			= anim_rotate(viewFoward);
	/////////////////////////////////////////////////////////////////////////////////////////////
	
	vec4 origin = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(objectSpacePos, 1.);
	vec4 vector = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(SpriteVec, 1.);
	vec2 dir	= normalize(vector.xy/vector.w - origin.xy/origin.w);
	vec4 quat	= quat_build(viewFoward, atan(dir.x*u_ratio, dir.y));
	vec3 axisUp	= rotate_quaternion(viewUp, quat);
	vec3 axisSide = rotate_quaternion(viewSide, quat);
	
	axisUp = (u_invWorld * vec4(axisUp, 0.)).xyz;
	axisSide = (u_invWorld * vec4(axisSide, 0.)).xyz;
	objectSpacePos += (axisUp * in_Normal.y) + (axisSide * in_Normal.x);
	
    gl_Position	= gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(objectSpacePos, 1.);
	v_vNormal	= -viewFoward;
    v_vTexcoord	= in_TextureCoord;
	v_vColour = vec4(1.);
    //v_vColour	= vec4(in_Colour2.g, in_Colour2.g, in_Colour2.g, 1.);
}