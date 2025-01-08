#macro AnimMaxBone 128
#macro Animation3DShader sh_anim_smf
#macro AnimationSpriteShader sh_anim_sprite
#macro AnimationVoxelShader sh_anim_voxel
#macro unit_Xaxis [1,0,0]
#macro unit_Yaxis [0,1,0]
#macro unit_Zaxis [0,0,1]

// sh_anim_voxel will rotate voxel in world-space while sh_anim_voxel_sprite will rotate voxel in texture space.
// sh_anim_voxel_sprite are true voxel and are rounded to world-space, take caution not to scale the model too small or too large (somewhere between 0.5 and 1.5).
// Otherwise both shader are similar, you should try both first and use whichever suits your artistic choice best.

globalvar animation_struct, animation_reference;
animation_struct = {
	//	You can set it to use buffer_f16 instead of buffer_f32 to reduce memory usage, but lower precision/quality;
	//	However the memory usage is insignificant either way comparing to memory computer have nowaday with 8Gbs+.
	type: buffer_f32,
	sizeof: buffer_sizeof(buffer_f32),
	width: 8,
	height: 1,
	name: "",
	data: -1,
	keyframe: [],
	reference: -1,
}
animation_reference = ds_map_create();

// These function are mostly handle by animation_editor and animation_player, you might want to use animation_player below instead
function animation_data(name)
{
	// Create new animation data and return a struct.
	var data = variable_clone(animation_struct);
	data.name = name;
	data.data = buffer_create(8*data.height*data.sizeof, buffer_fixed, data.sizeof);
	animation_data_set(data, 3, 0, 1);
	animation_data_set(data, 7, 0, 1);
	animation_reference[? name] = data;
	return data;
}
function animation_delete(name)
{
	if is_struct(name) name=name.name;
	var struct = animation_reference[? name]
	if is_undefined(struct) return false;
	buffer_delete(struct.data);
	ds_map_delete(animation_reference, name);
}
function animation_clone(anim, name)
{
	if is_string(anim) anim=animation_reference[? anim];
	if name = anim.name {log("Animation clone failed: reference name already exists ("+string(name)+")", "error"); return anim}
	var data = variable_clone(anim);
	data.name = name;
	data.data = buffer_create(buffer_get_size(data.data), buffer_fixed, data.sizeof);
	buffer_copy(anim.data, 0, buffer_get_size(data.data), data.data, 0);
	animation_reference[? name] = data;
	return data;
}

function animation_data_read(anim, x, y)
{
	return buffer_peek(anim.data, (anim.width*y + x)*anim.sizeof, anim.type);
}
function animation_data_set(anim, x, y, value)
{
	return buffer_poke(anim.data, (anim.width*y + x)*anim.sizeof, anim.type, value)
}
function animation_data_set_region(source, x1, y1, x2, y2, dest, xpos, ypos)
{
	var w = min(x2-x1, source.width-x1, dest.width-xpos);
	var h = min(y2-y1, source.height-y1, dest.height-ypos);
	
	// Write data forward or backward depend on relative position, so it wont repeat value.
	if ypos>y1 for(var yy=h-1; yy>=0; yy--)
	{
		if xpos>x1 for(var xx=w-1; xx>=0; xx--)
		{
			animation_data_set(dest, xpos+xx, ypos+yy, animation_data_read(source, x1+xx, y1+yy));
		}
		else for(var xx=0; xx<w; xx++)
		{
			animation_data_set(dest, xpos+xx, ypos+yy, animation_data_read(source, x1+xx, y1+yy));
		}
	}
	else for(var yy=0; yy<h; yy++)
	{
		if xpos>x1 for(var xx=w-1; xx>=0; xx--)
		{
			animation_data_set(dest, xpos+xx, ypos+yy, animation_data_read(source, x1+xx, y1+yy));
		}
		else for(var xx=0; xx<w; xx++)
		{
			animation_data_set(dest, xpos+xx, ypos+yy, animation_data_read(source, x1+xx, y1+yy));
		}
	}
}
function animation_data_resize(anim, w, h)
{
	var temp=buffer_create(w*h*anim.sizeof, buffer_fixed, anim.sizeof);
	for(var yy=0;yy<min(h,anim.height);yy++)
	{
		buffer_copy(anim.data, (anim.width*yy)*anim.sizeof, min(anim.width,w)*anim.sizeof, temp, (w*yy)*anim.sizeof)
	}
	buffer_delete(anim.data);
	anim.data = temp;
	anim.width = w;
	anim.height = h;
}
function animation_get_frames(anim)
{
	// Returning number of frames in the animation;
	return anim.width/8;
}
function animation_get_frame(anim, time)
{
	// Returning the frame index of the animation at the given time.
	// Output is a float value, decimal number represent the interpolation time between frames.
	// Result value can be -1, which is the time between the animation starts until the first keyframe (0);
	var s = array_length(anim.keyframe);
	var ind = -1, t=0, v;
	for(var i=0; i<s; i++)
	{
		if anim.keyframe[i].time>time break;
		t = anim.keyframe[i].time
		ind = i;
	}
	if t!=time && (ind>=0 && ind<s-1)
	{
		var prev = 0, next = -1, step=0;
		prev = t;
		next = anim.keyframe[ind+1].time;
		if prev<next ind+=InvLerp(prev, next, time);
	}
	if ind<0 ind=time/anim.keyframe[0].time-1;
	return ind;
}
function animation_get_duration(anim)
{
	// Return duration in second of the animation (time of the last keyframe)
	var f = anim.width/8;
	return anim.keyframe[f-1].time;
}

function animation_keyframe_get(anim, time, add=false)
{
	// Seek through timeline and find the nearest keyframe to the given time;
	// If add==false then simply return nearest frame, if add=true then resize data and insert new keyframe;
	var s = array_length(anim.keyframe);
	var ind = -1, t=-1, v;
	for(var i=0; i<s; i++)
	{
		if anim.keyframe[i].time>time break;
		t = anim.keyframe[i].time
		ind = i;
	}
		
	if t!=time && add
	{
		array_insert(anim.keyframe, i, {time:time, name:0});
		animation_data_resize(anim, (s+1)*8, anim.height);
		if ind<s-1 animation_data_set_region(anim, (ind+1)*8, 0, s*8, anim.height, anim, (ind+2)*8, 0);
		ind++;
	}
	return ind;
}
function animation_keyframe_capture(anim, skeleton, time)
{
	// Capture skeleton current transformation into animation;
	// It will resize data to match skeleton;
	// If time is match a keyframe then overwrite it, otherwise add new keyframe to timeline.
	if skeleton.size!=anim.height animation_data_resize(anim, anim.width, skeleton.size);
	var frame = animation_keyframe_get(anim, time, true);
	for(var i=0; i<skeleton.size; i++)
	{
		for(var j=0; j<8; j++)
		{
			var v = buffer_peek(skeleton.transform, 4*(i*8+j), buffer_f32);
			animation_data_set(anim, frame*8+j, i, v);
		}
	}
}
function animation_keyframe_sample_time(anim, skeleton, time)
{
	// Transform skeleton to animation data, automatically seeking keyframe in the timeline and interpolate between frames.
	// Frame interpolate using spherical-linear-interpolation for better quality, but slower than normal linear interpolation.
	// Meant to be used by animation editor, has no loop or other player feature.
	var s = array_length(anim.keyframe);
	//time = clamp(time, 0, anim.keyframe[s-1].time);
	var ind = -1, t=0, v;
	for(var i=0; i<s; i++)
	{
		if anim.keyframe[i].time>time break;
		t = anim.keyframe[i].time
		ind = i;
	}
	if t!=time && (ind>=0 && ind<s-1)
	{
		var prev = 0, next = -1, step=0;
		prev = t;
		next = anim.keyframe[ind+1].time;
		if prev<next ind+=InvLerp(prev, next, time);
	}
	if ind<0 ind=0
	animation_keyframe_sample(anim, skeleton, ind);
}
function animation_keyframe_sample(anim, skeleton, frame)
{
	// Transform skeleton to animation data, if frame number have decimal then automatically interpolate between frames.
	// Frame interpolate using spherical-linear-interpolation for better quality, but slower than normal linear interpolation.
	// Meant to be used by animation editor, has no loop or other player feature.
	var w = anim.width;
	var sizeof = anim.sizeof;
	var data = anim.data;
	var type = anim.type;
	var sample = skeleton.transform
	var interpolate = frac(frame);
	var size = min(anim.height, skeleton.size)
	if interpolate==0 // no interpolation needed
	{
		for(var i=0; i<size; i++)
		{
			for(var j=0; j<8; j ++)
			{
				var v = buffer_peek(data, (w*i+8*frame+j)*sizeof, type);
				buffer_poke(sample, 4*(i*8+j), buffer_f32, v);
			}
		}
	} else { // frame interpolation, using spherical linear interpolation.
		frame = floor(frame)
		for(var i=0; i<size; i++)
		{
			// interpolate transform
			for(var j=4; j<8; j ++)
			{
				var v1 = buffer_peek(data, (w*i+8*frame+j)*sizeof, type) * (1-interpolate);
				var v2 = buffer_peek(data, (w*i+8*(frame+1)+j)*sizeof, type) * (interpolate);
				var v = v1 + v2
				buffer_poke(sample, 4*(i*8+j), buffer_f32, v);
			}
			
			// interpolate quaternion
			var qax=buffer_peek(data, (w*i+8*frame+0)*sizeof, type);
			var qay=buffer_peek(data, (w*i+8*frame+1)*sizeof, type);
			var qaz=buffer_peek(data, (w*i+8*frame+2)*sizeof, type);
			var qaw=buffer_peek(data, (w*i+8*frame+3)*sizeof, type);
			var qbx=buffer_peek(data, (w*i+8*(frame+1)+0)*sizeof, type);
			var qby=buffer_peek(data, (w*i+8*(frame+1)+1)*sizeof, type);
			var qbz=buffer_peek(data, (w*i+8*(frame+1)+2)*sizeof, type);
			var qbw=buffer_peek(data, (w*i+8*(frame+1)+3)*sizeof, type);
			
			/*//	NLERP
			var qx = lerp(qax, qbx, interpolate);
			var qy = lerp(qay, qby, interpolate);
			var qz = lerp(qaz, qbz, interpolate);
			var qw = lerp(qaw, qbw, interpolate);
			var l = sqrt(qx*qx + qy*qy + qz*qz + qw*qw);
			buffer_poke(sample, 4*(i*8+0), buffer_f32, qx/l);
			buffer_poke(sample, 4*(i*8+1), buffer_f32, qy/l);
			buffer_poke(sample, 4*(i*8+2), buffer_f32, qz/l);
			buffer_poke(sample, 4*(i*8+3), buffer_f32, qw/l);
			*/
			// SLERP
			var dot = qaw * qbw + qax * qbx + qay * qby + qaz * qaz;
			if dot>0.9995
			{
				// Fall back to linear interpolation
				buffer_poke(sample, 4*(i*8+0), buffer_f32, lerp(qax, qbx, interpolate));
				buffer_poke(sample, 4*(i*8+1), buffer_f32, lerp(qay, qby, interpolate));
				buffer_poke(sample, 4*(i*8+2), buffer_f32, lerp(qaz, qbz, interpolate));
				buffer_poke(sample, 4*(i*8+3), buffer_f32, lerp(qaw, qbw, interpolate));
				continue
			}
			var angle = arccos(dot);
			var denom = sin(angle);
			var r1 = sin((1-interpolate)*angle);
			var r2 = sin(interpolate*angle);
			buffer_poke(sample, 4*(i*8+0), buffer_f32, (qax * r1 + qbx * r2)/denom);
			buffer_poke(sample, 4*(i*8+1), buffer_f32, (qay * r1 + qby * r2)/denom);
			buffer_poke(sample, 4*(i*8+2), buffer_f32, (qaz * r1 + qbz * r2)/denom);
			buffer_poke(sample, 4*(i*8+3), buffer_f32, (qaw * r1 + qbw * r2)/denom);
		}
	}
	skeleton.update_transform();
}
function animation_keyframe_delete(anim, frame)
{
	var s = array_length(anim.keyframe);
	if s<=1 return false;
	if frame<s-1
	{
		animation_data_set_region(anim, (frame+1)*8, 0, s*8, anim.height, anim, frame*8, 0);
	}
	array_delete(anim.keyframe, frame, 1);
	animation_data_resize(anim, (s-1)*8, anim.height);
	return true
}
function animation_keyframe_rename(anim, frame, text)
{
	var s = array_length(anim.keyframe);
	if frame<0 || frame>s-1 return false
	anim.keyframe[frame].name = text;
	return true
}

