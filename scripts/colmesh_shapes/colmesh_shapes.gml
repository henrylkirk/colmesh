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

enum eColMeshShape
{
	//Do not change the order of these. Changing the order will break saving and loading. Add new entries before "Num".
	Mesh, Sphere, Capsule, Cylinder, Torus, Cube, Block, Dynamic, None, Disk, Cone, Trigger, Heightmap, Num
}

function colmesh_shapes() constructor
{
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
	
	/// @func setTrigger(solid, colFunc*, rayFunc*)
	static setTrigger = function(_solid, _colFunc, _rayFunc)
	{
		//Marks this shape as a trigger.
		
		//You can give the shape custom collision functions.
		//These custom functions are NOT saved when writing the ColMesh to a buffer
		//You have access to the following global variables in the custom functions:
		//	cmCol - A struct containing the current position of the capsule being displaced
		//	cmCallingObject - The instance that is currently checking for collisions
			
		//colFunc lets you give the shape a custom collision function.
		//This is useful for example for collisions with collectible objects like coins and powerups.
		
		//rayFunc lets you give the shape a custom function that is executed if a ray hits the shape.
		
		type = eColMeshShape.Trigger;
		solid = _solid;
		colFunc = _colFunc;
		rayFunc = _rayFunc;
	}
	
	#region Shared functions
	
	/// @func capsuleCollision(x, y, z, xup, yup, zup, radius, height)
	static capsuleCollision = function(x, y, z, xup, yup, zup, radius, height)
	{
		/*
			Returns true if the given capsule collides with the shape
		*/
		if (height != 0)
		{
			var p = _capsuleGetRef(x, y, z, xup, yup, zup, height);
			return (_getPriority(p[0], p[1], p[2], radius) >= 0);
		}
		return (_getPriority(x, y, z, radius) >= 0);
	}
	
	/// @func move(colMesh, x, y, z)
	static move = function(colMesh, _x, _y, _z)
	{
		static oldReg = array_create(6);
		array_copy(oldReg, 0, colMesh._getRegions(getMinMax()), 0, 6);
		x = _x;
		y = _y;
		z = _z;
		var newReg = colMesh._getRegions(getMinMax());
		if (!array_equals(oldReg, newReg))
		{
			levelColmesh.removeShapeFromSubdiv(self, oldReg);
			levelColmesh.addShapeToSubdiv(self, newReg, false);
		}
	}
	
	#endregion
	
	#region Shape-specific functions
	
	/// @func getMinMax()
	static getMinMax = function()
	{
		static minMax = array_create(6);
		minMax[0] = min(triangle[0], triangle[3], triangle[6]);
		minMax[1] = min(triangle[1], triangle[4], triangle[7]);
		minMax[2] = min(triangle[2], triangle[5], triangle[8]);
		minMax[3] = max(triangle[0], triangle[3], triangle[6]);
		minMax[4] = max(triangle[1], triangle[4], triangle[7]);
		minMax[5] = max(triangle[2], triangle[5], triangle[8]);
		return minMax;
	}
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		//Will return true if the AABB of this shape overlaps the given AABB
		if (
			min(triangle[0], triangle[3], triangle[6]) < maxx && 
			min(triangle[1], triangle[4], triangle[7]) < maxy && 
			min(triangle[2], triangle[5], triangle[8]) < maxz && 
			max(triangle[0], triangle[3], triangle[6]) > minx && 
			max(triangle[1], triangle[4], triangle[7]) > miny && 
			max(triangle[2], triangle[5], triangle[8]) > minz){
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, xup, yup, zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var d = cmDot(xup, yup, zup, nx, ny, nz);
		if (d != 0)
		{
			var trace = cmDot(v1x - _x, v1y - _y, v1z - _z, nx, ny, nz) / d;
			var traceX = _x + xup * trace;
			var traceY = _y + yup * trace;
			var traceZ = _z + zup * trace;
			var p = _getClosestPoint(traceX, traceY, traceZ);
			d = cmDot(p[0] - _x, p[1] - _y, p[2] - _z, xup, yup, zup);
		}
		else
		{
			d = cmDot(_x - v1x, _y - v1y, _z - v1z, xup, yup, zup);
		}
		d = clamp(d, 0, height);
		ret[@ 0] = _x + xup * d;
		ret[@ 1] = _y + yup * d;
		ret[@ 2] = _z + zup * d;
		return ret;
	}
	
	/// @func _castRay(ray[6])
	static _castRay = function(ray)
	{
		var ox = ray[0], oy = ray[1], oz = ray[2];
		var dx = ray[3] - ox;
		var dy = ray[4] - oy;
		var dz = ray[5] - oz;
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var h = cmDot(dx, dy, dz, nx, ny, nz);
		if (h == 0){return false;} //Continue if the ray is parallel to the surface of the triangle (ie. perpendicular to the triangle's normal)
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var h = cmDot(v1x - ox, v1y - oy, v1z - oz, nx, ny, nz) / h;
		if (h < 0 || h > 1){return false;} //Continue if the intersection is too far behind or in front of the ray
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
		var dp = cmDot(cx, cy, cz, nx, ny, nz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = cmDot(ax, ay, az, bx, by, bz);
			if (t < 0 || t > cmDot(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
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
		var dp = cmDot(cx, cy, cz, nx, ny, nz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = cmDot(ax, ay, az, bx, by, bz);
			if (t < 0 || t > cmDot(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
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
		var dp = cmDot(cx, cy, cz, nx, ny, nz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = cmDot(ax, ay, az, bx, by, bz);
			if (t < 0 || t > cmDot(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
	
		//The line intersects the triangle. Save the triangle normal and intersection.
		var s = sign(h);
		return new colmesh_raycast_result(itsX, itsY, itsZ, nx * s, ny * s, nz * s, true, triangle);
	}
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(x, y, z, xup, yup, zup, height, radius, slope, fast)
	{
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
		var D = cmDot(t0, t1, t2, nx, ny, nz);
		if (abs(D) > radius)
		{
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
		var dp = cmDot(cx, cy, cz, nx, ny, nz);
		if (dp < 0)
		{
			var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
			var _nx = t0 - u0 * a;
			var _ny = t1 - u1 * a;
			var _nz = t2 - u2 * a;
			var d = point_distance_3d(0, 0, 0, _nx, _ny, _nz);
			if (d == 0 || d >= radius){return false;}
			colmesh__displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
			return true;
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
			var dp = cmDot(cx, cy, cz, nx, ny, nz);
			if (dp < 0)
			{
				var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
				var _nx = t0 - u0 * a;
				var _ny = t1 - u1 * a;
				var _nz = t2 - u2 * a;
				var d = point_distance_3d(0, 0, 0, _nx, _ny, _nz);
				if (d == 0 || d >= radius){return false;}
				colmesh__displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
				return true;
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
				var cx = t2 * u1 - t1 * u2;
				var cy = t0 * u2 - t2 * u0;
				var cz = t1 * u0 - t0 * u1;
				var dp = cmDot(cx, cy, cz, nx, ny, nz);
				if (dp < 0)
				{
					var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
					var _nx = t0 - u0 * a;
					var _ny = t1 - u1 * a;
					var _nz = t2 - u2 * a;
					var d = point_distance_3d(0, 0, 0, _nx, _ny, _nz);
					if (d == 0 || d >= radius){return false;}
					colmesh__displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
					return true;
				}
			}
		}
		var s = sign(D);
		colmesh__displace(nx * s, ny * s, nz * s, xup, yup, zup, radius - abs(D), slope);
		return true;
	}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(x, y, z, maxR)
	{
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
		var D = cmDot(t0, t1, t2, nx, ny, nz);
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
		if (cmDot(cx, cy, cz, nx, ny, nz) < 0)
		{
			var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
			return cmSqr(u0 * a - t0, u1 * a - t1, u2 * a - t2);
		}
		else
		{	//Check second edge
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
			if (cmDot(cx, cy, cz, nx, ny, nz) < 0)
			{
				var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
				return cmSqr(u0 * a - t0, u1 * a - t1, u2 * a - t2);
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
				if (cmDot(cx, cy, cz, nx, ny, nz) < 0)
				{
					var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
					return cmSqr(u0 * a - t0, u1 * a - t1, u2 * a - t2);
				}
			}
		}
		return abs(D);
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(x, y, z)
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
		if (cmDot(cx, cy, cz, nx, ny, nz) < 0)
		{
			var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
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
			if (cmDot(cx, cy, cz, nx, ny, nz) < 0)
			{
				var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
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
				if (cmDot(cx, cy, cz, nx, ny, nz) < 0)
				{
					var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
					ret[@ 0] = v3x + u0 * a;
					ret[@ 1] = v3y + u1 * a;
					ret[@ 2] = v3z + u2 * a;
					return ret;
				}
			}
		}
		var D =  cmDot(t0, t1, t2, nx, ny, nz);
		ret[@ 0] = x - nx * D;
		ret[@ 1] = y - ny * D;
		ret[@ 2] = z - nz * D;
		return ret;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ)
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
		if (min(d1x, d2x, d3x) > hsize || max(d1x, d2x, d3x) < -hsize){return false;}

		/* test in Y-direction */
		var v1y = triangle[1];
		var v2y = triangle[4];
		var v3y = triangle[7];
		var d1y = v1y - bY;
		var d2y = v2y - bY;
		var d3y = v3y - bY;
		if (min(d1y, d2y, d3y) > hsize || max(d1y, d2y, d3y) < -hsize){return false;}

		/* test in Z-direction */
		var v1z = triangle[2];
		var v2z = triangle[5];
		var v3z = triangle[8];
		var d1z = v1z - bZ;
		var d2z = v2z - bZ;
		var d3z = v3z - bZ;
		if (min(d1z, d2z, d3z) > hsize || max(d1z, d2z, d3z) < -hsize){return false;}
		
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

		var d = cmDot(d1x, d1y, d1z, nx, ny, nz);
		if (cmDot(minx, miny, minz, nx, ny, nz) > d){return false;}
		if (cmDot(maxx, maxy, maxz, nx, ny, nz) < d){return false;}

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
		if (min(p0, p2) > rad || max(p0, p2) < -rad){return false;}
   
		p0 = -ez * d1x + ex * d1z;
		p2 = -ez * d3x + ex * d3z;
		rad = fez + fex;
		if (min(p0, p2) > rad || max(p0, p2) < -rad){return false;}
           
		p1 = ey * d2x - ex * d2y;                 
		p2 = ey * d3x - ex * d3y;                 
		rad = fey + fex;
		if (min(p1, p2) > rad || max(p1, p2) < -rad){return false;}

		ex = d3x - d2x;
		ey = d3y - d2y;
		ez = d3z - d2z;
		fex = abs(ex) * hsize;
		fey = abs(ey) * hsize;
		fez = abs(ez) * hsize;
	      
		p0 = ez * d1y - ey * d1z;
		p2 = ez * d3y - ey * d3z;
		rad = fez + fey;
		if (min(p0, p2) > rad || max(p0, p2) < -rad){return false;}
          
		p0 = -ez * d1x + ex * d1z;
		p2 = -ez * d3x + ex * d3z;
		rad = fez + fex;
		if (min(p0, p2) > rad || max(p0, p2) < -rad){return false;}
	
		p0 = ey * d1x - ex * d1y;
		p1 = ey * d2x - ex * d2y;
		rad = fey + fex;
		if (min(p0, p1) > rad || max(p0, p1) < -rad){return false;}

		ex = d1x - d3x;
		ey = d1y - d3y;
		ez = d1z - d3z;
		fex = abs(ex) * hsize;
		fey = abs(ey) * hsize;
		fez = abs(ez) * hsize;

		p0 = ez * d1y - ey * d1z;
		p1 = ez * d2y - ey * d2z;
		rad = fez + fey;
		if (min(p0, p1) > rad || max(p0, p1) < -rad){return false;}

		p0 = -ez * d1x + ex * d1z;
		p1 = -ez * d2x + ex * d2z;
		rad = fez + fex;
		if (min(p0, p1) > rad || max(p0, p1) < -rad){return false;}
	
		p1 = ey * d2x - ex * d2y;
		p2 = ey * d3x - ex * d3y;
		rad = fey + fex;
		if (min(p1, p2) > rad || max(p1, p2) < -rad){return false;}

		return true;
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
		{
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
	
	#endregion
}

/// @func colmesh_sphere(x, y, z, radius)
function colmesh_sphere(_x, _y, _z, radius) : colmesh_shapes() constructor
{
	type = eColMeshShape.Sphere;
	x = _x;
	y = _y;
	z = _z;
	R = radius;
	
	#region functions
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (x - R < maxx && y - R < maxy && z - R < maxz && x + R > minx && y + R > miny && z + R > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, xup, yup, zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = clamp(cmDot(x - _x, y - _y, z - _z, xup, yup, zup), 0, height);
		ret[@ 0] = _x + xup * d;
		ret[@ 1] = _y + yup * d;
		ret[@ 2] = _z + zup * d;
		return ret;
	}
	
	/// @func _castRay(ox, oy, oz)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		var _ray = colmesh_cast_ray_sphere(x, y, z, R, ray[0], ray[1], ray[2], ray[3], ray[4], ray[5]);
		if (is_array(_ray))
		{
			var n = point_distance_3d(x, y, z, _ray[0], _ray[1], _ray[2]);
			if (n > 0)
			{
				return new colmesh_raycast_result(_ray[0], _ray[1], _ray[2], (_ray[0] - x) / n, (_ray[1] - y) / n, (_ray[2] - z) / n, true, self);
			}
		}
		return false;
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = sqrt(cmDot(dx, dy, dz, dx, dy, dz));
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, xup, yup, zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		var r = R + radius;
		if (d >= r * r){return false;}
		d = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, xup, yup, zup, r - d, slope);
		}
		return true;
	}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		var _r = R + maxR;
		if (d > _r * _r) return -1;
		return sqr(max(sqrt(d) - R, 0));
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
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
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Sphere];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Sphere] = colmesh_create_sphere(20, 16, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Sphere];
		}
		static M = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
		M[12] = x;
		M[13] = y;
		M[14] = z;
		
		var W = matrix_get(matrix_world);
		var scale = point_distance_3d(0, 0, 0, W[0], W[1], W[2]);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), R * scale);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @func colmesh_capsule(x, y, z, xup, yup, zup, radius, height)
function colmesh_capsule(_x, _y, _z, _xup, _yup, _zup, radius, height) : colmesh_shapes() constructor
{
	type = eColMeshShape.Capsule;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(cmDot(_xup, _yup, _zup, _xup, _yup, _zup));
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
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (x - R + H * min(0, xup) < maxx && 
			y - R + H * min(0, yup) < maxy && 
			z - R + H * min(0, zup) < maxz && 
			x + R + H * max(0, xup) > minx && 
			y + R + H * max(0, yup) > miny && 
			z + R + H * max(0, zup) > minz)
		return true;
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, _xup, _yup, _zup, height)
	{	
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var upDp = cmDot(_xup, _yup, _zup, xup, yup, zup);
		
		//If the capsules are parallel, finding the nearest point is trivial
		if (upDp == 1)
		{
			var t = cmDot(x - _x, y - _y, z - _z, _xup, _yup, _zup);
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
		var w1 = cmDot(dx, dy, dz, xup, yup, zup);
		var w2 = cmDot(dx, dy, dz, _xup, _yup, _zup);
		var s = clamp((w1 - w2 * upDp) / (1 - upDp * upDp), 0, H);
		var t = cmDot(xup * s - dx, yup * s - dy, zup * s - dz, _xup, _yup, _zup);
		t = clamp(t, 0, height);
		ret[0] = _x + _xup * t;
		ret[1] = _y + _yup * t;
		ret[2] = _z + _zup * t;
		return ret;
	}
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		var ox = ray[0],	oy = ray[1],	oz = ray[2];
		var _x = ray[3],	_y = ray[4],	_z = ray[5];
		var dx = _x - ox;
		var dy = _y - oy;
		var dz = _z - oz;
		
		//Transform the ray into the cylinder's local space, and do a 2D ray-circle intersection check
		var lox = cmDot(ox - x, oy - y, oz - z, inv0, inv4, inv8);
		var loy = cmDot(ox - x, oy - y, oz - z, inv1, inv5, inv9);
		var ldx = cmDot(dx, dy, dz, inv0, inv4, inv8);
		var ldy = cmDot(dx, dy, dz, inv1, inv5, inv9);
		var a = ldx * ldx + ldy * ldy;
		var b = - ldx * lox - ldy * loy;
		var c = lox * lox + loy * loy - 1;
		var k = b * b - a * c;
		if (k <= 0) return false;
		k = sqrt(k);
		var t = (b - k) / a;
		if (t > 1 || t < 0) return false;
		
		//Find the 3D intersection
		var itsX = ox + dx * t;
		var itsY = oy + dy * t;
		var itsZ = oz + dz * t;
		var d = cmDot(itsX - x, itsY - y, itsZ - z, xup, yup, zup);
		var _d = clamp(d, 0, H);
		var tx = x + xup * _d;
		var ty = y + yup * _d;
		var tz = z + zup * _d;
		if (d < 0 || d > H)
		{	//The intersection is outside the end of the capsule. Do a spherical ray cast at the nearest endpoint
			var _ray = colmesh_cast_ray_sphere(tx, ty, tz, R, ox, oy, oz, _x, _y, _z);
			if (!is_array(_ray)){return false;}
			itsX = ray[0];
			itsY = ray[1];
			itsZ = ray[2];
		}
		var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
		if (n == 0){return false;}
		return new colmesh_raycast_result(itsX, itsY, itsZ, (itsX - tx) / n, (itsY - ty) / n, (itsZ - tz) / n, true, self);
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = cmDot(_x - x, _y - y, _z - z, xup, yup, zup);
		d = clamp(d, 0, H);
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var d = sqrt(cmDot(dx, dy, dz, dx, dy, dz));
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		var D = cmDot(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		var r = R + radius;
		if (d >= r * r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, r - d, slope);
		}
		return true;
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var D = cmDot(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D
		var d = cmSqr(_x - tx, _y - ty, _z - tz);
		var _r = R + maxR;
		if (d > _r * _r) return -1;
		return sqr(max(sqrt(d) - R, 0));
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = _getClosestPoint(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize || abs(dy) > hsize || abs(dz) > hsize) return false;
		return true;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Capsule];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Capsule] = colmesh_create_capsule(20, 20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Capsule];
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, 1, 1, H, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		var scale = point_distance_3d(0, 0, 0, W[0], W[1], W[2]);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), R * scale);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @func colmesh_cylinder(x, y, z, xup, yup, zup, radius, height)
function colmesh_cylinder(_x, _y, _z, _xup, _yup, _zup, radius, height) : colmesh_shapes() constructor
{
	type = eColMeshShape.Cylinder;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(cmDot(_xup, _yup, _zup, _xup, _yup, _zup));
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
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (
			x - R + H * min(0, xup) < maxx && 
			y - R + H * min(0, yup) < maxy && 
			z - R + H * min(0, zup) < maxz && 
			x + R + H * max(0, xup) > minx && 
			y + R + H * max(0, yup) > miny && 
			z + R + H * max(0, zup) > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var upDp = cmDot(_xup, _yup, _zup, xup, yup, zup);
		
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
		var w1 = cmDot(dx, dy, dz, xup, yup, zup);
		var w2 = cmDot(dx, dy, dz, _xup, _yup, _zup);
		var s = (w1 - w2 * upDp) / (1 - upDp * upDp);
		if (s > 0 && s < H)
		{
			var t = cmDot(xup * s - dx, yup * s - dy, zup * s - dz, _xup, _yup, _zup);
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
		var d = cmDot(_xup, _yup, _zup, xup, yup, zup);
		if (d != 0)
		{
			var trace = cmDot(traceX - _x, traceY - _y, traceZ - _z, xup, yup, zup) / d;
			var traceX = _x + _xup * trace;
			var traceY = _y + _yup * trace;
			var traceZ = _z + _zup * trace;
			var p = _getClosestPoint(traceX, traceY, traceZ);
			d = cmDot(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
		}
		else
		{
			d = cmDot(traceX - _x, traceY - _y, traceZ - _z, _xup, _yup, _zup);
		}
		var t = clamp(d, 0, height);
		ret[0] = _x + _xup * t;
		ret[1] = _y + _yup * t;
		ret[2] = _z + _zup * t;
		return ret;
	}
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		gml_pragma("forceinline");
		var ox = ray[0],	oy = ray[1],	oz = ray[2];
		var ex = ray[3],	ey = ray[4],	ez = ray[5];
		var dx = ex - ox,	dy = ey - oy,	dz = ez - oz;
		
		//Transform the ray into the cylinder's local space, and do a 2D ray-circle intersection check
		var lox = cmDot(ox - x, oy - y, oz - z, inv0, inv4, inv8);
		var loy = cmDot(ox - x, oy - y, oz - z, inv1, inv5, inv9);
		var ldx = cmDot(dx, dy, dz, inv0, inv4, inv8);
		var ldy = cmDot(dx, dy, dz, inv1, inv5, inv9);
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
		var d = cmDot(itsX - x, itsY - y, itsZ - z, xup, yup, zup);
		if (d < 0 || d > H || inside)
		{	//The intersection is outside the end of the capsule. Do a plane intersection at the endpoint
			d = cmDot(ox - x, oy - y, oz - z, xup, yup, zup);
			d = clamp(d, 0, H);
			var tx = x + xup * d;
			var ty = y + yup * d;
			var tz = z + zup * d;
			var dp = cmDot(dx, dy, dz, xup, yup, zup);
			var s = - sign(dp);
			if (s == 2 * (d == 0) - 1) return false;
			t = cmDot(tx - ox, ty - oy, tz - oz, xup, yup, zup) / dp;
			if (t < 0 || t > 1){return false;}
			var itsX = ox + dx * t;
			var itsY = oy + dy * t;
			var itsZ = oz + dz * t;
			if (point_distance_3d(itsX, itsY, itsZ, tx, ty, tz) > R){return false;}
			return new colmesh_raycast_result(itsX, itsY, itsZ, xup * s, yup * s, zup * s, true, self);
		}
		
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
		if (n == 0){return false;}
		return new colmesh_raycast_result(itsX, itsY, itsZ, (itsX - tx) / n, (itsY - ty) / n, (itsZ - tz) / n, true, self);
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
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
		var d = cmDot(_x - x, _y - y, _z - z, xup, yup, zup);
		d = clamp(d, 0, H);
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var dp = cmDot(dx, dy, dz, xup, yup, zup);
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var d = sqrt(cmDot(dx, dy, dz, dx, dy, dz));
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		var D = cmDot(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var r = R + radius;
		if (D <= 0 || D >= H)
		{
			var dp = cmDot(dx, dy, dz, xup, yup, zup);
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = cmDot(dx, dy, dz, dx, dy, dz);
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
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d >= r * r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, r - d, slope);
		}
		return true;
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		var D = cmDot(_x - x, _y - y, _z - z, xup, yup, zup);
		D = clamp(D, 0, H);
		var tx = x + xup * D;
		var ty = y + yup * D;
		var tz = z + zup * D;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		if (D <= 0 || D >= H)
		{
			var dp = cmDot(dx, dy, dz, xup, yup, zup);
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = cmSqr(dx, dy, dz);
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
			var d = cmDot(dx, dy, dz, dx, dy, dz);
			if (d > maxR * maxR) return -1;
			return d;
		}
		var d = max(sqrt(cmDot(dx, dy, dz, dx, dy, dz)) - R, 0);
		if (d > maxR) return -1;
		return d * d;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = _getClosestPoint(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize || abs(dy) > hsize || abs(dz) > hsize) return false;
		return true;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Cylinder];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Cylinder] = colmesh_create_cylinder(20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Cylinder];
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

/// @func colmesh_cone(x, y, z, xup, yup, zup, radius, height)
function colmesh_unfinished_cone(_x, _y, _z, _xup, _yup, _zup, radius, height) : colmesh_shapes() constructor
{
	type = eColMeshShape.Cone;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(cmDot(_xup, _yup, _zup, _xup, _yup, _zup));
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	R = radius;
	H = height;
	
	#region functions
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var minMax = getMinMax();
		if (minMax[0] < maxx && minMax[1] < maxy && minMax[2] < maxz && minMax[3] > minx && minMax[4] > miny && minMax[5] > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, _xup, _yup, _zup, height)
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
		if (s > 0 && s < H)
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
			var p = _getClosestPoint(traceX, traceY, traceZ);
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
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		gml_pragma("forceinline");
		var ox = ray[0],	oy = ray[1],	oz = ray[2];
		var ex = ray[3],	ey = ray[4],	ez = ray[5];
		var dx = ex - ox,	dy = ey - oy,	dz = ez - oz;
		
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
		if (d < 0 || d > H || inside)
		{	//The intersection is outside the end of the capsule. Do a plane intersection at the endpoint
			d = clamp((ox - x) * xup + (oy - y) * yup + (oz - z) * zup, 0, H);
			var tx = x + xup * d;
			var ty = y + yup * d;
			var tz = z + zup * d;
			var dp = dx * xup + dy * yup + dz * zup;
			var s = - sign(dp);
			if (s == 2 * (d == 0) - 1) return false;
			t = - ((ox - tx) * xup + (oy - ty) * yup + (oz - tz) * zup) / dp;
			if (t < 0 || t > 1){return false;}
			var itsX = ox + dx * t;
			var itsY = oy + dy * t;
			var itsZ = oz + dz * t;
			if (point_distance_3d(itsX, itsY, itsZ, tx, ty, tz) > R){return false;}
			return new colmesh_raycast_result(itsX, itsY, itsZ, xup * s, yup * s, zup * s, true, self);
		}
		
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var nx = itsX - tx;
		var ny = itsY - ty;
		var nz = itsZ - tz;
		var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
		if (n == 0){return false;}
		return new colmesh_raycast_result(itsX, itsY, itsZ, (itsX - tx) / n,(itsY - ty) / n, (itsZ - tz) / n, true, self);
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
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
		if (D <= 0 || D >= H)
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
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d >= _r * _r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, _r - d, slope);
		}
		return true;
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		if (D <= 0 || D >= H)
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
		var d = max(sqrt(cmDot(dx, dy, dz, dx, dy, dz)) - R, 0);
		if (d > maxR) return -1;
		return d * d;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = _getClosestPoint(bX, bY, bZ);
		var dx = p[0] - bX, dy = p[1] - bY, dz = p[2] - bZ;
		if (abs(dx) > hsize || abs(dy) > hsize || abs(dz) > hsize) return false;
		return true;
	}
	
	#endregion
}

