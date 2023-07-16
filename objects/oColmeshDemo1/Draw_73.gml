/// @description

if (global.disableDraw) {
  exit;
}

//Draw player shadow
colmeshdemo_draw_circular_shadow(x, y, z, 0, 0, 1, radius, 200, 0.5);

//Draw player
colmesh_debug_draw_capsule(
  x,
  y,
  z,
  0,
  0,
  1,
  radius,
  height,
  make_colour_rgb(110, 127, 200)
);

//Draw water
draw_sprite_ext(sWater, 0, 0, 0, 33, 33, 0, c_white, 0.4);
