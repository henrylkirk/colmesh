// Verlet integration
fric = 1 - 0.4;
spdX = (x - prevX) * fric;
spdY = (y - prevY) * fric;
spdZ = (z - prevZ) * (1 - 0.01);
prevX = x;
prevY = y;
prevZ = z;

// Controls
jump = keyboard_check_pressed(vk_space);
var h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var v = keyboard_check(ord("W")) - keyboard_check(ord("S"));
if (h != 0 and v != 0) {	//If walking diagonally, divide the input vector by its own length
	var s = 1 / sqrt(2);
	h *= s;
	v *= s;
}

// Move
acc = 5;
x += spdX - acc * v;
y += spdY - acc * h;
z += spdZ - 1 + jump * ground * 15; // Apply gravity in z-direction

//Cast a short-range ray from the previous position to the current position to avoid going through geometry
//Only cast ray if there's a risk that we've gone through geometry
if (sqr(x - prevX) + sqr(y - prevY) + sqr(z - prevZ) > radius * radius){
	var d = height * (0.5 + 0.5 * sign(xup * (x - prevX) + yup * (y - prevY) + zup * (z - prevZ)));
	var dx = xup * d;
	var dy = yup * d;
	var dz = zup * d;
	ray = global.room_colmesh.cast_ray(prevX + dx, prevY + dy, prevZ + dz, x + dx, y + dy, z + dz);
	if is_array(ray) {
		x = ray[0] - dx - (x - prevX) * 0.1;
		y = ray[1] - dy - (y - prevY) * 0.1;
		z = ray[2] - dz - (z - prevZ) * 0.1;
	}
}

// Avoid ground
var col = global.room_colmesh.displace_capsule(x, y, z, 0, 0, 1, radius, height, 40, false, true);
if (col.is_collision) {
	x = col.x;
	y = col.y;
	z = col.z;
	ground = col.is_on_ground;
} else {
	ground = false;
}

//Put player in the middle of the map if he falls off
if (z < -400) {
	x = 0;
	y = 0;
	z = 300;
	prevX = x;
	prevY = y;
	prevZ = z;
}

var d = 150;
global.camX = x + d * dcos(yaw) * dcos(pitch);
global.camY = y + d * dsin(yaw) * dcos(pitch);
global.camZ = z + d * dsin(pitch);
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, x, y, z, xup, yup, zup));