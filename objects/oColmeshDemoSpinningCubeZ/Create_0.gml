/// @description
size = 64;
z = size / 2;
M = matrix_build(x, y, z, 0, 0, current_time / 50, 1, 1, 1);
shape = global.room_colmesh.add_dynamic(new colmesh_cube(0, 0, 0, size, size, size), M);