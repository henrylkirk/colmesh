/// @description
// Cast a ray along the mouse vector
var v = colmesh_convert_2d_to_3d(view_camera[0], window_mouse_get_x(), window_mouse_get_y());
var ray = levelColmesh
    .castRay(
    global.camX,
    global.camY,
    global.camZ,
    global.camX + (v[0] * 3000),
    global.camY + (v[1] * 3000),
    global.camZ + (v[2] * 3000)
);
colmesh_debug_draw_sphere(ray.x, ray.y, ray.z, 5, c_red);

if (global.disableDraw) {
    exit;
}

event_inherited();

// Draw ground
shader_set(sh_colmesh_collider);
shader_set_lightdir(sh_colmesh_collider);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_color"), 0.4, 0.6, 0.3);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_radius"), 0);
block.debugDraw(-1);
shader_reset();

// Cast a ray in the looking direction of the player
var xx = x + (charMat[0] * 2000);
var yy = y + (charMat[1] * 2000);
var zz = ((z - radius) - 5) + (charMat[2] * 2000);
var ray = levelColmesh.castRay(x, y, z + height, xx, yy, zz, true);

if (is_struct(ray)) {
    xx = ray.x;
    yy = ray.y;
    zz = ray.z;
}
var dx = xx - x;
var dy = yy - y;
var dz = (zz - z) - height;
var l = sqrt(((dx * dx) + (dy * dy)) + (dz * dz));
colmesh_debug_draw_capsule(x, y, z + height, dx, dy, dz, 1, l, c_red);
colmesh_debug_draw_sphere(xx, yy, zz, 5, c_red);

// Draw debug collision shapes

if (global.drawDebug) {
    var r = radius * 1.1;
    levelColmesh.debugDraw(levelColmesh.getRegion([x - r, y - r, z - r, x + r, y + r, (z + height) + r]), -1);
}
