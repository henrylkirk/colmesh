/*
	Some math scripts that are used by the ColMesh system.
*/
#macro cmDot dot_product_3d
#macro cmSqr colmesh_vector_square
#macro cmDist point_distance_3d

/// @func colmesh_vector_square(x, y, z)
function colmesh_vector_square(x, y, z)
{
	//Returns the square of the magnitude of the given vector
	return dot_product_3d(x, y, z, x, y, z);
}

function colmesh_matrix_transpose(M)
{
	return [M[0], M[4], M[8],  M[12],
			M[1], M[5], M[9],  M[13],
			M[2], M[6], M[10], M[14],
			M[3], M[7], M[11], M[15]];
}

/// @func colmesh_matrix_invert_fast(M, targetM*)
function colmesh_matrix_invert_fast(M, I = array_create(16)) 
{
	//Returns the inverse of a 4x4 matrix. Assumes indices 3, 7 and 11 are 0, and index 15 is 1
	//With this assumption a lot of factors cancel out
	var m0 = M[0], m1 = M[1], m2 = M[2], m4 = M[4], m5 = M[5], m6 = M[6], m8 = M[8], m9 = M[9], m10 = M[10], m12 = M[12], m13 = M[13], m14 = M[14];
	var i0  =   m5 * m10 -  m9 * m6;
	var i4  =   m8 * m6  -  m4 * m10;
	var i8  =   m4 * m9  -  m8 * m5;
	var det =   dot_product_3d(m0, m1, m2, i0, i4, i8);
	if (det == 0)
	{
		show_debug_message("Error in function colmesh_matrix_invert_fast: The determinant is zero.");
		return M;
	}
	var invDet = 1 / det;
	I[@ 0]  =   invDet * i0;
	I[@ 1]  =   invDet * (m9 * m2  - m1 * m10);
	I[@ 2]  =   invDet * (m1 * m6  - m5 * m2);
	I[@ 3]  =   0;
	I[@ 4]  =   invDet * i4;
	I[@ 5]  =   invDet * (m0 * m10 - m8 * m2);
	I[@ 6]  =   invDet * (m4 * m2  - m0 * m6);
	I[@ 7]  =   0;
	I[@ 8]  =   invDet * i8;
	I[@ 9]  =   invDet * (m8 * m1  - m0 * m9);
	I[@ 10] =   invDet * (m0 * m5  - m4 * m1);
	I[@ 11] =   0;
	I[@ 12] = - dot_product_3d(m12, m13, m14, I[0], I[4], I[8]);
	I[@ 13] = - dot_product_3d(m12, m13, m14, I[1], I[5], I[9]);
	I[@ 14] = - dot_product_3d(m12, m13, m14, I[2], I[6], I[10]);
	I[@ 15] =   dot_product_3d(m8,  m9,  m10, I[2], I[6], I[10]);
	return I;
}

