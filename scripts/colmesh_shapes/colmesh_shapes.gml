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
	Mesh, Sphere, Capsule, Cylinder, Torus, Cube, Block, Dynamic, None, Disk, Cone, Trigger, Heightmap, ColMesh, Num
}

function colmesh_shapes(group) constructor
{
	/*
		This is the parent struct for all the other possible collision shapes
		This struct contains a bunch of functions that are overwritten for the child structs.
	*/
	self.type = eColMeshShape.None;
	self.group = group ?? cmGroupSolid;
	
	#region Shared functions
	
	/// @func setSolid(solid)
	static setSolid = function(solid)
	{
		if (solid){	
			group |= cmGroupSolid; //Flag as solid
		}
		else{	
			group &= ~cmGroupSolid; //Remove solid flag
		}
	}
	
	/// @func setTrigger(solid, colFunc*, rayFunc*)
	static setTrigger = function(solid, _colFunc, _rayFunc)
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
		setSolid(solid);
		if (!is_undefined(_colFunc)){	
			group |= cmGroupColTrigger; //Flag as trigger
			colFunc = _colFunc;
		}
		else{	
			group &= ~cmGroupColTrigger; //Remove trigger flag
		}
		if (!is_undefined(_rayFunc)){	
			group |= cmGroupRayTrigger; //Flag as trigger
			rayFunc = _rayFunc;
		}
		else{
			group &= ~cmGroupRayTrigger; //Remove trigger flag
		}
	}
	
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
		if (type == eColMeshShape.Block)
		{
			M[12] = _x;
			M[13] = _y;
			M[14] = _z;
		}
		else if (type == eColMeshShape.Dynamic)
		{
			M[12] = _x;
			M[13] = _y;
			M[14] = _z;
			moving = false;
		}
		else
		{
			x = _x;
			y = _y;
			z = _z;
		}
		var newReg = colMesh._getRegions(getMinMax());
		if (!array_equals(oldReg, newReg))
		{
			colMesh.removeShapeFromSubdiv(self, oldReg);
			colMesh.addShapeToSubdiv(self, newReg, false);
		}
	}
	
	#endregion
	
	#region Shape-specific functions
	
	/// @func getMinMax()
	static getMinMax = function()
	{
		static minMax = array_create(6);
		return minMax;
	}
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz){return false;}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, xup, yup, zup, height)
	{
		static ret = array_create(3);
		return ret;
	}
	
	/// @func _castRay(ray[6])
	static _castRay = function(ray)
	{
		return [0, 0, 0, 0, 0, 1, self, 1];
	}
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, x, y, z, radius){return false;}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(x, y, z, maxR){return 1;}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(x, y, z)
	{
		static ret = array_create(3);
		return ret;
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ){return false;}
	
	/// @func debugDraw(region*, texture*)
	static debugDraw = function(region, tex){}
	
	static toString = function()
    {
        return "ColMesh shape: None. Group: " + string(group);
    }
	
	#endregion
}

