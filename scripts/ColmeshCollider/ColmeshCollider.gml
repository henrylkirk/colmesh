/// @function ColmeshCollider
/// @param id - The owner's instance id
/// @param {real} [height] - The height of the capsule collider
/// @param {real} [radius] - The radius of the capsule collider
/// @param {boolean} [fast=true] - If false, use precise collision checks
/// @description A helper struct for use with colmesh
function ColmeshCollider(id, height = 16, radius = height * 0.5, fast = true) constructor {
	self.height = height;
	self.radius = radius;
	self.fast = fast;
	static slope_angle = 40; // the angle of slopes it can traverse
	self.id = id; // store owner instance id
	
	/// @function step
	static step = function(){
		with id {
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
			if is_on_ground {
				z_ground = z;
			} else {
				var ray = global.room_colmesh.cast_ray_ext(x, y, z, x, y, -32);
				if is_struct(ray) {
					z_ground = ray.z;
				}
			}
		}
	}
	
}