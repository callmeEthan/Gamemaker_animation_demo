/// Initial model format
// Standard model format
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_texcoord();
vertex_format_add_colour();
global.stdFormat = vertex_format_end();
#macro mBuffStdBytesPerVert 36
	
// Animation model format
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_texcoord();
vertex_format_add_color();	// bone index
vertex_format_add_color();	// bone weight
global.animFormat = vertex_format_end();
#macro mBuffAnimBytesPerVert 40
	
// Sprite model format
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_texcoord();
vertex_format_add_color(); // bone index
vertex_format_add_color(); // bone weight
vertex_format_add_color();	// low precision bone vector
global.animSprFormat = vertex_format_end();
#macro mBuffAnimSprBytesPerVert 44
	
// Voxel model format
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();		// bone index
vertex_format_add_color();		// bone weight
vertex_format_add_color();		// custom attribute
global.animVoxelFormat = vertex_format_end();
#macro mBuffAnimVoxelBytesPerVert 24

/*	/////////////////////////////////////		MODEL FUNCTION		///////////////////////////////////////*/
function load_obj_to_buffer(filename, ds_list=-1) {
	/*
	Loads an .obj model into a buffer
	add ds_list to write model info to
	*/
	var vBuff, n_index, t_index, v_index, file, i, j, str, type, vertString, triNum, temp_faces, modelArray;
	file = file_text_open_read(filename);
	if file == -1{log("Failed to load model " + string(filename)); return -1;}
	log("Script <c_orange>spart_load_obj</>: Loading obj file " + string(filename));
	
	//Model info output
	if !(ds_list<0) {
		var xmin=0, xmax=0, ymin=0, ymax=0, zmin=0, zmax=0;
		}

	//Create the necessary lists
	var vx, vy, vz, nx, ny, nz, tx, ty, fl, v, n, t, f;
	vx = ds_list_create(); vx[| 0] = 0;
	vy = ds_list_create(); vy[| 0] = 0;
	vz = ds_list_create(); vz[| 0] = 0;
	nx = ds_list_create(); nx[| 0] = 0;
	ny = ds_list_create(); ny[| 0] = 0;
	nz = ds_list_create(); nz[| 0] = 0;
	tx = ds_list_create(); tx[| 0] = 0;
	ty = ds_list_create(); ty[| 0] = 0;
	fl = ds_list_create();

	//Read .obj as textfile
	while !file_text_eof(file)
	{
		str = string_replace_all(file_text_read_string(file),"  "," ");
		type = string_copy(str, 1, 2);
		str = string_delete(str, 1, string_pos(" ", str));
		//Different types of information in the .obj starts with different headers
		switch type
		{
			//Load vertex positions
			case "v ":
				ds_list_add(vx, real(string_copy(str, 1, string_pos(" ", str))));
		        str = string_delete(str, 1, string_pos(" ", str));     
				ds_list_add(vy, real(string_copy(str, 1, string_pos(" ", str))));  
				ds_list_add(vz, real(string_delete(str, 1, string_pos(" ", str))));
				break;
			//Load vertex normals
			case "vn":
				ds_list_add(nx, real(string_copy(str, 1, string_pos(" ", str))));
		        str = string_delete(str, 1, string_pos(" ", str)); 
				ds_list_add(ny, real(string_copy(str, 1, string_pos(" ", str))));
				ds_list_add(nz, real(string_delete(str, 1, string_pos(" ", str))));
				break;
			//Load vertex texture coordinates
			case "vt":
				var u = real(string_copy(str, 1, string_pos(" ", str)));
				var v = real(string_delete(str, 1, string_pos(" ", str)))
				ds_list_add(tx, clamp(u,0,1));
				ds_list_add(ty, clamp(v,0,1));
				break;
			//Load faces
			case "f ":
		        if (string_char_at(str, string_length(str)) == " "){str = string_copy(str, 0, string_length(str) - 1);}
		        triNum = string_count(" ", str);
		        for (i = 0; i < triNum; i ++){
		            vertString[i] = string_copy(str, 1, string_pos(" ", str));
		            str = string_delete(str, 1, string_pos(" ", str));}
				vertString[i--] = str;
		        while i--{for (j = 2; j >= 0; j --){
					ds_list_add(fl, vertString[(i + j) * (j > 0)]);}}
				break;
			}
	    file_text_readln(file);
	}
	file_text_close(file);

	//Loop through the loaded information and generate a model
	var vertCol = c_white;
	var bytesPerVert = 3 * 4 + 3 * 4 + 2 * 4 + 4 * 1;
	var size = ds_list_size(fl);
	var mbuff = buffer_create(size * bytesPerVert, buffer_fixed, 1);
	for (var f = 0; f < size; f ++)
	{
		vertString = ds_list_find_value(fl, f);
		v = 0; n = 0; t = 0;
		//If the vertex contains a position, texture coordinate and normal
		if string_count("/", vertString) == 2 and string_count("//", vertString) == 0{
			v = real(string_copy(vertString, 1, string_pos("/", vertString) - 1));
			vertString = string_delete(vertString, 1, string_pos("/", vertString));
			t = real(string_copy(vertString, 1, string_pos("/", vertString) - 1));
			n = real(string_delete(vertString, 1, string_pos("/", vertString)));}
		//If the vertex contains a position and a texture coordinate
		else if string_count("/", vertString) == 1{
			v = real(string_copy(vertString, 1, string_pos("/", vertString) - 1));
			t = real(string_delete(vertString, 1, string_pos("/", vertString)));}
		//If the vertex only contains a position
		else if (string_count("/", vertString) == 0){
			v = real(vertString);}
		//If the vertex contains a position and normal
		else if string_count("//", vertString) == 1{
			vertString = string_replace(vertString, "//", "/");
			v = real(string_copy(vertString, 1, string_pos("/", vertString) - 1));
			n = real(string_delete(vertString, 1, string_pos("/", vertString)));}
		if v < 0{v = -v;}
		if t < 0{t = -t;}
		if n < 0{n = -n;}
			
		//Add the vertex to the model buffer
		var v_x = vx[| v]
		var v_y = vy[| v]
		var v_z = vz[| v]
		buffer_write(mbuff, buffer_f32, v_x);
		buffer_write(mbuff, buffer_f32, vz[| v]);
		buffer_write(mbuff, buffer_f32, vy[| v]);
	
		buffer_write(mbuff, buffer_f32, nx[| n]);
		buffer_write(mbuff, buffer_f32, nz[| n]);
		buffer_write(mbuff, buffer_f32, ny[| n]);
	
		buffer_write(mbuff, buffer_f32, tx[| t]);
		buffer_write(mbuff, buffer_f32, 1-ty[| t]);
	
		buffer_write(mbuff, buffer_u8, 255);
		buffer_write(mbuff, buffer_u8, 255);
		buffer_write(mbuff, buffer_u8, 255);
		buffer_write(mbuff, buffer_u8, 255);
		
		if !(ds_list<0) {
			if v_x > xmax xmax = v_x;
			if v_x < xmin xmin = v_x;
			if v_y > ymax ymax = v_y;
			if v_y < ymin ymin = v_y;
			if v_z > zmax zmax = v_z;
			if v_z < zmin zmin = v_z;
		}
	}
	ds_list_destroy(fl);
	ds_list_destroy(vx);
	ds_list_destroy(vy);
	ds_list_destroy(vz);
	ds_list_destroy(nx);
	ds_list_destroy(ny);
	ds_list_destroy(nz);
	ds_list_destroy(tx);
	ds_list_destroy(ty);
	if !(ds_list<0) {
		ds_list_add(ds_list, xmin)
		ds_list_add(ds_list, xmax)
		ds_list_add(ds_list, ymin)
		ds_list_add(ds_list, ymax)
		ds_list_add(ds_list, zmin)
		ds_list_add(ds_list, zmax)
	}
	log("Script <c_lime>spart_load_obj</>: Successfully loaded obj " + string(filename));
	return mbuff;
}
function anim_create_buffer(size=0)
{
	if size<=0
	{
		return buffer_create(mBuffAnimBytesPerVert, buffer_grow, 1);
	} else {
		return buffer_create(mBuffAnimBytesPerVert*size, buffer_fixed, 1);
	}
}
function anim_buffer_write_vertex(mBuff, vx, vy, vz, u, v, nx, ny, nz, index=-1)
{
	if index>-1 buffer_seek(mBuff, buffer_seek_start, index*mBuffAnimBytesPerVert)
	//Vertex position
	buffer_writes(mBuff, buffer_f32, vx, vy, vz);

	//Vertex normal
	buffer_writes(mBuff, buffer_f32, nx, ny, nz);

	//Vertex UVs
	buffer_writes(mBuff, buffer_f32, u, v);
}
function anim_buffer_write_attribute(mBuff, indices, weight, index=-1) {
	// This function should be use AFTER anim_add_vertex
	if index>-1 buffer_seek(mBuff, buffer_seek_start, index*mBuffAnimBytesPerVert+32);
	buffer_writes(mBuff, buffer_u8, indices[0], indices[1], indices[2], indices[3]);
	buffer_writes(mBuff, buffer_u8, weight[0]*255, weight[1]*255, weight[2]*255, weight[3]*255);
}
function anim_buffer_read_vertex(mbuff, index, output=array_create(8))
{
	//	Read vertex info from a animation buffer
	//	Return array containing vertex info
	buffer_seek(mbuff, buffer_seek_start, index * mBuffAnimBytesPerVert)
	//Vertex position
	var vx = buffer_read(mbuff, buffer_f32)
	var vy = buffer_read(mbuff, buffer_f32)
	var vz = buffer_read(mbuff, buffer_f32)
	
	//Vertex normal
	var nx = buffer_read(mbuff, buffer_f32)
	var ny = buffer_read(mbuff, buffer_f32)
	var nz = buffer_read(mbuff, buffer_f32)
	
	//Vertex UVs
	var u = buffer_read(mbuff, buffer_f32)
	var v = buffer_read(mbuff, buffer_f32)
	
	output[@0]=vx;
	output[@1]=vy;
	output[@2]=vz;
	output[@3]=nx;
	output[@4]=ny;
	output[@5]=nz;
	output[@6]=u;
	output[@7]=v;
}
function anim_buffer_read_attribute(mBuff, index=-1, output = array_create(8)) {
	// This function should be use AFTER anim_add_vertex
	if index>-1 buffer_seek(mBuff, buffer_seek_start, index*mBuffAnimBytesPerVert+32);
	for(var i=0; i<4; i++) output[@i] = buffer_read(mBuff, buffer_u8);
	for(var i=4; i<8; i++) output[@i] = buffer_read(mBuff, buffer_u8)/255;
}
function stdf_buffer_to_anim_buffer(buffer)
{
	var size = buffer_get_size(buffer) / mBuffStdBytesPerVert;
	var mbuff = anim_create_buffer(size);
	var array= array_create(12);
	var indices = array_create(4);
	var weights = array_create(4);
	//weights[@ 0] = 1;
	for(var vi=0; vi<size; vi++)
	{
		mbuff_read_vertex(buffer, vi, array);
		anim_buffer_write_vertex(mbuff, array[0], array[1], array[2], array[6], array[7], array[3], array[4], array[5]);
		anim_buffer_write_attribute(mbuff, indices, weights);
	}
	return mbuff;
}
function anim_create_vbuffer_from_buffer(buffer)
{
	/* This function create a vertex buffer model buffer.
	You can use this to combine multiple model into a single draw batch, (They should have the same texture otherwise it will looks weird)
	Provide multiple model buffers as arguments or list them in an array. Eg:
		anim_create_vbuffer_from_buffer(mbuff);
		anim_create_vbuffer_from_buffer(buff1, buff2, buff3, buffer4);
		anim_create_vbuffer_from_buffer([buff1, buff2, buff3]);			*/
	if is_array(buffer)
	{
		var vbuff = vertex_create_buffer();
		vertex_begin(vbuff, global.animFormat)
		var s = array_length(buffer)
		for(var i=0; i<s; i++)
		{
			var mbuff = buffer[i]
			var size = buffer_get_size(mbuff)/mBuffAnimBytesPerVert;
			buffer_seek(mbuff, buffer_seek_start, 0);
			repeat(size) anim_buffer_write_from_buffer(mbuff, vbuff)
		}
		vertex_end(vbuff); 
		return vbuff;
	} else if argument_count>1 {
		var vbuff = vertex_create_buffer();
		vertex_begin(vbuff, global.animFormat)
		for(var i=0; i<argument_count; i++)
		{
			var mbuff = argument[i]
			var size = buffer_get_size(mbuff)/mBuffAnimBytesPerVert;
			buffer_seek(mbuff, buffer_seek_start, 0);
			repeat(size) anim_buffer_write_from_buffer(mbuff, vbuff)
		}
		vertex_end(vbuff); 
		return vbuff;
	}
	var vbuff = vertex_create_buffer_from_buffer(buffer, global.animFormat)
	return vbuff;
}
function anim_buffer_write_from_buffer(mbuffer, vbuffer, index=-1)
{
	if index>-1 buffer_seek(mbuffer, buffer_seek_start, index*mBuffAnimBytesPerVert+32);
	var vx, vy, vz, nx, ny, nz, u, v, b1, b2, b3, b4
	//Vertex position
	vx = buffer_read(mbuffer, buffer_f32);
	vy = buffer_read(mbuffer, buffer_f32);
	vz = buffer_read(mbuffer, buffer_f32);
	vertex_position_3d(vbuffer, vx, vy, vz);
	//Vertex normal
	nx = buffer_read(mbuffer, buffer_f32);
	ny = buffer_read(mbuffer, buffer_f32);
	nz = buffer_read(mbuffer, buffer_f32);
	vertex_normal(vbuffer, nx, ny, nz);
	//Vertex UVs
	u = buffer_read(mbuffer, buffer_f32);
	v = buffer_read(mbuffer, buffer_f32);
	vertex_texcoord(vbuffer, u, v);
	//Bone & Weight
	repeat(2)
	{
		b1 = buffer_read(mbuffer, buffer_u8);
		b2 = buffer_read(mbuffer, buffer_u8);
		b3 = buffer_read(mbuffer, buffer_u8);
		b4 = buffer_read(mbuffer, buffer_u8);
		vertex_color(vbuffer, make_color_rgb(b1, b2, b3), round(b4*255))
	}
}
function rebuild_anim_buffer_indice(mbuff, data)
{
	// Use by editor, rebind model indice to match with skeleton after deleting a bone.
	var size = buffer_get_size(mbuff)/mBuffAnimBytesPerVert;
	var s = ds_list_size(data)
	for(var v=0; v<size; v++)
	{
		var b = v*mBuffAnimBytesPerVert+32;
		for(var i=0; i<4; i++)
		{
			var ind = buffer_peek(mbuff, b+i, buffer_u8);
			if ind<s
			{
				var bone = data[| ind];
				ind = bone.index;
			} else {
				ind = 0;
			}
			buffer_poke(mbuff, b+i, buffer_u8, ind);
		}
	}
}
function anim_transform_model_buffer(mbuffer, matrix)
{
	var size = buffer_get_size(mbuffer) / mBuffAnimBytesPerVert;
	var vert = array_create(8);
	var pos, normal;
	for(var vi=0; vi<size; vi++)
	{
		anim_buffer_read_vertex(mbuffer, vi, vert);
		buffer_seek(mbuffer, buffer_seek_start, vi*mBuffAnimBytesPerVert)
		pos = matrix_transform_vertex(matrix, vert[0], vert[1], vert[2], 1)
		normal = matrix_transform_vertex(matrix, vert[3], vert[4], vert[5], 0)
		anim_buffer_write_vertex(mbuffer, pos[0], pos[1], pos[2], vert[6], vert[7], normal[0], normal[1], normal[2]);
	}
	return mbuffer;
}
function anim_buffer_transform_anim_vertex(mbuff, index, transform)
{
	// Transform a vertex using animation transform. (This directly edit model data, not for animation)
	static vertice = array_create(8);
	static anim = array_create(8);
	anim_buffer_read_vertex(mbuff, index, vertice);
	anim_buffer_read_attribute(mbuff, index, anim);
	
	static blendreal = array_create(4);
	static blenddual = array_create(4);
	static cross = array_create(3);
	static translate = array_create(3);
	static normal = array_create(3);
	
	// Get animation
	var sum = 0;
	for(var i=0; i<4; i++) {blendreal[@i]=0; blenddual[@i]=0;}
	normal[@0]=vertice[3]; normal[@1]=vertice[4]; normal[@2]=vertice[5];
	for(var i=0; i<4; i++)
	{
		var bone = anim[i];
		var weight = anim[i+4];
		if weight==0 continue;
		sum+=weight;
		var b = bone*8;
		blendreal[@0]+=buffer_peek(transform, 4*(b+0), buffer_f32)*weight;
		blendreal[@1]+=buffer_peek(transform, 4*(b+1), buffer_f32)*weight;
		blendreal[@2]+=buffer_peek(transform, 4*(b+2), buffer_f32)*weight;
		blendreal[@3]+=buffer_peek(transform, 4*(b+3), buffer_f32)*weight;
		
		blenddual[@0]+=buffer_peek(transform, 4*(b+4), buffer_f32)*weight;
		blenddual[@1]+=buffer_peek(transform, 4*(b+5), buffer_f32)*weight;
		blenddual[@2]+=buffer_peek(transform, 4*(b+6), buffer_f32)*weight;
		blenddual[@3]+=buffer_peek(transform, 4*(b+7), buffer_f32)*weight;
	}
	if sum==0 return false;
	
	// Calculate dual quaternion
	var norm = 1/magnitude(blendreal);
	var dot = dot_product_array(blendreal, blenddual);
	for(var i=0;i<4;i++)
	{
		blendreal[@i]*=norm;
		blenddual[@i] = (blenddual[i] - blendreal[i]*dot)*norm;
	}
	cross_product(blendreal, blenddual, cross);
	for(var i=0; i<3; i++) 
	{
		translate[@i] = 2 * (blendreal[3]*blenddual[i] - blenddual[3]*blendreal[i] + cross[i]);
	}
	
	// Rotate transform
	cross_product(blendreal, vertice, cross);
	for(var i=0; i<3; i++) {cross[@i] += blendreal[3]*vertice[i]};
	cross_product(blendreal, cross, cross);
	for(var i=0; i<3; i++) {vertice[@i] += (2*cross[i]) + translate[i]};
	
	// Rotate normal
	cross_product(blendreal, normal, cross);
	for(var i=0; i<3; i++) {cross[@i] += blendreal[3]*normal[i]};
	cross_product(blendreal, cross, cross);
	for(var i=0; i<3; i++) {normal[@i] += 2*cross[i]};
	
	anim_buffer_write_vertex(mbuff, vertice[0],vertice[1],vertice[2], vertice[6],vertice[7], normal[0],normal[1],normal[2], index)
	return true;
}
function anim_buffer_transform_anim(mbuffer, transform)
{
	// Apply animation transform to a model buffer. (This directly edit model data, not for animation)
	var size = buffer_get_size(mbuffer) / mBuffAnimBytesPerVert;
	for(var vi=0; vi<size; vi++) anim_buffer_transform_anim_vertex(mbuffer, vi, transform)
	return mbuffer;
}

