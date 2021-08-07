/// @description
xsize = 128;
ysize = 32;
zsize = 10;
z = 0;
matrix = matrix_build(x, y, z, 0, 0, 0, 1, 1, 1);
shape = global.room_colmesh.add_dynamic(new ColmeshBlock(matrix_build(0, 0, 0, 0, 0, 0, xsize, ysize, zsize)), matrix);