// Save previous position
prev_position.set(x, y, z);

// Make sure not to fall through the ground
if z <= z_ground {
    z = z_ground;
	if enable_z_bounce and velocity_max.z > 0.1 {
		velocity_max.z *= 0.7;
		velocity.z = velocity_max.z;
	} else {
		velocity.z = 0;
	}
} else {
	velocity.z -= (mass * grav); // mass * acceleration
}

global.demo_text = "x: "+string(round(x))+"\n" + "y: "+string(round(y))+"\n"+"z: "+string(round(z));

// Movement
var h = keyboard_check(ord("S")) - keyboard_check(ord("W"));
var v = keyboard_check(ord("D")) - keyboard_check(ord("A"));
if (h != 0 and v != 0){	// If walking diagonally, divide the input vector by its own length
	h *= ONE_OVER_SQRT_TWO;
	v *= ONE_OVER_SQRT_TWO;
}
var acc = 2; // movement acceleration
velocity.x += acc * v;
velocity.y += acc * h;

// Put player in the middle of the map if he falls off
if (z < -400) {
	x = room_width * 0.5;
	y = room_height * 0.5;
	z = 500;
	prev_position.set(x, y, z);
}

// Move camera
var d = 100;
global.camX = x + d * dcos(yaw) * dcos(pitch);
global.camY = y + d * dsin(yaw) * dcos(pitch);
global.camZ = z + d * dsin(pitch);
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, x, y, z, xup, yup, zup));