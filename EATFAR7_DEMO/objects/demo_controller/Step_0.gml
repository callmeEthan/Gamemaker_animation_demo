if keyboard_check_pressed(vk_f5) game_restart()

var xx = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var yy = keyboard_check(ord("S")) - keyboard_check(ord("W"));
var dir = point_direction(0,0,xx,yy);
var dist = 0
if abs(xx)+abs(yy)>0 dist = 1
if keyboard_check(vk_shift) dist*=2
xx = lengthdir_x(dist, dir);
yy = lengthdir_y(dist, dir);
axis1_x = lerp(axis1_x, xx, 0.5);
axis1_y = lerp(axis1_y, yy, 0.5);

renderer.xyAngle += main.mouse_xspeed * mouse_sensitivity;
renderer.zAngle += main.mouse_yspeed * mouse_sensitivity;
renderer.camDist = 80
renderer.floor_x = obj_character.x;
renderer.floor_y = obj_character.y;

// Shoulder view
var xx = obj_character.x + lengthdir_x(40, -renderer.xyAngle+90)
var yy = obj_character.y + lengthdir_y(40, -renderer.xyAngle+90)
renderer.xTo = lerp(renderer.xTo, xx, 0.1);
renderer.yTo = lerp(renderer.yTo, yy, 0.1);
renderer.zTo = lerp(renderer.zTo, obj_character.z+35, 0.2);

