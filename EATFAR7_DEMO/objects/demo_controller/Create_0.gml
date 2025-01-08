woman_spr = sprite_add("Texture\\woman.png", 1, false, false, 0, 0);
human_spr = sprite_add("Texture\\human_spr.png", 1, false, false, 0, 0);
firearms_voxel = sprite_add("Texture\\firearms_voxel.png", 1, false, false, 0, 0);

animation_load("Animations\\Idle.anim", "Idle");
animation_load("Animations\\Vigilant.anim", "Vigilant");
animation_load("Animations\\Roll.anim", "Roll");
animation_load("Animations\\Walk.anim", "Walk");
animation_load("Animations\\walk_backward.anim", "Walk_backward");
animation_load("Animations\\strafe_right.anim", "Strafe_right");
animation_load("Animations\\strafe_left.anim", "Strafe_left");
animation_load("Animations\\Sprint.anim", "Sprint");
animation_load("Animations\\Sprint_start.anim", "Sprint_start");
animation_load("Animations\\Sprint_stop.anim", "Sprint_stop");
animation_load("Animations\\Sprint_turn.anim", "Sprint_turn");
animation_load("Animations\\turn_right.anim", "Turn_right");
animation_load("Animations\\turn_left.anim", "Turn_left");
animation_load("Animations\\equip_handgun.anim", "Equip_handgun");

mouse_sensitivity = 0.1
axis1_x = 0;
axis1_y = 0;
axis2_x = 0;
axis2_y = 0;

instance_create_depth(0,0,0, obj_character);