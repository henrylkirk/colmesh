/// @description
if global.disableDraw{exit;}

event_inherited();

// Draw the house
matrix_set(matrix_world, matrix_build(house_x, house_y, house_z, 0, 0, 0, 10, 10, 10));
shader_set(sh_colmesh_world);
//global.shader_set_lightdir(sh_colmesh_world);
vertex_submit(house, pr_trianglelist, sprite_get_texture(spr_texture_house, 0));
shader_reset();
matrix_set(matrix_world, matrix_build_identity());

//Draw debug collision shapes
if global.drawDebug {
	global.levelColmesh.debugDraw(global.levelColmesh.getRegion(x, y, z, xup, yup, zup, radius, height), false);
}