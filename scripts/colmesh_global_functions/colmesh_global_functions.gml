
function colmesh_capsule_get_aabb(x, y, z, xup, yup, zup, radius, height)
{
	static AABB = array_create(6);
	xup *= height;
	yup *= height;
	zup *= height;
	AABB[0] = x + min(xup, 0) - radius;
	AABB[1] = y + min(yup, 0) - radius;
	AABB[2] = z + min(zup, 0) - radius;
	AABB[3] = x + max(xup, 0) + radius;
	AABB[4] = y + max(yup, 0) + radius;
	AABB[5] = z + max(zup, 0) + radius;
	return AABB;
}
function colmesh_debug_message(str)
{
	//Only show debug messages if CM_DEBUG is set to true
	if CM_DEBUG
	{
		show_debug_message(str);
	}
}

function colmesh_load_obj_to_buffer(filename) 
{
	static read_face = function(faceList, str) 
	{
		gml_pragma("forceinline");
		str = string_delete(str, 1, string_pos(" ", str))
		if (string_char_at(str, string_length(str)) == " ")
		{
			//Make sure the string doesn't end with an empty space
			str = string_copy(str, 0, string_length(str) - 1);
		}
		var triNum = string_count(" ", str);
		var vertString = array_create(triNum + 1);
		for (var i = 0; i < triNum; i ++)
		{
			//Add vertices in a triangle fan
			vertString[i] = string_copy(str, 1, string_pos(" ", str));
			str = string_delete(str, 1, string_pos(" ", str));
		}
		vertString[i--] = str;
		while i--
		{
			for (var j = 2; j >= 0; j --)
			{
				var vstr = vertString[(i + j) * (j > 0)];
				var v = 0, n = 0, t = 0;
				//If the vertex contains a position, texture coordinate and normal
				if string_count("/", vstr) == 2 and string_count("//", vstr) == 0
				{
					v = abs(real(string_copy(vstr, 1, string_pos("/", vstr) - 1)));
					vstr = string_delete(vstr, 1, string_pos("/", vstr));
					t = abs(real(string_copy(vstr, 1, string_pos("/", vstr) - 1)));
					n = abs(real(string_delete(vstr, 1, string_pos("/", vstr))));
				}
				//If the vertex contains a position and a texture coordinate
				else if string_count("/", vstr) == 1
				{
					v = abs(real(string_copy(vstr, 1, string_pos("/", vstr) - 1)));
					t = abs(real(string_delete(vstr, 1, string_pos("/", vstr))));
				}
				//If the vertex only contains a position
				else if (string_count("/", vstr) == 0)
				{
					v = abs(real(vstr));
				}
				//If the vertex contains a position and normal
				else if string_count("//", vstr) == 1
				{
					vstr = string_replace(vstr, "//", "/");
					v = abs(real(string_copy(vstr, 1, string_pos("/", vstr) - 1)));
					n = abs(real(string_delete(vstr, 1, string_pos("/", vstr))));
				}
				ds_list_add(faceList, [v-1, n-1, t-1]);
			}
		}
	}
	static read_line = function(str) 
	{
		gml_pragma("forceinline");
		str = string_delete(str, 1, string_pos(" ", str));
		var retNum = string_count(" ", str) + 1;
		var ret = array_create(retNum);
		for (var i = 0; i < retNum; i ++)
		{
			var pos = string_pos(" ", str);
			if (pos == 0)
			{
				pos = string_length(str);
				ret[i] = real(string_copy(str, 1, pos)); 
				break;
			}
			ret[i] = real(string_copy(str, 1, pos)); 
			str = string_delete(str, 1, pos);
		}
		return ret;
	}
	var file = file_text_open_read(filename);
	if (file == -1){colmesh_debug_message("Failed to load model " + string(filename)); return -1;}
	colmesh_debug_message("Script colmesh_load_obj_to_buffer: Loading obj file " + string(filename));

	//Create the necessary lists
	var V = ds_list_create();
	var N = ds_list_create();
	var T = ds_list_create();
	var F = ds_list_create();

	//Read .obj as textfile
	var str, type;
	while !file_text_eof(file)
	{
		str = string_replace_all(file_text_read_string(file),"  "," ");
		//Different types of information in the .obj starts with different headers
		switch string_copy(str, 1, string_pos(" ", str)-1)
		{
			//Load vertex positions
			case "v":
				ds_list_add(V, read_line(str));
				break;
			//Load vertex normals
			case "vn":
				ds_list_add(N, read_line(str));
				break;
			//Load vertex texture coordinates
			case "vt":
				ds_list_add(T, read_line(str));
				break;
			//Load faces
			case "f":
				read_face(F, str);
				break;
		}
		file_text_readln(file);
	}
	file_text_close(file);

	//Loop through the loaded information and generate a model
	var vnt, vertNum, mbuff, vbuff, v, n, t;
	var bytesPerVert = 3 * 4 + 3 * 4 + 2 * 4 + 4 * 1;
	vertNum = ds_list_size(F);
	mbuff = buffer_create(vertNum * bytesPerVert, buffer_fixed, 1);
	for (var f = 0; f < vertNum; f ++)
	{
		vnt = F[| f];
		
		//Add the vertex to the model buffer
		v = V[| vnt[0]];
		if !is_array(v){v = [0, 0, 0];}
		buffer_write(mbuff, buffer_f32, v[0]);
		buffer_write(mbuff, buffer_f32, v[2]);
		buffer_write(mbuff, buffer_f32, v[1]);
		
		n = N[| vnt[1]];
		if !is_array(n){n = [0, 0, 1];}
		buffer_write(mbuff, buffer_f32, n[0]);
		buffer_write(mbuff, buffer_f32, n[2]);
		buffer_write(mbuff, buffer_f32, n[1]);
		
		t = T[| vnt[2]];
		if !is_array(t){t = [0, 0];}
		buffer_write(mbuff, buffer_f32, t[0]);
		buffer_write(mbuff, buffer_f32, 1-t[1]);
		
		buffer_write(mbuff, buffer_u8, 255);
		buffer_write(mbuff, buffer_u8, 255);
		buffer_write(mbuff, buffer_u8, 255);
		buffer_write(mbuff, buffer_u8, 255);
	}
	ds_list_destroy(F);
	ds_list_destroy(V);
	ds_list_destroy(N);
	ds_list_destroy(T);
	colmesh_debug_message("Script colmesh_load_obj_to_buffer: Successfully loaded obj " + string(filename));
	return mbuff
}

