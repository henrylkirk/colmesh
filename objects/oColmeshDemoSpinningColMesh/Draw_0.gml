/// @description
if global.disableDraw{exit;}
gpu_set_texrepeat(true);
shader_set(sh_colmesh_collider);
shape.debugDraw(sprite_get_texture(texCollider, 0));
shader_reset();

/*
var mm = shape.getMinMax();
var M = matrix_build(x, y, z, 0, 0, 0, (mm[3] - mm[0]) / 2, (mm[4] - mm[1]) / 2, (mm[5] - mm[2]) / 2);
colmesh_debug_draw_block(M, c_white)