/// @func colmesh_matrix_invert(M, targetM*)
function colmesh_matrix_invert(M, I = array_create(16))
{
	//Proper matrix inversion
	var m0 = M[0], m1 = M[1], m2 = M[2], m3 = M[3], m4 = M[4], m5 = M[5], m6 = M[6], m7 = M[7], m8 = M[8], m9 = M[9], m10 = M[10], m11 = M[11], m12 = M[12], m13 = M[13], m14 = M[14], m15 = M[15];
	var a   = m5 * m10 - m9 * m6;
	var d   = m8 * m6  - m4 * m10;
	var g   = m4 * m9  - m8 * m5;
	var j   = m6 * m11 - m7 * m10;
	var m   = m9 * m7  - m5 * m11;
	var p   = m4 * m11 - m8 * m7;
	var i0  = dot_product_3d(m13,  m14,  m15,  j,  m,  a);
	var i4  = dot_product_3d(m12,  m14,  m15, -j,  p,  d);
	var i8  = dot_product_3d(m12,  m13,  m15, -m, -p,  g);
	var i12 = dot_product_3d(m12,  m13,  m14, -a, -d, -g);
	var det =   m0 * i0 + m1 * i4 + m2 * i8 + m3 * i12;
	if (det == 0){
		show_debug_message("Error in function colmesh_matrix_invert: The determinant is zero.");
		return M;
	}
	var b   = m9 * m2  - m1 * m10;
	var c   = m1 * m6  - m5 * m2;
	var e   = m0 * m10 - m8 * m2;
	var f   = m4 * m2  - m0 * m6;
	var h   = m8 * m1  - m0 * m9;
	var i   = m0 * m5  - m4 * m1;
	var k   = m3 * m10 - m2 * m11;
	var l   = m2 * m7  - m3 * m6;
	var n   = m1 * m11 - m9 * m3;
	var o   = m5 * m3  - m1 * m7;
	var q   = m8 * m3  - m0 * m11;
	var r   = m0 * m7  - m4 * m3;
	var invDet = 1 / det;
	I[@ 0]  = invDet * i0;
	I[@ 1]  = invDet * dot_product_3d(m13, m14, m15,  k,  n,  b);
	I[@ 2]  = invDet * dot_product_3d(m13, m14, m15,  l,  o,  c);
	I[@ 3]  = invDet * dot_product_3d(m3,  m7,  m11, -a, -b, -c);
	I[@ 4]  = invDet * i4;
	I[@ 5]  = invDet * dot_product_3d(m12, m14, m15, -k,  q,  e);
	I[@ 6]  = invDet * dot_product_3d(m12, m14, m15, -l,  r,  f);
	I[@ 7]  = invDet * dot_product_3d(m3,  m7,  m11, -d, -e, -f);
	I[@ 8]  = invDet * i8;
	I[@ 9]  = invDet * dot_product_3d(m12, m13, m15, -n, -q,  h);
	I[@ 10] = invDet * dot_product_3d(m12, m13, m15, -o, -r,  i);
	I[@ 11] = invDet * dot_product_3d(m3,  m7,  m11, -g, -h, -i);
	I[@ 12] = invDet * i12;
	I[@ 13] = invDet * dot_product_3d(m12, m13, m14, -b, -e, -h);
	I[@ 14] = invDet * dot_product_3d(m12, m13, m14, -c, -f, -i);
	I[@ 15] = invDet * dot_product_3d(m0,  m4,  m8,   a,  b,  c);
	return I;
}

function colmesh_matrix_build(x, y, z, xrotation, yrotation, zrotation, xscale, yscale, zscale)
{
	/*
		This is an alternative to the regular matrix_build.
		The regular function will rotate first and then scale, which can result in weird shearing.
		I have no idea why they did it this way.
		This script does it properly so that no shearing is applied even if you both rotate and scale non-uniformly.
	*/
	var M = matrix_build(x, y, z, xrotation, yrotation, zrotation, 1, 1, 1);
	return colmesh_matrix_scale(M, xscale, yscale, zscale);
}

function colmesh_matrix_orthogonalize(M)
{
	/*
		This makes sure the three vectors of the given matrix are all unit length
		and perpendicular to each other, using the up direction as master.
		GameMaker does something similar when creating a lookat matrix. People often use [0, 0, 1]
		as the up direction, but this vector is not used directly for creating the view matrix; rather, 
		it's being used as reference, and the entire view matrix is being orthogonalized to the looking direction.
	*/
	var l = point_distance_3d(0, 0, 0, M[8], M[9], M[10]);
	if (l != 0)
	{
		l = 1 / l;
		M[@ 8]  *= l;
		M[@ 9]  *= l;
		M[@ 10] *= l;
	}
	else
	{
		M[10] = 1;
	}
	
	M[@ 4] = M[9]  * M[2] - M[10] * M[1];
	M[@ 5] = M[10] * M[0] - M[8]  * M[2];
	M[@ 6] = M[8]  * M[1] - M[9]  * M[0];
	var l = point_distance_3d(0, 0, 0, M[4], M[5], M[6]);
	if (l != 0)
	{
		l = 1 / l;
		M[@ 4] *= l;
		M[@ 5] *= l;
		M[@ 6] *= l;
	}
	else
	{
		M[5] = 1;
	}
	
	//The last vector is automatically normalized, since the two other vectors now are perpendicular unit vectors
	M[@ 0] = M[10] * M[5] - M[9]  * M[6];
	M[@ 1] = M[8]  * M[6] - M[10] * M[4];
	M[@ 2] = M[9]  * M[4] - M[8]  * M[5];
	
	return M;
}