function colmesh_convert_smf(model)
{
	//This script was requested by somebody on the forums.
	//Creates a ColMesh-compatible buffer from an SMF model.
	//Remember to destroy the buffer after you're done using it!
	var mBuff = model.mBuff;
	var num = array_length(mBuff);
	
	var newBuff = buffer_create(1, buffer_grow, 1);
	var size = 0;
	
	//Convert to ColMesh-compatible format
	var num = array_length(mBuff);
	var SMFbytesPerVert = 44;
	var targetBytesPerVert = 36;
	for (var m = 0; m < num; m ++)
	{
		var buff = mBuff[m];
		var buff_size = buffer_get_size(buff);
		var vertNum = buff_size div SMFbytesPerVert;
		for (var i = 0; i < vertNum; i ++)
		{
			//Copy position and normal
			buffer_copy(buff, i * SMFbytesPerVert, targetBytesPerVert, newBuff, size + i * targetBytesPerVert);
		}
		size += buff_size * targetBytesPerVert / SMFbytesPerVert;
	}
	
	buffer_resize(newBuff, size);
	return newBuff;
}
	
function colmesh_get_key(x, y, z)
{
	//Returns a unique hash for any 3D integer position
	//Based on the algorithm described here:
	//	https://dmauro.com/post/77011214305/a-hashing-function-for-x-y-z-coordinates
    x = (x >= 0) ? 2 * x : - 2 * x - 1;
    y = (y >= 0) ? 2 * y : - 2 * y - 1;
    z = (z >= 0) ? 2 * z : - 2 * z - 1;
	
    var m = max(x, y, z)
    var hash = m * m * m + 2 * m * z + z
    if (m == z)
	{
        hash += sqr(max(x, y));
	}
    if (y >= x)
	{
        hash += x + y;
	}
    else
	{
        hash += y;
	}
    return hash
}


