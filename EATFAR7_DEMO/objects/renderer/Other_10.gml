gpu_set_tex_filter(false);
gpu_set_tex_repeat(true);
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
var campos = matrix_view_pos(matrix_get(matrix_view))

vFloor = vertex_create_buffer()
var tile = tile_scale
var tile_x = floor_x/(floor_scale/tile_scale)/2;
var tile_y = floor_y/(floor_scale/tile_scale)/2;
vertex_begin(vFloor, primitiveFormat);
vertex_position_3d(vFloor, floor_x-floor_scale,floor_y-floor_scale,0)
vertex_texcoord(vFloor, tile_x,tile_y)
vertex_position_3d(vFloor, floor_x+floor_scale,floor_y-floor_scale,0)
vertex_texcoord(vFloor, tile_x+tile,tile_y)
vertex_position_3d(vFloor, floor_x-floor_scale,floor_y+floor_scale,0)
vertex_texcoord(vFloor, tile_x,tile_y+tile)

vertex_position_3d(vFloor, floor_x+floor_scale,floor_y-floor_scale,0)
vertex_texcoord(vFloor, tile_x+tile,tile_y)
vertex_position_3d(vFloor, floor_x+floor_scale,floor_y+floor_scale,0)
vertex_texcoord(vFloor, tile_x+tile,tile_y+tile)
vertex_position_3d(vFloor, floor_x-floor_scale,floor_y+floor_scale,0)
vertex_texcoord(vFloor, tile_x,tile_y+tile)
vertex_end(vFloor);
vertex_freeze(vFloor);

if campos[2]>0
{
	draw_set_color(c_white);
	var tex = sprite_get_texture(spr_floor, 0);
	shader_set(sh_primitive)
	//matrix_set(matrix_world, matrix_build_transform(0,0,0,0,0,0,320,320,320));
	matrix_set(matrix_world, matrix_build_identity());
	vertex_submit(vFloor, pr_trianglelist, tex);
	shader_reset()
}

vertex_delete_buffer(vFloor);
matrix_set(matrix_world, matrix_build(xFrom,yFrom,zFrom, 0,0,0, 1000, 1000, 1000))
gpu_set_cullmode(cull_clockwise)
vertex_submit(skySphere, pr_trianglelist, sprite_get_texture(texSky, 0))
gpu_set_cullmode(cull_counterclockwise)

	var sh = Animation3DShader;
	shader_set(sh);
	shader_set_uniform_f_array(shader_get_uniform(sh, "u_LightForward"), light_direction);
	with obj_character render_model()
	shader_reset()
	
	anim_voxel_draw_start();
	shader_set_uniform_f_array(shader_get_uniform(AnimationVoxelShader, "u_LightForward"), light_direction);
	with obj_character render_voxel()
	anim_voxel_draw_end();
	
	anim_sprite_draw_start();
	shader_set_uniform_f_array(shader_get_uniform(AnimationSpriteShader, "u_LightForward"), light_direction)
	with obj_character render_sprite()
	anim_voxel_draw_end();
	

var s = array_length(pos_debug)
for(var i=0; i<s; i++)
{
	matrix_set(matrix_world, pos_debug[i])
	vertex_submit(skySphere, pr_trianglelist, -1)
}
matrix_set(matrix_world, matrix_build_identity())
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);