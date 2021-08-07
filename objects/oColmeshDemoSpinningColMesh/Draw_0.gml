/// @description
if global.disableDraw{exit;}

matrix_set(matrix_world, matrix);
gpu_set_texfilter(true);
shader_set(sh_colmesh_world);
global.shader_set_lightdir(sh_colmesh_world);
subMesh.debug_draw(-1, sprite_get_texture(texCollider, 0));
shader_reset();
matrix_set(matrix_world, matrix_build_identity());