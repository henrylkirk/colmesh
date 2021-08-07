/*
	Some math scripts that are used by the Colmesh system.
*/

/// @function colmesh_vector_magnitude(x, y, z)
/// @description Returns the magnitude of the given vector
function colmesh_vector_magnitude(x, y, z) {
	return sqrt(dot_product_3d(x, y, z, x, y, z));
}

/// @function colmesh_vector_square(x, y, z)
/// @description Returns the square of the magnitude of the given vector
function colmesh_vector_square(x, y, z) {
	return dot_product_3d(x, y, z, x, y, z);
}

/// @function colmesh_matrix_invert_fast
/// @description Returns the inverse of a 4x4 matrix. Assumes indices 3, 7 and 11 are 0, and index 15 is 1
function colmesh_matrix_invert_fast(matrix, targetM) {

	var m0 = matrix[0], m1 = matrix[1], m2 = matrix[2], m4 = matrix[4], m5 = matrix[5], m6 = matrix[6], m8 = matrix[8], m9 = matrix[9], m10 = matrix[10], m12 = matrix[12], m13 = matrix[13], m14 = matrix[14];
	var inv = targetM;
	inv[@ 0]  = m5 * m10 - m9 * m6;
	inv[@ 1]  = -m1 * m10 + m9 * m2;
	inv[@ 2]  = m1 * m6 - m5 * m2;
	inv[@ 3]  = 0;
	inv[@ 4]  = -m4 * m10 + m8 * m6;
	inv[@ 5]  = m0 * m10 - m8 * m2;
	inv[@ 6]  = -m0 * m6 + m4 * m2;
	inv[@ 7]  = 0;
	inv[@ 8]  = m4 * m9 - m8 * m5;
	inv[@ 9]  = -m0 * m9 + m8 * m1;
	inv[@ 10] = m0 * m5 - m4 * m1;
	inv[@ 11] = 0;
	inv[@ 12] = -m4 * m9 * m14 + m4 * m10 * m13 +m8 * m5 * m14 - m8 * m6 * m13 - m12 * m5 * m10 + m12 * m6 * m9;
	inv[@ 13] = m0 * m9 * m14 - m0 * m10 * m13 - m8 * m1 * m14 + m8 * m2 * m13 + m12 * m1 * m10 - m12 * m2 * m9;
	inv[@ 14] = -m0 * m5 * m14 + m0 * m6 * m13 + m4 * m1 * m14 - m4 * m2 * m13 - m12 * m1 * m6 + m12 * m2 * m5;
	inv[@ 15] = 1;
	var _det = m0 * inv[0] + m1 * inv[4] + m2 * inv[8];
	if (_det == 0){
		show_debug_message( "The determinant is zero.");
		return inv;
	}
	_det = 1 / _det;
	
	for(var i = 0; i < 16; i++){
		inv[@ i] *= _det;
	}
	return inv;
}

