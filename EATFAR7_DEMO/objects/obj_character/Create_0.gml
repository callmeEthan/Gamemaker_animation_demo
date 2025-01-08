// Load skeleton
skeleton = skeleton_load("Animations\\character.skeleton");

// Load 3d model
var mbuff = buffer_load("Model\\woman.eatbuff");
character_spr = sprite_add("Texture\\woman.png", 1, false, false, 0, 0);
skeleton_model_add_mbuffer(skeleton, mbuff, sprite_get_texture(character_spr, 0));

/*
// Load 2d model (use only one or the other)
sprite_model = new skeleton_sprite(skeleton);
skeleton_sprite_load(skeleton,"Model\\human.skinspr");
character_spr = sprite_add("Texture\\human_spr.png", 1, false, false, 0, 0);
sprite_model.bind_texture_sprite(0, character_spr, 0);
*/

// Create another bone for the gun, and add voxel model to it
weapon_spr = sprite_add("Texture\\firearms_voxel.png", 1, false, false, 0, 0);
voxel_model = new skeleton_voxel(skeleton)
var bone = skeleton.add_bone(-1, "ArmRight");
var temp = voxel_model.add_sprite(bone.index, weapon_spr, 0, [355,0,378,16], [5,12,1], 1, 3, "Pistol");

// Adjust voxel model scale and rotation
quaternion_build(1,0,0,-90, temp.rotation);
temp.scale = 0.45
voxel_model.build_vbuffer()

// Create a player to handle animations
player = new animation_player(skeleton);
with(player)
{
	x_lock=true;	y_lock=true;
	x_loop=false;	y_loop=false;
}
anim_main = anim_stack_create(player);
anim_stack_add(anim_main);
anim_arm = anim_stack_create(player, [2,4,5,6])

// Render functions
render_model = function()
{
	if skeleton.model_data==-1 return;
	matrix_set(matrix_world, skeleton.matrix)
	skeleton_set_uniform(skeleton);
	skeleton_model_render(skeleton);
}
render_sprite = function()
{
	if skeleton.sprite_data==-1 return;
	matrix_set(matrix_world, skeleton.matrix)
	skeleton_set_uniform(skeleton);
	sprite_model.render();
}
render_voxel = function()
{
	if skeleton.voxel_data==-1 return;
	matrix_set(matrix_world, skeleton.matrix)
	skeleton_set_uniform(skeleton);
	voxel_model.render()
}
anim_direction = function()
{
	static sample = array_create(8);
	//skeleton_get_sample_transform(skeleton, 0, sample);
	player.get_bone_transform(0, sample);
	var vec = quaternion_transform_vector(sample, 1, 0, 0);
	vec = matrix_transform_vertex(skeleton.matrix, vec[0], vec[1], vec[2], 0);
	return point_direction(0,0, vec[0], vec[1]);	
}

direction = 0; speed_mult = 1;
x=0;	y=0;	z=0
xspeed=0; yspeed=0

// Behavior state machine
basic_state()	// main behavior (walking, running,...)
secondary_state() // weapon behavior