// Skeleton model handling (Full-skeleton model with vertex transform)
// Model file (.eatbuff) are basically just buffer, you can load them with buffer_load(), and use anim_create_vbuffer_from_buffer() to convert them to vertex-buffer;
//	Use skeleton_model_add_mbuffer() to add them directly to skeleton, and render them using skeleton_model_render()
function skeleton_model_add_mbuffer(skeleton, mbuff, texture=-1)
{
	// Add a model mbuffer to skeleton, the model provided must have animation model format, see vertex_format_init();
	if skeleton.model_data==-1 skeleton.model_data={mbuffer: [], texture: [], vbuffer: [], vtexture: []}
	var dat = skeleton.model_data;
	array_push(dat.mbuffer, mbuff);
	array_push(dat.texture, texture);
	skeleton_model_handle_vbuffer(skeleton, texture);
}
function skeleton_model_remove_mbuffer(skeleton, mbuff)
{
	// Delete a model mbuffer from data list
	// This function does not destroy model buffer, only remove it from the list and clean up vertex buffer
	// You should delete model buffer if neccessary.
	var dat = skeleton.model_data
	if dat==-1 return false;
	var s = array_length(dat.mbuffer);
	var ind = -1;
	for(var i=0;i<s;i++)
	{
		if dat.mbuffer[i]==mbuff {ind=i; break}
	}
	if ind<0 return false;
	var texture = dat.texture[ind]
	array_delete(dat.mbuffer, ind, 1);
	array_delete(dat.texture, ind, 1);
	skeleton_model_handle_vbuffer(skeleton, texture);
}
function skeleton_model_set_texture(skeleton, mbuff, texture)
{
	// Assign texture to model buffer added to skeleton
	var dat = skeleton.model_data
	if dat==-1 return false;
	var s = array_length(dat.mbuffer);
	var ind = -1;
	for(var i=0;i<s;i++)
	{
		if dat.mbuffer[i]==mbuff {ind=i; break}
	}
	if ind<0 return false;
	var tex1 = dat.texture[ind];
	if tex1 = texture return false;
	dat.texture[@ind]=texture;
	skeleton_model_handle_vbuffer(skeleton, tex1);
	skeleton_model_handle_vbuffer(skeleton, texture);
}
function skeleton_model_handle_vbuffer(skeleton, texture)
{
	// This function handle vertex buffer (automatically executed if you use above function)
	// It combines model buffers that share the same texture into a single draw call.
	var data = skeleton.model_data
	if data=-1 return false;
	// Remove old vbuffer.
	var s = array_length(data.vtexture)
	for(var i=0; i<s; i++)
	{
		if data.vtexture==texture
		{
			vertex_delete_buffer(data.vbuffer[i]);
			array_delete(data.vbuffer, i, 1);
			array_delete(data.vtexture, i, 1);
			break
		}
	}
	// Update new vbuffer; if no mbuffer is found, returns undefined.
	var buff = [];
	s = array_length(data.texture);
	for(var i=0; i<s; i++)
	{
		if data.texture[i]==texture array_push(buff, data.mbuffer[i]);
	}
	if array_length(buff)==0 return undefined;
	var vbuff = anim_create_vbuffer_from_buffer(buff)
	vertex_freeze(vbuff);
	array_push(data.vbuffer, vbuff);
	array_push(data.vtexture, texture);
	return vbuff
}
function skeleton_model_render(skeleton)
{
	// Render skeleton buffer, to apply animation transform, use skeleton_set_uniform(skeleton);
	var data = skeleton.model_data;
	if data=-1 return false;
	var s = array_length(data.vbuffer);
	for(var i=0; i<s; i++)
	{
		vertex_submit(data.vbuffer[i], pr_trianglelist, data.vtexture[i])
	}
}

