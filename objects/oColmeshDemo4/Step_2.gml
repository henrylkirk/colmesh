/// @description

// Verlet integration
fric = 1 - 0.4;
spdX = (x - prevX) * fric;
spdY = (y - prevY) * fric;
spdZ = (z - prevZ) * (1 - 0.01);

prevX = x;
prevY = y;
prevZ = z;

// Controls
var jump = keyboard_check_pressed(vk_space);
var h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var v = keyboard_check(ord("W")) - keyboard_check(ord("S"));

if ((h != 0) and (v != 0)) {
    // If walking diagonally, divide the input vector by its own length
    var s = 1 / sqrt(2);
    h *= s;
    v *= s;
}

// Move
acc = 2;
x += spdX + (acc * h);
y += spdY - (acc * v);
z += (spdZ - 1) + ((jump * ground) * 15); // Apply gravity in z-direction

// Cast a short-range ray from the previous position to the current position to avoid going through geometry

if (point_distance_3d(x, y, z, prevX, prevY, prevZ) > radius) {
    var d = height * (0.5 + (0.5 * sign(((xup * (x - prevX)) + (yup * (y - prevY))) + (zup * (z - prevZ)))));
    var dx = xup * d;
    var dy = yup * d;
    var dz = zup * d;
    var ray = levelColmesh.castRay(prevX + dx, prevY + dy, prevZ + dz, x + dx, y + dy, z + dz);

    if (ray.hit) {
        x = (ray.x - dx) - ((x - prevX) * 0.1);
        y = (ray.y - dy) - ((y - prevY) * 0.1);
        z = (ray.z - dz) - ((z - prevZ) * 0.1);
    }
}

if (is_struct(col)) {
    var D = col.getDeltaMatrix();

    if (is_array(D)) {
        charMat[12] = x;
        charMat[13] = y;
        charMat[14] = z;
        charMat = matrix_multiply(charMat, D);
        x = charMat[12];
        y = charMat[13];
        z = charMat[14];

        var V = matrix_transform_vertex(D, prevX, prevY, prevZ);
        prevX = V[0];
        prevY = V[1];
        prevZ = V[2];
    }
}

// Avoid ground
col = levelColmesh.displaceCapsule(x, y, z, xup, yup, zup, radius, height, 46, false, false);
x = col.x;
y = col.y;
z = col.z;
ground = col.ground;

// Put player back on the map if he falls off

if (z < -1000) {
    x = xstart;
    y = ystart;
    z = 200;
    prevX = x;
    prevY = y;
    prevZ = z;
}

// Update character matrix
charMat[12] = x;
charMat[13] = y;
charMat[14] = z;
charMat[0] += spdX * 0.1;
charMat[1] += spdY * 0.1;
charMat[2] += spdZ * 0.1;
charMat[8] += (0 - charMat[8]) * 0.1;
charMat[9] += (0 - charMat[9]) * 0.1;
charMat[10] += (1 - charMat[10]) * 0.1;
colmesh_matrix_orthogonalize(charMat);

var d = 150;
global.camX = x + ((d * dcos(yaw)) * dcos(pitch));
global.camY = y + ((d * dsin(yaw)) * dcos(pitch));
global.camZ = z + (d * dsin(pitch));
camera_set_view_mat(view_camera[0], matrix_build_lookat(global.camX, global.camY, global.camZ, x, y, z, xup, yup, zup));
