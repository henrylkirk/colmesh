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
  global.camX + v[0] * 3000,
  global.camY + v[1] * 3000,
  global.camZ + v[2] * 3000
);
colmesh_debug_draw_sphere(ray.x, ray.y, ray.z, 5, c_red);

//Execute ray functions for the objects the ray hits. In this demo it makes the objects change colour
ray.executeRayFunc();

if (global.disableDraw) {
  exit;
}

event_inherited();

//Draw ground
shader_set(sh_colmesh_collider);
shader_set_lightdir(sh_colmesh_collider);
shader_reset();

//Draw debug collision shapes

if (global.drawDebug) {
  matrix_set(matrix_world, matrix_build_identity());
  var r = radius * 1.1;
  levelColmesh.debugDraw(
    levelColmesh.getRegion([x - r, y - r, z - r, x + r, y + r, z + height + r])
  );
}
