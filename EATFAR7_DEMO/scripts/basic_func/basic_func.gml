// DEMO
// These function are for demo to work.
function cmd_init() {	
	global.temp_list=ds_list_create();
	global.temp_map=ds_map_create();
	global.temp_grid=ds_grid_create(1,1);
	global.temp_buffer=buffer_create(128, buffer_grow, 1)
	
	global.script_ids=ds_map_create();
	global.object_ids=ds_map_create();
	global.memory_ids=ds_map_create();
	global.variables=ds_map_create();
	var s=global.script_ids
	var o=global.object_ids
}
function mouse_get_button_pressed() {
	if mouse_check_button_pressed(mb_right) {return(mb_right)}
	else if mouse_check_button_pressed(mb_left) {return(mb_left)}
	else if mouse_check_button_pressed(mb_middle) {return(mb_middle)}
	else if mouse_check_button_pressed(mb_side1) {return(mb_side1)}
	else if mouse_check_button_pressed(mb_side2) {return(mb_side2)}
	return(mb_none)
	}
function mouse_get_button_released() {
	if mouse_check_button_released(mb_right) {return(mb_right)}
	else if mouse_check_button_released(mb_left) {return(mb_left)}
	else if mouse_check_button_released(mb_middle) {return(mb_middle)}
	else if mouse_check_button_released(mb_side1) {return(mb_side1)}
	else if mouse_check_button_released(mb_side2) {return(mb_side2)}
	return(mb_none)
	}
function frametime()
{
	return main.frameend - ((get_timer()/1000)-main.framestart);
}
function debug_overlay(text, index=-1) {
	var out = false;
	if index<0 {
		ds_list_add(main.debug_txt, string(text));
		return true;
	} else {
		var s = ds_list_size(main.debug_txt);
		ds_list_set(main.debug_txt, index, string(text));
		if s<=index return true else return false
	}
}
function debug_overlay_clear(text, index=-1) {ds_list_clear(main.debug_txt)}

//	REQUISITE
// These function are required for the animation system to works properly
function log(text,type=""){
	text=string(text)
	show_debug_message(string(text))
}
function struct_inherit(child, parent)
{
	// Child struct will inherit parent struct variables, but will not overwrite any of the child's variable
	var names = struct_get_names(parent)
	var s = array_length(names)
	for(var i=0;i<s;i++)
	{
		var name = names[i];
		if struct_get(child, name)=undefined child[$ name]=variable_clone(parent[$ name]);
	}
}
function struct_replace(source, dest)
{
	// This struct replace a struct variable with another struct's variable.
	var names = struct_get_names(source)
	var s = array_length(names)
	for(var i=0;i<s;i++)
	{
		var name = names[i];
		dest[$ name] = source[$ name];
	}
}
function ds_map_create_struct(ds_map, result={})
{
	var s = ds_map_size(ds_map);
	var k = ds_map_find_first(ds_map), val;
	for(var i=0; i<s; i++)
	{
		val = ds_map[? k];
		struct_set(result, string(k), val)
		k = ds_map_find_next(ds_map, k);
	}
	return result;
}
function buffer_writes(buffer, type, value) {for (var i = 2; i < argument_count; i ++) buffer_write(buffer, type, argument[i])}
function InvLerp( val1, val2, value ) {
   gml_pragma("forceinline");
	//find the percentage that equates to the position between two other values for a given value. 
	return (value-val1)/(val2-val1)
}
function cross_product(a, b, result = array_create(3)) {
	var ax = a[0], ay = a[1], az = a[2],
		bx = b[0], by = b[1], bz = b[2];
	result[@0] = ay * bz - az * by;
	result[@1] = az * bx - ax * bz;
	result[@2] = ax * by - ay * bx;
	return result
}
function normalize(vec) {
	// Normalize this vector, vector component can be array or arguments
	var sum = 0, count, val, v;
	if is_array(vec)
	{
		v = vec;
		count = array_length(vec)
		for(var i=0; i<count; i++) sum+=power(vec[i], 2);
	} else {
		count = argument_count;
		v = array_create(count, 0);
		for(var i=0; i<count; i++) {val=argument[i]; sum+=power(val, 2); v[@i] = val}
	}
	var mag = sqrt(sum);
	for(var i=0; i<count; i++)
	{
		v[@i] = v[i]/mag;
	}
	return v;
}
function magnitude(vec)
{
	// Returns the length of this vector, vector component can be array or arguments
	var sum = 0, count, val;
	if is_array(vec)
	{
		count = array_length(vec)
		for(var i=0; i<count; i++) sum+=power(vec[i], 2);
	} else {
		count = argument_count;
		for(var i=0; i<count; i++) sum+=power(argument[i], 2);
	}
	return sqrt(sum);
}
function line_perpendicular_3d(x1,y1,z1, x2,y2,z2, px, py, pz, array=array_create(3))
{	
	// Find a point on a 3D line that is perpendicular to a 3D point.
	var vx = x2 - x1;
	var vy = y2 - y1;
	var vz = z2 - z1;
	
	var wx = px - x1;
	var wy = py - y1;
	var wz = pz - z1;
	
	var dot = dot_product_3d(wx, wy, wz, vx, vy, vz)
	var d = dot_product_3d(vx, vy, vz, vx, vy, vz)
	array[@0] = px - (wx - dot / d * vx);
	array[@1] = py - (wy - dot / d * vy);
	array[@2] = pz - (wz - dot / d * vz);
	return array;
}
function circle_intersect_circle(x0, y0, r0, x1, y1, r1, array=array_create(4))
{
	//	https://stackoverflow.com/questions/55816902/finding-the-intersection-of-two-circles
	var d=sqrt(power(x1-x0,2) + power(y1-y0,2))
    
	// non intersecting
	if d > r0 + r1 return undefined
	// One circle within other
	if d < abs(r0-r1) return undefined
	// coincident circles
	if d == 0 and r0 == r1 return undefined
	
	var a=(r0*r0-r1*r1+d*d)/(2*d)
	var h=sqrt(r0*r0-a*a)
	var x2=x0+a*(x1-x0)/d   
	var y2=y0+a*(y1-y0)/d   
	var x3=x2+h*(y1-y0)/d     
	var y3=y2-h*(x1-x0)/d 

	var x4=x2-h*(y1-y0)/d
	var y4=y2+h*(x1-x0)/d
        
	array[@0]=x3
	array[@1]=y3
	array[@2]=x4
	array[@3]=y4
	return array;
}
function sprite_get_tile_uv(sprite,index,left,top,width,height) {
	var spr_uv=sprite_get_uvs(sprite, index);
	var uv=array_create(4);
	var w=sprite_get_width(sprite)
	var h=sprite_get_height(sprite)
	uv[@0]=lerp(spr_uv[0],spr_uv[2],left/w);
	uv[@2]=lerp(spr_uv[0],spr_uv[2],(left+width)/w);
	uv[@1]=lerp(spr_uv[1],spr_uv[3],top/h);
	uv[@3]=lerp(spr_uv[1],spr_uv[3],(top+height)/h);
	return uv;
}