/// @function colmesh__addUnique(target, source)
function colmesh__addUnique(r1, r2)
{
	//Adds the unique list entries from source to target list
	if (ds_list_size(r1) == 0)
	{	
		//The target list is empty. Copy over the contents of r2 and call it a day
		ds_list_copy(r1, r2);
		return true;
	}
	var i = ds_list_size(r2);
	repeat i
	{
		var shapeInd = r2[| --i];
		if (ds_list_find_index(r1, shapeInd) < 0)
		{
			ds_list_add(r1, shapeInd);
		}
	}
	return true;
}
	
/// @function colmesh_displace(nx, ny, nz, xup, yup, zup, r, slope)
function colmesh_displace(nx, ny, nz, xup, yup, zup, _r, slope)
{
	/*
		A supplementary function, not meant to be used by itself.
		Displaces a sphere.
	*/
	gml_pragma("forceinline");
	var dp = nx * xup + ny * yup + nz * zup;
	if (dp > CM_COL[6])
	{
		CM_COL[@ 3] = nx;
		CM_COL[@ 4] = ny;
		CM_COL[@ 5] = nz;
		CM_COL[@ 6] = dp;
	}
	if (dp >= slope)
	{ 
		//Prevent sliding
		_r /= dp;
		CM_COL[@ 0] += xup * _r;
		CM_COL[@ 1] += yup * _r;
		CM_COL[@ 2] += zup * _r;
	}
	else
	{
		CM_COL[@ 0] += nx * _r;
		CM_COL[@ 1] += ny * _r;
		CM_COL[@ 2] += nz * _r;
	}
}

