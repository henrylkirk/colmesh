/// @description

//Verlet integration
fric = 1 - .4;
spdX = (x - prevX) * fric;
spdY = (y - prevY) * fric;
spdZ = (z - prevZ) * (1 - 0.01);

var D = global.room_colmesh.get_delta_matrix();
if (is_array(D)){
	colmesh_matrix_multiply_fast(D, charMat, charMat);
	x = charMat[12];
	y = charMat[13];
	z = charMat[14];
}

prevX = x;
prevY = y;
prevZ = z;

//Controls
var jump = keyboard_check_pressed(vk_space);
var h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var v = keyboard_check(ord("W")) - keyboard_check(ord("S"));
if (h != 0 and v != 0)
{	//If walking diagonally, divide the input vector by its own length
	var s = 1 / sqrt(2);
	h *= s;
	v *= s;
}

//Move
acc = 2;
x += spdX + acc * h;
y += spdY - acc * v;
z += spdZ - 1 + jump * ground * 15; //Apply gravity in z-direction

//Cast a short-range ray from the previous position to the current position to avoid going through geometry
if (sqr(x - prevX) + sqr(y - prevY) + sqr(z - prevZ) > radius * radius) //Only cast ray if there's a risk that we've gone through geometry
{
	var d = height * (.5 +0.5 * sign(xup * (x - prevX) + yup * (y - prevY) + zup * (z - prevZ)));
	var dx = xup * d;
	var dy = yup * d;
	var dz = zup * d;
	ray = global.room_colmesh.cast_ray_ext(prevX + dx, prevY + dy, prevZ + dz, x + dx, y + dy, z + dz);
	if is_struct(ray) {
		x = ray.x - dx - (x - prevX) * .1;
		y = ray.y - dy - (y - prevY) * .1;
		z = ray.z - dz - (z - prevZ) * .1;
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

//Put player back on the map if he falls off
if (z < -1000)
{
	x = xstart;
	y = ystart;
	z = 200;
	prevX = x;
	prevY = y;
	prevZ = z;
}

//Update character matrix
charMat[12] = x;
charMat[13] = y;
charMat[14] = z;
charMat[0] += spdX * .1;
charMat[1] += spdY * .1;
charMat[2] += spdZ * .1;
charMat[8] += (0 - charMat[8]) * .1;
charMat[9] += (0 - charMat[9]) * .1;
charMat[10] += (1 - charMat[10]) * .1;
colmesh_matrix_orthogonalize(charMat);

var d = 150;
global.camX = x + d * dcos(yaw) * dcos(pitch);
global.camY = y + d * dsin(yaw) * dcos(pitch);
global.camZ = z + d * dsin(pitch);
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, x, y, z, xup, yup, zup));