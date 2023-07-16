/// @description
xsize = 128;
ysize = 32;
zsize = 10;
z = 0;
M = matrix_build(x, y, z, 0, 0, 0, 1, 1, 1);
shape = levelColmesh.addDynamic(
  new colmesh_block(matrix_build(0, 0, 0, 0, 0, 0, xsize, ysize, zsize)),
  M
);

colour = [0.2, 0.7, 0.6];

//Create a ray function for this shape, changing the colour of the object if it is hit by a ray
colFunc = function () {
  colour = [0.5, 1, 0.2];
};

shape.setTrigger(true, colFunc);
