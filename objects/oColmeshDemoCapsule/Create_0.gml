/// @description
z = random(100);

colour = [0.2, 0.7, 0.6];

// Create a ray function for this shape, changing the colour of the object if it is hit by a ray
rayFunc = function() {
    colour = [0.5, 1, 0.2];
};

// shape.setRayFunction(rayFunc);
shape = levelColmesh
    .addTrigger(
    new colmesh_capsule(x, y, z, random(2) - 1, random(2) - 1, random(1) + 0.1, 10 + random(30), 100),
    true,
    undefined,
    rayFunc
);