// Bone model handling (Simple bone-attached model)
function bone_model_add_mbuffer(skeleton, boneInd, mbuff, texture, matrix=matrix_build_identity())
{
	// Add a model mbuffer to skeleton bone;
	// The provided model must have standard model format, see vertex_format_init(), it will automatically be converted to animation format;
	if skeleton.bone_model==-1 skeleton.bone_model={data:[], vbuffer:[], vtexture:[]}
	var dat = skeleton.bone_model;
	
	if is_undefined(texture) texture=-1;
	var bone = skeleton.data[boneInd];
	matrix = matrix_multiply(matrix_build(bone.Ox, bone.Oy, bone.Oz, 0,0,0,1,1,1), matrix);
	array_push(dat.data, {mbuffer: mbuff, boneInd: boneInd, texture: texture, matrix: matrix});
	var vbuff = bone_model_handle_vbuffer(skeleton, texture);
	return vbuff;
}
function bone_model_handle_vbuffer(skeleton, texture)
{
	// This function handle bone vertex buffer (automatically executed if you use above function)
	// It combines model buffers that share the same texture into a single draw call.
	var data = skeleton.bone_model;
	if data==-1 return false;
	// Remove old vbuffer.
	var s = array_length(data.vtexture);
	for(var i=0; i<s; i++)
	{
		if data.vtexture==texture
		{
			vertex_delete_buffer(data.vbuffer[i]);
			array_delete(data.vbuffer, i, 1);
			array_delete(data.vtexture, i, 1);
		}
	}
	
	// Update new vbuffer; if no mbuffer is found, returns undefined.
	var count=0;
	var s = array_length(data.data);
	var mbuff, matrix, size, pos;
	var vbuff = vertex_create_buffer();
	vertex_begin(vbuff, global.animFormat)
	for(var i=0; i<s; i++)
	{
		var entry = data.data[i];
		if entry.texture != texture continue;
		mbuff = entry.mbuffer;
		matrix = entry.matrix;
		
		buffer_seek(mbuff, buffer_seek_start, 0);
		size = buffer_get_size(mbuffer) / mBuffStdBytesPerVert;
		var vx, vy, vz, nx, ny, nz, u, v;
		repeat(size)
		{
			//Vertex position
			vx = buffer_read(mbuff, buffer_f32);
			vy = buffer_read(mbuff, buffer_f32);
			vz = buffer_read(mbuff, buffer_f32);
			pos = matrix_transform_vertex(matrix, vx, vy, vz, 1)
			vertex_position_3d(vbuff, pos[0], pos[1], pos[2]);
			//Vertex normal
			nx = buffer_read(mbuff, buffer_f32);
			ny = buffer_read(mbuff, buffer_f32);
			nz = buffer_read(mbuff, buffer_f32);
			pos = matrix_transform_vertex(matrix, nx, ny, nz, 0)
			vertex_normal(vbuff, pos[0], pos[1], pos[2]);
			//Vertex UVs
			u = buffer_read(mbuff, buffer_f32);
			v = buffer_read(mbuff, buffer_f32);
			vertex_texcoord(vbuff, u, v);
			//Color (unused)
			repeat(4) buffer_read(mbuff, buffer_u8);
			//Bone index & weight
			vertex_color(vbuff, make_color_rgb(entry.boneInd, 0, 0), 0)
			vertex_color(vbuff, make_color_rgb(1, 0, 0), 0)
		}
		count++;
	}
	vertex_end(vbuff);
	vertex_freeze(vbuff);
	if count==0 {vertex_delete_buffer(vbuff); return undefined}
	array_push(data.vbuffer, vbuff);
	array_push(data.vtexture, texture)
	return vbuff;
}
function bone_model_set_texture(skeleton, mbuff, texture)
{
	// Assign texture to model buffer added to bone
	var dat = skeleton.bone_model
	if dat==-1 return false;
	var s = array_length(dat.data);
	var ind = -1;
	for(var i=0;i<s;i++)
	{
		var entry = dat.data[i]
		if entry.mbuffer==mbuff {ind=i; break}
	}
	if ind<0 return false;
	var tex1 = entry.texture[ind];
	if tex1 = texture return false;
	entry.texture=texture;
	skeleton_model_handle_vbuffer(skeleton, tex1);
	skeleton_model_handle_vbuffer(skeleton, texture);
}
function bone_model_remove_mbuffer(skeleton, mbuff)
{
	// Delete a model mbuffer from data list;
	// This function does not destroy model buffer, only remove it from the list and clean up vertex buffer;
	// You should delete model buffer if neccessary.
	var dat = skeleton.bone_model;
	if dat==-1 return false;
	var s = array_length(dat.data);
	var ind = -1;
	for(var i=0;i<s;i++)
	{
		var entry = dat.data[i]
		if entry.mbuffer==mbuff {ind=i; break}
	}
	if ind<0 return false;	
	var texture = entry.texture;
	array_delete(dat.data, ind, 1);
	bone_model_handle_vbuffer(skeleton, texture);
}
function bone_model_render(skeleton)
{
	// Render bone buffer, to apply animation transform, use skeleton_set_uniform(skeleton);
	var data = skeleton.bone_model;
	if data=-1 return false;
	var s = array_length(data.vbuffer);
	for(var i=0; i<s; i++)
	{
		vertex_submit(data.vbuffer[i], pr_trianglelist, data.texture[i])
	}
}