/// @func colmesh_torus(x, y, z, xup, yup, zup, R, r)
function colmesh_torus(_x, _y, _z, _xup, _yup, _zup, _R, _r) : colmesh_shapes() constructor
{
	type = eColMeshShape.Torus;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(cmDot(_xup, _yup, _zup, _xup, _yup, _zup));
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
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var rr = R + r;
		if (x - rr < maxx && y - rr < maxy && z - rr < maxz && x + rr > minx && y + rr > miny && z + rr > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = cmDot(_xup, _yup, _zup, xup, yup, zup);
		if (d != 0)
		{
			var d = cmDot(x - _x, y - _y, z - _z, xup, yup, zup) / d;
			repeat 2
			{
				var p = _getRingCoord(_x + _xup * d, _y + _yup * d, _z + _zup * d);
				d = cmDot(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
				d = clamp(d, 0, height);
			}
		}
		else
		{
			d = cmDot(x - _x, y - _y, z - _z, _xup, _yup, _zup);
			d = clamp(d, 0, height);
		}
		ret[0] = _x + _xup * d;
		ret[1] = _y + _yup * d;
		ret[2] = _z + _zup * d;
		return ret;
	}
	
	/// @func _getRingCoord(x, y, z)
	static _getRingCoord = function(_x, _y, _z)
	{
		gml_pragma("forceinline");
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var dp = cmDot(dx, dy, dz, xup, yup, zup);
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var l = sqrt(cmDot(dx, dy, dz, dx, dy, dz));
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
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*
			Algorithm created by TheSnidr
			This is an approximation using the same principle as ray marching
		*/
		var repetitions = 15;
		
		var ox = ray[0],	oy = ray[1],	oz = ray[2];
		var ex = ray[3],	ey = ray[4],	ez = ray[5];
		var dx = ex - ox,	dy = ey - oy,	dz = ez - oz;
		ox -= x;
		oy -= y;
		oz -= z;
		var lox = cmDot(ox, oy, oz, inv0, inv4, inv8);
		var loy = cmDot(ox, oy, oz, inv1, inv5, inv9);
		var loz = cmDot(ox, oy, oz, inv2, inv6, inv10);
		var ldx = cmDot(dx, dy, dz, inv0, inv4, inv8);
		var ldy = cmDot(dx, dy, dz, inv1, inv5, inv9);
		var ldz = cmDot(dx, dy, dz, inv2, inv6, inv10);
		var l = point_distance_3d(0, 0, 0, ldx, ldy, ldz);
		ldx /= l;
		ldy /= l;
		ldz /= l;
		var p = 0, n = 0, d = 0;
		var radiusRatio = r / R;
		repeat repetitions 
		{
			p = n;
			n = (point_distance(0, 0, point_distance(0, 0, lox, loy) - 1, loz) - radiusRatio);
			d += n;
			if (p > 0 && n > R) return false; //The ray missed the torus, and we can remove it from the ray casting algorithm
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
		var n = point_distance_3d(itsX, itsY, itsZ, p[0], p[1], p[2]);
		return new colmesh_raycast_result(itsX, itsY, itsZ, (itsX - p[0]) / n, (itsY - p[1]) / n, (itsZ - p[2]) / n, true, self);
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
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
		var d = sqrt(cmDot(dx, dy, dz, dx, dy, dz));
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		gml_pragma("forceinline");
		var p = _getRingCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var _r = r + radius;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d > _r * _r) return false;
		d  = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, _r - d, slope);
		}
		return true;
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		var d = max(sqrt(cmDot(dx, dy, dz, dx, dy, dz)) - r, 0);
		if (d > maxR){return -1;}
		return d * d;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = _getClosestPoint(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize || abs(dy) > hsize || abs(dz) > hsize) return false;
		return true;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Torus];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Torus] = colmesh_create_torus(32, 20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Torus];
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		var scale = point_distance_3d(0, 0, 0, W[0], W[1], W[2]);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), r * scale);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @func colmesh_disk(x, y, z, xup, yup, zup, R, r)
function colmesh_disk(_x, _y, _z, _xup, _yup, _zup, _R, _r) : colmesh_shapes() constructor
{
	type = eColMeshShape.Disk;
	x = _x;
	y = _y;
	z = _z;
	var l = sqrt(cmDot(_xup, _yup, _zup, _xup, _yup, _zup));
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
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var rr = R + r;
		if (x - rr < maxx && y - rr < maxy && z - rr < maxz && x + rr > minx && y + rr > miny && z + rr > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, _xup, _yup, _zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		gml_pragma("forceinline");
		static ret = array_create(3);
		var d = cmDot(_xup, _yup, _zup, xup, yup, zup);
		if (d != 0)
		{
			var d = cmDot(x - _x, y - _y, z - _z, xup, yup, zup) / d;
			var p = _getDiskCoord(_x + _xup * d, _y + _yup * d, _z + _zup * d);
			d = cmDot(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
		}
		else
		{
			d = cmDot(x - _x, y - _y, z - _z, _xup, _yup, _zup);
		}
		d = clamp(d, 0, height);
		ret[0] = _x + _xup * d;
		ret[1] = _y + _yup * d;
		ret[2] = _z + _zup * d;
		return ret;
	}
	
	/// @func _getDiskCoord(x, y, z)
	static _getDiskCoord = function(_x, _y, _z)
	{
		gml_pragma("forceinline");
		static ret = array_create(3);
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var dp = cmDot(dx, dy, dz, xup, yup, zup);
		dx -= xup * dp;
		dy -= yup * dp;
		dz -= zup * dp;
		var l = cmDot(dx, dy, dz, dx, dy, dz);
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
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*
			Algorithm created by TheSnidr
			This is an approximation using the same principle as ray marching
		*/
		var repetitions = 15;
		
		var ox = ray[0],	oy = ray[1],	oz = ray[2];
		var ex = ray[3],	ey = ray[4],	ez = ray[5];
		var dx = ex - ox,	dy = ey - oy,	dz = ez - oz;
		ox -= x;
		oy -= y;
		oz -= z;
		var lox = cmDot(ox, oy, oz, inv0, inv4, inv8);
		var loy = cmDot(ox, oy, oz, inv1, inv5, inv9);
		var loz = cmDot(ox, oy, oz, inv2, inv6, inv10);
		var ldx = cmDot(dx, dy, dz, inv0, inv4, inv8);
		var ldy = cmDot(dx, dy, dz, inv1, inv5, inv9);
		var ldz = cmDot(dx, dy, dz, inv2, inv6, inv10);
		var l = cmDist(0, 0, 0, ldx, ldy, ldz);
		ldx /= l;
		ldy /= l;
		ldz /= l;
		var p = 0, n = 0, d = 0;
		var radiusRatio = r / R;
		repeat repetitions 
		{
			p = n;
			n = (point_distance(0, 0, max(0., point_distance(0, 0, lox, loy) - 1), loz) - radiusRatio);
			d += n;
			if (p > 0 && n > R){return false;} //The ray missed the torus, and we can remove it from the ray casting algorithm
			if (d > l){return false;} //The ray did not reach the torus
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
		var n = point_distance_3d(itsX, itsY, itsZ, p[0], p[1], p[2]);
		if (n == 0){return false;}
		return new colmesh_raycast_result(itsX, itsY, itsZ, (itsX - p[0]) / n, (itsY - p[1]) / n, (itsZ - p[2]) / n, true, self);
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
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
		var d = sqrt(cmDot(dx, dy, dz, dx, dy, dz));
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		gml_pragma("forceinline");
		var p = _getDiskCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var _r = r + radius;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d > _r * _r) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, _r - d, slope);
		}
		return true;
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		var d = max(sqrt(cmDot(dx, dy, dz, dx, dy, dz)) - r, 0);
		if (d > maxR){return -1;}
		return d * d;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		var p = _getClosestPoint(bX, bY, bZ);
		var dx = p[0] - bX;
		var dy = p[1] - bY;
		var dz = p[2] - bZ;
		if (abs(dx) > hsize || abs(dy) > hsize || abs(dz) > hsize) return false;
		return true;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Disk];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Disk] = colmesh_create_disk(32, 20, 1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Disk];
		}
		static M = array_create(16);
		colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R, M);
		
		var sh = shader_current();
		var W = matrix_get(matrix_world);
		var scale = point_distance_3d(0, 0, 0, W[0], W[1], W[2]);
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), r * scale);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	#endregion
}

