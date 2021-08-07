/// @description
size = 64;
z = size / 2;
shape = global.room_colmesh.add_shape(new ColmeshCube(x, y, z, size, size, size));
matrix = matrix_build(shape.x, shape.y, shape.z, 0, 0, 0, shape.halfW, shape.halfL, shape.halfH);