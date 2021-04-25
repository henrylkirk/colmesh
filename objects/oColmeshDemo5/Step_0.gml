// Verlet integration
fric = 1 - .4;
spdX = (x - prevX) * fric;
spdY = (y - prevY) * fric;
spdZ = (z - prevZ) * (1 - 0.01);
prevX = x;
prevY = y;
prevZ = z;

// Controls (rotated 90 degrees to match camera)
jump = keyboard_check_pressed(vk_space);
var h = keyboard_check(ord("W")) - keyboard_check(ord("S"));
var v = keyboard_check(ord("A")) - keyboard_check(ord("D"));
if (h != 0 && v != 0){	// If walking diagonally, divide the input vector by its own length
	var s = 1 / sqrt(2);
	h *= s;
	v *= s;
}

// Move
acc = 2;
x += spdX - acc * v;
y += spdY - acc * h;
z += spdZ - 1 + jump * ground * 15; // Apply gravity in z-direction

// Cast a short-range ray from the previous position to the current position to avoid going through geometry
if (sqr(x - prevX) + sqr(y - prevY) + sqr(z - prevZ) > radius * radius) //Only cast ray if there's a risk that we've gone through geometry
{
	var d = height * (.5 + .5 * sign(xup * (x - prevX) + yup * (y - prevY) + zup * (z - prevZ)));
	var dx = xup * d;
	var dy = yup * d;
	var dz = zup * d;
	ray = global.levelColmesh.castRay(prevX + dx, prevY + dy, prevZ + dz, x + dx, y + dy, z + dz);
	if is_array(ray) {
		x = ray[0] - dx - (x - prevX) * .1;
		y = ray[1] - dy - (y - prevY) * .1;
		z = ray[2] - dz - (z - prevZ) * .1;
	}
}

// Avoid ground
col = global.levelColmesh.displace_capsule(x, y, z, radius, height, 40, false, true);
if (col.is_collision) {
	// If we're touching ground...
	x = col.x;
	y = col.y;
	z = col.z;
	ground = col.is_on_ground;
}

// Put player in the middle of the map if he falls off
if (z < -400) {
	x = xstart;
	y = ystart;
	z = 300;
	prevX = x;
	prevY = y;
	prevZ = z;
}

var d = 100;
global.camX = x + d * dcos(yaw) * dcos(pitch);
global.camY = y + d * dsin(yaw) * dcos(pitch);
global.camZ = z + d * dsin(pitch);
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, x, y, z, xup, yup, zup));