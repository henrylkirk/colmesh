/// @description
size = 64;
z = size * 0.5;
M = matrix_build(x, y, z, 0, 0, current_time / 50, 1, 1, 1);
shape = levelColmesh.addDynamic(new colmesh_cylinder(0, 0, 0, 0, 0, 1, size, size / 10), M);
