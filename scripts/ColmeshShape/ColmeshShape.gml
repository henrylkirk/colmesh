/*
	ColMesh - 3D Collisions Made Easy!
	TheSnidr 2021
	
	License
	The ColMesh system is licensed under a CreativeCommons Attribution 4.0 International License
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

enum eColMeshShape {
	// Do not change the order of these. Changing the order will break saving and loading. Add new entries before "Num".
	Mesh, Sphere, Capsule, Cylinder, Torus, Cube, Block, Dynamic, None, Disk, Cone, Trigger, Heightmap, Num
}

function ColmeshShape() constructor {
	/*
		This is the parent struct for all the other possible collision shapes!
		This is also the parent struct for the ColMesh itself. Weird, huh?
		That is because of some optimizations for triangle meshes. It's much faster to read
		triangle info from a ds_grid than it is to store every triangle as its own struct, 
		so triangles are only saved as indices, and read from the ds_grid when necessary.
		
		This struct contains a bunch of functions that are overwritten for the child structs.
	*/
	type = eColMeshShape.Mesh;
	solid = true;
	
	/// @function set_trigger(solid, colFunc*, rayFunc*)
	/// @description Marks this shape as a trigger
	static set_trigger = function(_solid, _colFunc, _rayFunc){
		
		
		//You can give the shape custom collision functions.
		//These custom functions are NOT saved when writing the ColMesh to a buffer
		//You have access to the following global variables in the custom functions:
		//	CM_COL - An array containing the current position of the calling object
		//	CM_CALLING_OBJECT - The instance that is currently checking for collisions
			
		//colFunc lets you give the shape a custom collision function.
		//This is useful for example for collisions with collectible objects like coins and powerups.
		
		//rayFunc lets you give the shape a custom function that is executed if a ray hits the shape.
		
		type = eColMeshShape.Trigger;
		solid = _solid;
		colFunc = _colFunc;
		rayFunc = _rayFunc;
	}
	
	#region Shared functions
	
	/// @function capsule_collision(x, y, z, xup, yup, zup, radius, height)
	/// @description Returns true if the given capsule collides with the shape
	static capsule_collision = function(x, y, z, xup, yup, zup, radius, height){
		if (height != 0){
			var p = capsule_get_ref(x, y, z, xup, yup, zup, height);
			return (get_priority(p[0], p[1], p[2], radius) >= 0);
		}
		return (get_priority(x, y, z, radius) >= 0);
	}
	
	/// @function move(colMesh, x, y, z)
	static move = function(colMesh, x, y, z){
		static oldReg = array_create(6);
		array_copy(oldReg, 0, colMesh.get_regions(get_min_max()), 0, 6);
		self.x = x;
		self.y = y;
		self.z = z;
		var newReg = colMesh.get_regions(get_min_max());
		if (!array_equals(oldReg, newReg)){
			global.room_colmesh.remove_shape_from_subdiv(self, oldReg);
			global.room_colmesh.add_shape_to_subdiv(self, newReg, false);
		}
	}
	
	#endregion
	
	#region Shape-specific functions
	
	/// @function get_min_max()
	static get_min_max = function(){
		static min_max = array_create(6);
		min_max[0] = min(triangle[0], triangle[3], triangle[6]);
		min_max[1] = min(triangle[1], triangle[4], triangle[7]);
		min_max[2] = min(triangle[2], triangle[5], triangle[8]);
		min_max[3] = max(triangle[0], triangle[3], triangle[6]);
		min_max[4] = max(triangle[1], triangle[4], triangle[7]);
		min_max[5] = max(triangle[2], triangle[5], triangle[8]);
		return min_max;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	/// @description Will return true if the AABB of this shape overlaps the given AABB
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz){
		return (
			min(triangle[0], triangle[3], triangle[6]) < maxx and 
			min(triangle[1], triangle[4], triangle[7]) < maxy and 
			min(triangle[2], triangle[5], triangle[8]) < maxz and 
			max(triangle[0], triangle[3], triangle[6]) > minx and 
			max(triangle[1], triangle[4], triangle[7]) > miny and 
			max(triangle[2], triangle[5], triangle[8]) > minz);
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	/// @description A supplementary function, not meant to be used by itself. Returns the nearest point along the given capsule to the shape.
	static capsule_get_ref = function(_x, _y, _z, xup, yup, zup, height){
		gml_pragma("forceinline");
		static ret = array_create(3);
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var d = dot_product_3d(xup, yup, zup, nx, ny, nz);
		if (d != 0){
			var trace = dot_product_3d(v1x - _x, v1y - _y, v1z - _z, nx, ny, nz) / d;
			var traceX = _x + xup * trace;
			var traceY = _y + yup * trace;
			var traceZ = _z + zup * trace;
			var p = get_closest_point(traceX, traceY, traceZ);
			d = dot_product_3d(p[0] - _x, p[1] - _y, p[2] - _z, xup, yup, zup);
		}
		else
		{
			d = dot_product_3d(_x - v1x, _y - v1y, _z - v1z, xup, yup, zup);
		}
		d = clamp(d, 0, height);
		ret[@ 0] = _x + xup * d;
		ret[@ 1] = _y + yup * d;
		ret[@ 2] = _z + zup * d;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz){
		var dx = CM_RAY[0] - ox;
		var dy = CM_RAY[1] - oy;
		var dz = CM_RAY[2] - oz;
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var h = dot_product_3d(dx, dy, dz, nx, ny, nz);
		if (h == 0){return false;} // Continue if the ray is parallel to the surface of the triangle (ie. perpendicular to the triangle's normal)
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var h = dot_product_3d(v1x - ox, v1y - oy, v1z - oz, nx, ny, nz) / h;
		if (h < 0 or h > 1){return false;} // Continue if the intersection is too far behind or in front of the ray
		var itsX = ox + dx * h;
		var itsY = oy + dy * h;
		var itsZ = oz + dz * h;

		//Check first edge
		var v2x = triangle[3];
		var v2y = triangle[4];
		var v2z = triangle[5];
		var ax = itsX - v1x;
		var ay = itsY - v1y;
		var az = itsZ - v1z;
		var bx = v2x - v1x;
		var by = v2y - v1y;
		var bz = v2z - v1z;
		var cx = az * by - ay * bz;
		var cy = ax * bz - az * bx;
		var cz = ay * bx - ax * by;
		var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 or t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
	
		//Check second edge
		var v3x = triangle[6];
		var v3y = triangle[7];
		var v3z = triangle[8];
		var ax = itsX - v2x;
		var ay = itsY - v2y;
		var az = itsZ - v2z;
		var bx = v3x - v2x;
		var by = v3y - v2y;
		var bz = v3z - v2z;
		var cx = az * by - ay * bz;
		var cy = ax * bz - az * bx;
		var cz = ay * bx - ax * by;
		var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 or t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
	
		//Check third edge
		var ax = itsX - v3x;
		var ay = itsY - v3y;
		var az = itsZ - v3z;
		var bx = v1x - v3x;
		var by = v1y - v3y;
		var bz = v1z - v3z;
		var cx = az * by - ay * bz;
		var cy = ax * bz - az * bx;
		var cz = ay * bx - ax * by;
		var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 or t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
	
		//The line intersects the triangle. Save the triangle normal and intersection.
		var s = sign(h);
		CM_RAY[0] = itsX;
		CM_RAY[1] = itsY;
		CM_RAY[2] = itsZ;
		CM_RAY[3] = nx * s;
		CM_RAY[4] = ny * s;
		CM_RAY[5] = nz * s;
		CM_RAY[6] = triangle;
		return true;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(x, y, z, xup, yup, zup, height, radius, slope, fast){
		// Check first edge
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var t0 = x - v1x;
		var t1 = y - v1y;
		var t2 = z - v1z;
		var D = dot_product_3d(t0, t1, t2, nx, ny, nz);
		if (abs(D) > radius){
			return false;
		}
		var v2x = triangle[3];
		var v2y = triangle[4];
		var v2z = triangle[5];
		var u0 = v2x - v1x;
		var u1 = v2y - v1y;
		var u2 = v2z - v1z;
		var cx = t2 * u1 - t1 * u2;
		var cy = t0 * u2 - t2 * u0;
		var cz = t1 * u0 - t0 * u1;
		var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
		if (dp < 0){
			var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
			var _nx = t0 - u0 * a;
			var _ny = t1 - u1 * a;
			var _nz = t2 - u2 * a;
			var d = dot_product_3d(_nx, _ny, _nz, _nx, _ny, _nz);
			if (d >= radius * radius){return false;}
			d = sqrt(d);
			if (d <= 0){return false;}
			colmesh_displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
			return true;
		} else {
			// Check second edge
			var v3x = triangle[6];
			var v3y = triangle[7];
			var v3z = triangle[8];
			var t0 = x - v2x;
			var t1 = y - v2y;
			var t2 = z - v2z;
			var u0 = v3x - v2x;
			var u1 = v3y - v2y;
			var u2 = v3z - v2z;
			var cx = t2 * u1 - t1 * u2;
			var cy = t0 * u2 - t2 * u0;
			var cz = t1 * u0 - t0 * u1;
			var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
			if (dp < 0) {
				var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
				var _nx = t0 - u0 * a;
				var _ny = t1 - u1 * a;
				var _nz = t2 - u2 * a;
				var d = dot_product_3d(_nx, _ny, _nz, _nx, _ny, _nz);
				if (d >= radius * radius){return false;}
				d = sqrt(d);
				if (d <= 0){return false;}
				colmesh_displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
				return true;
			} else {
				// Check third edge
				var t0 = x - v3x;
				var t1 = y - v3y;
				var t2 = z - v3z;
				var u0 = v1x - v3x;
				var u1 = v1y - v3y;
				var u2 = v1z - v3z;
				var cx = t2 * u1 - t1 * u2;
				var cy = t0 * u2 - t2 * u0;
				var cz = t1 * u0 - t0 * u1;
				var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
				if (dp < 0){
					var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
					var _nx = t0 - u0 * a;
					var _ny = t1 - u1 * a;
					var _nz = t2 - u2 * a;
					var d = dot_product_3d(_nx, _ny, _nz, _nx, _ny, _nz);
					if (d >= radius * radius){ return false; }
					d = sqrt(d);
					if (d <= 0){ return false; }
					colmesh_displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
					return true;
				}
			}
		}
		var s = sign(D);
		colmesh_displace(nx * s, ny * s, nz * s, xup, yup, zup, radius - abs(D), slope);
		return true;
	}
	
	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(x, y, z, maxR) {
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		gml_pragma("forceinline");
		
		//Check first edge
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var t0 = x - v1x;
		var t1 = y - v1y;
		var t2 = z - v1z;
		var D = dot_product_3d(t0, t1, t2, nx, ny, nz);
		if (abs(D) > maxR){return -1;}
		var v2x = triangle[3];
		var v2y = triangle[4];
		var v2z = triangle[5];
		var u0 = v2x - v1x;
		var u1 = v2y - v1y;
		var u2 = v2z - v1z;
		var cx = t2 * u1 - t1 * u2;
		var cy = t0 * u2 - t2 * u0;
		var cz = t1 * u0 - t0 * u1;
		if (dot_product_3d(cx, cy, cz, nx, ny, nz) < 0){
			var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
			return colmesh_vector_square(u0 * a - t0, u1 * a - t1, u2 * a - t2);
		} else {
			// Check second edge
			var v3x = triangle[6];
			var v3y = triangle[7];
			var v3z = triangle[8];
			var t0 = x - v2x;
			var t1 = y - v2y;
			var t2 = z - v2z;
			var u0 = v3x - v2x;
			var u1 = v3y - v2y;
			var u2 = v3z - v2z;
			var cx = t2 * u1 - t1 * u2;
			var cy = t0 * u2 - t2 * u0;
			var cz = t1 * u0 - t0 * u1;
			if (dot_product_3d(cx, cy, cz, nx, ny, nz) < 0){
				var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
				return colmesh_vector_square(u0 * a - t0, u1 * a - t1, u2 * a - t2);
			}
			else
			{	//Check third edge
				var t0 = x - v3x;
				var t1 = y - v3y;
				var t2 = z - v3z;
				var u0 = v1x - v3x;
				var u1 = v1y - v3y;
				var u2 = v1z - v3z;
				var cx = t2 * u1 - t1 * u2;
				var cy = t0 * u2 - t2 * u0;
				var cz = t1 * u0 - t0 * u1;
				if (dot_product_3d(cx, cy, cz, nx, ny, nz) < 0)
				{
					var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
					return colmesh_vector_square(u0 * a - t0, u1 * a - t1, u2 * a - t2);
				}
			}
		}
		return abs(D);
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(x, y, z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		static ret = array_create(3);
		gml_pragma("forceinline");
		
		//Check first edge
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var v2x = triangle[3];
		var v2y = triangle[4];
		var v2z = triangle[5];
		var t0 = x - v1x;
		var t1 = y - v1y;
		var t2 = z - v1z;
		var u0 = v2x - v1x;
		var u1 = v2y - v1y;
		var u2 = v2z - v1z;
		var cx = t2 * u1 - t1 * u2;
		var cy = t0 * u2 - t2 * u0;
		var cz = t1 * u0 - t0 * u1;
		if (dot_product_3d(cx, cy, cz, nx, ny, nz) < 0)
		{
			var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
			ret[@ 0] = v1x + u0 * a;
			ret[@ 1] = v1y + u1 * a;
			ret[@ 2] = v1z + u2 * a;
			return ret;
		}
		else
		{
			//Check second edge
			var v3x = triangle[6];
			var v3y = triangle[7];
			var v3z = triangle[8];
			var t0 = x - v2x;
			var t1 = y - v2y;
			var t2 = z - v2z;
			var u0 = v3x - v2x;
			var u1 = v3y - v2y;
			var u2 = v3z - v2z;
			var cx = t2 * u1 - t1 * u2;
			var cy = t0 * u2 - t2 * u0;
			var cz = t1 * u0 - t0 * u1;
			if (dot_product_3d(cx, cy, cz, nx, ny, nz) < 0)
			{
				var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
				ret[@ 0] = v2x + u0 * a;
				ret[@ 1] = v2y + u1 * a;
				ret[@ 2] = v2z + u2 * a;
				return ret;
			}
			else
			{
				//Check third edge
				var t0 = x - v3x;
				var t1 = y - v3y;
				var t2 = z - v3z;
				var u0 = v1x - v3x;
				var u1 = v1y - v3y;
				var u2 = v1z - v3z;
				if (dot_product_3d(cx, cy, cz, nx, ny, nz) < 0)
				{
					var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
					ret[@ 0] = v3x + u0 * a;
					ret[@ 1] = v3y + u1 * a;
					ret[@ 2] = v3z + u2 * a;
					return ret;
				}
			}
		}
		var D =  dot_product_3d(t0, t1, t2, nx, ny, nz);
		ret[@ 0] = x - nx * D;
		ret[@ 1] = y - ny * D;
		ret[@ 2] = z - nz * D;
		return ret;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		gml_pragma("forceinline");
		/********************************************************/
		/* AABB-triangle overlap test code                      */
		/* by Tomas Akenine-Möller                              */
		/* Function: int triBoxOverlap(float boxcenter[3],      */
		/*          float boxhalfsize[3],float tri[3][3]); */
		/* History:                                             */
		/*   2001-03-05: released the code in its first version */
		/*   2001-06-18: changed the order of the tests, faster */
		/*                                                      */
		/* Acknowledgement: Many thanks to Pierre Terdiman for  */
		/* suggestions and discussions on how to optimize code. */
		/* Thanks to David Hunt for finding a ">="-bug!         */
		/********************************************************/
		// Source: http://fileadmin.cs.lth.se/cs/Personal/Tomas_Akenine-Moller/pubs/tribox.pdf
		// Modified by Snidr

		/* test in X-direction */
		var v1x = triangle[0];
		var v2x = triangle[3];
		var v3x = triangle[6];
		var d1x = v1x - bX;
		var d2x = v2x - bX;
		var d3x = v3x - bX;
		if (min(d1x, d2x, d3x) > hsize or max(d1x, d2x, d3x) < -hsize){return false;}

		/* test in Y-direction */
		var v1y = triangle[1];
		var v2y = triangle[4];
		var v3y = triangle[7];
		var d1y = v1y - bY;
		var d2y = v2y - bY;
		var d3y = v3y - bY;
		if (min(d1y, d2y, d3y) > hsize or max(d1y, d2y, d3y) < -hsize){return false;}

		/* test in Z-direction */
		var v1z = triangle[2];
		var v2z = triangle[5];
		var v3z = triangle[8];
		var d1z = v1z - bZ;
		var d2z = v2z - bZ;
		var d3z = v3z - bZ;
		if (min(d1z, d2z, d3z) > hsize or max(d1z, d2z, d3z) < -hsize){return false;}
		
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		
		var minx, maxx, miny, maxy, minz, maxz;
		if (nx > 0)
		{
			minx = -hsize;
			maxx = hsize;
		}
		else
		{
			minx = hsize;
			maxx = -hsize;
		}
		if (ny > 0)
		{
			miny = -hsize;
			maxy = hsize;
		}
		else
		{
			miny = hsize;
			maxy = -hsize;
		}
		if (nz > 0)
		{
			minz = -hsize;
			maxz = hsize;
		}
		else
		{
			minz = hsize;
			maxz = -hsize;
		}

		var d = dot_product_3d(d1x, d1y, d1z, nx, ny, nz);
		if (dot_product_3d(minx, miny, minz, nx, ny, nz) > d){return false;}
		if (dot_product_3d(maxx, maxy, maxz, nx, ny, nz) < d){return false;}

		/* Bullet 3:  */
		var fex, fey, fez, p0, p1, p2, ex, ey, ez, rad;
		ex = d2x - d1x;
		ey = d2y - d1y;
		ez = d2z - d1z;
		fex = abs(ex) * hsize;
		fey = abs(ey) * hsize;
		fez = abs(ez) * hsize;
   
		p0 = ez * d1y - ey * d1z;
		p2 = ez * d3y - ey * d3z;
		rad = fez + fey;
		if (min(p0, p2) > rad or max(p0, p2) < -rad){return false;}
   
		p0 = -ez * d1x + ex * d1z;
		p2 = -ez * d3x + ex * d3z;
		rad = fez + fex;
		if (min(p0, p2) > rad or max(p0, p2) < -rad){return false;}
           
		p1 = ey * d2x - ex * d2y;                 
		p2 = ey * d3x - ex * d3y;                 
		rad = fey + fex;
		if (min(p1, p2) > rad or max(p1, p2) < -rad){return false;}

		ex = d3x - d2x;
		ey = d3y - d2y;
		ez = d3z - d2z;
		fex = abs(ex) * hsize;
		fey = abs(ey) * hsize;
		fez = abs(ez) * hsize;
	      
		p0 = ez * d1y - ey * d1z;
		p2 = ez * d3y - ey * d3z;
		rad = fez + fey;
		if (min(p0, p2) > rad or max(p0, p2) < -rad){return false;}
          
		p0 = -ez * d1x + ex * d1z;
		p2 = -ez * d3x + ex * d3z;
		rad = fez + fex;
		if (min(p0, p2) > rad or max(p0, p2) < -rad){return false;}
	
		p0 = ey * d1x - ex * d1y;
		p1 = ey * d2x - ex * d2y;
		rad = fey + fex;
		if (min(p0, p1) > rad or max(p0, p1) < -rad){return false;}

		ex = d1x - d3x;
		ey = d1y - d3y;
		ez = d1z - d3z;
		fex = abs(ex) * hsize;
		fey = abs(ey) * hsize;
		fez = abs(ez) * hsize;

		p0 = ez * d1y - ey * d1z;
		p1 = ez * d2y - ey * d2z;
		rad = fez + fey;
		if (min(p0, p1) > rad or max(p0, p1) < -rad){return false;}

		p0 = -ez * d1x + ex * d1z;
		p1 = -ez * d2x + ex * d2z;
		rad = fez + fex;
		if (min(p0, p1) > rad or max(p0, p1) < -rad){return false;}
	
		p1 = ey * d2x - ex * d2y;
		p2 = ey * d3x - ex * d3y;
		rad = fey + fex;
		if (min(p1, p2) > rad or max(p1, p2) < -rad){return false;}

		return true;
	}
	
	/// @function debug_draw(region*, texture*)
	static debug_draw = function(region, tex) 
	{
		/*
			A crude way of drawing the collision shapes in the given region.
			Useful for debugging.
			
			Since dynamic shapes may contain the colmesh itself, this script needs a recursion counter.
		*/
		if (is_undefined(region))
		{
			exit;
		}
		if (region < 0)
		{
			region = shape_list;
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
	
		//Create triangle vbuffer if it does not exist
		var triVbuff = global.ColMeshDebugShapes[eColMeshShape.Mesh];
		if (triVbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Mesh] = vertex_create_buffer();
			triVbuff = global.ColMeshDebugShapes[eColMeshShape.Mesh];
		}
		if (CM_RECURSION == 0)
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
			var t = ds_list_find_index(shape_list, shape);
			var alpha = 1 - (t < 0) * .5;
			var col = make_color_hsv((t * 10) mod 255, 255, 255 * alpha);
			if (is_array(shape))
			{
				var V = shape;
				if (CM_RECURSION > 0)
				{
					var v = colmesh_matrix_transform_vertex(W, V[0], V[1], V[2]);
					var v1x = v[0], v1y = v[1], v1z = v[2];
					var v = colmesh_matrix_transform_vertex(W, V[3], V[4], V[5]);
					var v2x = v[0], v2y = v[1], v2z = v[2];
					var v = colmesh_matrix_transform_vertex(W, V[6], V[7], V[8]);
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
			++CM_RECURSION;
			shape.debug_draw(tex);
			--CM_RECURSION;
		}
	
		if (CM_RECURSION == 0)
		{
			matrix_set(matrix_world, W);
			shader_set_uniform_f(shader_get_uniform(sh_colmesh_debug, "u_radius"), 0);
			shader_set_uniform_f(shader_get_uniform(sh_colmesh_debug, "u_color"), 1, 1, 1, 1);
			vertex_end(triVbuff);
			vertex_submit(triVbuff, pr_trianglelist, tex);
			shader_set(sh);
		}
	}
	
	#endregion
}

/// @function colmesh_sphere(x, y, z, radius)
function colmesh_sphere(_x, _y, _z, radius) : ColmeshShape() constructor
{
	type = eColMeshShape.Sphere;
	x = _x;
	y = _y;
	z = _z;
	R = radius;
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		minMax[0] = x - R;
		minMax[1] = y - R;
		minMax[2] = z - R;
		minMax[3] = x + R;
		minMax[4] = y + R;
		minMax[5] = z + R;
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (x - R < maxx and y - R < maxy and z - R < maxz and x + R > minx and y + R > miny and z + R > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, xup, yup, zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = clamp(dot_product_3d(x - _x, y - _y, z - _z, xup, yup, zup), 0, height);
		ret[@ 0] = _x + xup * d;
		ret[@ 1] = _y + yup * d;
		ret[@ 2] = _z + zup * d;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		var ray = colmesh_cast_ray_sphere(x, y, z, R, ox, oy, oz, CM_RAY[0], CM_RAY[1], CM_RAY[2]);
		if (is_array(ray))
		{
			var nx = ray[0] - x;
			var ny = ray[1] - y;
			var nz = ray[2] - z;
			var n = sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz));
			if (n > 0)
			{
				CM_RAY[0] = ray[0];
				CM_RAY[1] = ray[1];
				CM_RAY[2] = ray[2];
				CM_RAY[3] = nx / n;
				CM_RAY[4] = ny / n;
				CM_RAY[5] = nz / n;
				CM_RAY[6] = self;
				return true;
			}
		}
		return false;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz));
		if (d > 0)
		{
			var _d = R / d;
			ret[@ 0] = x + dx * _d;
			ret[@ 1] = y + dy * _d;
			ret[@ 2] = z + dz * _d;
			return ret;
		}
		ret[@ 0] = x + R;
		ret[@ 1] = y;
		ret[@ 2] = z;
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, xup, yup, zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		var r = R + radius;
		if (d >= r * r){return false;}
		d = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, xup, yup, zup, r - d, slope);
		}
		return true;
	}
	
	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		var _r = R + maxR;
		if (d > _r * _r) return -1;
		return sqr(max(sqrt(d) - R, 0));
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var distSqr = R * R;
		var d = x - bX + hsize;
		if (d < 0)
		{
			distSqr -= d * d;
		}
		else
		{
			d = x - bX - hsize;
			if (d > 0)
			{
				distSqr -= d * d;
			}
		}
		d = y - bY + hsize;
		if (d < 0)
		{
			distSqr -= d * d;
		}
		else
		{
			d = y - bY - hsize;
			if (d > 0)
			{
				distSqr -= d * d;
			}
		}
		d = z - bZ + hsize;
		if (d < 0)
		{
			distSqr -= d * d;
		}
		else
		{
			d = z - bZ - hsize;
			if (d > 0)
			{
				distSqr -= d * d;
			}
		}
		return (distSqr > 0);
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Sphere];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Sphere] = colmesh_create_sphere(20, 16, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Sphere];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
		M[12] = x;
		M[13] = y;
		M[14] = z;
		
		var W = matrix_get(matrix_world);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), R);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_capsule(x, y, z, xup, yup, zup, radius, height)
