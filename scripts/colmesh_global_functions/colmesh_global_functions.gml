// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function colmesh_collision_result(x, y, z, nx, ny, nz) constructor
{
	static reset = function(_x, _y, _z, _nx, _ny, _nz)
	{
		x = _x;
		y = _y;
		z = _z;
		nx = _nx;
		ny = _ny;
		nz = _nz;
		maxdp = -1;
		struct = -1;
		ground = false;
		collision = false;
	}
	static clearTransforms = function()
	{
		transformQueue = [];
	}
	
	reset(x, y, z, nx, ny, nz);
	clearTransforms();
	
	static getDeltaMatrix = function()
	{
		//This is useful for getting the change in orientation in those cases where the player is standing on a dynamic shape.
		//If the player stands on a dynamic shape, its matrix and the inverse of its previous matrix are saved to that queue. This is done in colmesh_dynamic._displaceSphere.
		//If the dynamic shape is inside multiple layers of colmeshes, their matrices and inverse previous matrices are also added to the queue.
		//These matrices are all multiplied together in this function, resulting in their combined movements gathered in a single matrix.
			
		//Typical usage for making the player move:
		//	var D = levelColmesh.getDeltaMatrix();
		//	if (is_array(D))
		//	{
		//		var p = matrix_transform_vertex(D, x, y, z);
		//		x = p[0];
		//		y = p[1];
		//		z = p[2];
		//	}
				
		//And for transforming a vector:
		//	var D = levelColmesh.getDeltaMatrix();
		//	if (is_array(D))
		//	{
		//		var p = matrix_transform_vector(D, xto, yto, zto);
		//		xto = p[0];
		//		yto = p[1];
		//		zto = p[2];
		//	}
			
		//And for transforming a matrix:
		//	var D = levelColmesh.getDeltaMatrix();
		//	if (is_array(D))
		//	{
		//		colmesh_matrix_multiply_fast(D, targetMatrix, targetMatrix);
		//	}
		var num = array_length(transformQueue);
		var i = 0;
		if (num > 1)
		{
			//The first two matrices can simply be multiplied together
			var M = transformQueue[i++]; //The current world matrix
			var pI = transformQueue[i++]; //The inverse of the previous world matrix
			var m = matrix_multiply(pI, M);
			repeat (num / 2 - 1)
			{
				//The subsequent matrices need to be multiplied with the target matrix in the correct order
				M = transformQueue[i++]; //The current world matrix
				pI = transformQueue[i++]; //The inverse of the previous world matrix
				m = matrix_multiply(matrix_multiply(pI, m), M);
			}
			return m;
		}
		return false;
	}
}

function colmesh_raycast_result(x, y, z, nx, ny, nz, hit, struct) constructor
{
	self.x = x;
	self.y = y;
	self.z = z;
	self.nx = nx;
	self.ny = ny;
	self.nz = nz;
	self.hit = hit;
	self.struct = struct;
}

function colmesh_capsule_get_AABB(x, y, z, xup, yup, zup, radius, height)
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
	//Only show debug messages if cmDebug is set to true
	if cmDebug
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
		var buffSize = buffer_get_size(buff);
		var vertNum = buffSize div SMFbytesPerVert;
		for (var i = 0; i < vertNum; i ++)
		{
			//Copy position and normal
			buffer_copy(buff, i * SMFbytesPerVert, targetBytesPerVert, newBuff, size + i * targetBytesPerVert);
		}
		size += buffSize * targetBytesPerVert / SMFbytesPerVert;
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
	
/// @func colmesh__displace(nx, ny, nz, xup, yup, zup, r, slope)
function colmesh__displace(nx, ny, nz, xup, yup, zup, _r, slope)
{
	/*
		A supplementary function, not meant to be used by itself.
		Displaces a sphere.
	*/
	gml_pragma("forceinline");
	var dp = nx * xup + ny * yup + nz * zup;
	if (dp > cmCol.maxdp)
	{
		cmCol.nx = nx;
		cmCol.ny = ny;
		cmCol.nz = nz;
		cmCol.maxdp = dp;
	}
	if (dp >= slope)
	{ 
		//Prevent sliding
		_r /= dp;
		cmCol.x += xup * _r;
		cmCol.y += yup * _r;
		cmCol.z += zup * _r;
		cmCol.ground = true;
	}
	else
	{
		cmCol.x += nx * _r;
		cmCol.y += ny * _r;
		cmCol.z += nz * _r;
	}
}