function colmesh_mesh(name = "mesh" + string(ds_map_size(cmMeshMap)), mesh = undefined, matrix = undefined, group = cmGroupSolid) : colmesh_shapes(group) constructor
{
	/*
		This is the parent struct for the ColMesh itself. Weird, huh?
		That is because of some optimizations for triangle meshes. It's much faster to read
		triangle info from a ds_grid than it is to store every triangle as its own struct, 
		so triangles are only saved as indices, and read from the ds_grid when necessary.
		
		This struct contains a bunch of functions that are overwritten for the child structs.
	*/
	self.name = name;
	self.type = eColMeshShape.Mesh;
	self.solid = true;
	self.triangle = -1;
	self.shapeList = ds_list_create();
	self.triangles = [];
	self.matrix = -1;
	self.submeshes = 0;
	
	cmMeshMap[? name] = self;
	
	if (!is_undefined(mesh))
	{
	
		var load = false;
		if (is_string(mesh))
		{
			load = true;
			mesh = colmesh_load_obj_to_buffer(mesh);
		}
		if (is_array(mesh))
		{
			load = true;
			var _mesh = buffer_create(1, buffer_fixed, 1);
			var num = array_length(mesh);
			var totalSize = 0;
			for (var i = 0; i < num; i ++) 
			{
				var buffSize = buffer_get_size(mesh[i]);
				var buffPos = totalSize;
				totalSize += buffSize;
				buffer_resize(mesh, totalSize);
				buffer_copy(mesh[i], 0, buffSize, mesh, buffPos);
			}
			mesh = _mesh;
		}
		if (mesh >= 0)
		{
			//Create triangle list from mesh
			var bytesPerTri = cmBytesPerVert * 3;
			var triNum = buffer_get_size(mesh) div bytesPerTri;
			triangles = array_create(triNum);
			for (var i = 0; i < triNum; i ++)
			{
				var tri = array_create(9);
				for (var j = 0; j < 3; j ++){
					for (var k = 0; k < 3; k ++){
						tri[j * 3 + k] = buffer_peek(mesh, i * bytesPerTri + j * cmBytesPerVert + k * 4, buffer_f32);
					}
				}
				if (is_array(matrix))
				{
					//The shape has a transformation matrix. We need to copy the triangle into a new array and transform it.
					var V = array_create(9);
					array_copy(V, 0, matrix_transform_vertex(matrix, tri[0], tri[1], tri[2]), 0, 3);
					array_copy(V, 3, matrix_transform_vertex(matrix, tri[3], tri[4], tri[5]), 0, 3);
					array_copy(V, 6, matrix_transform_vertex(matrix, tri[6], tri[7], tri[8]), 0, 3);
					tri = V;
				}
				triangles[i] = tri;
			}
			if (load)
			{
				buffer_delete(mesh);
			}
		}
		else
		{
			show_debug_message("Error in function colmesh_mesh: Could not add given mesh " + string(mesh) + " to colmesh!");
		}
	}
	
	//// @func freeze()
	static freeze = function()
	{
		//This will delete any geometry info contained within the mesh itself. It will not delete any geometry added to a ColMesh.
		//After a mesh has been frozen, it can no longer be added to a colmesh.
		triangles = [];
		ds_list_destroy(shapeList);
	}
	
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
		var d = dot_product_3d(xup, yup, zup, nx, ny, nz);
		if (d != 0)
		{
			var trace = dot_product_3d(v1x - _x, v1y - _y, v1z - _z, nx, ny, nz) / d;
			var traceX = _x + xup * trace;
			var traceY = _y + yup * trace;
			var traceZ = _z + zup * trace;
			var p = _getClosestPoint(traceX, traceY, traceZ);
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
	
	/// @func _castRay(ray[6], mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		var ox = ray[0], oy = ray[1], oz = ray[2];
		var dx = ray[3] - ox;
		var dy = ray[4] - oy;
		var dz = ray[5] - oz;
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var h = dot_product_3d(dx, dy, dz, nx, ny, nz);
		if (h == 0){return false;} //Continue if the ray is parallel to the surface of the triangle (ie. perpendicular to the triangle's normal)
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var s = - sign(h);
		var h = dot_product_3d(v1x - ox, v1y - oy, v1z - oz, nx, ny, nz) / h;
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
		var dp = dot_product_3d(nx, ny, nz, az * by - ay * bz, ax * bz - az * bx, ay * bx - ax * by);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 || t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
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
		var dp = dot_product_3d(nx, ny, nz, az * by - ay * bz, ax * bz - az * bx, ay * bx - ax * by);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 || t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
	
		//Check third edge
		var ax = itsX - v3x;
		var ay = itsY - v3y;
		var az = itsZ - v3z;
		var bx = v1x - v3x;
		var by = v1y - v3y;
		var bz = v1z - v3z;
		var dp = dot_product_3d(nx, ny, nz, az * by - ay * bz, ax * bz - az * bx, ay * bx - ax * by);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 || t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
	
		//The line intersects the triangle. Save the triangle normal and intersection.
		return [itsX, itsY, itsZ, nx * s, ny * s, nz * s, triangle, h];
	}
	
	
	/// @func _castSphere(ray[6], radius, mask)
	static _castSphereUNFINISHED = function(ray, radius, mask)
	{
		var ox = ray[0], oy = ray[1], oz = ray[2];
		var dx = ray[3] - ox;
		var dy = ray[4] - oy;
		var dz = ray[5] - oz;
		var nx = triangle[9];
		var ny = triangle[10];
		var nz = triangle[11];
		var v1x = triangle[0];
		var v1y = triangle[1];
		var v1z = triangle[2];
		var itsX = ox;
		var itsY = oy;
		var itsZ = oz;
		var h = dot_product_3d(dx, dy, dz, nx, ny, nz);
		var s = sign(h);
		if (h != 0)
		{
			var t = (dot_product_3d(v1x - ox, v1y - oy, v1z - oz, nx, ny, nz) - radius) / h;
			if (t < 0 || t > 1){return false;} //Continue if the intersection is too far away
			itsX = ox + dx * t;
			itsY = oy + dy * t;
			itsZ = oz + dz * t;
		}
			
		//Check that the intersection is inside the first edge
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
		var a  = dot_product_3d(ax, ay, az, bx, by, bz);
		var b  = dot_product_3d(bx, by, bz, bx, by, bz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 || t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}
		/*if (dp <= 0)// || (dp == 0 && a >= 0 && a <= b))
		{return false;
			//The intersection is outside this edge. Cast a sphere against this edge and call it a day
			var kx = (v1z - oz) * by - (v1y - oy) * bz;
			var ky = (v1x - ox) * bz - (v1z - oz) * bx;
			var kz = (v1y - oy) * bx - (v1x - ox) * by;
			var ix = (dz * by + dy * bz);
			var iy = (dx * bz + dz * bx);
			var iz = (dy * bx + dx * by);
				
			var a = (ix * ix + iy * iy + iz * iz);
			var b =  - 2 * (kx * ix + ky * iy + kz * iz);
			var c = kx * kx + ky * ky + kz * kz - radius * radius;
			
			var k = b * b - 4 * a * c;
			if (k < 0){return false;}
			t = (-b - sqrt(k)) / (2 * a);
			if (t > 1){return false;}
			if (t >= 0)
			{
				//The line intersects the triangle. Save the triangle normal and intersection.
				var itsX = ox + dx * t;
				var itsY = oy + dy * t;
				var itsZ = oz + dz * t;
				var itsNX = itsX - v1x;
				var itsNY = itsY - v1y;
				var itsNZ = itsZ - v1z;
				var dp = dot_product_3d(itsNX, itsNY, itsNZ, bx, by, bz) / dot_product_3d(bx, by, bz, bx, by, bz);
				itsNX -= bx * dp;
				itsNY -= by * dp;
				itsNZ -= bz * dp;
				var l = point_distance_3d(0, 0, 0, itsNX, itsNY, itsNZ);
				return [itsX, itsY, itsZ, itsNX / l, itsNY / l, itsNZ / l, triangle, h];
			}
		}*/
		
		//Check that the intersection is inside the second edge
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
		var a  = dot_product_3d(ax, ay, az, bx, by, bz);
		var b  = dot_product_3d(bx, by, bz, bx, by, bz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 || t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}/*if (dp <= 0)// || (dp == 0 && a >= 0 && a <= b))
		{return false;
			//The intersection is outside this edge. Cast a sphere against this edge and call it a day
			var kx = (v2z - oz) * by - (v2y - oy) * bz;
			var ky = (v2x - ox) * bz - (v2z - oz) * bx;
			var kz = (v2y - oy) * bx - (v2x - ox) * by;
			var ix = (dz * by + dy * bz);
			var iy = (dx * bz + dz * bx);
			var iz = (dy * bx + dx * by);
				
			var a = (ix * ix + iy * iy + iz * iz);
			var b =  - 2 * (kx * ix + ky * iy + kz * iz);
			var c = kx * kx + ky * ky + kz * kz - radius * radius;
				
			var k = b * b - 4 * a * c;
			if (k < 0){return false;}
			t = (-b - sqrt(k)) / (2 * a);
			if (t > 1){return false;}
			if (t >= 0)
			{
				//The line intersects the triangle. Save the triangle normal and intersection.
				var itsX = ox + dx * t;
				var itsY = oy + dy * t;
				var itsZ = oz + dz * t;
				var itsNX = itsX - v2x;
				var itsNY = itsY - v2y;
				var itsNZ = itsZ - v2z;
				var dp = dot_product_3d(itsNX, itsNY, itsNZ, bx, by, bz) / dot_product_3d(bx, by, bz, bx, by, bz);
				itsNX -= bx * dp;
				itsNY -= by * dp;
				itsNZ -= bz * dp;
				var l = point_distance_3d(0, 0, 0, itsNX, itsNY, itsNZ);
				return [itsX, itsY, itsZ, itsNX / l, itsNY / l, itsNZ / l, triangle, h];
			}
		}*/
		
		//Check that the intersection is inside the third edge
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
		var a  = dot_product_3d(ax, ay, az, bx, by, bz);
		var b  = dot_product_3d(bx, by, bz, bx, by, bz);
		if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
		if (dp == 0)
		{
			var t = dot_product_3d(ax, ay, az, bx, by, bz);
			if (t < 0 || t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
		}/*if (dp <= 0)// || (dp == 0 && a >= 0 && a <= b))
		{return false;
			//The intersection is outside this edge. Cast a sphere against this edge and call it a day
			var kx = (v3z - oz) * by - (v3y - oy) * bz;
			var ky = (v3x - ox) * bz - (v3z - oz) * bx;
			var kz = (v3y - oy) * bx - (v3x - ox) * by;
			var ix = (dz * by + dy * bz);
			var iy = (dx * bz + dz * bx);
			var iz = (dy * bx + dx * by);
				
			var a = (ix * ix + iy * iy + iz * iz);
			var b =  - 2 * (kx * ix + ky * iy + kz * iz);
			var c = kx * kx + ky * ky + kz * kz - radius * radius;
				
			var k = b * b - 4 * a * c;
			if (k < 0){return false;}
			t = (-b - sqrt(k)) / (2 * a);
			if (t > 1){return false;}
			if (t >= 0)
			{
				//The line intersects the triangle. Save the triangle normal and intersection.
				var itsX = ox + dx * t;
				var itsY = oy + dy * t;
				var itsZ = oz + dz * t;
				var itsNX = itsX - v3x;
				var itsNY = itsY - v3y;
				var itsNZ = itsZ - v3z;
				var dp = dot_product_3d(itsNX, itsNY, itsNZ, bx, by, bz) / dot_product_3d(bx, by, bz, bx, by, bz);
				itsNX -= bx * dp;
				itsNY -= by * dp;
				itsNZ -= bz * dp;
				var l = point_distance_3d(0, 0, 0, itsNX, itsNY, itsNZ);
				return [itsX, itsY, itsZ, itsNX / l, itsNY / l, itsNZ / l, triangle, h];
			}
		}*/
	
		//The line intersects the triangle. Save the triangle normal and intersection.
		return [itsX, itsY, itsZ, nx * s, ny * s, nz * s, triangle, h];
	}
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, x, y, z, radius)
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
		var D = dot_product_3d(t0, t1, t2, nx, ny, nz);
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
		var dp = dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz);
		if (dp < 0)
		{
			var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
			var _nx = t0 - u0 * a;
			var _ny = t1 - u1 * a;
			var _nz = t2 - u2 * a;
			var d = point_distance_3d(0, 0, 0, _nx, _ny, _nz);
			if (d == 0 || d >= radius){return false;}
			d = (radius - d) / d;
			return collider.displace(_nx * d, _ny * d, _nz * d);
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
			var dp = dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz);
			if (dp < 0)
			{
				var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
				var _nx = t0 - u0 * a;
				var _ny = t1 - u1 * a;
				var _nz = t2 - u2 * a;
				var d = point_distance_3d(0, 0, 0, _nx, _ny, _nz);
				if (d == 0 || d >= radius){return false;}
				d = (radius - d) / d;
				return collider.displace(_nx * d, _ny * d, _nz * d);
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
				var dp = dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz);
				if (dp < 0)
				{
					var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
					var _nx = t0 - u0 * a;
					var _ny = t1 - u1 * a;
					var _nz = t2 - u2 * a;
					var d = point_distance_3d(0, 0, 0, _nx, _ny, _nz);
					if (d == 0 || d >= radius){return false;}
					d = (radius - d) / d;
					return collider.displace(_nx * d, _ny * d, _nz * d);
				}
			}
		}
		var s = sign(D) * (radius - abs(D));
		return collider.displace(nx * s, ny * s, nz * s);
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
		var D = dot_product_3d(t0, t1, t2, nx, ny, nz);
		if (abs(D) > maxR){return -1;}
		var v2x = triangle[3];
		var v2y = triangle[4];
		var v2z = triangle[5];
		var u0 = v2x - v1x;
		var u1 = v2y - v1y;
		var u2 = v2z - v1z;
		if (dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz) < 0)
		{
			var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
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
			if (dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz) < 0)
			{
				var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
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
				if (dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz) < 0)
				{
					var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
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
		if (dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz) < 0)
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
			if (dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz) < 0)
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
				if (dot_product_3d(t2 * u1 - t1 * u2, t0 * u2 - t2 * u0, t1 * u0 - t0 * u1, nx, ny, nz) < 0)
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
	
	static toString = function()
    {
        return "ColMesh shape: Mesh. Group: " + string(group) + ". Triangles: " + string(array_length(triangles)) + ". SubMeshes: " + string(submeshes);
    }
	
	#endregion
}