function colmesh_capsule(_x, _y, _z, _xup, _yup, _zup, radius, height) : ColmeshShape() constructor
{
	type = eColMeshShape.Capsule;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(dot_product_3d(_xup, _yup, _zup, _xup, _yup, _zup));
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	R = radius;
	H = height;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, H);
	var inv = colmesh_matrix_invert_fast(M, M);
	inv0 = inv[0];	inv1 = inv[1];
	inv4 = inv[4];	inv5 = inv[5];
	inv8 = inv[8];	inv9 = inv[9];
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		minMax[0] = x - R + H * min(0, xup);
		minMax[1] = y - R + H * min(0, yup);
		minMax[2] = z - R + H * min(0, zup);
		minMax[3] = x + R + H * max(0, xup);
		minMax[4] = y + R + H * max(0, yup);
		minMax[5] = z + R + H * max(0, zup);
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (x - R + H * min(0, xup) < maxx and 
			y - R + H * min(0, yup) < maxy and 
			z - R + H * min(0, zup) < maxz and 
			x + R + H * max(0, xup) > minx and 
			y + R + H * max(0, yup) > miny and 
			z + R + H * max(0, zup) > minz)
		return true;
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, _xup, _yup, _zup, height)
	{	
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var upDp = dot_product_3d(_xup, _yup, _zup, xup, yup, zup);
		
		//If the capsules are parallel, finding the nearest point is trivial
		if (upDp == 1)
		{
			var t = dot_product_3d(x - _x, y - _y, z - _z, _xup, _yup, _zup);
			t = clamp(t, 0, height);
			ret[0] = _x + _xup * t;
			ret[1] = _y + _yup * t;
			ret[2] = _z + _zup * t;
			return ret;
		}
		
		//Find the nearest point between the central axis of each capsule. Source: http://geomalgorithms.com/a07-_distance.html
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var w1 = dot_product_3d(dx, dy, dz, xup, yup, zup);
		var w2 = dot_product_3d(dx, dy, dz, _xup, _yup, _zup);
		var s = clamp((w1 - w2 * upDp) / (1 - upDp * upDp), 0, H);
		var t = dot_product_3d(xup * s - dx, yup * s - dy, zup * s - dz, _xup, _yup, _zup);
		t = clamp(t, 0, height);
		ret[0] = _x + _xup * t;
		ret[1] = _y + _yup * t;
		ret[2] = _z + _zup * t;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		var _x = CM_RAY[0],	_y = CM_RAY[1],	_z = CM_RAY[2];
		var dx = _x - ox;
		var dy = _y - oy;
		var dz = _z - oz;
		
		//Transform the ray into the cylinder's local space, and do a 2D ray-circle intersection check
		var lox = dot_product_3d(ox - x, oy - y, oz - z, inv0, inv4, inv8);
		var loy = dot_product_3d(ox - x, oy - y, oz - z, inv1, inv5, inv9);
		var ldx = dot_product_3d(dx, dy, dz, inv0, inv4, inv8);
		var ldy = dot_product_3d(dx, dy, dz, inv1, inv5, inv9);
		var a = ldx * ldx + ldy * ldy;
		var b = - ldx * lox - ldy * loy;
		var c = lox * lox + loy * loy - 1;
		var k = b * b - a * c;
		if (k <= 0) return false;
		k = sqrt(k);
		var t = (b - k) / a;
		if (t > 1 or t < 0) return false;
		
		//Find the 3D intersection
		var itsX = ox + dx * t;
		var itsY = oy + dy * t;
		var itsZ = oz + dz * t;
		var d = dot_product_3d(itsX - x, itsY - y, itsZ - z, xup, yup, zup);
		var _d = clamp(d, 0, H);
		var tx = x + xup * _d;
		var ty = y + yup * _d;
		var tz = z + zup * _d;
		if (d < 0 or d > H)
		{	//The intersection is outside the end of the capsule. Do a spherical ray cast at the nearest endpoint
			var ray = colmesh_cast_ray_sphere(tx, ty, tz, R, ox, oy, oz, _x, _y, _z);
			if (!is_array(ray)){return false;}
			itsX = ray[0];
			itsY = ray[1];
			itsZ = ray[2];
		}
		var nx = itsX - tx;
		var ny = itsY - ty;
		var nz = itsZ - tz;
		var n = 1 / sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz));
		CM_RAY[0] = itsX;
		CM_RAY[1] = itsY;
		CM_RAY[2] = itsZ;
		CM_RAY[3] = nx * n;
		CM_RAY[4] = ny * n;
		CM_RAY[5] = nz * n;
		CM_RAY[6] = self;
		return true;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		d = clamp(d, 0, H);
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var d = sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz));
		if (d > 0)
		{
			var r = R / d;
			ret[@ 0] = tx + dx * r;
			ret[@ 1] = ty + dy * r;
			ret[@ 2] = tz + dz * r;
			return ret;
		}
		ret[@ 0] = tx + R;
		ret[@ 1] = ty;
		ret[@ 2] = tz;
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		var D = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		var r = R + radius;
		if (d >= r * r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, r - d, slope);
		}
		return true;
	}

	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var D = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D
		var d = colmesh_vector_square(_x - tx, _y - ty, _z - tz);
		var _r = R + maxR;
		if (d > _r * _r) return -1;
		return sqr(max(sqrt(d) - R, 0));
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = get_closest_point(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize or abs(dy) > hsize or abs(dz) > hsize) return false;
		return true;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Capsule];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Capsule] = colmesh_create_capsule(20, 20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Capsule];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, 1, 1, H, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), R);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_cylinder(x, y, z, xup, yup, zup, radius, height)
