globalvar bone_struct, bone_shape_struct;
bone_struct = {
	x: 0,	y: 0,	z: 0,	// current position for animation
	Vx: 0,	Vy: 0,	Vz: 0,	// vector position for quaternion transform
	Ox: 0,	Oy: 0,	Oz: 0,	// origin position
	Ax: 0,	Ay: 0,	Az: 10,	// Bone vector for editor visual
	name: "",
	inherit: false,	// inherit rotation transformation from parent bone, this bone won't need to rotate to transform
	link: 0,	// parent node
	index: 0,
	length: 1,
	childs: [],	// all descendants bone connected to this node.
	heirs: [],	// only descendants bone directly connected to this node.
	shape: -1,	// shape for raycasting check
	type: bone_type.basic,
	indice: 0,
	skip_transform: true,
}
bone_shape_struct = {
	type: 0, smooth: 1,
	x:0, y:0, z:0, xscale:1, yscale:1, zscale: 1,
	rotation: quaternion_identity(), matrix: matrix_build_identity(),
	angle: quaternion_identity(), Vx:0, Vy:0, Vz:0
}
enum bone_type	// this doesn't do anything yet
{
	basic = 0,
	helper = 2,
	twist = 3,
}
// File extensions
#macro anim_ext_skeleton ".skeleton"
#macro anim_ext_skin_sprite ".skinspr"
#macro anim_ext_skin_voxel ".skinvox"
#macro anim_ext_animation ".anim"
#macro anim_ext_model ".eatbuff"
#macro std_ext_model ".mbuff"

