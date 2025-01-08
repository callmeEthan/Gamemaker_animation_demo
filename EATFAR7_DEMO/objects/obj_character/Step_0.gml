//if !(keyboard_check(vk_right) || keyboard_check_pressed(vk_up)) exit
debug_overlay(0, 5)
state(state_event.step)
arm_state(state_event.step)

player.step(1./room_speed);
xspeed = (lengthdir_x(player.xspeed, direction) + lengthdir_x(player.yspeed, direction-90))*speed_mult;
yspeed = (lengthdir_y(player.xspeed, direction) + lengthdir_y(player.yspeed, direction-90))*speed_mult;

x += xspeed;
y += yspeed;
skeleton.matrix = matrix_build(x, y, z, 0,0,direction, 1,1,1)
skeleton.update_matrix();