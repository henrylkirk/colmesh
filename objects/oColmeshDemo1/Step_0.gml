// Verlet integration
// Controls
jump = keyboard_check_pressed(vk_space);
var h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var v = keyboard_check(ord("W")) - keyboard_check(ord("S"));

if ((h != 0) and (v != 0)) {
    // If walking diagonally, make sure the total length of the vector is still 1
    var s = 0.707107; // This is approximately equal to 1 / sqrt(2);
    h *= s;
    v *= s;
}

// Move the collider
hfric = 0.65;
vfric = 0.95;
acc = 2;
collider.x += (spdX * hfric) - (acc * v);
collider.y += (spdY * hfric) - (acc * h);
collider.z += ((spdZ * vfric) - 1) + ((jump * ground) * 30); // Apply gravity in z-direction

// Cast a ray from the previous position to the next
var dz = height * (collider.z > z);
var ray = levelColmesh.castRay(x, y, z + dz, collider.x, collider.y, collider.z + dz);

if (ray.hit) {
    collider.x = ray.x + ray.nx;
    collider.y = ray.y + ray.ny;
    collider.z = (ray.z + ray.nz) - dz;
}

// Avoid ground
collider.avoid(levelColmesh);
ground = collider.ground;

// Execute collision functions
collider.executeColFunc();

// Find speed vector
spdX = collider.x - x;
spdY = collider.y - y;
spdZ = collider.z - z;
spd = point_distance_3d(0, 0, 0, spdX, spdY, spdZ);

// Put player in the middle of the map if he falls off

if (collider.z < -400) {
    collider.x = room_width * 0.5;
    collider.y = room_height * 0.5;
    collider.z = 200;
}

// Copy collider info over to player
x = collider.x;
y = collider.y;
z = collider.z;

var d = 150;
global.camX = x + ((d * dcos(yaw)) * dcos(pitch));
global.camY = y + ((d * dsin(yaw)) * dcos(pitch));
global.camZ = z + (d * dsin(pitch));

camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, x, y, z, 0, 0, 1));
