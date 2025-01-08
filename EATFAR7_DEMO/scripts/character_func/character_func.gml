enum state_event
{
	start,
	step,
	finish
}
// BASIC CHARACTER BEHAVIOR MACHINE STATE
function basic_state()
{
	static change_state = function(func)
	{
		state(state_event.finish);
		state = func;
		state(state_event.start);
	}
	l_feet=-1;r_feet=-1;
	leg_rot=-1; anim_mix=-1
	turn_hip = anim_stack_rotate_bone(anim_main, "Torso", quaternion_identity()).push();
	turn_head = anim_stack_rotate_bone(anim_main, "Head", quaternion_identity(), true, -1).push();
	equip = anim_stack_bind_transform(anim_main, "ArmRight", "RThigh", -2.6, 2.6, -1.1, quaternion_build(0,1,0,90)).push()
	state = basic_state.idle;
	state(state_event.start);
	static idle = function(event)
	{
		static change_state = basic_state.change_state
		var look = -renderer.xyAngle+180;
		var move = point_distance(0,0,demo_controller.axis1_x,-demo_controller.axis1_y);
		var facing = anim_direction();
		switch(event)
		{
			case state_event.start:
				debug_overlay("State: Idle", 0)
				anim_stack_set_animation(anim_main, "Vigilant", 0, 1.5);
				direction+=anim_stack_reset_rotation(anim_main);
				break
			case state_event.step:
				// Get angle between camera's and character's direction
				var xyangle = angle_difference(facing, look-10);
				var zangle = renderer.zAngle-20;
				
				if anim_main.loop // Check if animation is idle-loop
				{
					// Turn behavior
					if xyangle<-90 {anim_stack_set_animation(anim_main, "Turn_left", 0, 1.5, false, 0.1); exit}
					if xyangle>120 {anim_stack_set_animation(anim_main, "Turn_right", 0, 1.5, false, 0.1); exit}
				} else {
					// Not idle-loop animation, wait until this animation finish and play idle-loop animation
					if anim_stack_playing(anim_main)<=0
					{
						anim_stack_set_animation(anim_main, "Vigilant", 0, 1.5);
						direction+=anim_stack_reset_rotation(anim_main);
					}
				}
				// Turn hip and head to looking direction
				//xyangle = clamp(xyangle, -60, 120);
				if zangle>0 zangle/=2
				quaternion_build(0, 0, 1, xyangle/2, turn_hip.quaternion);
				var temp = direction-facing;
				if temp<-180 temp+=360 else if temp>180 temp-=360
				angle_to_quaternion(0, zangle, temp+xyangle, turn_head.quaternion);
				
				// Control check
				if move>0.25 change_state(basic_state.walk);
				break
			case state_event.finish:
				quaternion_identity(turn_hip.quaternion);
				break
		}
	}
	
	static walk = function(event)
	{
		static change_state = basic_state.change_state
		var look = -renderer.xyAngle+180
		var move = point_distance(0,0,demo_controller.axis1_x,-demo_controller.axis1_y);
		var facing = anim_direction();
		switch(event)
		{
			case state_event.start:
				debug_overlay("State: Walk", 0)
				anim_stack_set_animation(anim_main, "Walk", 1, 1, true, 0.1);
				direction+=anim_stack_reset_rotation(anim_main);
				if (leg_rot==-1) {leg_rot = anim_stack_rotate_bone(anim_main, ["LThigh", "RThigh"], quaternion_identity(), true, -1, 0);} // reduce leg rotation when turning
				break
			case state_event.step:
				// Control check
				if move<0.25 {change_state(basic_state.idle); break}
				if move>1.1 {change_state(basic_state.sprint); break}
				var dir = point_direction(0, 0, demo_controller.axis1_x, -demo_controller.axis1_y)+90;
				var angle = angle_difference(direction, look-dir);
				
				// Direction
				direction=lerp(direction, direction-clamp(angle, -6, 6), 0.5);
				speed_mult = (20-clamp(abs(angle), 0, 6))/20;
				leg_rot.amount = (1-speed_mult);
					
				// Turn hip to turning direction
				quaternion_build(0, 0, 1, clamp(angle, -40, 40), turn_hip.quaternion)
				// Turn head to looking direction
				var xyangle = angle_difference(facing,look-20);
				var zangle = renderer.zAngle-20;
				if zangle>0 zangle/=2
				
				var temp = direction-facing;
				if temp<-180 temp+=360 else if temp>180 temp-=360
				angle_to_quaternion(0, zangle, temp+clamp(xyangle, -70, 70), turn_head.quaternion);
				break
								
			case state_event.finish:
				if !(leg_rot==-1) {anim_stack_delete_layer(leg_rot); leg_rot=-1}
				speed_mult = 1;
				break
		}
	}
	
	static strafe = function(event)
	{
		static change_state = basic_state.change_state
		var look = -renderer.xyAngle+180
		var move = point_distance(0,0,demo_controller.axis1_x,-demo_controller.axis1_y);
		switch(event)
		{
			case state_event.start:
				debug_overlay("State: Strafe", 0)
				anim_stack_set_animation(anim_main, "Walk", 1, 1, true, 0.1);
				direction+=anim_stack_reset_rotation(anim_main);
				quaternion_identity(turn_hip.quaternion)
				quaternion_identity(turn_head.quaternion)
				anim_mix = anim_stack_mix_animation(anim_main, "Strafe_right", 0.).insert(0);
				break
			case state_event.step:
				// Control check
				if move<0.25 {change_state(basic_state.idle); break}
				if move>1.1 {change_state(basic_state.sprint); break}
				var dir = point_direction(0, 0, demo_controller.axis1_x, -demo_controller.axis1_y)+90;
				var angle = angle_difference(direction, look);
				
				// Movement controlled by animation
				switch(anim_main.reference)
				{
					case "Walk":
						if demo_controller.axis1_y>0 anim_stack_set_animation(anim_main, "Walk_backward", 0, 1, true, 0.1); 
						break
							
					case "Walk_backward":
						if demo_controller.axis1_y<0 anim_stack_set_animation(anim_main, "Walk", 0, 1, true, 0.1); 
						break
				}
				//var temp = normalize(demo_controller.axis1_x, demo_controller.axis1_y);
				switch(anim_mix.reference)
				{
					case "Strafe_right":
						if demo_controller.axis1_x<0 anim_layer_set_animation(anim_mix, "Strafe_left"); 
						break
							
					case "Strafe_left":
						if demo_controller.axis1_x>0 anim_layer_set_animation(anim_mix, "Strafe_right"); 
						break
				}
				var temp = abs(demo_controller.axis1_x) / (abs(demo_controller.axis1_x)+abs(demo_controller.axis1_y));
				debug_overlay("X strafe: "+string(temp), 1);
				anim_mix.amount = abs(temp);
				
				// Direction
				direction=lerp(direction, direction-clamp(angle, -10, 10), 0.5);
				break
								
			case state_event.finish:
				if !(anim_mix==-1) {anim_stack_delete_layer(anim_mix); anim_mix=-1}
				break
		}
	}

	static sprint = function(event)
	{
		static change_state = basic_state.change_state
		var look = -renderer.xyAngle+180
		var move = point_distance(0,0,demo_controller.axis1_x,-demo_controller.axis1_y);
		var facing = anim_direction();
		switch(event) 
		{
			case state_event.start:
				debug_overlay("State: Sprint", 0)
				anim_stack_set_animation(anim_main, "Sprint_start", 1, 1, false, 0.1);
				direction+=anim_stack_reset_rotation(anim_main);
				anim_mix = anim_stack_mix_animation(anim_main, "Sprint", 0.).insert(0);
				break
			case state_event.step:	
				var dir = point_direction(0, 0, demo_controller.axis1_x, -demo_controller.axis1_y)+90;
				var angle = angle_difference(direction, look-dir);
				if anim_main.loop
				{
					// Control check
					if move<1.1 anim_stack_set_animation(anim_main, "Sprint_stop", 1, 1, false);
					direction=lerp(direction, direction-clamp(angle, -5, 5), 0.5);
					if abs(angle)>110 anim_stack_set_animation(anim_main, "Sprint_turn", 0., 1.25, false)
					
					// Reduce speed when turning
					speed_mult = (20-clamp(abs(angle), 0, 6))/20;
					turn_hip.amount = lerp(turn_hip.amount, 1, 0.05)
					turn_head.amount = lerp(turn_head.amount, 1, 0.05)
				} else {
					switch(anim_main.reference)
					{
						case "Sprint_start":
						anim_mix.amount = anim_main.time / animation_get_duration(anim_main.animation);
						direction=lerp(direction, direction-clamp(angle, -5, 5), 0.5);
						if anim_stack_playing(anim_main)>0.99
						{
							// Not sprint-loop animation, wait until this animation finish and play sprint-loop animation
							if !(anim_mix==-1) {anim_stack_delete_layer(anim_mix); anim_mix=-1}
							anim_stack_set_animation(anim_main, "Sprint", -1, 1, true)
						}
						break
						
						case "Sprint_stop":
						if anim_stack_playing(anim_main)>0.99
						{
							change_state(basic_state.idle); break
						} else if anim_stack_playing(anim_main)<0.9 {
							if move>1.1
							{
								if abs(angle)>110 anim_stack_set_animation(anim_main, "Sprint_turn", 5, 1.25, false, 0.1)
								else {
									var step = (1-anim_stack_playing(anim_main))/2;
									anim_stack_set_animation(anim_main, "Sprint_start", step, 1, false, 0.1);
									anim_mix = anim_stack_mix_animation(anim_main, "Sprint", 0.).insert(0);
								}
							}
							
							if anim_stack_playing(anim_main)>0.7 && move>0.1
							{
								change_state(basic_state.walk); break
							}
						}
						break
						
						case "Sprint_turn":
						turn_hip.amount = 0;
						turn_head.amount = 0;
						if anim_stack_playing(anim_main)>0.99
						{
							anim_stack_set_animation(anim_main, "Sprint", -1, 1, true, 0.05)
							direction+=anim_stack_reset_rotation(anim_main);
						}
						break
					}
				}
					
				// Turn hip to turning direction
				quaternion_build(0, 0, 1, clamp(angle, -40, 40), turn_hip.quaternion)
				// Turn hip and head to looking direction
				var xyangle = angle_difference(facing, look-20);
				var zangle = renderer.zAngle - 20;
				xyangle = clamp(xyangle, -60, 60);
				if zangle>0 zangle/=2
				
				var temp = direction-facing;
				if temp<-180 temp+=360 else if temp>180 temp-=360
				angle_to_quaternion(0, zangle, temp+clamp(xyangle, -70, 70), turn_head.quaternion);
				//var temp = quaternion_build(0, 0, 1, xyangle)
				//quaternion_build(0, 1, 0, zangle, turn_head.quaternion)
				//quaternion_multiply(temp, turn_head.quaternion, turn_head.quaternion)
				break
			case state_event.finish:
				if !(anim_mix==-1) {anim_stack_delete_layer(anim_mix); anim_mix=-1}
				break
		}
	}
}

