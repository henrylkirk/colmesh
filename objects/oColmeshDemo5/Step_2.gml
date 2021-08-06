// Clamp velocity
velocity.x = clamp(velocity.x, -velocity_max.x, velocity_max.x);
velocity.y = clamp(velocity.y, -velocity_max.y, velocity_max.y);
velocity.z = clamp(velocity.z, -velocity_max.z, velocity_max.z);

// Apply friction
if is_on_ground {
	velocity.multiply(friction_ground, friction_ground, 1);
} else {
	velocity.multiply(friction_air, friction_air, 1);
}

// Apply velocity to position
x += velocity.x;
y += velocity.y;
z += velocity.z;

// Move collider
collider.step();