/// @func colmesh_cube(x, y, z, xsize, ysize, zsize)
function colmesh_cube(_x, _y, _z, xsize, ysize, zsize) : colmesh_shapes() constructor
{
	type = eColMeshShape.Cube;
	x = _x;
	y = _y;
	z = _z;
	halfX = xsize / 2;
	halfY = ysize / 2;
	halfZ = zsize / 2;
	
	#region functions
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (x - halfX < maxx && y - halfY < maxy && z - halfZ < maxz && x + halfX > minx && y + halfY > miny && z + halfZ > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, xup, yup, zup, height)
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
		var d = cmDot(px - _x, py - _y, pz - _z, xup, yup, zup);
		d = clamp(d, 0, height);
		var rx1 = _x + xup * d;
		var ry1 = _y + yup * d;
		var rz1 = _z + zup * d;
		var d1 = cmSqr(rx1 - px, ry1 - py, rz1 - pz);
		
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
		var d = cmDot(px - _x, py - _y, pz - _z, xup, yup, zup);
		d = clamp(d, 0, height);
		var rx2 = _x + xup * d;
		var ry2 = _y + yup * d;
		var rz2 = _z + zup * d;
		var d2 = cmSqr(rx2 - px, ry2 - py, rz2 - pz);
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
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		//Algorithm created by TheSnidr
		var x1 = (ray[0] - x) / halfX;
		var y1 = (ray[1] - y) / halfY;
		var z1 = (ray[2] - z) / halfZ;
		var x2 = (ray[3] - x) / halfX;
		var y2 = (ray[4] - y) / halfY;
		var z2 = (ray[5] - z) / halfZ;
		
		var nx, ny, nz
		var intersection = false;
		var insideBlock = true;
		if (x2 != x1 && abs(x1) > 1)
		{
			insideBlock = false;
			var s = sign(x1 - x2);
			var t = (s - x1) / (x2 - x1);
			if (t >= 0 && t <= 1)
			{
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 && abs(itsZ) <= 1)
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
		if (y2 != y1 && abs(y1) > 1)
		{
			insideBlock = false;
			var s = sign(y1 - y2);
			var t = (s - y1) / (y2 - y1);
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 && abs(itsZ) <= 1)
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
		if (z2 != z1 && abs(z1) > 1)
		{
			insideBlock = false;
			var s = sign(z1 - z2);
			var t = (s - z1) / (z2 - z1);
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 && abs(itsY) <= 1)
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
		if (insideBlock || !intersection){return false;}
		
		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		return new colmesh_raycast_result(x + x2 * halfX, y + y2 * halfY, z + z2 * halfZ, nx, ny, nz, true, self);
	}
		
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
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
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
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
			var d = cmDot(dx, dy, dz, nx, ny, nz);
			colmesh__displace(nx, ny, nz, _xup, _yup, _zup, radius - d, slope);
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
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d > radius * radius) return false;
		d = sqrt(d);
		if (d > 0)
		{
			colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, radius - d, slope);
		}
		return true;
	}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
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
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Cube];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Cube] = colmesh_create_block(1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Cube];
		}
		static M = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
		M[0]  = halfX;
		M[5]  = halfY;
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

