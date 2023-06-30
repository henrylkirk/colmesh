/// @description
event_inherited();

global.demoText = "There is one more type of shape you can add - the \"dynamic\"."
	+ "\nA dynamic shape can be moved in real time. It can contain any of the primitives,"
	+ "\nor even a whole different ColMesh! Yes, that's right, you can put a ColMesh inside a ColMesh!"
	+ "\nThe red boxes in the distance are part of a separate ColMesh inside the level ColMesh."
	+ "\nThe small red box in the middle is moving within its parent ColMesh, while that ColMesh is moving"
	+ "\naround in the level ColMesh. In short - we've got some pretty complex movement going on!";

/*
	levelColmesh is a global variable in these demos.
	Instead of deleting and creating it over and over, the levelColmesh is simply cleared
	whenever you switch rooms.
	oColmeshParent controls the levelColmesh, and makes sure it's cleared.
*/
var regionSize = 300; //<-- You need to define the size of the subdivision regions. Play around with it and see what value fits your model best. This is a list that stores all the triangles in a region in space. A larger value makes colmesh generation faster, but slows down collision detection. A too low value increases memory usage and generation time.
levelColmesh.subdivide(regionSize);

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
pitch = 45;

col = -1;