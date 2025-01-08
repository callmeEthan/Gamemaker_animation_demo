/*
	Snidr's Voxel Sprite vertex shader v1.0.7
	Sindre Hauge Larsen, anno 2019
*/

//Attributes
attribute vec3 in_Position;
attribute vec4 in_Colour; // bone indices
attribute vec4 in_Colour2; // bone weights
attribute vec4 in_Colour3; // index

//Varyings
varying vec4 v_vertPos;
varying vec4 v_pos;
varying vec4 v_rot;
varying vec3 v_origin;
varying vec4 v_PageRes;
varying vec3 v_scale;
varying vec4 v_attribute;
varying mat4 v_world;

//Uniforms
const int maxBatch = 16;
uniform vec4 u_transform[maxBatch*4];
const int AnimMaxBone = 128;
uniform vec4 u_boneDQ[2*AnimMaxBone];

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
vec4 quat_mult(vec4 q1, vec4 q2) {
	return vec4(
		q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz),
		q1.w * q2.w - dot(q1.xyz, q2.xyz)
	);
}
vec3 rotate_quaternion(vec3 vec, vec4 q)	// conjugated quaternion to match with GM world space
{
	return vec + 2.0*cross(cross(vec, -q.xyz ) + q.w*vec, -q.xyz);
}
vec3 invert_transform(vec3 vec, vec4 q, vec3 p, vec3 scale)
{
	return rotate_quaternion(vec - p, vec4(-q.xyz, q.w)) / scale; // invert transform
}
void main()
{
	int index = int(in_Colour3.a*255.0);
	vec4 position = u_transform[index*4];
	vec4 rotate = u_transform[index*4+1];
	vec4 origin = u_transform[index*4+2];
	vec4 pageRes = u_transform[index*4+3];
	
	ivec4 boneInd = ivec4(in_Colour * 255.0);
	vec4 boneWeight = in_Colour2;
	anim_init(boneInd, boneWeight);
	
	vec3 scale = vec3(pageRes.x/pageRes.w, pageRes.y/pageRes.z, pageRes.z*pageRes.w) * position.w;
	scale += vec3(2.);
	vec3 bound = vec3(1.0,1.0,0.5); // adjust if voxel clip outside of bounding-box
	
	blendTranslation += rotate_quaternion(position.xyz, blendReal) - rotate_quaternion(origin.xyz, blendReal);
	rotate = quat_mult(blendReal, rotate);
	vec3 world_pos = rotate_quaternion(in_Position*scale, rotate) + blendTranslation - rotate_quaternion(bound, blendReal);
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vec4(world_pos, 1.0);
    
    v_vertPos = gl_Position;
	v_pos = vec4(blendTranslation.xyz, position.w);
	//v_pos = vec4((gm_Matrices[MATRIX_WORLD] * vec4(position.xyz, 0.)).xyz, position.w);
	v_scale = scale;
	v_rot = rotate;
	v_PageRes = pageRes + vec4(0.5);
	v_attribute = vec4(in_Colour3.x, in_Colour3.y, in_Colour3.z, float(index)+0.5);
	v_world = gm_Matrices[MATRIX_WORLD];
}