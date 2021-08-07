/// @description
event_inherited();

global.demo_text = "This demo shows how you can create a Colmesh from an OBJ file!"
	+ "\nIt also shows how you can push the player out of the Colmesh,"
	+ "\nand how you can use the collision system to collect coins";
	
//Load the level model to a vertex buffer
var mbuffLevel = colmesh_load_obj_to_buffer("Demo1Level.obj");
modLevel = vertex_create_buffer_from_buffer(mbuffLevel, global.ColMeshFormat);
buffer_delete(mbuffLevel);

/*
	global.room_colmesh is a global variable in these demos.
	Instead of deleting and creating it over and over, the global.room_colmesh is simply cleared
	whenever you switch rooms.
	oColmeshSystem controls the global.room_colmesh, and makes sure it's cleared.
*/
//First check if a cached Colmesh exists
if (!global.room_colmesh.load("Demo1Cache.cm")) {
	//If a cache does not exist, generate a Colmesh from an OBJ file, subdivide it, and save a cache
	global.room_colmesh.add_mesh("Demo1Level.obj"); //Notice how I supply a path to an OBJ file. I could have instead used the mbuffLevel that I created earlier in this event
	global.room_colmesh.subdivide(100); //<-- You need to define the size of the subdivision regions. Play around with it and see what value fits your model best. This is a list that stores all the triangles in a region in space. A larger value makes Colmesh generation faster, but slows down collision detection. A too low value increases memory usage and generation time.
	global.room_colmesh.save("Demo1Cache.cm"); //Save a cache, so that loading it the next time will be quicker
}

// Player variables
x = 0;
y = 0;
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

//Create a bunch of coins around the level
repeat 30 {
	xx = random_range(-800, 800);	
	yy = random_range(-800, 800);	
	instance_create_depth(xx, yy, 0, oCoin);
}

//Enable 3D projection
view_enabled = true;
view_visible[0] = true;
view_camera[0] = camera_create();
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
camera_set_proj_mat(view_camera[0], matrix_build_projection_perspective_fov(-80, -window_get_width() / window_get_height(), 1, 32000));
yaw = 0;
pitch = 45;