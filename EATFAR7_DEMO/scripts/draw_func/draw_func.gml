
function cam_create(argument0, argument1, argument2, argument3, argument4) {
	/*
		Creates a camera for the given view
		If view is -1, the camera is not assigned to any views. This is useful for for example shadow maps.

		Script created by TheSnidr
		www.thesnidr.com
	*/
	var viewInd = argument0;
	var FOV = argument1;
	var aspect = argument2;
	var near = argument3;
	var far = argument4;

	var camera = camera_create();
	camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-FOV, -aspect, near, far));
	camera_set_view_mat(camera, matrix_build_identity());

	if viewInd >= 0
	{
		view_enabled = true;
		view_set_visible(viewInd, true);
		view_set_camera(viewInd, camera);
	}

	return camera;
}
/// @description cam_set_projmat(camera, FOV, aspect, near, far)
/// @param camera
/// @param FOV
/// @param aspect
/// @param near
/// @param far
function cam_set_projmat(camera, FOV, aspect, near, far) {
	/*
	Creates a camera for the given view

	Script created by TheSnidr
	www.thesnidr.com
	*/
	camera_set_proj_mat(camera, matrix_build_projection_perspective_fov(-FOV, -aspect, near, far));
}

/// @description cam_set_viewmat(camera, xFrom, yFrom, zFrom, xTarget, yTarget, zTarget, xUp, yUp, zUp)
/// @param camera
/// @param xFrom
/// @param yFrom
/// @param zFrom
/// @param xTarget
/// @param yTarget
/// @param zTarget
/// @param xUp
/// @param yUp
/// @param zUp
function cam_set_viewmat(argument0, argument1, argument2, argument3, argument4, argument5, argument6, argument7, argument8, argument9) {
	camera = argument0
	camera_set_view_mat(camera, matrix_build_lookat(argument1, argument2, argument3, argument4, argument5, argument6, argument7, argument8, argument9));
}

function camera_3d_enable(enable=true) {
	if enable {
		//Turns on the z-buffer
		gpu_set_zwriteenable(true);
		gpu_set_ztestenable(true);
		gpu_set_cullmode(cull_counterclockwise);
		gpu_set_texrepeat(true);
	} else {
		gpu_set_zwriteenable(false);
		gpu_set_ztestenable(false);
		gpu_set_cullmode(cull_noculling);
		gpu_set_texrepeat(false);
		}
}
	
function vertex_standard(vertex, x, y, z, nx=0, ny=0, nz=1, u=0, v=0, color=c_white, alpha=1)
{
	vertex_position_3d(vertex,x, y, z);
	vertex_normal(vertex, nx, ny, nz);
	vertex_texcoord(vertex, u, v);
	vertex_color(vertex, color, alpha);
}

function matrix_view_pos(view_mat) {
var _x = -view_mat[0] * view_mat[12] - view_mat[1] * view_mat[13] - view_mat[2] * view_mat[14]; 
var _y = -view_mat[4] * view_mat[12] - view_mat[5] * view_mat[13] - view_mat[6] * view_mat[14];
var _z = -view_mat[8] * view_mat[12] - view_mat[9] * view_mat[13] - view_mat[10] * view_mat[14];
return [_x,_y,_z]
}

