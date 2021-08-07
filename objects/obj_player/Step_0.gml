var fric = is_on_ground ? friction_ground : friction_air;
//velocity.x = (x - prev_position.x) * fric;
//velocity.y = (y - prev_position.y) * fric;
velocity.z = (z - prev_position.z) * (0.99);

prev_position.set(x, y, z);

jump = keyboard_check_pressed(vk_space);
z += velocity.z - 1 + jump * is_on_ground * 15; // Apply gravity in z-direction

global.demo_text = "x: "+string(round(x))+"\n" + "y: "+string(round(y))+"\n"+"z: "+string(round(z));

// Movement
var h = keyboard_check(ord("W")) - keyboard_check(ord("S"));
var v = keyboard_check(ord("A")) - keyboard_check(ord("D"));
if (h != 0 and v != 0){	// If walking diagonally, divide the input vector by its own length
	h *= ONE_OVER_SQRT_TWO;
	v *= ONE_OVER_SQRT_TWO;
}
var acc = 5; // movement acceleration
x += velocity.x - acc * v;
y += velocity.y - acc * h;

// Put player in the middle of the map if he falls off
if (z < -400) {
	x = room_width * 0.5;
	y = room_height * 0.5;
	z = 500;
	prev_position.set(x, y, z);
}

collider.step();