function skeleton_create(data) constructor {
	/*
		Contain bones structure and transform information, data type are buffer, struct and array;
		When deleting skeleton, use skeleton.destroy() to remove data from memory before delete.
		Transform data are directly written to buffers for faster read/write; then send directly to GPU for animation transform.
		data argument are used when loading file, to create new rig just use "new skeleton_create()"
	*/
	self.data = data;
	size = 0;		// number of bones
	animate = -1;	// contain transformation data, use as shader uniform for renderering.
	transform = -1;	// contain only rotation data, use to rotate bones and construct transformation data.
	filename = -1;
	bindmap = [];
	reference = ds_map_create();	// Reference bone name to index
	shapelist = -1;	// Reference for faster raycast check
	
	player = -1;	// Animation player, see animation_player()
	sprite_data = -1;	// Sprite renderer data, see skeleton_sprite()
	voxel_data = -1;	// Voxel renderer data, see skeleton_voxel()
	model_data = -1;	// Model buffer,vbuffer and texture data
	bone_model = -1;	// Bone model data
	matrix = matrix_build_identity(); matrix_inv=matrix_build_identity();
	if !is_array(self.data) {self.data = []; add_bone()}
	log("New skeleton created")
	
	static destroy = function()
	{
		// Destroy all data generate by the skeleton.
		//	This will also destroy relevant data associated with it: (skeleton_voxel, skeleton_sprite, animation_player and model buffer)
		//	Assume you didn't create dupplicates of those data, it should clean up memory nicely
		if transform!=-1 buffer_delete(transform);
		if animate!=-1 buffer_delete(animate);
		ds_map_destroy(reference);
		if sprite_data!=-1 {sprite_data.destroy(); delete sprite_data}
		if voxel_data!=-1 {voxel_data.destroy(); delete model_data}
		if player!=-1 {player.destroy(); delete player}
		if model_data!=-1
		{
			var s = array_length(model_data.mbuffer)
			for(var i=0;i<s;i++) buffer_delete(model_data.mbuffer[i]);
			var s = array_length(model_data.vbuffer)
			for(var i=0;i<s;i++) vertex_delete_buffer(model_data.vbuffer[i]);
			delete(model_data);
		}
	}
	static add_bone = function(link = -1, name="", update=true)
	{
		// Set update=false if you want to make any change to bone before update bone structure (Must call update_links() afterward).
		var ind = array_length(data);
		if is_struct(link) link=link.index
		var bone = variable_clone(bone_struct);
		bone.link = link;
		bone.index = ind;
		bone.name = name;
		if (ind>0 && link>=0)
		{
			var bind = data[link]
			if !is_nan(bind.Ax)
			{
				bone.x = bind.x + bind.Ax;
				bone.y = bind.y + bind.Ay;
				bone.z = bind.z + bind.Az;
				bone.Vx = bone.x-bind.x;
				bone.Vy = bone.y-bind.y;
				bone.Vz = bone.z-bind.z;
				bone.Ox = bone.x;
				bone.Oy = bone.y;
				bone.Oz = bone.z;
				var temp = [bind.Ax, bind.Ay, bind.Az]; normalize(temp);
				var len = point_distance_3d(0,0,0,bone.Ax,bone.Ay,bone.Az);
				bone.Ax = len*temp[0]
				bone.Ay = len*temp[1]
				bone.Az = len*temp[2]
			} else {
				bone.x = bind.x+10;
				bone.y = bind.y;
				bone.z = bind.z;
				bone.Vx = bone.x-bind.x;
				bone.Vy = bone.y-bind.y;
				bone.Vz = bone.z-bind.z;
				bone.Ox = bone.x;
				bone.Oy = bone.y;
				bone.Oz = bone.z;
			}
		}
		array_push(data, bone);
		if update update_links();
		return bone;
	}
	static delete_bone = function(bone = 0)
	{
		// Delete bone along with all of it's descendant, this can break your skeleton's structure.
		var index, offset=0;
		bone = check_bone(bone, self);
		if is_undefined(bone) return false
		index = bone.index
		if index=0 {log("Cannot delete main bone!"); return false}
		
		// If link armature is linked, detach
		if !(bone.link<0)
		{
			var link = data[bone.link];
			if is_nan(link.Ax) && link.Ay==index
			{
				link.Ax = bone.Ox - link.Ox;
				link.Ay = bone.Oy - link.Oy;
				link.Az = bone.Oz - link.Oz;
			}
		}
		// Bind linked armature directly to struct instead
		for(var i=index; i<size; i++)
		{
			var node = data[i]
			if is_nan(node.Ax) node.Ay=data[node.Ay];
		}
		
		var s = array_length(bone.childs);
		for(var n=0; n<size; n++)
		{
			var node = data[n];
			if node.index>index node.index -= 1;
			if node.link>index node.link-=1;
		}
		array_delete(data, index, 1);
		size-=1; offset+=1;
		for(var i=0; i<s; i++)
		{
			var c = bone.childs[i];
			var child = data[c-offset];
			for(var n=0; n<size; n++)
			{
				var node = data[n];
				if node.index>child.index node.index -= 1;
				if node.link>child.index node.link -= 1;
			}
			array_delete(data, child.index, 1);
			size-=1; offset+=1;
		}
		
		// Rebind armature to bone index
		for(var i=index; i<size; i++)
		{
			var node = data[i]
			if is_nan(node.Ax) node.Ay=node.Ay.index;
		}
		
		update_links();
	}
	static update_links = function()
	{
		// Update bones heritance and transformation datas
		// Must be used everytime a bone is added or removed.
		var prev = size;
		size = array_length(data);
		ds_map_clear(reference);
		delete bindmap; bindmap = array_create(size)
		for(var i=size-1; i>=0; i--)
		{
			var curr = data[i]
			if curr.name!="" reference[? curr.name]=i;
			var ind = curr.index;
			curr.childs = [];
			curr.heirs = [];
			bindmap[i] = []
			for(var b=i+1; b<size; b++)
			{
				var bone = data[b];
				if bone.link = ind
				{
					array_push(curr.heirs, bone);
					array_push(curr.childs, b);
					array_push(bindmap[i], bone);
					var s = array_length(bone.childs);
					for(var c=0; c<s; c++)
					{
						array_push(curr.childs, bone.childs[c])
						array_push(bindmap[i], data[bone.childs[c]])
					}
				}
			}
			array_sort(curr.childs, true);
		}

		if (transform==-1) transform = buffer_create(4*(8*size), buffer_fixed, 4) else buffer_resize(transform, 4*(8*size));
		if (animate==-1) animate = buffer_create(4*(8*size), buffer_fixed, 4) else buffer_resize(animate, 4*(8*size));
		for(var i=prev; i<size; i++)
		{
			buffer_poke(transform, 4*(i*8+3), buffer_f32, 1.);
			buffer_poke(transform, 4*(i*8+7), buffer_f32, 1.);
			buffer_poke(animate, 4*(i*8+3), buffer_f32, 1.);
			buffer_poke(animate, 4*(i*8+7), buffer_f32, 1.);
		}
	}
	static set_rig = function()
	{
		// Set current bones position and length as base for animation transformation.
		var quat=array_create(4), pos=array_create(3)
		for(var i=0; i<size; i++)
		{
			var b = i * 8;
			var bone = data[i]
			if bone.link>=0
			{
				var link = data[bone.link]
				bone.Vx = bone.x - link.x;
				bone.Vy = bone.y - link.y;
				bone.Vz = bone.z - link.z;
				bone.length = point_distance_3d(bone.x, bone.y, bone.z, link.x, link.y, link.z);
			} else {
				bone.length = 0;
			}
			bone.Ox = bone.x;
			bone.Oy = bone.y;
			bone.Oz = bone.z;
			if !is_nan(bone.Ax)
			{
				quat[@0] = buffer_peek(transform, 4*(b+0), buffer_f32);
				quat[@1] = buffer_peek(transform, 4*(b+1), buffer_f32);
				quat[@2] = buffer_peek(transform, 4*(b+2), buffer_f32);
				quat[@3] = buffer_peek(transform, 4*(b+3), buffer_f32);
				quaternion_transform_vector(quat, bone.Ax, bone.Ay, bone.Az, pos)
				bone.Ax=pos[0]; bone.Ay=pos[1];	bone.Az=pos[2]
			}
		}
		reset_transform();
	}
	static update_matrix = function()
	{
		// Call this function after making change to the character matrix as it is needed for various rendering function.
		// Simply update the inverse-matrix	
		// Derived from matrix inversion in SMF	
		var M = matrix;
		var I = matrix_inv
		var m0 = M[0], m1 = M[1], m2 = M[2], m3 = M[3], m4 = M[4], m5 = M[5], m6 = M[6], m7 = M[7], m8 = M[8], m9 = M[9], m10 = M[10], m11 = M[11], m12 = M[12], m13 = M[13], m14 = M[14], m15 = M[15];
		I[@ 0]  = m5 * m10 * m15 - m5 * m11 * m14 - m9 * m6 * m15 + m9 * m7 * m14 +m13 * m6 * m11 - m13 * m7 * m10;
		I[@ 1]  = -m1 * m10 * m15 + m1 * m11 * m14 + m9 * m2 * m15 - m9 * m3 * m14 - m13 * m2 * m11 + m13 * m3 * m10;
		I[@ 2]  = m1 * m6 * m15 - m1 * m7 * m14 - m5 * m2 * m15 + m5 * m3 * m14 + m13 * m2 * m7 - m13 * m3 * m6;
		I[@ 3]  = -m1 * m6 * m11 + m1 * m7 * m10 + m5 * m2 * m11 - m5 * m3 * m10 - m9 * m2 * m7 + m9 * m3 * m6;
		I[@ 4]  = -m4 * m10 * m15 + m4 * m11 * m14 + m8 * m6 * m15 - m8 * m7 * m14 - m12 * m6 * m11 + m12 * m7 * m10;
		I[@ 5]  = m0 * m10 * m15 - m0 * m11 * m14 - m8 * m2 * m15 + m8 * m3 * m14 + m12 * m2 * m11 - m12 * m3 * m10;
		I[@ 6]  = -m0 * m6 * m15 + m0 * m7 * m14 + m4 * m2 * m15 - m4 * m3 * m14 - m12 * m2 * m7 + m12 * m3 * m6;
		I[@ 7]  = m0 * m6 * m11 - m0 * m7 * m10 - m4 * m2 * m11 + m4 * m3 * m10 + m8 * m2 * m7 - m8 * m3 * m6;
		I[@ 8]  = m4 * m9 * m15 - m4 * m11 * m13 - m8 * m5 * m15 + m8 * m7 * m13 + m12 * m5 * m11 - m12 * m7 * m9;
		I[@ 9]  = -m0 * m9 * m15 + m0 * m11 * m13 + m8 * m1 * m15 - m8 * m3 * m13 - m12 * m1 * m11 + m12 * m3 * m9;
		I[@ 10] = m0 * m5 * m15 - m0 * m7 * m13 - m4 * m1 * m15 + m4 * m3 * m13 + m12 * m1 * m7 - m12 * m3 * m5;
		I[@ 11] = -m0 * m5 * m11 + m0 * m7 * m9 + m4 * m1 * m11 - m4 * m3 * m9 - m8 * m1 * m7 + m8 * m3 * m5;
		I[@ 12] = m12 * (m6 * m9  - m5 * m10) + m13 * (m4 * m10 - m8 * m6)  + m14 * (m8 * m5 - m4 * m9);
		I[@ 13] = m12 * (m1 * m10 - m2 * m9)  + m13 * (m8 * m2  - m0 * m10) + m14 * (m0 * m9 - m8 * m1);
		I[@ 14] = m12 * (m5 * m2  - m1 * m6)  + m13 * (m0 * m6  - m4 * m2)  + m14 * (m4 * m1 - m0 * m5);
		I[@ 15] = m0 * m5 * m10 - m0 * m6 * m9 - m4 * m1 * m10 + m4 * m2 * m9 + m8 * m1 * m6 - m8 * m2 * m5;
		var _det = m0 * I[0] + m1 * I[4] + m2 * I[8] + m3 * I[12];
		if (_det == 0)
		{
			log("Error in function smf_mat_invert: The determinant is zero.");
			return I;
		}
		_det = 1 / _det;
		for(var i = 0; i < 16; i++)
		{
			I[@ i] *= _det;
		}
		return I;
	}
	
	static rename_bone = function(boneInd, name)
	{
		var bone = data[boneInd];
		if !is_string(name) || name="" return false
		if bone.name!="" ds_map_delete(reference, bone.name);
		bone.name = name;
		ds_map_add(reference, bone.name, bone.index);
		return true;
	}
	static rotate_bone = function(boneInd, Qx, Qy, Qz, Qw, local=true, rotateChilds=false)
	{
		var r0 = Qx, r1 = Qy, r2 = Qz, r3 = Qw;
		var b = boneInd * 8;
		// Get current bone transform
		var s0 = buffer_peek(transform, 4*(b+0), buffer_f32);
		var s1 = buffer_peek(transform, 4*(b+1), buffer_f32);
		var s2 = buffer_peek(transform, 4*(b+2), buffer_f32);
		var s3 = buffer_peek(transform, 4*(b+3), buffer_f32);
		// Multiply transform dualquat
		if local
		{
			Qx = s3 * r0 + s0 * r3 + s1 * r2 - s2 * r1;
			Qy = s3 * r1 + s1 * r3 + s2 * r0 - s0 * r2;
			Qz = s3 * r2 + s2 * r3 + s0 * r1 - s1 * r0;
			Qw = s3 * r3 - s0 * r0 - s1 * r1 - s2 * r2;
		} else {
			Qx = r3 * s0 + r0 * s3 + r1 * s2 - r2 * s1;
			Qy = r3 * s1 + r1 * s3 + r2 * s0 - r0 * s2;
			Qz = r3 * s2 + r2 * s3 + r0 * s1 - r1 * s0;
			Qw = r3 * s3 - r0 * s0 - r1 * s1 - r2 * s2;
		}
		// Write bone transform
		bone_set_rotation(boneInd, Qx, Qy, Qz, Qw);
		if rotateChilds
		{
			var bind = bindmap[boneInd]
			var s = array_length(bind)
			for(var i=0; i<s; i++)
			{
				var bone = bind[i];
				if bone.inherit continue;
				var b = bone.index * 8;
				// Get current bone transform
				var s0 = buffer_peek(transform, 4*(b+0), buffer_f32);
				var s1 = buffer_peek(transform, 4*(b+1), buffer_f32);
				var s2 = buffer_peek(transform, 4*(b+2), buffer_f32);
				var s3 = buffer_peek(transform, 4*(b+3), buffer_f32);
				// Multiply transform dualquat
				if local
				{
					Qx = s3 * r0 + s0 * r3 + s1 * r2 - s2 * r1;
					Qy = s3 * r1 + s1 * r3 + s2 * r0 - s0 * r2;
					Qz = s3 * r2 + s2 * r3 + s0 * r1 - s1 * r0;
					Qw = s3 * r3 - s0 * r0 - s1 * r1 - s2 * r2;
				} else {
					Qx = r3 * s0 + r0 * s3 + r1 * s2 - r2 * s1;
					Qy = r3 * s1 + r1 * s3 + r2 * s0 - r0 * s2;
					Qz = r3 * s2 + r2 * s3 + r0 * s1 - r1 * s0;
					Qw = r3 * s3 - r0 * s0 - r1 * s1 - r2 * s2;
				}
				// Write bone transform
				bone_set_rotation(bone.index, Qx, Qy, Qz, Qw)
			}
		}
	}
	static move_bone = function(boneInd, xspeed, yspeed, zspeed)
	{
		var b = boneInd * 8;
		// Get current bone transform
		var s0 = buffer_peek(transform, 4*(b+4), buffer_f32);
		var s1 = buffer_peek(transform, 4*(b+5), buffer_f32);
		var s2 = buffer_peek(transform, 4*(b+6), buffer_f32);
		bone_set_position(boneInd, s0+xspeed, s1+yspeed, s2+zspeed)
	}
	static bone_set_position = function(boneInd, x, y, z)
	{
		var b = boneInd * 8;
		buffer_poke(transform, 4*(b+4), buffer_f32, x);
		buffer_poke(transform, 4*(b+5), buffer_f32, y);
		buffer_poke(transform, 4*(b+6), buffer_f32, z);
	}
	static bone_set_rotation = function(boneInd, Qx, Qy, Qz, Qw)
	{
		var b = boneInd * 8;
		// Write bone transform
		buffer_poke(transform, 4*(b+0), buffer_f32, Qx);
		buffer_poke(transform, 4*(b+1), buffer_f32, Qy);
		buffer_poke(transform, 4*(b+2), buffer_f32, Qz);
		buffer_poke(transform, 4*(b+3), buffer_f32, Qw);
	}
	static update_transform = function(start=0, buffer = transform, uniform = animate)
	{
		// Construct animation transformation from rotations.
		// After calculating rotation, apply transform to children bone, but only direct-descendant to reduce excess calculation
		var r0, r1, r2, r3, r4, r5, r6, r7, f0, f1, f2, f3, f4, f5, f6, f7
		for(var i=start; i<size; i++)
		{
			var bone = data[i];
			if bone.link<0
			{
				var b = i * 8;
				r0 = buffer_peek(buffer, 4*(b+4), buffer_f32);
				r1 = buffer_peek(buffer, 4*(b+5), buffer_f32);
				r2 = buffer_peek(buffer, 4*(b+6), buffer_f32);
				bone.x = bone.Ox+r0;	bone.y = bone.Oy+r1;	bone.z = bone.Oz+r2;
			}
			if !bone.inherit
			{
				var b = i * 8;
				// Get transform dualquat
				r0 = buffer_peek(buffer, 4*(b+0), buffer_f32);
				r1 = buffer_peek(buffer, 4*(b+1), buffer_f32);
				r2 = buffer_peek(buffer, 4*(b+2), buffer_f32);
				r3 = buffer_peek(buffer, 4*(b+3), buffer_f32);
				r4 = bone.Oy * r2 - bone.Oz * r1;
				r5 = bone.Oz * r0 - bone.Ox * r2;
				r6 = bone.Ox * r1 - bone.Oy * r0;
				r7 = 0;
		
				// Add parent's transform offset to transform
				f4=.5*(bone.x-bone.Ox);
				f5=.5*(bone.y-bone.Oy);
				f6=.5*(bone.z-bone.Oz);
				r4 = r4 + f4 * r3 + f5 * r2 - f6 * r1;
				r5 = r5 - f4 * r2 + f5 * r3 + f6 * r0;
				r6 = r6 + f4 * r1 - f5 * r0 + f6 * r3;
				r7 = r7 - f4 * r0 - f5 * r1 - f6 * r2;
		
				// Write transformation into uniform buffer
				buffer_poke(uniform, 4*(b+0), buffer_f32, r0);
				buffer_poke(uniform, 4*(b+1), buffer_f32, r1);
				buffer_poke(uniform, 4*(b+2), buffer_f32, r2);
				buffer_poke(uniform, 4*(b+3), buffer_f32, r3);
				buffer_poke(uniform, 4*(b+4), buffer_f32, r4);
				buffer_poke(uniform, 4*(b+5), buffer_f32, r5);
				buffer_poke(uniform, 4*(b+6), buffer_f32, r6);
				buffer_poke(uniform, 4*(b+7), buffer_f32, r7);
			
				// Translate bone position
				var s = array_length(bone.heirs);
				for(var h=0; h<s; h++)
				{
					var heir = bone.heirs[h]
					var b = heir.index * 8;
					var vx = heir.Vx + buffer_peek(buffer, 4*(b+4), buffer_f32);
					var vy = heir.Vy + buffer_peek(buffer, 4*(b+5), buffer_f32);
					var vz = heir.Vz + buffer_peek(buffer, 4*(b+6), buffer_f32);
					var xx = r3*r3*vx + 2*r1*r3*vz - 2*r2*r3*vy + r0*r0*vx + 2*r1*r0*vy + 2*r2*r0*vz - r2*r2*vx - r1*r1*vx;
					var yy = 2*r0*r1*vx + r1*r1*vy + 2*r2*r1*vz + 2*r3*r2*vx - r2*r2*vy + r3*r3*vy - 2*r0*r3*vz - r0*r0*vy;
					var zz = 2*r0*r2*vx + 2*r1*r2*vy + r2*r2*vz - 2*r3*r1*vx - r1*r1*vz + 2*r3*r0*vy - r0*r0*vz + r3*r3*vz;
					heir.x = bone.x + xx;
					heir.y = bone.y + yy;
					heir.z = bone.z + zz;
				}
			} else {
				var link = data[bone.link];
				// Get parent bone's rotations
				var b = link.index*8
				var i0 = buffer_peek(uniform, 4*(b+0), buffer_f32);
				var i1 = buffer_peek(uniform, 4*(b+1), buffer_f32);
				var i2 = buffer_peek(uniform, 4*(b+2), buffer_f32);
				var i3 = buffer_peek(uniform, 4*(b+3), buffer_f32);
				var b = i * 8;
				// Get transform dualquat
				var b0 = buffer_peek(buffer, 4*(b+0), buffer_f32);
				var b1 = buffer_peek(buffer, 4*(b+1), buffer_f32);
				var b2 = buffer_peek(buffer, 4*(b+2), buffer_f32);
				var b3 = buffer_peek(buffer, 4*(b+3), buffer_f32);
				r0 = b3 * i0 + b0 * i3 + b1 * i2 - b2 * i1;
				r1 = b3 * i1 - b0 * i2 + b1 * i3 + b2 * i0;
				r2 = b3 * i2 + b0 * i1 - b1 * i0 + b2 * i3;
				r3 = b3 * i3 - b0 * i0 - b1 * i1 - b2 * i2;
				r4 = bone.Oy * r2 - bone.Oz * r1;
				r5 = bone.Oz * r0 - bone.Ox * r2;
				r6 = bone.Ox * r1 - bone.Oy * r0;
				r7 = 0;
			
				// Add parent's transformation
				f4=.5*(bone.x-bone.Ox);
				f5=.5*(bone.y-bone.Oy);
				f6=.5*(bone.z-bone.Oz);
				r4 = r4 + f4 * r3 + f5 * r2 - f6 * r1;
				r5 = r5 - f4 * r2 + f5 * r3 + f6 * r0;
				r6 = r6 + f4 * r1 - f5 * r0 + f6 * r3;
				r7 = r7 - f4 * r0 - f5 * r1 - f6 * r2;
			
				// Write transformation into uniform buffer
				buffer_poke(uniform, 4*(b+0), buffer_f32, r0);
				buffer_poke(uniform, 4*(b+1), buffer_f32, r1);
				buffer_poke(uniform, 4*(b+2), buffer_f32, r2);
				buffer_poke(uniform, 4*(b+3), buffer_f32, r3);
				buffer_poke(uniform, 4*(b+4), buffer_f32, r4);
				buffer_poke(uniform, 4*(b+5), buffer_f32, r5);
				buffer_poke(uniform, 4*(b+6), buffer_f32, r6);
				buffer_poke(uniform, 4*(b+7), buffer_f32, r7);
			
				// Translate bone position
				var s = array_length(bone.heirs);
				for(var h=0; h<s; h++)
				{
					var heir = bone.heirs[h]
					var b = heir.index * 8;
					var vx = heir.Vx + buffer_peek(buffer, 4*(b+4), buffer_f32);
					var vy = heir.Vy + buffer_peek(buffer, 4*(b+5), buffer_f32);
					var vz = heir.Vz + buffer_peek(buffer, 4*(b+6), buffer_f32);
					var xx = r3*r3*vx + 2*r1*r3*vz - 2*r2*r3*vy + r0*r0*vx + 2*r1*r0*vy + 2*r2*r0*vz - r2*r2*vx - r1*r1*vx;
					var yy = 2*r0*r1*vx + r1*r1*vy + 2*r2*r1*vz + 2*r3*r2*vx - r2*r2*vy + r3*r3*vy - 2*r0*r3*vz - r0*r0*vy;
					var zz = 2*r0*r2*vx + 2*r1*r2*vy + r2*r2*vz - 2*r3*r1*vx - r1*r1*vz + 2*r3*r0*vy - r0*r0*vz + r3*r3*vz;
					heir.x = bone.x + xx;
					heir.y = bone.y + yy;
					heir.z = bone.z + zz;
				}
			}
		}
	}
	static reset_transform = function(boneInd=-1, identity=true)
	{
		if boneInd<0
		{
			buffer_seek(transform, buffer_seek_start, 0)
			for(var i=0; i<size; i++) buffer_writes(transform, buffer_f32, 0, 0, 0, 1, 0, 0, 0, 1)
		} else {
			var b = boneInd * 8
			buffer_seek(transform, buffer_seek_start, 4*b);
			buffer_writes(transform, buffer_f32, 0, 0, 0, 1, 0, 0, 0, 1)
			var bone = data[boneInd]
			var dat = bone.childs;
			var s = array_length(dat);
			for(var i=0; i<s; i++)
			{
				b = dat[i] * 8;
				buffer_seek(transform, buffer_seek_start, 4*b)
				buffer_writes(transform, buffer_f32, 0, 0, 0, 1, 0, 0, 0, 1)
			}
		}
		update_transform(undefined)
	}
}

