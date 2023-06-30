/// @description
size = 64;
z = -200;
M = matrix_build(x, y, z, 0, 0, current_time / 50, 1, 1, 1);

subMesh = new colmesh();

//subMesh.addShape(new colmesh_block(matrix_build(0, 0, 0, 0, 0, 0, 300, 300, 40)));
subMesh.addShape(new colmesh_disk(0, 0, 0, 0, 0, 1, 300, 50));


cube = subMesh.addDynamic(new colmesh_cube(45, 0, 100, 100, 100, 100), matrix_build_identity());

shape = levelColmesh.addDynamic(subMesh, M);
subMesh.subdivide(300);