function animation_save(anim, file, skeleton=-1)
{
	// Skeleton data is optional, it is used to get bone names for reference.
	if is_struct(skeleton) {
		if ds_map_size(skeleton.reference)>0 log("Skeleton does not have reference data (size=0)", "error") else anim.reference = ds_map_create_struct(skeleton.reference);
	}
	var ref = anim.reference;
	if ref!=-1 ref=json_stringify(ref)
	var header = 
	{
		type: anim.type,
		width: anim.width,
		height: anim.height,
		sizeof: anim.sizeof,
		name: anim.name,
		keyframe: anim.keyframe,
		reference: ref,
	}
	var data = buffer_create(1, buffer_grow, 1)
	buffer_write(data, buffer_string, json_stringify(header))
	var pos = buffer_tell(data);
	var size = buffer_get_size(anim.data);
	buffer_copy(anim.data, 0, size, data, pos);
	buffer_resize(data, pos+size);
	buffer_save(data, file);
	buffer_delete(data);
	delete header;
	return true;
}
function animation_load(file, name=-1)
{
	if !file_exists(file) {log("Animation file not found "+string(file),"error");return undefined};
	var buffer = buffer_load(file);
	buffer_seek(buffer, buffer_seek_start, 0);
	var txt = buffer_read(buffer, buffer_string);
	var pos = buffer_tell(buffer)
	
	var data = json_parse(txt);
	struct_inherit(data, animation_struct);
	var size = data.width*data.height*data.sizeof;
	data.data = buffer_create(size, buffer_fixed, data.sizeof);
	buffer_copy(buffer, pos, size, data.data, 0);
	buffer_delete(buffer);
	if data.reference!=-1 data.reference=json_parse(data.reference)
	
	// If animation with the same name already exists, populate pre-existing data with new one instead.
	var temp = animation_reference[? data.name];
	if !is_undefined(temp)
	{
		buffer_delete(temp.data);
		struct_replace(data, temp);
		delete(data);
		return temp;
	}
	if is_string(name) {data.name = name}
	if is_real(name) && name=-2 {data.name = string_trim_end(filename_name(file), filename_ext(file))};
	animation_reference[? data.name] = data;
	return data;
}
function animation_reference_skeleton(anim, skeleton, name=undefined)
{
	// Compare the animation's reference-data against skeleton's bone name, and arrange animation's data so that the animation will
	// transform the correct bones, even if the skeleton structure is difference from the one used to create animation. (Bone must have matching name)
	var s = ds_map_size(skeleton.reference)
	if s==0 {log("Skeleton does not have reference data (size=0)", "error"); return false};
	if !is_struct(anim.reference) {log("Animation does not have reference data", "error"); return false}
		
	if is_undefined(name) name=anim.name;
	var data = variable_clone(animation_struct);
	data.name = name;
	data.sizeof = anim.sizeof;
	data.type = anim.type;
	data.width = anim.width;
	data.height = anim.height;
	data.keyframe = variable_clone(anim.keyframe);
	data.data = buffer_create((data.width*data.height)*data.sizeof, buffer_fixed, data.sizeof);
	// Fill with identity transform
	for(var i=0; i<data.height; i++)
	{
		for(var j=0; j<data.width/8; j++)
		{
			animation_data_set(data, j*8+3, i, 1);
			animation_data_set(data, j*8+7, i, 1);
		}
	}
	var s = skeleton.size, bone, ind;
	for(var i=0; i<s; i++)
	{
		bone = skeleton.data[i];
		if (i==0)
		{
			if bone.name!="" var ind = anim.reference[$ bone.name];
			if is_undefined(ind) ind = 0;
		} else {
			if bone.name=="" continue;
			var ind = anim.reference[$ bone.name];
			if is_undefined(ind) continue;
		}
		buffer_copy(anim.data, (anim.width*ind)*anim.sizeof, anim.width*anim.sizeof, data.data, (data.width*bone.index)*data.sizeof);
	}
	data.reference = ds_map_create_struct(skeleton.reference);
	
	// If animation with the same name already exists, populate pre-existing data with new one instead.
	var temp = animation_reference[? data.name];
	if !is_undefined(temp)
	{
		buffer_delete(temp.data);
		struct_replace(data, temp);
		delete(data);
		return temp;
	}
	animation_reference[? name] = data;
	return data;
}
function animation_reference_check(anim, skeleton)
{
	// This function simply check if animation reference is match with skeleton data; Use to tell whether if animation_reference_skeleton() is necessary;
	// Return true is matches, false otherwise, and -2 if animation does not have any reference data;
	if anim.reference=-1 {log("Animation does not have reference data (ref=-1)", "error"); return -2};
	var names = struct_get_names(anim.reference)
	var sk = array_length(skeleton.data);
	var s = array_length(names);
	for(var i=0; i<s; i++)
	{
		var n = names[i]
		var b = anim.reference[$ n];
		if b>=s continue;
		var bone = skeleton.data[b];
		if bone.name == n continue;
		return false;
	}
	return true;
}
function animation_predict_position(anim, frame, skeleton, boneInd, root=true, array=array_create(3))
{
	// Predict the position of the bone during animation, without involving skeleton's data, return array [x,y,z]
	// Set root=false to ignore root translation, output will be relative to root instead;
	var xpos=0, ypos=0, zpos=0;
	if root
	{
		var bone = skeleton.data[0]
		xpos = bone.Ox + animation_data_read(anim, 8*frame+4, 0);
		ypos = bone.Oy + animation_data_read(anim, 8*frame+5, 0);
		zpos = bone.Oz + animation_data_read(anim, 8*frame+6, 0);
	}
	
	var xx, yy, zz, qx, qy, qz, qw;
	var bone = skeleton.data[boneInd];
	var i = bone.link;
	while(i>0)
	{
		// Get transform dualquat
		qx = animation_data_read(anim, 8*frame+0, i);
		qy = animation_data_read(anim, 8*frame+1, i);
		qz = animation_data_read(anim, 8*frame+2, i);
		qw = animation_data_read(anim, 8*frame+3, i);
		var vx = bone.Vx + animation_data_read(anim, 8*frame+4, i);
		var vy = bone.Vy + animation_data_read(anim, 8*frame+5, i);
		var vz = bone.Vz + animation_data_read(anim, 8*frame+6, i);
		var xx = qw*qw*vx + 2*qy*qw*vz - 2*qz*qw*vy + qx*qx*vx + 2*qy*qx*vy + 2*qz*qx*vz - qz*qz*vx - qy*qy*vx;
		var yy = 2*qx*qy*vx + qy*qy*vy + 2*qz*qy*vz + 2*qw*qz*vx - qz*qz*vy + qw*qw*vy - 2*qx*qw*vz - qx*qx*vy;
		var zz = 2*qx*qz*vx + 2*qy*qz*vy + qz*qz*vz - 2*qw*qy*vx - qy*qy*vz + 2*qw*qx*vy - qx*qx*vz + qw*qw*vz;
		xpos+=xx;
		ypos+=yy;
		zpos+=zz;
		
		bone = skeleton.data[bone.link];
		i = bone.link;
	}
	
	// Get transform dualquat
	qx = animation_data_read(anim, 8*frame+0, 0);
	qy = animation_data_read(anim, 8*frame+1, 0);
	qz = animation_data_read(anim, 8*frame+2, 0);
	qw = animation_data_read(anim, 8*frame+3, 0);
	var vx = bone.Vx;
	var vy = bone.Vy;
	var vz = bone.Vz;
	var xx = qw*qw*vx + 2*qy*qw*vz - 2*qz*qw*vy + qx*qx*vx + 2*qy*qx*vy + 2*qz*qx*vz - qz*qz*vx - qy*qy*vx;
	var yy = 2*qx*qy*vx + qy*qy*vy + 2*qz*qy*vz + 2*qw*qz*vx - qz*qz*vy + qw*qw*vy - 2*qx*qw*vz - qx*qx*vy;
	var zz = 2*qx*qz*vx + 2*qy*qz*vy + qz*qz*vz - 2*qw*qy*vx - qy*qy*vz + 2*qw*qx*vy - qx*qx*vz + qw*qw*vz;
	xpos+=xx;
	ypos+=yy;
	zpos+=zz;
	
	array[@0]=xpos;
	array[@1]=ypos;
	array[@2]=zpos;
	return array;
}
function animation_get_transform(anim, boneInd, frame, array=array_create(8))
{
	for(var i=0; i<8; i++) array[@i] = animation_data_read(anim, 8*frame+i, boneInd);
}
/*	================================= ANIMATION PLAYER ==================================
	These function handle animation playback, make it easier to perform complex animation.
	You can stack multiple animations on a skeleton; each stack will animate specific bones, higher stack will override lower stack.
	You can apply modification on a specific stack, mixing animations together.
	
	Begin by create an animation_player:
		player = new animation_player(skeleton);
	Then use anim_stack functions below to start animating skeleton;
	Execute player.step() to update animation every step;
	To remove animation player from memory (and relevant data like stacks and layers), simply destroy the skeleton.
*/
enum anim_blendmode
{
	animation, time, duration,
	frame,
	rotate_world, rotate_local, rotate_set,
	transform,
	IK_world, IK_bind, transform_bind, transform_bone,
	anchor_IK,
	inherit,
}
#macro animation_default_speed 0.1 // Speed when there's no animation is active
globalvar animation_stack;		// Default stack data format
animation_stack = {
	animation: -1, reference: "", duration: 0,
	player: -1, skeleton: -1, active: false, index: -1,
	bones: -1, sample: -1, root: false, anim_ref: false,
	layers:[],
	time: 0, frame: -1, frame_durr: 0, step_time: 0, step: 0, previous: 0,
	speed: 1, loop: true,
	event: -1,
	update_layer: false, // layer update
	visible: false
}

