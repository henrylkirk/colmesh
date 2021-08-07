/// @function ColmeshCollider
/// @param id - The owner's instance id
/// @param {real} [height] - The height of the capsule collider
/// @param {real} [radius] - The radius of the capsule collider
/// @param {boolean} [fast=true] - If false, use precise collision checks
/// @description A helper struct for use with Colmesh
function ColmeshCollider(id, height = 16, radius = height * 0.5, fast = true) constructor {
	self.height = height;
	self.radius = radius;
	self.fast = fast;
	static slope_angle = 40; // the angle of slopes it can traverse
	self.id = id; // store owner instance id
	
	/// @function move(vx, vy, vz)
	static move = function(vx, vy, vz){
		with id {
			
			// Apply friction
			var fric = is_on_ground ? friction_ground : friction_air;
			velocity.x = ((x - prev_position.x) * fric) + vx;
			velocity.y = ((y - prev_position.y) * fric) + vy;
			velocity.z = ((z - prev_position.z) * (0.99) - mass) + vz;

			velocity.x = clamp(velocity.x, -velocity_max.x, velocity_max.x);
			velocity.y = clamp(velocity.y, -velocity_max.y, velocity_max.y);
			velocity.z = clamp(velocity.z, -velocity_max.z, velocity_max.z);
			
			// Save previous position
			prev_position.set(x, y, z);
			
			// Apply velocity to position
			x += velocity.x;
			y += velocity.y;
			z += velocity.z;
			
			if !other.fast {
				// Cast a short-range ray from the previous position to the current position to avoid going through geometry
				// Only cast ray if there's a risk that we've gone through geometry
				if (sqr(x - prev_position.x) + sqr(y - prev_position.y) + sqr(z - prev_position.z) > sqr(other.radius)) {
					var d = other.height * (0.5 + 0.5 * sign(xup * (x - prev_position.x) + yup * (y - prev_position.y) + zup * (z - prev_position.z)));
					var dx = xup * d;
					var dy = yup * d;
					var dz = zup * d;
					ray = global.room_colmesh.cast_ray(prev_position.x + dx, prev_position.y + dy, prev_position.z + dz, x + dx, y + dy, z + dz);
					if is_struct(ray) {
						x = ray.x - dx - (x - prev_position.x) * 0.1;
						y = ray.y - dy - (y - prev_position.y) * 0.1;
						z = ray.z - dz - (z - prev_position.z) * 0.1;
					}
				}
			}

			// Avoid ground
			var col = global.room_colmesh.displace_capsule(x, y, z, xup, yup, zup, other.radius, other.height, other.slope_angle, true, true);
			if (is_struct(col) and col.is_collision) {
				x = col.x;
				y = col.y;
				z = col.z;
				is_on_ground = col.is_on_ground;
			} else {
				is_on_ground = false;
			}

			// Find z ground
			//var ray = global.room_colmesh.cast_ray_ext(x, y, z, x, y, -32);
			//if is_struct(ray) {
			//	z_ground = ray.z;
			//}
			
		}
	}
	
}