/// @function colmesh_matrix_invert
/// @description Proper matrix inversion
function colmesh_matrix_invert(matrix, targetM){
	
	var m0 = matrix[0], m1 = matrix[1], m2 = matrix[2], m3 = matrix[3], m4 = matrix[4], m5 = matrix[5], m6 = matrix[6], m7 = matrix[7], m8 = matrix[8], m9 = matrix[9], m10 = matrix[10], m11 = matrix[11], m12 = matrix[12], m13 = matrix[13], m14 = matrix[14], m15 = matrix[15];
	var inv = targetM;
	inv[@ 0]  = m5 * m10 * m15 - m5 * m11 * m14 - m9 * m6 * m15 + m9 * m7 * m14 +m13 * m6 * m11 - m13 * m7 * m10;
	inv[@ 1]  = -m1 * m10 * m15 + m1 * m11 * m14 + m9 * m2 * m15 - m9 * m3 * m14 - m13 * m2 * m11 + m13 * m3 * m10;
	inv[@ 2]  = m1 * m6 * m15 - m1 * m7 * m14 - m5 * m2 * m15 + m5 * m3 * m14 + m13 * m2 * m7 - m13 * m3 * m6;
	inv[@ 3]  = -m1 * m6 * m11 + m1 * m7 * m10 + m5 * m2 * m11 - m5 * m3 * m10 - m9 * m2 * m7 + m9 * m3 * m6;
	inv[@ 4]  = -m4 * m10 * m15 + m4 * m11 * m14 + m8 * m6 * m15 - m8 * m7 * m14 - m12 * m6 * m11 + m12 * m7 * m10;
	inv[@ 5]  = m0 * m10 * m15 - m0 * m11 * m14 - m8 * m2 * m15 + m8 * m3 * m14 + m12 * m2 * m11 - m12 * m3 * m10;
	inv[@ 6]  = -m0 * m6 * m15 + m0 * m7 * m14 + m4 * m2 * m15 - m4 * m3 * m14 - m12 * m2 * m7 + m12 * m3 * m6;
	inv[@ 7]  = m0 * m6 * m11 - m0 * m7 * m10 - m4 * m2 * m11 + m4 * m3 * m10 + m8 * m2 * m7 - m8 * m3 * m6;
	inv[@ 8]  = m4 * m9 * m15 - m4 * m11 * m13 - m8 * m5 * m15 + m8 * m7 * m13 + m12 * m5 * m11 - m12 * m7 * m9;
	inv[@ 9]  = -m0 * m9 * m15 + m0 * m11 * m13 + m8 * m1 * m15 - m8 * m3 * m13 - m12 * m1 * m11 + m12 * m3 * m9;
	inv[@ 10] = m0 * m5 * m15 - m0 * m7 * m13 - m4 * m1 * m15 + m4 * m3 * m13 + m12 * m1 * m7 - m12 * m3 * m5;
	inv[@ 11] = -m0 * m5 * m11 + m0 * m7 * m9 + m4 * m1 * m11 - m4 * m3 * m9 - m8 * m1 * m7 + m8 * m3 * m5;
	inv[@ 12] = -m4 * m9 * m14 + m4 * m10 * m13 +m8 * m5 * m14 - m8 * m6 * m13 - m12 * m5 * m10 + m12 * m6 * m9;
	inv[@ 13] = m0 * m9 * m14 - m0 * m10 * m13 - m8 * m1 * m14 + m8 * m2 * m13 + m12 * m1 * m10 - m12 * m2 * m9;
	inv[@ 14] = -m0 * m5 * m14 + m0 * m6 * m13 + m4 * m1 * m14 - m4 * m2 * m13 - m12 * m1 * m6 + m12 * m2 * m5;
	inv[@ 15] = m0 * m5 * m10 - m0 * m6 * m9 - m4 * m1 * m10 + m4 * m2 * m9 + m8 * m1 * m6 - m8 * m2 * m5;
	var _det = m0 * inv[0] + m1 * inv[4] + m2 * inv[8] + m3 * inv[12];
	if (_det == 0){
		show_debug_message( "The determinant is zero.");
		return inv;
	}
	_det = 1 / _det;
	for(var i = 0; i < 16; i++){
		inv[@ i] *= _det;
	}
	return inv;
}

/// @function colmesh_matrix_multiply
/// @description Multiplies two matrices and outputs the result to targetM
function colmesh_matrix_multiply(matrix, N, targetM) {

	var m0 = matrix[0], m1 = matrix[1], m2 = matrix[2], m3 = matrix[3], m4 = matrix[4], m5 = matrix[5], m6 = matrix[6], m7 = matrix[7], m8 = matrix[8], m9 = matrix[9], m10 = matrix[10], m11 = matrix[11], m12 = matrix[12], m13 = matrix[13], m14 = matrix[14], m15 = matrix[15];
	var n0 = N[0], n1 = N[1], n2 = N[2], n3 = N[3], n4 = N[4], n5 = N[5], n6 = N[6], n7 = N[7], n8 = N[8], n9 = N[9], n10 = N[10], n11 = N[11], n12 = N[12], n13 = N[13], n14 = N[14], n15 = N[15];
	targetM[@ 0]  = m0 * n0 + m4 * n1 + m8 * n2 + m12 * n3;
	targetM[@ 1]  = m1 * n0 + m5 * n1 + m9 * n2 + m13 * n3;
	targetM[@ 2]  = m2 * n0 + m6 * n1 + m10 * n2 + m14 * n3;
	targetM[@ 3]  = m3 * n0 + m7 * n1 + m11 * n2 + m15 * n3;
	targetM[@ 4]  = m0 * n4 + m4 * n5 + m8 * n6 + m12 * n7;
	targetM[@ 5]  = m1 * n4 + m5 * n5 + m9 * n6 + m13 * n7;
	targetM[@ 6]  = m2 * n4 + m6 * n5 + m10 * n6 + m14 * n7;
	targetM[@ 7]  = m3 * n4 + m7 * n5 + m11 * n6 + m15 * n7;
	targetM[@ 8]  = m0 * n8 + m4 * n9 + m8 * n10 + m12 * n11;
	targetM[@ 9]  = m1 * n8 + m5 * n9 + m9 * n10 + m13 * n11;
	targetM[@ 10] = m2 * n8 + m6 * n9 + m10 * n10 + m14 * n11;
	targetM[@ 11] = m3 * n8 + m7 * n9 + m11 * n10 + m15 * n11;
	targetM[@ 12] = m0 * n12 + m4 * n13 + m8 * n14 + m12 * n15;
	targetM[@ 13] = m1 * n12 + m5 * n13 + m9 * n14 + m13 * n15;
	targetM[@ 14] = m2 * n12 + m6 * n13 + m10 * n14 + m14 * n15;
	targetM[@ 15] = m3 * n12 + m7 * n13 + m11 * n14 + m15 * n15;
	return targetM;
}