/// @func colmesh__triangle_displace_sphere(triangle, x, y, z, xup, yup, zup, height, radius, slope, fast)
function colmesh__triangle_displace_sphere(triangle, x, y, z, xup, yup, zup, height, radius, slope, fast)
{
	/*
		A supplementary function, not meant to be used by itself.
		Pushes a sphere out of the shape by changing the global array cmCol
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
	var D = cmDot(t0, t1, t2, nx, ny, nz);
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
	var dp = cmDot(cx, cy, cz, nx, ny, nz);
	if (dp < 0)
	{
		var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
		var _nx = t0 - u0 * a;
		var _ny = t1 - u1 * a;
		var _nz = t2 - u2 * a;
		var d = cmDist(0, 0, 0, _nx, _ny, _nz);
		if (d <= 0 || d > radius){return false;}
		colmesh__displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
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
		var dp = cmDot(cx, cy, cz, nx, ny, nz);
		if (dp < 0)
		{
			var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
			var _nx = t0 - u0 * a;
			var _ny = t1 - u1 * a;
			var _nz = t2 - u2 * a;
			var d = cmDist(0, 0, 0, _nx, _ny, _nz);
			if (d <= 0 || d > radius){return false;}
			colmesh__displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
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
			var dp = cmDot(cx, cy, cz, nx, ny, nz);
			if (dp < 0)
			{
				var a = clamp(cmDot(u0, u1, u2, t0, t1, t2) / cmDot(u0, u1, u2, u0, u1, u2), 0, 1);
				var _nx = t0 - u0 * a;
				var _ny = t1 - u1 * a;
				var _nz = t2 - u2 * a;
				var d = cmDist(0, 0, 0, _nx, _ny, _nz);
				if (d <= 0 || d > radius){return false;}
				colmesh__displace(_nx / d, _ny / d, _nz / d, xup, yup, zup, radius - d, slope);
				return true;
			}
		}
	}
	var s = sign(D);
	colmesh__displace(nx * s, ny * s, nz * s, xup, yup, zup, radius - abs(D), slope);
	return true;
}


function colmesh__region_cast_ray(region, ray, executeRayFunc = false)
{
	//This ray casting script is faster than the regular colmesh raycasting script.
	//However, it will only cast a ray onto the shapes in the current region, and is as such a "short-range" ray.
	//If there was an intersection, it returns an array with the following format:
	//	[x, y, z, nX, nY, nZ, success]
	//Returns false if there was no intersection.
	var success = false;
	if (is_undefined(region) || (ray[0] == ray[3] && ray[1] == ray[4] && ray[2] == ray[5]))
	{
		return false;
	}
	if (cmRecursion >= cmMaxRecursion)
	{
		//Exit the script if we've reached the recursive limit
		return false;
	}
	if (cmRecursion == 0 && cmCallingObject < 0)
	{
		cmCallingObject = other;
	}
		
	//Loop through the shapes in the region
	var firstHit = -1;
	var i = ds_list_size(region);
	repeat i
	{
		var shape = _getShape(region[| -- i])
		static temp = array_create(7);
		++ cmRecursion;
		var hit = shape._castRay(ray);
		-- cmRecursion;
		if (is_struct(hit))
		{
			if (shape.type == eColMeshShape.Trigger)
			{
				if (executeRayFunc && is_method(shape.rayFunc))
				{
					shape.rayFunc();
				}
			}
			if (!shape.solid)
			{
				//This shape is not solid. The ray should continue!
				continue;
			}
			ray[3] = hit.x;
			ray[4] = hit.y;
			ray[5] = hit.z;
			firstHit = hit;
			success = true;
		}
	}
	if (cmRecursion == 0)
	{
		cmCallingObject = -1;
	}
	if (is_struct(firstHit))
	{
		return firstHit;
	}
	return false;
}


function colmesh__region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height)
{
	//Returns whether or not the given capsule collides with the given region
	if (is_undefined(region))
	{
		cmCol[0] = x;
		cmCol[1] = y;
		cmCol[2] = z;
		cmCol[6] = false;
		return cmCol;
	}
	if (cmRecursion >= cmMaxRecursion)
	{
		return false;
	}
	var i = ds_list_size(region);
	repeat (i)
	{
		++ cmRecursion;
		var col = _getShape(region[| --i]).capsuleCollision(x, y, z, xup, yup, zup, radius, height);
		-- cmRecursion;
		if (col) return true;
	}
	return false;
}

/// @func colmesh_convert_2d_to_3d(cameraIndex, x, y)
function colmesh_convert_2d_to_3d(cameraIndex, _x, _y) {
	/*
		Transforms a 2D coordinate (in window space) to a 3D vector.
		Returns an array of the following format:
		[dx, dy, dz, ox, oy, oz]
		where [dx, dy, dz] is the direction vector and [ox, oy, oz] is the origin of the ray.

		Works for both orthographic and perspective projections.

		Script created by TheSnidr
	*/
	var V = camera_get_view_mat(cameraIndex);
	var P = camera_get_proj_mat(cameraIndex);

	var mx = 2 * (_x / window_get_width()  - .5) / P[0];
	var my = 2 * (_y / window_get_height() - .5) / P[5];
	var camX = - (V[12] * V[0] + V[13] * V[1] + V[14] * V[2]);
	var camY = - (V[12] * V[4] + V[13] * V[5] + V[14] * V[6]);
	var camZ = - (V[12] * V[8] + V[13] * V[9] + V[14] * V[10]);

	if (P[15] == 0) 
	{    //This is a perspective projection
	    return [V[2]  + mx * V[0] - my * V[1], 
	            V[6]  + mx * V[4] - my * V[5], 
	            V[10] + mx * V[8] - my * V[9], 
	            camX, 
	            camY, 
	            camZ];
	}
	else 
	{    //This is an ortho projection
	    return [V[2], 
	            V[6], 
	            V[10], 
	            camX + mx * V[0] - my * V[1], 
	            camY + mx * V[4] - my * V[5], 
	            camZ + mx * V[8] - my * V[9]];
	}
}