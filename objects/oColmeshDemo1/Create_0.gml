/// @description
event_inherited();

global.demoText = ("This demo shows how you can create a ColMesh from an OBJ file!" +
"\nIt also shows how you can push the player out of the ColMesh,") +
"\nand how you can use the collision system to collect coins";

// Load the level model to a vertex buffer
var mbuffLevel = colmesh_load_obj_to_buffer("ColMesh Demo/Demo1Level.obj");
modLevel = vertex_create_buffer_from_buffer(mbuffLevel, global.ColMeshFormat);
buffer_delete(mbuffLevel);

/*
	levelColmesh is a global variable in these demos.
	Instead of deleting and creating it over and over, the levelColmesh is simply cleared
	whenever you switch rooms.
	oColmeshSystem controls the levelColmesh, and makes sure it's cleared.
*/
// First check if a cached ColMesh exists
if (!levelColmesh.load("Demo1Cache.cm")) {
    // If a cache does not exist, generate a colmesh from an OBJ file, subdivide it, and save a cache
    var mesh = levelColmesh.addMesh("ColMesh Demo/Demo1Level.obj"); // Notice how I supply a path to an OBJ file. I could have instead used the mbuffLevel that I created earlier in this event
    levelColmesh.subdivide(100); // <-- You need to define the size of the subdivision regions. Play around with it and see what value fits your model best. This is a list that stores all the triangles in a region in space. A larger value makes colmesh generation faster, but slows down collision detection. A too low value increases memory usage and generation time.
    levelColmesh.save("Demo1Cache.cm", false); // Save a cache, so that loading it the next time will be quicker
}

// Player variables
z = 200;
radius = 15;
height = 30;
spdX = 0;
spdY = 0;
spdZ = 0;
ground = false;
collider = new colmesh_collider_capsule(x, y, z, 0, 0, 1, radius, height, 40, 3, cmGroupSolid | cmGroupColTrigger);

// Create a bunch of coins around the level
repeat (30) {
    xx = random_range(-800, 800);
    yy = random_range(-800, 800);
    instance_create_depth(xx, yy, 0, oCoin);
}

// Enable 3D projection
view_enabled = true;
view_visible[0] = true;
view_camera[0] = camera_create();
gpu_set_ztestenable(true);
gpu_set_zwriteenable(true);
camera_set_proj_mat(
    view_camera[0],
    matrix_build_projection_perspective_fov(-80, -window_get_width() / window_get_height(), 1, 32000)
);
yaw = 0;
pitch = 45;
