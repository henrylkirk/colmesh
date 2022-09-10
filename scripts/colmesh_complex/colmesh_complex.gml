// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function colmesh_complex(_colMesh, _xup, _yup, _zup) constructor
{
	colMesh = _colMesh;
	nodes = [];
	connectors = [];
	gravity = 1;
	xup = _xup;
	yup = _yup;
	zup = _zup;
	impulseX = 0;
	impulseY = 0;
	impulseZ = 0;
	region = undefined;
	groundFriction = .9;
	airFriction = .98;
	
	static step = function(iterations)
	{
		if (iterations <= 0){exit;}
		var amount = 1 / iterations;
		var nodeNum = array_length(nodes);
		var connectorNum = array_length(connectors);
		var minX = 99999;
		var minY = 99999;
		var minZ = 99999;
		var maxX = -99999;
		var maxY = -99999;
		var maxZ = -99999;
		var R = 0;
		var spdX = 0;
		var spdY = 0;
		var spdZ = 0;
		for (var i = 0; i < nodeNum; i ++)
		{
			var node = nodes[i];
			node.stepBegin();
			minX = min(node.x, minX);
			minY = min(node.y, minY);
			minZ = min(node.z, minZ);
			maxX = max(node.x, maxX);
			maxY = max(node.y, maxY);
			maxZ = max(node.z, maxZ);
			spdX += node.spdX;
			spdY += node.spdY;
			spdZ += node.spdZ;
			R += node.radius;
		}
		x = (minX + maxX) * .5;
		y = (minY + maxY) * .5;
		z = (minZ + maxZ) * .5;
		var radius = max(maxX - minX, maxY - minY, maxZ - minZ) * .5 + R / nodeNum;
		spdX /= nodeNum;
		spdY /= nodeNum;
		spdZ /= nodeNum;
		region = colMesh.getRegion(x, y, z, spdX, spdY, spdZ, radius, 1);
		impulseX = 0;
		impulseY = 0;
		impulseZ = 0;
		
		repeat iterations
		{
			for (var i = 0; i < nodeNum; i ++)
			{
				nodes[i].step(amount);
			}
			for (var i = 0; i < connectorNum; i ++)
			{
				connectors[i].apply();
			}
		}
	}
	
	static draw = function()
	{
		var nodeNum = array_length(nodes);
		for (var i = 0; i < nodeNum; i ++)
		{
			with nodes[i]
			{
				colmesh_debug_draw_sphere(x, y, z, radius, c_red);
			}
		}
	}
	
	static impulse = function(dx, dy, dz)
	{
		impulseX = dx;
		impulseY = dy;
		impulseZ = dz;
	}
	
	/// @func addNode(x, y, z, radius, weight, movable)
	static addNode = function(_x, _y, _z, _radius, _weight, _movable)
	{
		static node = function(_x, _y, _z, _radius, _weight, _movable) constructor
		{
			parent = other;
			x = _x;
			y = _y;
			z = _z;
			radius = _radius;
			weight = _weight;
			movable = is_undefined(_movable) ? false : _movable;
			px = x;
			py = y;
			pz = z;
			ground = false;
			
			spdX = 0;
			spdY = 0;
			spdZ = 0;
			
			static stepBegin = function()
			{
				var f = ground ? parent.groundFriction : parent.airFriction; 
				spdX = (x - px) * f - parent.xup * parent.gravity;
				spdY = (y - py) * f - parent.yup * parent.gravity;
				spdZ = (z - pz) * f - parent.zup * parent.gravity;
				if (movable)
				{
					spdX += parent.impulseX;
					spdY += parent.impulseY;
					spdZ += parent.impulseZ;
				}
				px = x;
				py = y;
				pz = z;
				ground = false;
			}
			
			static step = function(amount)
			{
				x += spdX * amount;
				y += spdY * amount;
				z += spdZ * amount;
				var col = parent.colMesh.regionDisplaceCapsule(parent.region, x, y, z, parent.xup, parent.yup, parent.zup, radius, 0, 0, true, false);
				if (is_array(col))
				{
					x = col[0];
					y = col[1];
					z = col[2];
					ground = true;
				}
			}
		}
		var newNode = new node(_x, _y, _z, _radius, _weight, _movable);
		array_push(nodes, newNode);
		return newNode;
	}
	
	/// @func connectRigid(A, B, solid)
	static connectRigid = function(_A, _B, _solid)
	{
		static rigid = function(_A, _B, _solid) constructor
		{
			A = _A;
			B = _B;
			parent = -1;
			length = point_distance_3d(A.x, A.y, A.z, B.x, B.y, B.z);
			
			static apply = function()
			{
				var l = point_distance_3d(A.x, A.y, A.z, B.x, B.y, B.z);
				if (l <= 0){exit;}
				var d = length / l;
				var d1 = (1 + d) * .5;
				var d2 = (1 - d) * .5;
				A.x = A.x * d1 + B.x * d2;
				A.y = A.y * d1 + B.y * d2;
				A.z = A.z * d1 + B.z * d2;
				B.x = B.x * d1 + A.x * d2;
				B.y = B.y * d1 + A.y * d2;
				B.z = B.z * d1 + A.z * d2;
			}
		}
		var newConnector = new rigid(_A, _B, _solid);
		array_push(connectors, newConnector);
		return newConnector;
	}
}