/// @description
if global.disableDraw{exit;}
if global.drawDebug{exit;}
gpu_set_cullmode(cull_counterclockwise)
matrix_set(matrix_world, M);
vertex_submit(global.modTree, pr_trianglelist, sprite_get_texture(texSmallTree, 0));
matrix_set(matrix_world, matrix_build_identity());