/// @function colmesh__triangle_cast_ray(triangle, ox, oy, oz)
function colmesh__triangle_cast_ray(triangle, ox, oy, oz)
{
	/*
		A supplementary function, not meant to be used by itself.
		Used by colmesh.cast_ray
	*/
	gml_pragma("forceinline");
	var dx = CM_RAY[0] - ox;
	var dy = CM_RAY[1] - oy;
	var dz = CM_RAY[2] - oz;
	var nx = triangle[9];
	var ny = triangle[10];
	var nz = triangle[11];
	var h = dot_product_3d(dx, dy, dz, nx, ny, nz);
	if (h == 0){return false;} //Continue if the ray is parallel to the surface of the triangle (ie. perpendicular to the triangle's normal)
	var v1x = triangle[0];
	var v1y = triangle[1];
	var v1z = triangle[2];
	var h = dot_product_3d(v1x - ox, v1y - oy, v1z - oz, nx, ny, nz) / h;
	if (h < 0 or h > 1){return false;} //Continue if the intersection is too far behind or in front of the ray
	var itsX = ox + dx * h;
	var itsY = oy + dy * h;
	var itsZ = oz + dz * h;

	//Check first edge
	var v2x = triangle[3];
	var v2y = triangle[4];
	var v2z = triangle[5];
	var ax = itsX - v1x;
	var ay = itsY - v1y;
	var az = itsZ - v1z;
	var bx = v2x - v1x;
	var by = v2y - v1y;
	var bz = v2z - v1z;
	var cx = az * by - ay * bz;
	var cy = ax * bz - az * bx;
	var cz = ay * bx - ax * by;
	var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
	if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
	if (dp == 0)
	{
		var t = dot_product_3d(ax, ay, az, bx, by, bz);
		if (t < 0 or t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
	}
	
	//Check second edge
	var v3x = triangle[6];
	var v3y = triangle[7];
	var v3z = triangle[8];
	var ax = itsX - v2x;
	var ay = itsY - v2y;
	var az = itsZ - v2z;
	var bx = v3x - v2x;
	var by = v3y - v2y;
	var bz = v3z - v2z;
	var cx = az * by - ay * bz;
	var cy = ax * bz - az * bx;
	var cz = ay * bx - ax * by;
	var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
	if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
	if (dp == 0)
	{
		var t = dot_product_3d(ax, ay, az, bx, by, bz);
		if (t < 0 or t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
	}
	
	//Check third edge
	var ax = itsX - v3x;
	var ay = itsY - v3y;
	var az = itsZ - v3z;
	var bx = v1x - v3x;
	var by = v1y - v3y;
	var bz = v1z - v3z;
	var cx = az * by - ay * bz;
	var cy = ax * bz - az * bx;
	var cz = ay * bx - ax * by;
	var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
	if (dp < 0){return false;} //Continue if the intersection is outside this edge of the triangle
	if (dp == 0)
	{
		var t = dot_product_3d(ax, ay, az, bx, by, bz);
		if (t < 0 or t > dot_product_3d(bx, by, bz, bx, by, bz)){return false;} //Intersection is perfectly on this triangle edge. Continue if outside triangle.
	}
	
	//The line intersects the triangle. Save the triangle normal and intersection.
	var s = sign(h);
	CM_RAY[0] = itsX;
	CM_RAY[1] = itsY;
	CM_RAY[2] = itsZ;
	CM_RAY[3] = nx * s;
	CM_RAY[4] = ny * s;
	CM_RAY[5] = nz * s;
	CM_RAY[6] = triangle;
	return true;
}	

/// @function colmesh__triangle_displace_sphere(triangle, x, y, z, xup, yup, zup, height, radius, slope, fast)
function colmesh__triangle_displace_sphere(triangle, x, y, z, xup, yup, zup, height, radius, slope, fast)
{
	/*
		A supplementary function, not meant to be used by itself.
		Pushes a sphere out of the shape by changing the global array CM_COL
		Returns true if there was a collision.
	*/
	gml_pragma("forceinline");
		
	//Check first edge
	var nx = triangle[9];
	var ny = triangle[10];
	var nz = triangle[11];
	var v1x = triangle[0];
	var v1y = triangle[1];
	var v1z = triangle[2];
	var t0 = x - v1x;
	var t1 = y - v1y;
	var t2 = z - v1z;
	var D = dot_product_3d(t0, t1, t2, nx, ny, nz);
	if (abs(D) > radius)
	{
		return false;
	}
	var v2x = triangle[3];
	var v2y = triangle[4];
	var v2z = triangle[5];
	var u0 = v2x - v1x;
	var u1 = v2y - v1y;
	var u2 = v2z - v1z;
	var cx = t2 * u1 - t1 * u2;
	var cy = t0 * u2 - t2 * u0;
	var cz = t1 * u0 - t0 * u1;
	var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
	if (dp < 0)
	{
		var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
		var _nx = t0 - u0 * a;
		var _ny = t1 - u1 * a;
		var _nz = t2 - u2 * a;
		var d = colmesh_vector_magnitude(_nx, _ny, _nz);
		if (d <= 0 or d > radius){return false;}
		colmesh_displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
		return true;
	}
	else
	{
		//Check second edge
		var v3x = triangle[6];
		var v3y = triangle[7];
		var v3z = triangle[8];
		var t0 = x - v2x;
		var t1 = y - v2y;
		var t2 = z - v2z;
		var u0 = v3x - v2x;
		var u1 = v3y - v2y;
		var u2 = v3z - v2z;
		var cx = t2 * u1 - t1 * u2;
		var cy = t0 * u2 - t2 * u0;
		var cz = t1 * u0 - t0 * u1;
		var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
		if (dp < 0)
		{
			var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
			var _nx = t0 - u0 * a;
			var _ny = t1 - u1 * a;
			var _nz = t2 - u2 * a;
			var d = colmesh_vector_magnitude(_nx, _ny, _nz);
			if (d <= 0 or d > radius){return false;}
			colmesh_displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
			return true;
		}
		else
		{
			//Check third edge
			var t0 = x - v3x;
			var t1 = y - v3y;
			var t2 = z - v3z;
			var u0 = v1x - v3x;
			var u1 = v1y - v3y;
			var u2 = v1z - v3z;
			var cx = t2 * u1 - t1 * u2;
			var cy = t0 * u2 - t2 * u0;
			var cz = t1 * u0 - t0 * u1;
			var dp = dot_product_3d(cx, cy, cz, nx, ny, nz);
			if (dp < 0)
			{
				var a = clamp(dot_product_3d(u0, u1, u2, t0, t1, t2) / dot_product_3d(u0, u1, u2, u0, u1, u2), 0, 1);
				var _nx = t0 - u0 * a;
				var _ny = t1 - u1 * a;
				var _nz = t2 - u2 * a;
				var d = colmesh_vector_magnitude(_nx, _ny, _nz);
				if (d <= 0 or d > radius){return false;}
				colmesh_displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
				return true;
			}
		}
	}
	var s = sign(D);
	colmesh_displace(nx * s, ny * s, nz * s, xup, yup, zup, radius - abs(D), slope);
	return true;
}


function colmesh_region_cast_ray(region, x1, y1, z1, x2, y2, z2, _executeRayFunc)
{
	//This ray casting script is faster than the regular colmesh raycasting script.
	//However, it will only cast a ray onto the shapes in the current region, and is as such a "short-range" ray.
	//If there was an intersection, it returns an array with the following format:
	//	[x, y, z, nX, nY, nZ, success]
	//Returns false if there was no intersection.
	var success = false;
	if (is_undefined(region) or (x1 == x2 and y1 == y2 and z1 == z2))
	{
		return false;
	}
	if (CM_RECURSION >= CM_MAX_RECURSION)
	{
		//Exit the script if we've reached the recursive limit
		return false;
	}
	if (CM_RECURSION == 0 and CM_CALLING_OBJECT < 0)
	{
		CM_CALLING_OBJECT = other;
	}
	var executeRayFunc = (is_undefined(_executeRayFunc) ? false : _executeRayFunc);
		
	//Store the end position in the global CM_RAY array
	CM_RAY[0] = x2;
	CM_RAY[1] = y2;
	CM_RAY[2] = z2;
	CM_RAY[6] = -1; //The sixth index will store the struct the ray has collided with. Initialize to -1.
		
	//Loop through the shapes in the region
	var i = ds_list_size(region);
	repeat i
	{
		var shape = get_shape(region[| -- i])
		static temp = array_create(7);
		if (!shape.solid)
		{
			array_copy(temp, 0, CM_RAY, 0, 7);
		}
		++ CM_RECURSION;
		var ray = shape.cast_ray(x1, y1, z1);
		-- CM_RECURSION;
		if (ray)
		{
			if (shape.type == eColMeshShape.Trigger)
			{
				if (executeRayFunc and is_method(shape.rayFunc))
				{
					shape.rayFunc();
				}
			}
			if (!shape.solid)
			{
				//This shape is not solid. The ray should continue!
				array_copy(CM_RAY, 0, temp, 0, 7);
				continue;
			}
			success = true;
		}
	}
	if (CM_RECURSION == 0)
	{
		CM_CALLING_OBJECT = -1;
	}
	if (success)
	{
		return CM_RAY;
	}
	return false;
}


function colmesh_region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height)
{
	//Returns whether or not the given capsule collides with the given region
	if (is_undefined(region))
	{
		CM_COL[0] = x;
		CM_COL[1] = y;
		CM_COL[2] = z;
		CM_COL[6] = false;
		return CM_COL;
	}
	if (CM_RECURSION >= CM_MAX_RECURSION)
	{
		return false;
	}
	var i = ds_list_size(region);
	repeat (i)
	{
		++ CM_RECURSION;
		var col = get_shape(region[| --i]).capsule_collision(x, y, z, xup, yup, zup, radius, height);
		-- CM_RECURSION;
		if (col) return true;
	}
	return false;
}