/// @description
if global.disableDraw{exit;}

//Draw player shadow
global.colmeshdemo_draw_circular_shadow(x, y, z, xup, yup, zup, radius, 200, .5);

//Draw player
colmesh_debug_draw_capsule(x, y, z, xup, yup, zup, radius, height, make_colour_rgb(110, 127, 200));

//Draw water
//draw_sprite_ext(sWater, 0, 0, 0, 33, 33, 0, c_white, .4);

//Draw player shadow
global.colmeshdemo_draw_circular_shadow(room_width/2, room_height/2, 50, xup, yup, zup, radius, 200, .5);

//Draw player
colmesh_debug_draw_capsule(room_width/2, room_height/2, 50, xup, yup, zup, radius, height, make_colour_rgb(110, 127, 200));