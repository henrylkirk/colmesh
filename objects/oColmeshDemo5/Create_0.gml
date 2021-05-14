/// @description
event_inherited();

global.demoText = "This demo shows how you can create a ColMesh from an OBJ file!"
	+ "\nIt also shows how you can push the player out of the ColMesh,"
	+ "\nand how you can use the collision system to collect coins";
	
//Load the level model to a vertex buffer
//var mbuffLevel = colmesh_load_obj_to_buffer("Demo1Level.obj");
//modLevel = vertex_create_buffer_from_buffer(mbuffLevel, global.ColMeshFormat);
//buffer_delete(mbuffLevel);

/*
	global.levelColmesh is a global variable in these demos.
	Instead of deleting and creating it over and over, the global.levelColmesh is simply cleared
	whenever you switch rooms.
	oColmeshSystem controls the global.levelColmesh, and makes sure it's cleared.
*/

gpu_set_cullmode(cull_noculling);
gpu_set_texfilter(true);

//Load the level model to a vertex buffer
var mbuffLevel = colmesh_load_obj_to_buffer("house.obj");
house = vertex_create_buffer_from_buffer(mbuffLevel, global.ColMeshFormat);
buffer_delete(mbuffLevel);

#macro TILE_SIZE 16
var hw = room_width * 0.5;
var hh = room_height * 0.5;

//First check if a cached ColMesh exists
//if (!global.levelColmesh.load("Demo5Cache.cm")){
	// No cache found, add flat ground to colmesh
	global.levelColmesh.addShape(
		new colmesh_block(colmesh_matrix_build(hw, hh, -1, 0, 0, 0, hw, hh, 1))
	);
//	global.levelColmesh.save("Demo5Cache.cm"); //Save a cache, so that loading it the next time will be quicker
//}

house_x = hw;
house_y = hh;
house_z = 1;
house_mesh = global.levelColmesh.addMesh(
	"house.obj",
	colmesh_matrix_build(house_x, house_y, house_z, 0, 0, 0, 10, 10, 10)
);

// Add tile shapes to colmesh
tile_manager = new TileManager(TILE_SIZE);
tile_manager.tile_layer_to_colmesh(global.levelColmesh, "tiles_collision");

// Player variables
x = hw;
y = hh;
z = 300;
radius = 10;
height = 16;
prevX = x;
prevY = y;
prevZ = z;
ground = false;
xup = 0;
yup = 0;
zup = 1;

// Enable 3D projection
view_enabled = true;
view_visible[0] = true;
view_camera[0] = camera_create();
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
camera_set_proj_mat(view_camera[0], matrix_build_projection_perspective_fov(-90, -window_get_width() / window_get_height(), 1, 32000));
yaw = 90;
pitch = 45;