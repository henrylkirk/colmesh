/// @description
size = 64;
z = size / 2;
colour = [.4, .5, .8];
	
//Create a ray function for this shape, changing the colour of the object if it is hit by a ray
rayFunc = function()
{
	colour = [1, .5, .2];
	return true;			//Return true so that the ray stops when it hits this shape
}

shape = levelColmesh.addTrigger(new colmesh_cube(x, y, z, size, size, size), true, undefined, rayFunc);
M = matrix_build(shape.x, shape.y, shape.z, 0, 0, 0, shape.halfX, shape.halfY, shape.halfZ);