/*	/////////////////////////////////////		SKELETON SPRITE RENDER		///////////////////////////////////////
	These functions handle sprite renderer for skeleton rig.
	skeleton_sprite_write() and skeleton_sprite_read() are mostly used by editor, they simply return json-string to write to file.*/
function skeleton_sprite(skeleton) constructor
{
	data = [];
	texture = [];
	resource = ds_map_create();	// resource[? texture] = index
	vbuffer = [];
	mbuffer = [];
	reference = ds_map_create();
	size = 0;
	self.skeleton = skeleton;
	skeleton.sprite_data = self;
	struct_format =
	{
		vindex:-1, vsize:0, bone:0, type:0, name: "",
		texture:-1, UV:[0,0,0,0], texcoord:[0,0,0,0],center:[0,0,0],width:1, height:1, gridw:1, gridh:1,
		scale:1., billboard:0., x:0, y:0, z:0,  angle: 0,
		lookat: -1, symmetric:1, uvs: [0,0,0,0], state:0, halign: 0
	};
	
	// Game function usage, you only need to care about these
	static destroy = function()
	{
		if resource!=-1 ds_map_destroy(resource)
		if reference!=-1 ds_map_destroy(reference)
		var s
		s = array_length(vbuffer);		for(var i=0; i<s; i++) vertex_delete_buffer(vbuffer[i]);
		s = array_length(mbuffer);		for(var i=0; i<s; i++) buffer_delete(mbuffer[i]);
		
		resource=-1;	vbuffer=[]
		reference=-1;	reference=[]
	}
	static add_sprite = function(boneInd, sprite, subimg, texcoord, centerx, centery, num=1, name=undefined)
	{
		/*
		Simply add a sprite to skeleton render.
		boneInd, sprite, subimg should be self-explainatory.
		texcoord: area of the sprite to render in pixel space, must be an array in the follow format [x1,y1,x2,y2] (top left and bottom right).
		centerx, centery: center of the sprite in pixel space, must be an array in the follow format [x,y]
		num: use if this is a sprite-strip containing multiple angle of the object, default: 1
		name (optional): this is for reference if you want to edit it afterward. For example: delete_sprite(get_reference("neck"));
		*/
		var tex = sprite_get_texture(sprite, subimg)
		var texture_ind = resource[? tex];
		if is_undefined(texture_ind) {texture_ind=ds_map_size(resource); resource[? tex]=texture_ind; array_push(texture, tex)}
		var w = texcoord[2]-texcoord[0];
		var h = texcoord[3]-texcoord[1];
		var UV = sprite_get_tile_uv(sprite, subimg, texcoord[0], texcoord[1], texcoord[2]-texcoord[0], texcoord[3]-texcoord[1])
		var bone = skeleton.data[boneInd];
		centerx = InvLerp(texcoord[0], texcoord[2], centerx);
		centery = InvLerp(texcoord[1], texcoord[3], centery);
		var out;
		out = variable_clone(struct_format);
		out.bone = boneInd;
		out.texture = texture_ind;
		out.UV = UV;
		out.texcoord = texcoord;
		out.center = [centerx, centery, centerx];
		out.width = w; out.height = h;
		out.gridw = num;
		out.uvs = variable_clone(UV);
		out.state = 0;
		out.name = bone.name;
		
		var vec = [bone.Ax, bone.Ay, bone.Az];
		if is_nan(bone.Ax) 	{var a = skeleton.data[bone.Ay];	vec = [a.Ox-bone.Ox, a.Oy-bone.Oy, a.Oz-bone.Oz]}
		var up = [0,0,0];
		if vec[1]==0 up[1]=-1 else up[0]=1;
		out.lookat = matrix_build_lookat(vec[0], vec[1], vec[2], 0,0,0, up[0], up[1], up[2]);
		
		struct_inherit(out, struct_format)
		array_push(data, out);
		size = array_length(data);
		if !is_undefined(name) reference[? name] = out;
		log("Sprite added: "+string(out))
		build_vbuffer();
		return out;
	};
	static delete_sprite = function(struct)
	{
		if is_string(struct)
		{
			var str = reference[? struct]
			if is_undefined(struct) {log("Sprite reference not found, name is incorrect or data reference is not defined: "+struct);return false;}
			struct = str
		}
		var s = array_length(data);
		for(var i=0; i<s; i++)
		{
			if data[i]==struct
			{
				array_delete(data,i,1);
				size = array_length(data);
				build_vbuffer();
				delete struct;
				return true
			}
		}
		return false;
	}
	static get_reference = function(name)
	{
		return reference[? name];
	}
	static bind_texture_sprite = function(index, sprite, subimg)
	{
		// swap a different sprite texture, it will also iterate through all bone configurations and correct UV positions.
		var tex = sprite_get_texture(sprite, subimg);
		texture[@ index] = tex;
		for(var i=0; i<size; i++)
		{
			var spr = data[i];
			if spr.texture != index continue;
			var texcoord = spr.texcoord;
			var UV = sprite_get_tile_uv(sprite, subimg, texcoord[0], texcoord[1], texcoord[2]-texcoord[0], texcoord[3]-texcoord[1]);
			spr.UV = UV;
			spr.uvs = variable_clone(UV);
			update_vbuffer(spr);
		}
		resource[? tex] = index;
	}

	// System function, if you want to tinker around
	static update_mbuffer = function(struct)
	{
		// write model buffer data, does not update vertex-buffer
		var dat = struct;
		var boneInd = dat.bone;
		var bone = skeleton.data[boneInd], link, glink;
		if bone.index<=0 {link=bone; glink=bone} else
		{
			if bone.link<0 link=bone else link = skeleton.data[bone.link];
			if link.link<0 glink=link else glink = skeleton.data[link.link];
		}
		
		var type = dat.type;
		var tex_index = dat.texture;
		var mbuff = mbuffer[tex_index];
		if mbuff<0
		{
			mbuff = buffer_create(1, buffer_grow, 1);
			mbuffer[tex_index] = mbuff;
		}
		var bpos = buffer_tell(mbuff)
		if dat.vindex==-1 dat.vindex = bpos;
		buffer_seek(mbuff, buffer_seek_start, dat.vindex);
		
		var uv, center, w, h, xx, yy ,zz, Vx, Vy, Vz;
		var bottom = {x: 0, y: 0, z: 0, uvy: 0, ny: 0, bone: 0, len:0}
		var top = {x: 0, y: 0, z: 0, uvy: 0, ny: 0, bone: 0, len:0}
		switch(type)
		{
			case 0:
				uv = dat.uvs;
				w = dat.width*dat.scale; h = dat.height*dat.scale;
				center = [dat.center[2]*w, dat.center[1]*h];
				var vec = [bone.Ax, bone.Ay, bone.Az];
				if is_nan(bone.Ax) 	{var a = skeleton.data[bone.Ay];	vec = [a.Ox-bone.Ox, a.Oy-bone.Oy, a.Oz-bone.Oz]}
				var len = point_distance_3d(0,0,0,vec[0], vec[1], vec[2]);
				normalize(vec);
				Vx = (vec[0]*.5+.5)*255;
				Vy = (vec[1]*.5+.5)*255;
				Vz = (vec[2]*.5+.5)*255;
				xx = bone.Ox + dat.x - vec[0]*(center[1]-h);
				yy = bone.Oy + dat.y - vec[1]*(center[1]-h);
				zz = bone.Oz + dat.z - vec[2]*(center[1]-h);
				bottom.ny = 0;
				bottom.x = xx; bottom.y = yy; bottom.z = zz; bottom.len = 1;
				top.len = 1;
				top.ny = lerp(0, -h, dat.billboard)
				top.x = lerp(xx, xx - vec[0]*h, 1-dat.billboard)
				top.y = lerp(yy, yy - vec[1]*h, 1-dat.billboard)
				top.z = lerp(zz, zz - vec[2]*h, 1-dat.billboard)
				
				if dat.halign {bottom.ny=top.ny*-1; top.ny=0}
					
				buffer_writes(mbuff, buffer_f32, bottom.x, bottom.y, bottom.z);
				buffer_writes(mbuff, buffer_f32, -center[0], bottom.ny, len);
				buffer_writes(mbuff, buffer_f32, uv[0], uv[3]);
				buffer_writes(mbuff, buffer_u8, bone.index,0,0, 0);
				buffer_writes(mbuff, buffer_u8, 255,0,0, 0);
				buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, bottom.len);
					
				buffer_writes(mbuff, buffer_f32, bottom.x, bottom.y, bottom.z);
				buffer_writes(mbuff, buffer_f32, -center[0]+w,bottom.ny, len);
				buffer_writes(mbuff, buffer_f32, uv[2], uv[3]);
				buffer_writes(mbuff, buffer_u8, bone.index,0,0, 0);
				buffer_writes(mbuff, buffer_u8, 255,0,0, 0);
				buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, bottom.len);
					
				buffer_writes(mbuff, buffer_f32, top.x, top.y, top.z);
				buffer_writes(mbuff, buffer_f32, -center[0]+w,top.ny,len);
				buffer_writes(mbuff, buffer_f32, uv[2], uv[1]);
				buffer_writes(mbuff, buffer_u8, bone.index,0,0, 0);
				buffer_writes(mbuff, buffer_u8, 255,0,0, 0);
				buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, top.len);
					
				buffer_writes(mbuff, buffer_f32, top.x, top.y, top.z);
				buffer_writes(mbuff, buffer_f32, -center[0]+w,top.ny,len);
				buffer_writes(mbuff, buffer_f32, uv[2], uv[1]);
				buffer_writes(mbuff, buffer_u8, bone.index,0,0, 0);
				buffer_writes(mbuff, buffer_u8, 255,0,0, 0);
				buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, top.len);
					
				buffer_writes(mbuff, buffer_f32, top.x, top.y, top.z);
				buffer_writes(mbuff, buffer_f32, -center[0],top.ny,len);
				buffer_writes(mbuff, buffer_f32, uv[0], uv[1]);
				buffer_writes(mbuff, buffer_u8, bone.index,0,0, 0);
				buffer_writes(mbuff, buffer_u8, 255,0,0, 0);
				buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, top.len);
					
				buffer_writes(mbuff, buffer_f32, bottom.x, bottom.y, bottom.z);
				buffer_writes(mbuff, buffer_f32, -center[0], bottom.ny,len);
				buffer_writes(mbuff, buffer_f32, uv[0], uv[3]);
				buffer_writes(mbuff, buffer_u8, bone.index,0,0, 0);
				buffer_writes(mbuff, buffer_u8, 255,0,0, 0);
				buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, bottom.len);
				break
				
			case 1:
				var quad = 10; // number of quad
				var step = 0;
				uv = dat.uvs;
				w = dat.width*dat.scale; h = dat.height*dat.scale;
				center = [dat.center[2]*w, dat.center[1]*h];
				var vec = [bone.Ax, bone.Ay, bone.Az];
				if is_nan(bone.Ax) 	{var a = skeleton.data[bone.Ay];	vec = [a.Ox-bone.Ox, a.Oy-bone.Oy, a.Oz-bone.Oz]}
				var len = point_distance_3d(0,0,0,vec[0], vec[1], vec[2])
				normalize(vec);
				var Vx = (vec[0]*.5+.5)*255;
				var Vy = (vec[1]*.5+.5)*255;
				var Vz = (vec[2]*.5+.5)*255;
				xx = bone.Ox + dat.x - vec[0]*(center[1]-h)
				yy = bone.Oy + dat.y - vec[1]*(center[1]-h)
				zz = bone.Oz + dat.z - vec[2]*(center[1]-h)
				top.x=xx;	top.y=yy; top.z=zz
				top.uvy=uv[3]; top.ny=0; top.bone=0; top.ind=0
				
				var slen = (1/quad)*255;
				for(var t=0; t<quad; t++)
				{
					step = (t+1)/quad
					bottom.x = top.x; bottom.y = top.y; bottom.z = top.z
					bottom.uvy = top.uvy;
					bottom.ny = top.ny;
					bottom.bone = top.bone;
						
					top.x = xx - vec[0]*h*step; //lerp(xx, xx-vec[0]*h, step)
					top.y = yy - vec[1]*h*step;//lerp(yy, yy-vec[1]*h, step)
					top.z = zz - vec[2]*h*step; //lerp(zz, zz-vec[2]*h, step)
					top.uvy =  lerp(uv[3], uv[1], step);
					top.ny = 0;
					top.bone = clamp((step*h)/(len*2), 0, 1) * 255;
						
					buffer_writes(mbuff, buffer_f32, bottom.x, bottom.y, bottom.z);
					buffer_writes(mbuff, buffer_f32, -center[0],bottom.ny, len);
					buffer_writes(mbuff, buffer_f32, uv[0], bottom.uvy);
					buffer_writes(mbuff, buffer_u8, bone.index,link.index,0, 0);
					buffer_writes(mbuff, buffer_u8, 255-bottom.bone,bottom.bone,0, 0);
					buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, slen);
					
					buffer_writes(mbuff, buffer_f32, bottom.x, bottom.y, bottom.z);
					buffer_writes(mbuff, buffer_f32, -center[0]+w,bottom.ny, len);
					buffer_writes(mbuff, buffer_f32, uv[2], bottom.uvy);
					buffer_writes(mbuff, buffer_u8, bone.index,link.index,0, 0);
					buffer_writes(mbuff, buffer_u8, 255-bottom.bone,bottom.bone,0, 0);
					buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, slen);
					
					buffer_writes(mbuff, buffer_f32, top.x, top.y, top.z);
					buffer_writes(mbuff, buffer_f32, -center[0]+w,top.ny,len);
					buffer_writes(mbuff, buffer_f32, uv[2], top.uvy);
					buffer_writes(mbuff, buffer_u8, bone.index,link.index,0, 0);
					buffer_writes(mbuff, buffer_u8, 255-top.bone,top.bone,0, 0);
					buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, slen);
					
					buffer_writes(mbuff, buffer_f32, top.x, top.y, top.z);
					buffer_writes(mbuff, buffer_f32, -center[0]+w,top.ny,len);
					buffer_writes(mbuff, buffer_f32, uv[2], top.uvy);
					buffer_writes(mbuff, buffer_u8, bone.index,link.index,0, 0);
					buffer_writes(mbuff, buffer_u8, 255-top.bone,top.bone,0, 0);
					buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, slen);
					
					buffer_writes(mbuff, buffer_f32, top.x, top.y, top.z);
					buffer_writes(mbuff, buffer_f32, -center[0],top.ny,len);
					buffer_writes(mbuff, buffer_f32, uv[0], top.uvy);
					buffer_writes(mbuff, buffer_u8, bone.index,link.index,0, 0);
					buffer_writes(mbuff, buffer_u8, 255-top.bone,top.bone,0, 0);
					buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, slen);
					
					buffer_writes(mbuff, buffer_f32, bottom.x, bottom.y, bottom.z);
					buffer_writes(mbuff, buffer_f32, -center[0],bottom.ny,len);
					buffer_writes(mbuff, buffer_f32, uv[0], bottom.uvy);
					buffer_writes(mbuff, buffer_u8, bone.index,link.index,0, 0);
					buffer_writes(mbuff, buffer_u8, 255-bottom.bone,bottom.bone,0, 0);
					buffer_writes(mbuff, buffer_u8, Vx,Vy,Vz, slen);
				}
				break;
			}
		struct.vsize = buffer_tell(mbuff) - struct.vindex
		bpos = max(bpos, buffer_tell(mbuff));
		buffer_seek(mbuff, buffer_seek_start, bpos);
	}
	static clear_cache = function()
	{
		// flush buffer and vertex buffer data, sprite data are untouched
		var count = array_length(vbuffer)
		for(var i=0; i<count; i++) {vertex_delete_buffer(vbuffer[i])}
		var count = array_length(mbuffer)
		for(var i=0; i<count; i++) {buffer_delete(mbuffer[i])}
		// check for unused texture and remove it from reference
		count = array_length(texture);
		var check = array_create(count, false);
		for(var i=0; i<size; i++)
		{
			var spr = data[i];
			check[@ spr.texture] = true;
		}
		for(var i=count-1; i>=0; i--)
		{
			// remove unused texture
			if check[i]==false
			{
				array_delete(texture, i, 1)
				var k = ds_map_find_first(resource);
				var s = ds_map_size(resource);
				for(var j=0; j<s; j++)
				{
					if resource[? k]==i {ds_map_delete(resource,k);break}
					k = ds_map_find_next(resource, k)
				}
			}
		}
		count = array_length(texture);
		vbuffer = array_create(count, -1);
		mbuffer = array_create(count, -1);
	}
	static render = function()
	{
		static sh_invWorld = shader_get_uniform(AnimationSpriteShader, "u_invWorld");
		shader_set_uniform_f_array(sh_invWorld, skeleton.matrix_inv);
		
		var quat = array_create(8);
		var vec = array_create(3);
		var pos;
		var mat = matrix_get(matrix_view);
		var view = [mat[2], mat[6], mat[10]];
		view = matrix_transform_vertex(skeleton.matrix_inv, view[0], view[1], view[2], 0)
		
		var state = 1;
		for(var i=0; i<size; i++)
		{
			// Calculate view angle from camera to sprite position
			var spr = data[i];
			var l = skeleton.data[spr.bone].link; if l<0 l=spr.bone
			skeleton_get_sample_transform(skeleton, l, quat);
			quaternion_conjugate(quat)
			quaternion_transform_vector(quat, view[0], view[1], view[2], vec);
			pos = matrix_transform_vertex(spr.lookat, vec[0], vec[1], vec[2]);
			var a = 360-point_direction(pos[0],pos[1],0,0)+spr.angle;
			if a>360 a-=360 else if a<0 a+=360; // degree value should range from 0 to 360.
			var f = 1;
			var r = 360;
			var n = 0;
			if spr.symmetric
			{
				r = 180;
				if a>180 {f=-1;  a=360-a; spr.center[2]=0.5-(spr.center[0]-0.5)} else {spr.center[2]=spr.center[0]};
			}
			state = max(1, ceil((a/r)*spr.gridw));
			//debug_overlay("sprite_angle: "+string(a)+", num: "+string(state)+"/"+string(spr.gridw)+", state: "+string(state*f), i+4)
			//debug_overlay("pos: "+string(pos)+", view: "+string(view), i+5)
			if spr.state = state*f continue; // only update when necessary instead of every step.
			spr.uvs[@0] = spr.UV[0] + abs(spr.UV[2]-spr.UV[0])*(f? state-1 : state);
			spr.uvs[@1] = spr.UV[1];
			spr.uvs[@2] = spr.UV[0] + abs(spr.UV[2]-spr.UV[0])*(f? state : state-1);
			spr.uvs[@3] = spr.UV[3];
			spr.state = state*f;
			update_mbuffer(spr);
			update_vbuffer(spr);
			//debug_overlay("update sprite: "+string(get_timer()), 3);
		}
		var s = array_length(vbuffer);
		for(var i=0;  i<s; i++)
		{
			vertex_submit(vbuffer[i], pr_trianglelist, texture[i])
		}
	}
	static build_vbuffer = function()
	{
		// clear vertex-buffer and create new one, use when add/remove or modifying sprite type.
		clear_cache();
		var s = array_length(data);
		if s == 0 return false;
		for(var i=0; i<s; i++){data[i].vindex=-1; update_mbuffer(data[i])}
		
		var s = array_length(mbuffer)
		for(var i=0; i<s; i++)
		{
			var mBuff = mbuffer[i]
			if mbuffer[i]!=-1
			{
				buffer_resize(mBuff, buffer_tell(mBuff)) // trim buffer
				vbuffer[@i]=vertex_create_buffer_from_buffer(mBuff, global.animSprFormat);
			}
		}
	}
	static update_vbuffer = function(struct)
	{ 
		// update only specific sprite, without creating new vertex-buffer
		if is_string(struct)
		{
			var str = reference[? struct];
			if is_undefined(struct) {log("Sprite reference not found, name is incorrect or data reference is not defined: "+struct);return false;}
			struct = str;
		}
		if struct.vindex=-1 {build_vbuffer(); return}
		update_mbuffer(struct);
		var tex_index = struct.texture;
		vertex_update_buffer_from_buffer(vbuffer[tex_index], struct.vindex, mbuffer[tex_index], struct.vindex, struct.vsize)
	}
}
function skeleton_sprite_write(struct)
{
	return json_stringify(struct.data)
}
function skeleton_sprite_read(str, skeleton, struct)
{
///@func skeleton_sprite_read(string, skeleton, [struct])
	var data = json_parse(str);
	var tex = 1;
	var s = array_length(data);
	for(var i=0; i<s; i++)
	{
		var spr = data[i];
		tex = max(tex, spr.texture+1);
		
		// Reference skeleton name
		var b = spr.bone;
		var n = "";
		if array_length(skeleton.data)>b {n=skeleton.data[b].name}
		var name = spr[$ "name"];
		if is_undefined(name) || name=="" {spr.name = n; continue}
		var ind = skeleton.reference[? name];
		if is_undefined(ind) {spr.name = n; continue};
		spr.bone = ind;
	}
	if !is_struct(struct)
	{
		struct = new skeleton_sprite(skeleton);
		struct.texture = array_create(tex, -1);
	} else {
		var len = array_length(struct.texture);
		for(var i=len; i<tex; i++) array_push(struct.texture, -1);
	}
	log("skeleton sprite skin loaded with "+string(array_length(struct.texture))+" texture slot")
	struct.data = data;
	struct.size = array_length(data);
	struct.build_vbuffer();
	return struct;
}
function skeleton_sprite_load(skeleton, file)
{
	var f = file_text_open_read(file);
	var str = file_text_read_string(f);
	file_text_close(f);
	skeleton_sprite_read(str, skeleton, skeleton.sprite_data);
}
function anim_sprite_draw_start()
{
	static Aspect = shader_get_uniform(AnimationSpriteShader, "u_ratio");
	
	var sh = AnimationSpriteShader;
	gpu_push_state()
	var pM = matrix_get(matrix_projection);
	var aspect = pM[5] / pM[0];
	gpu_set_cullmode(cull_noculling);
	shader_set(sh)
	shader_set_uniform_f(Aspect, aspect);
}
function anim_sprite_draw_end()
{
	shader_reset();
	gpu_pop_state();
}

