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

#macro TILE_SIZE 16
var hw = room_width * 0.5;
var hh = room_height * 0.5;

//First check if a cached ColMesh exists
//if (!global.levelColmesh.load("Demo5Cache.cm")){
	// No cache found, add flat ground to colmesh
	global.levelColmesh.addShape(
		new colmesh_block(colmesh_matrix_build(hw, hh, 0, 0, 0, 0, hw, hh, 1))
	);
//	global.levelColmesh.save("Demo5Cache.cm"); //Save a cache, so that loading it the next time will be quicker
//}

tile_manager = new TileManager(TILE_SIZE);
tile_manager.add_colmesh_at_grid(global.levelColmesh, eTileType.wedge_skinny_hor_tl, 0, 0, 0);
tile_manager.add_colmesh_at_grid(global.levelColmesh, eTileType.wedge_skinny_hor_tr, 1, 0, 0);
tile_manager.add_colmesh_at_grid(global.levelColmesh, eTileType.wedge_skinny_hor_bl, 0, 1, 0);
tile_manager.add_colmesh_at_grid(global.levelColmesh, eTileType.wedge_skinny_hor_br, 1, 1, 0);

// Add test cube - TODO add tile conversion here
//var h_tile_size = TILE_SIZE * 0.5; // half a tile
//global.levelColmesh.addShape(
//	new colmesh_cube(h_tile_size, h_tile_size, h_tile_size, TILE_SIZE, TILE_SIZE, TILE_SIZE)
//);


//// Add wedge
//global.levelColmesh.addMesh("wedge.obj", matrix_build(h_tile_size + TILE_SIZE, h_tile_size, h_tile_size, 0, 0, 0, TILE_SIZE, TILE_SIZE, TILE_SIZE));

//// Add wedge with flat bit
//global.levelColmesh.addMesh("wedge-flat.obj", matrix_build(h_tile_size + TILE_SIZE*2, h_tile_size, h_tile_size, 90, 0, 0, TILE_SIZE, TILE_SIZE, TILE_SIZE));

//// Add small wedge
//global.levelColmesh.addMesh("wedge.obj", matrix_build(h_tile_size * 0.5 + TILE_SIZE*3, h_tile_size * 0.5, h_tile_size, 180, 90, 90, h_tile_size, h_tile_size, TILE_SIZE));


//Player variables
x = hw;
y = hh;
z = 300;
radius = 15;
height = 20;
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