function colmesh_matrix_orthogonalize_to(M)
{
	/*
		This makes sure the three vectors of the given matrix are all unit length
		and perpendicular to each other, using the up direction as master.
		GameMaker does something similar when creating a lookat matrix. People often use [0, 0, 1]
		as the up direction, but this vector is not used directly for creating the view matrix; rather, 
		it's being used as reference, and the entire view matrix is being orthogonalized to the looking direction.
	*/
	var l = sqrt(dot_product_3d(M[0], M[1], M[2], M[0], M[1], M[2]));
	if (l != 0)
	{
		l = 1 / l;
		M[@ 0]  *= l;
		M[@ 1]  *= l;
		M[@ 2] *= l;
	}
	else
	{
		M[0] = 1;
	}
	
	M[@ 4] = M[9]  * M[2] - M[10] * M[1];
	M[@ 5] = M[10] * M[0] - M[8]  * M[2];
	M[@ 6] = M[8]  * M[1] - M[9]  * M[0];
	var l = sqrt(dot_product_3d(M[4], M[5], M[6], M[4], M[5], M[6]));
	if (l != 0)
	{
		l = 1 / l;
		M[@ 4] *= l;
		M[@ 5] *= l;
		M[@ 6] *= l;
	}
	else
	{
		M[5] = 1;
	}
	
	//The last vector is automatically normalized, since the two other vectors now are perpendicular unit vectors
	M[@ 8]  = M[1] * M[6] - M[2] * M[5];
	M[@ 9]  = M[2] * M[4] - M[0] * M[6];
	M[@ 10] = M[0] * M[5] - M[1] * M[4];
	
	return M;
}

function colmesh_matrix_scale(M, toScale, siScale, upScale)
{
	/*
		Scaled the given matrix along its own axes
	*/
	M[@ 0] *= toScale;
	M[@ 1] *= toScale;
	M[@ 2] *= toScale;
	M[@ 4] *= siScale;
	M[@ 5] *= siScale;
	M[@ 6] *= siScale;
	M[@ 8] *= upScale;
	M[@ 9] *= upScale;
	M[@ 10]*= upScale;
	return M;
}

/// @func colmesh_matrix_build_from_vector(X, Y, Z, vx, vy, vz, toScale, siScale, upScale, targetM*)
function colmesh_matrix_build_from_vector(X, Y, Z, vx, vy, vz, toScale, siScale, upScale, targetM = [abs(vx) < abs(vy), 1, 1, 0, 0, 0, 0, 0, vx, vy, vz, 0, X, Y, Z, 1])
{
	/*
		Creates a matrix based on the vector (vx, vy, vz).
		The vector will be used as basis for the up-vector of the matrix, ie. indices 8, 9, 10.
	*/
	targetM[@ 0]  = abs(vx) < abs(vy);
	targetM[@ 1]  = 1;
	targetM[@ 2]  = 1;
	targetM[@ 3]  = 0;
	targetM[@ 4]  = 0;
	targetM[@ 5]  = 0;
	targetM[@ 6]  = 0;
	targetM[@ 7]  = 0;
	targetM[@ 8]  = vx;
	targetM[@ 9]  = vy;
	targetM[@ 10] = vz;
	targetM[@ 11] = 0;
	targetM[@ 12] = X;
	targetM[@ 13] = Y;
	targetM[@ 14] = Z;
	targetM[@ 15] = 1;
	colmesh_matrix_orthogonalize(targetM);
	return colmesh_matrix_scale(targetM, toScale, siScale, upScale);
}