function animation_player(skeleton) constructor
{
	var size=skeleton.size;
	self.skeleton = skeleton; skeleton.player=self;
	stacks = [];	self.size=0;	childs=[];
	x_lock=false;	y_lock=false;	z_lock=false;	// Lock root bone movement, if you want to handle the movement yourself (for things like physics collision).
	x_loop=true;	y_loop=true;	z_loop=true;	// Whether to loop root bone position during animation, or move continuously;
	xspeed=0;	yspeed=0;	zspeed=0;	// Movement speed of the root bone during animation (this value add up even if *_lock value is true);
	event = []
	sync = false;	// networking (?)
	bones = buffer_create(size, buffer_fixed, 1); count=skeleton.size	// bone's "stack" index value
	anim_index = buffer_create(size, buffer_fixed, 1);	// Animation read index
	bone_origin = buffer_create(4*(4*size), buffer_fixed, 4);	// bones's origin position to caculate dual quaternion
	
	buff_prev = buffer_create(4*(8*size), buffer_fixed, 4);	// previous bone transform (animation last frame, for interpolation).
	buff_anim = buffer_create(4*(8*size), buffer_fixed, 4);	// current bone transform (animation current frame)
		
	xroot=0;	yroot=0;	zroot=0;	// Position of root bone in animation space;
	xprevious=0;yprevious=0;zprevious=0;xreal=0;yreal=0;zreal=0	// use to calculate movement speed of the root bone;
	buffer_copy(skeleton.transform, 0, buffer_get_size(buff_anim), buff_prev, 0);
	buffer_copy(skeleton.transform, 0, buffer_get_size(buff_anim), buff_anim, 0);
	for(var i=0; i<skeleton.size; i++) {var bone=skeleton.data[i]; buffer_writes(bone_origin, buffer_f32, bone.Ox, bone.Oy, bone.Oz, 0);}
	for(var i=0; i<size; i++)	buffer_write(anim_index, buffer_u8, i);
	qx=0; qy=0; qz=0; qw=0;
	
	// Internal functions
	static update_bone = function(boneInd, buffer=skeleton.transform, sample=-1, step=-1)
	{
		// Custom update code derived from skeleton_create.update_transform().
		// Quaternion dual part can be skipped by setting skeleton.sample to -1.
		static readDanim = function(ind, interpolate, buffer) {return lerp(buffer_peek(self.buff_prev, 4*(ind), buffer_f32), buffer_peek(self.buff_anim, 4*(ind), buffer_f32), interpolate);}
		static readDtransform = function(ind, interpolate, buffer) {return buffer_peek(buffer, 4*(ind), buffer_f32);}
		static readQtransform = function(ind, interpolate, buffer)
		{
			qx = buffer_peek(buffer, 4*(ind), buffer_f32)
			qy = buffer_peek(buffer, 4*(ind+1), buffer_f32)
			qz = buffer_peek(buffer, 4*(ind+2), buffer_f32)
			qw = buffer_peek(buffer, 4*(ind+3), buffer_f32)
		}
		static readQanim = function(ind, interpolate, buffer)
		{
			var x1, y1, z1, w1, x2, y2, z2, w2;
			x1 = buffer_peek(self.buff_prev, 4*(ind), buffer_f32);		x2 = buffer_peek(self.buff_anim, 4*(ind), buffer_f32);
			y1 = buffer_peek(self.buff_prev, 4*(ind+1), buffer_f32);	y2 = buffer_peek(self.buff_anim, 4*(ind+1), buffer_f32);
			z1 = buffer_peek(self.buff_prev, 4*(ind+2), buffer_f32);	z2 = buffer_peek(self.buff_anim, 4*(ind+2), buffer_f32);
			w1 = buffer_peek(self.buff_prev, 4*(ind+3), buffer_f32);	w2 = buffer_peek(self.buff_anim, 4*(ind+3), buffer_f32);
			
			//var dot = w1 * w2 + x1 * x2 + y1 * y2 + z1 * z2;
			//if (dot < 0) {x2=-x2; y2=-y2; z2=-z2; w2=-w2;} // make sure to interpolate using the closet path
			
			qx = lerp(buffer_peek(self.buff_prev, 4*(ind), buffer_f32), buffer_peek(self.buff_anim, 4*(ind), buffer_f32), interpolate)
			qy = lerp(buffer_peek(self.buff_prev, 4*(ind+1), buffer_f32), buffer_peek(self.buff_anim, 4*(ind+1), buffer_f32), interpolate)
			qz = lerp(buffer_peek(self.buff_prev, 4*(ind+2), buffer_f32), buffer_peek(self.buff_anim, 4*(ind+2), buffer_f32), interpolate)
			qw = lerp(buffer_peek(self.buff_prev, 4*(ind+3), buffer_f32), buffer_peek(self.buff_anim, 4*(ind+3), buffer_f32), interpolate)
			// nlerp
			var l = 1 / sqrt(qx*qx + qy*qy + qz*qz + qw*qw);
			qx*=l; qy*=l; qz*=l; qw*=l
		}
		var r0, r1, r2, r3, r4, r5, r6, r7, f0, f1, f2, f3, f4, f5, f6;
		//var qx, qy, qz, qw
		var i = boneInd;
		var bone = skeleton.data[i];
		var b = i * 8;
		if bone.skip_transform
		{
			var readD = readDanim;
			var readQ = readQanim
			var interpolate = step;
			if step<0 interpolate = buffer_peek(buff_anim, 4*(b+7), buffer_f32);
		} else {
			var readD = readDtransform;
			var readQ = readQtransform
			var interpolate = 1;
		}
			bone.skip_transform = true;
		if bone.link<0
		{
			r4 = readD(b+4, interpolate, buffer);
			r5 = readD(b+5, interpolate, buffer);
			r6 = readD(b+6, interpolate, buffer);
			bone.x = bone.Ox+r4;	bone.y = bone.Oy+r5;	bone.z = bone.Oz+r6;
			buffer_poke(buffer, 4*(b+4), buffer_f32, bone.x);
			buffer_poke(buffer, 4*(b+5), buffer_f32, bone.y);
			buffer_poke(buffer, 4*(b+6), buffer_f32, bone.z);
		}
		if !bone.inherit
		{
			var b = i * 8;
			// Get transform dualquat
			readQ(b, interpolate, buffer);
			
			// Write transformation into uniform buffer
			buffer_poke(buffer, 4*(b+0), buffer_f32, qx);
			buffer_poke(buffer, 4*(b+1), buffer_f32, qy);
			buffer_poke(buffer, 4*(b+2), buffer_f32, qz);
			buffer_poke(buffer, 4*(b+3), buffer_f32, qw);
		} else {
			// Get parent bone's rotations
			var b = bone.link*8
			var i0 = buffer_peek(buffer, 4*(b+0), buffer_f32);
			var i1 = buffer_peek(buffer, 4*(b+1), buffer_f32);
			var i2 = buffer_peek(buffer, 4*(b+2), buffer_f32);
			var i3 = buffer_peek(buffer, 4*(b+3), buffer_f32);
			var b = i * 8;
			// Get transform dualquat
			readQ(b, interpolate, buffer);
			qx = qw * i0 + qx * i3 + qy * i2 - qz * i1;
			qy = qw * i1 - qx * i2 + qy * i3 + qz * i0;
			qz = qw * i2 + qx * i1 - qy * i0 + qz * i3;
			qw = qw * i3 - qx * i0 - qy * i1 - qz * i2;
			// nlerp
			var l = 1 / sqrt(qx*qx + qy*qy + qz*qz + qw*qw);
			qx*=l; qy*=l; qz*=l; qw*=l
				
			// Write transformation into uniform buffer
			buffer_poke(buffer, 4*(b+0), buffer_f32, qx);
			buffer_poke(buffer, 4*(b+1), buffer_f32, qy);
			buffer_poke(buffer, 4*(b+2), buffer_f32, qz);
			buffer_poke(buffer, 4*(b+3), buffer_f32, qw);
		}
		// Translate bone position
		var s = array_length(bone.heirs);
		for(var h=0; h<s; h++)
		{
			var heir = bone.heirs[h]
			var b = heir.index * 8;
			var vx = heir.Vx + readD(b+4, interpolate, buffer);
			var vy = heir.Vy + readD(b+5, interpolate, buffer);
			var vz = heir.Vz + readD(b+6, interpolate, buffer);
			var xx = qw*qw*vx + 2*qy*qw*vz - 2*qz*qw*vy + qx*qx*vx + 2*qy*qx*vy + 2*qz*qx*vz - qz*qz*vx - qy*qy*vx;
			var yy = 2*qx*qy*vx + qy*qy*vy + 2*qz*qy*vz + 2*qw*qz*vx - qz*qz*vy + qw*qw*vy - 2*qx*qw*vz - qx*qx*vy;
			var zz = 2*qx*qz*vx + 2*qy*qz*vy + qz*qz*vz - 2*qw*qy*vx - qy*qy*vz + 2*qw*qx*vy - qx*qx*vz + qw*qw*vz;
			heir.x = bone.x + xx;
			heir.y = bone.y + yy;
			heir.z = bone.z + zz;
		}
		if !(sample==-1) sample_dualquat(boneInd, qx, qy, qz, qw, bone.x, bone.y, bone.z, sample)
	}
	static stack_anim_ref = function(stack=-1)
	{
		// Check skeleton bone names and animation reference. Make sure it animate correct bones
		//	Only execute when stack order is changed or animation change.
		if is_struct(stack)
		{
			var anim = stack.animation;
			var s = buffer_tell(stack.sample)
			if !stack.anim_ref || anim.reference==-1
			{
				for(var i=0;i<s;i++)
				{
					var boneInd = buffer_peek(stack.sample, i, buffer_u8);
					buffer_poke(anim_index, boneInd, buffer_u8, boneInd)
				}
				return true;
			}
			for(var i=0; i<s; i++)
			{
				var boneInd = buffer_peek(stack.sample, i, buffer_u8);
				var ind = boneInd;
				var bone = skeleton.data[boneInd]
				if bone.name!=""
				{
					var ind = anim.reference[$ bone.name];
					if is_undefined(ind) ind = boneInd;
				}
				buffer_poke(anim_index, boneInd, buffer_u8, ind);
			}
			return true
		}
		for(var j=0; j<size; j++)
		{
			stack = stacks[j];
			var anim = stack.animation;
			var s = buffer_tell(stack.sample)
			if !stack.anim_ref || anim.reference==-1
			{
				for(var i=0;i<s;i++)
				{
					var boneInd = buffer_peek(stack.sample, i, buffer_u8);
					buffer_poke(anim_index, boneInd, buffer_u8, boneInd)
				}
				continue;
			}
			for(var i=0; i<s; i++)
			{
				var boneInd = buffer_peek(stack.sample, i, buffer_u8);
				var ind = boneInd;
				var bone = skeleton.data[boneInd]
				if bone.name!=""
				{
					var ind = anim.reference[$ bone.name];
					if is_undefined(ind) ind = boneInd;
				}
				buffer_poke(anim_index, boneInd, buffer_u8, ind);
			}
		}
		return true
	}
	static sample_dualquat = function(boneInd, qx, qy, qz, qw, x, y, z, uniform=skeleton.animate)
	{
		// Write dual quaternion for animation sample buffer (rendering)
		var ox, oy, oz, xx, yy, zz;
		var r4, r5, r6, r7, f4, f5, f6, f7;
		var b = boneInd*8;
		// nlerp
		//l = 1 / sqrt(qx*qx + qy*qy + qz*qz + qw*qw);
		//qx*=l; qy*=l; qz*=l; qw*=l
		buffer_poke(uniform, 4*(b+0), buffer_f32, qx);
		buffer_poke(uniform, 4*(b+1), buffer_f32, qy);
		buffer_poke(uniform, 4*(b+2), buffer_f32, qz);
		buffer_poke(uniform, 4*(b+3), buffer_f32, qw);
				
		ox = buffer_peek(bone_origin, 4*(boneInd*4), buffer_f32);
		oy = buffer_peek(bone_origin, 4*(boneInd*4+1), buffer_f32);
		oz = buffer_peek(bone_origin, 4*(boneInd*4+2), buffer_f32);
		r4 = oy * qz - oz * qy;
		r5 = oz * qx - ox * qz;
		r6 = ox * qy - oy * qx;
		r7 = 0;
		f4=.5*(x-ox);
		f5=.5*(y-oy);
		f6=.5*(z-oz);
		buffer_poke(uniform, 4*(b+4), buffer_f32, r4 + f4 * qw + f5 * qz - f6 * qy); 
		buffer_poke(uniform, 4*(b+5), buffer_f32, r5 - f4 * qz + f5 * qw + f6 * qx);
		buffer_poke(uniform, 4*(b+6), buffer_f32, r6 + f4 * qy - f5 * qx + f6 * qw); 
		buffer_poke(uniform, 4*(b+7), buffer_f32, r7 - f4 * qx - f5 * qy - f6 * qz);
	}
	static bone_set_rotation = function(boneInd, qx, qy, qz, qw, buffer = buff_anim)
	{
		var b = boneInd * 8;
		// Write bone transform
		buffer_poke(buffer, 4*(b+0), buffer_f32, qx);
		buffer_poke(buffer, 4*(b+1), buffer_f32, qy);
		buffer_poke(buffer, 4*(b+2), buffer_f32, qz);
		buffer_poke(buffer, 4*(b+3), buffer_f32, qw);
	}
	static bone_set_position = function(boneInd, x, y, z, buffer=buff_anim)
	{
		var b = boneInd * 8;
		// Write bone transform
		buffer_poke(buffer, 4*(b+4), buffer_f32, x);
		buffer_poke(buffer, 4*(b+5), buffer_f32, y);
		buffer_poke(buffer, 4*(b+6), buffer_f32, z);
	}
	static rotate_bone = function(boneInd, Qx, Qy, Qz, Qw, local=true, rotateChilds=false, buffer = buff_anim)
	{
		var r0 = Qx, r1 = Qy, r2 = Qz, r3 = Qw;
		var b = boneInd * 8;
		// Get current bone transform
		var s0 = buffer_peek(buffer, 4*(b+0), buffer_f32);
		var s1 = buffer_peek(buffer, 4*(b+1), buffer_f32);
		var s2 = buffer_peek(buffer, 4*(b+2), buffer_f32);
		var s3 = buffer_peek(buffer, 4*(b+3), buffer_f32);
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
		bone_set_rotation(boneInd, Qx, Qy, Qz, Qw, buffer);
		if rotateChilds
		{
			var bind = skeleton.bindmap[boneInd]
			var s = array_length(bind)
			for(var i=0; i<s; i++)
			{
				var bone = bind[i];
				if bone.inherit continue;
				var b = bone.index * 8;
				// Get current bone transform
				var s0 = buffer_peek(buffer, 4*(b+0), buffer_f32);
				var s1 = buffer_peek(buffer, 4*(b+1), buffer_f32);
				var s2 = buffer_peek(buffer, 4*(b+2), buffer_f32);
				var s3 = buffer_peek(buffer, 4*(b+3), buffer_f32);
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
				bone_set_rotation(bone.index, Qx, Qy, Qz, Qw, buffer)
			}
		}
	}
	static move_bone = function(boneInd, xspeed, yspeed, zspeed)
	{
		var buffer = buff_anim;
		var b = boneInd * 8;
		// Get current bone transform
		var s0 = buffer_peek(buffer, 4*(b+4), buffer_f32);
		var s1 = buffer_peek(buffer, 4*(b+5), buffer_f32);
		var s2 = buffer_peek(buffer, 4*(b+6), buffer_f32);
		bone_set_position(boneInd, s0+xspeed, s1+yspeed, s2+zspeed)
	}
	static update_size = function(size)
	{
		var s = buffer_get_size(bones)-1;
		buffer_resize(bones, size)
		buffer_resize(anim_index, size)
		buffer_resize(bone_origin, 4*(4*size))
		buffer_resize(buff_prev, 4*(8*size))
		buffer_resize(buff_anim, 4*(8*size))
		for(var i=s; i<size; i++)
		{
			buffer_write(anim_index, buffer_u8, i);
			var bone=skeleton.data[i]; buffer_writes(bone_origin, buffer_f32, bone.Ox, bone.Oy, bone.Oz, 0);
			var b = i*8;
			for(var j=0; j<8; j++)
			{
				buffer_poke(buff_prev, 4*(b+j), buffer_f32, buffer_peek(skeleton.transform, 4*(b+j), buffer_f32))
				buffer_poke(buff_anim, 4*(b+j), buffer_f32, buffer_peek(skeleton.transform, 4*(b+j), buffer_f32))
			}
		}
		
	}
	
	// Front-end function
	static destroy=function()
	{
		buffer_delete(bones);
		buffer_delete(buff_prev);
		buffer_delete(buff_anim);
		buffer_delete(bone_origin);
		var s = array_length(childs)
		for(var i=0; i<s; i++) {
			var stack = childs[i]
			buffer_delete(stack.bones);
			buffer_delete(stack.sample);
		}
	}
	static step = function(_delta=1/room_speed)
	{
		if array_length(event)>0 {array_resize(event,0)}
		if skeleton.size>count {update_size(skeleton.size); count=skeleton.size}
		for(var i=0; i<size; i++)
		{
			var stack = stacks[i];
			anim_stack_step(stack, _delta);
			if stack.event>=0 anim_stack_sample(stack);
		}
		
		// Update entire skeleton for animation
		for(var i=0; i<skeleton.size; i++)
		{
			update_bone(i, skeleton.transform, skeleton.animate)
		}
	}
	static update_stack = function()
	{
		// Check which stack is on top of bone
		buffer_seek(bones, buffer_seek_start, 0);
		repeat(skeleton.size) buffer_write(bones, buffer_u8, 0);
		size = array_length(stacks);
		for(var i=0; i<size; i++)
		{
			var stack = stacks[i];
			buffer_seek(stack.sample, buffer_seek_start, 0);
			stack.visible = false;
			stack.root = false;
			stack.index = i;
			
			var s = buffer_get_size(stack.bones);
			for(var j=0; j<s; j++)
			{
				var bone = buffer_peek(stack.bones, j, buffer_u8);
				buffer_poke(bones, bone, buffer_u8, i+1)
			}
		}
		
		// Check which bone the stack is on top of
		var bone=buffer_peek(bones, 0, buffer_u8)
		if bone>0
		{
			var stack = stacks[bone-1];
			stack.root = true;
			stack.visible = true;
		} else {
			xspeed = 0;
			yspeed = 0;
			zspeed = 0;
		}
		for(var i=1; i<skeleton.size; i++)
		{
			bone = buffer_peek(bones, i, buffer_u8);
			if bone==0 continue;
			var stack = stacks[bone-1];
			buffer_write(stack.sample, buffer_u8, i);
			stack.visible=true;
		}
		stack_anim_ref()
	}
	static clear_stack = function()
	{
		for(var i=0; i<size; i++)
		{
			stacks[i].active = false;
		}
		stacks = [];
		size = 0;
		update_stack()
	}
	static get_bone_transform = function(boneInd, output=array_create(8))
	{
		// Get the bone transform of the current frame
		var buff = buff_anim;
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
}
function animation_player_get_event(player, event=undefined)
{
	// Return true if event string specified is true
	// If event is undefined then returns the event list array.
	if is_undefined(event) return player.event;
	var s = array_length(player.event);
	for(var i=0; i<s; i++)
	{
		if player.event[i] == event return true
	}
	return false;
}
// These function are used by animation_player, leaving here for easy tweaking
function anim_stack_step(stack, _delta)
{
	// Check frame time function, set stack.event for sample function to execute. Return integer.
	//	-1: null
	//	0: animation end (no loop)
	//	1: interpolate between frame
	//	2: read next frame
	//	3: animation end (loop to first frame)
	stack.step_time += _delta*stack.speed;
	var anim = stack.animation;
	var player = stack.player;
	if stack.step_time<=stack.frame_durr
	{	// Next step (Time before next frame)
		stack.step = clamp(stack.step_time/stack.frame_durr,0,1);
		stack.event = 1;
		return 1;
	} else {// End of frame
		if (anim==-1)
		{
			if stack.update_layer
			{
				stack.frame_durr=animation_default_speed;
				stack.step_time = _delta*stack.speed; stack.step = clamp(stack.step_time/stack.frame_durr,0,1);
				stack.event=4;
				return 4; // No animation, sample layer
			}
			stack.event=-2;
			return -2;
		}
		// Seek next frame
		var f = -1;
		var s = array_length(anim.keyframe);
		stack.step_time-=stack.frame_durr;
		for(var i=max(0,stack.frame+1); i<s; i++) 
		{
			var k = anim.keyframe[i]
			if k.name!=0 array_push(player.event, k.name);
			if k.time>stack.time {f=i; break}
		}
		if !(f==-1)	// next frame
		{
			stack.previous = max(0, stack.frame);
			stack.frame = f;
			var t = anim.keyframe[f].time;
			stack.frame_durr = t - stack.time;
			stack.time = t;
			stack.step = clamp(stack.step_time/stack.frame_durr,0,1);
			stack.event = 2;
			return 2;
		} else {	// No next frame found (animation end)
			if stack.loop
			{
				f=0; stack.time=0
				for(var i=0; i<s; i++)
				{
					var k = anim.keyframe[i]
					if k.name!=0 array_push(player.event, k.name);
					if k.time>stack.time {f=i; break} 
				}
				//stack.time=anim.keyframe[f].time;
				stack.previous = max(0, stack.frame);
				stack.frame = f;
				var t = anim.keyframe[f].time;
				stack.frame_durr = t - stack.time;
				stack.time = t;
				stack.step = clamp(stack.step_time/stack.frame_durr,0,1);
				stack.event = 3;
				return 3;	// End of animation, looping
			} else {
				if stack.frame<s-1
				{
					// Not the last frame?
					stack.step_time = stack.frame_durr;
					stack.previous = max(0, stack.frame);
					stack.frame=s-1;
					stack.step=1;
					stack.event=2;
					return 2
				}
				if stack.frame_durr==0 {stack.event=-1;stack.step=1;return -1}
				stack.step_time=1;
				stack.frame_durr=0;
				stack.previous = max(0, stack.frame);
				stack.frame = s;
				stack.event = 0;
				stack.step = 1;
				return 0;	// End of animation, no loop
			}
		}
	}
}
function anim_stack_sample(stack)
{
	// Sample animation frame function
	var s = buffer_tell(stack.sample);
	var player = stack.player;
	var skeleton = player.skeleton;
	var buff_prev = player.buff_prev;
	var buff_next = player.buff_anim;
	switch(stack.event)
	{
		case 2:	// Animation play next frame
		case 3:	// Animation starting/looping
			var anim = stack.animation;
			var w = anim.width;
			for(var i=0; i<s; i++)
			{
				var boneInd = buffer_peek(stack.sample, i, buffer_u8);
				var animInd = buffer_peek(anim_index, boneInd, buffer_u8);
				var b = boneInd*8;
				var interpolate = buffer_peek(buff_next, 4*(b+7), buffer_f32);
				for(var j=0; j<7; j++)
				{
					var val = lerp(buffer_peek(buff_prev, 4*(b+j), buffer_f32), buffer_peek(buff_next, 4*(b+j), buffer_f32), interpolate);
					buffer_poke(buff_prev, 4*(b+j), buffer_f32, val);
				}
				if animInd>=anim.height continue;
				for(var j=0; j<7; j++) buffer_poke(buff_next, 4*(b+j), buffer_f32, animation_data_read(anim, 8*stack.frame+j, animInd));
			}
			if stack.root
			{
				var animInd = buffer_peek(anim_index, 0, buffer_u8);
				var interpolate = buffer_peek(buff_next, 4*(7), buffer_f32);
				for(var j=0; j<7; j++)
				{
					var val1 = lerp(buffer_peek(buff_prev, 4*(j), buffer_f32), buffer_peek(buff_next, 4*(j), buffer_f32), interpolate);
					buffer_poke(buff_prev, 4*j, buffer_f32, val1);
				}
				for(var j=0; j<4; j++)
				{
					var val2 = animation_data_read(anim, 8*stack.frame+j, animInd);
					buffer_poke(buff_next, 4*j, buffer_f32, val2);
				}
				var xfrom, yfrom, zfrom, xto, yto, zto, xspd, yspd, zspd;
				xprevious = xroot; yprevious = yroot; zprevious = zroot
				//xprevious = xreal; yprevious = yreal; zprevious = zreal
				if (stack.event==3)
				{
					if x_loop xroot=0;
					if y_loop yroot=0;
					if z_loop zroot=0;
				}
				if stack.frame==0
				{
					if x_loop xroot=animation_data_read(anim, 4, animInd) else xroot+=animation_data_read(anim, 4, animInd);
					if y_loop yroot=animation_data_read(anim, 5, animInd) else yroot+=animation_data_read(anim, 5, animInd);
					if z_loop zroot=animation_data_read(anim, 6, animInd) else zroot+=animation_data_read(anim, 6, animInd);
				} else {
					if x_loop xroot=animation_data_read(anim, 8*stack.frame+4, animInd) else xroot+=animation_data_read(anim, 8*stack.frame+4, animInd) - animation_data_read(anim, 8*(stack.previous)+4, animInd);
					if y_loop yroot=animation_data_read(anim, 8*stack.frame+5, animInd) else yroot+=animation_data_read(anim, 8*stack.frame+5, animInd) - animation_data_read(anim, 8*(stack.previous)+5, animInd);
					if z_loop zroot=animation_data_read(anim, 8*stack.frame+6, animInd) else zroot+=animation_data_read(anim, 8*stack.frame+6, animInd) - animation_data_read(anim, 8*(stack.previous)+6, animInd);
				}
				if !x_lock buffer_poke(buff_next, 4*4, buffer_f32, xroot);
				if !y_lock buffer_poke(buff_next, 4*5, buffer_f32, yroot);
				if !z_lock buffer_poke(buff_next, 4*6, buffer_f32, zroot);
			}
			break
		
		case 0: // Animation end (no loop)
			for(var i=0; i<s; i++)
			{
				var boneInd = buffer_peek(stack.sample, i, buffer_u8);
				var b = boneInd*8;
				for(var j=0; j<7; j++)
				{
					var val = buffer_peek(buff_next, 4*(b+j), buffer_f32);
					buffer_poke(buff_prev, 4*(b+j), buffer_f32, val);
				}
			}
			if stack.root
			{
				for(var j=0; j<7; j++)
				{
					var val1 = buffer_peek(buff_next, 4*(j), buffer_f32);
					buffer_poke(buff_prev, 4*j, buffer_f32, val1);
				}
				var xfrom, yfrom, zfrom, xto, yto, zto, xspd, yspd, zspd;
				xprevious=xreal; yprevious=yreal; zprevious=zreal
				xspeed=0; yspeed=0; zspeed=0
				xroot=xreal; yroot=yreal; zroot=zreal
			}
			break
	}
	
	if (stack.event==4)
	{
		stack.update_layer = false;
		for(var i=0; i<s; i++)
		{
			var boneInd = buffer_peek(stack.sample, i, buffer_u8);
			var b = boneInd*8;
			for(var j=0; j<8; j++) buffer_poke(buff_prev, 4*(b+j), buffer_f32, buffer_peek(buff_next, 4*(b+j), buffer_f32));
		}
		if stack.root for(var j=0; j<7; j++) buffer_poke(buff_prev, 4*j, buffer_f32, buffer_peek(buff_next, 4*j, buffer_f32));
	}
	
	if stack.event>=0
		{
			// Layer sample
			var l = array_length(stack.layers)
			for(var i=0; i<l; i++)
			{
				var L = stack.layers[i];
				L.func(stack, L);
			}
			
			for(var i=0; i<s; i++)
			{
				var boneInd = buffer_peek(stack.sample, i, buffer_u8);
				var b = boneInd*8;
				buffer_poke(buff_next, 4*(b+7), buffer_f32, stack.step);
			}
			if stack.root
			{
				buffer_poke(buff_next, 4*7, buffer_f32, stack.step);
				var xx, yy, zz
				xx = lerp(xprevious, xroot, stack.step);
				yy = lerp(yprevious, yroot, stack.step);
				zz = lerp(zprevious, zroot, stack.step);
				xspeed = xx - xreal;
				yspeed = yy - yreal;
				zspeed = zz - zreal;
				xreal=xx; yreal=yy; zreal=zz
				
				var f = stack.frame_durr*60
			}
		}
}
function anim_layer_sample()
{
	// Layer function, see stack layer function below for more information
	static rotate_bone = function(stack, layer)
	{
		if !(stack.event>1) return;
		var player = stack.player;
		if layer.amount==0 return;
		if is_array(layer.boneInd)
		{
			var s = array_length(layer.boneInd);
			for(var i=0; i<s; i++)
			{
				if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd[i]) return;
				anim_layer_sample.rotate_animation(stack, layer, layer.boneInd[i])
			}
		} else {
			if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
			anim_layer_sample.rotate_animation(stack, layer, layer.boneInd)
		}
		
	}
	static blend_frame = function(stack, layer)
	{
		if !(stack.event>1) return;
		var player = stack.player;
		var buffer = player.buff_anim
		var val1, val2;
		var anim = layer.animation;
		var w = anim.width;
		var frame = clamp(layer.frame, 0, (w/8)-1);
		var fract = frac(frame);
		frame = floor(frame);
		var s = buffer_tell(stack.sample);
		for(var i=0; i<s; i++)
		{
			var boneInd = buffer_peek(stack.sample, i, buffer_u8);
			var animInd = buffer_peek(player.anim_index, boneInd, buffer_u8);
			var b = boneInd*8;
			for(var j=0; j<8; j++)
			{
				if animInd>=anim.height continue;
				val1 = buffer_peek(buffer, 4*(b+j), buffer_f32);
				if (fract==0)
				{
					// No interpolation
					val2 = animation_data_read(anim, 8*frame+j, animInd);
				} else {
					// Frame interpolation
					val2 = lerp(animation_data_read(anim, 8*frame+j, animInd), animation_data_read(anim, 8*(frame+1)+j, animInd), fract);
				}
				buffer_poke(buffer, 4*(b+j), buffer_f32, lerp(val1, val2, layer.amount));
			}
		}
		if stack.root
		{
			var animInd = buffer_peek(player.anim_index, 0, buffer_u8);
			// Rotation interpolation
			for(var j=0; j<4; j++)
			{
				var val1 = buffer_peek(buffer, 4*j, buffer_f32);
				if (fract==0)
				{
					val2 = animation_data_read(anim, 8*frame+j, animInd);
				} else {
					val2 = lerp(animation_data_read(anim, 8*frame+j, animInd), animation_data_read(anim, 8*(frame+1)+j, animInd), fract);
				}
				buffer_poke(buffer, 4*j, buffer_f32, lerp(val1, val2, layer.amount));
			}
		}
	}
	static blend_animation = function(stack, layer)
	{
		static _wrap = function(value,val1,val2) {
			if value = val1 return 0;
			var temp = (((value - val1) % (val2 - val1)) + (val2 - val1)) % (val2 - val1) + val1;
			if temp = 0 return 1 else return temp}
			
		if !(stack.event>1) return;
		if stack.animation==-1 return;
		var player = stack.player;
		var skeleton = player.skeleton
		if layer.amount==0 return;
		var pframe=-1;
		var anim, f, time=0, durr1, durr2;
		switch(layer.mode)
		{
			// Get frame index based on current blend mode
			case anim_blendmode.frame:
				s = animation_get_frames(layer.animation);
				layer.frame = stack.frame + 1 + layer.offset;
				layer.frame = _wrap(layer.frame, 0, s);
				pframe = max(layer.frame-1, -1);
				anim = layer.animation; 
				break;
				
			default:
			case anim_blendmode.duration:
				anim = layer.animation;
				durr1 = animation_get_duration(stack.animation);
				durr2 = animation_get_duration(layer.animation);
				var step = stack.time / durr1;
				time = _wrap((step * durr2) + layer.offset, 0, durr2);
				layer.frame = animation_get_frame(anim, time);
				time = max(time-stack.frame_durr/(durr1/durr2), 0)
				pframe = animation_get_frame(anim, time);
				break
			case anim_blendmode.time:
				anim = layer.animation;
				var step = stack.time + layer.offset;
				time = _wrap(step, 0, animation_get_duration(layer.animation));
				layer.frame = animation_get_frame(anim, time);
				time = max(time-stack.frame_durr, 0);
				pframe = animation_get_frame(anim, time);
				break
		}
		var frame = max(layer.frame, 0);
		var fract = frac(layer.frame); frame=floor(frame);
		
		var buffer=player.buff_anim;
		var s = buffer_tell(stack.sample);
		for(var i=0; i<s; i++)
		{
			var boneInd = buffer_peek(stack.sample, i, buffer_u8);
			var animInd = buffer_peek(player.anim_index, boneInd, buffer_u8);
			var b = boneInd*8;
			for(var j=0; j<8; j++)
			{
				if animInd>=anim.height continue;
				var val1 = buffer_peek(buffer, 4*(b+j), buffer_f32);
				var val2 = animation_data_read(anim, 8*frame+j, animInd);
				if (fract>0) {val2 = lerp(val2, animation_data_read(anim, 8*(frame+1)+j, animInd), fract);}
				buffer_poke(buffer, 4*(b+j), buffer_f32, lerp(val1, val2, layer.amount));
			}
		}
		if stack.root
		{
			var animInd = buffer_peek(player.anim_index, 0, buffer_u8);
			// Rotation interpolation
			for(var j=0; j<4; j++)
			{
				var val1 = buffer_peek(buffer, 4*j, buffer_f32);
				val2 = animation_data_read(anim, 8*frame+j, 0);
				if (fract>0) {val2 = lerp(val2, animation_data_read(anim, 8*(frame+1)+j, animInd), fract);}
				buffer_poke(buffer, 4*j, buffer_f32, lerp(val1, val2, layer.amount));
			}
			if !layer.translate return;
			
			if player.x_loop player.xroot=lerp(player.xroot, animation_data_read(anim, 8*frame+4, 0), layer.amount);
			if player.y_loop player.yroot=lerp(player.yroot, animation_data_read(anim, 8*frame+5, 0), layer.amount);
			if player.z_loop player.zroot=lerp(player.zroot, animation_data_read(anim, 8*frame+6, 0), layer.amount);
			
			var xspd=0, yspd=0, zspd=0, f;
			if frame==0
			{
				f = (anim.keyframe[frame].time)*60;
				if !player.x_loop xspd = animation_data_read(anim, 4, 0)/f;
				if !player.y_loop yspd = animation_data_read(anim, 5, 0)/f;
				if !player.z_loop zspd = animation_data_read(anim, 6, 0)/f;
			} else {
				f = (anim.keyframe[frame].time - anim.keyframe[frame-1].time)*60;
				if !player.x_loop xspd = (animation_data_read(anim, 8*frame+4, 0) - animation_data_read(anim, 8*(frame-1)+4, 0))/f;
				if !player.y_loop yspd = (animation_data_read(anim, 8*frame+5, 0) - animation_data_read(anim, 8*(frame-1)+5, 0))/f;
				if !player.z_loop zspd = (animation_data_read(anim, 8*frame+6, 0) - animation_data_read(anim, 8*(frame-1)+6, 0))/f;
			}
			anim = stack.animation.keyframe;
			if stack.frame==0 f=anim[0].time*60 else f=(anim[stack.frame].time-anim[stack.frame-1].time)*60;
			   
			if !player.x_loop player.xroot=lerp(player.xroot, player.xprevious+xspd*f, layer.amount);
			if !player.y_loop player.yroot=lerp(player.yroot, player.yprevious+yspd*f, layer.amount);
			if !player.z_loop player.zroot=lerp(player.zroot, player.zprevious+zspd*f, layer.amount);
						
			if !player.x_lock buffer_poke(buffer, 4*4, buffer_f32, player.xroot);
			if !player.y_lock buffer_poke(buffer, 4*5, buffer_f32, player.yroot);
			if !player.z_lock buffer_poke(buffer, 4*6, buffer_f32, player.zroot);
		}
	}
	static IK_world = function(stack, layer)
	{
		if !(stack.event>0) return;
		var player = stack.player;
		var skeleton = player.skeleton;
		if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
		
		// Update relevant bone to get actual position
		var s = array_length(layer.bones);
		for(var i=0;i<s;i++) player.update_bone(layer.bones[i], skeleton.transform, undefined, stack.step);
		
		// Simple 2 joint inverse-kinematic
		var pos = matrix_transform_vertex(skeleton.matrix_inv, layer.x, layer.y, layer.z);
		anim_layer_sample.instant_IK(player, layer.boneInd, pos[0], pos[1], pos[2], layer.stretch, layer.childs);
		return false;
	}
	static IK_bind = function(stack, layer)
	{
		if !(stack.event>1) return;
		var player = stack.player;
		var skeleton = player.skeleton;
		if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
		// Update relevant bone to get actual position
		var s = array_length(layer.bones);
		for(var i=0;i<s;i++) player.update_bone(layer.bones[i], undefined, undefined, 1);
		
		static pos = array_create(3);
		static sample = array_create(8);
		skeleton_get_sample_transform(skeleton, layer.bindInd, sample);
		quaternion_transform_vector(sample, layer.x, layer.y, layer.z, pos);
		var bind = skeleton.data[layer.bindInd];
		var xx = bind.x + pos[0];
		var yy = bind.y + pos[1];
		var zz = bind.z + pos[2];
		quaternion_multiply(sample, layer.quaternion, sample);
		
		player.bone_set_rotation(layer.boneInd, sample[0], sample[1], sample[2], sample[3]);
		anim_layer_sample.simple_IK(player, layer.boneInd, xx, yy, zz, layer.stretch, false);
	}
	static bone_inherit = function(stack,layer)
	{
		if !(stack.event>1) return;
		var player = stack.player;
		if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
		var buff = player.buff_anim;
		var qx, qy, qz, qw, xx, yy, zz;
		var b = layer.bindInd * 8;
		qx = buffer_peek(buff, 4*(b), buffer_f32);
		qy = buffer_peek(buff, 4*(b+1), buffer_f32);
		qz = buffer_peek(buff, 4*(b+2), buffer_f32);
		qw = buffer_peek(buff, 4*(b+3), buffer_f32);
		player.rotate_bone(layer.boneInd, qx, qy, qz, qw, layer.local, layer.childs);
		
		/*
		xx = buffer_peek(buff, 4*(b+4), buffer_f32);
		yy = buffer_peek(buff, 4*(b+5), buffer_f32);
		zz = buffer_peek(buff, 4*(b+6), buffer_f32);
		player.move_bone(layer.boneInd, xx, yy, zz);
		*/
	}
	static anchor_IK = function(stack, layer)
	{
		if !(stack.event>1) return;
		if (stack.animation==-1) return;
		var player = stack.player;
		if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
		var skeleton = player.skeleton;
		var frame = stack.frame;
		var anim = stack.animation;
		
		static bone_pos = array_create(3);
		static bind_pos = array_create(3);
		animation_predict_position(anim, frame, skeleton, layer.boneInd, false, bone_pos);
		animation_predict_position(anim, frame, skeleton, layer.bindInd, false, bind_pos);
		for(var i=0; i<3; i++) bone_pos[i] -= bind_pos[i];
		
		static bone_rot = array_create(4);
		static bind_rot = array_create(4);
		for(var i=0; i<4; i++) bone_rot[@i] = animation_data_read(anim, 8*frame+i, layer.boneInd);
		for(var i=0; i<4; i++) bind_rot[@i] = animation_data_read(anim, 8*frame+i, layer.bindInd);
		
		var s = array_length(layer.bones);
		for(var i=0;i<s;i++) player.update_bone(layer.bones[i], undefined, undefined, 1);
		
		static sample = array_create(8);
		var bind = skeleton.data[layer.bindInd];
		skeleton_get_sample_transform(skeleton, layer.bindInd, sample)
		quaternion_difference(sample, bind_rot, sample)
		sample[@0] = lerp(sample[0], 0, layer.amount);
		sample[@1] = lerp(sample[1], 0, layer.amount);
		sample[@2] = lerp(sample[2], 0, layer.amount);
		sample[@3] = lerp(sample[3], 1, layer.amount);
		var s=0;	for(var i=0; i<4; i++) s = sample[i]*sample[i]
		var l = 1 / sqrt(s);
		for(var i=0; i<4; i++) sample[@i] = sample[i]*l
		
		quaternion_transform_vector(sample, bone_pos[0], bone_pos[1], bone_pos[2], bind_pos);
		var xx = bind.x + lerp(bone_pos[0], bind_pos[0], layer.amount)
		var yy = bind.y + lerp(bone_pos[1], bind_pos[1], layer.amount)
		var zz = bind.z + lerp(bone_pos[2], bind_pos[2], layer.amount)
		anim_layer_sample.simple_IK(player, layer.boneInd, xx, yy, zz, layer.stretch, false);
		
		quaternion_multiply(sample, bone_rot, bone_rot)
		player.bone_set_rotation(layer.boneInd, bone_rot[0], bone_rot[1], bone_rot[2], bone_rot[3]);
	}
	static bind_transform = function(stack, layer)
	{
		if !(stack.event>1) return;
		var player = stack.player;
		var skeleton = player.skeleton;
		if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
		static pos = array_create(3);
		static translate = array_create(3);
		static quat = array_create(4);
		anim_layer_sample.predict_position(skeleton, layer.bindInd, player.buff_anim, true, pos);
		var b = layer.bindInd*8
		for(var i=0; i<4; i++) quat[@i] = buffer_peek(player.buff_anim, 4*(b+i), buffer_f32);
		quaternion_transform_vector(quat, layer.x, layer.y, layer.z, translate);
		quaternion_multiply(quat, layer.quaternion, quat);
		
		player.bone_set_rotation(layer.boneInd, quat[0], quat[1], quat[2], quat[3]);
		player.bone_set_position(layer.boneInd, pos[0]+translate[0], pos[1]+translate[1], pos[2]+translate[2]);
		
	}
	static bone_transform = function(stack, layer)
	{
		if !(stack.event>1) return;
		var player = stack.player;
		if !anim_layer_sample.bone_check_stack(player, stack, layer.boneInd) return;
		
		var q = layer.quaternion;		
		player.bone_set_rotation(layer.boneInd, q[0], q[1], q[2], q[3]);
		player.bone_set_position(layer.boneInd, layer.x, layer.y, layer.z)
	}
	
	static rotate_animation = function(stack, layer, boneInd)
	{
		var player = stack.player;
		var buffer = player.buff_anim;
		var skeleton = player.skeleton;
		if (layer.blendmode == anim_blendmode.rotate_set)
		{
			var qx = layer.quaternion[0]
			var qy = layer.quaternion[1]
			var qz = layer.quaternion[2]
			var qw = layer.quaternion[3]
			if layer.amount==1
			{
				var b = boneInd*8;
				buffer_poke(buffer, 4*(b+0), buffer_f32, qx);
				buffer_poke(buffer, 4*(b+1), buffer_f32, qy);
				buffer_poke(buffer, 4*(b+2), buffer_f32, qz);
				buffer_poke(buffer, 4*(b+3), buffer_f32, qw);
				if !layer.childs return;
				var childs = skeleton.bindmap[boneInd];
				var c = array_length(childs);
				for(var j=0; j<c; j++)
				{
					var bone = childs[j]
					if bone.inherit continue;
					if !anim_layer_sample.bone_check_stack(player, stack, bone.index) continue;
					b = bone.index*8;
					buffer_poke(buffer, 4*(b+0), buffer_f32, qx);
					buffer_poke(buffer, 4*(b+1), buffer_f32, qy);
					buffer_poke(buffer, 4*(b+2), buffer_f32, qz);
					buffer_poke(buffer, 4*(b+3), buffer_f32, qw);
				}
			} else {
				var b = boneInd*8;
				buffer_poke(buffer, 4*(b+0), buffer_f32, lerp(buffer_peek(buffer, 4*(b+0), buffer_f32), qx, layer.amount));
				buffer_poke(buffer, 4*(b+1), buffer_f32, lerp(buffer_peek(buffer, 4*(b+1), buffer_f32), qy, layer.amount));
				buffer_poke(buffer, 4*(b+2), buffer_f32, lerp(buffer_peek(buffer, 4*(b+2), buffer_f32), qz, layer.amount));
				buffer_poke(buffer, 4*(b+3), buffer_f32, lerp(buffer_peek(buffer, 4*(b+3), buffer_f32), qw, layer.amount));
				if !layer.childs return;
				var childs = skeleton.bindmap[boneInd];
				var c = array_length(childs);
				for(var j=0; j<c; j++)
				{
					var bone = childs[j]
					if bone.inherit continue;
					if !anim_layer_sample.bone_check_stack(player, stack, bone.index) continue;
					b = bone.index*8;
					buffer_poke(buffer, 4*(b+0), buffer_f32, lerp(buffer_peek(buffer, 4*(b+0), buffer_f32), qx, layer.amount));
					buffer_poke(buffer, 4*(b+1), buffer_f32, lerp(buffer_peek(buffer, 4*(b+1), buffer_f32), qy, layer.amount));
					buffer_poke(buffer, 4*(b+2), buffer_f32, lerp(buffer_peek(buffer, 4*(b+2), buffer_f32), qz, layer.amount));
					buffer_poke(buffer, 4*(b+3), buffer_f32, lerp(buffer_peek(buffer, 4*(b+3), buffer_f32), qw, layer.amount));
				}
			}
		} else if (layer.blendmode == anim_blendmode.rotate_local)
		{
			var b = boneInd*8;
			var qax = lerp(layer.quaternion[0], 0, 1-layer.amount);
			var qay = lerp(layer.quaternion[1], 0, 1-layer.amount);
			var qaz = lerp(layer.quaternion[2], 0, 1-layer.amount);
			var qaw = lerp(layer.quaternion[3], 1, 1-layer.amount);
			var qbx = buffer_peek(buffer, 4*(b+0), buffer_f32);
			var qby = buffer_peek(buffer, 4*(b+1), buffer_f32);
			var qbz = buffer_peek(buffer, 4*(b+2), buffer_f32);
			var qbw = buffer_peek(buffer, 4*(b+3), buffer_f32);
			buffer_poke(buffer, 4*(b+0), buffer_f32, qbw * qax + qbx * qaw + qby * qaz - qbz * qay);
			buffer_poke(buffer, 4*(b+1), buffer_f32, qbw * qay + qby * qaw + qbz * qax - qbx * qaz);
			buffer_poke(buffer, 4*(b+2), buffer_f32, qbw * qaz + qbz * qaw + qbx * qay - qby * qax);
			buffer_poke(buffer, 4*(b+3), buffer_f32, qbw * qaw - qbx * qax - qby * qay - qbz * qaz);
			if !layer.childs return;
			var childs = skeleton.bindmap[boneInd];
			var c = array_length(childs)
			for(var j=0; j<c; j++)
			{
				var bone = childs[j]
				if bone.inherit continue;
				if !anim_layer_sample.bone_check_stack(player, stack, bone.index) continue;
				b = bone.index*8;
				var qbx = buffer_peek(buffer, 4*(b+0), buffer_f32);
				var qby = buffer_peek(buffer, 4*(b+1), buffer_f32);
				var qbz = buffer_peek(buffer, 4*(b+2), buffer_f32);
				var qbw = buffer_peek(buffer, 4*(b+3), buffer_f32);
				buffer_poke(buffer, 4*(b+0), buffer_f32, qbw * qax + qbx * qaw + qby * qaz - qbz * qay);
				buffer_poke(buffer, 4*(b+1), buffer_f32, qbw * qay + qby * qaw + qbz * qax - qbx * qaz);
				buffer_poke(buffer, 4*(b+2), buffer_f32, qbw * qaz + qbz * qaw + qbx * qay - qby * qax);
				buffer_poke(buffer, 4*(b+3), buffer_f32, qbw * qaw - qbx * qax - qby * qay - qbz * qaz);
			}
		} else {
			var b = boneInd*8;
			var qbx = lerp(layer.quaternion[0], 0, 1-layer.amount);
			var qby = lerp(layer.quaternion[1], 0, 1-layer.amount);
			var qbz = lerp(layer.quaternion[2], 0, 1-layer.amount);
			var qbw = lerp(layer.quaternion[3], 1, 1-layer.amount);
			var qax = buffer_peek(buffer, 4*(b+0), buffer_f32);
			var qay = buffer_peek(buffer, 4*(b+1), buffer_f32);
			var qaz = buffer_peek(buffer, 4*(b+2), buffer_f32);
			var qaw = buffer_peek(buffer, 4*(b+3), buffer_f32);
			buffer_poke(buffer, 4*(b+0), buffer_f32, qbw * qax + qbx * qaw + qby * qaz - qbz * qay);
			buffer_poke(buffer, 4*(b+1), buffer_f32, qbw * qay + qby * qaw + qbz * qax - qbx * qaz);
			buffer_poke(buffer, 4*(b+2), buffer_f32, qbw * qaz + qbz * qaw + qbx * qay - qby * qax);
			buffer_poke(buffer, 4*(b+3), buffer_f32, qbw * qaw - qbx * qax - qby * qay - qbz * qaz);
			if !layer.childs return;
			var childs = skeleton.bindmap[boneInd];
			var c = array_length(childs)
			for(var j=0; j<c; j++)
			{
				var bone = childs[j]
				if bone.inherit continue;
				if !anim_layer_sample.bone_check_stack(player, stack, bone.index) continue;
				b = bone.index*8;
				var qax = buffer_peek(buffer, 4*(b+0), buffer_f32);
				var qay = buffer_peek(buffer, 4*(b+1), buffer_f32);
				var qaz = buffer_peek(buffer, 4*(b+2), buffer_f32);
				var qaw = buffer_peek(buffer, 4*(b+3), buffer_f32);
				buffer_poke(buffer, 4*(b+0), buffer_f32, qbw * qax + qbx * qaw + qby * qaz - qbz * qay);
				buffer_poke(buffer, 4*(b+1), buffer_f32, qbw * qay + qby * qaw + qbz * qax - qbx * qaz);
				buffer_poke(buffer, 4*(b+2), buffer_f32, qbw * qaz + qbz * qaw + qbx * qay - qby * qax);
				buffer_poke(buffer, 4*(b+3), buffer_f32, qbw * qaw - qbx * qax - qby * qay - qbz * qaz);
			}
		}
	}
	static bone_check_stack = function(player, stack, boneInd)
	{
		var index = buffer_peek(player.bones, boneInd, buffer_u8)-1;
		if (index==stack.index) return true;
		return false
	}
	static simple_IK = function(player, boneInd, x, y, z, stretch, childs)
	{
		static rotate_toward = function(player, boneInd, v0, v1, childs)
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
			player.rotate_bone(boneInd, Qx, Qy, Qz, Qw, false, childs);
			return true
		}
		var skeleton = player.skeleton;
		var bone = skeleton.data[boneInd];
		var link = skeleton.data[bone.link];
		var root = skeleton.data[link.link];
		
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
		if stretch {player.bone_set_position(boneInd, 0,0,0);player.bone_set_position(link.index, 0,0,0)}
		v0[@0] = v1[0]*t+vec[0]*up;
		v0[@1] = v1[1]*t+vec[1]*up;
		v0[@2] = v1[2]*t+vec[2]*up;
		vec[@0]=link.x-root.x;	vec[@1]=link.y-root.y;	vec[@2]=link.z-root.z
		rotate_toward(player, root.index, vec, v0, false);
		v1[@0] = x-(root.x+v0[0]);
		v1[@1] = y-(root.y+v0[1]);
		v1[@2] = z-(root.z+v0[2]);
		vec[@0]=bone.x-link.x;	vec[@1]=bone.y-link.y;	vec[@2]=bone.z-link.z
		rotate_toward(player, link.index, vec, v1, false);
		
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
			player.bone_set_position(link.index, v0[0]*dist*l2, v0[1]*dist*l2, v0[2]*dist*l2);
		
			v0[@0] = bone.Ox-link.Ox;
			v0[@1] = bone.Oy-link.Oy;
			v0[@2] = bone.Oz-link.Oz;
			normalize(v0);
			player.bone_set_position(boneInd, v0[0]*dist*l1, v0[1]*dist*l1, v0[2]*dist*l1);
		}
		return true;
	}
	static instant_IK = function(player, boneInd, x, y, z, stretch, childs)
	{
		static rotate_toward = function(player, boneInd, v0, v1, childs)
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
			player.rotate_bone(boneInd, Qx, Qy, Qz, Qw, false, childs, player.skeleton.transform);
			return true
		}
		var skeleton = player.skeleton;
		var bone = skeleton.data[boneInd];
		var link = skeleton.data[bone.link];
		var root = skeleton.data[link.link];
		
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
		if stretch {player.bone_set_position(boneInd, 0,0,0,skeleton.transform);player.bone_set_position(link.index, 0,0,0,skeleton.transform)}
		v0[@0] = v1[0]*t+vec[0]*up;
		v0[@1] = v1[1]*t+vec[1]*up;
		v0[@2] = v1[2]*t+vec[2]*up;
		vec[@0]=link.x-root.x;	vec[@1]=link.y-root.y;	vec[@2]=link.z-root.z
		rotate_toward(player, root.index, vec, v0, false);
		v1[@0] = x-(root.x+v0[0]);
		v1[@1] = y-(root.y+v0[1]);
		v1[@2] = z-(root.z+v0[2]);
		vec[@0]=bone.x-link.x;	vec[@1]=bone.y-link.y;	vec[@2]=bone.z-link.z
		rotate_toward(player, link.index, vec, v1, false);
		root.skip_transform=false;
		link.skip_transform=false;
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
			player.bone_set_position(link.index, v0[0]*dist*l2, v0[1]*dist*l2, v0[2]*dist*l2,skeleton.transform);
		
			v0[@0] = bone.Ox-link.Ox;
			v0[@1] = bone.Oy-link.Oy;
			v0[@2] = bone.Oz-link.Oz;
			normalize(v0);
			player.bone_set_position(boneInd, v0[0]*dist*l1, v0[1]*dist*l1, v0[2]*dist*l1,skeleton.transform);
		}
		return true;
	}
	static transform_overwrite = function(player, index)
	{
		var buffer = player.skeleton.transform;
		var b = index * 8;
		for(var j=0; j<7; j++)
		{
			var val = buffer_peek(buffer, 4*(b+j), buffer_f32);
			buffer_poke(player.buff_prev, 4*(b+j), buffer_f32, val);
		}
	}
	static predict_position = function(skeleton, boneInd, buffer, root=true, array=array_create(3))
	{
		var xpos=0, ypos=0, zpos=0;
		if root
		{
			var bone = skeleton.data[0]
			xpos = bone.Ox + buffer_peek(buffer, 4*(4), buffer_f32);
			ypos = bone.Oy + buffer_peek(buffer, 4*(5), buffer_f32);
			zpos = bone.Oz + buffer_peek(buffer, 4*(6), buffer_f32);
		}
	
		var xx, yy, zz, qx, qy, qz, qw;
		var bone = skeleton.data[boneInd];
		var i = bone.link;
		while(i>0)
		{
			// Get transform dualquat
			var b = i*8;
			qx = buffer_peek(buffer, 4*(b), buffer_f32);//animation_data_read(anim, 8*frame+0, i);
			qy = buffer_peek(buffer, 4*(b+1), buffer_f32);
			qz = buffer_peek(buffer, 4*(b+2), buffer_f32);
			qw = buffer_peek(buffer, 4*(b+3), buffer_f32);
			var vx = bone.Vx + buffer_peek(buffer, 4*(b+4), buffer_f32);
			var vy = bone.Vy + buffer_peek(buffer, 4*(b+5), buffer_f32);
			var vz = bone.Vz + buffer_peek(buffer, 4*(b+6), buffer_f32);
			var xx = qw*qw*vx + 2*qy*qw*vz - 2*qz*qw*vy + qx*qx*vx + 2*qy*qx*vy + 2*qz*qx*vz - qz*qz*vx - qy*qy*vx;
			var yy = 2*qx*qy*vx + qy*qy*vy + 2*qz*qy*vz + 2*qw*qz*vx - qz*qz*vy + qw*qw*vy - 2*qx*qw*vz - qx*qx*vy;
			var zz = 2*qx*qz*vx + 2*qy*qz*vy + qz*qz*vz - 2*qw*qy*vx - qy*qy*vz + 2*qw*qx*vy - qx*qx*vz + qw*qw*vz;
			xpos+=xx;
			ypos+=yy;
			zpos+=zz;
		
			bone = skeleton.data[bone.link];
			i = bone.link;
		}
	
		// Get transform dualquat
		qx = buffer_peek(buffer, 4*(0), buffer_f32);
		qy = buffer_peek(buffer, 4*(1), buffer_f32);
		qz = buffer_peek(buffer, 4*(2), buffer_f32);
		qw = buffer_peek(buffer, 4*(3), buffer_f32);
		var vx = bone.Vx;
		var vy = bone.Vy;
		var vz = bone.Vz;
		var xx = qw*qw*vx + 2*qy*qw*vz - 2*qz*qw*vy + qx*qx*vx + 2*qy*qx*vy + 2*qz*qx*vz - qz*qz*vx - qy*qy*vx;
		var yy = 2*qx*qy*vx + qy*qy*vy + 2*qz*qy*vz + 2*qw*qz*vx - qz*qz*vy + qw*qw*vy - 2*qx*qw*vz - qx*qx*vy;
		var zz = 2*qx*qz*vx + 2*qy*qz*vy + qz*qz*vz - 2*qw*qy*vx - qy*qy*vz + 2*qw*qx*vy - qx*qx*vz + qw*qw*vz;
		xpos+=xx;
		ypos+=yy;
		zpos+=zz;
	
		array[@0]=xpos;
		array[@1]=ypos;
		array[@2]=zpos;
		return array
	}
	
	static push = function() {anim_push_layer(self); return self}
	static insert = function(index) {anim_insert_layer(index, self); return self}
	static remove = function() {anim_stack_delete_layer(self); return self}
}
anim_layer_sample() // initiate layer sample functions