/// @function colmesh_matrix_multiply_fast
/// @description Multiplies two matrices and outputs the result to targetM. Assumes indices 3, 7 and 11 are 0, and 15 is 1
function colmesh_matrix_multiply_fast(matrix, N, targetM) {

	var m0 = matrix[0], m1 = matrix[1], m2 = matrix[2], m4 = matrix[4], m5 = matrix[5], m6 = matrix[6], m8 = matrix[8], m9 = matrix[9], m10 = matrix[10], m12 = matrix[12], m13 = matrix[13], m14 = matrix[14];
	var n0 = N[0], n1 = N[1], n2 = N[2], n4 = N[4], n5 = N[5], n6 = N[6], n8 = N[8], n9 = N[9], n10 = N[10], n12 = N[12], n13 = N[13], n14 = N[14];
	targetM[@ 0]  = m0 * n0 + m4 * n1 + m8 * n2;
	targetM[@ 1]  = m1 * n0 + m5 * n1 + m9 * n2;
	targetM[@ 2]  = m2 * n0 + m6 * n1 + m10 * n2;
	targetM[@ 3]  = 0;
	targetM[@ 4]  = m0 * n4 + m4 * n5 + m8 * n6;
	targetM[@ 5]  = m1 * n4 + m5 * n5 + m9 * n6;
	targetM[@ 6]  = m2 * n4 + m6 * n5 + m10 * n6;
	targetM[@ 7]  = 0;
	targetM[@ 8]  = m0 * n8 + m4 * n9 + m8 * n10;
	targetM[@ 9]  = m1 * n8 + m5 * n9 + m9 * n10;
	targetM[@ 10] = m2 * n8 + m6 * n9 + m10 * n10;
	targetM[@ 11] = 0;
	targetM[@ 12] = m0 * n12 + m4 * n13 + m8 * n14 + m12;
	targetM[@ 13] = m1 * n12 + m5 * n13 + m9 * n14 + m13;
	targetM[@ 14] = m2 * n12 + m6 * n13 + m10 * n14 + m14;
	targetM[@ 15] = 1;
	return targetM;
}

/// @function colmesh_matrix_build
/// @description This is an alternative to the regular matrix_build properly so that no shearing is applied even if you both rotate and scale non-uniformly
function colmesh_matrix_build(x, y, z, xrotation, yrotation, zrotation, xscale, yscale, zscale){
	var matrix = matrix_build(x, y, z, xrotation, yrotation, zrotation, 1, 1, 1);
	return colmesh_matrix_scale(matrix, xscale, yscale, zscale);
}

/// @function colmesh_matrix_orthogonalize
function colmesh_matrix_orthogonalize(matrix){
	/*
		This makes sure the three vectors of the given matrix are all unit length
		and perpendicular to each other, using the up direciton as master.
		GameMaker does something similar when creating a lookat matrix. People often use [0, 0, 1]
		as the up direction, but this vector is not used directly for creating the view matrix; rather, 
		it's being used as reference, and the entire view matrix is being orthogonalized to the looking direction.
	*/
	var l = matrix[8] * matrix[8] + matrix[9] * matrix[9] + matrix[10] * matrix[10];
	if (l == 0){exit;}
	l = 1 / sqrt(l);
	matrix[@ 8] *= l;
	matrix[@ 9] *= l;
	matrix[@ 10]*= l;
	
	matrix[@ 4] = matrix[9] * matrix[2] - matrix[10]* matrix[1];
	matrix[@ 5] = matrix[10]* matrix[0] - matrix[8] * matrix[2];
	matrix[@ 6] = matrix[8] * matrix[1] - matrix[9] * matrix[0];
	var l = matrix[4] * matrix[4] + matrix[5] * matrix[5] + matrix[6] * matrix[6];
	if (l == 0){exit;}
	l = 1 / sqrt(l);
	matrix[@ 4] *= l;
	matrix[@ 5] *= l;
	matrix[@ 6] *= l;
	
	//The last vector is automatically normalized, since the two other vectors now are perpendicular unit vectors
	matrix[@ 0] = matrix[10]* matrix[5] - matrix[9] * matrix[6];
	matrix[@ 1] = matrix[8] * matrix[6] - matrix[10]* matrix[4];
	matrix[@ 2] = matrix[9] * matrix[4] - matrix[8] * matrix[5];
	
	return matrix;
}

