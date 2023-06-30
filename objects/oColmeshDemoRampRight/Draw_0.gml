/// @description
if global.disableDraw{exit;}
shader_set(sh_colmesh_collider);
shader_set_uniform_f(shader_get_uniform(sh_colmesh_collider, "u_color"), .4, .5, .8);
shape.debugDraw(sprite_get_texture(texCollider, 0));
shader_reset();