// A stack is associated with a specific animation_player, first create a stack containing which bone you want to animate using anim_stack_create();
// You can activate this stack by using anim_stack_add(stack) and deactivate it using anim_stack_remove(stack);
// A newly created stack will not have any animation, you can assign animation to a stack using anim_stack_set_animation();
// Stacks will be removed from memory by destroying animation_player (which is destroyed automatically by the skeleton);
function anim_stack_create(player, bones=-1)
{
	// This function create a new animation stack, return a struct;
	// "bones" value can be an array containing list of bone to be animated, or an integer.
	// If "bones" value is an integer, the skeleton bone index and all of its connected children will be animated. Use anim_stack_create(player, 0) to animate entire skeleton;
	var stack = variable_clone(animation_stack)
	stack.player = player;
	array_push(player.childs, stack);
	anim_stack_set_bone(stack, bones)
	return stack;
}
function anim_stack_set_animation(stack, animation, frame=0, speed=1, loop=true, time=0, reference=false)
{
	// Set base animation for an animation_stack;
	// If frame is a decimal value between 0-1, then read as percentage of duration (0.5 means half way through the animation), 1 still means second frame.
	// Frame value can be negative integer, -1 starting from the very last frame, -2 is second last, and so on...
	// Set reference=true to automatically reference skeleton bone to the correct animation bone (matching bone's name).
	//	'Time' value is the transition duration to the next animation (in second), in addition to the specified frame duration;
	var anim;
	if is_struct(animation) anim=animation else anim = animation_reference[? animation];
	if is_undefined(anim) {log("Stack animation failed: could not reference animation: "+string(animation), "error");return undefined}
	stack.animation = anim;
	stack.reference = anim.name;
	stack.speed = speed;
	stack.loop = loop;
	var player = stack.player;
	player.xroot = player.xreal;
	player.yroot = player.yreal;
	player.zroot = player.zreal;
	
	if frame<1 && frac(frame)>0
	{
		var dur = animation_get_duration(anim);
		frame = animation_get_frame(anim, dur*frame);
		if frame<0 frame=0;
	}
	stack.frame = floor(frame);
	if stack.frame==0
	{
		stack.previous = 0;
		stack.time=0-time;
		stack.frame=-1;
	} else {
		var s = array_length(anim.keyframe), k;
		if stack.frame<0 {k = s+stack.frame} else {k = min(stack.frame, s-1)}
		stack.time = anim.keyframe[k-1].time-time;
		stack.frame = k-1;
		stack.previous = max(0, k-1);
	}
	if stack.event<0 stack.step_time=0 else stack.step_time=stack.frame_durr;
	stack.anim_ref = reference;
	stack.duration = animation_get_duration(anim);
	stack.player.stack_anim_ref(stack);
}
function anim_stack_set_bone(stack, bones=-1)
{
	// You can change which bone the stack influents with this function;
	// "bones" value can be an array containing list of bone to be animated, or an integer.
	// If "bones" value is an integer, the skeleton bone index and all of its connected children will be animated.
	//	Use anim_stack_set_bone(stack, -1) to animate entire skeleton;
	if !(stack.bones==-1) buffer_delete(stack.bones);
	if !(stack.sample==-1) buffer_delete(stack.sample);
	var player = stack.player;
	if is_array(bones)
	{
		var s = array_length(bones);
		stack.bones=buffer_create(s, buffer_fixed, 1);
		stack.sample=buffer_create(s, buffer_fixed, 1);
		for(var i=0; i<s; i++)
		{
			buffer_write(stack.bones, buffer_u8, bones[i])
		}
	} else {
		var skeleton = player.skeleton;
		if bones<0
		{
			stack.bones=buffer_create(skeleton.size, buffer_fixed, 1);
			stack.sample=buffer_create(skeleton.size, buffer_fixed, 1);
			for(var i=0; i<skeleton.size; i++) buffer_write(stack.bones, buffer_u8, i);
		} else {
			var bone = skeleton.data[bones]
			var s = array_length(bone.childs);
			stack.bones=buffer_create(s+1, buffer_fixed, 1);
			stack.sample=buffer_create(s+1, buffer_fixed, 1);
			buffer_write(stack.bones, buffer_u8, bone.index);
			for(var i=0; i<s; i++) buffer_write(stack.bones, buffer_u8, bone.childs[i])
		}
	}
	if stack.active player.update_stack();
	return stack;
}
function anim_stack_add_bone(stack, bones)
{
	// You can add new bone for a stack to influence, "bones" value can be an array containing list of bone to be animated, or an integer.
	// If "bones" value is an integer, the skeleton bone index and all of its connected children will be added.
	var size = buffer_get_size(stack.bones);
	var player = stack.player;
	if is_array(bones)
	{
		var s = array_length(bones);
		buffer_resize(stack.bones, size+s)
		buffer_resize(stack.sample, size+s)
		stack.bones=buffer_create(s, buffer_fixed, 1);
		stack.sample=buffer_create(s, buffer_fixed, 1);
		for(var i=0; i<s; i++)
		{
			buffer_write(stack.bones, buffer_u8, bones[i])
		}
	} else {
		var skeleton = player.skeleton;
		var bone = skeleton.data[bones]
		var s = array_length(bone.childs);
		buffer_resize(stack.bones, size+s+1)
		buffer_resize(stack.sample, size+s+1)
		buffer_write(stack.bones, buffer_u8, bone.index);
		for(var i=0; i<s; i++)
		{
			buffer_write(stack.bones, buffer_u8, bone.childs[i])
		}
	}
	if stack.active player.update_stack();
	return stack;
}
function anim_stack_clear_animation(stack)
{
	// Remove base animation from an animation_stack;
	stack.animation = -1;
	stack.reference = "";
	stack.anim_ref = false;
	stack.duration = 0;
}
function anim_stack_playing(stack)
{
	// Return false is animation looping, -1 if animation ended (no loop);
	// Otherwise return a value between [0 - 1] to represent animation progress.
	if stack.event==-1 return -1;
	if stack.event==3 return 0;
	var t = stack.time / stack.duration;
	return max(t, 0.01);
}
function anim_stack_add(stack, index=-1)
{
	// Activate an animation stack; if multiple stack animating the same bone, top stack will override bottom stack instead;
	// Stack is pushed to the top by default; set index value to insert stack in the animation pipeline;
	if stack.active return;
	var player = stack.player;
	if index<0 array_push(player.stacks, stack) else
	{
		index = clamp(index, 0, stack.size-1)
		array_insert(player.stacks, index, stack);
	}
	stack.active = true
	player.update_stack();
}
function anim_stack_move(stack, index)
{
	// Move stack to a different position in the animation pipeline; if multiple stack animating the same bone, top stack will override bottom stack instead;
	if !stack.active return;
	var player = stack.player;
	index = clamp(index, 0, array_length(player.stacks)-1);
	var s = array_length(player.stacks);
	for(var i=0; i<s; i++)
	{
		if player.stacks[i]==stack {break}
	}
	var temp = player.stacks[index]
	player.stacks[index] = stack;
	player.stacks[i] = temp;
	player.update_stack();
}
function anim_stack_remove(stack)
{
	// Deactivate an animation stack; this does not delete stack from memory, you can activate it again using anim_stack_add()
	// A stack will be removed from memory if the animation_player is destroyed;
	if !stack.active return;
	var player = stack.player
	var s = array_length(player.stacks);
	for(var i=0; i<s; i++)
	{
		if player.stacks[i]==stack {array_delete(player.stacks, i, 1); break}
	}
	stack.active = false;
	
	var s = buffer_tell(stack.sample);
	var buff_prev = player.buff_prev;
	var buff_next = player.buff_anim;
	var interpolate = stack.step;
	for(var i=0; i<s; i++)
	{
		var boneInd = buffer_peek(stack.sample, i, buffer_u8);
		var b = boneInd*8;
		for(var j=0; j<7; j++)
		{
			var val = lerp(buffer_peek(buff_prev, 4*(b+j), buffer_f32), buffer_peek(buff_next, 4*(b+j), buffer_f32), interpolate);
			buffer_poke(buff_prev, 4*(b+j), buffer_f32, val);
			buffer_poke(buff_next, 4*(b+j), buffer_f32, val);
		}
	}
	
	player.update_stack();
}
function anim_stack_reset_rotation(stack)
{
	// Set the skeleton rotation to match with the current animation rotation (of the root bone), and return the angle difference for the matrix;
	// This function is specifically made for when animation player x,y movement is locked and you are using matrix to handle movement.
	static rot1 = array_create(4);
	static rot2 = array_create(4);
	static vec = array_create(3);
	static quat_yaw = function(q)
	{
	    var siny_cosp = 2 * (q[3] * q[2] + q[0] * q[1]);
	    var cosy_cosp = 1 - 2 * (q[1] * q[1] + q[2] * q[2]);
	    var yaw = arctan2(siny_cosp, cosy_cosp);
		return radtodeg(yaw);
	}
	
	// Get quaternion
	var player = stack.player;
	for(var i=0; i<4; i++) rot1[@i] = buffer_peek(player.buff_anim, 4*i, buffer_f32);
	var anim = stack.animation;
	for(var i=0; i<4; i++) rot2[@i] = animation_data_read(anim, i, 0);
	
	// Compare their rotation
	var a1 = quat_yaw(rot1);
	var a2 = quat_yaw(rot2);
	var angle = a2 - a1;
	quaternion_build(0,0,1,angle,rot1);
	
	// Write transform to skeleton
	var skeleton = player.skeleton;
	var qbx = rot1[0];
	var qby = rot1[1];
	var qbz = rot1[2];
	var qbw = rot1[3];
	var buffer = player.buff_anim;
	repeat(2)
	{
		for(var i=0; i<skeleton.size; i++)
		{
			var b = i*8;
			var qax = buffer_peek(buffer, 4*(b+0), buffer_f32);
			var qay = buffer_peek(buffer, 4*(b+1), buffer_f32);
			var qaz = buffer_peek(buffer, 4*(b+2), buffer_f32);
			var qaw = buffer_peek(buffer, 4*(b+3), buffer_f32);
			buffer_poke(buffer, 4*(b+0), buffer_f32, qbw * qax + qbx * qaw + qby * qaz - qbz * qay);
			buffer_poke(buffer, 4*(b+1), buffer_f32, qbw * qay + qby * qaw + qbz * qax - qbx * qaz);
			buffer_poke(buffer, 4*(b+2), buffer_f32, qbw * qaz + qbz * qaw + qbx * qay - qby * qax);
			buffer_poke(buffer, 4*(b+3), buffer_f32, qbw * qaw - qbx * qax - qby * qay - qbz * qaz);
			if i==0 continue;
			var bone = skeleton.data[i];
			
			// Rotate position if bone is not linked
			if bone.link>=0 continue;
			var xx = buffer_peek(buffer, 4*(b+4), buffer_f32);
			var yy = buffer_peek(buffer, 4*(b+5), buffer_f32);
			var dis = point_distance(0,0,xx,yy);
			var dir = point_direction(0,0,xx,yy)-angle;
			buffer_poke(buffer, 4*(b+4), buffer_f32, lengthdir_x(dis, dir));
			buffer_poke(buffer, 4*(b+5), buffer_f32, lengthdir_y(dis, dir));
		}
		buffer = player.buff_prev
	}
	return angle;
}