/// @func colmesh_block(blockMatrix)
function colmesh_block(M) : colmesh_shapes() constructor
{
	type = eColMeshShape.Block;
	x = M[12];
	y = M[13];
	z = M[14];
	
	lx = 1 / cmDist(0, 0, 0, M[0], M[1], M[2]);
	ly = 1 / cmDist(0, 0, 0, M[4], M[5], M[6]);
	lz = 1 / cmDist(0, 0, 0, M[8], M[9], M[10]);
	
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
	
	/// @func getMinMax()
	static getMinMax = function()
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
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var dx = abs(xto) + abs(xsi) + abs(xup);
		var dy = abs(yto) + abs(ysi) + abs(yup);
		var dz = abs(zto) + abs(zsi) + abs(zup);
		if (x - dx < maxx && y - dy < maxy && z - dz < maxz && x + dx > minx && y + dy > miny && z + dz > minz)
		{
			return true;
		}
		return false;
	}
	
	/// @func _capsuleGetRef(x, y, z, _xup, _yup, _zup, height)
	static _capsuleGetRef = function(_x, _y, _z, _xup, _yup, _zup, height)
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
		var bx = clamp(cmDot(xx, yy, zz, inv0, inv4, inv8),  -1, 1);
		var by = clamp(cmDot(xx, yy, zz, inv1, inv5, inv9),  -1, 1);
		var bz = clamp(cmDot(xx, yy, zz, inv2, inv6, inv10), -1, 1);
		var px = x + cmDot(bx, by, bz, xto, xsi, xup);
		var py = y + cmDot(bx, by, bz, yto, ysi, yup);
		var pz = z + cmDot(bx, by, bz, zto, zsi, zup);
		var d = cmDot(px - _x, py - _y, pz - _z, _xup, _yup, _zup);
		d = clamp(d, 0, height);
		var rx1 = _x + _xup * d;
		var ry1 = _y + _yup * d;
		var rz1 = _z + _zup * d;
		var d1 = cmSqr(rx1 - px, ry1 - py, rz1 - pz);
		
		//Check top of capsule
		xx += _xup * height;
		yy += _yup * height;
		zz += _zup * height;
		var bx = clamp(cmDot(xx, yy, zz, inv0, inv4, inv8),  -1, 1);
		var by = clamp(cmDot(xx, yy, zz, inv1, inv5, inv9),  -1, 1);
		var bz = clamp(cmDot(xx, yy, zz, inv2, inv6, inv10), -1, 1);
		var px = x + cmDot(bx, by, bz, xto, xsi, xup);
		var py = y + cmDot(bx, by, bz, yto, ysi, yup);
		var pz = z + cmDot(bx, by, bz, zto, zsi, zup);
		var d = cmDot(px - _x, py - _y, pz - _z, _xup, _yup, _zup);
		d = clamp(d, 0, height);
		var rx2 = _x + _xup * d;
		var ry2 = _y + _yup * d;
		var rz2 = _z + _zup * d;
		var d2 = cmSqr(rx2 - px, ry2 - py, rz2 - pz);
		
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
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		//Algorithm created by TheSnidr
		var ox = ray[0] - x, oy = ray[1] - y, oz = ray[2] - z;
		var ex = ray[3] - x, ey = ray[4] - y, ez = ray[5] - z;
		var x1 = cmDot(ox, oy, oz, inv0, inv4, inv8);
		var y1 = cmDot(ox, oy, oz, inv1, inv5, inv9);
		var z1 = cmDot(ox, oy, oz, inv2, inv6, inv10);
		var x2 = cmDot(ex, ey, ez, inv0, inv4, inv8);
		var y2 = cmDot(ex, ey, ez, inv1, inv5, inv9);
		var z2 = cmDot(ex, ey, ez, inv2, inv6, inv10);
		var nx = 0, ny = 0, nz = 1;
		var intersection = false;
		var insideBlock = true;
		if (x2 != x1 && abs(x1) > 1)
		{
			insideBlock = false;
			var s = sign(x1 - x2);
			var t = (s - x1) / (x2 - x1);
			if (t >= 0 && t <= 1)
			{
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 && abs(itsZ) <= 1)
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
		if (y2 != y1 && abs(y1) > 1)
		{
			insideBlock = false;
			var s = sign(y1 - y2);
			var t = (s - y1) / (y2 - y1);
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 && abs(itsZ) <= 1)
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
		if (z2 != z1 && abs(z1) > 1)
		{
			insideBlock = false;
			var s = sign(z1 - z2);
			var t = (s - z1) / (z2 - z1);
			if (t >= 0 && t <= 1)
			{
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 && abs(itsY) <= 1)
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
		if (insideBlock || !intersection) return false;

		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		return new colmesh_raycast_result(
					x + cmDot(x2, y2, z2, xto, xsi, xup), 
					y + cmDot(x2, y2, z2, yto, ysi, yup),
					z + cmDot(x2, y2, z2, zto, zsi, zup),
					nx, ny, nz, true, self);
	}
		
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
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
		var bx = cmDot(_x, _y, _z, inv0, inv4, inv8);
		var by = cmDot(_x, _y, _z, inv1, inv5, inv9);
		var bz = cmDot(_x, _y, _z, inv2, inv6, inv10);
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
		ret[@ 0] = x + cmDot(bx, by, bz, xto, xsi, xup);
		ret[@ 1] = y + cmDot(bx, by, bz, yto, ysi, yup);
		ret[@ 2] = z + cmDot(bx, by, bz, zto, zsi, zup);
		return ret;
	}
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(_x, _y, _z, _xup, _yup, _zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		//Find normalized block space position
		var xx = _x - x;
		var yy = _y - y;
		var zz = _z - z;
		var bx = cmDot(xx, yy, zz, inv0, inv4, inv8);
		var by = cmDot(xx, yy, zz, inv1, inv5, inv9);
		var bz = cmDot(xx, yy, zz, inv2, inv6, inv10);
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
			var px = x + cmDot(bx, by, bz, xto, xsi, xup);
			var py = y + cmDot(bx, by, bz, yto, ysi, yup);
			var pz = z + cmDot(bx, by, bz, zto, zsi, zup);
			var dx = _x - px;
			var dy = _y - py;
			var dz = _z - pz;
			var _d = cmDot(dx, dy, dz, nx, ny, nz);
			colmesh__displace(nx, ny, nz, _xup, _yup, _zup, radius - _d, slope);
			return true;
		}
		//Nearest point on the cube in normalized block space
		bx = clamp(bx, -1, 1);
		by = clamp(by, -1, 1);
		bz = clamp(bz, -1, 1);
		var px = x + cmDot(bx, by, bz, xto, xsi, xup);
		var py = y + cmDot(bx, by, bz, yto, ysi, yup);
		var pz = z + cmDot(bx, by, bz, zto, zsi, zup);
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d > radius * radius){return false;}
		d = sqrt(d);
		colmesh__displace(dx / d, dy / d, dz / d, _xup, _yup, _zup, radius - d, slope);
		return true;
	}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		var bx = cmDot(xx, yy, zz, inv0, inv4, inv8);
		var by = cmDot(xx, yy, zz, inv1, inv5, inv9);
		var bz = cmDot(xx, yy, zz, inv2, inv6, inv10);
		if (max(abs(bx), abs(by), abs(bz)) <= 1)
		{	//If the center of the sphere is inside the cube, normalize the largest axis
			return 0; //0 is the highest possible priority
		}
		//Nearest point on the cube in normalized block space
		bx = clamp(bx, -1, 1);
		by = clamp(by, -1, 1);
		bz = clamp(bz, -1, 1);
		var px = x + cmDot(bx, by, bz, xto, xsi, xup);
		var py = y + cmDot(bx, by, bz, yto, ysi, yup);
		var pz = z + cmDot(bx, by, bz, zto, zsi, zup);
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = cmDot(dx, dy, dz, dx, dy, dz);
		if (d > maxR * maxR){return -1;}
		return d;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
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
		var bx = cmDot(xx, yy, zz, inv0, inv4, inv8);
		var by = cmDot(xx, yy, zz, inv1, inv5, inv9);
		var bz = cmDot(xx, yy, zz, inv2, inv6, inv10);
		if (max(abs(bx), abs(by), abs(bz)) < 1) return true;
		
		//Then check if the nearest point in the cube is inside the AABB
		var bx = clamp(cmDot(dx, dy, dz, inv0, inv4, inv8),  -1, 1);
		var by = clamp(cmDot(dx, dy, dz, inv1, inv5, inv9),  -1, 1);
		var bz = clamp(cmDot(dx, dy, dz, inv2, inv6, inv10), -1, 1);
		var dx = bX - cmDot(bx, by, bz, xto, xsi, xup);
		var dy = bY - cmDot(bx, by, bz, yto, ysi, yup);
		var dz = bZ - cmDot(bx, by, bz, zto, zsi, zup);
		if (max(abs(dx), abs(dy), abs(dz)) < hsize) return true;
		
		return false;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex = -1)
	{
		static vbuff = global.ColMeshDebugShapes[eColMeshShape.Block];
		if (vbuff < 0)
		{
			global.ColMeshDebugShapes[eColMeshShape.Block] = colmesh_create_block(1, 1);
			vbuff = global.ColMeshDebugShapes[eColMeshShape.Block];
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

/// @func colmesh_dynamic(shape, colMesh, M, shapeInd)
function colmesh_dynamic(_shape, _colMesh, _M, _shapeInd) : colmesh_shapes() constructor
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
	
	/// @func capsuleCollision(x, y, z, xup, yup, zup, radius, height)
	static capsuleCollision = function(x, y, z, xup, yup, zup, radius, height)
	{
		//Returns true if the given capsule collides with the shape
		var xx = I[12] + cmDot(x, y, z, I[0], I[4], I[8]);
		var yy = I[13] + cmDot(x, y, z, I[1], I[5], I[9]);
		var zz = I[14] + cmDot(x, y, z, I[2], I[6], I[10]);
		var ux = scale * cmDot(xup, yup, zup, I[0], I[4], I[8]);
		var uy = scale * cmDot(xup, yup, zup, I[1], I[5], I[9]);
		var uz = scale * cmDot(xup, yup, zup, I[2], I[6], I[10]);
		return shape.capsuleCollision(xx, yy, zz, ux, uy, uz, radius / scale, height / scale);
	}
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var mm = getMinMax();
		if (mm[0] < maxx && mm[1] < maxy && mm[2] < maxz && mm[3] > minx && mm[4] > miny && mm[5] > minz)
		{
			return true;
		}
		return false;
	}
	
	#endregion
	
	#region Shape-specific functions
	
	/// @func setMatrix(M, moving)
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
		array_copy(oldReg, 0, colMesh._getRegions(getMinMax()), 0, 6);
		
		moving = _moving;
		array_copy(M, 0, _M, 0, 16);
		
		//Orthogonalize the side vector
		var sqrScale = cmDot(M[0], M[1], M[2], M[0], M[1], M[2]);
		var sideDp = cmDot(M[0], M[1], M[2], M[4], M[5], M[6]) / sqrScale;
		M[4] -= M[0] * sideDp;
		M[5] -= M[1] * sideDp;
		M[6] -= M[2] * sideDp;
		var l = sqrt(cmDot(M[4], M[5], M[6], M[4], M[5], M[6]));
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
		colmesh_matrix_invert(M, I);
		
		var mm = getMinMax();
		colMesh._expandBoundaries(mm);
		var newReg = colMesh._getRegions(mm);
		if !array_equals(oldReg, newReg)
		{
			colMesh.removeShapeFromSubdiv(self, oldReg);
			colMesh.addShapeToSubdiv(self, newReg, false);
		}
	}
	
	/// @func move(colMesh, x, y, z)
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
	
	/// @func getMinMax()
	static getMinMax = function()
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
			var mm = shape.getMinMax();
		}
		var xs = (mm[3] - mm[0]) * .5;
		var ys = (mm[4] - mm[1]) * .5;
		var zs = (mm[5] - mm[2]) * .5;
		var mx = (mm[0] + mm[3]) * .5;
		var my = (mm[1] + mm[4]) * .5;
		var mz = (mm[2] + mm[5]) * .5;
		var tx = M[12] + cmDot(mx, my, mz, M[0], M[4], M[8]);
		var ty = M[13] + cmDot(mx, my, mz, M[1], M[5], M[9]);
		var tz = M[14] + cmDot(mx, my, mz, M[2], M[6], M[10]);
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
	
	/// @func _castRay(ray)
	static _castRay = function(ray)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		//Transform the ray to local space
		var ox = ray[0], oy = ray[1], oz = ray[2];
		var ex = ray[3], ey = ray[4], ez = ray[5];
		var _ray = array_create(6);
		_ray[0] = I[12] + cmDot(ox, oy, oz, I[0], I[4], I[8]);
		_ray[1] = I[13] + cmDot(ox, oy, oz, I[1], I[5], I[9]);
		_ray[2] = I[14] + cmDot(ox, oy, oz, I[2], I[6], I[10]);
		_ray[3] = I[12] + cmDot(ex, ey, ez, I[0], I[4], I[8]);
		_ray[4] = I[13] + cmDot(ex, ey, ez, I[1], I[5], I[9]);
		_ray[5] = I[14] + cmDot(ex, ey, ez, I[2], I[6], I[10]);
		
		var hit = false;
		if (shape.type == eColMeshShape.Mesh)
		{
			//If this is a mesh, we want to raycast against all the shapes the mesh contains
			hit = shape.castRay(_ray[0], _ray[1], _ray[2], _ray[3], _ray[4], _ray[5]);
		}
		else
		{
			//If this is not a mesh, we can raycast against just this shape
			hit = shape._castRay(_ray);
		}
		if (!is_struct(hit))
		{
			return false;
		}
		var ex = hit.x,  ey = hit.y,  ez = hit.z;
		var nx = hit.nx, ny = hit.ny, nz = hit.nz;
		return new colmesh_raycast_result(
					M[12] + cmDot(ex, ey, ez, M[0], M[4], M[8]),
					M[13] + cmDot(ex, ey, ez, M[1], M[5], M[9]),
					M[14] + cmDot(ex, ey, ez, M[2], M[6], M[10]),
					cmDot(nx, ny, nz, M[0], M[4], M[8])  / scale,
					cmDot(nx, ny, nz, M[1], M[5], M[9])  / scale,
					cmDot(nx, ny, nz, M[2], M[6], M[10]) / scale,
					true, hit.struct)
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		if (shape.type == eColMeshShape.Mesh)
		{
			//Find normalized block space position
			var bx = M[12] + cmDot(_x, _y, _z, I[0], I[4], I[8]);
			var by = M[13] + cmDot(_x, _y, _z, I[1], I[5], I[9]);
			var bz = M[14] + cmDot(_x, _y, _z, I[2], I[6], I[10]);
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
				cmCol.x = p[0];
				cmCol.y = p[1];
				cmCol.z = p[2];
			}
			else
			{	//Nearest point on the cube in normalized block space
				bx = clamp(bx, -1, 1);
				by = clamp(by, -1, 1);
				bz = clamp(bz, -1, 1);
				var p = colmesh_matrix_transform_vertex(M, bx, by, bz);
			}
			cmCol.x = p[0];
			cmCol.y = p[1];
			cmCol.z = p[2];
			return cmCol;
		}
		var p = colmesh_matrix_transform_vertex(I, _x, _y, _z);
		var n = shape._getClosestPoint(p[0], p[1], p[2]);
		return colmesh_matrix_transform_vertex(M, n[0], n[1], n[2]);
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, xup, yup, zup, height)
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
		var r = shape._capsuleGetRef(p[0], p[1], p[2], u[0], u[1], u[2], height / scale);
		return colmesh_matrix_transform_vertex(M, r[0], r[1], r[2]);
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ)
	{
		/*
			A supplementary function, not meant to be used by itself.
			For dynamic shapes it always returns true
		*/
		return true;
	}
	
	/// @func _displaceSphere(x, y, z, xup, yup, zup, height, radius, slope, fast)
	static _displaceSphere = function(x, y, z, xup, yup, zup, height, radius, slope, fast)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape by changing the global array cmCol
			Returns true if there was a collision.
		*/
		var temp = {
			x: cmCol.x,
			y: cmCol.y,
			z: cmCol.z,
			nx: cmCol.nx,
			ny: cmCol.ny,
			nz: cmCol.nz,
			maxdp: cmCol.maxdp,
			ground: cmCol.ground,
			collision: cmCol.collision
		}
		
		//cmCol contains the current position of the capsule in indices 0-3, and the current collision normal vector in indices 3-5
		var _x = cmCol.x,  _y = cmCol.y,  _z = cmCol.z;
		var nx = cmCol.nx, ny = cmCol.ny, nz = cmCol.nz;
		cmCol.x  = I[12] + cmDot(_x, _y, _z, I[0], I[4], I[8]);
		cmCol.y  = I[13] + cmDot(_x, _y, _z, I[1], I[5], I[9]);
		cmCol.z  = I[14] + cmDot(_x, _y, _z, I[2], I[6], I[10]);
		cmCol.nx = scale * cmDot(nx, ny, nz, I[0], I[4], I[8]);
		cmCol.ny = scale * cmDot(nx, ny, nz, I[1], I[5], I[9]);
		cmCol.nz = scale * cmDot(nx, ny, nz, I[2], I[6], I[10]);
		var _xup = scale * cmDot(xup, yup, zup, I[0], I[4], I[8]);
		var _yup = scale * cmDot(xup, yup, zup, I[1], I[5], I[9]);
		var _zup = scale * cmDot(xup, yup, zup, I[2], I[6], I[10]);
		
		var col = false;
		if (shape.type == eColMeshShape.Mesh)
		{
			//Special case if this dynamic contains a mesh
			var slopeAngle = (slope >= 1) ? 0 : darccos(slope);
			shape.displaceCapsule(cmCol.x, cmCol.y, cmCol.z, _xup, _yup, _zup, radius / scale, height / scale, slopeAngle, fast);
			if (cmCol.collision)
			{
				cmCol.collision = max(temp.maxdp, _xup * cmCol.nx + _yup * cmCol.ny + _zup * cmCol.nz);
				col = true;
			}
		}
		else
		{
			//This dynamic contains a primitive
			var lx = I[12] + cmDot(x, y, z, I[0], I[4], I[8]);
			var ly = I[13] + cmDot(x, y, z, I[1], I[5], I[9]);
			var lz = I[14] + cmDot(x, y, z, I[2], I[6], I[10]);
			col = shape._displaceSphere(lx, ly, lz, _xup, _yup, _zup, height / scale, radius / scale, slope, fast);
		}
		if (col)
		{
			if (slope < 1 && cmTransform == true)
			{
				array_push(cmCol.transformQueue, M);
				if (moving)
				{
					//This object is moving. Save its current world matrix and the inverse of the previous 
					//world matrix so that figuring out the delta matrix later is as easy as a matrix multiplication
					array_push(cmCol.transformQueue, pI);
				}
				//If the transformation queue is empty, this is the first dynamic to be added. 
				//If it's static as well, there's no point in adding it to the transformation queue
				else if (!ds_queue_empty(cmTransform))
				{	
					//If the dynamic is not marked as "moving", save the current inverse matrix to the transformation 
					//queue so that no transformation is done. It will then only transform the preceding transformations
					//into its own frame of reference
					array_push(cmCol.transformQueue, I);
				}
			}
			//Transform collision position and normal to world-space
			var _x = cmCol.x,  _y = cmCol.y,  _z = cmCol.z;
			var nx = cmCol.nx, ny = cmCol.ny, nz = cmCol.nz;
			cmCol.x  = M[12] + cmDot(_x, _y, _z, M[0], M[4], M[8]);
			cmCol.y  = M[13] + cmDot(_x, _y, _z, M[1], M[5], M[9]);
			cmCol.z  = M[14] + cmDot(_x, _y, _z, M[2], M[6], M[10]);
			cmCol.nx = cmDot(nx, ny, nz, M[0], M[4], M[8])  / scale;
			cmCol.ny = cmDot(nx, ny, nz, M[1], M[5], M[9])  / scale;
			cmCol.nz = cmDot(nx, ny, nz, M[2], M[6], M[10]) / scale;
			return true;
		}
		
		//There was no collision. Revert any temporary changes to cmCol
		cmCol.x = temp.x;
		cmCol.y = temp.y;
		cmCol.z = temp.z;
		cmCol.nx = temp.nx;
		cmCol.ny = temp.ny;
		cmCol.nz = temp.nz;
		cmCol.maxdp = temp.maxdp;
		cmCol.ground = temp.ground;
		cmCol.collision = temp.collision;
		return false;
	}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		var pri = shape._getPriority(p[0], p[1], p[2], maxR / scale);
		return pri * scale * scale;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex)
	{
		var W = matrix_get(matrix_world);
		matrix_set(matrix_world, matrix_multiply(M, W));
		if (shape.type == eColMeshShape.Mesh)
		{
			if (cmRecursion < cmMaxRecursion)
			{
				++ cmRecursion;
				shape.debugDraw(-1, tex);
				-- cmRecursion;
			}
		}
		else
		{
			shape.debugDraw(tex);
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
	static capsuleCollision = function(){return false;}
	static _displace = function(){}
	static _addToSubdiv = function(){return 0;}
	static getMinMax = function(){return array_create(6);}
	static _capsuleGetRef = function()
	{
		static ret = array_create(3);
		return ret;
	}
	static _castRay = function(){return false;}	
	static _displaceSphere = function(){return false;}
	static _getPriority = function(){return -1;}
	static _getClosestPoint = function()
	{
		static ret = array_create(3);
		return ret;
	}
	static _intersectsCube = function(){return false;}
}