function colmesh_sphere(x, y, z, radius, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Sphere;
	self.x = x;
	self.y = y;
	self.z = z;
	self.R = radius;
	
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
		return (x - R < maxx && y - R < maxy && z - R < maxz && x + R > minx && y + R > miny && z + R > minz);
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
		var d = clamp(dot_product_3d(x - _x, y - _y, z - _z, xup, yup, zup), 0, height);
		ret[@ 0] = _x + xup * d;
		ret[@ 1] = _y + yup * d;
		ret[@ 2] = _z + zup * d;
		return ret;
	}
	
	/// @func _castRay(ray*, mask)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		var t = colmesh_cast_ray_sphere(x, y, z, R, ray[0], ray[1], ray[2], ray[3], ray[4], ray[5]);
		if (t < 0 || t > 1){return false;}
		var itsX = lerp(ray[0], ray[3], t);
		var itsY = lerp(ray[1], ray[4], t);
		var itsZ = lerp(ray[2], ray[5], t);
		var n = point_distance_3d(x, y, z, itsX, itsY, itsZ);
		return [itsX, itsY, itsZ, (itsX - x) / n, (itsY - y) / n, (itsZ - z) / n, self, t];
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
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
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
			Returns true if there was a collision.
		*/
		var dx = _x - x;
		var dy = _y - y;
		var dz = _z - z;
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		var r = R + radius;
		if (d == 0 || d >= r){return false;}
		d = r / d - 1;
		return collider.displace(dx * d, dy * d, dz * d);
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d > R + maxR) return -1;
		return sqr(max(d - R, 0));
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		return colmesh_sphere_intersects_cube(x, y, z, R, hsize, bX, bY, bZ);
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
	
	static toString = function()
    {
        return "ColMesh shape: Sphere. Group: " + string(group) + ". X,Y,Z,R: " + string([x, y, z, R]);
    }
	
	#endregion
}

function colmesh_capsule(x, y, z, xup, yup, zup, radius, height, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Capsule;
	self.x = x;
	self.y = y;
	self.z = z;
	var l = point_distance_3d(xup, yup, zup, 0, 0, 0);
	self.xup = xup / l;
	self.yup = yup / l;
	self.zup = zup / l;
	self.R = radius;
	self.H = height;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, H);
	self.I = colmesh_matrix_invert_fast(M, M);
	
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
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		
		//Transform the ray into the cylinder's local space, and do a 2D ray-circle intersection check
		var ox = ray[0], oy = ray[1], oz = ray[2];
		var ex = ray[3], ey = ray[4], ez = ray[5];
		var o = matrix_transform_vertex(I, ox, oy, oz);
		var e = matrix_transform_vertex(I, ex, ey, ez);
		var lox = o[0],			loy = o[1];
		var ldx = e[0] - lox,	ldy = e[1] - loy;
		var a = ldx * ldx + ldy * ldy;
		var b = ldx * lox + ldy * loy;
		var c = lox * lox + loy * loy - 1;
		var k = b * b - a * c;
		
		//Check if the intersection is on the central tube
		if (sign(k) >= 0)
		{
			//Find the 3D intersection
			var t = - (b + sqrt(k)) / a;
			if (t > 0 && t <= 1)
			{
				var itsX = lerp(ox, ex, t);
				var itsY = lerp(oy, ey, t);
				var itsZ = lerp(oz, ez, t);
				var d = dot_product_3d(itsX - x, itsY - y, itsZ - z, xup, yup, zup);
				if (d > 0 && d < H)
				{
					var tx = x + xup * d;
					var ty = y + yup * d;
					var tz = z + zup * d;
				
					var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
					if (n == 0){return false;}
					return [itsX, itsY, itsZ, (itsX - tx) / n, (itsY - ty) / n, (itsZ - tz) / n, self, t];
				}
			}
		}
		
		//The intersection is not on the central tube. Do a spherical ray cast at both endpoints
		var t1 = colmesh_cast_ray_sphere(x,				y,				z,				R, ox, oy, oz, ex, ey, ez);
		var t2 = colmesh_cast_ray_sphere(x + xup * H,	y + yup * H,	z + zup * H,	R, ox, oy, oz, ex, ey, ez);
		t = min(t1 < 0 ? 1 : t1, t2 < 0 ? 1 : t2);
		if (t == 1){return false;}
		if (t == t1)
		{
			tx = x;
			ty = y;
			tz = z;
		}
		else
		{
			tx = x + xup * H;
			ty = y + yup * H;
			tz = z + zup * H;
		}
		var itsX = lerp(ox, ex, t);
		var itsY = lerp(oy, ey, t);
		var itsZ = lerp(oz, ez, t);
		var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
		if (n == 0){return false;}
		return [itsX, itsY, itsZ, (itsX - tx) / n, (itsY - ty) / n, (itsZ - tz) / n, self, t];
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
		var d = dot_product_3d(_x - x, _y - y, _z - z, xup, yup, zup);
		d = clamp(d, 0, H);
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var dx = _x - tx;
		var dy = _y - ty;
		var dz = _z - tz;
		var d = point_distance_3d(0, 0, 0, dx, dy, dz);
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
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		var r = R + radius;
		if (d == 0 || d >= r) return false;
		d = (r - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		var d = point_distance_3d(_x - tx, _y - ty, _z - tz, 0, 0, 0);
		if (d > R + maxR) return -1;
		return sqr(max(d - R, 0));
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ) 
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns true if the shape intersects the given axis-aligned cube
		*/
		//Find the nearest point to the box along the central axis
		var bx = bX;
		var by = bY;
		var bz = bZ;
		
		repeat 2
		{
			var d = dot_product_3d(bx - x, by - y, bz - z, xup, yup, zup);
			d = clamp(d, 0, H);
			var tx = x + xup * d;
			var ty = y + yup * d;
			var tz = z + zup * d;
		
			//Find the nearest point to the capsule on the box
			bx = clamp(tx, bX - hsize, bX + hsize);
			by = clamp(ty, bY - hsize, bY + hsize);
			bz = clamp(tz, bZ - hsize, bZ + hsize);
		}
		
		//Check a sphere at this position
		return colmesh_sphere_intersects_cube(tx, ty, tz, R * 1.2, hsize, bX, bY, bZ);
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
	
	
	static toString = function()
    {
        return "ColMesh shape: Capsule. Group: " + string(group) + ". X,Y,Z,R,H: " + string([x, y, z, R, H]) + ". xup,yup,zup: " + string([xup, yup, zup]);
    }
	
	#endregion
}