function skeleton_set_uniform(skeleton, shader=shader_current())
{
	static uniform3D = shader_get_uniform(Animation3DShader, "u_boneDQ");
	static uniformSprite = shader_get_uniform(AnimationSpriteShader, "u_boneDQ");
	static uniformVoxel = shader_get_uniform(AnimationVoxelShader, "u_boneDQ");
	var set = false;
	switch(shader)
	{
		case Animation3DShader:
			shader_set_uniform_f_buffer(uniform3D, skeleton.animate, 0, 8*skeleton.size); set=true
			break
			
		case AnimationSpriteShader:
			shader_set_uniform_f_buffer(uniformSprite, skeleton.animate, 0, 8*skeleton.size); set = true
			break
			
		case AnimationVoxelShader:
			shader_set_uniform_f_buffer(uniformVoxel, skeleton.animate, 0, 8*skeleton.size); set = true
			break
	}
	if !set shader_set_uniform_f_buffer(shader_get_uniform(shader, "u_boneDQ"), skeleton.animate, 0, 8*skeleton.size);
}
function skeleton_set_identity(skeleton, shader=shader_current())
{

	static get_buff = function()
	{
		var buff = buffer_create(AnimMaxBone*mBuffAnimBytesPerVert, buffer_fixed, 4);
		for(var i=0; i<AnimMaxBone; i++) {buffer_poke(buff, 4*(i*8+3), buffer_f32, 1.);}
		return buff
	}
	static AnimIdentity = get_buff();
	static uniform3D = shader_get_uniform(Animation3DShader, "u_boneDQ");
	static uniformSprite = shader_get_uniform(AnimationSpriteShader, "u_boneDQ");
	static uniformVoxel = shader_get_uniform(AnimationVoxelShader, "u_boneDQ");
	var set = false;
	switch(shader)
	{
		case Animation3DShader:
			shader_set_uniform_f_buffer(uniform3D, AnimIdentity, 0, 8*skeleton.size); set=true
			break
			
		case AnimationSpriteShader:
			shader_set_uniform_f_buffer(uniformSprite, AnimIdentity, 0, 8*skeleton.size); set = true
			break
			
		case AnimationVoxelShader:
			shader_set_uniform_f_buffer(uniformVoxel, AnimIdentity, 0, 8*skeleton.size); set = true
			break
	}
	if !set shader_set_uniform_f_buffer(shader_get_uniform(shader, "u_boneDQ"), AnimIdentity, 0, 8*skeleton.size);
}
function skeleton_save(skeleton, file)
{
	var f = file_text_open_write(file);
	var dat = variable_clone(skeleton.data, 16), bone;
	var s = array_length(dat)
	for(var i=0;i<s;i++) {bone = dat[i]; struct_remove(bone, "childs"); struct_remove(bone, "heirs")}
	file_text_write_string(f, json_stringify(dat));
	file_text_close(f);
	delete dat;
	log("Skeleton data saved: "+string(file))
}
function skeleton_load(file)
{
	if !file_exists(file) {log("SKeleton file not found "+string(file),"error");return false}
	var f = file_text_open_read(file);
	var d = file_text_read_string(f);
	file_text_close(f);
	var data = json_parse(d);
	var skeleton = new skeleton_create(data);
	var s = array_length(data);
	for(var i=0; i<s; i++)
	{	
		struct_inherit(data[i], bone_struct);
	}
	skeleton.data[0].link=-1;
	skeleton.update_links();
	return skeleton;
}

