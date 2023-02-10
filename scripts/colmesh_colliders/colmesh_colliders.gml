// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function colmesh_raycast_result(x, y, z, nx, ny, nz, hit, struct) constructor
{
	self.ray = -1;
	self.x = x;
	self.y = y;
	self.z = z;
	self.nx = nx;
	self.ny = ny;
	self.nz = nz;
	self.hit = hit;
	self.struct = struct;
	self.intersections = [];
	self.t = 1;
	
	/// @func executeRayFunc(argument0*, argument1*, ..., argument7*)
	static executeRayFunc = function(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
	{
		/*
			Executes the ray functions of all the objects this ray intersects.
		*/
		cmCallingObject = other;
		var l = 0;
		if (is_array(ray))
		{
			l = point_distance_3d(ray[0], ray[1], ray[2], x, y, z);
		}
		var hitMap = ds_map_create();
		var exNum = 0;
		var i = array_length(intersections);
		repeat i
		{
			var intersection = intersections[--i];
			if (!is_struct(intersection[6])){continue;}
			if ((intersection[6].group & cmGroupRayTrigger) == 0){continue;}
			if (!is_undefined(hitMap[? intersection])){continue;}
			hitMap[? intersection] = true;
			
			//Perform this struct's collision function
			if (point_distance_3d(intersection[0], intersection[1], intersection[2], x, y, z) > l){continue;}
			intersection[6].rayFunc(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
		}
		ds_map_destroy(hitMap);
	}
}

function colmesh_colliders(x, y, z, xup, yup, zup, slopeAngle, precision, mask) constructor
{
	self.x = x;
	self.y = y;
	self.z = z;
	self.xup = xup;
	self.yup = yup;
	self.zup = zup;
	self.nx = 0;
	self.ny = 0;
	self.nz = 1;
	self.slopeAngle = slopeAngle;
	self.slope = 0;
	self.precision = precision;
	self.mask = mask;
	
	/// @func reset()
	static reset = function()
	{
		maxdp = -1;
		ground = false;
		collision = false;
		collisions = [];
		transformQueue = [];
		slope = ((slopeAngle <= 0) ? 1 : dcos(slopeAngle));
	}
	reset();
	
	/// @func getDeltaMatrix()
	static getDeltaMatrix = function()
	{
		//This is useful for getting the change in orientation in those cases where the player is standing on a dynamic shape.
		//If the player stands on a dynamic shape, its matrix and the inverse of its previous matrix are saved to that queue. This is done in colmesh_dynamic._displaceSphere.
		//If the dynamic shape is inside multiple layers of colmeshes, their matrices and inverse previous matrices are also added to the queue.
		//These matrices are all multiplied together in this function, resulting in their combined movements gathered in a single matrix.
		var num = array_length(transformQueue);
		var i = 0;
		if (num > 1)
		{
			//The first two matrices can simply be multiplied together
			var M = transformQueue[i++]; //The current world matrix
			var pI = transformQueue[i++]; //The inverse of the previous world matrix
			var m = matrix_multiply(pI, M);
			repeat (num / 2 - 1)
			{
				//The subsequent matrices need to be multiplied with the target matrix in the correct order
				M = transformQueue[i++]; //The current world matrix
				pI = transformQueue[i++]; //The inverse of the previous world matrix
				m = matrix_multiply(matrix_multiply(pI, m), M);
			}
			return m;
		}
		return false;
	}
	
	/// @func executeColFunc(argument0*, argument1*, ..., argument7*)
	static executeColFunc = function(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7)
	{
		/*
			Executes the collision functions of all the objects this collider touches
		*/
		if (cmRecursion == 0)
		{
			cmCallingObject = other;
		}
		var executedStructs = [];
		var exNum = 0;
		var i = array_length(collisions);
		repeat i
		{
			var struct = collisions[--i];
			if ((struct.group & cmGroupColTrigger) == 0){continue;}
			
			//Make sure each struct is only activated once
			var j = array_length(executedStructs) - 1;
			repeat (j + 1){if (struct == executedStructs[j --]){break;}}
			if (j >= 0){continue;}
			array_push(executedStructs, struct);
			
			//Perform this struct's collision function
			struct.colFunc(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
		}
	}
}

function colmesh_collider_capsule(x, y, z, xup, yup, zup, radius, height, slopeAngle = 40, precision = 0, mask = 1) : colmesh_colliders(x, y, z, xup, yup, zup, slopeAngle, precision, mask) constructor
{
	self.radius = radius;
	self.height = height;
	
	/// @func checkForCollision(colMesh)
	static checkForCollision = function(colMesh)
	{
		//Returns whether or not the given capsule collides with the given colMesh
		var AABB = colmesh_capsule_get_AABB(x, y, z, xup, yup, zup, (precision == 0) ? radius : radius * cmFirstPassRadius, height);
		return checkForCollisionRegion(colMesh, colMesh.getRegion(AABB));
	}
	
	/// @func checkForCollisionRegion(colMesh, region)
	static checkForCollisionRegion = function(colMesh, region)
	{
		//Returns whether or not the given capsule collides with the given region
		var i = ds_list_size(region);
		repeat (i)
		{
			var col = _getShape(region[| --i]).capsuleCollision(x, y, z, xup, yup, zup, radius, height);
			if (col) return true;
		}
		return false;
	}
	
	/// @func avoid(colMesh, mask*)
	static avoid = function(colMesh, _mask = self.mask)
	{
		var AABB = colmesh_capsule_get_AABB(x, y, z, xup, yup, zup, (precision == 0) ? radius : radius * cmFirstPassRadius, height);
		return avoidRegion(colMesh, colMesh.getRegion(AABB), _mask);
	}
	
	/// @func avoidRegion(colMesh, region, mask*)
	static avoidRegion = function(colMesh, region, _mask = self.mask)
	{
		cmCol = self;
		if (cmRecursion == 0)
		{
			//Only reset the collider for the first recursive call
			reset();
		}
		
		if (is_undefined(region) || cmRecursion >= cmMaxRecursion)
		{
			//Exit the script if the given region does not exist
			//Exit the script if we've reached the recursion limit
			return false;
		}
		
		//p is the center of the sphere for which we're doing collision checking. 
		//If height is larger than 0, this will be overwritten by the closest point to the shape along the central axis of the capsule
		var p = [x, y, z];
		var P = colMesh.priority[cmRecursion];
		if (P < 0 && precision > 0)
		{	
			//We need a separate ds_priority for each recursive level, otherwise they'll mess with each other
			P = ds_priority_create();
			colMesh.priority[cmRecursion] = P;
		}
		
		//If we're doing fast collision checking, the collisions are done on a first-come-first-serve basis. 
		//Fast collisions will also not save anything to the delta matrix queue
		var i = ds_list_size(region);
		repeat (i)
		{
			var shapeInd = region[| --i];
			var shape = colMesh._getShape(shapeInd);
			if ((_mask & shape.group) == 0)
			{	//If the shape is not in any of the groups in the mask, continue the loop
				continue;
			}
			if ((shape.group & cmGroupSolid) == 0)
			{	//If this shape is not solid, check if there is an intersection
				if (shape.capsuleCollision(x, y, z, xup, yup, zup, radius, height))
				{
					array_push(collisions, shape);
				}
				continue;
			}
			if (height != 0)
			{
				//If height is larger than 0, this is a capsule, and we must find the most fitting point along the central axis of the capsule
				p = shape._capsuleGetRef(x, y, z, xup, yup, zup, height);
			}
			if (precision == 0)
			{
				if (shape._displaceSphere(self, p[0], p[1], p[2], radius))
				{
					array_push(collisions, shape);
				}
			}
			else
			{
				var pri = shape._getPriority(p[0], p[1], p[2], radius * cmFirstPassRadius);
				if (pri >= 0){
					ds_priority_add(P, shapeInd, pri);
				}
			}
		}
		if (precision == 0)
		{
			return collision;
		}
		
		//If precision is larger than 1, copy the contents of the priority over to an array, so that it's easier to reuse the data
		var colNum = ds_priority_size(P);
		var colOrder = array_create(colNum);
		var i = colNum;
		repeat (colNum)
		{
			colOrder[--i] = ds_priority_delete_min(P);
		}
		var rep = 0;
		repeat (precision)
		{
			var i = colNum;
			var remainingCollisions = 0;
			repeat (colNum)
			{
				//Second pass, collide with the nearby shapes, starting with the closest one
				var shape = colMesh._getShape(colOrder[--i]);
				if (height != 0)
				{	
					//If height is larger than 0, this is a capsule, and we must find the most fitting point along the central axis of the capsule
					p = shape._capsuleGetRef(x, y, z, xup, yup, zup, height);
				}
				if (shape._displaceSphere(self, p[0], p[1], p[2], radius))
				{
					++ remainingCollisions;
					if (rep == 0)
					{
						array_push(collisions, shape);
					}
				}
			}
			//Early out if the capsule is only colliding with a single shape
			if (remainingCollisions <= 1){break;}
			++ rep;
		}
		
		return collision;
	}
	
	/// @func displace(dx, dy, dz)
	static displace = function(dx, dy, dz)
	{
		var d  = point_distance_3d(dx, dy, dz, 0, 0, 0);
		if (d == 0)
		{
			return false;
		}
		var dp = dot_product_3d(dx, dy, dz, xup, yup, zup) / d;
		if (dp > maxdp)
		{
			//Store the normal vector that is the most parallel to the given up vector
			nx = dx / d;
			ny = dy / d;
			nz = dz / d;
			maxdp = dp;
		}
		if (dp >= slope)
		{ 
			//Prevent sliding by displacing along the up vector instead of the normal vector
			d /= dp;
			x += xup * d;
			y += yup * d;
			z += zup * d;
			ground = true;
			slope = 1;
		}
		else
		{
			x += dx;
			y += dy;
			z += dz;
		}
		collision = true;
		return true;
	}
	
	static transform = function(M, invScale)
	{
		//Transforms the collider by the given matrix and scale. Useful when transforming between different spaces for collisions with submeshes
		var p = matrix_transform_vertex(M, x, y, z);
		x = p[0]; y = p[1]; z = p[2];
		var u = matrix_transform_vertex(M, xup * invScale, yup * invScale, zup * invScale);
		xup = u[0] - M[12]; yup = u[1] - M[13]; zup = u[2] - M[14];
		var n = matrix_transform_vertex(M, nx * invScale, ny * invScale, nz * invScale);
		nx = n[0] - M[12]; ny = n[1] - M[13]; nz = n[2] - M[14];
		radius /= invScale;
		height /= invScale;
	}
}