function colmesh_cylinder(_x, _y, _z, _xup, _yup, _zup, radius, height) : ColmeshShape() constructor
{
	type = eColMeshShape.Cylinder;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(dot_product_3d(_xup, _yup, _zup, _xup, _yup, _zup));
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	R = radius;
	H = height;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, H);
	var inv = colmesh_matrix_invert_fast(M, M);
	inv0 = inv[0]; inv1 = inv[1];
	inv4 = inv[4]; inv5 = inv[5];
	inv8 = inv[8]; inv9 = inv[9];
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		minMax[0] = x - R + H * min(0, xup);
		minMax[1] = y - R + H * min(0, yup);
		minMax[2] = z - R + H * min(0, zup);
		minMax[3] = x + R + H * max(0, xup);
		minMax[4] = y + R + H * max(0, yup);
		minMax[5] = z + R + H * max(0, zup);
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (
			x - R + H * min(0, xup) < maxx and 
			y - R + H * min(0, yup) < maxy and 
			z - R + H * min(0, zup) < maxz and 
			x + R + H * max(0, xup) > minx and 
			y + R + H * max(0, yup) > miny and 
			z + R + H * max(0, zup) > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var upDp = dot_product_3d(_xup, _yup, _zup, xup, yup, zup);
		
		//If the capsules are parallel, finding the nearest point is trivial
		if (upDp == 1)
		{
			var t = clamp(_xup * (x - _x) + _yup * (y - _y) + _zup * (z - _z), 0, height);
			ret[0] = _x + _xup * t;
			ret[1] = _y + _yup * t;
			ret[2] = _z + _zup * t;
			return ret;
		}
		
		//Find the nearest point between the central axis of each shape. Source: http://geomalgorithms.com/a07-_distance.html
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var w1 = dot_product_3d(dx, dy, dz, xup, yup, zup);
		var w2 = dot_product_3d(dx, dy, dz, _xup, _yup, _zup);
		var s = (w1 - w2 * upDp) / (1 - upDp * upDp);
		if (s > 0 and s < H)
		{
			var t = dot_product_3d(xup * s - dx, yup * s - dy, zup * s - dz, _xup, _yup, _zup);
			t = clamp(t, 0, height);
			ret[0] = _x + _xup * t;
			ret[1] = _y + _yup * t;
			ret[2] = _z + _zup * t;
			return ret;
		}
		
		//If the given point is outside either end of the cylinder, find the nearest point to the terminal plane instead
		s = clamp(s, 0, H);
		var traceX = x + xup * s;
		var traceY = y + yup * s;
		var traceZ = z + zup * s;
		var d = dot_product_3d(_xup, _yup, _zup, xup, yup, zup);
		if (d != 0)
		{
			var trace = dot_product_3d(traceX - _x, traceY - _y, traceZ - _z, xup, yup, zup) / d;
			var traceX = _x + _xup * trace;
			var traceY = _y + _yup * trace;
			var traceZ = _z + _zup * trace;
			var p = get_closest_point(traceX, traceY, traceZ);
			d = dot_product_3d(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
		}
		else
		{
			d = dot_product_3d(traceX - _x, traceY - _y, traceZ - _z, _xup, _yup, _zup);
		}
		var t = clamp(d, 0, height);
		ret[0] = _x + _xup * t;
		ret[1] = _y + _yup * t;
		ret[2] = _z + _zup * t;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		gml_pragma("forceinline");
		var _x = CM_RAY[0],	_y = CM_RAY[1],	_z = CM_RAY[2];
		var dx = _x - ox,	dy = _y - oy,	dz = _z - oz;
		
		//Transform the ray into the cylinder's local space, and do a 2D ray-circle intersection check
		var lox = dot_product_3d(ox - x, oy - y, oz - z, inv0, inv4, inv8);
		var loy = dot_product_3d(ox - x, oy - y, oz - z, inv1, inv5, inv9);
		var ldx = dot_product_3d(dx, dy, dz, inv0, inv4, inv8);
		var ldy = dot_product_3d(dx, dy, dz, inv1, inv5, inv9);
		var a = ldx * ldx + ldy * ldy;
		var b = - ldx * lox - ldy * loy;
		var c = lox * lox + loy * loy - 1;
		var k = b * b - a * c;
		if (k <= 0){return false;}
		k = sqrt(k);
		var t = (b - k) / a;
		if (t > 1){return false;}
		var inside = false;
		if (t < 0)
		{
			t = (b + k) / a;
			inside = true;
			if (t < 0){return false;}
		}
		
		//Find the 3D intersection
		var itsX = ox + dx * t;
		var itsY = oy + dy * t;
		var itsZ = oz + dz * t;
		var d = dot_product_3d(itsX - x, itsY - y, itsZ - z, xup, yup, zup);
		if (d < 0 or d > H or inside)
		{	//The intersection is outside the end of the capsule. Do a plane intersection at the endpoint
			d = dot_product_3d(ox - x, oy - y, oz - z, xup, yup, zup);
			d = clamp(d, 0, H);
			var tx = x + xup * d;
			var ty = y + yup * d;
			var tz = z + zup * d;
			var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
			var s = - sign(dp);
			if (s == 2 * (d == 0) - 1) return false;
			t = dot_product_3d(tx - ox, ty - oy, tz - oz, xup, yup, zup) / dp;
			if (t < 0 or t > 1){return false;}
			var itsX = ox + dx * t;
			var itsY = oy + dy * t;
			var itsZ = oz + dz * t;
			var dx = itsX - tx;
			var dy = itsY - ty;
			var dz = itsZ - tz;
			if (dot_product_3d(dx, dy, dz, dx, dy, dz) > R * R) return false;
			CM_RAY[0] = itsX;
			CM_RAY[1] = itsY;
			CM_RAY[2] = itsZ;
			CM_RAY[3] = xup * s;
			CM_RAY[4] = yup * s;
			CM_RAY[5] = zup * s;
			CM_RAY[6] = self;
			return true;
		}
		
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var nx = itsX - tx;
		var ny = itsY - ty;
		var nz = itsZ - tz;
		var n = 1 / max(sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz)), 0.00001);
		CM_RAY[0] = itsX;
		CM_RAY[1] = itsY;
		CM_RAY[2] = itsZ;
		CM_RAY[3] = nx * n;
		CM_RAY[4] = ny * n;
		CM_RAY[5] = nz * n;
		CM_RAY[6] = self;
		return true;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		d = clamp(d, 0, H);
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var d = sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz));
		if (d > 0)
		{
			if (d > R)
			{
				var r = R / d;
				dx *= r;
				dy *= r;
				dz *= r;
			}
			ret[@ 0] = tx + dx;
			ret[@ 1] = ty + dy;
			ret[@ 2] = tz + dz;
			return ret;
		}
		ret[@ 0] = tx + R;
		ret[@ 1] = ty;
		ret[@ 2] = tz;
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		var D = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var r = R + radius;
		if (D <= 0 or D >= H)
		{
			var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
			if (d > R * R)
			{
				var _d = R / sqrt(d);
				dx *= _d;
				dy *= _d;
				dz *= _d;
			}
			dx = _x - tx - dx;
			dy = _y - ty - dy;
			dz = _z - tz - dz;
			r = radius;
		}
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d >= r * r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, r - d, slope);
		}
		return true;
	}

	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var D = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		if (D <= 0 or D >= H)
		{
			var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = colmesh_vector_square(dx, dy, dz);
			if (d > R * R)
			{
				var _d = R / sqrt(d);
				dx *= _d;
				dy *= _d;
				dz *= _d;
			}
			dx = _x - tx - dx;
			dy = _y - ty - dy;
			dz = _z - tz - dz;
			var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
			if (d > maxR * maxR) return -1;
			return d;
		}
		var d = max(sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz)) - R, 0);
		if (d > maxR) return -1;
		return d * d;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = get_closest_point(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize or abs(dy) > hsize or abs(dz) > hsize) return false;
		return true;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Cylinder];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Cylinder] = colmesh_create_cylinder(20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Cylinder];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, H, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), 0);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_cone(x, y, z, xup, yup, zup, radius, height)