/// @function colmesh_matrix_scale
/// @description Scaled the given matrix along its own axes
function colmesh_matrix_scale(matrix, toScale, siScale, upScale){
	matrix[@ 0] *= toScale;
	matrix[@ 1] *= toScale;
	matrix[@ 2] *= toScale;
	matrix[@ 4] *= siScale;
	matrix[@ 5] *= siScale;
	matrix[@ 6] *= siScale;
	matrix[@ 8] *= upScale;
	matrix[@ 9] *= upScale;
	matrix[@ 10]*= upScale;
	return matrix;
}

/// @function colmesh_matrix_build_from_vector
/// @description Creates a matrix based on the vector (vx, vy, vz). The vector will be used as basis for the up-vector of the matrix, ie. indices 8, 9, 10
function colmesh_matrix_build_from_vector(X, Y, Z, vx, vy, vz, toScale, siScale, upScale){

	var matrix = [0, 1, 1, 0, 0, 0, 0, 0, vx, vy, vz, 0, X, Y, Z, 1];
	if abs(vx) < abs(vy){
		matrix[0] = 1;
	}
	colmesh_matrix_orthogonalize(matrix);
	return colmesh_matrix_scale(matrix, toScale, siScale, upScale);
}

/// @function colmesh_matrix_transform_vertex
/// @description Transforms a vertex using the given matrix
function colmesh_matrix_transform_vertex(matrix, x, y, z){

	static ret = array_create(3);
	ret[@ 0] = matrix[0] * x + matrix[4] * y + matrix[8] * z + matrix[12];
	ret[@ 1] = matrix[1] * x + matrix[5] * y + matrix[9] * z + matrix[13];
	ret[@ 2] = matrix[2] * x + matrix[6] * y + matrix[10]* z + matrix[14];
	return ret;
}

/// @function colmesh_matrix_transform_vector
/// @description Transforms a vector using the given matrix
function colmesh_matrix_transform_vector(matrix, x, y, z){

	static ret = array_create(3);
	ret[@ 0] = matrix[0] * x + matrix[4] * y + matrix[8] * z;
	ret[@ 1] = matrix[1] * x + matrix[5] * y + matrix[9] * z;
	ret[@ 2] = matrix[2] * x + matrix[6] * y + matrix[10]* z;
	return ret;
}

/// @function colmesh_cast_ray_sphere
function colmesh_cast_ray_sphere(sx, sy, sz, r, x1, y1, z1, x2, y2, z2) {	
	/*	
		Finds the intersection between a line segment going from [x1, y1, z1] to [x2, y2, z2], and a sphere centered at (sx,sy,sz) with radius r.
		Returns false if the ray hits the sphere but the line segment is too short,
		returns true if the ray misses completely, 
		returns an array of the following format if there was and intersection between the line segment and the sphere:
			[x, y, z]
	*/
	var dx = sx - x1;
	var dy = sy - y1;
	var dz = sz - z1;

	var vx = x2 - x1;
	var vy = y2 - y1;
	var vz = z2 - z1;

	//dp is now the distance from the starting point to the plane perpendicular to the ray direction, times the length of dV
	var v = vx * vx + vy * vy + vz * vz;
	var d = dx * dx + dy * dy + dz * dz;
	var t = dx * vx + dy * vy + dz * vz;

	//u is the remaining distance from this plane to the surface of the sphere, times the length of dV
	var u = t * t + v * (r * r - d);

	//If u is less than 0, there is no intersection
	if (u < 0){
		return true;
	}
	
	u = sqrt(u);
	if (t < u) {
		// Project to the inside of the sphere
		t += u; 
		if (t < 0) {
			// The sphere is behind the ray
			return true;
		}
	} else {
		// Project to the outside of the sphere
		t -= u;
		if (t > v) {
			// The sphere is too far away
			return false;
		}
	}

	// Find the point of intersection
	static ret = array_create(3);
	t /= v;
	ret[0] = x1 + vx * t;
	ret[1] = y1 + vy * t;
	ret[2] = z1 + vz * t;
	return ret;
}