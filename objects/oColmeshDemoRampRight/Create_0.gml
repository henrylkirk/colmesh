/// @description
size = 64;
z = size * 0.5;
var h = size;
var s = sqrt(2);
shape = levelColmesh
    .addShape(new colmesh_block(colmesh_matrix_build(x + (h / s), y, z - (h / s), 0, 45, 0, size / s, size * 0.5, h)));
