/*
	Snidr's Voxel Sprite fragment shader v1.0.7
	Sindre Hauge Larsen, anno 2019
*/
//Varyings
varying vec4 v_vertPos;
varying vec4 v_pos;
varying vec4 v_rot;
varying vec4 v_PageRes;
varying vec3 v_origin;
varying vec3 v_worldpos;
varying vec4 v_attribute;
varying mat4 v_world;

const int maxBatch = 16;
uniform vec4 u_texture[maxBatch];	// texture UVs

//Matrices
uniform mat4 u_invWorld;
uniform vec3 u_camPos;
uniform mat4 u_view;
uniform float u_tanFOV;
uniform float u_aspect;
uniform float u_near;
uniform float u_far;

uniform vec3 u_LightForward;

//Constants and common variables
const vec3 AllOnes = vec3(1.);
const vec3 AllZero = vec3(0.);

//Various functions
vec3 rotate_quaternion(vec3 vec, vec4 q)
{
	return vec + 2.0*cross(cross(vec, -q.xyz ) + q.w*vec, -q.xyz);
}
vec3 invert_quaternion(vec3 vec, vec4 q)
{
	return rotate_quaternion(vec, vec4(-q.xyz,q.w));
}
float castRayBlock(vec3 cubePos, vec3 size, vec3 ro, vec3 rd)
{	//	Cast ray at block, finds intersection with exterior wall.
	//	Returns the normalized distance from ro along rd to the intersection. Returns 1 if there is no intersection. Returns 0 if the ray starts inside the block.
	//	Sindre Hauge Larsen, anno 2019.	
	ro -= cubePos;
	vec3 halfSize = size * .5;
	vec3 T = (sign(ro) * halfSize - ro) / rd;
	vec3 dV = mix(T, AllOnes, vec3(
		min(dot(step(vec3(T.x, halfSize.yz), vec3(0., abs(ro.yz + rd.yz * T.x))), AllOnes), 1.),
		min(dot(step(vec3(T.y, halfSize.xz), vec3(0., abs(ro.xz + rd.xz * T.y))), AllOnes), 1.),
		min(dot(step(vec3(T.z, halfSize.xy), vec3(0., abs(ro.xy + rd.xy * T.z))), AllOnes), 1.)));
	
	return min(min(dot(step(halfSize, abs(ro)), AllOnes), 1.), min(dV.x, min(dV.y, dV.z)));
}


vec4 getVoxel(vec3 pos)
{	//	Returns the colour of the voxel at a given 3D position.
	//	Sindre Hauge Larsen, anno 2019.
	vec4 PageRes = floor(v_PageRes);
	int index = int(v_attribute.a);
	vec4 UVs = u_texture[index];
	vec4 TexUV = UVs;
	pos.xy = ceil(pos.xy * PageRes.xy) / PageRes.xy;
	pos.z /= PageRes.w;
	vec2 texCoord = pos.xy / PageRes.xy + vec2(fract(pos.z), floor(pos.z) / PageRes.z);
	return texture2D(gm_BaseTexture, mix(TexUV.xy, TexUV.zw, texCoord));
}