function colmesh_unfinished_cone(_x, _y, _z, _xup, _yup, _zup, radius, height) : ColmeshShape() constructor
{
	type = eColMeshShape.Cone;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(dot_product_3d(_xup, _yup, _zup, _xup, _yup, _zup));
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	R = radius;
	H = height;
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		minMax[0] = x - R + H * min(0, xup);
		minMax[1] = y - R + H * min(0, yup);
		minMax[2] = z - R + H * min(0, zup);
		minMax[3] = x + R + H * max(0, xup);
		minMax[4] = y + R + H * max(0, yup);
		minMax[5] = z + R + H * max(0, zup);
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var minMax = get_min_max();
		if (minMax[0] < maxx and minMax[1] < maxy and minMax[2] < maxz and minMax[3] > minx and minMax[4] > miny and minMax[5] > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		//A supplementary function, not meant to be used by itself.
		//Returns the nearest point along the given capsule to the shape.
		gml_pragma("forceinline");
		static ret = array_create(3);
		var upDp = _xup * xup + _yup * yup + _zup * zup;
		
		//If the capsules are parallel, finding the nearest point is trivial
		if (upDp == 1)
		{
			var t = clamp(_xup * (x - _x) + _yup * (y - _y) + _zup * (z - _z), 0, height);
			ret[0] = _x + _xup * t;
			ret[1] = _y + _yup * t;
			ret[2] = _z + _zup * t;
			return ret;
		}
		
		//Find the nearest point between the central axis of each capsule. Source: http://geomalgorithms.com/a07-_distance.html
		var w1 = (_x - x) * xup + (_y - y) * yup + (_z - z) * zup;
		var w2 = (_x - x) * _xup + (_y - y) * _yup + (_z - z) * _zup;
		var s = (w1 - w2 * upDp) / (1 - upDp * upDp);
		if (s > 0 and s < H)
		{
			var t = clamp(_xup * (x + xup * s - _x) + _yup * (y + yup * s - _y) + _zup * (z + zup * s - _z), 0, height);
			ret[0] = _x + _xup * t;
			ret[1] = _y + _yup * t;
			ret[2] = _z + _zup * t;
			return ret;
		}
		
		//If the given point is outside either end of the cylinder, find the nearest point to the terminal plane instead
		s = clamp(s, 0, H);
		var traceX = x + xup * s;
		var traceY = y + yup * s;
		var traceZ = z + zup * s;
		var d = (_xup * xup + _yup * yup + _zup * zup);
		if (d != 0)
		{
			var trace = ((traceX - _x) * xup + (traceY - _y) * yup + (traceZ - _z) * zup) / d;
			var traceX = _x + _xup * trace;
			var traceY = _y + _yup * trace;
			var traceZ = _z + _zup * trace;
			var p = get_closest_point(traceX, traceY, traceZ);
			d = (p[0] - _x) * _xup + (p[1] - _y) * _yup + (p[2] - _z) * _zup;
		}
		else
		{
			d = (traceX - _x) * _xup + (traceY - _y) * _yup + (traceZ - _z) * _zup;
		}
		var t = clamp(d, 0, height);
		ret[0] = _x + _xup * t;
		ret[1] = _y + _yup * t;
		ret[2] = _z + _zup * t;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		gml_pragma("forceinline");
		var _x = CM_RAY[0],	_y = CM_RAY[1],	_z = CM_RAY[2];
		var dx = _x - ox,	dy = _y - oy,	dz = _z - oz;
		
		//Transform the ray into the cylinder's local space, and do a 2D ray-circle intersection check
		var lox = inv0 * (ox - x) + inv4 * (oy - y) + inv8 * (oz - z);
		var loy = inv1 * (ox - x) + inv5 * (oy - y) + inv9 * (oz - z);
		var ldx = inv0 * dx + inv4 * dy + inv8 * dz;
		var ldy = inv1 * dx + inv5 * dy + inv9 * dz;
		var a = (ldx * ldx + ldy * ldy);
		var b = - (ldx * lox + ldy * loy);
		var c = lox * lox + loy * loy - 1;
		var k = b * b - a * c;
		if (k <= 0){return false;}
		k = sqrt(k);
		var t = (b - k) / a;
		if (t > 1){return false;}
		var inside = false;
		if (t < 0)
		{
			t = (b + k) / a;
			inside = true;
			if (t < 0){return false;}
		}
		
		//Find the 3D intersection
		var itsX = ox + dx * t;
		var itsY = oy + dy * t;
		var itsZ = oz + dz * t;
		var d = (itsX - x) * xup + (itsY - y) * yup + (itsZ - z) * zup;
		if (d < 0 or d > H or inside)
		{	//The intersection is outside the end of the capsule. Do a plane intersection at the endpoint
			d = clamp((ox - x) * xup + (oy - y) * yup + (oz - z) * zup, 0, H);
			var tx = x + xup * d;
			var ty = y + yup * d;
			var tz = z + zup * d;
			var dp = dx * xup + dy * yup + dz * zup;
			var s = - sign(dp);
			if (s == 2 * (d == 0) - 1) return false;
			t = - ((ox - tx) * xup + (oy - ty) * yup + (oz - tz) * zup) / dp;
			if (t < 0 or t > 1){return false;}
			var itsX = ox + dx * t;
			var itsY = oy + dy * t;
			var itsZ = oz + dz * t;
			var dx = itsX - tx;
			var dy = itsY - ty;
			var dz = itsZ - tz;
			if (dot_product_3d(dx, dy, dz, dx, dy, dz) > R * R) return false;
			CM_RAY[0] = itsX;
			CM_RAY[1] = itsY;
			CM_RAY[2] = itsZ;
			CM_RAY[3] = xup * s;
			CM_RAY[4] = yup * s;
			CM_RAY[5] = zup * s;
			CM_RAY[6] = self;
			return true;
		}
		
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var nx = itsX - tx;
		var ny = itsY - ty;
		var nz = itsZ - tz;
		var n = 1 / max(sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz)), 0.00001);
		CM_RAY[0] = itsX;
		CM_RAY[1] = itsY;
		CM_RAY[2] = itsZ;
		CM_RAY[3] = nx * n;
		CM_RAY[4] = ny * n;
		CM_RAY[5] = nz * n;
		CM_RAY[6] = self;
		return true;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = clamp(dx * xup + dy * yup + dz * zup, 0, H);
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var dp = dx * xup + dy * yup + dz * zup;
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var d = dx * dx + dy * dy + dz * dz;
		if (d > 0)
		{
			if (d > R * R)
			{
				var r = R / sqrt(d);
				dx *= r;
				dy *= r;
				dz *= r;
			}
			ret[@ 0] = tx + dx;
			ret[@ 1] = ty + dy;
			ret[@ 2] = tz + dz;
			return ret;
		}
		ret[@ 0] = tx + R;
		ret[@ 1] = ty;
		ret[@ 2] = tz;
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		var D = clamp((_x - x) * xup + (_y - y) * yup + (_z - z) * zup, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var _r = R + radius;
		if (D <= 0 or D >= H)
		{
			var dp = dx * xup + dy * yup + dz * zup;
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = dx * dx + dy * dy + dz * dz;
			if (d > R * R)
			{
				var _d = R / sqrt(d);
				dx *= _d;
				dy *= _d;
				dz *= _d;
			}
			dx = _x - tx - dx;
			dy = _y - ty - dy;
			dz = _z - tz - dz;
			_r = radius;
		}
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d >= _r * _r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, _r - d, slope);
		}
		return true;
	}

	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var D = clamp((_x - x) * xup + (_y - y) * yup + (_z - z) * zup, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		if (D <= 0 or D >= H)
		{
			var dp = dx * xup + dy * yup + dz * zup;
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = dx * dx + dy * dy + dz * dz;
			if (d > R * R)
			{
				var _d = R / sqrt(d);
				dx *= _d;
				dy *= _d;
				dz *= _d;
			}
			dx = _x - tx - dx;
			dy = _y - ty - dy;
			dz = _z - tz - dz;
			var d = dx * dx + dy * dy + dz * dz;
			if (d > maxR * maxR) return -1;
			return d;
		}
		var d = max(sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz)) - R, 0);
		if (d > maxR) return -1;
		return d * d;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = get_closest_point(bX, bY, bZ);
		var dx = p[0] - bX, dy = p[1] - bY, dz = p[2] - bZ;
		if (abs(dx) > hsize or abs(dy) > hsize or abs(dz) > hsize) return false;
		return true;
	}
	
	#endregion
}

