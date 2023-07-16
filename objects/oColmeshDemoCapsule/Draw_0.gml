/// @description

if (global.disableDraw) {
  exit;
}
shader_set(sh_colmesh_collider);
shader_set_uniform_f(
  shader_get_uniform(sh_colmesh_collider, "u_color"),
  colour[0],
  colour[1],
  colour[2]
);
shape.debugDraw(sprite_get_texture(texCollider, 0));
shader_reset();

colour = [0.2, 0.7, 0.6];