vec4 voxelCol = vec4(0.);
vec3 voxelNormal = vec3(0.);
#define MAX_STEPS 64
float castRayVoxel(vec3 ro, vec3 rd, float dEnd)
{	//	Cast a ray (in world-space) onto a voxel sprite.
	//	Returns the normalized distance from ro along rd to intersection.
	//	Also sets the vec4 voxelCol to the colour of the last intersected voxel.
	//	Also sets the vec3 voxelNormal to the normal of the intersection.
	//	Sindre Hauge Larsen, anno 2019.
	
	//Find the starting point of the ray by finding the intersection with the voxel sprite's bounding box
	vec4 PageRes = floor(v_PageRes);
	vec3 sprRes = vec3(PageRes.x / PageRes.w, PageRes.y / PageRes.z, PageRes.z * PageRes.w);
	float dO = castRayBlock(sprRes * .5, sprRes + 3., ro, rd);
	
	//Initialize various vectors and values needed for ray casting
	float m;
	vec3 d, vPos, dV;
	vec3 id = 1. / rd;
	vec3 inc = abs(id);
	vec3 wPos = ro + rd * dO;
	vec3 invHalfRes = 2. / sprRes;
	vec3 dirCorr = step(rd, AllZero); //Direction correction, needed for reading the correct voxel from texture
	
	//Iterate through the voxel sprite
	for (int i = 0; i < MAX_STEPS; i ++)
	{
		d = - fract(wPos) * id;			//Find the remaining distance to the nearest wall
		d += inc * step(d, AllZero);	//Add the increment value if d is less than or equal to zero
		m = min(d.x, min(d.y, d.z));	//Find which dimension needs to travel the shortest to cross a wall
		dO += m;						//Increment the ray parameter so that the ray ends up at the intersection
		if (dO >= dEnd){break;}			//Break loop if the ray has passed its limit
		dV = 1. - abs(sign(m - d));		//Dimension vector, indicates which dimension has been intersected
		wPos = ro + rd * dO;			//World-space ray position
		wPos = mix(wPos, floor(wPos + .5), dV); //Make sure that the current position is exactly at the intersection in the intersected dimension
		vPos = vec3(floor(wPos - dV * dirCorr));
		
		//Exit condition, if we've hit a solid voxel
		if (dot(floor(abs((vPos + .5) * invHalfRes - 1.)), AllOnes) == 0.)
		{
			vec4 voxel = getVoxel(vPos);
			if (voxel.a > 0.) 
			{
				voxelNormal = - sign(rd) * dV;
				voxelCol = voxel;
				return dO;
			}
		}
	}
	return 1.;
}
//Process view and projection values before the main function
vec4 viewZ = vec4(u_view[0].z, u_view[1].z, u_view[2].z, u_view[3].z);
float depthRange = u_far / (u_far - u_near);

void main()
{	//	Main shader code.
	//	Contains basic lighting functionality using a single point light. You'll need to modify the shader to add more lights.
	//	This version of the script has ray-casted shadows and ambient occlusion.
	//	Sindre Hauge Larsen, anno 2019.
	//Cast ray from camera
	vec3 camPos = (u_invWorld * vec4(u_camPos.xyz, 0.)).xyz;	
	
	vec2 screenCoord = v_vertPos.xy / v_vertPos.w * u_tanFOV;
	vec3 ro = u_camPos - v_pos.xyz;
	vec3 rd = vec3(screenCoord.x * u_aspect, screenCoord.y, 1.) * mat3(u_view) * u_far;
	
	//Rotate ray to transforms
	ro = (u_invWorld * vec4(ro, 1.)).xyz;
	rd = (u_invWorld * vec4(rd, 0.)).xyz;
	ro = invert_quaternion(ro, v_rot) / v_pos.w;
	rd = invert_quaternion(rd, v_rot) / v_pos.w;
	
	//Sprite origin offset
	vec3 spr_origin = v_origin.xyz;
	ro += spr_origin;
	float ray = castRayVoxel(ro, rd, length(v_worldpos-u_camPos) / (u_far));
	voxelNormal = rotate_quaternion(voxelNormal, v_rot);
	voxelNormal = (v_world * vec4(voxelNormal, 0.)).xyz;
	
	//If the ray didn't hit anything, discard this fragment
	if (ray == 1.) {discard;}
	
	//Get fragment position (invert transform)
	vec3 fragPos = ro + rd * ray;
	fragPos = rotate_quaternion((fragPos - spr_origin) * v_pos.w, v_rot);
	fragPos = (v_world * vec4(fragPos, 1.)).xyz + v_pos.xyz;
	#extension GL_EXT_frag_depth : enable
	gl_FragDepthEXT = (1. - u_near / dot(vec4(fragPos, 1.), viewZ)) * depthRange;
	
	gl_FragColor = voxelCol;
	float illumination    = -dot(voxelNormal, u_LightForward);
	gl_FragColor.rgb *= illumination * .5 + .5;
}