/// @function colmesh_torus(x, y, z, xup, yup, zup, R, r)
function colmesh_torus(_x, _y, _z, _xup, _yup, _zup, _R, _r) : ColmeshShape() constructor
{
	type = eColMeshShape.Torus;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(dot_product_3d(_xup, _yup, _zup, _xup, _yup, _zup));
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	R = _R;
	r = _r;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R);
	var inv = colmesh_matrix_invert_fast(M, M);
	inv0 = inv[0];	inv1 = inv[1];	inv2 = inv[2];
	inv4 = inv[4];	inv5 = inv[5];	inv6 = inv[6];
	inv8 = inv[8];	inv9 = inv[9];	inv10 = inv[10];
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		var rr = R + r;
		minMax[0] = x - rr;
		minMax[1] = y - rr;
		minMax[2] = z - rr;
		minMax[3] = x + rr;
		minMax[4] = y + rr;
		minMax[5] = z + rr;
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var rr = R + r;
		if (x - rr < maxx and y - rr < maxy and z - rr < maxz and x + rr > minx and y + rr > miny and z + rr > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = dot_product_3d(_xup, _yup, _zup, xup, yup, zup);
		if (d != 0)
		{
			var d = dot_product_3d(x - _x, y - _y, z - _z, xup, yup, zup) / d;
			repeat 2
			{
				var p = _getRingCoord(_x + _xup * d, _y + _yup * d, _z + _zup * d);
				d = dot_product_3d(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
				d = clamp(d, 0, height);
			}
		}
		else
		{
			d = dot_product_3d(x - _x, y - _y, z - _z, _xup, _yup, _zup);
			d = clamp(d, 0, height);
		}
		ret[0] = _x + _xup * d;
		ret[1] = _y + _yup * d;
		ret[2] = _z + _zup * d;
		return ret;
	}
	
	/// @function _getRingCoord(x, y, z)
	static _getRingCoord = function(_x, _y, _z)
	{
		gml_pragma("forceinline");
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var l = sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz));
		if (l > 0)
		{
			var _d = R / l;
			ret[0] = x + dx * _d;
			ret[1] = y + dy * _d;
			ret[2] = z + dz * _d;
			return ret;
		}
		ret[0] = x;
		ret[1] = y;
		ret[2] = z;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		/*
			Algorithm created by TheSnidr
			This is an approximation using the same principle as ray marching
		*/
		var repetitions = 15;
		
		var _x = CM_RAY[0];
		var _y = CM_RAY[1];
		var _z = CM_RAY[2];
		var dx = _x - ox;
		var dy = _y - oy;
		var dz = _z - oz;
		ox -= x;
		oy -= y;
		oz -= z;
		var lox = dot_product_3d(ox, oy, oz, inv0, inv4, inv8);
		var loy = dot_product_3d(ox, oy, oz, inv1, inv5, inv9);
		var loz = dot_product_3d(ox, oy, oz, inv2, inv6, inv10);
		var ldx = dot_product_3d(dx, dy, dz, inv0, inv4, inv8);
		var ldy = dot_product_3d(dx, dy, dz, inv1, inv5, inv9);
		var ldz = dot_product_3d(dx, dy, dz, inv2, inv6, inv10);
		var l = sqrt(dot_product_3d(ldx, ldy, ldz, ldx, ldy, ldz));
		ldx /= l;
		ldy /= l;
		ldz /= l;
		var p = 0, n = 0, d = 0;
		var radiusRatio = r / R;
		repeat repetitions 
		{
			p = n;
			n = (sqrt(sqr(sqrt(lox * lox + loy * loy) - 1) + loz * loz) - radiusRatio);
			d += n;
			if (p > 0 and n > R) return false; //The ray missed the torus, and we can remove it from the ray casting algorithm
			if (d > l) return false; //The ray did not reach the torus
			lox += ldx * n;	
			loy += ldy * n;
			loz += ldz * n;
		}
		if (n > p) return false; //If the new distance estimate is larger than the previous one, the ray must have missed a close point and is moving away from the object 
		d /= l;
		var itsX = x + ox + dx * d;
		var itsY = y + oy + dy * d;
		var itsZ = z + oz + dz * d;
		var p = _getRingCoord(itsX, itsY, itsZ);
		var nx = itsX - p[0];
		var ny = itsY - p[1];
		var nz = itsZ - p[2];
		var n = 1 / sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz));
		CM_RAY[0] = itsX;
		CM_RAY[1] = itsY;
		CM_RAY[2] = itsZ;
		CM_RAY[3] = nx * n;
		CM_RAY[4] = ny * n;
		CM_RAY[5] = nz * n;
		CM_RAY[6] = self;
		return true;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var p = _getRingCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var d = sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz));
		if (d > 0)
		{
			dx /= d;
			dy /= d;
			dz /= d;
			ret[@ 0] = p[0] + dx * r;
			ret[@ 1] = p[1] + dy * r;
			ret[@ 2] = p[2] + dz * r;
			return ret;
		}
		ret[@ 0] = _x;
		ret[@ 1] = _y;
		ret[@ 2] = _z;
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		gml_pragma("forceinline");
		var p = _getRingCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var _r = r + radius;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d > _r * _r) return false;
		d  = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, _r - d, slope);
		}
		return true;
	}

	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		gml_pragma("forceinline");
		var p = _getRingCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var d = max(sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz)) - r, 0);
		if (d > maxR){return -1;}
		return d * d;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = get_closest_point(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize or abs(dy) > hsize or abs(dz) > hsize) return false;
		return true;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Torus];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Torus] = colmesh_create_torus(32, 20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Torus];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), r);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_disk(x, y, z, xup, yup, zup, R, r)
function colmesh_disk(_x, _y, _z, _xup, _yup, _zup, _R, _r) : ColmeshShape() constructor
{
	type = eColMeshShape.Disk;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(dot_product_3d(_xup, _yup, _zup, _xup, _yup, _zup));
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	R = _R;
	r = _r;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R);
	var inv = colmesh_matrix_invert_fast(M, M);
	inv0 = inv[0];	inv1 = inv[1];	inv2 = inv[2];
	inv4 = inv[4];	inv5 = inv[5];	inv6 = inv[6];
	inv8 = inv[8];	inv9 = inv[9];	inv10 = inv[10];
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		var rr = R + r;
		minMax[0] = x - rr;
		minMax[1] = y - rr;
		minMax[2] = z - rr;
		minMax[3] = x + rr;
		minMax[4] = y + rr;
		minMax[5] = z + rr;
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var rr = R + r;
		if (x - rr < maxx and y - rr < maxy and z - rr < maxz and x + rr > minx and y + rr > miny and z + rr > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = dot_product_3d(_xup, _yup, _zup, xup, yup, zup);
		if (d != 0)
		{
			var d = dot_product_3d(x - _x, y - _y, z - _z, xup, yup, zup) / d;
			var p = _getDiskCoord(_x + _xup * d, _y + _yup * d, _z + _zup * d);
			d = dot_product_3d(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
		}
		else
		{
			d = dot_product_3d(x - _x, y - _y, z - _z, _xup, _yup, _zup);
		}
		d = clamp(d, 0, height);
		ret[0] = _x + _xup * d;
		ret[1] = _y + _yup * d;
		ret[2] = _z + _zup * d;
		return ret;
	}
	
	/// @function _getDiskCoord(x, y, z)
	static _getDiskCoord = function(_x, _y, _z)
	{
		gml_pragma("forceinline");
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var l = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (l <= R * R)
		{
			ret[0] = x + dx;
			ret[1] = y + dy;
			ret[2] = z + dz;
			return ret;
		}
		var _d = R / sqrt(l);
		ret[0] = x + dx * _d;
		ret[1] = y + dy * _d;
		ret[2] = z + dz * _d;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		/*
			Algorithm created by TheSnidr
			This is an approximation using the same principle as ray marching
		*/
		var repetitions = 15;
		
		var _x = CM_RAY[0];
		var _y = CM_RAY[1];
		var _z = CM_RAY[2];
		var dx = _x - ox;
		var dy = _y - oy;
		var dz = _z - oz;
		ox -= x;
		oy -= y;
		oz -= z;
		var lox = dot_product_3d(ox, oy, oz, inv0, inv4, inv8);
		var loy = dot_product_3d(ox, oy, oz, inv1, inv5, inv9);
		var loz = dot_product_3d(ox, oy, oz, inv2, inv6, inv10);
		var ldx = dot_product_3d(dx, dy, dz, inv0, inv4, inv8);
		var ldy = dot_product_3d(dx, dy, dz, inv1, inv5, inv9);
		var ldz = dot_product_3d(dx, dy, dz, inv2, inv6, inv10);
		var l = colmesh_vector_magnitude(ldx, ldy, ldz);
		ldx /= l;
		ldy /= l;
		ldz /= l;
		var p = 0, n = 0, d = 0;
		var radiusRatio = r / R;
		repeat repetitions 
		{
			p = n;
			n = (sqrt(sqr(max(0., sqrt(lox * lox + loy * loy) - 1)) + loz * loz) - radiusRatio);
			d += n;
			if (p > 0 and n > R) return false; //The ray missed the torus, and we can remove it from the ray casting algorithm
			if (d > l) return false; //The ray did not reach the torus
			lox += ldx * n;	
			loy += ldy * n;
			loz += ldz * n;
		}
		if (n > p) return false; //If the new distance estimate is larger than the previous one, the ray must have missed a close point and is moving away from the object 
		d /= l;
		var itsX = x + ox + dx * d;
		var itsY = y + oy + dy * d;
		var itsZ = z + oz + dz * d;
		var p = _getDiskCoord(itsX, itsY, itsZ);
		var nx = itsX - p[0];
		var ny = itsY - p[1];
		var nz = itsZ - p[2];
		var n = sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz));
		if (n == 0){return true;}
		var n = 1 / n;
		CM_RAY[0] = itsX;
		CM_RAY[1] = itsY;
		CM_RAY[2] = itsZ;
		CM_RAY[3] = nx * n;
		CM_RAY[4] = ny * n;
		CM_RAY[5] = nz * n;
		CM_RAY[6] = self;
		return true;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var p = _getDiskCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var d = sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz));
		if (d > 0)
		{
			dx /= d;
			dy /= d;
			dz /= d;
			ret[@ 0] = p[0] + dx * r;
			ret[@ 1] = p[1] + dy * r;
			ret[@ 2] = p[2] + dz * r;
			return ret;
		}
		ret[@ 0] = _x;
		ret[@ 1] = _y;
		ret[@ 2] = _z;
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		gml_pragma("forceinline");
		var p = _getDiskCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var _r = r + radius;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d > _r * _r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, _r - d, slope);
		}
		return true;
	}

	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		gml_pragma("forceinline");
		var p = _getDiskCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var d = max(sqrt(dot_product_3d(dx, dy, dz, dx, dy, dz)) - r, 0);
		if (d > maxR){return -1;}
		return d * d;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = get_closest_point(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize or abs(dy) > hsize or abs(dz) > hsize) return false;
		return true;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Disk];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Disk] = colmesh_create_disk(32, 20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Disk];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), r);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_cube(x, y, z, xsize, ysize, zsize)