function colmesh_cylinder(x, y, z, xup, yup, zup, radius, height, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Cylinder;
	self.x = x;
	self.y = y;
	self.z = z;
	var l = point_distance_3d(xup, yup, zup, 0, 0, 0);
	self.xup = xup / l;
	self.yup = yup / l;
	self.zup = zup / l;
	self.R = radius;
	self.H = height;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, H);
	self.I = colmesh_matrix_invert_fast(M, M);
	
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
		if (s > 0 && s < H)
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
			var p = _getClosestPoint(traceX, traceY, traceZ);
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
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		/*	Algorithm created by TheSnidr	*/
		var ox = ray[0], oy = ray[1], oz = ray[2];
		var ex = ray[3], ey = ray[4], ez = ray[5];
		var o = matrix_transform_vertex(I, ox, oy, oz);
		var e = matrix_transform_vertex(I, ex, ey, ez);
		var lox = o[0],			loy = o[1];
		var ldx = e[0] - lox,	ldy = e[1] - loy;
		var a = ldx * ldx + ldy * ldy;
		var b = ldx * lox + ldy * loy;
		var c = lox * lox + loy * loy - 1;
		var k = b * b - a * c;
		if (k < 0){return false;}
		k = sqrt(k);
		var t = - (b + k) / a;
		if (t > 1){return false;}
		var inside = false;
		if (t < 0)
		{
			t = - (b - k) / a;
			inside = true;
			if (t < 0){return false;}
		}
		
		//Find the 3D intersection
		var itsX = lerp(ox, ex, t);
		var itsY = lerp(oy, ey, t);
		var itsZ = lerp(oz, ez, t);
		var d = dot_product_3d(itsX - x, itsY - y, itsZ - z, xup, yup, zup);
		if (d < 0 || d > H || inside)
		{	//The intersection is outside the end of the capsule. Do a plane intersection at the endpoint
			d = dot_product_3d(ox - x, oy - y, oz - z, xup, yup, zup);
			d = clamp(d, 0, H);
			var tx = x + xup * d;
			var ty = y + yup * d;
			var tz = z + zup * d;
			var dp = dot_product_3d(ray[3] - ray[0], ray[4] - ray[1], ray[5] - ray[2], xup, yup, zup);
			var s = - sign(dp);
			if (s == 2 * (d == 0) - 1){return false;}
			t = dot_product_3d(tx - ox, ty - oy, tz - oz, xup, yup, zup) / dp;
			if (t < 0 || t > 1){return false;}
			var itsX = lerp(ox, ex, t);
			var itsY = lerp(oy, ey, t);
			var itsZ = lerp(oz, ez, t);
			if (point_distance_3d(itsX, itsY, itsZ, tx, ty, tz) > R){return false;}
			return [itsX, itsY, itsZ, xup * s, yup * s, zup * s, self, t];
		}
		
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
		if (n == 0){return false;}
		return [itsX, itsY, itsZ, (itsX - tx) / n, (itsY - ty) / n, (itsZ - tz) / n, self, t];
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
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
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
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
		if (D <= 0 || D >= H)
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
		
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0 || d >= r) return false;
		d = (r - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
	}

	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
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
		if (D <= 0 || D >= H)
		{
			var dp = dot_product_3d(dx, dy, dz, xup, yup, zup);
			dx -= xup * dp;
			dy -= yup * dp;
			dz -= zup * dp;
			var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
			if (d > R)
			{
				var _d = R / d;
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
		var d = max(point_distance_3d(dx, dy, dz, 0, 0, 0) - R, 0);
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
	
	static toString = function()
    {
        return "ColMesh shape: Cylinder. Group: " + string(group) + ". X,Y,Z,R,H: " + string([x, y, z, R, H]) + ". xup,yup,zup: " + string([xup, yup, zup]);
    }
	
	#endregion
}

function colmesh_unfinished_cone(x, y, z, xup, yup, zup, radius, height, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Cone;
	self.x = x;
	self.y = y;
	self.z = z;
	var l = point_distance_3d(0, 0, 0, xup, yup, zup);
	self.xup = xup / l;
	self.yup = yup / l;
	self.zup = zup / l;
	self.R = radius;
	self.H = height;
	
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
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
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
			return [itsX, itsY, itsZ, xup * s, yup * s, zup * s, self, t];
		}
		
		var tx = x + xup * d;
		var ty = y + yup * d;
		var tz = z + zup * d;
		var nx = itsX - tx;
		var ny = itsY - ty;
		var nz = itsZ - tz;
		var n = point_distance_3d(itsX, itsY, itsZ, tx, ty, tz);
		if (n == 0){return false;}
		return [itsX, itsY, itsZ, (itsX - tx) / n, (itsY - ty) / n, (itsZ - tz) / n, self, t];
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
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0 || d >= _r) return false;
		d = (_r - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
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
			var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
			if (d > R)
			{
				var _d = R / d;
				dx *= _d;
				dy *= _d;
				dz *= _d;
			}
			dx = _x - tx - dx;
			dy = _y - ty - dy;
			dz = _z - tz - dz;
			var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
			if (d > maxR) return -1;
			return d * d;
		}
		var d = max(point_distance_3d(dx, dy, dz, 0, 0, 0) - R, 0);
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

function colmesh_torus(x, y, z, xup, yup, zup, R, r, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Torus;
	self.x = x;
	self.y = y;
	self.z = z;
	var l = point_distance_3d(xup, yup, zup, 0, 0, 0);
	self.xup = xup / l;
	self.yup = yup / l;
	self.zup = zup / l;
	self.invXup = sqrt(1 - xup * xup);
	self.invYup = sqrt(1 - yup * yup);
	self.invZup = sqrt(1 - zup * zup);
	self.R = R;
	self.r = r;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R);
	self.I = colmesh_matrix_invert_fast(M, M);
	
	#region functions
	
	/// @func getMinMax()
	static getMinMax = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		var xs = r + R * invXup;
		var ys = r + R * invYup;
		var zs = r + R * invZup;
		minMax[0] = x - xs;
		minMax[1] = y - ys;
		minMax[2] = z - zs;
		minMax[3] = x + xs;
		minMax[4] = y + ys;
		minMax[5] = z + zs;
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
			This uses an approximation.
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
	
	/// @func _getRingCoord(x, y, z)
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
		var l = point_distance_3d(dx, dy, dz, 0, 0, 0);
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
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
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
		var o = matrix_transform_vertex(I, ray[0], ray[1], ray[2]);
		var e = matrix_transform_vertex(I, ray[3], ray[4], ray[5]);
		var lox = o[0], loy = o[1], loz = o[2];
		var ldx = e[0] - lox, ldy = e[1] - loy, ldz = e[2] - loz;
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
			if ((p > 0 && n > R) || d > l) return false; //The ray missed or didn't reach the torus
			lox += ldx * n;	
			loy += ldy * n;
			loz += ldz * n;
		}
		if (n > p) return false; //If the new distance estimate is larger than the previous one, the ray must have missed a close point and is moving away from the object 
		d /= l;
		var itsX = lerp(ray[0], ray[3], d);
		var itsY = lerp(ray[1], ray[4], d);
		var itsZ = lerp(ray[2], ray[5], d);
		var p = _getRingCoord(itsX, itsY, itsZ);
		var n = point_distance_3d(itsX, itsY, itsZ, p[0], p[1], p[2]);
		return [itsX, itsY, itsZ, (itsX - p[0]) / n, (itsY - p[1]) / n, (itsZ - p[2]) / n, self, d];
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
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
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
			Returns true if there was a collision.
		*/
		gml_pragma("forceinline");
		var p = _getRingCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var _r = r + radius;
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0 || d >= _r) return false;
		d = (_r - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
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
		var d = max(point_distance_3d(dx, dy, dz, 0, 0, 0) - r, 0);
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
	
	static toString = function()
    {
        return "ColMesh shape: Torus. Group: " + string(group) + ". X,Y,Z,R,r: " + string([x, y, z, R, r]) + ". xup,yup,zup: " + string([xup, yup, zup]);
    }
	
	#endregion
}

