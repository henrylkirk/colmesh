/// @description
if global.disableDraw{exit;}
shader_set(sh_colmesh_collider);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_radius"), 0);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_color"), .4,0.5, .8);
matrix_set(matrix_world, matrix);
vertex_submit(global.modBlock, pr_trianglelist, sprite_get_texture(texCollider, 0));
matrix_set(matrix_world, matrix_build_identity());
shader_reset();