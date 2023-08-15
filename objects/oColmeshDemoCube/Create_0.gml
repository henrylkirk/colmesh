/// @description
size = 64;
z = size * 0.5;
colour = [0.4, 0.5, 0.8];

// Create a ray function for this shape, changing the colour of the object if it is hit by a ray
rayFunc = function() {
    colour = [1, 0.5, 0.2];
    return true; // Return true so that the ray stops when it hits this shape
};

shape = levelColmesh.addTrigger(new colmesh_cube(x, y, z, size, size, size), true, undefined, rayFunc);
M = matrix_build(shape.x, shape.y, shape.z, 0, 0, 0, shape.halfX, shape.halfY, shape.halfZ);
