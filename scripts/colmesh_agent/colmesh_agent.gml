//A ColMesh agent is a system for more easily making a player or other objects interact with the level model.

function colmesh_agent(_x, _y, _z, _xup, _yup, _zup, _radius, _height, _slopeAngle = 0, _fast = true, _executeColFunc = false) constructor
{
	x = _x;
	y = _y;
	z = _z;
	ground = false;
	var l = cmDist(0, 0, 0, _xup, _yup, _zup);
	xup = _xup / l;
	yup = _yup / l;
	zup = _zup / l;
	raycast = false;
	radius = _radius;
	height = _height;
	fast = _fast;
	slope = dcos(_slopeAngle);
	slopeAngle = _slopeAngle;
	executeColFunc = _executeColFunc;
	
	spd = 0;
	spdX = 0;
	spdY = 0;
	spdZ = 0;
	maxSpd = 9999;
	
	prevX = x;
	prevY = y;
	prevZ = z;
	airFrictionFactor = 1;
	groundFrictionFactor = .5;
	
	gravityX = 0;
	gravityY = 0;
	gravityZ = -1;
	
	collider = new colmesh_collider_capsule(x, y, z, xup, yup, zup, radius, height, slopeAngle, !fast);
	
	static setGravity = function(gx, gy, gz)
	{
		gravityX = gx;
		gravityY = gy;
		gravityZ = gz;
	}
	
	static setFriction = function(_groundFriction, _airFriction)
	{
		groundFrictionFactor = _groundFriction;
		airFrictionFactor = _airFriction;
	}
	
	static setRaycast = function(_raycast)
	{
		raycast = _raycast;
	}
	
	static setMaxspeed = function(_maxSpd)
	{
		maxSpd = _maxSpd;
	}
	
	static step = function(xAcceleration, yAcceleration, zAcceleration)
	{
		spdX = x - prevX;
		spdY = y - prevY;
		spdZ = z - prevZ;
		
		//Save previous coords
		prevX = x;
		prevY = y;
		prevZ = z;
		
		//Apply friction
		var f = ground ? groundFrictionFactor : airFrictionFactor;
		spdX *= f;
		spdY *= f;
		spdZ *= f;
		
		//Apply gravity
		spdX += gravityX;
		spdY += gravityY;
		spdZ += gravityZ;
		
		//Add acceleration
		spdX += xAcceleration;
		spdY += yAcceleration;
		spdZ += zAcceleration;
		
		//Limit the speed
		spd = point_distance_3d(0, 0, 0, spdX, spdY, spdZ);
		if (spd > maxSpd)
		{
			var d = maxSpd / spd;
			spdX *= d;
			spdY *= d;
			spdZ *= d;
		}
		
		//Apply speed
		x += spdX;
		y += spdY;
		z += spdZ;
		
		//Reset ground variable
		ground = false;
	}
	
	static avoid = function(colMesh)
	{
		if (raycast && spd >= radius)
		{
			//Find the best fitting place along the capsule's central axis to cast the ray from
			var d = height * (cmDot(xup, yup, zup, spdX, spdY, spdZ) > 0);
			var dx = xup * d;
			var dy = yup * d;
			var dz = zup * d;
			var ray = colMesh.castRay(prevX + dx, prevY + dy, prevZ + dz, x + dx, y + dy, z + dz);
			if (ray.hit)
			{
				x = ray.x - dx - spdX * .1;
				y = ray.y - dy - spdY * .1;
				z = ray.z - dz - spdZ * .1;
			}
		}
		collider.x = x;
		collider.y = y;
		collider.z = z;
		collider.xup = xup;
		collider.yup = yup;
		collider.zup = zup;
		if (collider.avoid(colMesh))
		{
			x = collider.x;
			y = collider.y;
			z = collider.z;
			ground = collider.ground;
		}
		if (executeColFunc)
		{
			collider.executeColFunc();
		}
	}
}