/// @description
event_inherited();

global.demoText =	"You can also use dynamics to add multiple copies of a single mesh to a colmesh."
					+"\nMeshes added this way are added by reference, instead of being copied triangle by triangle."
					+"\nThese can then be translated, rotated and scaled (uniformly) to your liking";

/*
	levelColmesh is a global variable in these demos.
	Instead of deleting and creating it over and over, the levelColmesh is simply cleared
	whenever you switch rooms.
	oColmeshParent controls the levelColmesh, and makes sure it's cleared.
*/
var regionSize = 100; //<-- You need to define the size of the subdivision regions. Play around with it and see what value fits your model best. This is a list that stores all the triangles in a region in space. A larger value makes colmesh generation faster, but slows down collision detection. A too low value increases memory usage and generation time.
levelColmesh.subdivide(100);

//Create base platform
//block = levelColmesh.addShape(new colmesh_block(matrix_build(99000 / 2, 99000 / 2, -50, 0, 0, 0, 99000 / 2, 99000 / 2, 50)));

//Load high-poly tree model
var mbuff = colmesh_load_obj_to_buffer("ColMesh Demo/SmallTreeHighPoly.obj");
global.modTree = vertex_create_buffer_from_buffer(mbuff, global.ColMeshFormat);
buffer_delete(mbuff);

//Load low-poly tree model for collisions
levelColmesh.treeMesh = new colmesh_mesh("SmallTree", "ColMesh Demo/SmallTreeLowPoly.obj", undefined, cmGroupSolid);
levelColmesh.treeColMesh = new colmesh();
levelColmesh.treeColMesh.addMesh(levelColmesh.treeMesh);
levelColmesh.treeColMesh.subdivide(regionSize / 30);


//Add trees to the level colmesh
repeat 40
{
	var xx = random(9900);
	var yy = random(9900);
	
	instance_create_depth(xx, yy, 0, oColmeshDemo5Tree);
}

levelColmesh.addTriangle([0, 0, 0, 100, 100, 100, 100, -100, 100]);

col = -1;
//Player variables
z = 200;
radius = 15;
height = 40;
spdX = 0;
spdY = 0;
spdZ = 0;
prevX = x;
prevY = y;
prevZ = z;
xup = 0;
yup = 0;
zup = 1;
ground = false;
charMat = matrix_build(x, y, z, 0, 0, 0, 1, 1, height);

//Enable 3D projection
view_enabled = true;
view_visible[0] = true;
view_set_camera(0, camera_create());
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
camera_set_proj_mat(view_camera[0], matrix_build_projection_perspective_fov(-80, -window_get_width() / window_get_height(), 1, 32000));
yaw = 90;
pitch = 30;

col = -1;