function skeleton_rotate_axis(skeleton, boneInd, radians, aX, aY, aZ, local=false, childs=false) 
{
	// This function rotate bone axis in world-space or local-space from it's current transformation.
	// it does not consider the bone's pivot (Direction toward its parent's bone)
	radians /= 2;
	var s = sin(radians);
	var Qx, Qy, Qz, Qw
	Qx = aX * s;
	Qy = aY * s;
	Qz = aZ * s;
	Qw = cos(radians);
	
	skeleton.rotate_bone(boneInd, Qx, Qy, Qz, Qw, local, childs);
	skeleton.update_transform(boneInd);
	return true
}
function skeleton_rotate_bone_axis(skeleton, boneInd, radians, aX, aY, aZ, childs)
{
	// This function rotate bone axis in local-space, considering it's pivot (Direction toward its parent's bone).
	// rotating x axis will roll the bone.
	var q;
	q[@0] = 0; q[@1]=0; q[@2]=0; q[@3]=1.0001;
	var bone = skeleton.data[boneInd];
	if (bone.Vx==0 && bone.Vy==0) {yaw=0; pitch=90}
	else {
		var yaw = point_direction(0,0,bone.Vx, bone.Vy);
		var pitch = point_direction(0,0, point_distance(0,0,bone.Vx, bone.Vy), bone.Vz);
	}
	angle_to_quaternion(0, pitch, -yaw, q);
	var sample = skeleton_get_sample_transform(skeleton, boneInd)
	quaternion_multiply(sample, q, q);
	
	var axis = quaternion_transform_vector(q, aX, aY, aZ)
	skeleton_rotate_axis(skeleton, boneInd, radians, axis[0], axis[1], axis[2], false, childs)
}
function skeleton_roll_bone(skeleton, boneInd, radians, childs)
{
	// Simply roll the bone around it's armature.
	var q;
	q[@0] = 0; q[@1]=0; q[@2]=0; q[@3]=1.0001;
	var bone = skeleton.data[boneInd];
	var Ax, Ay, Az
	if is_nan(bone.Ax)
	{
		var link = skeleton.data[bone.Ay];
		Ax = link.Ox - bone.Ox;
		Ay = link.Oy - bone.Oy;
		Az = link.Oz - bone.Oz;
	} else {
		Ax = bone.Ax;
		Ay = bone.Ay;
		Az = bone.Az;
	}
	var yaw = point_direction(0,0,Ax, Ay);
	var pitch = point_direction(0,0, point_distance(0,0, Ax, Ay), Az);
	angle_to_quaternion(0, pitch, -yaw, q);
	var sample = skeleton_get_sample_transform(skeleton, boneInd)
	quaternion_multiply(sample, q, q);
	
	var axis = quaternion_transform_vector(q, 1, 0, 0);
	normalize(axis)
	skeleton_rotate_axis(skeleton, boneInd, radians, axis[0], axis[1], axis[2], false, childs)
}
function skeleton_rotate_bone_toward(skeleton, boneInd, x, y, z, childs=false)
{
	// Rotate a bone toward a specific direction using shortest path.
	// For editor, it may not represent the rotation you want.
	if boneInd == 0 return false;
	var bone = skeleton.data[boneInd];
	var link = skeleton.data[bone.link];
	var v0 = [bone.x - link.x, bone.y - link.y, bone.z - link.z]
	var v1 = [x - link.x, y - link.y, z - link.z]
	
	var d = dot_product_3d(v0[0], v0[1], v0[2], v1[0], v1[1], v1[2]);
	var m1 = magnitude(v0[0], v0[1], v0[2]);
	var m2 = magnitude(v1[0], v1[1], v1[2]);
	var angle = arccos( d/(m1*m2))
	
	if angle==0 return false;
	if angle==pi/2 {if abs(v0[2])=1 cross_product(v0, [0,1,0], v0) else cross_product(v0, [0,0,1], v0)
	} else {cross_product(v0, v1, v0);}
	normalize(v0);
	skeleton_rotate_axis(skeleton, bone.link, angle, v0[0], v0[1], v0[2], false, childs)
}
function skeleton_rotate_armature(skeleton, boneInd, x, y, z, childs=false)
{
	// Rotate a bone armature toward a specific direction using shortest path.
	// For editor, it may not represent the rotation you want.
	var bone = skeleton.data[boneInd];
	var sample = skeleton_get_sample_transform(skeleton, boneInd)
	var v0 = quaternion_transform_vector(sample, bone.Ax, bone.Ay, bone.Az);
	if is_nan(bone.Ax) return false; // bone is linked, no armature
	var v1 = [x - bone.x, y - bone.y, z - bone.z]
	normalize(v0);
	normalize(v1);
	
	var a = dot_product_3d(v0[0], v0[1], v0[2], v1[0], v1[1], v1[2]);
	if (a == 1) return false;
	if (a == -1) return false;
	var angle = (1-a)*pi;
	cross_product(v0, v1, v0);
	normalize(v0);
	skeleton_rotate_axis(skeleton, boneInd, angle, v0[0], v0[1], v0[2], false, childs)
}
function skeleton_move_bone(skeleton, boneInd, x, y, z)
{
	// Move point toward a specific position; Does not rotation bone.
	var bone = skeleton.data[boneInd];
	var xx = x - bone.x;
	var yy = y - bone.y;
	var zz = z - bone.z;
	if bone.link<0 || bone.link==bone.index
	{
		skeleton.move_bone(boneInd, xx, yy, zz);
		skeleton.update_transform(0);
		var sample = skeleton_get_sample_transform(skeleton, boneInd)
		return true;
	} else {
		var pivot = skeleton_get_sample_transform(skeleton, bone.link)
		pivot[@0] *= -1;
		pivot[@1] *= -1;
		pivot[@2] *= -1;
		var vec = quaternion_transform_vector(pivot, xx, yy, zz);
		skeleton.move_bone(boneInd, vec[0], vec[1], vec[2]);
		skeleton.update_transform(bone.link);
		return true;
	}
}
function skeleton_get_bone_inherit(skeleton, boneInd)
{
	var dat = skeleton.data;
	var bone = dat[boneInd];
	return bone.inherit;
}
function skeleton_set_bone_inherit(skeleton, boneInd, inherit)
{
	var dat = skeleton.data;
	var bone = dat[boneInd];
	bone.inherit = inherit;
	var s = array_length(bone.childs)
	for(var i=0; i<s; i++)
	{
		var child = dat[bone.childs[i]];
		child.inherit = inherit;
	}
	skeleton.update_transform(boneInd);
}
function skeleton_get_sample_transform(skeleton, boneInd, output=array_create(8))
{
	// Get the transform uniform (gpu data)
	var buff = skeleton.animate;
	var b = boneInd*8;
	output[@0] = buffer_peek(buff, 4*(b+0), buffer_f32);
	output[@1] = buffer_peek(buff, 4*(b+1), buffer_f32);
	output[@2] = buffer_peek(buff, 4*(b+2), buffer_f32);
	output[@3] = buffer_peek(buff, 4*(b+3), buffer_f32);
	output[@4] = buffer_peek(buff, 4*(b+4), buffer_f32);
	output[@5] = buffer_peek(buff, 4*(b+5), buffer_f32);
	output[@6] = buffer_peek(buff, 4*(b+6), buffer_f32);
	output[@7] = buffer_peek(buff, 4*(b+7), buffer_f32);
	return output;
}
function skeleton_get_transform(skeleton, boneInd, output=array_create(8))
{
	// Get the animation transform of the bone (animation data)
	var buff = skeleton.transform;
	var b = boneInd*8;
	output[@0] = buffer_peek(buff, 4*(b+0), buffer_f32);
	output[@1] = buffer_peek(buff, 4*(b+1), buffer_f32);
	output[@2] = buffer_peek(buff, 4*(b+2), buffer_f32);
	output[@3] = buffer_peek(buff, 4*(b+3), buffer_f32);
	output[@4] = buffer_peek(buff, 4*(b+4), buffer_f32);
	output[@5] = buffer_peek(buff, 4*(b+5), buffer_f32);
	output[@6] = buffer_peek(buff, 4*(b+6), buffer_f32);
	output[@7] = buffer_peek(buff, 4*(b+7), buffer_f32);
	return output;
}
function skeleton_delete_bone(skeleton, boneInd, mbuff=[])
{
	var bone;
	ds_list_clear(global.temp_list);
	var size = skeleton.size;
	if size==1 return false;
	for(var i=0; i<size; i++)
	{
		bone = skeleton.data[i]
		//if i==boneInd bone=skeleton.data[bone.link];
		ds_list_set(global.temp_list, i, bone);
	}
	var bone = skeleton.data[boneInd];
	if !(bone.link<0 )
	{
		var link = skeleton.data[bone.link];
		ds_list_set(global.temp_list, bone.index, link);
	}
	var s = array_length(bone.childs);
	for(var i=0; i<s; i++)
	{
		log("override childs: "+string(bone.childs[i])+" with "+string(link.index))
		ds_list_set(global.temp_list, bone.childs[i], link)
	}
	
	skeleton.delete_bone(boneInd, false)
	
	var s = array_length(mbuff)
	for(var i=0; i<s; i++)
	{
		rebuild_anim_buffer_indice(mbuff[i], global.temp_list)
	}
	ds_list_clear(global.temp_list);
}
function skeleton_delete_bone_rebind(skeleton, boneInd, rebind, mbuff=[])
{
	log("Rebind "+string(boneInd)+" to "+string(rebind))
	var bone, bind;
	ds_list_clear(global.temp_list);
	var size = skeleton.size;
	for(var i=0; i<size; i++)
	{
		bone = skeleton.data[i]
		if i==boneInd bone=skeleton.data[bone.link];
		ds_list_set(global.temp_list, i, bone);
	}
	bone = skeleton.data[boneInd];
	bind = skeleton.data[rebind];
	var s = array_length(bone.heirs);
	for(var i=0; i<s; i++)
	{
		var b = bone.heirs[i];
		b.link = bind.index;
	}
	skeleton.update_links();
	skeleton.delete_bone(boneInd)
	
	var s = array_length(mbuff)
	for(var i=0; i<s; i++)
	{
		rebuild_anim_buffer_indice(mbuff[i], global.temp_list)
	}
	ds_list_clear(global.temp_list);
}

