/*
	ColMesh - 3D Collisions Made Easy!
	TheSnidr 2021
	
	License
	The ColMesh system is licensed under a CreativeCommons Attribution 4.0 International License.
		https://creativecommons.org/licenses/by/4.0/
	This means you are free to use it in both personal and commercial projects, free of charge.
	Appropriate credit is required.
	
	What is a ColMesh?
	A ColMesh is a collection of 3D primitives and triangle meshes against which you can cast rays and do collision checks. It is basically an easy-to-use 3D collision system for GMS 2.3.
	
	What does it do?
	It will push your player out of level geometry.
	It handles slope calculations for you so that your player doesn’t slide down slopes.
	It lets you move platforms around and gives you everything you need to make sure your player moves the same way.
	It lets you cast rays so that your player can shoot bullets or laser beams, and by casting a ray from the player’s previous coordinate to the new coordinate before doing collision checking, you can make sure the player never falls through level geometry.
	
	See forum topic for updated info:
		https://forum.yoyogames.com/index.php?threads/82765/
	
	Also feel free to join the Discord channel:
		www.TheSnidr.com
*/
#macro cmDebug true	//Set to false if you don't want the ColMesh system to output debug messages
#macro cmMaxRecursion 8	//The maximum recursion depth. Applies when you place a ColMesh inside itself
#macro cmFirstPassRadius 1.2 //The radius for the first pass when doing precise collision checking. It's useful to check a slightly larger radius when doing the first pass.
#macro cmCol global.ColMeshCol //A global array that is used for returning a position after collision
#macro cmMeshMap global.ColMeshMeshMap
#macro cmRecursion global.ColMeshRecursionCounter //A global variable counting number of recursions
#macro cmCallingObject global.ColMeshCallingObject //A global variable storing the instance that is currently using either colmesh.displaceCapsule or colmesh.castRay
#macro cmBytesPerVert 36

#macro cmGroupSolid 1
#macro cmGroupColTrigger 2
#macro cmGroupRayTrigger 4

global.ColMeshCallingObject = -1;
global.ColMeshRecursionCounter = 0;
global.ColMeshRayMap = ds_map_create();
global.ColMeshMeshMap = ds_map_create();
global.ColMeshDefaultParent = new colmesh_mesh();
global.ColMeshDebugShapes = array_create(eColMeshShape.Num, -1);

