/// @description
z = random(100);
colour = [.2, .7, .6];
	
//Create a ray function for this shape, changing the colour of the object if it is hit by a ray
rayFunc = function()
{
	colour = [1, .5, .2];	//Set the colour when a ray hits the object
	return true;			//Return true so that the ray stops when it hits this shape
}

shape = levelColmesh.addTrigger(new colmesh_sphere(x, y, z, 30 + random(100)), true, undefined, rayFunc);