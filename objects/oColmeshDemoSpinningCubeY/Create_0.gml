/// @description
size = 64;
z = size / 2;
matrix = matrix_build(x, y, z, 0, current_time / 50, 0, 1, 1, 1);
shape = global.room_colmesh.add_dynamic(new ColmeshCube(0, 0, 0, size, size, size), matrix);