function colmesh_disk(x, y, z, xup, yup, zup, R, r, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Disk;
	self.x = x;
	self.y = y;
	self.z = z;
	var l = point_distance_3d(xup, yup, zup, 0, 0, 0);
	self.xup = xup / l;
	self.yup = yup / l;
	self.zup = zup / l;
	self.invXup = sqrt(1 - xup * xup);
	self.invYup = sqrt(1 - yup * yup);
	self.invZup = sqrt(1 - zup * zup);
	self.R = R;
	self.r = r;
	var M = colmesh_matrix_build_from_vector(x, y, z, xup, yup, zup, R, R, R);
	self.I = colmesh_matrix_invert_fast(M, M);
	
	#region functions
	
	/// @func getMinMax()
	static getMinMax = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		var xs = r + R * invXup;
		var ys = r + R * invYup;
		var zs = r + R * invZup;
		minMax[0] = x - xs;
		minMax[1] = y - ys;
		minMax[2] = z - zs;
		minMax[3] = x + xs;
		minMax[4] = y + ys;
		minMax[5] = z + zs;
		return minMax;
	}
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var rr = R + r;
		if (x - rr < maxx && y - rr < maxy && z - rr < maxz && x + rr > minx && y + rr > miny && z + rr > minz)
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
	
	/// @func _getDiskCoord(x, y, z)
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
		var l = point_distance_3d(0, 0, 0, dx, dy, dz);
		if (l <= R)
		{
			ret[0] = x + dx;
			ret[1] = y + dy;
			ret[2] = z + dz;
			return ret;
		}
		var _d = R / l;
		ret[0] = x + dx * _d;
		ret[1] = y + dy * _d;
		ret[2] = z + dz * _d;
		return ret;
	}
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
			This is an approximation using the same principle as ray marching
		*/
		var repetitions = 15;
		var o = matrix_transform_vertex(I, ray[0], ray[1], ray[2]);
		var e = matrix_transform_vertex(I, ray[3], ray[4], ray[5]);
		var lox = o[0], loy = o[1], loz = o[2];
		var ldx = e[0] - lox, ldy = e[1] - loy, ldz = e[2] - loz;
		var l = point_distance_3d(0, 0, 0, ldx, ldy, ldz);
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
			if ((p > 0 && n > R) || d > l) return false; //The ray missed or didn't reach the torus
			lox += ldx * n;	
			loy += ldy * n;
			loz += ldz * n;
		}
		if (n > p) return false; //If the new distance estimate is larger than the previous one, the ray must have missed a close point and is moving away from the object 
		d /= l;
		var itsX = lerp(ray[0], ray[3], d);
		var itsY = lerp(ray[1], ray[4], d);
		var itsZ = lerp(ray[2], ray[5], d);
		var p = _getDiskCoord(itsX, itsY, itsZ);
		var n = point_distance_3d(itsX, itsY, itsZ, p[0], p[1], p[2]);
		if (n == 0){return false;}
		return [itsX, itsY, itsZ, (itsX - p[0]) / n, (itsY - p[1]) / n, (itsZ - p[2]) / n, self, d];
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
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d > 0)
		{
			var _r = r / d;
			ret[@ 0] = p[0] + dx * _r;
			ret[@ 1] = p[1] + dy * _r;
			ret[@ 2] = p[2] + dz * _r;
			return ret;
		}
		ret[@ 0] = _x;
		ret[@ 1] = _y;
		ret[@ 2] = _z;
		return ret;
	}
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
			Returns true if there was a collision.
		*/
		gml_pragma("forceinline");
		var p = _getDiskCoord(_x, _y, _z);
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var _r = r + radius;
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0 || d >= _r) return false;
		d = (_r - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
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
		var d = max(point_distance_3d(dx, dy, dz, 0, 0, 0) - r, 0);
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
	
	static toString = function()
    {
        return "ColMesh shape: Disk. Group: " + string(group) + ". X,Y,Z,R,r: " + string([x, y, z, R, r]) + ". xup,yup,zup: " + string([xup, yup, zup]);
    }
	
	#endregion
}

function colmesh_cube(x, y, z, xsize, ysize, zsize, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Cube;
	self.x = x;
	self.y = y;
	self.z = z;
	self.halfX = xsize / 2;
	self.halfY = ysize / 2;
	self.halfZ = zsize / 2;
	
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
		var px = x + clamp(xx / halfX, -1, 1) * halfX;
		var py = y + clamp(yy / halfY, -1, 1) * halfY;
		var pz = z + clamp(zz / halfZ, -1, 1) * halfZ;
		var d = dot_product_3d(px - _x, py - _y, pz - _z, xup, yup, zup);
		d = clamp(d, 0, height);
		var rx1 = _x + xup * d;
		var ry1 = _y + yup * d;
		var rz1 = _z + zup * d;
		var d1 = cmSqr(rx1 - px, ry1 - py, rz1 - pz);
		
		//Check top of capsule
		xx += xup * height;
		yy += yup * height;
		zz += zup * height;
		var px = x + clamp(xx / halfX, -1, 1) * halfX;
		var py = y + clamp(yy / halfY, -1, 1) * halfY;
		var pz = z + clamp(zz / halfZ, -1, 1) * halfZ;
		var d = dot_product_3d(px - _x, py - _y, pz - _z, xup, yup, zup);
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
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		//Algorithm created by TheSnidr
		var tmin = 1;
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
					tmin *= t;
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
					tmin *= t;
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
					tmin *= t;
				}
			}
		}
		if (insideBlock || !intersection){return false;}
		
		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		return [x + x2 * halfX, y + y2 * halfY, z + z2 * halfZ, nx, ny, nz, self, tmin];
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
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
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
			var d = radius - dot_product_3d(dx, dy, dz, nx, ny, nz);
			return collider.displace(nx * d, ny * d, nz * d);
		}
		//Nearest point on the cube
		var px = x + clamp(bx, -1, 1) * halfX;
		var py = y + clamp(by, -1, 1) * halfY;
		var pz = z + clamp(bz, -1, 1) * halfZ;
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0 || d >= radius) return false;
		d = (radius - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
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
		if (max(abs(bx), abs(by), abs(bz)) <= 1)
		{	//If the center of the sphere is inside the cube, set priority to max priority
			return 0; //0 is the highest possible priority
		}
		//Nearest point on the cube
		var px = x + clamp(bx, -1, 1) * halfX;
		var py = y + clamp(by, -1, 1) * halfY;
		var pz = z + clamp(bz, -1, 1) * halfZ;
		var dx = _x - px;
		var dy = _y - py;
		var dz = _z - pz;
		var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
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
	
	
	static toString = function()
    {
        return "ColMesh shape: Cube. Group: " + string(group) + ". X,Y,Z,halfx,halfy,halfz: " + string([x, y, z, halfX, halfY, halfZ]);
    }
	
	#endregion
}