function skeleton_simple_IK(skeleton, boneInd, x, y, z, childs=false, stretch=true)
{
	//	Simple 2-bones Inverse Kinematic using basic geometry, the bones automatically bends at it's current angle to reach the target xyz;
	//	If target is out of reach, stretch the bone out with simple transform (disable with stretch=false);
	static rotate_toward = function(skeleton, boneInd, v0, v1, childs)
	{
		var d = dot_product_3d(v0[0], v0[1], v0[2], v1[0], v1[1], v1[2]);
		var m1 = magnitude(v0[0], v0[1], v0[2]);
		var m2 = magnitude(v1[0], v1[1], v1[2]);
		var angle = arccos( d/(m1*m2))
	
		if angle==0 return false;
		if angle==pi/2 {if abs(v0[2])=1 cross_product(v0, unit_Yaxis, v0) else cross_product(v0, unit_Zaxis, v0)
		} else {cross_product(v0, v1, v0);}
		normalize(v0);
		
		angle /= 2;
		var s = sin(angle);
		var Qx, Qy, Qz, Qw
		Qx = v0[0]*s;
		Qy = v0[1]*s;
		Qz = v0[2]*s;
		Qw = cos(angle);
		skeleton.rotate_bone(boneInd, Qx, Qy, Qz, Qw, false, childs);
		return true
	}
	
	// Ignore if connected bone are origin bone (0);
	var bone = skeleton.data[boneInd]
	if bone.link==0 {skeleton_rotate_bone_toward(skeleton, boneInd, x, y, z, childs); return false};
	var link = skeleton.data[bone.link];
	if link.link==0 {skeleton_rotate_bone_toward(skeleton, boneInd, x, y, z, childs); return false};
	var root = skeleton.data[link.link];
	if bone.x==x && bone.y==y && bone.z==z return false;
	
	// Length of current IK joints
	var length1 = point_distance_3d(bone.Ox,bone.Oy,bone.Oz,link.Ox,link.Oy,link.Oz);
	var length2 = point_distance_3d(link.Ox,link.Oy,link.Oz,root.Ox,root.Oy,root.Oz);
	var distance = point_distance_3d(x,y,z,root.x,root.y,root.z);
		
	// Get relative rotation
	static v0 = array_create(3);
	static v1 = array_create(3);
	static quat = array_create(4);
	v0[@0]=bone.x-root.x;	v0[@1]=bone.y-root.y;	v0[@2]=bone.z-root.z
	v1[@0]=x-root.x;	v1[@1]=y-root.y		v1[@2]=z-root.z;
	quaternion_vector_angle(v0, v1, quat)
	normalize(v1);
	
	// Get perpendicular (bending vector)
	static vec = array_create(3);
	if abs(dot_product_3d_normalized(bone.x-link.x, bone.y-link.y, bone.z-link.z, link.x-root.x, link.y-root.y, link.z-root.z))==1 // (edge case)
	{
		if bone.y!=link.y vec=cross_product([bone.x-link.x, bone.y-link.y, bone.z-link.z], unit_Yaxis, vec) else vec=cross_product([bone.x-link.x, bone.y-link.y, bone.z-link.z], unit_Xaxis, vec)
	} else {
		var pos = line_perpendicular_3d(root.x, root.y, root.z, bone.x, bone.y, bone.z, link.x, link.y, link.z);
		vec[@0] = link.x - pos[0];
		vec[@1] = link.y - pos[1];
		vec[@2] = link.z - pos[2];
	}
	normalize(vec);
	quaternion_transform_vector(quat, vec[0], vec[1], vec[2], vec);
	
	// Get 2D IK
	var threshold = 0.001
	var dist = clamp(distance, abs(length2-length1)*(1+threshold), (length1+length2)*(1-threshold));
	var p = circle_intersect_circle(0,0,length2, dist, 0, length1);
	if is_undefined(p) {return false;}
	var t = p[0];
	var up = abs(p[1])
	
	// Bone rotate
	if stretch {skeleton.bone_set_position(boneInd, 0,0,0);skeleton.bone_set_position(link.index, 0,0,0)}
	//skeleton_rotate_bone_toward(skeleton, link.index, root.x+v1[0]*t+vec[0]*up, root.y+v1[1]*t+vec[1]*up, root.z+v1[2]*t+vec[2]*up, false);
	//skeleton_rotate_bone_toward(skeleton, boneInd, x, y, z, childs);
	//static rotate_toward = function(skeleton, boneInd, vector1, vector2, childs)
	//var v0 = [bone.x - link.x, bone.y - link.y, bone.z - link.z]
	//var v1 = [x - link.x, y - link.y, z - link.z]
	v0[@0] = v1[0]*t+vec[0]*up;
	v0[@1] = v1[1]*t+vec[1]*up;
	v0[@2] = v1[2]*t+vec[2]*up;
	vec[@0]=link.x-root.x;	vec[@1]=link.y-root.y;	vec[@2]=link.z-root.z
	rotate_toward(skeleton, root.index, vec, v0, false);
	v1[@0] = x-(root.x+v0[0]);
	v1[@1] = y-(root.y+v0[1]);
	v1[@2] = z-(root.z+v0[2]);
	vec[@0]=bone.x-link.x;	vec[@1]=bone.y-link.y;	vec[@2]=bone.z-link.z
	rotate_toward(skeleton, link.index, vec, v1, false);
	
	// Bone stretching
	if stretch && distance>dist
	{
		dist = distance-dist;
		var l1 = length1/(length1+length2);
		var l2 = length2/(length1+length2);
		
		v0[@0] = link.Ox-root.Ox;
		v0[@1] = link.Oy-root.Oy;
		v0[@2] = link.Oz-root.Oz;
		normalize(v0);
		skeleton.bone_set_position(link.index, v0[0]*dist*l2, v0[1]*dist*l2, v0[2]*dist*l2);
		
		v0[@0] = bone.Ox-link.Ox;
		v0[@1] = bone.Oy-link.Oy;
		v0[@2] = bone.Oz-link.Oz;
		normalize(v0);
		skeleton.bone_set_position(boneInd, v0[0]*dist*l1, v0[1]*dist*l1, v0[2]*dist*l1);
	}
	skeleton.update_transform(root.index);
	return true;
}
function skeleton_bind_bones(skeleton, boneInd, bindskeleton, bindInd, x, y, z, rotation=-1)
{
	/*	Bind a skeleton bone to another skeleton bone, making it 'stick' and follow it's movement.
		"rotation" is the origin-rotation of the bone when follow bind-bone rotation, it should be an array containing quaternion unit;
			If no rotation is provided, use the bone's current rotation by default.			
		Return a struct containing binding data; this data then can be use with skeleton_bind_transform_step() or skeleton_bind_IK_step()
		
		skeleton_bind_transform_step() will make the bone follow with simple transform (may cause stretching), design to make item (unlinked bone) attach to hand-bone;
		skeleton_bind_IK_step() will make the bone follow using inverse-kinematic;
		boneInd of skeleton will bind and follow bindskeleton's bindInd bone movement.
		
		When you no longer want it to bind simply stop using said function and delete this struct.			*/
	var bind = bindskeleton.data[bindInd];
	var pos = [x-bind.x, y-bind.y, z-bind.z];
	var sample = skeleton_get_sample_transform(bindskeleton, bindInd);
	quaternion_conjugate(sample)
	quaternion_transform_vector(sample, pos[0], pos[1], pos[2], pos);
	var rot;
	if is_array(rotation) {rot=rotation} else {rot = skeleton_get_sample_transform(skeleton, boneInd);}
	var idendity = quaternion_multiply(sample, rot);
	return
	{
		skeleton: skeleton,
		boneInd: boneInd,
		bindskeleton: bindskeleton,
		bindInd: bindInd,
		Ox: pos[0], Oy: pos[1], Oz: pos[2],
		x:x, y:y, z:z,
		idendity: idendity
	}
}
function skeleton_bind_IK_step(struct, stretch)
{
	// Calculate inverse kinematic to make a bone 'stick' to another bone;
	// Must use skeleton_bind_bones() to get the binding data first.
	static pos = array_create(3);
	static sample = array_create(8);
	var boneInd = struct.boneInd
	var skeleton = struct.skeleton;
	var bindskeleton = struct.bindskeleton;
	var bindInd = struct.bindInd
	// Get transformation
	skeleton_get_sample_transform(bindskeleton, bindInd, sample);
	quaternion_transform_vector(sample, struct.Ox, struct.Oy, struct.Oz, pos);
	var bind = bindskeleton.data[bindInd];
	struct.x = bind.x + pos[0];
	struct.y = bind.y + pos[1];
	struct.z = bind.z + pos[2];
	quaternion_multiply(sample, struct.idendity, sample);
	// Transform bone
	skeleton.bone_set_rotation(boneInd, sample[0], sample[1], sample[2], sample[3]);
	skeleton_simple_IK(skeleton, boneInd, struct.x, struct.y, struct.z, false, stretch);
}
function skeleton_bind_transform_step(struct)
{
	// Transform a bone to 'stick' to another bone;
	// Must use skeleton_bind_bones() to get the binding data first.
	static pos = array_create(3);
	static sample = array_create(8);
	var boneInd = struct.boneInd
	var skeleton = struct.skeleton;
	var bindskeleton = struct.bindskeleton;
	var bindInd = struct.bindInd
	// Get transformation
	skeleton_get_sample_transform(bindskeleton, bindInd, sample);
	quaternion_transform_vector(sample, struct.Ox, struct.Oy, struct.Oz, pos);
	var bind = bindskeleton.data[bindInd];
	struct.x = bind.x + pos[0];
	struct.y = bind.y + pos[1];
	struct.z = bind.z + pos[2];
	quaternion_multiply(sample, struct.idendity, sample);
	// Transform bone
	skeleton.bone_set_rotation(boneInd, sample[0], sample[1], sample[2], sample[3]);
	skeleton_move_bone(skeleton, boneInd, struct.x, struct.y, struct.z);
}
function skeleton_get_bone_mass(skeleton, boneInd, array=-1)
{
	// Get center of mass of the specific bone
	static sample = array_create(8);
	var bone = skeleton.data[boneInd], m, link
	if is_nan(bone.Ax)
	{
		link = skeleton.data[bone.Ay];
		m = point_distance_3d(bone.x, bone.y, bone.z, link.x, link.y, link.z);
		if !is_array(array) return m;
		array[@0] = (bone.x+link.x)/2;
		array[@1] = (bone.y+link.y)/2;
		array[@2] = (bone.z+link.z)/2;
		array[@3] = m;
		return array
	} else {
		m = point_distance_3d(0,0,0,bone.Ax,bone.Ay,bone.Az)
		if !is_array(array) return m;
		skeleton_get_sample_transform(skeleton, boneInd, sample);
		quaternion_transform_vector(sample, bone.Ax, bone.Ay, bone.Az, array);
		array[@0] = bone.x+array[0]/2;
		array[@1] = bone.y+array[1]/2;
		array[@2] = bone.z+array[2]/2;
		array[@3] = m;
		return array
	}
}
function skeleton_get_mass(skeleton)
{
	//	Calculate centre and mass of each bone as well as entire skeleton.
	//	Based on armature length and position of bones.
	
	// Prepare data structure
	var s = skeleton.size
	var bone, link, M=0, m, mass, r;
	var masses = skeleton[$ "masses"];
	if is_undefined(masses) || array_length(masses)!=s
	{
		masses = array_create(s);
		skeleton.masses = masses;
		for(var i=0; i<s; i++) masses[@i] = array_create(4)
	}
	var sample = array_create(8);
	var centre = array_create(3);
	// Get total mass and mass of each bone;
	for(var i=0; i<s; i++)
	{
		bone = skeleton.data[i];
		mass = masses[i];
		skeleton_get_bone_mass(skeleton, i, mass);
		M+=mass[3];
	}
	var cx=0, cy=0, cz=0;
	for(var i=0; i<s; i++)
	{
		mass = masses[i];
		r = mass[3]/M
		cx+=mass[0]*r
		cy+=mass[1]*r
		cz+=mass[2]*r
	}
	var array=skeleton[$ "center"];
	if is_undefined(array) {array=array_create(4);skeleton.center=array}
	array[@0] = cx;
	array[@1] = cy;
	array[@2] = cz;
	array[@3] = M;
	return array;
}
function skeleton_counter_rotate(skeleton, boneInd, scale=0.5)
{
	//	Rotating a bone also rotate parent bone, imitating physics.
	//	Calculate rotation angle using relative position of center of mass when rotating.
	var bone = skeleton.data[boneInd];
	if bone.link<=0 return true;
	var m, mass=array_create(3), M;
	var v0, v1, mass1, mass2;
	var cx0, cy0, cz0, cx1, cy1, cz1, r;
	
	var link = skeleton.data[bone.link];
	var s = array_length(link.heirs);
	M=skeleton_get_bone_mass(skeleton, link.index);
	for(var i=0; i<s; i++) {M+=skeleton_get_bone_mass(skeleton, link.heirs[i].index)}
	
	// Previous center mass;
	mass1 = skeleton.masses[bone.index];
	mass2 = skeleton.masses[bone.link];
	r = mass1[3]/M;
	cx0 = lerp(mass1[0], mass2[0], r);
	cy0 = lerp(mass1[1], mass2[1], r);
	cz0 = lerp(mass1[2], mass2[2], r);
	
	// Current center mass;
	var mass1 = array_create(4);
	var mass2 = array_create(4);
	skeleton_get_bone_mass(skeleton, boneInd, mass1);
	skeleton_get_bone_mass(skeleton, bone.link, mass2);
	r = mass1[3]/M;
	cx1 = lerp(mass1[0], mass2[0], r);
	cy1 = lerp(mass1[1], mass2[1], r);
	cz1 = lerp(mass1[2], mass2[2], r);
	
	// Get rotation unit
	v0 = [cx0-link.x, cy0-link.y, cz0-link.z];
	v1 = [cx1-link.x, cy1-link.y, cz1-link.z];
	var rotation = quaternion_vector_angle(v0, v1);
	
	static identity = [0,0,0,1];
	quaternion_slerp(identity, rotation, scale, rotation);
	quaternion_normalize(rotation, rotation);
	skeleton.rotate_bone(bone.link, -rotation[0], -rotation[1], -rotation[2], rotation[3], false, false);
	skeleton.update_transform(bone.link);
	skeleton_counter_rotate(skeleton, bone.link)
	return true;
	
}
function skeleton_center_balance(skeleton)
{
	var center = skeleton.center;
	var curr = array_create(4);
	skeleton_get_mass(skeleton, curr);
	if center=-1 {center=curr; skeleton.center=curr}
	
	if center[0]==curr[0] && center[1]==curr[1] && center[2]==curr[2] return false;
	var size = skeleton.size;
	for(var i=0; i<s; i++)
	{
		var bone = skeleton.data[i];
		
	}
}

