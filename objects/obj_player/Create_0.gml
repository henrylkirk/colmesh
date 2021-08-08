// Player variables
x = room_width * 0.5;
y = room_height * 0.5;
z = 300;
radius = 10;
height = 16;
velocity_max = new Vector3(12, 12, 16); // Max velocity for all three axis
prev_position = new Vector3(x, y, z); // Position last step
velocity = new Vector3(0, 0, 0); // Current velocity
is_on_ground = false;
xup = 0;
yup = 0;
zup = 1;
enable_z_bounce = false;
collider = new ColmeshCollider(id, height, radius, false);