function colmesh_block(M, group = 1) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Block;
	
	self.lx = 1 / point_distance_3d(0, 0, 0, M[0], M[1], M[2]);
	self.ly = 1 / point_distance_3d(0, 0, 0, M[4], M[5], M[6]);
	self.lz = 1 / point_distance_3d(0, 0, 0, M[8], M[9], M[10]);
	
	//Remove any potential shear from the matrix
	var m = array_create(16);
	array_copy(m, 0, M, 0, 16);
	colmesh_matrix_orthogonalize(m);
	self.M = colmesh_matrix_scale(m, 1/lx, 1/ly, 1/lz);
	self.I = colmesh_matrix_invert_fast(M);	
	
	#region functions
	
	/// @func getMinMax()
	static getMinMax = function()
	{
		/*
			Returns the AABB of the shape as an array with six values
		*/
		static minMax = array_create(6);
		var dx = abs(M[0]) + abs(M[4]) + abs(M[8]);
		var dy = abs(M[1]) + abs(M[5]) + abs(M[9]);
		var dz = abs(M[2]) + abs(M[6]) + abs(M[10]);
		minMax[0] = M[12] - dx;
		minMax[1] = M[13] - dy;
		minMax[2] = M[14] - dz;
		minMax[3] = M[12] + dx;
		minMax[4] = M[13] + dy;
		minMax[5] = M[14] + dz;
		return minMax;
	}
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		var dx = abs(M[0]) + abs(M[4]) + abs(M[8]);
		var dy = abs(M[1]) + abs(M[5]) + abs(M[9]);
		var dz = abs(M[2]) + abs(M[6]) + abs(M[10]);
		if (M[12] - dx < maxx && M[13] - dy < maxy && M[14] - dz < maxz && M[12] + dx > minx && M[13] + dy > miny && M[14] + dz > minz)
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
		var b = matrix_transform_vertex(I, _x, _y, _z);
		var p = matrix_transform_vertex(M, clamp(b[0], -1, 1), clamp(b[1], -1, 1), clamp(b[2], -1, 1));
		var d = dot_product_3d(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
		d = clamp(d, 0, height);
		var rx1 = _x + _xup * d;
		var ry1 = _y + _yup * d;
		var rz1 = _z + _zup * d;
		var d1 = cmSqr(rx1 - p[0], ry1 - p[1], rz1 - p[2]);
		
		//Check top of capsule
		var b = matrix_transform_vertex(I, _x + _xup * height, _y + _yup * height, _z + _zup * height);
		var p = matrix_transform_vertex(M, clamp(b[0], -1, 1), clamp(b[1], -1, 1), clamp(b[2], -1, 1));
		var d = dot_product_3d(p[0] - _x, p[1] - _y, p[2] - _z, _xup, _yup, _zup);
		d = clamp(d, 0, height);
		var rx2 = _x + _xup * d;
		var ry2 = _y + _yup * d;
		var rz2 = _z + _zup * d;
		var d2 = cmSqr(rx2 - p[0], ry2 - p[1], rz2 - p[2]);
		
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
	
	/// @func _castRay(ray, mask*)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		//Algorithm created by TheSnidr
		var o = matrix_transform_vertex(I, ray[0], ray[1], ray[2]);
		var e = matrix_transform_vertex(I, ray[3], ray[4], ray[5]);
		var x1 = o[0], y1 = o[1], z1 = o[2];
		var x2 = e[0], y2 = e[1], z2 = e[2];
		
		var tmin = 1;
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
					nx = M[0] * s;
					ny = M[1] * s;
					nz = M[2] * s;
					intersection = true;
					tmin *= t;
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
					nx = M[4] * s;
					ny = M[5] * s;
					nz = M[6] * s;
					intersection = true;
					tmin *= t;
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
					nx = M[8]  * s;
					ny = M[0]  * s;
					nz = M[10] * s;
					intersection = true;
					tmin *= t;
				}
			}
		}
		if (insideBlock || !intersection) return false;

		///////////////////////////////////////////////////////////////////
		//Return the point of intersection in world space
		var p = matrix_transform_vertex(M, x2, y2, z2);
		return [p[0], p[1], p[2], nx, ny, nz, self, tmin];
	}
		
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		//Find normalized block space position
		var p = matrix_transform_vertex(I, _x, _y, _z);
		var bx = p[0], by = p[1], bz = p[2];
		var b = max(abs(bx), abs(by), abs(bz));
		
		//If the center of the sphere is inside the cube, normalize the largest axis
		if (b <= 1){
			if (b == abs(bx))		bx = sign(bx);
			else if (b == abs(by))	by = sign(by);
			else					bz = sign(bz);
			return matrix_transform_vertex(M, bx, by, bz);
		}
		return matrix_transform_vertex(M, clamp(bx, -1, 1), clamp(by, -1, 1), clamp(bz, -1, 1));
	}
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, _x, _y, _z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
			Returns true if there was a collision.
		*/
		//Find normalized block space position
		var p = matrix_transform_vertex(I, _x, _y, _z);
		var bx = p[0];
		var by = p[1];
		var bz = p[2];
		var b = max(abs(bx), abs(by), abs(bz));
		var nx, ny, nz;
		//If the center of the sphere is inside the cube, normalize the largest axis
		if (b <= 1)
		{
			if (b == abs(bx))
			{
				nx = M[0] * lx;
				ny = M[1] * lx;
				nz = M[2] * lx;
			}
			else if (b == abs(by))
			{
				by = sign(by);
				nx = M[4] * ly;
				ny = M[5] * ly;
				nz = M[6] * ly;
			}
			else
			{
				bz = sign(bz);
				nx = M[8]  * lz;
				ny = M[9]  * lz;
				nz = M[10] * lz;
			}
			var p = matrix_transform_vertex(M, bx, by, bz);
			var d = radius - dot_product_3d(_x - p[0], _y - p[1], _z - p[2], nx, ny, nz);
			return collider.displace(nx * d, ny * d, nz * d);
		}
		//Nearest point on the cube
		var p = matrix_transform_vertex(M, clamp(bx, -1, 1), clamp(by, -1, 1), clamp(bz, -1, 1));
		var dx = _x - p[0];
		var dy = _y - p[1];
		var dy = _y - p[1];
		var dz = _z - p[2];
		var d = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0 || d > radius){return false;}
		d = (radius - d) / d;
		return collider.displace(dx * d, dy * d, dz * d);
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
		var b = matrix_transform_vertex(I, _x, _y, _z);
		if (max(abs(b[0]), abs(b[1]), abs(b[2])) <= 1)
		{	//If the center of the sphere is inside the cube, normalize the largest axis
			return 0; //0 is the highest possible priority
		}
		//Nearest point on the cube in normalized block space
		var p = matrix_transform_vertex(M, clamp(b[0], -1, 1), clamp(b[1], -1, 1), clamp(b[2], -1, 1));
		var d = point_distance_3d(_x, _y, _z, p[0], p[1], p[2]);
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
		//Find normalized block space position
		var b = matrix_transform_vertex(I, 
					bX + clamp(M[12] - bX, -hsize, hsize),
					bY + clamp(M[13] - bY, -hsize, hsize),
					bZ + clamp(M[14] - bZ, -hsize, hsize));
		if (max(abs(b[0]), abs(b[1]), abs(b[2])) < 1) return true;
		
		//Then check if the nearest point in the cube is inside the AABB
		var b = matrix_transform_vertex(I, bX, bY, bZ);
		var p = matrix_transform_vertex(M, 
					clamp(b[0], -1, 1), 
					clamp(b[1], -1, 1), 
					clamp(b[2], -1, 1));
		if (max(abs(p[0] - bX), abs(p[1] - bY), abs(p[2] - bZ)) < hsize) return true;
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
		var sh = shader_current();
		shader_set_uniform_f(shader_get_uniform(shader_current(), "u_radius"), 0);
		var W = matrix_get(matrix_world);
		matrix_set(matrix_world, matrix_multiply(M, W));
		vertex_submit(vbuff, pr_trianglelist, tex);
		
		//Reset the world matrix
		matrix_set(matrix_world, W);
	}
	
	
	static toString = function()
    {
        return "ColMesh shape: Block. Group: " + string(group) + ". Matrix: " + string(M);
    }
	
	#endregion
}

