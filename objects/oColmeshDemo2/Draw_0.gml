/// @description
if global.disableDraw{exit;}


event_inherited();

//Draw ground
shader_set(sh_colmesh_collider);
shader_set_lightdir(sh_colmesh_collider);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_color"), .4, .6, .3);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_radius"), 0);
block.debugDraw(-1);
shader_reset();

//Cast a ray in the looking direction of the player
var xx = x + charMat[0] * 2000;
var yy = y + charMat[1] * 2000;
var zz = z - radius - 5 + charMat[2] * 2000;
var ray = levelColmesh.castRay(x, y, z + height, xx, yy, zz, true);
if (is_struct(ray))
{
	xx = ray.x;
	yy = ray.y;
	zz = ray.z;
}
var dx = xx - x;
var dy = yy - y;
var dz = zz - z - height;
var l = sqrt(dx * dx + dy * dy + dz * dz);
colmesh_debug_draw_capsule(x, y, z + height, dx, dy, dz, 1, l, c_red);
colmesh_debug_draw_sphere(xx, yy, zz, 5, c_red);

//Draw debug collision shapes
if global.drawDebug
{
	var r = radius * 1.1;
	levelColmesh.debugDraw(levelColmesh.getRegion([x - r, y - r, z - r, x + r, y + r, z + height + r]), false);
}