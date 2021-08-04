/// @description
event_inherited();

global.demo_text = "You can combine triangle meshes and primitives into one ColMesh."
	+ "\nUse this to your advantage! In this demo, for example, the red shapes are"
	+ "\npart of a triangle mesh, while the central sphere is a primitive"
	+ "\nCollision checking against a primitive is much faster than against a triangle mesh!";

//Load the level model as a buffer, and convert it to a vertex buffer
var mbuffLevel = colmesh_load_obj_to_buffer("Corona.obj");
modLevel = vertex_create_buffer_from_buffer(mbuffLevel, global.ColMeshFormat);
buffer_delete(mbuffLevel);

/*
	global.room_colmesh is a global variable in these demos.
	Instead of deleting and creating it over and over, the global.room_colmesh is simply cleared
	whenever you switch rooms.
	oColmeshSystem controls the global.room_colmesh, and makes sure it's cleared.
*/

// First check if a cached ColMesh exists
if (!global.room_colmesh.load("Demo3Cache.cm")) {
	//If a cache does not exist, generate a colmesh from an OBJ file, subdivide it, and save a cache
	global.room_colmesh.add_mesh("CoronaColmesh.obj"); //Notice how I supply a path to an OBJ file. I could have instead used the mbuffLevel that I created earlier in this event
	global.room_colmesh.add_shape(new colmesh_sphere(0, 0, 0, 400));
	global.room_colmesh.subdivide(100);
	global.room_colmesh.save("Demo3Cache.cm"); //Save a cache, so that loading it the next time will be quicker
}

// Player variables
x = 0;
y = 0;
z = 500;
radius = 15;
height = 20;
prevX = x;
prevY = y;
prevZ = z;
ground = false;
xup = 0;
yup = 0;
zup = 1;

//Enable 3D projection
view_enabled = true;
view_visible[0] = true;
view_set_camera(0, camera_create());
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
camera_set_proj_mat(view_camera[0], matrix_build_projection_perspective_fov(-80, -window_get_width() / window_get_height(), 1, 32000));
pitch = 45;

//The character matrix stores the player's world matrix so that it looks in the direction it's moving
charMat = matrix_build(x, y, z, 0, 0, 0, 1, 1, 1);

//The camera matrix stores the camera's orientation around the player
camMat = matrix_build(x, y, z, 0, 0, 0, 1, 1, 1);