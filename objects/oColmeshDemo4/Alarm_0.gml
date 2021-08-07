/// @description
var region_size = 250; //<-- You need to define the size of the subdivision regions. Play around with it and see what value fits your model best. This is a list that stores all the triangles in a region in space. A larger value makes Colmesh generation faster, but slows down collision detection. A too low value increases memory usage and generation time.
global.room_colmesh.subdivide(region_size);