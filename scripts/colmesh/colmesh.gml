/*
	ColMesh - 3D Collisions Made Easy!
	TheSnidr 2021
	
	License
	The ColMesh system is licensed under a CreativeCommons Attribution 4.0 International License.
		https://creativecommons.org/licenses/by/4.0/
	This means you are free to use it in both personal and commercial projects, free of charge.
	Appropriate credit is required.
	
	What is a ColMesh?
	A ColMesh is a collection of 3D primitives and triangle meshes against which you can cast rays and do collision checks. It is basically an easy-to-use 3D collision system for GMS 2.3.
	
	What does it do?
	It will push your player out of level geometry.
	It handles slope calculations for you so that your player doesn’t slide down slopes.
	It lets you move platforms around and gives you everything you need to make sure your player moves the same way.
	It lets you cast rays so that your player can shoot bullets or laser beams, and by casting a ray from the player’s previous coordinate to the new coordinate before doing collision checking, you can make sure the player never falls through level geometry.
	
	See forum topic for updated info:
		https://forum.yoyogames.com/index.php?threads/82765/
	
	Also feel free to join the Discord channel:
		www.TheSnidr.com
*/

#macro CM_DEBUG true	// Set to false if you don't want the ColMesh system to output debug messages
#macro CM_MAX_RECURSION 8	// The maximum recursion depth. Applies when you place a ColMesh inside itself
#macro CM_FIRST_PASS_RADIUS 1.2 // The radius for the first pass when doing precise collision checking. 
#macro CM_COL global.ColMeshCol // A global array that is used for returning a position after collision
#macro CM_RAY global.ColMeshRay // A global array that is used for ray casting
#macro CM_TRANSFORM global.ColMeshTransformQueue // The calling object's transformation queue
#macro CM_TRANSFORM_MAP global.ColMeshTransformQueueMap // A map containing the transformation stacks of objects colliding with the colmesh
#macro CM_RECURSION global.ColMeshRecursionCounter // A global variable counting number of recursions
#macro CM_CALLING_OBJECT global.ColMeshCallingObject // A global variable storing the instance that is currently using either colmesh.displace_capsule or colmesh.cast_ray
global.ColMeshCallingObject = -1;
global.ColMeshTransformQueue = -1;
global.ColMeshRecursionCounter = 0;
global.ColMeshRay = array_create(7);
global.ColMeshCol = array_create(7);
global.ColMeshDebugShapes = array_create(eColMeshShape.Num, -1);
global.ColMeshTransformQueueMap = ds_map_create();