function colmesh_matrix_transform_vertex(M, x, y, z)
{
	/*
		Transforms a vertex using the given matrix
	*/
	static ret = array_create(3);
	ret[@ 0] = M[12] + dot_product_3d(x, y, z, M[0], M[4], M[8]);
	ret[@ 1] = M[13] + dot_product_3d(x, y, z, M[1], M[5], M[9]);
	ret[@ 2] = M[14] + dot_product_3d(x, y, z, M[2], M[6], M[10]);
	return ret;
}

function colmesh_matrix_transform_vector(M, x, y, z)
{
	/*
		Transforms a vector using the given matrix
	*/
	var ret = matrix_transform_vertex(M, x, y, z);
	ret[0] -= M[12];
	ret[1] -= M[13];
	ret[2] -= M[14];
	return ret;
}

function colmesh_cast_ray_sphere(sx, sy, sz, r, x1, y1, z1, x2, y2, z2, doublesided = false) 
{	
	/*	
		Finds the intersection between a line segment going from [x1, y1, z1] to [x2, y2, z2], and a sphere centered at (sx,sy,sz) with radius r.
		Returns -1 if the ray does not hit the sphere
		Returns a value between 0 and 1 depending on how far along the ray intersects the sphere
	*/
	var dx = sx - x1;
	var dy = sy - y1;
	var dz = sz - z1;

	var vx = x2 - x1;
	var vy = y2 - y1;
	var vz = z2 - z1;

	var v = dot_product_3d(vx, vy, vz, vx, vy, vz);
	var d = dot_product_3d(dx, dy, dz, dx, dy, dz);
	var t = dot_product_3d(vx, vy, vz, dx, dy, dz);
	var u = t * t + v * (r * r - d);
	
	if (u < 0){return -1;}
	
	u = sqrt(max(u, 0));
	if (t < u)
	{
		//The ray started inside the sphere
		if (!doublesided){return -1;} //The ray started inside the sphere, and the sphere is not doublesided. There is no way this ray can intersect the sphere.
		t += u; //Project to the inside of the sphere
		if (t < 0){return -1;} //The sphere is behind the ray
	}
	else
	{
		//Project to the outside of the sphere
		t -= u;
		if (t > v)
		{
			//The sphere is too far away
			return -1;
		}
	}

	//Find the point of intersection
	return t / v;
}

function colmesh_cast_ray_plane(px, py, pz, nx, ny, nz, x1, y1, z1, x2, y2, z2) 
{
	/*
		Finds the intersection between a line segment going from [x1, y1, z1] to [x2, y2, z2], and a plane at (px, py, pz) with normal (nx, ny, nz).

		Returns the intersection as an array of the following format:
		[x, y, z, nx, ny, nz, intersection (true or false)]

		Script made by TheSnidr

		www.thesnidr.com
	*/
	var vx = x2 - x1;
	var vy = y2 - y1;
	var vz = z2 - z1;
	var dn = dot_product_3d(vx, vy, vz, nx, ny, nz);
	if (dn == 0)
	{
		return [x2, y2, z2, 0, 0, 0, false];
	}
	var dp = dot_product_3d(x1 - px, y1 - py, z1 - pz, nx, ny, nz);
	var t = - dp / dn; 
	var s = sign(dp);
	
	static ret = array_create(6);
	ret[0] = x1 + t * vx;
	ret[1] = y1 + t * vy;
	ret[2] = z1 + t * vz;
	ret[3] = s * nx;
	ret[4] = s * ny;
	ret[5] = s * nz;
	ret[6]= true;
	return ret;
}