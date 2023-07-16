/// @description
//Cast a ray along the mouse vector
var v = colmesh_convert_2d_to_3d(
  view_camera[0],
  window_mouse_get_x(),
  window_mouse_get_y()
);
var ray = levelColmesh.castRay(
  global.camX,
  global.camY,
  global.camZ,
  global.camX + v[0] * 1000,
  global.camY + v[1] * 1000,
  global.camZ + v[2] * 1000
);
colmesh_debug_draw_sphere(ray.x, ray.y, ray.z, 5, c_red);

if (global.disableDraw) {
  exit;
}

event_inherited();

//Draw ground
shader_set(sh_colmesh_collider);
shader_set_lightdir(sh_colmesh_collider);
shader_set_uniform_f(
  shader_get_uniform(sh_colmesh_collider, "u_color"),
  0.4,
  0.6,
  0.3
);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_radius"), 0);
//block.debugDraw(-1);
shader_reset();

//Draw debug collision shapes

if (global.drawDebug) {
  matrix_set(matrix_world, matrix_build_identity());
  var r = radius * 1.1;
  levelColmesh.debugDraw(
    levelColmesh.getRegion([x - r, y - r, z - r, x + r, y + r, z + height + r])
  );
  matrix_set(matrix_world, matrix_build_identity());
}