// You can add a layer-effect to a stack to modify it's animation: mixing animations, mix a static frame, rotate bone, inverse-kinematic...
// These function will simply return a struct, use their local function push() or insert() to add them to stack layer array, example: layer = anim_stack_mix_frame(stack, anim, 2).insert(0)
// You can still use some of these layer function even if animation_stack doesn't have any animation, it will update with default speed (animation_default_speed in second)
// These function return a struct; If you want to change their value directly, call anim_stack_update_layer(stack) afterward to update animation properly.
// Most function will only works if the specified bone is being influenced by associated stack.
function anim_stack_rotate_bone(stack, boneInd, quaternion=quaternion_identity(), childs=true, local=false, amount=1)
{
	// Simply rotate a bone by quaternion unit. (after animation sampling), boneInd can be integer, bone_name, or an array of integer or bone_name.
	// Local value can be true(1), false(0), or -1;
	// if true(1): rotate bone in bone's local space, relative to animation;
	// if false(0): rotate bone in world space, relative to animation;
	// if -1: set bone rotation, override animation;
	var player = stack.player;
	var skeleton = player.skeleton;
	if is_array(boneInd)
	{
		var s = array_length(boneInd);
		var bones = [];
		for(var i=0; i<s; i++)
		{
			var bone = check_bone(boneInd[i], skeleton); if !is_undefined(bone) {array_push(bones, bone.index)}
		}
		if array_length(boneInd)==0 {log("Bone not found: "+string(boneInd));return false;}
		boneInd = bones;
	} else {
		var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
		boneInd = bone.index;
	}
	var mode;
	if local mode=anim_blendmode.rotate_local
	else if local=-1 mode=anim_blendmode.rotate_set;
	else mode=anim_blendmode.rotate_world;
	var struct = {
		blendmode: mode,
		boneInd: boneInd,
		quaternion: quaternion,
		childs: childs,
		local: local,
		amount: amount,
		func: anim_layer_sample.rotate_bone,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	return struct;
}
function anim_stack_mix_animation(stack, animation, amount=1, mode=anim_blendmode.duration, movement=true)
{
	// Mix current animation with another animation, Mode can be anim_blendmode.frame, anim_blendmode.time or anim_blendmode.duration;
	// anim_blendmode.frame: Secondary animation will mix at the same frame number;
	// anim_blendmode.time: Secondary animation will mix at the same time, using keyframe nearest to current time (not precise);
	// anim_blendmode.duration: Secondary animation will mix at the same duration percentage (duration is stretched to match main animation), using nearest keyframe (not precise);
	// It will also use the same reference as current animation.
	var anim;
	if is_struct(animation) anim=animation else anim = animation_reference[? animation];
	if is_undefined(anim) {log("Stack animation failed: could not reference animation: "+string(animation), "error");return undefined}
	var struct = {
		blendmode: anim_blendmode.animation,
		animation: anim,
		reference: anim.name,
		amount: amount,
		mode: mode, translate: movement,
		offset: 0,
		frame: 0, time: 0,
		x:0, y:0, z:0,
		func: anim_layer_sample.blend_animation,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	return struct;
}
function anim_stack_mix_frame(stack, animation, frame=0, amount=1)
{ 
	// Mix current animation with a frame of another animation; if frame value is a decimal, interpolate between frames.
	// It will also use the same reference as current animation.
	var anim;
	if is_struct(animation) anim=animation else anim = animation_reference[? animation];
	if is_undefined(anim) {log("Stack animation failed: could not reference animation: "+string(animation), "error");return undefined}
	var struct =
	{
		blendmode: anim_blendmode.frame,
		animation: anim,
		reference: anim.name,
		amount: amount,
		frame: frame,
		func: anim_layer_sample.blend_frame,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	return struct;
}
function anim_stack_world_IK(stack, boneInd, x, y, z, stretch=true, childs=false, amount=1)
{
	// Use simple 2-joint inverse-kinematic to move a bone to target destination in world-space.
	// IK are performed at every step to ensure accuracy, can be costly if use too much.
	// You can use anim_stack_delete_layer() to remove this layer, but anim_stack_world_IK_remove() is recommended instead.
	var player = stack.player;
	var skeleton = player.skeleton;
	var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
	boneInd = bone.index;
	
	// Return false if root bone is connected
	var bone = skeleton.data[boneInd];
	if bone.link==0 return false;
	var link = skeleton.data[bone.link];
	if link.link==0 return false;
	
	var struct =
	{
		blendmode: anim_blendmode.IK_world,
		boneInd: boneInd,
		x:x, y:y, z:z,
		stretch: stretch,
		childs: childs,
		amount: amount,
		func: anim_layer_sample.IK_world,
		bones: [link.link, bone.link, boneInd],
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
		
	}
	while(link.link>0)
	{
		link = skeleton.data[link.link];
		array_insert(struct.bones, 0, link.link);
	}
	return struct;
}
	function anim_stack_world_IK_remove(stack, layer)
	{
		// Set current bone rotation to animation-buffer for proper interpolation (preventing bone snapping back to animation position).
		// Then remove this layer from stack.
		var player=stack.player;
		var skeleton = player.skeleton;
		var s = array_length(layer.bones)
		anim_layer_sample.transform_overwrite(player, layer.bones[s-3]);
		anim_layer_sample.transform_overwrite(player, layer.bones[s-2]);
		anim_stack_delete_layer(stack, layer)
	}
function anim_stack_bind_IK(stack, boneInd, bindInd, x, y, z, rotation=quaternion_identity(), stretch=true)
{
	// Use simple 2-joint inverse-kinematic to move a bone to position of another bone.
	//	offset position and rotation are relative to the binding-bone's origin.
	var player = stack.player;
	var skeleton = player.skeleton;
	var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
	boneInd = bone.index;
	var bone = check_bone(bindInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(bindInd));return false;}
	bindInd = bone.index
	
	// Return false if root bone is connected
	var bone = skeleton.data[boneInd];
	if bone.link==0 return false;
	var link = skeleton.data[bone.link];
	if link.link==0 return false;
	
	var rot;
	if is_array(rotation) {rot=rotation} else {rot = skeleton_get_sample_transform(skeleton, boneInd);}
	
	var struct = {
		blendmode: anim_blendmode.IK_bind,
		boneInd: boneInd,
		bindInd: bindInd,
		x:x, y:y, z:z,
		quaternion: rot,
		stretch: stretch,
		func: anim_layer_sample.IK_bind,
		bones: [link.link, bone.link, boneInd],
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	while(link.link>0)
	{
		link = skeleton.data[link.link];
		array_push(struct.bones, link.link);
	}
	array_push(struct.bones, bindInd);
	link = skeleton.data[bindInd];
	while(link.link>0)
	{
		link = skeleton.data[link.link];
		array_push(struct.bones, link.index);
	}
	array_sort(struct.bones, true)
	var s = array_unique_ext(struct.bones);
	array_resize(struct.bones, s)
	
	return struct;
}
function anim_stack_bind_inherit(stack, boneInd, bindInd, childs=true, local=false)
{
	// Make a bone inherit rotation of another bone
	var player = stack.player;
	var skeleton = player.skeleton;
	var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
	boneInd = bone.index;
	var bone = check_bone(bindInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(bindInd));return false;}
	bindInd = bone.index
		
	var bind = skeleton.data[bindInd];
	var struct = {
		blendmode: anim_blendmode.inherit,
		boneInd: boneInd,
		bindInd: bindInd,
		childs: childs,
		local: local,
		func: anim_layer_sample.bone_inherit,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	return struct;
}
function anim_stack_bind_transform(stack, boneInd, bindInd, x, y, z, rotation=quaternion_identity())
{
	// Bind a bone to another bone's transform and rotation (the bone still follow its hiearchy transformation)
	//	Use to attach unlinked bone to another bone, if bone is already linked to another bone, transformation will be skewed.
	var player = stack.player;
	var skeleton = player.skeleton;
	var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
	boneInd = bone.index;
	var bone = check_bone(bindInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(bindInd));return false;}
	bindInd = bone.index
		
	var rot;
	if is_array(rotation) {rot=rotation} else {rot = skeleton_get_sample_transform(skeleton, boneInd);}
	
	var struct = {
		blendmode: anim_blendmode.transform_bind,
		boneInd: boneInd,
		bindInd: bindInd,
		x:x, y:y, z:z,
		quaternion: rot,
		func: anim_layer_sample.bind_transform,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}	
	return struct;
}
function anim_stack_bone_transform(stack, boneInd, x, y, z, rotation=quaternion_identity())
{
	// Set the transformation and rotation of the bone (the bone still follow its hiearchy transformation)
	//	If bone is already linked to another bone, transformation will be skewed.
	var player = stack.player;
	var skeleton = player.skeleton;
	var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
	boneInd = bone.index;
	
	var rot;
	if is_array(rotation) {rot=rotation} else {rot = skeleton_get_sample_transform(skeleton, boneInd);}
	
	var struct = {
		blendmode: anim_blendmode.transform_bone,
		boneInd: boneInd,
		x:x, y:y, z:z,
		quaternion: rot,
		func: anim_layer_sample.bone_transform,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	
	return struct;
}
function anim_stack_anchor_IK(stack, boneInd, bindInd, stretch=true, amount=1)
{
	var player = stack.player;
	var skeleton = player.skeleton;
	var bone = check_bone(boneInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(boneInd));return false;}
	boneInd = bone.index;
	var bone = check_bone(bindInd, skeleton); if is_undefined(bone) {log("Bone not found: "+string(bindInd));return false;}
	bindInd = bone.index
	
	// Return false if root bone is connected
	var bone = skeleton.data[boneInd];
	if bone.link==0 return false;
	var link = skeleton.data[bone.link];
	if link.link==0 return false;
		
	var struct = {
		blendmode: anim_blendmode.anchor_IK,
		boneInd: boneInd,
		bindInd: bindInd,
		stretch: stretch,
		func: anim_layer_sample.anchor_IK,
		bones: [link.link, bone.link, boneInd],
		amount: amount,
		stack: stack, push: anim_layer_sample.push, insert: anim_layer_sample.insert, remove: anim_layer_sample.remove
	}
	while(link.link>0)
	{
		link = skeleton.data[link.link];
		array_insert(struct.bones, 0, link.link);
	}
	anim_stack_update_layer(stack);
	return struct;
}

// These function handle layer operation
function anim_push_layer( layer)
{
	var stack = layer.stack
	array_push(stack.layers, layer);
	anim_stack_update_layer(stack);
}
function anim_insert_layer(index, layer)
{
	var stack = layer.stack
	array_insert(stack.layers, index, layer)
	anim_stack_update_layer(stack);
}
function anim_stack_clear_layer(stack)
{
	stack.layers = [];
	anim_stack_update_layer(stack);
}
function anim_stack_delete_layer(layer)
{
	var stack = layer.stack
	var s = array_length(stack.layers)
	for(var i=0; i<s; i++)
	{
		if stack.layers[i] == layer {array_delete(stack.layers, i, 1); return true}
	}
	anim_stack_update_layer(stack);
}
function anim_stack_update_layer(stack)
{
	// When changing layer value, call this function to update stack animation appropriately
	stack.update_layer=true;
}
function anim_layer_set_animation(layer, animation)
{
	var anim;
	if is_struct(animation) anim=animation else anim = animation_reference[? animation];
	if is_undefined(anim) {log("Stack animation failed: could not reference animation: "+string(animation), "error");return undefined}
	layer.animation = anim;
	layer.reference = anim.name;
	anim_stack_update_layer(layer.stack)
}