function colmesh_dynamic(shape, M, group = cmGroupSolid) : colmesh_shapes(group) constructor
{
	self.type = eColMeshShape.Dynamic;
	self.shape = shape;
	self.colMesh = -1;
	self.M  = matrix_build_identity(); //World matrix
	self.I  = matrix_build_identity(); //Inverse world matrix
	self.pI = matrix_build_identity(); //Previous inverse world matrix
	self.scale = 1;
	self.moving = false;
	self.minMax = array_create(6);
	
	static toString = function()
    {
        return "ColMesh shape: Dynamic. Group: " + string(group) + ". Matrix: " + string(M) + ". \n	Submesh: [" + string(shape) + "]";
    }
	
	#region Shared functions (this is only overwritten for the dynamic
	
	/// @func capsuleCollision(x, y, z, xup, yup, zup, radius, height)
	static capsuleCollision = function(x, y, z, xup, yup, zup, radius, height)
	{
		//Returns true if the given capsule collides with the shape
		if (cmRecursion >= cmMaxRecursion)
		{
			return false;
		}
		var p = matrix_transform_vertex(I, x, y, z);
		var u = colmesh_matrix_transform_vector(I, xup * scale, yup * scale, zup * scale);
		++ cmRecursion;
		var col = shape.capsuleCollision(p[0], p[1], p[2], u[0], u[1], u[2], radius / scale, height / scale);
		-- cmRecursion;
		return col;
	}
	
	/// @func checkAABB(minx, miny, minz, maxx, maxy, maxz)
	static checkAABB = function(minx, miny, minz, maxx, maxy, maxz)
	{
		if (shape.type == eColMeshShape.ColMesh)
		{
			//If this shape is a colmesh, we can do a little more calculation here to avoid some extra calculations later
			var mm = shape.getMinMax();
			var block = matrix_multiply(matrix_build((mm[0] + mm[3]) * .5, (mm[1] + mm[4]) * .5, (mm[2] + mm[5]) * .5, 0, 0, 0, (mm[3] - mm[0]) * .5, (mm[4] - mm[1]) * .5, (mm[5] - mm[2]) * .5), M);
			return colmesh_block_intersects_AABB(block, minx, miny, minz, maxx, maxy, maxz);
		}
		var mm = getMinMax();
		if (mm[0] < maxx && mm[1] < maxy && mm[2] < maxz && mm[3] > minx && mm[4] > miny && mm[5] > minz)
		{
			return true;
		}
		return false;
	}
	
	#endregion
	
	#region Shape-specific functions
	
	/// @func setMatrix(M, moving*)
	static setMatrix = function(_M, _moving = true) 
	{	
		/*	
			This script lets you make it seem like a colmesh instance has been transformed.
			What really happens though, is that the collision shape is transformed by the inverse of the given matrix, 
			then it performs collision checks, and then it is transformed back. This is an efficient process.
			This script creates a new matrix from the given matrix, making sure that all the vectors are perpendicular, 
			and making sure the scaling is uniform (using the scale in the first column as reference).
			
			Set moving to true if your object moves from frame to frame, and false if it's a static object that only uses a dynamic for static transformations.
		*/
		var mm = getMinMax();
		
		moving = _moving;
		array_copy(M, 0, _M, 0, 16);
		
		//Orthogonalize the side vector
		var sqrScale = dot_product_3d(M[0], M[1], M[2], M[0], M[1], M[2]);
		var sideDp   = dot_product_3d(M[0], M[1], M[2], M[4], M[5], M[6]) / sqrScale;
		M[4] -= M[0] * sideDp;
		M[5] -= M[1] * sideDp;
		M[6] -= M[2] * sideDp;
		var l = point_distance_3d(0, 0, 0, M[4], M[5], M[6]);
		if (l <= 0){return false;}
		scale = sqrt(sqrScale);
		l = scale / l;
		M[4] *= l;
		M[5] *= l;
		M[6] *= l;

		//Orthogonalize the up vector
		var m8 = M[8], m9 = M[9], m10 = M[10];
		M[8]  = (M[1] * M[6] - M[2] * M[5]) / scale;
		M[9]  = (M[2] * M[4] - M[0] * M[6]) / scale;
		M[10] = (M[0] * M[5] - M[1] * M[4]) / scale;
		
		//Ensure that the handedness of the new matrix is the same as the input
		var s = sign(dot_product_3d(M[8], M[9], M[10], m8, m9, m10));
		M[8] *= s;
		M[9] *= s;
		M[10]*= s;
		
		//Set the 4th row of the matrix to [0, 0, 0, 1]
		M[3]  = 0;
		M[7]  = 0;
		M[11] = 0;
		M[15] = 1;
		
		if (moving)
		{	//If the object is moving, save the previous inverse matrix to pI
			array_copy(pI, 0, I, 0, 16);
		}
		colmesh_matrix_invert_fast(M, I);
		
		if (is_struct(colMesh))
		{
			static oldReg = array_create(6);
			array_copy(oldReg, 0, colMesh._getRegions(mm), 0, 6);
			var mm = getMinMax(true);
			colMesh._expandBoundaries(mm);
			var newReg = colMesh._getRegions(mm);
			if (!array_equals(oldReg, newReg))
			{
				colMesh.removeShapeFromSubdiv(self, oldReg);
				colMesh.addShapeToSubdiv(self, newReg, !moving);
			}
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
	static getMinMax = function(forceUpdate = true)
	{
		static prevLocalMinMax = array_create(6);
		var mm = shape.getMinMax();
		if (forceUpdate || !array_equals(mm, prevLocalMinMax))
		{
			array_copy(prevLocalMinMax, 0, mm, 0, 6);
			
			//Returns the AABB of the shape as an array with six values
			var mm = shape.getMinMax();
			var xs = (mm[3] - mm[0]) * .5;
			var ys = (mm[4] - mm[1]) * .5;
			var zs = (mm[5] - mm[2]) * .5;
			var mx = (mm[0] + mm[3]) * .5;
			var my = (mm[1] + mm[4]) * .5;
			var mz = (mm[2] + mm[5]) * .5;
			var t = matrix_transform_vertex(M, mx, my, mz);
			var dx = abs(M[0] * xs) + abs(M[4] * ys) + abs(M[8] * zs);
			var dy = abs(M[1] * xs) + abs(M[5] * ys) + abs(M[9] * zs);
			var dz = abs(M[2] * xs) + abs(M[6] * ys) + abs(M[10]* zs);
			minMax[0] = t[0] - dx;
			minMax[1] = t[1] - dy;
			minMax[2] = t[2] - dz;
			minMax[3] = t[0] + dx;
			minMax[4] = t[1] + dy;
			minMax[5] = t[2] + dz;
		}
		return minMax;
	}
	
	/// @func _castRay(ray, mask)
	static _castRay = function(ray, mask = cmGroupSolid)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.castRay
			Changes the global array cmRay if the ray intersects the shape
		*/
		//Transform the ray to local space
		static _ray = array_create(6);
		array_copy(_ray, 0, matrix_transform_vertex(I, ray[0], ray[1], ray[2]), 0, 3);
		array_copy(_ray, 3, matrix_transform_vertex(I, ray[3], ray[4], ray[5]), 0, 3);
		if (shape.type == eColMeshShape.ColMesh)
		{
			//If this is a mesh, we want to raycast against all the shapes the mesh contains
			if (cmRecursion >= cmMaxRecursion)
			{
				return true;
			}
			++ cmRecursion;
			rayResult = shape.castRay(_ray[0], _ray[1], _ray[2], _ray[3], _ray[4], _ray[5], mask);
			-- cmRecursion;
			if (!rayResult.hit){return true;}
			var p = matrix_transform_vertex(M, rayResult.x, rayResult.y, rayResult.z);
			var n = colmesh_matrix_transform_vector(M, rayResult.nx, rayResult.ny, rayResult.nz);
			var dx = ray[3] - ray[0], dy = ray[4] - ray[1], dz = ray[5] - ray[2];
			var t = dot_product_3d(p[0] - ray[0], p[1] - ray[1], p[2] - ray[2], dx, dy, dz) / dot_product_3d(dx, dy, dz, dx, dy, dz);
			return [p[0], p[1], p[2], n[0], n[1], n[2], rayResult.struct, t];
		}
		else
		{
			//If this is not a mesh, we can raycast against just this shape
			intersection = shape._castRay(_ray, mask);
			if (!is_array(intersection)){return false;}
			var p = matrix_transform_vertex(M, intersection[0], intersection[1], intersection[2]);
			var n = colmesh_matrix_transform_vector(M, intersection[3] / scale, intersection[4] / scale, intersection[5] / scale);
			return [p[0], p[1], p[2], n[0], n[1], n[2], shape, intersection[7]];
		}
	}
	
	/// @func _getClosestPoint(x, y, z)
	static _getClosestPoint = function(_x, _y, _z)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Used by colmesh.getClosestPoint
		*/
		if (shape.type == eColMeshShape.ColMesh)
		{
			//Find normalized block space position
			var p = matrix_transform_vertex(I, _x, _y, _z)
			var bx = p[0];
			var by = p[1];
			var bz = p[2];
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
				var p = matrix_transform_vertex(M, bx, by, bz);
			}
			else
			{	//Nearest point on the cube in normalized block space
				bx = clamp(bx, -1, 1);
				by = clamp(by, -1, 1);
				bz = clamp(bz, -1, 1);
				var p = matrix_transform_vertex(M, bx, by, bz);
			}
			return p;
		}
		var p = matrix_transform_vertex(I, _x, _y, _z);
		var n = shape._getClosestPoint(p[0], p[1], p[2]);
		return matrix_transform_vertex(M, n[0], n[1], n[2]);
	}
	
	/// @func _capsuleGetRef(x, y, z, xup, yup, zup, height)
	static _capsuleGetRef = function(_x, _y, _z, xup, yup, zup, height)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns the nearest point along the given capsule to the shape.
		*/
		if (shape.type == eColMeshShape.ColMesh)
		{
			//If the dynamic contains a mesh, there's no point in finding the actual reference at this time. Return the input position.
			static ret = array_create(3);
			ret[0] = _x;
			ret[1] = _y;
			ret[2] = _z;
			return ret;
		} 
		var p = matrix_transform_vertex(I, _x, _y, _z);
		var u = colmesh_matrix_transform_vector(I, xup * scale, yup * scale, zup * scale);
		var r = shape._capsuleGetRef(p[0], p[1], p[2], u[0], u[1], u[2], height / scale);
		return matrix_transform_vertex(M, r[0], r[1], r[2]);
	}
	
	/// @func _intersectsCube(cubeHalfSize, cubeCenterX, cubeCenterY, cubeCenterZ)
	static _intersectsCube = function(hsize, bX, bY, bZ)
	{
		if (shape.type == eColMeshShape.ColMesh)
		{
			var mm = shape.getMinMax();
			//This shape is a colmesh. Transform the cube to local space, and make it into a sphere instead
			var b = matrix_transform_vertex(I, bX, bY, bZ);
			var s = hsize * scale;
			//Find AABB of the resulting sphere
			var AABB = [b[0] - s, b[1] - s, b[2] - s, b[0] + s, b[1] + s, b[2] + s];
			//Limit the AABB to the size of the dynamic
			AABB[0] = max(AABB[0], mm[0]);
			AABB[1] = max(AABB[1], mm[1]);
			AABB[2] = max(AABB[2], mm[2]);
			AABB[3] = min(AABB[3], mm[3]);
			AABB[4] = min(AABB[4], mm[4]);
			AABB[5] = min(AABB[5], mm[5]);
			//Transform into grid coordinates
			AABB[0] = (floor(AABB[0] / shape.regionSize));
			AABB[1] = (floor(AABB[1] / shape.regionSize));
			AABB[2] = (floor(AABB[2] / shape.regionSize));
			AABB[3] = (floor(AABB[3] / shape.regionSize));
			AABB[4] = (floor(AABB[4] / shape.regionSize));
			AABB[5] = (floor(AABB[5] / shape.regionSize));
			//Check all the coords
			var xNum = AABB[3] - AABB[0] + 1;
			var yNum = AABB[4] - AABB[1] + 1;
			var zNum = AABB[5] - AABB[2] + 1;
			var xx = 0;
			repeat xNum
			{
				var _x = (xx++ + .5) * shape.regionSize;
				var yy = 0;
				repeat yNum
				{
					var _y = (yy++ + .5) * shape.regionSize;
					var zz = 0;
					repeat zNum
					{
						var _z = (zz++ + .5) * shape.regionSize;
						var key = colmesh_get_key(_x, _y, _z);
						if (!is_undefined(shape.spHash[? key]))
						{
							return true;
						}
					}
				}
			}
		}
	    var mm = minMax;
	    return (mm[0] < bX + hsize && mm[1] < bY + hsize && mm[2] < bZ + hsize && mm[3] > bX - hsize && mm[4] > bY - hsize && mm[5] > bZ - hsize);
		/*
		var mm = shape.getMinMax();
		var halfx = (mm[3] - mm[0]) * .5;
		var halfy = (mm[4] - mm[1]) * .5;
		var halfz = (mm[5] - mm[2]) * .5;
		var b = matrix_transform_vertex(I, 
					bX + clamp(M[12] - bX, -hsize, hsize),
					bY + clamp(M[13] - bY, -hsize, hsize),
					bZ + clamp(M[14] - bZ, -hsize, hsize));
		if (max(abs(b[0]) / halfx, abs(b[1]) / halfy, abs(b[2]) / halfz) < 1) return true;
		
		//Then check if the nearest point in the cube is inside the AABB
		var b = matrix_transform_vertex(I, bX, bY, bZ);
		var b = matrix_transform_vertex(M, 
					clamp(b[0], -halfx, halfx), 
					clamp(b[1], -halfy, halfy), 
					clamp(b[2], -halfz, halfz));
		if (max(abs(b[0] - bX), abs(b[1] - bY), abs(b[2] - bZ)) < hsize) return true;
		return false;*/
	}
	
	/// @func _displaceSphere(collider, x, y, z, radius)
	static _displaceSphere = function(collider, x, y, z, radius)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Pushes a sphere out of the shape
			Returns true if there was a collision.
		*/
		var tempR = collider.radius;
		var tempH = collider.height;
		var slope = collider.slope;
		
		//Transform the capsule to the local space of this shape
		collider.transform(I, scale);
		
		var col = false;
		if (shape.type == eColMeshShape.ColMesh)
		{
			if (cmRecursion < cmMaxRecursion)
			{
				++ cmRecursion;
				col = collider.avoid(shape);
				-- cmRecursion;
			}
		}
		else
		{
			//This dynamic contains a primitive
			var p = matrix_transform_vertex(I, x, y, z);
			col = shape._displaceSphere(collider, p[0], p[1], p[2], collider.radius);
		}
		if (col && slope < 1)
		{
			if (moving)
			{
				//This object is moving. Save its current world matrix and the inverse of the previous 
				//world matrix so that figuring out the delta matrix later is as easy as a matrix multiplication
				array_push(collider.transformQueue, M);
				array_push(collider.transformQueue, pI);
			}
			//If the transformation queue is empty, this is the first dynamic to be added. 
			//If it's static as well, there's no point in adding it to the transformation queue
			else if (array_length(collider.transformQueue) > 0)
			{
				//If the dynamic is not marked as "moving", save the current inverse matrix to the transformation 
				//queue so that no transformation is done. It will then only transform the preceding transformations
				//into its own frame of reference
				array_push(collider.transformQueue, M);
				array_push(collider.transformQueue, I);
			}
		}
		
		//Transform the collider back to world space
		collider.transform(M, 1 / scale);
		collider.radius = tempR;
		collider.height = tempH;
		
		//Return whether or not there was a collision
		return col;
	}
	
	/// @func _getPriority(x, y, z, maxR)
	static _getPriority = function(_x, _y, _z, maxR)
	{
		/*
			A supplementary function, not meant to be used by itself.
			Returns -1 if the shape is too far away
			Returns the square of the distance between the shape and the given point
		*/
		if (shape.type == eColMeshShape.ColMesh)
		{
			return 0; //0 is maximum priority
		}
		var p = matrix_transform_vertex(I, _x, _y, _z);
		var pri = shape._getPriority(p[0], p[1], p[2], maxR / scale);
		return pri * scale * scale;
	}
	
	/// @func debugDraw(tex)
	static debugDraw = function(tex)
	{
		var W = matrix_get(matrix_world);
		matrix_set(matrix_world, matrix_multiply(M, W));
		if (shape.type == eColMeshShape.ColMesh)
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
	setMatrix(M, false);
}

function colmesh_none() constructor
{
	/*
		This is a failsafe object for when loading a ColMesh that contains dynamic objects
	*/
	type = eColMeshShape.None;
	static capsuleCollision = function(){return false;}
	static _displace = function(){}
	static getMinMax = function(){return array_create(6);}
	static _capsuleGetRef = function()
	{
		static ret = array_create(3);
		return ret;
	}
	static _castRay = function(){return array_create(8);}	
	static _displaceSphere = function(){return false;}
	static _getPriority = function(){return -1;}
	static _getClosestPoint = function()
	{
		static ret = array_create(3);
		return ret;
	}
	static _intersectsCube = function(){return false;}
}