/// @description
matrix_set(matrix_world, matrix_build_identity());

// Cast a ray along the mouse vector
var v = colmesh_convert_2d_to_3d(view_camera[0], window_mouse_get_x(), window_mouse_get_y());
var ray = levelColmesh
    .castRay(
    global.camX,
    global.camY,
    global.camZ,
    global.camX + (v[0] * 1000),
    global.camY + (v[1] * 1000),
    global.camZ + (v[2] * 1000)
);
colmesh_debug_draw_sphere(ray.x, ray.y, ray.z, 5, c_red);
colmesh_debug_draw_sphere(ray.x + (ray.nx * 5), ray.y + (ray.ny * 5), ray.z + (ray.nz * 5), 5, c_red);

if (global.disableDraw) {
    exit;
}

event_inherited();

gpu_set_cullmode(cull_noculling);

// Draw the level
shader_set(sh_colmesh_world);
shader_set_lightdir(sh_colmesh_world);
vertex_submit(modLevel, pr_trianglelist, sprite_get_texture(ImphenziaPalette01, 0));
matrix_set(matrix_world, matrix_build_identity());

// Draw debug collision shapes

if (global.drawDebug) {
    var r = radius * 1.1;
    levelColmesh.debugDraw(levelColmesh.getRegion([x - r, y - r, z - r, x + r, y + r, (z + height) + r]), -1);
}
