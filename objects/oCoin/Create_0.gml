/// @description

//Cast a ray from high above to the ground so that the coin is placed onto the ground
var ray = global.room_colmesh.cast_ray_ext(x, y, 1000, x, y, -100);
if (!is_array(ray))
{
	//The ray didn't hit anything, for some reason. Destroy this coin.
	instance_destroy();
	exit;
}
radius = 10;
z = ray[2] + radius;
zstart = z;

//Create a collision function for the coin, telling it to destroy itself and remove its shape from the level ColMesh
col_func = function()
{
	global.coins ++;					 //Increment the global variable "coins"
	instance_destroy();					 //This will destroy the current instance of oCoin
	global.room_colmesh.remove_shape(shape);	 //"shape" is oCoin's shape variable. Remove it from the ColMesh
	audio_play_sound(sndCoin, 0, false); //Play coin pickup sound
}

//Create a spherical collision shape for the coin
//Give the coin the collision function we created. 
//The collision function will be executed if the player collides with the coin, using colmesh.displace_capsule.
shape = global.room_colmesh.add_trigger(new colmesh_sphere(x, y, z, radius), col_func);


//M = colmesh_matrix_build(x, y, z, 0, 0, 0, 1, 1, 1);
//shape = global.room_colmesh.add_dynamic(new colmesh_sphere(0, 0, 0, radius), M);