/// @func colmesh()
function colmesh() : colmesh_mesh() constructor
{
	//Shape settings
	type = eColMeshShape.ColMesh;
	
	//Creates an empty ColMesh
	spHash = -1;
	originX = 0;
	originY = 0;
	originZ = 0;
	regionSize = 0;
	tempList  = ds_list_create();	//Temporary list used for collision
	shapeNum = 0;
	minimum = [0, 0, 0];
	maximum = [0, 0, 0];
	priority = array_create(cmMaxRecursion, -1); //An array containing a ds priority for each level of recursion
	rayMap = array_create(cmMaxRecursion, -1);
	
	/// @func subdivide(regionSize)
	static subdivide = function(_regionSize)
	{
		//This function will subdivide the colmesh into smaller regions, and save those regions to a ds_map.
		//If the colmesh has already been subdivided, that is cleared first.
		//A smaller region size will result in more regions, but fewer collision shapes per region.
		//The ColMesh only has to be subdivided once. Any shapes added after subdividing will add new regions to the subdivision as required.
		var debugTime = get_timer();
		
		//Clear old subdivision
		clearSubdiv();
		
		//Update subdivision parameters
		spHash = ds_map_create();
		regionSize = _regionSize;
		originX = (minimum[0] + maximum[0]) * .5;
		originY = (minimum[1] + maximum[1]) * .5;
		originZ = (minimum[2] + maximum[2]) * .5;
		
		//Subdivide
		shapeNum = ds_list_size(shapeList);
		for (var i = 0; i < shapeNum; i ++)
		{
			addShapeToSubdiv(shapeList[| i]);
		}
		colmesh_debug_message("colmesh.subdivide: Generated spatial hash with " + string(ds_map_size(spHash)) + " regions in " + string((get_timer() - debugTime) / 1000) + " milliseconds");
	}
	
	#region Add shapes
	
	/// @func addShape(shape)
	static addShape = function(shape)
	{
		//Adds the given shape to the ColMesh.
		//Look in colmesh_shapes for a list of all the shapes that can be added.
		//Typical usage:
		//	levelColmesh.addShape(new colmesh_sphere(x, y, z, radius));
		if (is_struct(shape))
		{
			if (shape.type == eColMeshShape.Mesh)
			{
				//We're currently adding a triangle mesh
				var num = array_length(shape.triangles);
				for (var i = 0; i < num; i ++)
				{
					var V = shape.triangles[i];
					if (is_array(shape.matrix))
					{
						//The shape has a transformation matrix. We need to copy the triangle into a new array and transform it.
						var tri = V;
						V = array_create(9);
						array_copy(V, 0, matrix_transform_vertex(shape.matrix, tri[0], tri[1], tri[2]), 0, 3);
						array_copy(V, 3, matrix_transform_vertex(shape.matrix, tri[3], tri[4], tri[5]), 0, 3);
						array_copy(V, 6, matrix_transform_vertex(shape.matrix, tri[6], tri[7], tri[8]), 0, 3);
					}
					var tri = addTriangle(V, shape);
				}
				++ shape.submeshes;
				return shape;
			}
			if (shape.type == eColMeshShape.Dynamic)
			{
				shape.colMesh = self;
			}
		}
		//Add the shape to the subdivision.
		_expandBoundaries(_getShape(shape).getMinMax());
		ds_list_add(shapeList, shape);
		addShapeToSubdiv(shape);
		++shapeNum;
		return shape;
	}
	
	/// @func addTrigger(shape, solid*, colFunc*, rayFunc*)
	static addTrigger = function(shape, solid = true, colFunc = undefined, rayFunc = undefined)
	{
		//Create a trigger object. 
		//This will not displace the player.
		
		//You can give the shape custom collision functions.
		//These custom functions are NOT saved when writing the ColMesh to a buffer
		//You have access to the following global variables in the custom functions:
		//	cmCol - The collider struct that is checking for collisions
		//	cmCallingObject - The instance that is currently checking for collisions
			
		//colFunc lets you give the shape a custom collision function.
		//This is useful for example for collisions with collectible objects like coins and powerups.
		
		//rayFunc lets you give the shape a custom function that is executed if a ray hits the shape.
		
		addShape(shape);
		shape.setTrigger(solid, colFunc, rayFunc);
		return shape;
	}
	
	/// @func addDynamic(shape, M)
	static addDynamic = function(shape, M)
	{
		//Adds a dynamic shape to the ColMesh.
		//A dynamic is a special kind of shape container that can be moved, scaled and rotated dynamically.
		//Look in colmesh_shapes for a list of all the shapes that can be added.
			
		//You can also supply a whole different colmesh to a dynamic.
		//Dynamics will not be saved when using colmesh.save or colmesh.writeToBuffer.
			
		//Scaling must be uniform, ie. the same for all dimensions. Non-uniform scaling and shearing is automatically removed from the matrix.
		
		//Typical usage:
		//	//Create event
		//	M = matrix_build(x, y, z, xangle, yangle, zangle, size, size, size); //Create a matrix
		//	dynamic = levelColmesh.addDynamic(new colmesh_sphere(0, 0, 0, radius), M); //Add a dynamic sphere to the colmesh, and save it to a variable called "dynamic"
				
		//	//Step event
		//	M = matrix_build(x, y, z, xangle, yangle, zangle, size, size, size); //Update the matrix
		//	dynamic.setMatrix(M, true); //"moving" should only be true if the orientation is updated every step
		return addShape(new colmesh_dynamic(shape, M));
	}
	
	/// @func addMesh(mesh, [matrix])
	static addMesh = function(mesh, M)
	{
		//Lets you add a mesh to the colmesh.
		//"mesh" should be either a path to an OBJ file, an array containing buffers, or a buffer containing vertex info in the following format:
		//	3D position, 3x4 bytes
		//	3D normal, 3x4 bytes
		//	UV coords, 2x4 bytes
		//	Colour, 4 bytes
		//This script does not return anything. The mesh as a whole does not have a handle. Triangles are added to the colmesh individually.
		var name = mesh;
		if (is_string(mesh))
		{
			name = filename_name(mesh);
		}
		if (is_struct(mesh))
		{
			mesh.matrix = M;
			return addShape(mesh);
		}
		return addShape(new colmesh_mesh(name, mesh, M));
	}
	
	/// @func addTriangle(V[9], parent*)
	static addTriangle = function(V, parent = global.ColMeshDefaultParent)
	{
		//Construct normal vector
		var nx = (V[4] - V[1]) * (V[8] - V[2]) - (V[5] - V[2]) * (V[7] - V[1]);
		var ny = (V[5] - V[2]) * (V[6] - V[0]) - (V[3] - V[0]) * (V[8] - V[2]);
		var nz = (V[3] - V[0]) * (V[7] - V[1]) - (V[4] - V[1]) * (V[6] - V[0]);
		var l = point_distance_3d(0, 0, 0, nx, ny, nz);
		if (l <= 0){return false;}
		var tri = array_create(13);
		array_copy(tri, 0, V, 0, 9);
		tri[9]  = nx / l;
		tri[10] = ny / l;
		tri[11] = nz / l;
		tri[12] = parent ?? global.ColMeshDefaultParent;
		addShape(tri);
		return tri;
	}
	
	/// @func removeShape(shape)
	static removeShape = function(shape)
	{
		//Removes the given shape from the ColMesh.
		//Cannot remove a mesh that has been added with colmesh.addMesh.
		var ind = ds_list_find_index(shapeList, shape);
		if (ind < 0){return false;}
		removeShapeFromSubdiv(shape);
		ds_list_delete(shapeList, ind);
		return true;
	}
	
	#endregion
	
	/// @func addShapeToSubdiv(shape, regions*, precise*)
	static addShapeToSubdiv = function(shape, regions = undefined, precise = true)
	{
		if (spHash < 0){exit;}
		var struct = _getShape(shape);
		if (is_undefined(regions)){regions = _getRegions(struct.getMinMax());}
		
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat xNum
		{
			++xx;
			var yy = regions[1];
			var _x = (xx + .5) * regionSize + originX;
			repeat yNum
			{
				++yy;
				var zz = regions[2];
				var _y = (yy + .5) * regionSize + originY;
				repeat zNum
				{
					++zz;
					var _z = (zz + .5) * regionSize + originZ;
					if (!precise || struct._intersectsCube(regionSize * .5 * 1.001, _x, _y, _z)) //The 1.001 fixes an issue with triangles placed exactly on the division planes not being added
					{
						var key = colmesh_get_key(xx, yy, zz);
						var list = spHash[? key];
						if (is_undefined(list))
						{
							list = ds_list_create();
							spHash[? key] = list;
						}
						ds_list_add(list, shape);
					}
				}
			}
		}
	}
	
	/// @func removeShapeFromSubdiv(shape, regions*)
	static removeShapeFromSubdiv = function(shape, regions = undefined)
	{
		if (spHash < 0){return false;}
		if (is_undefined(regions)){regions = _getRegions(_getShape(shape).getMinMax());}
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat xNum
		{
			++xx;
			var yy = regions[1];
			repeat yNum
			{
				++yy;
				var zz = regions[2];
				repeat zNum
				{
					++zz;
					var key = colmesh_get_key(xx, yy, zz);
					var list = spHash[? key];
					if (is_undefined(list))
					{
						continue;
					}
					var ind = ds_list_find_index(list, shape);
					if (ind < 0){continue;}
					ds_list_delete(list, ind);
					if (ds_list_empty(list))
					{
						ds_list_destroy(list);
						ds_map_delete(spHash, key);
					}
				}
			}
		}
	}
	
	/// @func clearSubdiv()
	static clearSubdiv = function()
	{
		//Clears any data structures related to the subdivision of the colmesh
		if (spHash >= 0)
		{
			var region = ds_map_find_first(spHash);
			while (!is_undefined(region))
			{
				ds_list_destroy(spHash[? region]);
				region = ds_map_find_next(spHash, region);
			}
			ds_map_destroy(spHash);
			spHash = -1;
		}
	}
	
	/// @func clear()
	static clear = function()
	{
		//Clears all info from the colmesh
		clearSubdiv();
		minimum = [0, 0, 0];
		maximum = [0, 0, 0];
		ds_list_clear(tempList);
		ds_list_clear(shapeList);
		for (var i = 0; i < cmMaxRecursion; i ++)
		{
			if (priority[i] >= 0)
			{
				ds_priority_destroy(priority[i]);
				priority[i] = -1;
			}
			if (rayMap[i] >= 0)
			{
				ds_map_destroy(rayMap[i]);
				rayMap[i] = -1;
			}
		}
	}
	
	/// @func destroy()
	static destroy = function()
	{
		//Destroys the colmesh
		clear();
		ds_list_destroy(tempList);
		ds_list_destroy(shapeList);
	}
	
	/// @func getRegion(AABB[6])
	static getRegion = function(AABB) 
	{
		//Returns a list containing all the shapes in the regions the AABB of the given capsule touches.
		//If the colmesh is not subdivided, this will return a list of all the shapes in the colmesh.
		var minx = AABB[0], miny = AABB[1], minz = AABB[2], maxx = AABB[3], maxy = AABB[4], maxz = AABB[5];
		if (minx > maximum[0] || miny > maximum[1] || minz > maximum[2] || maxx < minimum[0] || maxy < minimum[1] || maxz < minimum[2])
		{
			//If the capsule is fully outside the AABB of the colmesh, return undefined
			return undefined;
		}
		
		ds_list_clear(tempList);
		if (spHash < 0)
		{
			var i = ds_list_size(shapeList);
			repeat i
			{
				var shape = shapeList[| --i];
				if (!_getShape(shape).checkAABB(minx, miny, minz, maxx, maxy, maxz)){continue;} //Only add the shape to the list if its AABB intersects the capsule AABB
				ds_list_add(tempList, shape);
			}
			return tempList;
		}
		
		var regions = _getRegions(AABB);
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat (xNum)
		{
			++xx;
			var yy = regions[1];
			repeat (yNum)
			{
				++yy;
				var zz = regions[2];
				repeat (zNum)
				{
					++zz;
					
					//Check if the region exists
					var key = colmesh_get_key(xx, yy, zz);
					var region = spHash[? key];
					if (is_undefined(region)){continue;}
					
					//The region exists! Check all the shapes in the region and see if their AABB intersects the AABB of the capsule
					var i = ds_list_size(region);
					repeat i
					{
						var shape = region[| --i];
						if (ds_list_find_index(tempList, shape) >= 0){continue;} //Make sure the shape hasn't already been added to the list
						if (!_getShape(shape).checkAABB(minx, miny, minz, maxx, maxy, maxz)){continue;} //Only add the shape to the list if its AABB intersects the capsule AABB
						ds_list_add(tempList, shape);
					}
				}
			}
		}
		return tempList;
	}
	
	/// @func displaceCapsule(x, y, z, xup, yup, zup, radius, height, slopeAngle*, fast*, executeColFunc*)
	static displaceCapsule = function(x, y, z, xup, yup, zup, radius, height, slopeAngle = 0, fast = true, executeCollisionFunction = false)
	{
		//This is a compatibility function. All the functionality that used to be here has been moved to colmesh_colliders
		var precision = 2 * (!fast);
		var collider = new colmesh_collider_capsule(x, y, z, xup, yup, zup, radius, height, slopeAngle, precision);
		collider.avoid(self);
		if (executeCollisionFunction)
		{
			cmCallingObject = other;
			++cmRecursion;
			collider.executeColFunc();
			--cmRecursion;
		}
		return collider;
	}
	
	/// @func regionDisplaceCapsule(region, x, y, z, xup, yup, zup, radius, height, slopeAngle*, fast*, executeColFunc*)
	static regionDisplaceCapsule = function(region, x, y, z, xup, yup, zup, radius, height, slopeAngle = 0, fast = true, executeColFunc = false)
	{
		//This is a compatibility function. All the functionality that used to be here has been moved to colmesh_colliders
		var precision = 2 * (!fast);
		var collider = new colmesh_collider_capsule(x, y, z, xup, yup, zup, radius, height, slopeAngle, precision);
		collider.avoidRegion(self, region);
		if (executeColFunc)
		{
			cmCallingObject = other;
			++cmRecursion;
			collider.executeColFunc();
			--cmRecursion;
		}
		return collider;
	}
	
	/// @func capsuleCollision(x, y, z, xup, yup, zup, radius, height)
	static capsuleCollision = function(x, y, z, xup, yup, zup, radius, height)
	{
		//Returns whether or not the given capsule collides with the colmesh
		var AABB = colmesh_capsule_get_AABB(x, y, z, xup, yup, zup, radius, height);
		var region = getRegion(AABB);
		return colmesh__region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height);
	}
	
	/// @func regionCapsuleCollision(x, y, z, xup, yup, zup, radius, height)
	static regionCapsuleCollision = function(region, x, y, z, xup, yup, zup, radius, height)
	{
		//Returns whether or not the given capsule collides with the given region
		return colmesh__region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height);
	}
	
	/// @func getNearestPoint(x, y, z)
	static getNearestPoint = function(x, y, z)
	{
		//Returns the nearest point on the colmesh to the given point.
		//Only checks the region the point is in.
		var AABB = colmesh_capsule_get_AABB(x, y, z, 0, 0, 1, 0, 0);
		return regionGetNearestPoint(getRegion(AABB), x, y, z);
	}
	
	/// @func regionGetNearestPoint(region, x, y, z, radius)
	static regionGetNearestPoint = function(region, x, y, z)
	{
		//Returns the nearest point in the region to the given point
		if (region < 0)
		{
			return false;
		}
		var i = ds_list_size(region);
		if (i == 0)
		{
			return false;
		}
		static ret = array_create(3);
		var minD = 9999999;
		ret[0] = x;
		ret[1] = y;
		ret[2] = z;
		repeat i
		{
			var shapeInd = abs(region[| --i]);
			var shape = _getShape(shapeList[| shapeInd]);
			var p = shape._getClosestPoint(x, y, z);
			var d = point_distance_3d(0, 0, 0, p[0] - x, p[1] - y, p[2] - z);
			if (d < minD)
			{
				minD = d;
				ret[0] = p[0];
				ret[1] = p[1];
				ret[2] = p[2];
			}
		}
		return ret;
	}
	
	#region Ray casting
	
	/// @func castRay(x1, y1, z1, x2, y2, z2, mask*)
	static castRay = function(x1, y1, z1, x2, y2, z2, mask = cmGroupSolid)
	{
		//Casts a ray from (x1, y1, z1) to (x2, y2, z2).
		//Returns a new instance of the colmesh_raycast_result struct.
		
		if (spHash < 0){	
			//This ColMesh has not been subdivided. Cast a ray against all the shapes it contains
			return regionCastRay(shapeList, [x1, y1, z1, x2, y2, z2], mask);
		}
		var ray = [x1, y1, z1, x2, y2, z2];
		var rayStruct = new colmesh_raycast_result(x2, y2, z2, 0, 0, 1, false, -1);
		if (!_constrain_ray(ray)){
			//The ray is fully outside the borders of this ColMesh. Return the un-altered ray struct
			return rayStruct;
		}
		var map = rayMap[cmRecursion];
		if (map < 0){
			map = ds_map_create();
			rayMap[cmRecursion] = map;
		}
		var ldx = ray[3] - ray[0];
		var ldy = ray[4] - ray[1];
		var ldz = ray[5] - ray[2];
		var idx = (ldx == 0) ? 0 : 1 / ldx;
		var idy = (ldy == 0) ? 0 : 1 / ldy;
		var idz = (ldz == 0) ? 0 : 1 / ldz;
		var incx = abs(idx) + (idx == 0);
		var incy = abs(idy) + (idy == 0);
		var incz = abs(idz) + (idz == 0);
		var ox = (ray[0] - originX) / regionSize;
		var oy = (ray[1] - originY) / regionSize;
		var oz = (ray[2] - originZ) / regionSize;
		var currX = ox, currY = oy, currZ = oz;
		var key = colmesh_get_key(floor(currX), floor(currY), floor(currZ));
		var prevKey = key;
		var t = 0, _t = 0;
		while (t < 1){
			var tMaxX = - frac(currX) * idx;
			var tMaxY = - frac(currY) * idy;
			var tMaxZ = - frac(currZ) * idz;
			if (tMaxX <= 0){tMaxX += incx;}
			if (tMaxY <= 0){tMaxY += incy;}
			if (tMaxZ <= 0){tMaxZ += incz;}
			if (tMaxX < tMaxY){
				if (tMaxX < tMaxZ){
					_t += tMaxX;
					currX = round(ox + ldx * _t);
					currY = oy + ldy * _t;
					currZ = oz + ldz * _t;
					key = colmesh_get_key(currX - (ldx < 0), floor(currY), floor(currZ));
				}
				else{
					_t += tMaxZ;
					currX = ox + ldx * _t;
					currY = oy + ldy * _t;
					currZ = round(oz + ldz * _t);
					key = colmesh_get_key(floor(currX), floor(currY), currZ - (ldz < 0));
				}
			}
			else{
				if (tMaxY < tMaxZ){
					_t += tMaxY;
					currX = ox + ldx * _t;
					currY = round(oy + ldy * _t);
					currZ = oz + ldz * _t;
					key = colmesh_get_key(floor(currX), currY - (ldy < 0), floor(currZ));
				}
				else{
					_t += tMaxZ;
					currX = ox + ldx * _t;
					currY = oy + ldy * _t;
					currZ = round(oz + ldz * _t);
					key = colmesh_get_key(floor(currX), floor(currY), currZ - (ldz < 0));
				}
			}
			
			//Check if this region exists
			t = min(1, _t * regionSize);
			var region = spHash[? prevKey];
			prevKey = key;
			if (is_undefined(region)){continue;}
			
			//Loop through the shapes in the region
			var i = ds_list_size(region);
			repeat i
			{
				var _shape = region[| --i];							//Get the shape from the region list
				var shape = _getShape(_shape);						//Gets the struct of the given shape. This only does anything if the shape is a triangle, otherwise it returns the input.
				if ((mask & shape.group) == 0){continue;}			//Continue the loop if the mask does not match the group
				var hit = map[? _shape];							//Check if this shape has been raycasted against before
				if (is_undefined(hit))								//If this shape has not been raycasted against before
				{
					//if (!is_struct(_shape)) && false
					//{
					//	hit = shape._castSphere(ray, 10, mask);
					//}
					//else
					//{
						hit = shape._castRay(ray, mask);				//Do a raycast against this shape
					//}
					map[? _shape] = hit;							//Store the result to the map
				}
				if (!is_array(hit)){continue;}						//There is no intersection between the ray and this shape
				if (hit[7] > t){continue;}							//The intersection between the ray and the shape is too far away
				array_push(rayStruct.intersections, hit);			//Add shape to intersection list regardless of whether or not it's solid
				if (shape.type == eColMeshShape.Dynamic){			//If this shape is a dynamic, add it to the intersections list as well
					array_push(rayStruct.intersections, [hit[0], hit[1], hit[2], hit[3], hit[4], hit[5], shape]);
				}
				if ((shape.group & cmGroupSolid) == 0){
					hit[@ 7] = 1;									//Make sure nonsolids are only added to the intersections array once
					continue;										//This shape is not solid. The ray should continue!
				}	
				t = hit[7];
				rayStruct.x  = hit[0];
				rayStruct.y  = hit[1];
				rayStruct.z  = hit[2];
				rayStruct.nx = hit[3];
				rayStruct.ny = hit[4];
				rayStruct.nz = hit[5];
				rayStruct.hit = true;
				rayStruct.struct = _shape;
			}
			if (rayStruct.hit){break;}
		}
		ds_map_clear(map);
		return rayStruct;
	}
	
	/// @func regionCastRay(region, ray, mask*, rayStruct*)
	static regionCastRay = function(region, ray, mask = cmGroupSolid, rayStruct = new colmesh_raycast_result(ray[3], ray[4], ray[5], 0, 0, 1, false, -1)) 
	{
		//This ray casting script is faster than the regular colmesh raycasting script.
		//However, it will only cast a ray onto the shapes in the current region, and is as such a "short-range" ray.
		//If there was an intersection, it returns an array with the following format:
		//	[x, y, z, nX, nY, nZ, success]
		//Returns false if there was no intersection.
		if (is_undefined(region) || (ray[0] == ray[3] && ray[1] == ray[4] && ray[2] == ray[5]))
		{
			return rayStruct;
		}
		
		//Loop through the shapes in the region
		var firstHit = -1;
		var i = ds_list_size(region);
		repeat i
		{
			var _shape = region[| --i];
			var shape = _getShape(_shape);
			if ((mask & shape.group) == 0){continue;}
			var hit = shape._castRay(ray, mask);
			if (!is_array(hit)){continue;}
			array_push(rayStruct.intersections, hit);
			if (shape.type == eColMeshShape.Dynamic){			//If this shape is a dynamic, add it to the intersections list as well
				array_push(rayStruct.intersections, [hit[0], hit[1], hit[2], hit[3], hit[4], hit[5], shape]);
			}
			if ((shape.group & cmGroupSolid) == 0){continue;}
			array_copy(ray, 3, hit, 0, 3);
			rayStruct.x  = hit[0];
			rayStruct.y  = hit[1];
			rayStruct.z  = hit[2];
			rayStruct.nx = hit[3];
			rayStruct.ny = hit[4];
			rayStruct.nz = hit[5];
			rayStruct.hit = true;
			rayStruct.struct = _shape;
		}
		return rayStruct;
	}
		
	#endregion
	
	#region Supplementaries
	
	/// @func _expandBoundaries(AABB[6])
	static _expandBoundaries = function(AABB)
	{
		if (shapeNum == 0)
		{
			minimum[0] = AABB[0];
			minimum[1] = AABB[1];
			minimum[2] = AABB[2];
			maximum[0] = AABB[3];
			maximum[1] = AABB[4];
			maximum[2] = AABB[5];
			return;
		}
		//Expands the boundaries of the ColMesh. This will only come into effect once the ColMesh is subdivided.
		minimum[0] = min(minimum[0], AABB[0]);
		minimum[1] = min(minimum[1], AABB[1]);
		minimum[2] = min(minimum[2], AABB[2]);
		maximum[0] = max(maximum[0], AABB[3]);
		maximum[1] = max(maximum[1], AABB[4]);
		maximum[2] = max(maximum[2], AABB[5]);
	}
	
	/// @func _getShape(shape)
	static _getShape = function(shape)
	{
		//A supplementary function.
		//If the given shape is a real value, it must contain a triangle index. 
		//It will then load that triangle into the colmesh, and return the index of the colmesh.
		//If it does not contain a real, the given shape is returned.
		if (is_array(shape))
		{
			var parent = shape[12];
			parent.triangle = shape;
			return parent;
		}
		return shape;
	}
	
	/// @func _constrain_ray(ray)
	static _constrain_ray = function(ray) 
	{
		//This script will truncate the ray from (x1, y1, z1) to (x2, y2, z2) so that it fits inside the bounding box of the colmesh.
		//Returns false if the ray is fully outside the bounding box.
		
		///////////////////////////////////////////////////////////////////
		//Convert from world coordinates to local coordinates
		var sx = (maximum[0] - minimum[0]) * .5;
		var sy = (maximum[1] - minimum[1]) * .5;
		var sz = (maximum[2] - minimum[2]) * .5;
		var mx = (maximum[0] + minimum[0]) * .5;
		var my = (maximum[1] + minimum[1]) * .5;
		var mz = (maximum[2] + minimum[2]) * .5;
		var x1 = (ray[0] - mx) / sx;
		var y1 = (ray[1] - my) / sy;
		var z1 = (ray[2] - mz) / sz;
		var x2 = (ray[3] - mx) / sx;
		var y2 = (ray[4] - my) / sy;
		var z2 = (ray[5] - mz) / sz;
		
		var _min = min(x1, y1, z1, x2, y2, z2);
		var _max = max(x1, y1, z1, x2, y2, z2);
		if (_min >= -1 && _max <= 1)
		{
			//The ray is fully inside the bounding box, and we can end the algorithm here
			return true;
		}
		if (_min < -1 || _max > 1)
		{
			if ((x1 < -1 && x2 < -1) || (y1 < -1 && y2 < -1) || (z1 < -1 && z2 < -1) || (x1 > 1 && x2 > 1) || (y1 > 1 && y2 > 1) || (z1 > 1 && z2 > 1))
			{	//The ray is fully outside the bounding box, and we can end the algorithm here
				return false;
			}
		}
	
		///////////////////////////////////////////////////////////////////
		//Check X dimension
		var d = x2 - x1;
		if (d != 0)
		{
			//Check outside
			var s = sign(d);
			var t = (- s - x1) / d;
			if (t >= 0 && t <= 1)
			{
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 && abs(itsZ) <= 1)
				{
					x1 = - s;
					y1 = itsY;
					z1 = itsZ;
					d = x2 - x1;
				}
			}
			//Check inside
			var t = (s - x1) / d;
			if (t >= 0 && t <= 1)
			{
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 && abs(itsZ) <= 1)
				{
					x2 = s;
					y2 = itsY;
					z2 = itsZ;
				}
			}
		}
		///////////////////////////////////////////////////////////////////
		//Check Y dimension
		var d = y2 - y1;
		if (d != 0)
		{
			//Check outside
			var s = sign(d);
			var t = (- s - y1) / d;
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 && abs(itsZ) <= 1)
				{
					x1 = itsX;
					y1 = - s;
					z1 = itsZ;
					d = y2 - y1;
				}
			}
			//Check inside
			var t = (s - y1) / d;
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 && abs(itsZ) <= 1)
				{
					x2 = itsX;
					y2 = s;
					z2 = itsZ;
				}
			}
		}
		///////////////////////////////////////////////////////////////////
		//Check Z dimension
		var d = z2 - z1;
		if (d != 0)
		{
			//Check outside
			var s = sign(d);
			var t = (- s - z1) / d;
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 && abs(itsY) <= 1)
				{
					x1 = itsX;
					y1 = itsY;
					z1 = - s;
					d = z2 - z1;
				}
			}
			//Check inside
			var t = (s - z1) / d;
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 && abs(itsY) <= 1)
				{
					x2 = itsX;
					y2 = itsY;
					z2 = s;
				}
			}
		}

		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		ray[@ 0] = (x1 * sx + mx);
		ray[@ 1] = (y1 * sy + my);
		ray[@ 2] = (z1 * sz + mz);
		ray[@ 3] = (x2 * sx + mx);
		ray[@ 4] = (y2 * sy + my);
		ray[@ 5] = (z2 * sz + mz);
		return true;
	}
		
	#endregion
	
	#region Saving and loading
	
	/// @func save(path, saveTriggers)
	static save = function(path, saveTriggers)
	{
		//Saves the colmesh to a file.
		//This function will not work in HTML5.
		//For HTML5 you need to create a buffer, write the colmesh to it with colmesh.writeToBuffer, and save it with buffer_save_async.
		var buff = buffer_create(1, buffer_grow, 1);
		writeToBuffer(buff, saveTriggers);
		buffer_resize(buff, buffer_tell(buff));
		buffer_save(buff, path);
		buffer_delete(buff);
	}
	
	/// @func load(path)
	static load = function(path)
	{
		//Loads the colmesh from a file.
		//This function will not work in HTML5.
		//For HTML5 you need to load a buffer asynchronously, and read from that using colmesh.readFromBuffer.
		var buff = buffer_load(path);
		if (buff < 0)
		{
			colmesh_debug_message("colmesh.load: Could not find file " + string(path));
			return false;
		}
		var success = readFromBuffer(buff);
		buffer_delete(buff);
		return success;
	}
	
	/// @func writeToBuffer(saveBuff)
	static writeToBuffer = function(saveBuff, saveTriggers = false)
	{
		//Writes the colmesh to a buffer.
		//This will not save dynamic shapes!
		var debugTime = current_time;
		var tempBuff = buffer_create(1, buffer_grow, 1);
		shapeNum = ds_list_size(shapeList);
		
		//Make a map of all the submeshes in the colmesh
		var meshMap = ds_map_create();
		var meshNames = [];
		
		//Write shape list
		buffer_write(tempBuff, buffer_u32, shapeNum);
		for (var i = 0; i < shapeNum; i ++)
		{
			with _getShape(shapeList[| i])
			{
				if ((group & cmGroupSolid == 0) && !saveTriggers)
				{
					//Do not write trigger objects
					buffer_write(tempBuff, buffer_u8, eColMeshShape.None);
					continue;
				}
				buffer_write(tempBuff, buffer_u8, type);
				switch type
				{
					case eColMeshShape.Mesh:
						var index = meshMap[? name];
						if (is_undefined(index))
						{
							index = ds_map_size(meshMap);
							meshMap[? name] = index;
							array_push(meshNames, name);
						}
						buffer_write(tempBuff, buffer_u32, index);
						for (var j = 0; j < 9; j ++)
						{
							buffer_write(tempBuff, buffer_f32, triangle[j]);
						}
						break;
					case eColMeshShape.Sphere:
						buffer_write(tempBuff, buffer_u32, group);
						buffer_write(tempBuff, buffer_f32, x);
						buffer_write(tempBuff, buffer_f32, y);
						buffer_write(tempBuff, buffer_f32, z);
						buffer_write(tempBuff, buffer_f32, R);
						break;
					case eColMeshShape.Capsule:
						buffer_write(tempBuff, buffer_u32, group);
						buffer_write(tempBuff, buffer_f32, x);
						buffer_write(tempBuff, buffer_f32, y);
						buffer_write(tempBuff, buffer_f32, z);
						buffer_write(tempBuff, buffer_f32, xup);
						buffer_write(tempBuff, buffer_f32, yup);
						buffer_write(tempBuff, buffer_f32, zup);
						buffer_write(tempBuff, buffer_f32, R);
						buffer_write(tempBuff, buffer_f32, H);
						break;
					case eColMeshShape.Cylinder:
						buffer_write(tempBuff, buffer_u32, group);
						buffer_write(tempBuff, buffer_f32, x);
						buffer_write(tempBuff, buffer_f32, y);
						buffer_write(tempBuff, buffer_f32, z);
						buffer_write(tempBuff, buffer_f32, xup);
						buffer_write(tempBuff, buffer_f32, yup);
						buffer_write(tempBuff, buffer_f32, zup);
						buffer_write(tempBuff, buffer_f32, R);
						buffer_write(tempBuff, buffer_f32, H);
						break;
					case eColMeshShape.Torus:
						buffer_write(tempBuff, buffer_u32, group);
						buffer_write(tempBuff, buffer_f32, x);
						buffer_write(tempBuff, buffer_f32, y);
						buffer_write(tempBuff, buffer_f32, z);
						buffer_write(tempBuff, buffer_f32, xup);
						buffer_write(tempBuff, buffer_f32, yup);
						buffer_write(tempBuff, buffer_f32, zup);
						buffer_write(tempBuff, buffer_f32, R);
						buffer_write(tempBuff, buffer_f32, r);
						break;
					case eColMeshShape.Cube:
						buffer_write(tempBuff, buffer_u32, group);
						buffer_write(tempBuff, buffer_f32, x);
						buffer_write(tempBuff, buffer_f32, y);
						buffer_write(tempBuff, buffer_f32, z);
						buffer_write(tempBuff, buffer_f32, halfX);
						buffer_write(tempBuff, buffer_f32, halfY);
						buffer_write(tempBuff, buffer_f32, halfZ);
						break;
					case eColMeshShape.Block:
						buffer_write(tempBuff, buffer_u32, group);
						buffer_write(tempBuff, buffer_f32, M[0]);
						buffer_write(tempBuff, buffer_f32, M[1]);
						buffer_write(tempBuff, buffer_f32, M[2]);
						buffer_write(tempBuff, buffer_f32, M[4]);
						buffer_write(tempBuff, buffer_f32, M[5]);
						buffer_write(tempBuff, buffer_f32, M[6]);
						buffer_write(tempBuff, buffer_f32, M[8]);
						buffer_write(tempBuff, buffer_f32, M[9]);
						buffer_write(tempBuff, buffer_f32, M[10]);
						buffer_write(tempBuff, buffer_f32, M[12]);
						buffer_write(tempBuff, buffer_f32, M[13]);
						buffer_write(tempBuff, buffer_f32, M[14]);
						break;
				}
			}
		}

		//Write subdivision to buffer
		if (spHash >= 0)
		{
			buffer_write(tempBuff, buffer_u32, ds_map_size(spHash));
			buffer_write(tempBuff, buffer_f32, regionSize);
			buffer_write(tempBuff, buffer_f32, originX);
			buffer_write(tempBuff, buffer_f32, originY);
			buffer_write(tempBuff, buffer_f32, originZ);
			
			var key = ds_map_find_first(spHash);
			while (!is_undefined(key))
			{
				var region = spHash[? key];
				var num = ds_list_size(region);
				var n = num;
				buffer_write(tempBuff, buffer_string, key);
				var numPos = buffer_tell(tempBuff);
				buffer_write(tempBuff, buffer_u32, num);
				repeat n
				{
					var shapeInd = region[| --n];
					buffer_write(tempBuff, buffer_u32, ds_list_find_index(shapeList, shapeInd));
				}
				buffer_poke(tempBuff, numPos, buffer_u32, num);
				key = ds_map_find_next(spHash, key);
			}
		}
		else
		{
			buffer_write(tempBuff, buffer_u32, 0);
		}

		//Write header
		var buffSize = buffer_tell(tempBuff);
		buffer_write(saveBuff, buffer_string, "ColMesh v4");
		
		//Write submeshes
		var num = ds_map_size(meshMap);
		buffer_write(saveBuff, buffer_u32, num);
		for (var i = 0; i < num; i ++)
		{
			var identifier = meshNames[i];
			buffer_write(saveBuff, buffer_string, identifier);
			buffer_write(saveBuff, buffer_u32, global.ColMeshMeshMap[? identifier].group);
		}
		
		//Copy over the rest of the buffer
		buffer_write(saveBuff, buffer_u64, buffSize);
		buffer_copy(tempBuff, 0, buffSize, saveBuff, buffer_tell(saveBuff));
		buffer_seek(saveBuff, buffer_seek_relative, buffSize);
		colmesh_debug_message("Script colmesh.writeToBuffer: Wrote colmesh to buffer in " + string(current_time - debugTime) + " milliseconds");

		//Clean up
		buffer_delete(tempBuff);
	}
		
	/// @func readFromBuffer(loadBuff)
	static readFromBuffer = function(loadBuff) 
	{
		//Reads a collision mesh from the given buffer.
		var debugTime = current_time;
		clear();
		
		//Make sure this is a colmesh
		var version = 4;
		var headerText = buffer_read(loadBuff, buffer_string);
		if (headerText != "ColMesh v4")
		{
			show_debug_message("Error in script readFromBuffer: Trying to load deprecated version cache");
			return false;
		}
		
		//Read submeshes
		var num = buffer_read(loadBuff, buffer_u32);
		var meshNames = array_create(num);
		var debugString = "colmesh.readFromBuffer mesh names: ";
		for (var i = 0; i < num; i ++)
		{
			var identifier = buffer_read(loadBuff, buffer_string);
			var group = buffer_read(loadBuff, buffer_u32);
			var a = new colmesh_mesh(identifier, undefined, undefined, group);
			meshNames[i] = identifier;
			debugString += identifier;
			if (i < num - 1)
			{
				debugString += ", "
			}
		}
		colmesh_debug_message(debugString);
		
		var buffSize = buffer_read(loadBuff, buffer_u64);
		var tempBuff = buffer_create(buffSize, buffer_fixed, 1);
		buffer_copy(loadBuff, buffer_tell(loadBuff), buffSize, tempBuff, 0);
		buffer_seek(loadBuff, buffer_seek_relative, buffSize);
		
		//Read shape list
		var num = buffer_read(tempBuff, buffer_u32);
		for (var i = 0; i < num; i ++)
		{
			var type = buffer_read(tempBuff, buffer_u8);
			switch (type)
			{
				case eColMeshShape.Mesh:
					var index = buffer_read(tempBuff, buffer_u32);
					var parent = global.ColMeshMeshMap[? meshNames[index]];
					var V = array_create(9);
					for (var j = 0; j < 9; j ++)
					{
						V[j] = buffer_read(tempBuff, buffer_f32);
					}
					addTriangle(V, parent);
					break;
				case eColMeshShape.Sphere:
					var group = buffer_read(tempBuff, buffer_u32);
					var _x = buffer_read(tempBuff, buffer_f32);
					var _y = buffer_read(tempBuff, buffer_f32);
					var _z = buffer_read(tempBuff, buffer_f32);
					var R  = buffer_read(tempBuff, buffer_f32);
					addShape(new colmesh_sphere(_x, _y, _z, R, group));
					break;
				case eColMeshShape.Capsule:
					var group = buffer_read(tempBuff, buffer_u32);
					var _x  = buffer_read(tempBuff, buffer_f32);
					var _y  = buffer_read(tempBuff, buffer_f32);
					var _z  = buffer_read(tempBuff, buffer_f32);
					var xup = buffer_read(tempBuff, buffer_f32);
					var yup = buffer_read(tempBuff, buffer_f32);
					var zup = buffer_read(tempBuff, buffer_f32);
					var R   = buffer_read(tempBuff, buffer_f32);
					var H   = buffer_read(tempBuff, buffer_f32);
					addShape(new colmesh_capsule(_x, _y, _z, xup, yup, zup, R, H, group));
					break;
				case eColMeshShape.Cylinder:
					var group = buffer_read(tempBuff, buffer_u32);
					var _x  = buffer_read(tempBuff, buffer_f32);
					var _y  = buffer_read(tempBuff, buffer_f32);
					var _z  = buffer_read(tempBuff, buffer_f32);
					var xup = buffer_read(tempBuff, buffer_f32);
					var yup = buffer_read(tempBuff, buffer_f32);
					var zup = buffer_read(tempBuff, buffer_f32);
					var R   = buffer_read(tempBuff, buffer_f32);
					var H   = buffer_read(tempBuff, buffer_f32);
					addShape(new colmesh_cylinder(_x, _y, _z, xup, yup, zup, R, H, group));
					break;
				case eColMeshShape.Torus:
					var group = buffer_read(tempBuff, buffer_u32);
					var _x  = buffer_read(tempBuff, buffer_f32);
					var _y  = buffer_read(tempBuff, buffer_f32);
					var _z  = buffer_read(tempBuff, buffer_f32);
					var xup = buffer_read(tempBuff, buffer_f32);
					var yup = buffer_read(tempBuff, buffer_f32);
					var zup = buffer_read(tempBuff, buffer_f32);
					var R   = buffer_read(tempBuff, buffer_f32);
					var r   = buffer_read(tempBuff, buffer_f32);
					addShape(new colmesh_torus(_x, _y, _z, xup, yup, zup, R, r, group));
					break;
				case eColMeshShape.Cube:
					var group = buffer_read(tempBuff, buffer_u32);
					var _x    = buffer_read(tempBuff, buffer_f32);
					var _y    = buffer_read(tempBuff, buffer_f32);
					var _z    = buffer_read(tempBuff, buffer_f32);
					var halfW = buffer_read(tempBuff, buffer_f32);
					var halfL = buffer_read(tempBuff, buffer_f32);
					var halfH = buffer_read(tempBuff, buffer_f32);
					addShape(new colmesh_cube(_x, _y, _z, halfW * 2, halfW * 2, halfH * 2, group));
					break;
				case eColMeshShape.Block:
					var group = buffer_read(tempBuff, buffer_u32);
					var M = array_create(16);
					M[0]  = buffer_read(tempBuff, buffer_f32);
					M[1]  = buffer_read(tempBuff, buffer_f32);
					M[2]  = buffer_read(tempBuff, buffer_f32);
					M[4]  = buffer_read(tempBuff, buffer_f32);
					M[5]  = buffer_read(tempBuff, buffer_f32);
					M[6]  = buffer_read(tempBuff, buffer_f32);
					M[8]  = buffer_read(tempBuff, buffer_f32);
					M[9]  = buffer_read(tempBuff, buffer_f32);
					M[10] = buffer_read(tempBuff, buffer_f32);
					M[12] = buffer_read(tempBuff, buffer_f32);
					M[13] = buffer_read(tempBuff, buffer_f32);
					M[14] = buffer_read(tempBuff, buffer_f32);
					M[15] = 1;
					addShape(new colmesh_block(M, group));
					break;
				case eColMeshShape.None:
					//Dynamic shapes are NOT saved! This is a failsafe so that the order of objects added after the dynamic is kept.
					addShape(new colmesh_none());
					break;
				case eColMeshShape.Dynamic:
					//Dynamic shapes are NOT saved! This is a failsafe so that the order of objects added after the dynamic is kept.
					addShape(new colmesh_none());
					break;
			}
		}

		//Read subdivision
		var num = buffer_read(tempBuff, buffer_u32);
		if (num >= 0)
		{
			regionSize = buffer_read(tempBuff, buffer_f32);
			originX	= buffer_read(tempBuff, buffer_f32);
			originY	= buffer_read(tempBuff, buffer_f32);
			originZ	= buffer_read(tempBuff, buffer_f32);
			spHash = ds_map_create();
			repeat num
			{
				var region = ds_list_create();
				var key = buffer_read(tempBuff, buffer_string);
				repeat buffer_read(tempBuff, buffer_u32)
				{
					var shape = shapeList[| buffer_read(tempBuff, buffer_u32)];
					if (is_struct(shape))
					{
						if (shape.type == eColMeshShape.Dynamic || shape.type == eColMeshShape.None)
						{
							continue;
						}
					}
					ds_list_add(region, shape);
				}
				spHash[? key] = region;
			}
		}

		//Clean up and return result
		colmesh_debug_message("Script colmesh.readFromBuffer: Read " + string(self) + " from buffer in " + string(current_time - debugTime) + " milliseconds");
		buffer_delete(tempBuff);
		return true;
	}
	
	/// @func move(x, y, z)
	static move = function(_x, _y, _z)
	{
		//This does not make sense for a triangle, so we can just return false here and now
		return false;
	}
	
	/// @func _getRegions(minMax)
	static _getRegions = function(minMax)
	{
		static ret = array_create(6);
		ret[0] = floor((minMax[0] - originX) / regionSize) - 1;
		ret[1] = floor((minMax[1] - originY) / regionSize) - 1;
		ret[2] = floor((minMax[2] - originZ) / regionSize) - 1;
		ret[3] =  ceil((minMax[3] - originX) / regionSize);
		ret[4] =  ceil((minMax[4] - originY) / regionSize);
		ret[5] =  ceil((minMax[5] - originZ) / regionSize);
		return ret;
	}
	
	/// @func getMinMax()
	static getMinMax = function()
	{
		static minMax = array_create(6);
		array_copy(minMax, 0, minimum, 0, 3);
		array_copy(minMax, 3, maximum, 0, 3);
		return minMax;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ)
	{
		if (spHash < 0)
		{
			var i = ds_list_size(shapeList);
			repeat i
			{
				var shape = _getShape(shapeList[| --i]);
				if (shape._intersectsCube(hsize, bX, bY, bZ))
				{
					return true;
				}
			}
			return false;
		}
		var regions = _getRegions(getMinMax());
		
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat (xNum)
		{
			++xx;
			var yy = regions[1];
			repeat (yNum)
			{
				++yy;
				var zz = regions[2];
				repeat (zNum)
				{
					++zz;
					
					//Check if the region exists
					var key = colmesh_get_key(xx, yy, zz);
					var region = spHash[? key];
					if (is_undefined(region)){continue;}
					
					//if (colmesh_cube_cube_intersection
					
				}
			}
		}
	}
	
	/// @func debugDraw(region*, texture*)
	static debugDraw = function(region, tex = -1) 
	{
		/*
			A crude way of drawing the collision shapes in the given region.
			Useful for debugging.
			
			Since dynamic shapes may contain the colmesh itself, this script needs a recursion counter.
		*/
		if (is_undefined(region))
		{	//Exit if the given region is undefined
			exit;
		}
		if (region < 0)
		{
			region = shapeList;
		}
	
		//Create triangle vbuffer if it does not exist
		var triVbuff = global.ColMeshDebugShapes[eColMeshShape.Mesh];
		if (triVbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Mesh] = vertex_create_buffer();
			triVbuff = global.ColMeshDebugShapes[eColMeshShape.Mesh];
		}
		if (cmRecursion == 0)
		{
			vertex_begin(triVbuff, global.ColMeshFormat);
		}
		
		var sh = shader_current();
		shader_set(sh_colmesh_debug);
		var n = ds_list_size(region);
		var W = matrix_get(matrix_world);
	
		for (var i = 0; i < n; i ++)
		{
			var shape = region[| i];
			var t = ds_list_find_index(shapeList, shape);
			var alpha = 1 - (t < 0) * .5;
			var col = make_color_hsv((t * 10) mod 255, 255, 255 * alpha);
			if (is_array(shape))
			{
				var V = shape;
				if (cmRecursion > 0)
				{
					var v = matrix_transform_vertex(W, V[0], V[1], V[2]);
					var v1x = v[0], v1y = v[1], v1z = v[2];
					var v = matrix_transform_vertex(W, V[3], V[4], V[5]);
					var v2x = v[0], v2y = v[1], v2z = v[2];
					var v = matrix_transform_vertex(W, V[6], V[7], V[8]);
					var v3x = v[0], v3y = v[1], v3z = v[2];
					var v = colmesh_matrix_transform_vector(W, V[9], V[10], V[11]);
					var nx = v[0], ny = v[1], nz = v[2];
				}
				else
				{
					var v1x = V[0], v1y = V[1], v1z = V[2];
					var v2x = V[3], v2y = V[4], v2z = V[5];
					var v3x = V[6], v3y = V[7], v3z = V[8];
					var nx  = V[9], ny  = V[10], nz = V[11];
				}
				vertex_position_3d(triVbuff, v1x, v1y, v1z);
				vertex_normal(triVbuff, nx, ny, nz);
				vertex_texcoord(triVbuff, 0, 0);
				vertex_color(triVbuff, col, 1);
	
				vertex_position_3d(triVbuff, v2x, v2y, v2z);
				vertex_normal(triVbuff, nx, ny, nz);
				vertex_texcoord(triVbuff, 1, 0);
				vertex_color(triVbuff, col, 1);
	
				vertex_position_3d(triVbuff, v3x, v3y, v3z);
				vertex_normal(triVbuff, nx, ny, nz);
				vertex_texcoord(triVbuff, 0, 1);
				vertex_color(triVbuff, col, 1);
				continue;
			}
			
			shader_set_uniform_f(shader_get_uniform(sh_colmesh_debug, "u_color"), color_get_red(col) / 255, color_get_green(col) / 255, color_get_blue(col) / 255, 1);
			++cmRecursion;
			shape.debugDraw(tex);
			--cmRecursion;
		}
	
		if (cmRecursion == 0)
		{
			matrix_set(matrix_world, W);
			shader_set_uniform_f(shader_get_uniform(sh_colmesh_debug, "u_radius"), 0);
			shader_set_uniform_f(shader_get_uniform(sh_colmesh_debug, "u_color"), 1, 1, 1, 1);
			vertex_end(triVbuff);
			vertex_submit(triVbuff, pr_trianglelist, tex);
			shader_set(sh);
		}
	}
	
	static toString = function()
    {
		var str = "ColMesh with " + string(ds_list_size(shapeList)) + " shapes, and ";
		str += ds_exists(spHash, ds_type_map) ? string(ds_map_size(spHash)) : "zero";
		str += " regions.";
        return str;
    }

	#endregion
}