/// @function Colmesh
/// @description Creates an empty ColMesh
function Colmesh() : ColmeshShape() constructor {
	sp_hash = -1; // used for a ds map
	origin_x = 0;
	origin_y = 0;
	origin_z = 0;
	triangle = -1;
	triangles = [];
	region_size = 0;
	temp_list  = ds_list_create();	// Temporary list used for collision
	shape_list = ds_list_create();	// List containing all the shapes of the colmesh
	minimum = array_create(3);
	maximum = array_create(3);
	priority = array_create(CM_MAX_RECURSION, -1); // An array containing a ds priority for each level of recursion
	
	/// @function subdivide(region_size)
	/// @description Subdivide the colmesh into smaller regions, and save those regions to a ds_map. If the colmesh has already been subdivided, that is cleared first. A smaller region size will result in more regions, but fewer collision shapes per region.
	static subdivide = function(region_size){
		var debugTime = get_timer();
		
		// Clear old subdivision
		clear_subdiv();
		
		// Update subdivision parameters
		sp_hash = ds_map_create();
		region_size = region_size;
		origin_x = (minimum[0] + maximum[0]) * .5;
		origin_y = (minimum[1] + maximum[1]) * .5;
		origin_z = (minimum[2] + maximum[2]) * .5;
		
		// Subdivide
		var shapeNum = ds_list_size(shape_list);
		for (var i = 0; i < shapeNum; i++){
			add_shape_to_subdiv(shape_list[| i]);
		}
		colmesh_debug_message("colmesh.subdivide: Generated spatial hash with " + string(ds_map_size(sp_hash)) + " regions in " + string((get_timer() - debugTime) / 1000) + " milliseconds");
	}
	
	/// @function add_shape_to_subdiv(shape, [regions], [precise])
	static add_shape_to_subdiv = function(shape, regions, precise){
		if (sp_hash < 0){ exit; }
		var struct = get_shape(shape);
		if (is_undefined(precise)){ precise = true; }
		if (is_undefined(regions)){ regions = get_regions(struct.get_min_max()); }
		
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat xNum {
			++xx;
			var yy = regions[1];
			var _x = (xx + .5) * region_size + origin_x;
			repeat yNum {
				++yy;
				var zz = regions[2];
				var _y = (yy + .5) * region_size + origin_y;
				repeat zNum {
					++zz;
					var _z = (zz + .5) * region_size + origin_z;
					if (!precise or struct.intersects_cube(region_size * .5, _x, _y, _z)){
						var key = colmesh_get_key(xx, yy, zz);
						var list = sp_hash[? key];
						if (is_undefined(list)){
							list = ds_list_create();
							sp_hash[? key] = list;
						}
						ds_list_add(list, shape);
					}
				}
			}
		}
	}
	
	/// @function remove_shape_from_subdiv(shape, regions*)
	static remove_shape_from_subdiv = function(shape, regions) {
		if (sp_hash < 0){return false;}
		if (is_undefined(regions)){ regions = get_regions(get_shape(shape).get_min_max()); }
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat xNum {
			++xx;
			var yy = regions[1];
			repeat yNum {
				++yy;
				var zz = regions[2];
				repeat zNum {
					++zz;
					var key = colmesh_get_key(xx, yy, zz);
					var list = sp_hash[? key];
					if (is_undefined(list)){
						continue;
					}
					var ind = ds_list_find_index(list, shape);
					if (ind < 0){continue;}
					ds_list_delete(list, ind);
					if (ds_list_empty(list)){
						ds_list_destroy(list);
						ds_map_delete(sp_hash, key);
					}
				}
			}
		}
	}
	
	/// @function clear_subdiv()
	/// @description Clears any data structures related to the subdivision of the colmesh
	static clear_subdiv = function(){
		if (sp_hash >= 0){
			var region = ds_map_find_first(sp_hash);
			while (!is_undefined(region)){
				ds_list_destroy(sp_hash[? region]);
				region = ds_map_find_next(sp_hash, region);
			}
			ds_map_destroy(sp_hash);
			sp_hash = -1;
		}
		
		// Delete any queue lists that have been created in instances colliding with the colmesh
		var key = ds_map_find_first(CM_TRANSFORM_MAP);
		while (!is_undefined(key)){
			ds_queue_destroy(CM_TRANSFORM_MAP[? key]);
			key = ds_map_find_next(CM_TRANSFORM_MAP, key);
		}
		ds_map_clear(CM_TRANSFORM_MAP);
	}
	
	/// @function clear()
	/// @description Clears all info from the colmesh
	static clear = function(){
		clear_subdiv();
		var h = 99999;
		triangles = [];
		minimum = [ 99999,  99999,  99999];
		maximum = [-99999, -99999, -99999];
		ds_list_clear(temp_list);
		ds_list_clear(shape_list);
		for (var i = 0; i < CM_MAX_RECURSION; i++) {
			if (priority[i] < 0) break;
			ds_priority_destroy(priority[i]);
			priority[i] = -1;
		}
	}
	
	/// @function destroy()
	/// @description Destroys the colmesh
	static destroy = function() {
		clear();
		ds_list_destroy(temp_list);
		ds_list_destroy(shape_list);
		if ds_exists(sp_hash, ds_type_map) {
			ds_map_destroy(sp_hash);
		}
	}
	
	/// @function get_region(AABB[6])
	/// @description Returns a list containing all the shapes in the regions the AABB of the given capsule touches. If the colmesh is not subdivided, this will return a list of all the shapes in the colmesh.
	static get_region = function(AABB)  {

		var minx = AABB[0], miny = AABB[1], minz = AABB[2], maxx = AABB[3], maxy = AABB[4], maxz = AABB[5];
		if (minx > maximum[0] or miny > maximum[1] or minz > maximum[2] or maxx < minimum[0] or maxy < minimum[1] or maxz < minimum[2]) {
			// If the capsule is fully outside the AABB of the colmesh, return undefined
			return undefined;
		}
		
		ds_list_clear(temp_list);
		if (sp_hash < 0) {
			var i = ds_list_size(shape_list);
			repeat i {
				var shape = shape_list[| --i];
				if (!get_shape(shape).check_aabb(minx, miny, minz, maxx, maxy, maxz)){ continue; } // Only add the shape to the list if its AABB intersects the capsule AABB
				ds_list_add(temp_list, shape);
			}
			return temp_list;
		}
		
		var regions = get_regions(AABB);
		var xNum = regions[3] - regions[0];
		var yNum = regions[4] - regions[1];
		var zNum = regions[5] - regions[2];
		var xx = regions[0];
		repeat (xNum) {
			++xx;
			var yy = regions[1];
			repeat (yNum) {
				++yy;
				var zz = regions[2];
				repeat (zNum) {
					++zz;
					
					// Check if the region exists
					var key = colmesh_get_key(xx, yy, zz);
					var region = sp_hash[? key];
					if (is_undefined(region)){continue;}
					
					// The region exists! Check all the shapes in the region and see if their AABB intersects the AABB of the capsule
					var i = ds_list_size(region);
					repeat i {
						var shape = region[| --i];
						if (!get_shape(shape).check_aabb(minx, miny, minz, maxx, maxy, maxz)){continue;} //Only add the shape to the list if its AABB intersects the capsule AABB
						if (ds_list_find_index(temp_list, shape) >= 0){continue;} //Make sure the shape hasn't already been added to the list
						ds_list_add(temp_list, shape);
					}
				}
			}
		}
		return temp_list;
	}
	
	#region Add shapes
	
	/// @function add_shape(shape)
	/// @param shape - Look in ColmeshShape for a list of all the shapes that can be added
	/// @description Adds the given shape to the ColMesh
	static add_shape = function(shape){
		// Typical usage:
		// global.room_colmesh.add_shape(new colmesh_sphere(x, y, z, radius));
		var s = get_shape(shape);
		expand_boundaries(s.get_min_max());
		if (s.type != eColMeshShape.Dynamic){
			// Add the shape to the subdivision. Dynamic shapes take care of this themselves.
			add_shape_to_subdiv(s);
		}
		ds_list_add(shape_list, shape);
		return shape;
	}
	
	/// @function add_trigger(shape, solid, colFunc*, rayFunc*)
	/// @description Create a trigger object. This will not displace the player.
	static add_trigger = function(shape, solid, colFunc, rayFunc){
		// You can give the shape custom collision functions.
		// These custom functions are NOT saved when writing the ColMesh to a buffer
		// You have access to the following global variables in the custom functions:
		// CM_COL - An array containing the current position of the calling object
		// CM_CALLING_OBJECT - The instance that is currently checking for collisions
			
		// colFunc lets you give the shape a custom collision function.
		// This is useful for example for collisions with collectible objects like coins and powerups.
		
		// rayFunc lets you give the shape a custom function that is executed if a ray hits the shape.
		
		add_shape(shape);
		shape.set_trigger(solid, colFunc, rayFunc);
		return shape;
	}
	
	/// @function add_dynamic(shape, M)
	/// @description Adds a dynamic shape to the ColMesh
	static add_dynamic = function(shape, M){
		// A dynamic is a special kind of shape container that can be moved, scaled and rotated dynamically.
		// Look in ColmeshShape for a list of all the shapes that can be added.
			
		// You can also supply a whole different colmesh to a dynamic.
		// Dynamics will not be saved when using colmesh.save or colmesh.write_to_buffer.
			
		// Scaling must be uniform, ie. the same for all dimensions. Non-uniform scaling and shearing is automatically removed from the matrix.
			
		//Typical usage:
		//	//Create event
		//	M = matrix_build(x, y, z, xangle, yangle, zangle, size, size, size); //Create a matrix
		//	dynamic = global.room_colmesh.add_dynamic(new colmesh_sphere(0, 0, 0, radius), M); //Add a dynamic sphere to the colmesh, and save it to a variable called "dynamic"
				
		//	//Step event
		//	M = matrix_build(x, y, z, xangle, yangle, zangle, size, size, size); // Update the matrix
		//	dynamic.setMatrix(M, true); // "moving" should only be true if the orientation is updated every step
		return add_shape(new colmesh_dynamic(shape, self, M, ds_list_size(shape_list)));
	}
	
	/// @function add_mesh(mesh, [matrix])
	/// @param {obj} mesh - Should be either a path to an OBJ file, an array containing buffers, or a buffer containing vertex info
	/// @description Adds a mesh to the colmesh
	/// @returns void - This script does not return anything. The mesh as a whole does not have a handle. Triangles are added to the colmesh individually.
	static add_mesh = function(mesh, M){
		
		// "mesh" should be in the following format:
		// 3D position, 3x4 bytes
		// 3D normal, 3x4 bytes
		// UV coords, 2x4 bytes
		// Colour, 4 bytes
			
		// Matrix is an optional argument in case you'd like to transform your mesh before adding it to the ColMesh
		var load = false;
		if (is_string(mesh)){
			load = true;
			mesh = colmesh_load_obj_to_buffer(mesh);
		}
		if (is_array(mesh)){
			load = true;
			var _mesh = buffer_create(1, buffer_fixed, 1);
			var num = array_length(mesh);
			var totalSize = 0;
			for (var i = 0; i < num; i++) {
				var buff_size = buffer_get_size(mesh[i]);
				var buffPos = totalSize;
				totalSize += buff_size;
				buffer_resize(mesh, totalSize);
				buffer_copy(mesh[i], 0, buff_size, mesh, buffPos);
			}
			mesh = _mesh;
		}
		if (mesh >= 0){
			// Create triangle list from mesh
			var bytesPerVert = 3 * 4 + 3 * 4 + 2 * 4 + 4;
			var bytesPerTri = bytesPerVert * 3;
			var mBuffSize = buffer_get_size(mesh);
			var triNum = mBuffSize div bytesPerTri;
			array_resize(triangles, array_length(triangles) + triNum);
			for (var i = 0; i < mBuffSize; i += bytesPerTri){
				static V = array_create(9);
				for (var j = 0; j < 3; j++){
					for (var k = 0; k < 3; k++){
						// Read vert position
					    V[j * 3 + k] = buffer_peek(mesh, i + j * bytesPerVert + k * 4, buffer_f32);
					}
				}
				if (is_array(M)){
					array_copy(V, 0, colmesh_matrix_transform_vertex(M, V[0], V[1], V[2]), 0, 3);
					array_copy(V, 3, colmesh_matrix_transform_vertex(M, V[3], V[4], V[5]), 0, 3);
					array_copy(V, 6, colmesh_matrix_transform_vertex(M, V[6], V[7], V[8]), 0, 3);
				}
				add_triangle(V);
			}
			if load{
				buffer_delete(mesh);
			}
			return true;
		}
		return false;
	}
	
	/// @function add_triangle(V[9])
	/// @description Add a single triangle to the colmesh
	static add_triangle = function(V){
		var shapeNum = ds_list_size(shape_list);
		if (array_length(triangles) <= shapeNum){
			array_resize(triangles, shapeNum + 1);
		}
		// Construct normal vector
		var nx = (V[4] - V[1]) * (V[8] - V[2]) - (V[5] - V[2]) * (V[7] - V[1]);
		var ny = (V[5] - V[2]) * (V[6] - V[0]) - (V[3] - V[0]) * (V[8] - V[2]);
		var nz = (V[3] - V[0]) * (V[7] - V[1]) - (V[4] - V[1]) * (V[6] - V[0]);
		var l = sqrt(dot_product_3d(nx, ny, nz, nx, ny, nz));
		if (l <= 0){ return false; }
		l = 1 / l;
		var tri = array_create(12);
		array_copy(tri, 0, V, 0, 9);
		tri[9]  = nx * l;
		tri[10] = ny * l;
		tri[11] = nz * l;
		add_shape(tri);
		return -1;
	}
	
	/// @function remove_shape(shape)
	/// @description Removes the given shape from the ColMesh. Cannot remove a mesh that has been added with colmesh.add_mesh.
	static remove_shape = function(shape){
		var ind = ds_list_find_index(shape_list, shape);
		if (ind < 0){ return false; }
		remove_shape_from_subdiv(shape);
		ds_list_delete(shape_list, ind);
		return true;
	}
	
	#endregion
	
	/// @function displace_capsule(x, y, z, [xup], [yup], [zup], radius, height, slope_angle, fast*, executeColFunc*)
	/// @param {real} x
	/// @param {real} y
	/// @param {real} z
	/// @param {real} [xup]
	/// @param {real} [yup]
	/// @param {real} [zup]
	/// @param {real} radius
	/// @param {real} height
	/// @param {real} slope_angle - Slope is given in degrees, and is the maximum slope angle allowed before the capsule starts sliding downhill
	/// @param {boolean} [fast] - If false, will process in 2 passes: The first pass sorts through all triangles in the region, and checks if there is a potential collision. The second pass makes the capsule avoid triangles, starting with the triangles that cause the greatest displacement.
	/// @description Pushes a capsule out of a collision mesh
	static displace_capsule = function(x, y, z, xup = 0, yup = 0, zup = 1, radius, height, slope_angle, fast = false, executeColFunc){
		
		// This will first use get_region to get a list containing all shapes the capsule potentially could collide with
		
		if (CM_RECURSION == 0) {
			CM_CALLING_OBJECT = other;
		}
		if (is_undefined(fast)){fast = false;}
		var AABB = colmesh_capsule_get_aabb(x, y, z, xup, yup, zup, fast ? radius * CM_FIRST_PASS_RADIUS : radius, height);
		var region = get_region(AABB);
		
		var coll_array = region_displace_capsule(region, x, y, z, xup, yup, zup, radius, height, slope_angle, fast, executeColFunc);
	
		// Transform array into struct
		return {
			x : coll_array[0],
			y : coll_array[1],
			z : coll_array[2],
			nx : coll_array[3],
			ny : coll_array[4],
			nz : coll_array[5],
			is_collision : coll_array[6],
			is_on_ground : (xup * coll_array[3] + yup * coll_array[4] + zup * coll_array[5] > 0.7)
		}
	}
	
	/// @function region_displace_capsule(region, x, y, z, xup, yup, zup, radius, height, slope_angle, [fast=true], [execute_col_func=false])
	/// @description Pushes a capsule out of a collision mesh
	static region_displace_capsule = function(region, x, y, z, xup, yup, zup, radius, height, slope_angle, _fast = true, execute_col_func = false) {	
			
		// Since dynamic shapes could potentially contain the colmesh itself, this script also needs a recursion counter to avoid infinite loops.
		// You can change the maximum number of recursive calls by changing the CM_MAX_RECURSION macro.

		CM_COL[0] = x;
		CM_COL[1] = y;
		CM_COL[2] = z;
		CM_COL[6] = -1; // Until collision checking is done, this will store the highest dot product between triangle normal and up vector
		
		if (is_undefined(region) or CM_RECURSION >= CM_MAX_RECURSION){
			// Exit the script if the given region does not exist or if we've reached the recursion limit
			return CM_COL;
		}
		var success = false;
		var i = ds_list_size(region);
		var fast = (is_undefined(_fast) ? false : _fast);
		var slope = ((slope_angle <= 0) ? 1 : dcos(slope_angle));
		var executeColFunc = (is_undefined(execute_col_func) ? false : execute_col_func);
		
		// p is the center of the sphere for which we're doing collision checking. 
		// If height is larger than 0, this will be overwritten by the closest point to the shape along the central axis of the capsule
		var p = CM_COL;
		
		if (fast) {
			// If we're doing fast collision checking, the collisions are done on a first-come-first-serve basis. 
			// Fast collisions will also not save anything to the delta matrix queue
			repeat i {
				var shape = get_shape(region[| --i]);
				if (shape.type == eColMeshShape.Trigger){
					if (executeColFunc and is_method(shape.colFunc)){
						++CM_RECURSION;
						if (shape.capsule_collision(CM_COL[0], CM_COL[1], CM_COL[2], xup, yup, zup, radius, height)){
							shape.colFunc(other.id);
						}
						--CM_RECURSION;
					}
					if (!shape.solid) {
						continue;
					}
				}
				if (height != 0) {	
					// If height is larger than 0, this is a capsule, and we must find the most fitting point along the central axis of the capsule
					p = shape.capsule_get_ref(CM_COL[0], CM_COL[1], CM_COL[2], xup, yup, zup, height);
				}
				++CM_RECURSION;
				success |= shape.displace_sphere(p[0], p[1], p[2], xup, yup, zup, height, radius, slope, fast);
				--CM_RECURSION;
			}
			CM_COL[6] = success;
			return CM_COL;
		}
		
		// If this is the first recursive call, clear the transformation stack of the calling object
		if (CM_RECURSION == 0){
			if (CM_CALLING_OBJECT < 0){
				CM_CALLING_OBJECT = other;
			}
			CM_TRANSFORM = CM_TRANSFORM_MAP[? CM_CALLING_OBJECT];
			if (!is_undefined(CM_TRANSFORM)){
				ds_queue_clear(CM_TRANSFORM);
			}
		}
		
		var P = priority[CM_RECURSION];
		if (P < 0){
			// We need a separate ds_priority for each recursive level, otherwise they'll mess with each other
			P = ds_priority_create();
			priority[CM_RECURSION] = P;
		}
		
		repeat i {
			// First pass, find potential collisions and add them to the ds_priority
			var shapeInd = region[| --i];
			var shape = get_shape(shapeInd);
			if (shape.type == eColMeshShape.Trigger){
				if (executeColFunc and is_method(shape.colFunc)){
					++CM_RECURSION;
					if (shape.capsule_collision(CM_COL[0], CM_COL[1], CM_COL[2], xup, yup, zup, radius, height)){
						shape.colFunc(other.id);
					}
					--CM_RECURSION;
				}
			}
			if (!shape.solid){
				continue;
			}
			if (height != 0){
				// If height is larger than 0, this is a capsule, and we must find the most fitting point along the central axis of the capsule
				p = shape.capsule_get_ref(CM_COL[0], CM_COL[1], CM_COL[2], xup, yup, zup, height);
			}
			var pri = shape.get_priority(p[0], p[1], p[2], radius * CM_FIRST_PASS_RADIUS);
			if (pri >= 0){
				ds_priority_add(P, shapeInd, pri);
			}
		}
		
		repeat (ds_priority_size(P)){
			// Second pass, collide with the nearby shapes, starting with the closest one
			var shape = get_shape(ds_priority_delete_min(P));
			if (height != 0){	
				// If height is larger than 0, this is a capsule, and we must find the most fitting point along the central axis of the capsule
				p = shape.capsule_get_ref(CM_COL[0], CM_COL[1], CM_COL[2], xup, yup, zup, height);
			}
			++CM_RECURSION;
			success |= shape.displace_sphere(p[0], p[1], p[2], xup, yup, zup, height, radius, slope, false);
			--CM_RECURSION;
			if (success and slope < 1){
				if (dot_product_3d(xup, yup, zup, CM_COL[3], CM_COL[4], CM_COL[5]) > slope){
					// Set slope to 1 so that slope calculations are only done for the shape that displaces the player the most
					slope = 1; 
				}
			}
		}
		CM_COL[6] = success;
		
		// Reset the calling object to -1 once the script is done running
		if (CM_RECURSION == 0){
			CM_CALLING_OBJECT = -1;	
		}
		
		return CM_COL;
	}
	
	/// @function capsule_collision(x, y, z, xup, yup, zup, radius, height)
	/// @description Returns whether or not the given capsule collides with the colmesh
	static capsule_collision = function(x, y, z, xup, yup, zup, radius, height) {
		var AABB = colmesh_capsule_get_aabb(x, y, z, xup, yup, zup, radius, height);
		var region = get_region(AABB);
		return colmesh_region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height);
	}
	
	/// @function region_capsule_collision(x, y, z, xup, yup, zup, radius, height)
	/// @description Returns whether or not the given capsule collides with the given region
	static region_capsule_collision = function(region, x, y, z, xup, yup, zup, radius, height) {
		return colmesh_region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height);
	}
	
	/// @function get_delta_matrix()
	/// @desription Useful for getting the change in orientation in those cases where the player is standing on a dynamic shape.
	/// @returns {matrix/boolean} delta_matrix
	static get_delta_matrix = function() {
		// If the player stands on a dynamic shape, its matrix and the inverse of its previous matrix are saved to that queue. This is done in colmesh_dynamic.displace_sphere.
		// If the dynamic shape is inside multiple layers of colmeshes, their matrices and inverse previous matrices are also added to the queue.
		// These matrices are all multiplied together in this function, resulting in their combined movements gathered in a single matrix.
		// The reson they are saved to a queue and not just multiplied together immediately is that you usually want to get the delta matrix the step after the collision was performed.
		// Since matrices are arrays, and arrays are stored by their handle, any changes to the arrays from the previous frame will also be applied to the delta matrix!
			
		// Typical usage for making the player move:
		//	var D = global.room_colmesh.get_delta_matrix();
		//	if (is_array(D))
		//	{
		//		var p = matrix_transform_vertex(D, x, y, z);
		//		x = p[0];
		//		y = p[1];
		//		z = p[2];
		//	}
				
		// And for transforming a vector:
		//	var D = global.room_colmesh.get_delta_matrix();
		//	if (is_array(D))
		//	{
		//		var p = matrix_transform_vector(D, xto, yto, zto);
		//		xto = p[0];
		//		yto = p[1];
		//		zto = p[2];
		//	}
			
		// And for transforming a matrix:
		//	var D = global.room_colmesh.get_delta_matrix();
		//	if (is_array(D))
		//	{
		//		colmesh_matrix_multiply_fast(D, targetMatrix, targetMatrix);
		//	}
		var queue = CM_TRANSFORM_MAP[? other];
		if (is_undefined(queue)) {
			queue = ds_queue_create();
			CM_TRANSFORM_MAP[? other] = queue;
		}
		var num = ds_queue_size(queue);
		if (num > 1) {
			// The first two matrices can simply be multiplied together
			var M = ds_queue_dequeue(queue); //The current world matrix
			var pI = ds_queue_dequeue(queue); //The inverse of the previous world matrix
			var m = matrix_multiply(pI, M);
			repeat (num / 2 - 1) {
				// The subsequent matrices need to be multiplied with the target matrix in the correct order
				M = ds_queue_dequeue(queue); // The current world matrix
				pI = ds_queue_dequeue(queue); // The inverse of the previous world matrix
				m = matrix_multiply(matrix_multiply(pI, m), M);
			}
			return m;
		}
		return false;
	}
	
	/// @function get_nearest_point(x, y, z)
	/// @description Returns the nearest point on the colmesh to the given point. Only checks the region the point is in
	static get_nearest_point = function(x, y, z) {
		var aabb = colmesh_capsule_get_aabb(x, y, z, 0, 0, 1, 0, 0);
		return region_get_nearest_point(get_region(aabb), x, y, z);
	}
	
	/// @function region_get_nearest_point(region, x, y, z, radius)
	/// @description Returns the nearest point in the region to the given point
	static region_get_nearest_point = function(region, x, y, z) {
		if (region < 0) {
			return false;
		}
		var i = ds_list_size(region);
		if (i == 0) {
			return false;
		}
		static ret = array_create(3);
		var minD = 9999999;
		ret[0] = x;
		ret[1] = y;
		ret[2] = z;
		repeat i {
			var shapeInd = abs(region[| --i]);
			var shape = get_shape(shape_list[| shapeInd]);
			var p = shape.get_closest_point(x, y, z);
			var d = colmesh_vector_square(p[0] - x, p[1] - y, p[2] - z);
			if (d < minD) {
				minD = d;
				ret[0] = p[0];
				ret[1] = p[1];
				ret[2] = p[2];
			}
		}
		return ret;
	}
	
	#region Ray casting
	
	/// @function cast_ray_ext(x1, y1, z1, x2, y2, z2, executeRayFunc*)
	/// @description Casts a ray from (x1, y1, z1) to (x2, y2, z2)
	/// @returns {array} ray - An array with the following format: [x, y, z, nX, nY, nZ, success], returns false if no intersection
	static cast_ray_ext = function(x1, y1, z1, x2, y2, z2, executeRayFunc) {
		if (sp_hash < 0) {
			// This ColMesh has not been subdivided. Cast a ray against all the shapes it contains
			return region_cast_ray(shape_list, x1, y1, z1, x2, y2, z2, executeRayFunc);
		}
		if (!constrain_ray(x1, y1, z1, x2, y2, z2)){
			// The ray is fully outside the borders of this ColMesh
			return false;
		}
		
		if (CM_RECURSION == 0){
			CM_CALLING_OBJECT = other;
		}
		
		x1 = CM_RAY[0];	y1 = CM_RAY[1];	z1 = CM_RAY[2];
		x2 = CM_RAY[3];	y2 = CM_RAY[4];	z2 = CM_RAY[5];
		var ldx = x2 - x1;
		var ldy = y2 - y1;
		var ldz = z2 - z1;
		var idx = (ldx == 0) ? 0 : 1 / ldx;
		var idy = (ldy == 0) ? 0 : 1 / ldy;
		var idz = (ldz == 0) ? 0 : 1 / ldz;
		var incx = abs(idx) + (idx == 0);
		var incy = abs(idy) + (idy == 0);
		var incz = abs(idz) + (idz == 0);
		var ox = (x1 - origin_x) / region_size;
		var oy = (y1 - origin_y) / region_size;
		var oz = (z1 - origin_z) / region_size;
		var currX = ox, currY = oy, currZ = oz;
		var key = colmesh_get_key(floor(currX), floor(currY), floor(currZ));
		var prevKey = key;
		var t = 0, _t = 0;
		while (t < 1) {	
			// Find which region needs to travel the shortest to cross a wall
			var tMaxX = - frac(currX) * idx;
			var tMaxY = - frac(currY) * idy;
			var tMaxZ = - frac(currZ) * idz;
			if (tMaxX <= 0){tMaxX += incx;}
			if (tMaxY <= 0){tMaxY += incy;}
			if (tMaxZ <= 0){tMaxZ += incz;}
			if (tMaxX < tMaxY) {
				if (tMaxX < tMaxZ) {
					_t += tMaxX;
					currX = round(ox + ldx * _t);
					currY = oy + ldy * _t;
					currZ = oz + ldz * _t;
					key = colmesh_get_key(currX - (ldx < 0), floor(currY), floor(currZ));
				} else {
					_t += tMaxZ;
					currX = ox + ldx * _t;
					currY = oy + ldy * _t;
					currZ = round(oz + ldz * _t);
					key = colmesh_get_key(floor(currX), floor(currY), currZ - (ldz < 0));
				}
			} else {
				if (tMaxY < tMaxZ) {
					_t += tMaxY;
					currX = ox + ldx * _t;
					currY = round(oy + ldy * _t);
					currZ = oz + ldz * _t;
					key = colmesh_get_key(floor(currX), currY - (ldy < 0), floor(currZ));
				} else {
					_t += tMaxZ;
					currX = ox + ldx * _t;
					currY = oy + ldy * _t;
					currZ = round(oz + ldz * _t);
					key = colmesh_get_key(floor(currX), floor(currY), currZ - (ldz < 0));
				}
			}
			
			// Check for ray mesh intersections in the current region
			t = min(1, _t * region_size);
			var region = sp_hash[? prevKey];
			if (!is_undefined(region)){
				if (is_array(colmesh_region_cast_ray(region, x1, y1, z1, x1 + ldx * t, y1 + ldy * t, z1 + ldz * t, executeRayFunc))){
					if (CM_RECURSION == 0){
						CM_CALLING_OBJECT = -1;
					}
					return CM_RAY;
				}
			}
			prevKey = key;
		}
		return false;
	}
	
	/// @function region_cast_ray(region, x1, y1, z1, x2, y2, z2, [execute_ray_func])
	/// @description This ray casting method is faster than the regular colmesh raycasting one, but it will only cast a ray onto the shapes in the current region, and is as such a "short-range" ray
	/// @returns {array/boolean} intersection - If there was an intersection, it returns an array with the following format: [x, y, z, nX, nY, nZ, success]. Returns false if there was no intersection.
	static region_cast_ray = function(region, x1, y1, z1, x2, y2, z2, execute_ray_func = false) {
		return colmesh_region_cast_ray(region, x1, y1, z1, x2, y2, z2, execute_ray_func);
	}
		
	#endregion
	
	#region Supplementaries
	
	/// @function expand_boundaries(AABB[6])
	/// @description Expands the boundaries of the Colmesh. This will only come into effect once the Colmesh is subdivided.
	static expand_boundaries = function(AABB){
		minimum[0] = min(minimum[0], AABB[0]);
		minimum[1] = min(minimum[1], AABB[1]);
		minimum[2] = min(minimum[2], AABB[2]);
		maximum[0] = max(maximum[0], AABB[3]);
		maximum[1] = max(maximum[1], AABB[4]);
		maximum[2] = max(maximum[2], AABB[5]);
	}
	
	/// @function get_shape(shape)
	static get_shape = function(shape){
		// If the given shape is a real value, it must contain a triangle index. 
		// It will then load that triangle into the colmesh, and return the index of the colmesh.
		// If it does not contain a real, the given shape is returned.
		if is_array(shape) {	
			triangle = shape; 
			return self;
		}
		return shape;
	}
	
	/// @function constrain_ray(x1, y1, z1, x2, y2, z2)
	/// @description This method will truncate the ray from (x1, y1, z1) to (x2, y2, z2) so that it fits inside the bounding box of the colmesh. Returns false if the ray is fully outside the bounding box
	static constrain_ray = function(x1, y1, z1, x2, y2, z2) {

		// Convert from world coordinates to local coordinates
		var sx = (maximum[0] - minimum[0]) * 0.5;
		var sy = (maximum[1] - minimum[1]) * 0.5;
		var sz = (maximum[2] - minimum[2]) * 0.5;
		var mx = (maximum[0] + minimum[0]) * 0.5;
		var my = (maximum[1] + minimum[1]) * 0.5;
		var mz = (maximum[2] + minimum[2]) * 0.5;
		x1 = (x1 - mx) / sx;
		y1 = (y1 - my) / sy;
		z1 = (z1 - mz) / sz;
		x2 = (x2 - mx) / sx;
		y2 = (y2 - my) / sy;
		z2 = (z2 - mz) / sz;
		
		var intersection = true;
		if (min(x1, y1, z1, x2, y2, z2) < -1 or max(x1, y1, z1, x2, y2, z2) > 1){
			if ((x1 < -1 and x2 < -1) or (y1 < -1 and y2 < -1) or (z1 < -1 and z2 < -1) or (x1 > 1 and x2 > 1) or (y1 > 1 and y2 > 1) or (z1 > 1 and z2 > 1)){
				// The ray is fully outside the bounding box, and we can end the algorithm here
				return false;
			}
			intersection = false;
		}
	
		// Check X dimension
		var d = x2 - x1;
		if (d != 0){
			// Check outside
			var s = sign(d);
			var t = (- s - x1) / d;
			if (abs(x1) > 1 and t >= 0 and t <= 1){
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 and abs(itsZ) <= 1){
					x1 = - s;
					y1 = itsY;
					z1 = itsZ;
					intersection = true;
				}
			}
			// Check inside
			var t = (s - x1) / d;
			if (t >= 0 and t <= 1){
				var itsY = lerp(y1, y2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsY) <= 1 and abs(itsZ) <= 1){
					x2 = s;
					y2 = itsY;
					z2 = itsZ;
					intersection = true;
				}
			}
		}

		// Check Y dimension
		var d = y2 - y1;
		if (d != 0) {
			// Check outside
			var s = sign(d);
			var t = (- s - y1) / d;
			if (abs(y1) > 1 and t >= 0 and t <= 1){
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 and abs(itsZ) <= 1){
					x1 = itsX;
					y1 = - s;
					z1 = itsZ;
					intersection = true;
				}
			}
			// Check inside
			var t = (s - y1) / d;
			if (t >= 0 and t <= 1){
				var itsX = lerp(x1, x2, t);
				var itsZ = lerp(z1, z2, t);
				if (abs(itsX) <= 1 and abs(itsZ) <= 1){
					x2 = itsX;
					y2 = s;
					z2 = itsZ;
					intersection = true;
				}
			}
		}

		// Check Z dimension
		var d = z2 - z1;
		if (d != 0) {
			// Check outside
			var s = sign(d);
			var t = (- s - z1) / d;
			if (abs(z1) > 1 and t >= 0 and t <= 1){
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsX) <= 1 and abs(itsY) <= 1) {
					x1 = itsX;
					y1 = itsY;
					z1 = - s;
					intersection = true;
				}
			}
			// Check inside
			var t = (s - z1) / d;
			if (t >= 0 and t <= 1){
				var itsX = lerp(x1, x2, t);
				var itsY = lerp(y1, y2, t);
				if (abs(itsY) <= 1 and abs(itsY) <= 1) {
					x2 = itsX;
					y2 = itsY;
					z2 = s;
					intersection = true;
				}
			}
		}
		if (!intersection){
			// The ray is outside the box and does not intersect the box
			return false;
		}

		// Return the point of intersection in world space
		CM_RAY[0] = (x1 * sx + mx);
		CM_RAY[1] = (y1 * sy + my);
		CM_RAY[2] = (z1 * sz + mz);
		CM_RAY[3] = (x2 * sx + mx);
		CM_RAY[4] = (y2 * sy + my);
		CM_RAY[5] = (z2 * sz + mz);
		return true;
	}
		
	#endregion
	
	#region Saving and loading
	
	/// @function save(path)
	/// @description Saves the colmesh to a file.
	static save = function(path) {
		// This function will not work in HTML5.
		// For HTML5 you need to create a buffer, write the colmesh to it with colmesh.write_to_buffer, and save it with buffer_save_async.
		var buff = buffer_create(1, buffer_grow, 1);
		write_to_buffer(buff);
		buffer_resize(buff, buffer_tell(buff));
		buffer_save(buff, path);
		buffer_delete(buff);
	}
	
	/// @function load(path)
	/// @description Loads the colmesh from a file.
	static load = function(path) {
		// This function will not work in HTML5.
		// For HTML5 you need to load a buffer asynchronously, and read from that using colmesh.read_from_buffer.
		var buff = buffer_load(path);
		if (buff < 0) {
			colmesh_debug_message("Colmesh.load: Could not find file " + string(path));
			return false;
		}
		var success = read_from_buffer(buff);
		buffer_delete(buff);
		return success;
	}
	
	/// @function write_to_buffer(saveBuff)
	/// @description Writes/saves the Colmesh to a buffer. This will not save dynamic shapes.
	static write_to_buffer = function(saveBuff){
		var debugTime = current_time;
		var temp_buff = buffer_create(1, buffer_grow, 1);
		var shapeNum = ds_list_size(shape_list);
		
		// Write shape list
		buffer_write(temp_buff, buffer_u32, shapeNum);
		buffer_write(temp_buff, buffer_u32, array_length(triangles));
		for (var i = 0; i < shapeNum; i++) {
			with get_shape(shape_list[| i]) {
				if (type == eColMeshShape.Trigger) {
					// Do not write triggers objects
					buffer_write(temp_buff, buffer_u8, eColMeshShape.None);
					colmesh_debug_message("Error in function Colmesh.write_to_buffer: Trying to save a trigger. Triggers cannot be saved to file!");
					continue;
				}
				buffer_write(temp_buff, buffer_u8, type);
				switch type {
					case eColMeshShape.Mesh:
						for (var j = 0; j < 9; j ++)
						{
							buffer_write(temp_buff, buffer_f32, triangle[j]);
						}
						break;
					case eColMeshShape.Sphere:
						buffer_write(temp_buff, buffer_f32, x);
						buffer_write(temp_buff, buffer_f32, y);
						buffer_write(temp_buff, buffer_f32, z);
						buffer_write(temp_buff, buffer_f32, R);
						break;
					case eColMeshShape.Capsule:
						buffer_write(temp_buff, buffer_f32, x);
						buffer_write(temp_buff, buffer_f32, y);
						buffer_write(temp_buff, buffer_f32, z);
						buffer_write(temp_buff, buffer_f32, xup);
						buffer_write(temp_buff, buffer_f32, yup);
						buffer_write(temp_buff, buffer_f32, zup);
						buffer_write(temp_buff, buffer_f32, R);
						buffer_write(temp_buff, buffer_f32, H);
						break;
					case eColMeshShape.Cylinder:
						buffer_write(temp_buff, buffer_f32, x);
						buffer_write(temp_buff, buffer_f32, y);
						buffer_write(temp_buff, buffer_f32, z);
						buffer_write(temp_buff, buffer_f32, xup);
						buffer_write(temp_buff, buffer_f32, yup);
						buffer_write(temp_buff, buffer_f32, zup);
						buffer_write(temp_buff, buffer_f32, R);
						buffer_write(temp_buff, buffer_f32, H);
						break;
					case eColMeshShape.Torus:
						buffer_write(temp_buff, buffer_f32, x);
						buffer_write(temp_buff, buffer_f32, y);
						buffer_write(temp_buff, buffer_f32, z);
						buffer_write(temp_buff, buffer_f32, xup);
						buffer_write(temp_buff, buffer_f32, yup);
						buffer_write(temp_buff, buffer_f32, zup);
						buffer_write(temp_buff, buffer_f32, R);
						buffer_write(temp_buff, buffer_f32, r);
						break;
					case eColMeshShape.Cube:
						buffer_write(temp_buff, buffer_f32, x);
						buffer_write(temp_buff, buffer_f32, y);
						buffer_write(temp_buff, buffer_f32, z);
						buffer_write(temp_buff, buffer_f32, halfW);
						buffer_write(temp_buff, buffer_f32, halfL);
						buffer_write(temp_buff, buffer_f32, halfH);
						break;
					case eColMeshShape.Block:
						buffer_write(temp_buff, buffer_f32, M[0]);
						buffer_write(temp_buff, buffer_f32, M[1]);
						buffer_write(temp_buff, buffer_f32, M[2]);
						buffer_write(temp_buff, buffer_f32, M[4]);
						buffer_write(temp_buff, buffer_f32, M[5]);
						buffer_write(temp_buff, buffer_f32, M[6]);
						buffer_write(temp_buff, buffer_f32, M[8]);
						buffer_write(temp_buff, buffer_f32, M[9]);
						buffer_write(temp_buff, buffer_f32, M[10]);
						buffer_write(temp_buff, buffer_f32, M[12]);
						buffer_write(temp_buff, buffer_f32, M[13]);
						buffer_write(temp_buff, buffer_f32, M[14]);
						break;
				}
			}
		}

		// Write subdivision to buffer
		if (sp_hash >= 0) {
			buffer_write(temp_buff, buffer_u32, ds_map_size(sp_hash));
			buffer_write(temp_buff, buffer_f32, region_size);
			buffer_write(temp_buff, buffer_f32, origin_x);
			buffer_write(temp_buff, buffer_f32, origin_y);
			buffer_write(temp_buff, buffer_f32, origin_z);
			
			var key = ds_map_find_first(sp_hash);
			while (!is_undefined(key)) {
				var region = sp_hash[? key];
				var num = ds_list_size(region);
				var n = num;
				buffer_write(temp_buff, buffer_u64, key);
				var numPos = buffer_tell(temp_buff);
				buffer_write(temp_buff, buffer_u32, num);
				repeat n {
					var shapeInd = region[| --n];
					buffer_write(temp_buff, buffer_u32, ds_list_find_index(shape_list, shapeInd));
				}
				buffer_poke(temp_buff, numPos, buffer_u32, num);
				key = ds_map_find_next(sp_hash, key);
			}
		} else {
			buffer_write(temp_buff, buffer_u32, 0);
		}

		// Write to savebuff
		var buff_size = buffer_tell(temp_buff);
		buffer_write(saveBuff, buffer_string, "ColMesh v3");
		buffer_write(saveBuff, buffer_u64, buff_size);
		buffer_copy(temp_buff, 0, buff_size, saveBuff, buffer_tell(saveBuff));
		buffer_seek(saveBuff, buffer_seek_relative, buff_size);
		colmesh_debug_message("Script Colmesh.write_to_buffer: Wrote colmesh to buffer in " + string(current_time - debugTime) + " milliseconds");

		// Clean up
		buffer_delete(temp_buff);
	}
		
	/// @function read_from_buffer(load_buff)
	/// @description Reads a collision mesh from the given buffer
	static read_from_buffer = function(load_buff) {
		var debugTime = current_time;
		clear();
		
		// Make sure this is a colmesh
		var version = 3;
		var header_text = buffer_read(load_buff, buffer_string);
		var buff_size = buffer_read(load_buff, buffer_u64);
		var temp_buff = buffer_create(buff_size, buffer_fixed, 1);
		buffer_copy(load_buff, buffer_tell(load_buff), buff_size, temp_buff, 0);
		buffer_seek(load_buff, buffer_seek_relative, buff_size);
		
		switch header_text {
			case "ColMesh v3":
				version = 3;
				break;
			case "ColMesh v2":
				version = 2;
				region_size = buffer_read(temp_buff, buffer_f32);
				buffer_seek(temp_buff, buffer_seek_relative, 36);
				subdivide(region_size);
				break;
			case "ColMesh":
				version = 1;
				region_size = buffer_read(temp_buff, buffer_f32);
				buffer_seek(temp_buff, buffer_seek_relative, 54);
				subdivide(region_size);
				break;
			default:
				colmesh_debug_message("ERROR in script Colmesh.read_from_buffer: Could not find colmesh in buffer.");
				return false;
		}
		
		// Read shape list
		var shapeNum = buffer_read(temp_buff, buffer_u32);
		var triNum = buffer_read(temp_buff, buffer_u32);
		array_resize(triangles, triNum);
		for (var i = 0; i < shapeNum; i++){
			var type = buffer_read(temp_buff, buffer_u8);
			switch (type){
				case eColMeshShape.Mesh:
					var V = array_create(9);
					for (var j = 0; j < 9; j++){
						V[j] = buffer_read(temp_buff, buffer_f32);
					}
					add_triangle(V);
					break;
				case eColMeshShape.Sphere:
					var _x = buffer_read(temp_buff, buffer_f32);
					var _y = buffer_read(temp_buff, buffer_f32);
					var _z = buffer_read(temp_buff, buffer_f32);
					var R  = buffer_read(temp_buff, buffer_f32);
					add_shape(new colmesh_sphere(_x, _y, _z, R));
					break;
				case eColMeshShape.Capsule:
					var _x  = buffer_read(temp_buff, buffer_f32);
					var _y  = buffer_read(temp_buff, buffer_f32);
					var _z  = buffer_read(temp_buff, buffer_f32);
					var xup = buffer_read(temp_buff, buffer_f32);
					var yup = buffer_read(temp_buff, buffer_f32);
					var zup = buffer_read(temp_buff, buffer_f32);
					var R   = buffer_read(temp_buff, buffer_f32);
					var H   = buffer_read(temp_buff, buffer_f32);
					add_shape(new colmesh_capsule(_x, _y, _z, xup, yup, zup, R, H));
					break;
				case eColMeshShape.Cylinder:
					var _x  = buffer_read(temp_buff, buffer_f32);
					var _y  = buffer_read(temp_buff, buffer_f32);
					var _z  = buffer_read(temp_buff, buffer_f32);
					var xup = buffer_read(temp_buff, buffer_f32);
					var yup = buffer_read(temp_buff, buffer_f32);
					var zup = buffer_read(temp_buff, buffer_f32);
					var R   = buffer_read(temp_buff, buffer_f32);
					var H   = buffer_read(temp_buff, buffer_f32);
					add_shape(new colmesh_cylinder(_x, _y, _z, xup, yup, zup, R, H));
					break;
				case eColMeshShape.Torus:
					var _x  = buffer_read(temp_buff, buffer_f32);
					var _y  = buffer_read(temp_buff, buffer_f32);
					var _z  = buffer_read(temp_buff, buffer_f32);
					var xup = buffer_read(temp_buff, buffer_f32);
					var yup = buffer_read(temp_buff, buffer_f32);
					var zup = buffer_read(temp_buff, buffer_f32);
					var R   = buffer_read(temp_buff, buffer_f32);
					var r   = buffer_read(temp_buff, buffer_f32);
					add_shape(new colmesh_torus(_x, _y, _z, xup, yup, zup, R, r));
					break;
				case eColMeshShape.Cube:
					var _x    = buffer_read(temp_buff, buffer_f32);
					var _y    = buffer_read(temp_buff, buffer_f32);
					var _z    = buffer_read(temp_buff, buffer_f32);
					var halfW = buffer_read(temp_buff, buffer_f32);
					var halfL = buffer_read(temp_buff, buffer_f32);
					var halfH = buffer_read(temp_buff, buffer_f32);
					add_shape(new colmesh_cube(_x, _y, _z, halfW * 2, halfW * 2, halfH * 2));
					break;
				case eColMeshShape.Block:
					var M = array_create(16);
					M[0]  = buffer_read(temp_buff, buffer_f32);
					M[1]  = buffer_read(temp_buff, buffer_f32);
					M[2]  = buffer_read(temp_buff, buffer_f32);
					M[4]  = buffer_read(temp_buff, buffer_f32);
					M[5]  = buffer_read(temp_buff, buffer_f32);
					M[6]  = buffer_read(temp_buff, buffer_f32);
					M[8]  = buffer_read(temp_buff, buffer_f32);
					M[9]  = buffer_read(temp_buff, buffer_f32);
					M[10] = buffer_read(temp_buff, buffer_f32);
					M[12] = buffer_read(temp_buff, buffer_f32);
					M[13] = buffer_read(temp_buff, buffer_f32);
					M[14] = buffer_read(temp_buff, buffer_f32);
					M[15] = 1;
					add_shape(new colmesh_block(M));
					break;
				case eColMeshShape.None:
					//Dynamic shapes are NOT saved! This is a failsafe so that the order of objects added after the dynamic is kept.
					add_shape(new colmesh_none());
					break;
				case eColMeshShape.Dynamic:
					//Dynamic shapes are NOT saved! This is a failsafe so that the order of objects added after the dynamic is kept.
					add_shape(new colmesh_none());
					break;
			}
		}

		// Read subdivision
		var num = buffer_read(temp_buff, buffer_u32);
		if (num >= 0 and version == 3) {
			region_size = buffer_read(temp_buff, buffer_f32);
			origin_x	= buffer_read(temp_buff, buffer_f32);
			origin_y	= buffer_read(temp_buff, buffer_f32);
			origin_z	= buffer_read(temp_buff, buffer_f32);
			sp_hash = ds_map_create();
			repeat num {
				var region = ds_list_create();
				var key = buffer_read(temp_buff, buffer_u64);
				repeat buffer_read(temp_buff, buffer_u32) {
					var shape = shape_list[| buffer_read(temp_buff, buffer_u32)];
					if (is_struct(shape)) {
						if (shape.type == eColMeshShape.Dynamic or shape.type == eColMeshShape.None) {
							continue;
						}
					}
					ds_list_add(region, shape);
				}
				sp_hash[? key] = region;
			}
		}

		// Clean up and return result
		colmesh_debug_message("Script colmesh.read_from_buffer: Read colmesh from buffer in " + string(current_time - debugTime) + " milliseconds");
		buffer_delete(temp_buff);
		return true;
	}
	
	/// @function move(x, y, z)
	/// @description This does not make sense for a triangle, so we can just return false here
	static move = function(x, y, z) {
		return false;
	}
	
	/// @function get_regions(min_max)
	static get_regions = function(min_max) {
		static regs = array_create(6);
		regs[0] = floor((min_max[0] - origin_x) / region_size) - 1;
		regs[1] = floor((min_max[1] - origin_y) / region_size) - 1;
		regs[2] = floor((min_max[2] - origin_z) / region_size) - 1;
		regs[3] = floor((min_max[3] - origin_x) / region_size);
		regs[4] = floor((min_max[4] - origin_y) / region_size);
		regs[5] = floor((min_max[5] - origin_z) / region_size);
		return regs;
	}

	#endregion
}