function skeleton_raycast_bone(skeleton, bone, posx, posy, posz, dirx, diry, dirz)
{
	// Check ray against a bone shape, written as spagetti code to reduce memory reference (array) to calculate as fast as possible
	//	Manually calculate inverse transform without using any matrix.
	if !is_struct(bone) bone = skeleton.data[bone];
	var shape = bone.shape;
	if shape==-1 return -1;
	/*	Derived from:
			skeleton_get_sample_transform(skeleton, i, sample);
			quaternion_multiply(sample, shape.angle, q);
			quaternion_transform_vector(q, shape.Vx, shape.Vy, shape.Vz, pos)
			quaternion_conjugate(q);
			rayPos[@0]-=bone.x+pos[0];
			rayPos[@1]-=bone.y+pos[1];
			rayPos[@2]-=bone.z+pos[2];
			quaternion_transform_vector(q, rayPos[0], rayPos[1], rayPos[2], pos);
			quaternion_transform_vector(q, rayVec[0], rayVec[1], rayVec[2], vec);
			var temp = line_intersect_AABB(pos, vec, [-shape.xscale, -shape.yscale, -shape.zscale], [shape.xscale, shape.yscale, shape.zscale])
			if is_undefined(temp[0]) debug_overlay("No collision", 2) else debug_overlay("Collision detected", 2);
	*/
	var qx, qy, qz, qw
	var qx1, qy1, qz1, qw1, qx2, qy2, qz2, qw2;
	// Get rotation
	var buff = skeleton.animate;
	var b = bone.index*8;
	qx1 = buffer_peek(buff, 4*(b+0), buffer_f32);
	qy1 = buffer_peek(buff, 4*(b+1), buffer_f32);
	qz1 = buffer_peek(buff, 4*(b+2), buffer_f32);
	qw1 = buffer_peek(buff, 4*(b+3), buffer_f32);
	qx2 = shape.angle[0];
	qy2 = shape.angle[1];
	qz2 = shape.angle[2];
	qw2 = shape.angle[3];
	
	// Quaternion multiply (bone animation sample * shape rotation)
	var Qx = qw1 * qx2 + qx1 * qw2 + qy1 * qz2 - qz1 * qy2;
	var Qy = qw1 * qy2 + qy1 * qw2 + qz1 * qx2 - qx1 * qz2;
	var Qz = qw1 * qz2 + qz1 * qw2 + qx1 * qy2 - qy1 * qx2;
	var Qw = qw1 * qw2 - qx1 * qx2 - qy1 * qy2 - qz1 * qz2;
	
	// Transform vector (shape offset from bone position)
	var xx, yy, zz
	xx = Qw*Qw*shape.Vx + 2*Qy*Qw*shape.Vz - 2*Qz*Qw*shape.Vy + Qx*Qx*shape.Vx + 2*Qy*Qx*shape.Vy + 2*Qz*Qx*shape.Vz - Qz*Qz*shape.Vx - Qy*Qy*shape.Vx;
	yy = 2*Qx*Qy*shape.Vx + Qy*Qy*shape.Vy + 2*Qz*Qy*shape.Vz + 2*Qw*Qz*shape.Vx - Qz*Qz*shape.Vy + Qw*Qw*shape.Vy - 2*Qx*Qw*shape.Vz - Qx*Qx*shape.Vy;
	zz = 2*Qx*Qz*shape.Vx + 2*Qy*Qz*shape.Vy + Qz*Qz*shape.Vz - 2*Qw*Qy*shape.Vx - Qy*Qy*shape.Vz + 2*Qw*Qx*shape.Vy - Qx*Qx*shape.Vz + Qw*Qw*shape.Vz;
	
	// Inverse transform raycast
	Qx*=-1;	Qy*=-1;	Qz*=-1	// conjugate rotation for ray transform
	var rpx, rpy, rpz;
	var rvx, rvy, rvz;
	xx = posx-bone.x-xx;
	yy = posy-bone.y-yy;
	zz = posz-bone.z-zz;
	rpx = Qw*Qw*xx + 2*Qy*Qw*zz - 2*Qz*Qw*yy + Qx*Qx*xx + 2*Qy*Qx*yy + 2*Qz*Qx*zz - Qz*Qz*xx - Qy*Qy*xx;
	rpy = 2*Qx*Qy*xx + Qy*Qy*yy + 2*Qz*Qy*zz + 2*Qw*Qz*xx - Qz*Qz*yy + Qw*Qw*yy - 2*Qx*Qw*zz - Qx*Qx*yy;
	rpz = 2*Qx*Qz*xx + 2*Qy*Qz*yy + Qz*Qz*zz - 2*Qw*Qy*xx - Qy*Qy*zz + 2*Qw*Qx*yy - Qx*Qx*zz + Qw*Qw*zz;
	xx = dirx;
	yy = diry;
	zz = dirz;
	rvx = Qw*Qw*xx + 2*Qy*Qw*zz - 2*Qz*Qw*yy + Qx*Qx*xx + 2*Qy*Qx*yy + 2*Qz*Qx*zz - Qz*Qz*xx - Qy*Qy*xx;
	rvy = 2*Qx*Qy*xx + Qy*Qy*yy + 2*Qz*Qy*zz + 2*Qw*Qz*xx - Qz*Qz*yy + Qw*Qw*yy - 2*Qx*Qw*zz - Qx*Qx*yy;
	rvz = 2*Qx*Qz*xx + 2*Qy*Qz*yy + Qz*Qz*zz - 2*Qw*Qy*xx - Qy*Qy*zz + 2*Qw*Qx*yy - Qx*Qx*zz + Qw*Qw*zz;
	
	// Raycast AABB (against bone size)
	var xMin, yMin, zMin, xMax, yMax, zMax;
	xMin = (-shape.xscale - rpx) / rvx;
	yMin = (-shape.yscale - rpy) / rvy;
	zMin = (-shape.zscale - rpz) / rvz;
	xMax = (shape.xscale - rpx) / rvx;
	yMax = (shape.yscale - rpy) / rvy;
	zMax = (shape.zscale - rpz) / rvz;
	
	var x1, y1, z1, x2, y2, z2
	x1 = min(xMin, xMax);
	y1 = min(yMin, yMax);
	z1 = min(zMin, zMax);
	x2 = max(xMin, xMax);
	y2 = max(yMin, yMax);
	z2 = max(zMin, zMax);
	
	// Return nearest collision
    var Near = max(max(x1, y1), z1);
    var Far = min(min(x2, y2), z2);
	if Near > Far return -1 else return Near;
}
function skeleton_raycast(skeleton, rayPos, rayVec, nearest=false, array=array_create(2))
{
	// Perform raycast against all bone shape, return array [bone, unit], where bone is the struct of the bone hit, and vector unit (distance multiplier).
	//	Set nearest=true to check all bone and find the nearest bone hit by ray, otherwise return the first bone found.
	
	// Get the list of bone with shape (only first time), bone order are reversed so outer bones are alway checked first.
	if (skeleton.shapelist==-1)
	{
		skeleton.shapelist = []
		for(var i=skeleton.size-1; i>=0; i--)
		{
			var bone = skeleton.data[i];
			if bone.shape==-1 continue;
			array_push(skeleton.shapelist, bone);
		}
	}
	var posx=rayPos[0], posy=rayPos[1], posz=rayPos[2], dirx=rayVec[0], diry=rayVec[1], dirz=rayVec[2]
	var near = infinity, hit = -1;
	var s = array_length(skeleton.shapelist);
	if nearest for(var i=0; i<s; i++)
	{
		var bone = skeleton.shapelist[i];
		var temp = skeleton_raycast_bone(skeleton, bone, posx, posy, posz, dirx, diry, dirz)
		if temp<0 continue;
		if temp<near {near=temp; hit=bone}
	}
	else for(var i=0; i<s; i++)
	{
		var bone = skeleton.shapelist[i];
		var temp = skeleton_raycast_bone(skeleton, bone, posx, posy, posz, dirx, diry, dirz)
		if temp<0 continue;
		if temp<near {near=temp; hit=bone; break}
	}
	if hit==-1 {array[@0]=undefined; array[@1]=undefined; return array}
	array[@0] = hit;
	array[@1] = near;
	return array;
}

function check_bone(ref, skeleton)
{
	// Check references and return struct of bone if possible;
	// reference can be a name-string, an integer or bone struct itself, return undefined if can't find any bone;
	var bone;
	if is_struct(ref) bone=ref;
	else if is_real(ref)
	{
		if floor(ref)>=skeleton.size {log("Unable to reference bone: "+string(floor(ref))+", skeleton size is: "+string(skeleton.size)); return undefined}
		bone = skeleton.data[floor(ref)]
	}
	else if is_string(ref)
	{
		bone = skeleton.reference[? ref];
		if is_undefined(bone)
		{
			var n = string_digits(ref);
			if string_length(n)==0 {log("Unable to reference bone: "+string(ref)); return undefined};
			bone = skeleton.data[real(n)];
		} else {
			bone = skeleton.data[bone];
		}
	}
	return bone;
}