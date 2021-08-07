/// @description
size = 64;
z = -200;
matrix = matrix_build(x, y, z, 0, 0, current_time / 50, 1, 1, 1);

subMesh = new Colmesh();

shape = global.room_colmesh.add_dynamic(subMesh, matrix);

subMesh.add_shape(new ColmeshBlock(matrix_build(0, 0, 0, 0, 0, 0, 300, 300, 40)));
cube = subMesh.add_dynamic(new ColmeshCube(45, 0, 100, 100, 100, 100), matrix_build_identity());
subMesh.subdivide(150);

//Load the level model as a buffer, and convert it to a vertex buffer
var mbuffLevel = colmesh_load_obj_to_buffer("Corona.obj");
model = vertex_create_buffer_from_buffer(mbuffLevel, global.ColMeshFormat);
buffer_delete(mbuffLevel);