function secondary_state()
{
	arm_state = secondary_state.unequipped;
	arm_state(state_event.start);
	arm_mix = -1
	static change_state = function(func)
	{
		arm_state(state_event.finish);
		arm_state = func;
		arm_state(state_event.start);
	}
	static unequipped = function(event)
	{
		static change_state = secondary_state.change_state
		switch(event)
		{
			case state_event.step:
			if mouse_check_button_pressed(mb_right) change_state(secondary_state.equip)
			break
		}
	}
	
	static equip = function(event)
	{
		static change_state = secondary_state.change_state
		switch(event)
		{
			case state_event.start:
				anim_stack_add(anim_arm);
				anim_stack_set_animation(anim_arm, "Equip_handgun", 0, 1, false, 0.1);
				arm_mix = anim_stack_anchor_IK(anim_arm, "RHand", "RThigh", true, 1).push()
				break
			case state_event.step:
				if animation_player_get_event(player, "Equip")
				{
					anim_stack_delete_layer(equip);
					var bone = check_bone("ArmRight", skeleton);
					anim_stack_add_bone(anim_arm, bone.index)
					equip = anim_stack_bind_transform(anim_arm, "ArmRight", "RHand", -0.4, 2.8, -1.1, angle_to_quaternion(90,0,90)).push()
				}
				if anim_stack_playing(anim_arm)>=1 change_state(secondary_state.equipped)
				break;
			case state_event.finish:
				anim_stack_delete_layer(equip);
				anim_stack_delete_layer(arm_mix); arm_mix=-1;
				anim_stack_remove(anim_arm);
				equip = anim_stack_bind_transform(anim_main, "ArmRight", "RHand", -0.4, 2.8, -1.1, angle_to_quaternion(90,0,90)).push();
				//skeleton.delete_bone("ArmRight")
				//voxel_model.build_vbuffer()
				break
		}
	}
	
	static equipped = function(event)
	{
		switch(event)
		{
			case state_event.step:
		}
	}
}