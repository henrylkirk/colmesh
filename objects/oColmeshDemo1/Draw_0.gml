/// @description
if global.disableDraw{exit;}

event_inherited();

gpu_set_cullmode(cull_noculling)
//Draw the level
shader_set(sh_colmesh_world);
global.shader_set_lightdir(sh_colmesh_world);
vertex_submit(modLevel, pr_trianglelist, sprite_get_texture(ImphenziaPalette01, 0));
matrix_set(matrix_world, matrix_build_identity());

//Draw debug collision shapes
if global.drawDebug
{
	global.room_colmesh.debug_draw(global.room_colmesh.get_region(x, y, z, xup, yup, zup, radius, height), false);
}