function colmesh_cube(_x, _y, _z, xsize, ysize, zsize) : ColmeshShape() constructor
{
	type = eColMeshShape.Cube;
	x = _x;
	y = _y;
	z = _z;
	halfX = xsize / 2;
	halfY = ysize / 2;
	halfZ = zsize / 2;
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		minMax[0] = x - halfX;
		minMax[1] = y - halfY;
		minMax[2] = z - halfZ;
		minMax[3] = x + halfX;
		minMax[4] = y + halfY;
		minMax[5] = z + halfZ;
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (x - halfX < maxx and y - halfY < maxy and z - halfZ < maxz and x + halfX > minx and y + halfY > miny and z + halfZ > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, xup, yup, zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		
		//Check bottom of capsule
		var xx = _x - x;
		var yy = _y - y;
		var zz = _z - z;
		var bx = clamp(xx / halfX, -1, 1);
		var by = clamp(yy / halfY, -1, 1);
		var bz = clamp(zz / halfZ, -1, 1);
		var px = x + bx * halfX;
		var py = y + by * halfY;
		var pz = z + bz * halfZ;
		var d = dot_product_3d(px - _x, py - _y, pz - _z, xup, yup, zup);
		d = clamp(d, 0, height);
		var rx1 = _x + xup * d;
		var ry1 = _y + yup * d;
		var rz1 = _z + zup * d;
		var d1 = colmesh_vector_square(rx1 - px, ry1 - py, rz1 - pz);
		
		//Check top of capsule
		xx += xup * height;
		yy += yup * height;
		zz += zup * height;
		var bx = clamp(xx / halfX, -1, 1);
		var by = clamp(yy / halfY, -1, 1);
		var bz = clamp(zz / halfZ, -1, 1);
		var px = x + bx * halfX;
		var py = y + by * halfY;
		var pz = z + bz * halfZ;
		var d = dot_product_3d(px - _x, py - _y, pz - _z, xup, yup, zup);
		d = clamp(d, 0, height);
		var rx2 = _x + xup * d;
		var ry2 = _y + yup * d;
		var rz2 = _z + zup * d;
		var d2 = colmesh_vector_square(rx2 - px, ry2 - py, rz2 - pz);
		if (d2 < d1)
		{
			ret[0] = rx2;
			ret[1] = ry2;
			ret[2] = rz2;
			return ret;
		}
		ret[0] = rx1;
		ret[1] = ry1;
		ret[2] = rz1;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		//Algorithm created by TheSnidr
		var x1 = (ox - x) / halfX;
		var y1 = (oy - y) / halfY;
		var z1 = (oz - z) / halfZ;
		var x2 = (CM_RAY[0] - x) / halfX;
		var y2 = (CM_RAY[1] - y) / halfY;
		var z2 = (CM_RAY[2] - z) / halfZ;
		
		var nx, ny, nz
		var intersection = false;
		var insideBlock = true;
		if (x2 != x1 and abs(x1) > 1)
		{
			insideBlock = false;
			var s = sign(x1 - x2);
			var t = (s - x1) / (x2 - x1);
			if (t >= 0 and t <= 1)
			{
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 and abs(itsZ) <= 1)
				{
					x2 = s;
					y2 = itsY;
					z2 = itsZ;
					nx = sign(x1);
					ny = 0;
					nz = 0;
					intersection = true;
				}
			}
		}
		if (y2 != y1 and abs(y1) > 1)
		{
			insideBlock = false;
			var s = sign(y1 - y2);
			var t = (s - y1) / (y2 - y1);
			if (t >= 0 and t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 and abs(itsZ) <= 1)
				{
					x2 = itsX;
					y2 = s;
					z2 = itsZ;
					nx = 0;
					ny = sign(y1);
					nz = 0;
					intersection = true;
				}
			}
		}
		if (z2 != z1 and abs(z1) > 1)
		{
			insideBlock = false;
			var s = sign(z1 - z2);
			var t = (s - z1) / (z2 - z1);
			if (t >= 0 and t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 and abs(itsY) <= 1)
				{
					x2 = itsX;
					y2 = itsY;
					z2 = s;
					nx = 0;
					ny = 0;
					nz = sign(z1);
					intersection = true;
				}
			}
		}
		if (insideBlock or !intersection) return false;
		
		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		CM_RAY[0] = x + x2 * halfX;
		CM_RAY[1] = y + y2 * halfY;
		CM_RAY[2] = z + z2 * halfZ;
		CM_RAY[3] = nx;
		CM_RAY[4] = ny;
		CM_RAY[5] = nz;
		CM_RAY[6] = self;
		return true;
	}
		
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		static ret = array_create(3);
		
		//Find normalized block space position
		var bx = (_x - x) / halfX;
		var by = (_y - y) / halfY;
		var bz = (_z - z) / halfZ;
		var b = max(abs(bx), abs(by), abs(bz));
		
		//If the center of the sphere is inside the cube, normalize the largest axis
		if (b <= 1)
		{
			if (b == abs(bx))
			{
				bx = sign(bx);
			}
			else if (b == abs(by))
			{
				by = sign(by);
			}
			else
			{
				bz = sign(bz);
			}
			ret[@ 0] = x + bx * halfX;
			ret[@ 1] = y + by * halfY;
			ret[@ 2] = z + bz * halfZ;
			ret[@ 6] = 0;
		}
		else
		{	//Nearest point on the cube in normalized block space
			bx = clamp(bx, -1, 1);
			by = clamp(by, -1, 1);
			bz = clamp(bz, -1, 1);
			ret[@ 0] = x + bx * halfX;
			ret[@ 1] = y + by * halfY;
			ret[@ 2] = z + bz * halfZ;
		}
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		//Find normalized block space position
		var bx = (_x - x) / halfX;
		var by = (_y - y) / halfY;
		var bz = (_z - z) / halfZ;
		var b = max(abs(bx), abs(by), abs(bz));
		var nx = 0, ny = 0, nz = 0;
		
		//If the center of the sphere is inside the cube, normalize the largest axis
		if (b <= 1)
		{
			if (b == abs(bx))
			{
				bx = sign(bx);
				nx = bx;
			}
			else if (b == abs(by))
			{
				by = sign(by);
				ny = by;
			}
			else
			{
				bz = sign(bz);
				nz = bz;
			}
			var px = x + bx * halfX;
			var py = y + by * halfY;
			var pz = z + bz * halfZ;
			var dx = _x - px;
			var dy = _y - py;
			var dz = _z - pz;
			var d = dot_product_3d(dx, dy, dz, nx, ny, nz);
			colmesh_displace(nx, ny, nz, _xup, _yup, _zup, radius - d, slope);
			return true;
		}
		//Nearest point on the cube in normalized block space
		bx = clamp(bx, -1, 1);
		by = clamp(by, -1, 1);
		bz = clamp(bz, -1, 1);
		var px = x + bx * halfX;
		var py = y + by * halfY;
		var pz = z + bz * halfZ;
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d > radius * radius) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, radius - d, slope);
		}
		return true;
	}
	
	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		//Find normalized block space position
		var bx = (_x - x) / halfX;
		var by = (_y - y) / halfY;
		var bz = (_z - z) / halfZ;
		var b = max(abs(bx), abs(by), abs(bz));
		if (b <= 1)
		{	//If the center of the sphere is inside the cube, normalize the largest axis
			return 0; //0 is the highest possible priority
		}
		//Nearest point on the cube in normalized block space
		bx = clamp(bx, -1, 1);
		by = clamp(by, -1, 1);
		bz = clamp(bz, -1, 1);
		var px = x + bx * halfX;
		var py = y + by * halfY;
		var pz = z + bz * halfZ;
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = dx * dx + dy * dy + dz * dz;
		if (d > maxR * maxR){return -1;}
		return d;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		if (abs(bX - x) > hsize + halfX){return false;}
		if (abs(bY - y) > hsize + halfY){return false;}
		if (abs(bZ - z) > hsize + halfZ){return false;}
		return true;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Cube];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Cube] = colmesh_create_block(1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Cube];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
		M[0]  = halfX;
		M[1]  = 0;
		M[2]  = 0;
		M[4]  = 0;
		M[5]  = halfY;
		M[6]  = 0;
		M[8]  = 0;
		M[9]  = 0;
		M[10] = halfZ;
		M[12] = x;
		M[13] = y;
		M[14] = z;
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), 0);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_block(blockMatrix)
function colmesh_block(M) : ColmeshShape() constructor
{
	type = eColMeshShape.Block;
	x = M[12];
	y = M[13];
	z = M[14];
	
	lx = 1 / colmesh_vector_magnitude(M[0], M[1], M[2]);
	ly = 1 / colmesh_vector_magnitude(M[4], M[5], M[6]);
	lz = 1 / colmesh_vector_magnitude(M[8], M[9], M[10]);
	
	//Remove any potential shear from the matrix
	var m = array_create(16);
	array_copy(m, 0, M, 0, 16);
	colmesh_matrix_orthogonalize(m);
	colmesh_matrix_scale(m, 1/lx, 1/ly, 1/lz);
	
	//Extract necessary info from the matrix
	xto = m[0];
	yto = m[1];
	zto = m[2];
	xsi = m[4];
	ysi = m[5];
	zsi = m[6];
	xup = m[8];
	yup = m[9];
	zup = m[10];
	
	//Invert the matrix
	var inv = colmesh_matrix_invert_fast(m, m);
	inv0  = inv[0];		inv1  = inv[1];		inv2  = inv[2];
	inv4  = inv[4];		inv5  = inv[5];		inv6  = inv[6];
	inv8  = inv[8];		inv9  = inv[9];		inv10 = inv[10];	
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		var dx = abs(xto) + abs(xsi) + abs(xup);
		var dy = abs(yto) + abs(ysi) + abs(yup);
		var dz = abs(zto) + abs(zsi) + abs(zup);
		minMax[0] = x - dx;
		minMax[1] = y - dy;
		minMax[2] = z - dz;
		minMax[3] = x + dx;
		minMax[4] = y + dy;
		minMax[5] = z + dz;
		return minMax;
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var dx = abs(xto) + abs(xsi) + abs(xup);
		var dy = abs(yto) + abs(ysi) + abs(yup);
		var dz = abs(zto) + abs(zsi) + abs(zup);
		if (x - dx < maxx and y - dy < maxy and z - dz < maxz and x + dx > minx and y + dy > miny and z + dz > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @function capsule_get_ref(x, y, z, _xup, _yup, _zup, height)
	static capsule_get_ref = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		
		//Check bottom of capsule
		var xx = _x - x;
		var yy = _y - y;
		var zz = _z - z;
		var bx = clamp(dot_product_3d(xx, yy, zz, inv0, inv4, inv8),  -1, 1);
		var by = clamp(dot_product_3d(xx, yy, zz, inv1, inv5, inv9),  -1, 1);
		var bz = clamp(dot_product_3d(xx, yy, zz, inv2, inv6, inv10), -1, 1);
		var px = x + dot_product_3d(bx, by, bz, xto, xsi, xup);
		var py = y + dot_product_3d(bx, by, bz, yto, ysi, yup);
		var pz = z + dot_product_3d(bx, by, bz, zto, zsi, zup);
		var d = dot_product_3d(px - _x, py - _y, pz - _z, _xup, _yup, _zup);
		d = clamp(d, 0, height);
		var rx1 = _x + _xup * d;
		var ry1 = _y + _yup * d;
		var rz1 = _z + _zup * d;
		var d1 = colmesh_vector_square(rx1 - px, ry1 - py, rz1 - pz);
		
		//Check top of capsule
		xx += _xup * height;
		yy += _yup * height;
		zz += _zup * height;
		var bx = clamp(dot_product_3d(xx, yy, zz, inv0, inv4, inv8),  -1, 1);
		var by = clamp(dot_product_3d(xx, yy, zz, inv1, inv5, inv9),  -1, 1);
		var bz = clamp(dot_product_3d(xx, yy, zz, inv2, inv6, inv10), -1, 1);
		var px = x + dot_product_3d(bx, by, bz, xto, xsi, xup);
		var py = y + dot_product_3d(bx, by, bz, yto, ysi, yup);
		var pz = z + dot_product_3d(bx, by, bz, zto, zsi, zup);
		var d = dot_product_3d(px - _x, py - _y, pz - _z, _xup, _yup, _zup);
		d = clamp(d, 0, height);
		var rx2 = _x + _xup * d;
		var ry2 = _y + _yup * d;
		var rz2 = _z + _zup * d;
		var d2 = colmesh_vector_square(rx2 - px, ry2 - py, rz2 - pz);
		
		if (d2 < d1)
		{
			ret[0] = rx2;
			ret[1] = ry2;
			ret[2] = rz2;
			return ret;
		}
		ret[0] = rx1;
		ret[1] = ry1;
		ret[2] = rz1;
		return ret;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		//Algorithm created by TheSnidr
		ox -= x;
		oy -= y;
		oz -= z;
		var tx = CM_RAY[0] - x;
		var ty = CM_RAY[1] - y;
		var tz = CM_RAY[2] - z;
		var x1 = dot_product_3d(ox, oy, oz, inv0, inv4, inv8);
		var y1 = dot_product_3d(ox, oy, oz, inv1, inv5, inv9);
		var z1 = dot_product_3d(ox, oy, oz, inv2, inv6, inv10);
		var x2 = dot_product_3d(tx, ty, tz, inv0, inv4, inv8);
		var y2 = dot_product_3d(tx, ty, tz, inv1, inv5, inv9);
		var z2 = dot_product_3d(tx, ty, tz, inv2, inv6, inv10);
		var nx = 0, ny = 0, nz = 1;
		var intersection = false;
		var insideBlock = true;
		if (x2 != x1 and abs(x1) > 1)
		{
			insideBlock = false;
			var s = sign(x1 - x2);
			var t = (s - x1) / (x2 - x1);
			if (t >= 0 and t <= 1)
			{
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 and abs(itsZ) <= 1)
				{
					x2 = s;
					y2 = itsY;
					z2 = itsZ;
					s = sign(x1) * lx;
					nx = xto * s;
					ny = yto * s;
					nz = zto * s;
					intersection = true;
				}
			}
		}
		if (y2 != y1 and abs(y1) > 1)
		{
			insideBlock = false;
			var s = sign(y1 - y2);
			var t = (s - y1) / (y2 - y1);
			if (t >= 0 and t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 and abs(itsZ) <= 1)
				{
					x2 = itsX;
					y2 = s;
					z2 = itsZ;
					s = sign(y1) * ly;
					nx = xsi * s;
					ny = ysi * s;
					nz = zsi * s;
					intersection = true;
				}
			}
		}
		if (z2 != z1 and abs(z1) > 1)
		{
			insideBlock = false;
			var s = sign(z1 - z2);
			var t = (s - z1) / (z2 - z1);
			if (t >= 0 and t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 and abs(itsY) <= 1)
				{
					x2 = itsX;
					y2 = itsY;
					z2 = s;
					s = sign(z1) * lz;
					nx = xup * s;
					ny = yup * s;
					nz = zup * s;
					intersection = true;
				}
			}
		}
		if (insideBlock or !intersection) return false;

		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		CM_RAY[0] = x + dot_product_3d(x2, y2, z2, xto, xsi, xup);
		CM_RAY[1] = y + dot_product_3d(x2, y2, z2, yto, ysi, yup);
		CM_RAY[2] = z + dot_product_3d(x2, y2, z2, zto, zsi, zup);
		CM_RAY[3] = nx;
		CM_RAY[4] = ny;
		CM_RAY[5] = nz;
		CM_RAY[6] = self;
		return true;
	}
		
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		static ret = array_create(3);
		
		//Find normalized block space position
		_x -= x;
		_y -= y;
		_z -= z;
		var bx = dot_product_3d(_x, _y, _z, inv0, inv4, inv8);
		var by = dot_product_3d(_x, _y, _z, inv1, inv5, inv9);
		var bz = dot_product_3d(_x, _y, _z, inv2, inv6, inv10);
		var b = max(abs(bx), abs(by), abs(bz));
		
		//If the center of the sphere is inside the cube, normalize the largest axis
		if (b <= 1)
		{
			if (b == abs(bx))
			{
				bx = sign(bx);
			}
			else if (b == abs(by))
			{
				by = sign(by);
			}
			else
			{
				bz = sign(bz);
			}
			
			ret[@ 6] = 0;
		}
		else
		{	//Nearest point on the cube in normalized block space
			bx = clamp(bx, -1, 1);
			by = clamp(by, -1, 1);
			bz = clamp(bz, -1, 1);
		}
		ret[@ 0] = x + dot_product_3d(bx, by, bz, xto, xsi, xup);
		ret[@ 1] = y + dot_product_3d(bx, by, bz, yto, ysi, yup);
		ret[@ 2] = z + dot_product_3d(bx, by, bz, zto, zsi, zup);
		return ret;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		//Find normalized block space position
		var xx = _x - x;
		var yy = _y - y;
		var zz = _z - z;
		var bx = dot_product_3d(xx, yy, zz, inv0, inv4, inv8);
		var by = dot_product_3d(xx, yy, zz, inv1, inv5, inv9);
		var bz = dot_product_3d(xx, yy, zz, inv2, inv6, inv10);
		var b = max(abs(bx), abs(by), abs(bz));
		var nx, ny, nz;
		//If the center of the sphere is inside the cube, normalize the largest axis
		if (b <= 1)
		{
			if (b == abs(bx))
			{
				nx = xto * lx;
				ny = yto * lx;
				nz = zto * lx;
			}
			else if (b == abs(by))
			{
				by = sign(by);
				nx = xsi * ly;
				ny = ysi * ly;
				nz = zsi * ly;
			}
			else
			{
				bz = sign(bz);
				nx = xup * lz;
				ny = yup * lz;
				nz = zup * lz;
			}
			var px = x + dot_product_3d(bx, by, bz, xto, xsi, xup);
			var py = y + dot_product_3d(bx, by, bz, yto, ysi, yup);
			var pz = z + dot_product_3d(bx, by, bz, zto, zsi, zup);
			var dx = _x - px;
			var dy = _y - py;
			var dz = _z - pz;
			var _d = dot_product_3d(dx, dy, dz, nx, ny, nz);
			colmesh_displace(nx, ny, nz, _xup, _yup, _zup, radius - _d, slope);
			return true;
		}
		//Nearest point on the cube in normalized block space
		bx = clamp(bx, -1, 1);
		by = clamp(by, -1, 1);
		bz = clamp(bz, -1, 1);
		var px = x + dot_product_3d(bx, by, bz, xto, xsi, xup);
		var py = y + dot_product_3d(bx, by, bz, yto, ysi, yup);
		var pz = z + dot_product_3d(bx, by, bz, zto, zsi, zup);
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d > radius * radius){return false;}
		d = sqrt(d);
		colmesh_displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, radius - d, slope);
		return true;
	}
	
	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		//Find normalized block space position
		var xx = _x - x;
		var yy = _y - y;
		var zz = _z - z;
		var bx = dot_product_3d(xx, yy, zz, inv0, inv4, inv8);
		var by = dot_product_3d(xx, yy, zz, inv1, inv5, inv9);
		var bz = dot_product_3d(xx, yy, zz, inv2, inv6, inv10);
		if (max(abs(bx), abs(by), abs(bz)) <= 1)
		{	//If the center of the sphere is inside the cube, normalize the largest axis
			return 0; //0 is the highest possible priority
		}
		//Nearest point on the cube in normalized block space
		bx = clamp(bx, -1, 1);
		by = clamp(by, -1, 1);
		bz = clamp(bz, -1, 1);
		var px = x + dot_product_3d(bx, by, bz, xto, xsi, xup);
		var py = y + dot_product_3d(bx, by, bz, yto, ysi, yup);
		var pz = z + dot_product_3d(bx, by, bz, zto, zsi, zup);
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
		if (d > maxR * maxR){return -1;}
		return d;
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		//First check if the nearest point in the AABB to the cube is inside the cube
		var dx = bX - x;
		var dy = bY - y;
		var dz = bZ - z;
		var xx = dx - clamp(dx, -hsize, hsize);
		var yy = dy - clamp(dy, -hsize, hsize);
		var zz = dz - clamp(dz, -hsize, hsize);
		
		//Find normalized block space position
		var bx = dot_product_3d(xx, yy, zz, inv0, inv4, inv8);
		var by = dot_product_3d(xx, yy, zz, inv1, inv5, inv9);
		var bz = dot_product_3d(xx, yy, zz, inv2, inv6, inv10);
		if (max(abs(bx), abs(by), abs(bz)) < 1) return true;
		
		//Then check if the nearest point in the cube is inside the AABB
		var bx = clamp(dot_product_3d(dx, dy, dz, inv0, inv4, inv8),  -1, 1);
		var by = clamp(dot_product_3d(dx, dy, dz, inv1, inv5, inv9),  -1, 1);
		var bz = clamp(dot_product_3d(dx, dy, dz, inv2, inv6, inv10), -1, 1);
		var dx = bX - dot_product_3d(bx, by, bz, xto, xsi, xup);
		var dy = bY - dot_product_3d(bx, by, bz, yto, ysi, yup);
		var dz = bZ - dot_product_3d(bx, by, bz, zto, zsi, zup);
		if (max(abs(dx), abs(dy), abs(dz)) < hsize) return true;
		
		return false;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Block];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Block] = colmesh_create_block(1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Block];
		}
		if (is_undefined(tex))
		{
			tex = -1;
		}
		static M = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
		M[0]  = xto;
		M[1]  = yto;
		M[2]  = zto;
		M[4]  = xsi;
		M[5]  = ysi;
		M[6]  = zsi;
		M[8]  = xup;
		M[9]  = yup;
		M[10] = zup;
		M[12] = x;
		M[13] = y;
		M[14] = z;
		var sh = shader_current();
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), 0);
		var W = matrix_get(matrix_world);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @function colmesh_dynamic(shape, colMesh, M, shapeInd)
