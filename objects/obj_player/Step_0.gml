var fric = is_on_ground ? friction_ground : friction_air;
velocity.x = (x - prev_position.x) * fric;
velocity.y = (y - prev_position.y) * fric;
velocity.z = (z - prev_position.z) * (0.99);

prev_position.set(x, y, z);

jump = keyboard_check_pressed(vk_space);
//z += velocity.z + (jump * is_on_ground * 15) - 1; // Apply gravity in z-direction
z += velocity.z + (jump * is_on_ground * 15) - 1; // Apply gravity in z-direction

// Movement
var v = keyboard_check(ord("S")) - keyboard_check(ord("W"));
var h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
if (v != 0 and h != 0){	// If walking diagonally, divide the input vector by its own length
	v *= ONE_OVER_SQRT_TWO;
	h *= ONE_OVER_SQRT_TWO;
}
var acc = 5; // movement acceleration
velocity.x += acc * h;
velocity.y += acc * v;

// Put player in the middle of the map if he falls off
if (z < -400) {
	x = room_width * 0.5;
	y = room_height * 0.5;
	z = 500;
	prev_position.set(x, y, z);
}

collider.step();

// Set demo text
global.demo_text = "x: "+string(round(x))+"\n" + "y: "+string(round(y))+"\n"+"z: "+string(round(z));