/*	/////////////////////////////////////		SKELETON VOXEL RENDER		///////////////////////////////////////
	These functions handle voxel renderer for skeleton rig.
	While it share some similarity with sprite-renderer above, it handle vertex-buffer and shader-uniforms differently.
	You should call anim_voxel_draw_start() first before calling skeleton_voxel.render(), and use anim_voxel_draw_end() afterward.
	skeleton_voxel_write() and skeleton_voxel_read() are mostly used by editor, they simply return json-string to write to file.*/
function skeleton_voxel(skeleton) constructor
{
	data = [];
	texture = [];
	resource = ds_map_create();	// resource[? texture] = index
	vbuffer = [];
	reference = ds_map_create();
	vox_tranpos = -1;
	vox_texture = -1;
	size = 0;
	self.skeleton = skeleton;
	skeleton.voxel_data = self
	struct_format =
	{
		bone:0, type:0,
		texture:-1, UV:[0,0,0,0], texcoord:[0,0,0,0],center:[0,0,0],gridw:1, gridh:1,
		scale:1., x:0, y:0, z:0, rotation: quaternion_identity(), rotate_sprite: false, name: ""
	};
	
	// Game function usage, you only need to care about these
	static destroy = function()
	{
		if resource!=-1 ds_map_destroy(resource)
		if reference!=-1 ds_map_destroy(reference)
		var s;
		s = array_length(vbuffer);		for(var i=0; i<s; i++) vertex_delete_buffer(vbuffer[i]);
		if vox_tranpos!=-1 {buffer_delete(vox_tranpos); vox_tranpos=-1}
		if vox_texture!=-1 {buffer_delete(vox_texture); vox_texture=-1}
		
		resource=-1;
		reference=-1
		vbuffer=[]
	}
	static add_sprite = function(boneInd, sprite, subimg, texcoord, center, gridw, gridh, name)
	{
		/*
		Simply add a sprite to skeleton render.
		*/
		var tex = sprite_get_texture(sprite, subimg)
		var texture_ind = resource[? tex];
		if is_undefined(texture_ind) {texture_ind=ds_map_size(resource); resource[? tex]=texture_ind; array_push(texture, tex)}
		var w = (texcoord[2]-texcoord[0])*gridw;
		var h = (texcoord[3]-texcoord[1])*gridh;
		var UV = sprite_get_tile_uv(sprite, subimg, texcoord[0], texcoord[1], w, h)
		var out =
		{
			bone: boneInd, type:0,
			texture: texture_ind, UV:UV, texcoord:texcoord, center:center, gridw:gridw, gridh:gridh,
			scale:1., x:0, y:0, z:0, rotation: quaternion_identity()
		}
		struct_inherit(out, struct_format)
		array_push(data, out);
		size = array_length(data);
		if !is_undefined(name) reference[? name] = out;
		log("Voxel added: "+string(out))
		build_vbuffer();
		return out;
	};
	static delete_sprite = function(struct)
	{
		if is_string(struct)
		{
			var str = reference[? struct]
			if is_undefined(struct) {log("Sprite reference not found, name is incorrect or data reference is not defined: "+struct);return false;}
			struct = str
		}
		var s = array_length(data);
		for(var i=0; i<s; i++)
		{
			if data[i]==struct
			{
				array_delete(data,i,1);
				size = array_length(data)
				build_vbuffer();
				delete struct;
				return true
			}
		}
		return false;
	}
	static get_reference = function(name)
	{
		return reference[? name];
	}
	static bind_texture_sprite = function(index, sprite, subimg)
	{
		// swap a different sprite texture, it will also iterate through all bone configurations and correct UV positions.
		var tex = sprite_get_texture(sprite, subimg);
		texture[@ index] = tex;
		for(var i=0; i<size; i++)
		{
			var spr = data[i];
			if spr.texture != index continue;
			var texcoord = spr.texcoord;
			var UV = sprite_get_tile_uv(sprite, subimg, texcoord[0], texcoord[1], texcoord[2]-texcoord[0], texcoord[3]-texcoord[1]);
			spr.UV = UV;
			spr.uvs = variable_clone(UV);
		}
		resource[? tex] = index;
	}

	// System function, if you want to tinker around
	static clear_cache = function()
	{
		// flush vertex buffer data, sprite data are untouched
		var count = array_length(vbuffer)
		for(var i=0; i<count; i++) {vertex_delete_buffer(vbuffer[i])}
		// check for unused texture and remove it from reference
		count = array_length(texture);
		var check = array_create(count, false);
		for(var i=0; i<size; i++)
		{
			var spr = data[i];
			check[@ spr.texture] = true;
		}
		for(var i=count-1; i>=0; i--)
		{
			// remove unused texture
			if check[i]==false
			{
				array_delete(texture, i, 1)
				var k = ds_map_find_first(resource);
				var s = ds_map_size(resource);
				for(var j=0; j<s; j++)
				{
					if resource[? k]==i {ds_map_delete(resource,k);break}
					k = ds_map_find_next(resource, k)
				}
			}
		}
		count = array_length(texture);
		vbuffer = array_create(count, -1);
		if vox_tranpos!=-1 {buffer_delete(vox_tranpos); vox_tranpos=-1}
		if vox_texture != -1 {buffer_delete(vox_texture); vox_texture=-1}
	}
	static render = function()
	{
		static sh_tranpos = shader_get_uniform(AnimationVoxelShader, "u_transform");
		static sh_page = shader_get_uniform(AnimationVoxelShader, "u_page");
		static sh_texture = shader_get_uniform(AnimationVoxelShader, "u_texture");
		static sh_invWorld = shader_get_uniform(AnimationVoxelShader, "u_invWorld");
		var s = array_length(vbuffer); if (s==0) return;
		shader_set_uniform_f_buffer(sh_tranpos, vox_tranpos, 0, size*4*4);
		shader_set_uniform_f_buffer(sh_texture, vox_texture, 0, size*4*1);
		shader_set_uniform_f_array(sh_invWorld, skeleton.matrix_inv);
		
		for(var i=0;  i<s; i++)
		{
			vertex_submit(vbuffer[i], pr_trianglelist, texture[i])
		}
	}
	static build_vbuffer = function()
	{
		// clear vertex-buffer and create new one, use when add/remove or modifying sprite type.
		clear_cache();
		
		var count = array_length(texture);
		if count==0 return false;
		for(var i=0; i<count; i++) {vBuff = vertex_create_buffer(); vertex_begin(vBuff, global.animVoxelFormat); vbuffer[@i]=vBuff}
		var slot, spr, bone;
		vox_tranpos=buffer_create(4*4*4*size, buffer_fixed, 4);	// 2x vec4 per bone-sprite (rotation and position)
		vox_texture=buffer_create(4*4*1*size, buffer_fixed, 4);	// 3x vec4 per bone-sprite (texture UV, texture width/height & grid width/height, sprite center)
		
		var r0 = [0,0,0];
		var r1 = [1,1,1];
		var col = c_black, ind;
		var scale = [0,0,0];
		var padding = 0
		var bone, link, rot;
		for(var i=0; i<size; i++)
		{
			var spr = data[i]
			var vBuff = vbuffer[spr.texture];
			bone = skeleton.data[spr.bone];
			//link = skeleton.data[bone.link];
			rot = spr.rotate_sprite * 255.;
			if spr.rotate_sprite padding=2 else padding=0;
			
			ind = i/255; 
			//col = make_color_rgb(0,0,0); // custom u8 attribute
			
			//-x
			vertex_position_3d(vBuff, r0[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			vertex_position_3d(vBuff, r0[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			//+x
			vertex_position_3d(vBuff, r1[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			vertex_position_3d(vBuff, r1[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			//-y
			vertex_position_3d(vBuff, r0[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			vertex_position_3d(vBuff, r0[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			//+y
			vertex_position_3d(vBuff, r0[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			vertex_position_3d(vBuff, r0[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			//-z
			vertex_position_3d(vBuff, r0[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			vertex_position_3d(vBuff, r0[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r0[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			//+z
			vertex_position_3d(vBuff, r0[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r0[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);

			vertex_position_3d(vBuff, r0[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r0[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			vertex_position_3d(vBuff, r1[0],	r1[1],	r1[2]);	vertex_color(vBuff, make_color_rgb(bone.index,0,0), 0); vertex_color(vBuff, make_color_rgb(255,0,0), 0); vertex_color(vBuff, col, ind);
			
			slot = i*(4*4*4); //4 bytes * vec4 * 4x per bone
			var w = (spr.texcoord[2]-spr.texcoord[0])*spr.gridw;
			var h = (spr.texcoord[3]-spr.texcoord[1])*spr.gridh;
			buffer_seek(vox_tranpos, buffer_seek_start, slot);
			buffer_writes(vox_tranpos, buffer_f32, spr.x+bone.Ox, spr.y+bone.Oy, spr.z+bone.Oz, spr.scale)
			buffer_writes(vox_tranpos, buffer_f32, spr.rotation[0], spr.rotation[1], spr.rotation[2], spr.rotation[3])
			buffer_writes(vox_tranpos, buffer_f32, spr.center[0], spr.center[1], spr.center[2], 0);
			buffer_writes(vox_tranpos, buffer_f32, w, h, spr.gridh, spr.gridw);
			
						
			slot = i*(4*4*1); 
			buffer_seek(vox_texture, buffer_seek_start, slot);
			buffer_writes(vox_texture, buffer_f32, spr.UV[0], spr.UV[1], spr.UV[2], spr.UV[3]);
		}
		for(var i=0; i<count; i++) {vBuff = vbuffer[i]; vertex_end(vBuff);	vertex_freeze(vBuff);}
	}
}
function anim_voxel_draw_start()
{
	static shader = AnimationVoxelShader
	static camPos = shader_get_uniform(AnimationVoxelShader, "u_camPos");
	static ViewMat = shader_get_uniform(AnimationVoxelShader, "u_view");
	static TanFOV = shader_get_uniform(AnimationVoxelShader, "u_tanFOV");
	static Aspect = shader_get_uniform(AnimationVoxelShader, "u_aspect");
	static Near = shader_get_uniform(AnimationVoxelShader, "u_near");
	static Far = shader_get_uniform(AnimationVoxelShader, "u_far");
	
	var vM = matrix_get(matrix_view);
	var pM = matrix_get(matrix_projection);
	var cam = [
		- vM[12] * vM[0] - vM[13] * vM[1] - vM[14] * vM[2], 
		- vM[12] * vM[4] - vM[13] * vM[5] - vM[14] * vM[6], 
		- vM[12] * vM[8] - vM[13] * vM[9] - vM[14] * vM[10]];
	var FOV = 1 / pM[5];
	var aspect = pM[5] / pM[0];
	
	gpu_push_state()
	shader_set(shader)
	shader_set_uniform_f_array(camPos, cam);
	shader_set_uniform_f_array(ViewMat, vM);
	shader_set_uniform_f(TanFOV, FOV);
	shader_set_uniform_f(Aspect, aspect);
	shader_set_uniform_f(Near, renderer.near);
	shader_set_uniform_f(Far, renderer.far);
	gpu_set_tex_filter(false);
	gpu_set_tex_repeat(false);
	gpu_set_cullmode(cull_clockwise);
	gpu_set_ztestenable(true);
	gpu_set_zwriteenable(true);
}
function anim_voxel_draw_end()
{
	shader_reset();
	gpu_pop_state();
}
function skeleton_voxel_write(struct)
{
	// output string data, to write to file or to use in networking.
	// read string ouput using skeleton_voxel_read()
	return json_stringify(struct.data)
}
function skeleton_voxel_read(str, skeleton, struct)
{
///@func skeleton_voxel_read(string, skeleton, [struct])
	var data = json_parse(str);
	var tex = 1;
	var s = array_length(data);
	for(var i=0; i<s; i++)
	{
		var spr = data[i];
		tex = max(tex, spr.texture+1);
		
		// Reference skeleton name
		var b = spr.bone;
		var n = "";
		if array_length(skeleton.data)>b {n=skeleton.data[b].name}
		var name = spr[$ "name"];
		if is_undefined(name) || name=="" {spr.name = n; continue}
		var ind = skeleton.reference[? name];
		if is_undefined(ind) {spr.name = n; continue};
		spr.bone = ind;
	}
	if !is_struct(struct)
	{
		struct = new skeleton_voxel(skeleton);
		struct.texture = array_create(tex, -1);
	} else {
		var len = array_length(struct.texture);
		for(var i=len; i<tex; i++) array_push(struct.texture, -1);
	}
	struct.data = data;
	struct.size = array_length(data);
	struct.build_vbuffer();
	return struct;
}
