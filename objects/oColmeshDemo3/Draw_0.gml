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

// Draw the level
gpu_set_texfilter(true);
shader_set(sh_colmesh_world);
shader_set_lightdir(sh_colmesh_world);
vertex_submit(modLevel, pr_trianglelist, sprite_get_texture(texCorona, 0));
shader_reset();

// Draw debug collision shapes

if (global.drawDebug) {
    levelColmesh
        .debugDraw(levelColmesh.getRegion(colmesh_capsule_get_AABB(x, y, z, xup, yup, zup, radius * 1.1, height)));
}
