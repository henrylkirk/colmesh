// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information
function colmesh_sphere_intersects_cube(x, y, z, R, hsize, bX, bY, bZ)
{
	var distSqr = R * R;
	var d = x - bX + hsize;
	if (d < 0)
	{
		distSqr -= d * d;
	}
	else
	{
		d = x - bX - hsize;
		if (d > 0)
		{
			distSqr -= d * d;
		}
	}
	d = y - bY + hsize;
	if (d < 0)
	{
		distSqr -= d * d;
	}
	else
	{
		d = y - bY - hsize;
		if (d > 0)
		{
			distSqr -= d * d;
		}
	}
	d = z - bZ + hsize;
	if (d < 0)
	{
		distSqr -= d * d;
	}
	else
	{
		d = z - bZ - hsize;
		if (d > 0)
		{
			distSqr -= d * d;
		}
	}
	return (distSqr > 0);
}

function colmesh_block_intersects_AABB(M, minx, miny, minz, maxx, maxy, maxz)
{
	static I = array_create(16);
	colmesh_matrix_invert_fast(M, I);
	
	//Find normalized block space position
	var b = matrix_transform_vertex(I, 
				clamp(M[12], minx, maxx),
				clamp(M[13], miny, maxy),
				clamp(M[14], minz, maxz));
	
	if (max(abs(b[0]), abs(b[1]), abs(b[2])) <= 1) return true;
		
	//Then check if the nearest point in the cube is inside the AABB
	var bX = (minx + maxx) * .5;
	var bY = (miny + maxy) * .5;
	var bZ = (minz + maxz) * .5;
	var sX = maxx - bX;
	var sY = maxy - bY;
	var sZ = maxz - bZ;
	var b = matrix_transform_vertex(I, bX, bY, bZ);
	var p = matrix_transform_vertex(M, 
				clamp(b[0], -1, 1), 
				clamp(b[1], -1, 1), 
				clamp(b[2], -1, 1));
				
	if (max(abs(p[0] - bX) / sX, abs(p[1] - bY) / sY, abs(p[2] - bZ) / sZ) <= 1) return true;
	
	return false;
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
	vertNum = ds_list_size(F);
	mbuff = buffer_create(vertNum * cmBytesPerVert, buffer_fixed, 1);
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
	return string(x) + "," + string(y) + "," + string(z);
	
	//Returns a unique hash for any 3D integer position
	//Based on the algorithm described here:
	//	https://dmauro.com/post/77011214305/a-hashing-function-for-x-y-z-coordinates
	
    x = (x >= 0) ? 2 * x : - 2 * x - 1;
    y = (y >= 0) ? 2 * y : - 2 * y - 1;
    z = (z >= 0) ? 2 * z : - 2 * z - 1;
	
    var m = max(x, y, z)
    var hash = m * m * m + 2 * m * z + z;
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
    return hash;
}

function colmesh__region_capsule_collision(region, x, y, z, xup, yup, zup, radius, height)
{
	//Returns whether or not the given capsule collides with the given region
	if (is_undefined(region))
	{
		return false;
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