function colmesh_dynamic(_shape, _colMesh, _M, _shapeInd) : ColmeshShape() constructor
{
	type = eColMeshShape.Dynamic;
	shape = _shape;
	colMesh = _colMesh;
	shapeInd = _shapeInd;
	M = matrix_build_identity(); //World matrix
	I = matrix_build_identity(); //Inverse world matrix
	pI = matrix_build_identity(); //Previous inverse world matrix
	scale = 1;
	moving = false;
	
	#region Shared functions (this is only overwritten for the dynamic
	
	/// @function capsule_collision(x, y, z, xup, yup, zup, radius, height)
	static capsule_collision = function(x, y, z, xup, yup, zup, radius, height)
	{
		//Returns true if the given capsule collides with the shape
		var xx = I[12] + dot_product_3d(x, y, z, I[0], I[4], I[8]);
		var yy = I[13] + dot_product_3d(x, y, z, I[1], I[5], I[9]);
		var zz = I[14] + dot_product_3d(x, y, z, I[2], I[6], I[10]);
		var ux = scale * dot_product_3d(xup, yup, zup, I[0], I[4], I[8]);
		var uy = scale * dot_product_3d(xup, yup, zup, I[1], I[5], I[9]);
		var uz = scale * dot_product_3d(xup, yup, zup, I[2], I[6], I[10]);
		return shape.capsule_collision(xx, yy, zz, ux, uy, uz, radius / scale, height / scale);
	}
	
	/// @function check_aabb(minx, miny, minz, maxx, maxy, maxz)
	static check_aabb = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var mm = get_min_max();
		if (mm[0] < maxx and mm[1] < maxy and mm[2] < maxz and mm[3] > minx and mm[4] > miny and mm[5] > minz)
		{
			return true;
		}
		return false;
	}
	
	#endregion
	
	#region Shape-specific functions
	
	/// @function setMatrix(M, moving)
	static setMatrix = function(_M, _moving) 
	{	
		/*	
			This script lets you make it seem like a colmesh instance has been transformed.
			What really happens though, is that the collision shape is transformed by the inverse of the given matrix, 
			then it performs collision checks, and then it is transformed back. This is an efficient process.
			This script creates a new matrix from the given matrix, making sure that all the vectors are perpendicular, 
			and making sure the scaling is uniform (using the scale in the first column as reference).
		*/
		static oldReg = array_create(6);
		array_copy(oldReg, 0, colMesh.get_regions(get_min_max()), 0, 6);
		
		moving = _moving;
		array_copy(M, 0, _M, 0, 16);
		
		//Orthogonalize the side vector
		var sqrScale = dot_product_3d(M[0], M[1], M[2], M[0], M[1], M[2]);
		var sideDp = dot_product_3d(M[0], M[1], M[2], M[4], M[5], M[6]) / sqrScale;
		M[4] -= M[0] * sideDp;
		M[5] -= M[1] * sideDp;
		M[6] -= M[2] * sideDp;
		var l = sqrt(dot_product_3d(M[4], M[5], M[6], M[4], M[5], M[6]));
		if (l <= 0){return false;}
		scale = sqrt(sqrScale);
		l = scale / max(l, 0.00001);
		M[4] *= l;
		M[5] *= l;
		M[6] *= l;

		//Orthogonalize the up vector
		M[8]  = (M[1] * M[6] - M[2] * M[5]) / scale;
		M[9]  = (M[2] * M[4] - M[0] * M[6]) / scale;
		M[10] = (M[0] * M[5] - M[1] * M[4]) / scale;
		
		M[3]  = 0;
		M[7]  = 0;
		M[11] = 0;
		M[15] = 1;
		
		if (moving)
		{	//If the object is moving, save the previous inverse matrix to pI
			array_copy(pI, 0, I, 0, 16);
		}
		colmesh_matrix_invert_fast(M, I);
		
		var mm = get_min_max();
		colMesh.expand_boundaries(mm);
		var newReg = colMesh.get_regions(mm);
		if !array_equals(oldReg, newReg)
		{
			colMesh.remove_shape_from_subdiv(self, oldReg);
			colMesh.add_shape_to_subdiv(self, newReg, false);
		}
	}
	
	/// @function move(colMesh, x, y, z)
	static move = function(colMesh, _x, _y, _z)
	{
		static temp = matrix_build_identity();
		array_copy(temp, 0, M, 0, 16);
		temp[12] = _x;
		temp[13] = _y;
		temp[14] = _z;
		setMatrix(temp, true);
	}
	
	#endregion
	
	#region functions
	
	/// @function get_min_max()
	static get_min_max = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		if (shape.type == eColMeshShape.Mesh)
		{
			var mm = array_create(6);
			array_copy(mm, 0, shape.minimum, 0, 3);
			array_copy(mm, 3, shape.maximum, 0, 3);
		}
		else
		{
			var mm = shape.get_min_max();
		}
		var xs = (mm[3] - mm[0]) * .5;
		var ys = (mm[4] - mm[1]) * .5;
		var zs = (mm[5] - mm[2]) * .5;
		var mx = (mm[0] + mm[3]) * .5;
		var my = (mm[1] + mm[4]) * .5;
		var mz = (mm[2] + mm[5]) * .5;
		var tx = M[12] + dot_product_3d(mx, my, mz, M[0], M[4], M[8]);
		var ty = M[13] + dot_product_3d(mx, my, mz, M[1], M[5], M[9]);
		var tz = M[14] + dot_product_3d(mx, my, mz, M[2], M[6], M[10]);
		var dx = abs(M[0] * xs) + abs(M[4] * ys) + abs(M[8] * zs);
		var dy = abs(M[1] * xs) + abs(M[5] * ys) + abs(M[9] * zs);
		var dz = abs(M[2] * xs) + abs(M[6] * ys) + abs(M[10]* zs);
		minMax[0] = tx - dx;
		minMax[1] = ty - dy;
		minMax[2] = tz - dz;
		minMax[3] = tx + dx;
		minMax[4] = ty + dy;
		minMax[5] = tz + dz;
		return minMax;
	}
	
	/// @function cast_ray(ox, oy, oz)
	static cast_ray = function(ox, oy, oz)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.cast_ray
			Changes the global array CM_RAY if the ray intersects the shape
		*/
		//Make a copy of the ray, since the ray casting process might change this
		static temp = array_create(7);
		array_copy(temp, 0, CM_RAY, 0, 7);
		
		//Transform the ray to local space
		var ex = CM_RAY[0];
		var ey = CM_RAY[1];
		var ez = CM_RAY[2];
		CM_RAY[0] = I[12] + dot_product_3d(ex, ey, ez, I[0], I[4], I[8]);
		CM_RAY[1] = I[13] + dot_product_3d(ex, ey, ez, I[1], I[5], I[9]);
		CM_RAY[2] = I[14] + dot_product_3d(ex, ey, ez, I[2], I[6], I[10]);
		CM_RAY[3] = I[12] + dot_product_3d(ox, oy, oz, I[0], I[4], I[8]);
		CM_RAY[4] = I[13] + dot_product_3d(ox, oy, oz, I[1], I[5], I[9]);
		CM_RAY[5] = I[14] + dot_product_3d(ox, oy, oz, I[2], I[6], I[10]);
		
		var success = false;
		if (shape.type == eColMeshShape.Mesh)
		{
			//If this is a mesh, we want to raycast against all the shapes the mesh contains
			success = is_array(shape.cast_ray(CM_RAY[3], CM_RAY[4], CM_RAY[5], CM_RAY[0], CM_RAY[1], CM_RAY[2]));
		}
		else
		{
			//If this is not a mesh, we can raycast against just this shape
			success = shape.cast_ray(CM_RAY[3], CM_RAY[4], CM_RAY[5]);
		}
		if (!success)
		{
			array_copy(CM_RAY, 0, temp, 0, 7);
			return false;
		}
		var ex = CM_RAY[0];
		var ey = CM_RAY[1];
		var ez = CM_RAY[2];
		var nx = CM_RAY[3];
		var ny = CM_RAY[4];
		var nz = CM_RAY[5];
		CM_RAY[0] = M[12] + dot_product_3d(ex, ey, ez, M[0], M[4], M[8]);
		CM_RAY[1] = M[13] + dot_product_3d(ex, ey, ez, M[1], M[5], M[9]);
		CM_RAY[2] = M[14] + dot_product_3d(ex, ey, ez, M[2], M[6], M[10]);
		CM_RAY[3] = dot_product_3d(nx, ny, nz, M[0], M[4], M[8])  / scale;
		CM_RAY[4] = dot_product_3d(nx, ny, nz, M[1], M[5], M[9])  / scale;
		CM_RAY[5] = dot_product_3d(nx, ny, nz, M[2], M[6], M[10]) / scale;
		return true;
	}
	
	/// @function get_closest_point(x, y, z)
	static get_closest_point = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		if (shape.type == eColMeshShape.Mesh)
		{
			//Find normalized block space position
			var bx = M[12] + dot_product_3d(_x, _y, _z, I[0], I[4], I[8]);
			var by = M[13] + dot_product_3d(_x, _y, _z, I[1], I[5], I[9]);
			var bz = M[14] + dot_product_3d(_x, _y, _z, I[2], I[6], I[10]);
			var b = max(abs(bx), abs(by), abs(bz));
		
			//If the center of the sphere is inside the cube, normalize the largest axis
			if (b <= 1)
			{
				if (b == abs(bx))
				{
					bx = sign(bx);
				}
				else if (b == abs(by))
				{
					by = sign(by);
				}
				else
				{
					bz = sign(bz);
				}
				var p = colmesh_matrix_transform_vertex(M, bx, by, bz);
				CM_COL[0] = p[0];
			}
			else
			{	//Nearest point on the cube in normalized block space
				bx = clamp(bx, -1, 1);
				by = clamp(by, -1, 1);
				bz = clamp(bz, -1, 1);
				var p = colmesh_matrix_transform_vertex(M, bx, by, bz);
			}
			CM_COL[@ 0] = p[0];
			CM_COL[@ 1] = p[1];
			CM_COL[@ 2] = p[2];
			return CM_COL;
		}
		var p = colmesh_matrix_transform_vertex(I, _x, _y, _z);
		var n = shape.get_closest_point(p[0], p[1], p[2]);
		return colmesh_matrix_transform_vertex(M, _x, _y, _z);
	}
	
	/// @function capsule_get_ref(x, y, z, xup, yup, zup, height)
	static capsule_get_ref = function(_x, _y, _z, xup, yup, zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		if (shape.type == eColMeshShape.Mesh)
		{
			//If the dynamic contains a mesh, there's no point in finding the actual reference at this time. Return the input position.
			static ret = array_create(3);
			ret[0] = _x;
			ret[1] = _y;
			ret[2] = _z;
			return ret;
		}
		var p = colmesh_matrix_transform_vertex(I, _x, _y, _z);
		var u = colmesh_matrix_transform_vector(I, xup * scale, yup * scale, zup * scale);
		var r = shape.capsule_get_ref(p[0], p[1], p[2], u[0], u[1], u[2], height / scale);
		return colmesh_matrix_transform_vertex(M, r[0], r[1], r[2]);
	}
	
	/// @function intersects_cube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static intersects_cube = function(hsize, bX, bY, bZ)
	{
		/*
			A supplementary function, not meant to be used by itself.
			For dynamic shapes it always returns true
		*/
		return true;
	}
	
	/// @function displace_sphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static displace_sphere = function(x, y, z, xup, yup, zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array CM_COL
			Returns true if there was a collision.
		*/
		var temp = array_create(7);
		array_copy(temp, 0, CM_COL, 0, 7);
		
		//CM_COL contains the current position of the capsule in indices 0-3, and the current collision normal vector in indices 3-5
		var _x = CM_COL[0], _y = CM_COL[1], _z = CM_COL[2];
		var nx = CM_COL[3], ny = CM_COL[4], nz = CM_COL[5];
		CM_COL[0] = I[12] + dot_product_3d(_x, _y, _z, I[0], I[4], I[8]);
		CM_COL[1] = I[13] + dot_product_3d(_x, _y, _z, I[1], I[5], I[9]);
		CM_COL[2] = I[14] + dot_product_3d(_x, _y, _z, I[2], I[6], I[10]);
		CM_COL[3] = scale * dot_product_3d(nx, ny, nz, I[0], I[4], I[8]);
		CM_COL[4] = scale * dot_product_3d(nx, ny, nz, I[1], I[5], I[9]);
		CM_COL[5] = scale * dot_product_3d(nx, ny, nz, I[2], I[6], I[10]);
		var _xup = scale * dot_product_3d(xup, yup, zup, I[0], I[4], I[8]);
		var _yup = scale * dot_product_3d(xup, yup, zup, I[1], I[5], I[9]);
		var _zup = scale * dot_product_3d(xup, yup, zup, I[2], I[6], I[10]);
		
		var col = false;
		if (shape.type == eColMeshShape.Mesh)
		{
			//Special case if this dynamic contains a mesh
			var slopeAngle = (slope >= 1) ? 0 : darccos(slope);
			shape.displace_capsule(CM_COL[0], CM_COL[1], CM_COL[2], _xup, _yup, _zup, radius / scale, height / scale, slopeAngle, fast);
			if (CM_COL[6])
			{
				CM_COL[6] = max(temp[6], _xup * CM_COL[3] + _yup * CM_COL[4] + _zup * CM_COL[5]);
				col = true;
			}
		}
		else
		{
			//This dynamic contains a primitive
			var lx = I[12] + dot_product_3d(x, y, z, I[0], I[4], I[8]);
			var ly = I[13] + dot_product_3d(x, y, z, I[1], I[5], I[9]);
			var lz = I[14] + dot_product_3d(x, y, z, I[2], I[6], I[10]);
			col = shape.displace_sphere(lx, ly, lz, _xup, _yup, _zup, height / scale, radius / scale, slope, fast);
		}
		if (col)
		{
			if (slope < 1 and CM_TRANSFORM >= 0)
			{
				ds_queue_enqueue(CM_TRANSFORM, M);
				if (moving)
				{
					//This object is moving. Save its current world matrix and the inverse of the previous 
					//world matrix so that figuring out the delta matrix later is as easy as a matrix multiplication
					ds_queue_enqueue(CM_TRANSFORM, pI);
				}
				//If the transformation queue is empty, this is the first dynamic to be added. 
				//If it's static as well, there's no point in adding it to the transformation queue
				else if (!ds_queue_empty(CM_TRANSFORM))
				{	
					//If the dynamic is not marked as "moving", save the current inverse matrix to the transformation 
					//queue so that no transformation is done. It will then only transform the preceding transformations
					//into its own frame of reference
					ds_queue_enqueue(CM_TRANSFORM, I);
				}
			}
			//Transform collision position and normal to world-space
			var _x = CM_COL[0], _y = CM_COL[1], _z = CM_COL[2];
			var nx = CM_COL[3], ny = CM_COL[4], nz = CM_COL[5];
			CM_COL[0] = M[12] + dot_product_3d(_x, _y, _z, M[0], M[4], M[8]);
			CM_COL[1] = M[13] + dot_product_3d(_x, _y, _z, M[1], M[5], M[9]);
			CM_COL[2] = M[14] + dot_product_3d(_x, _y, _z, M[2], M[6], M[10]);
			CM_COL[3] = dot_product_3d(nx, ny, nz, M[0], M[4], M[8])  / scale;
			CM_COL[4] = dot_product_3d(nx, ny, nz, M[1], M[5], M[9])  / scale;
			CM_COL[5] = dot_product_3d(nx, ny, nz, M[2], M[6], M[10]) / scale;
			return true;
		}
		array_copy(CM_COL, 0, temp, 0, 7);
		return false;
	}
	
	/// @function get_priority(x, y, z, maxR)
	static get_priority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		if (shape.type == eColMeshShape.Mesh)
		{
			return 0; //0 is maximum priority
		}
		var p = colmesh_matrix_transform_vertex(I, _x, _y, _z);
		var pri = shape.get_priority(p[0], p[1], p[2], maxR / scale);
		return pri * scale * scale;
	}
	
	/// @function debug_draw(tex)
	static debug_draw = function(tex)
	{
		var W = matrix_get(matrix_world);
		matrix_set(matrix_world, matrix_multiply(M, W));
		if (shape.type == eColMeshShape.Mesh)
		{
			if (CM_RECURSION < CM_MAX_RECURSION)
			{
				++ CM_RECURSION;
				shape.debug_draw(-1, tex);
				-- CM_RECURSION;
			}
		}
		else
		{
			shape.debug_draw(tex);
		}
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
	
	//Update the matrix
	setMatrix(_M, false);
}

function colmesh_none() constructor
{
	/*
		This is a failsafe object for when loading a ColMesh that contains dynamic objects
	*/
	type = eColMeshShape.None;
	static capsule_collision = function(){return false;}
	static _displace = function(){}
	static _addToSubdiv = function(){return 0;}
	static get_min_max = function(){return array_create(6);}
	static capsule_get_ref = function()
	{
		static ret = array_create(3);
		return ret;
	}
	static cast_ray = function(){return false;}	
	static displace_sphere = function(){return false;}
	static get_priority = function(){return -1;}
	static get_closest_point = function()
	{
		static ret = array_create(3);
		return ret;
	}
	static intersects_cube = function(){return false;}
}