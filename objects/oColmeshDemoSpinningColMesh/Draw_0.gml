/// @description
if global.disableDraw{exit;}
shader_set(sh_colmesh_collider);
shape.debugDraw();
shader_reset();