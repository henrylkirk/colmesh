/// @function Vector2
/// @param {real} [x=0]
/// @param {real} [y=0]
/// @description Create a 2 dimensional vector
function Vector2(x = 0, y = 0) constructor {
	self.x = x;
	self.y = y;

	/// @function add
	/// @param {Vector2/real} x/vector - Either a real number or a vector to add
	/// @param {real} [y] - If two real arguments are provided, add each component
	/// @description Add a Vector2 or one or two real numbers to this Vector2
	/// @returns {Vector2} self
	static add = function(o){
		if instanceof(o) == "Vector2" {
		    x += o.x;
		    y += o.y;
		} else if argument_count == 2 {
			x += argument[0];
			y += argument[1];
		} else if is_real(o) {
			x += o;
			y += o;
		} else {
			throw "ERROR Vector2.add: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function subtract
	/// @param {Vector2/real} x/vector
	/// @param {real} [y] - If two real arguments are provided, subtract each component
	/// @description Add a Vector2 or one or two real numbers to this Vector2
	/// @returns {Vector2} self
	static subtract = function(o){
		if instanceof(o) == "Vector2" {
		    x -= o.x;
		    y -= o.y;
		} else if argument_count == 2 {
			x -= argument[0];
			y -= argument[1];
		} else if is_real(o) {
			x -= o;
			y -= o;
		} else {
			throw "ERROR Vector2.subtract: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function set
	/// @param {real/Vector2} [x/other] - Either another Vector2 to copy from, or a real x value
	/// @param {real} [y] - Must be provided if x is provided for first argument
	/// @description Set the Vector's values
	/// @returns {Vector2} self
	static set = function(){
		if argument_count == 1 {
			x = argument[0].x;
			y = argument[0].y;
		} else if is_real(argument[0]) and is_real(argument[1]) {
			x = argument[0];
			y = argument[1];
		} else {
			throw "ERROR Vector2.set: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function copy()
	/// @description Create a new vector with the same values as this one
	/// @returns {Vector2} new_vector
	static copy = function(){
		return new Vector2(x, y);
	}

	/// @function equals
	/// @param {real/Vector2} x/other_vector
	/// @param {real} [y]
	/// @description Check if two Vector2's have the same values, or whether this vector is equal to two real numbers
		/// @returns {boolean} equals
	static equals = function() {
		if instanceof(argument[0]) == "Vector2" { // A vector - check if each component is equal
			return (x == argument[0].x) and (y == argument[0].y);
		} else if (argument_count == 2) { // Two real numbers
			return (x == argument[0]) and (y == argument[1]);
		} else {
			throw "ERROR Vector2.equals: Invalid argument(s) provided";
		}
	}

	/// @function divide
	/// @param {Vector2/real} x/other_vector
	/// @param {real} [y]
	/// @description Divide two Vector2 structs or divide by one or two real numbers
	/// @returns {Vector2} self
	static divide = function(o){
		if instanceof(o) == "Vector2" {
			x /= o.x;
			y /= o.y;
		} else if argument_count == 2 {
			x /= argument[0];
			y /= argument[1];
		} else if is_real(o) {
			x /= o;
			y /= o;
		} else {
			throw "ERROR Vector2.divide: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function multiply
	/// @param {Vector2/real} x/other_vector
	/// @param {real} [y]
	/// @description Multiply two Vector2 structs or multiply by one or two real numbers
	/// @returns {Vector2} self
	static multiply = function(o){
		if instanceof(o) == "Vector2" {
		    x *= o.x;
		    y *= o.y;
		} else if argument_count == 2 {
			x *= argument[0];
			y *= argument[1];
		} else if is_real(o) {
			x *= o;
			y *= o;
		} else {
			throw "ERROR Vector2.multiply: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function length()
	/// @description Get the length of a Vector2
	/// @returns {real} length
	static length = function(){
		return point_distance(0, 0, x, y);
	}

	/// @function normalize()
	/// @description Normalize a scalar
	/// @returns {Vector2} self
    static normalize = function() {
        if ((x != 0) or (y != 0)) {
			multiply(1 / sqrt(sqr(x) + sqr(y)));
        }
		return self;
    }

	/// @function set_magnitude
	/// @param {real} scalar
	/// @description Set the Vector's magnitude
	/// @returns {Vector2} self
	static set_magnitude = function(scal) {
        normalize();
        multiply(scal);
		return self;
    }

	/// @function limit
	/// @param {real} limit
	/// @description Returns the vector with a maximum length by limiting its length
	/// @returns {Vector2} self
    static limit = function(lim) {
		if(length() > lim) {
			set_magnitude(lim);
		}
		return self;
    }

	/// @function distance_to
	/// @param {Vector2/real} other/x
	/// @param {real} [y]
	/// @description Get the distance between two Vectors
	/// @returns {real} distance - The distance between self and other
	static distance_to = function(){
		var ox, oy;
		if argument_count == 2 {
			ox = argument[0];
			oy = argument[1];
		} else if instanceof(argument[0]) == "Vector2" {
			ox = argument[0].x;
			oy = argument[0].y;
		} else {
			throw "Invalid argument(s) provided";
		}
		return point_distance(x, y, ox, oy);
	}

	/// @function direction_to
	/// @param {Vector2/real} other/x
	/// @param {real} [y]
	/// @returns Direction of the given Vector2(s)
	static direction_to = function(){
		var ox, oy;
		if argument_count == 2 {
			ox = argument[0];
			oy = argument[1];
		} else if instanceof(argument[0]) == "Vector2" {
			ox = argument[0].x;
			oy = argument[0].y;
		} else {
			throw "ERROR Vector2.direction_to: Invalid argument(s) provided";
		}
		return point_direction(x, y, ox, oy);
	}

	/// @function get_angle
	/// @description Get the direction/angle of this Vector2 in degrees
	/// @returns {real} angle
	static get_angle = function(){
		return point_direction(0, 0, x, y);
	}

	/// @function rotate_add
	/// @param {real} rot_angle - The angle in degrees to add
	/// @param {real} [origin_x=0]
	/// @param {real} [origin_y=0]
	/// @returns {Vector2} self
	/// @description Rotate a vector around a point or the origin
	static rotate_add = function(rot_angle, origin_x = 0, origin_y = 0){
		var theta = point_direction(origin_x, origin_y, x, y);
		return rotate_set(theta+rot_angle, origin_x, origin_y);
	}

	/// @function rotate_set
	/// @param {real} rot_angle - The angle in degrees to set
	/// @param {real} [origin_x=0]
	/// @param {real} [origin_y=0]
	/// @returns {Vector2} self
	/// @description Rotate a vector around a point or the origin
	static rotate_set = function(rot_angle, origin_x = 0, origin_y = 0){
		// Convert to polar
		var r = point_distance(origin_x, origin_y, x, y);

		// Convert back and apply
		x = origin_x + lengthdir_x(r, rot_angle);
		y = origin_y + lengthdir_y(r, rot_angle);

		return self;
	}

	/// @function to_string
	/// @param {boolean} [round_values=false]
	static to_string = function(round_values = false){
		var names = variable_struct_get_names(self);
		var len = variable_struct_names_count(self);
		var result_string = instanceof(self)+"{";
		for (var i = 0; i < len; i++) {
			result_string += names[i] + ": ";
			var val = variable_instance_get(self, names[i]);
			if round_values {
				val = round(val);
			}
			result_string += string(val);
			if i < len-1 {
				result_string += ", ";
			}
		}
		result_string += "}";
		return result_string;
	}

	/// @function dot
	/// @param {Vector2} other
	///	@description Find the dot product
	/// @returns {real} The scalar dot product
	static dot = function(o) {
		return dot_product(x, y, o.x, o.y);
	}
	
	/// @function to_array()
	/// @description Return this Vector as an array
	static to_array = function(){
		return [x, y];
	}
	
	/// @function to_list()
	/// @description Return this Vector as a ds_list
	/// @returns {ds_list} vector_as_list
	static to_list = function(){
		var l = ds_list_create();
		ds_list_insert(l, 0, x);
		ds_list_insert(l, 1, y);
		return l;
	}
	
	/// @function clamp_value
	/// @param {real} value
	/// @description Use this vector as a range to clamp a value between
	/// @returns {real} clamped_value
	static clamp_value = function(value){
		return clamp(value, x, y);
	}

}

/// @function Vector3
/// @param {real} [x=0]
/// @param {real} [y=0]
/// @param {real} [z=0]
/// @description Create a 3 dimensional vector (inherits from Vector2)
function Vector3(x = 0, y = 0, z = 0) : Vector2(x, y) constructor {
	self.z = z;

	/// @function add
	/// @param {Vector3/real} other
	/// @description Add two Vector3 structs
	static add = function(o){
		if instanceof(o) == "Vector3" {
		    x += o.x;
		    y += o.y;
			z += o.z;
		} else if argument_count == 3 {
			x += argument[0];
			y += argument[1];
			z += argument[2];
		} else if is_real(o) {
			x += o;
			y += o;
			z += o;
		} else {
			throw "ERROR Vector3.add: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function copy()
	/// @description Create a new vector with the same values as this one
	/// @returns {Vector3} new_vector
	static copy = function(){
		return new Vector3(x, y, z);
	}

	/// @function subtract
	/// @param {Vector3/real} other
	/// @description Subtract two Vector3 structs
	static subtract = function(o){
		if instanceof(o) == "Vector3" {
		    x -= o.x;
		    y -= o.y;
			z -= o.z;
		} else if argument_count == 3 {
			x -= argument[0];
			y -= argument[1];
			z -= argument[2];
		} else if is_real(o) {
			x -= o;
			y -= o;
			z -= o;
		} else {
			throw "ERROR Vector3.subtract: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function multiply(other)
	/// @description Multiply two Vector3 structs or by a real number
	/// @returns {Vector3} self
	static multiply = function(o){
		if instanceof(o) == "Vector3" {
			x *= o.x;
			y *= o.y;
			z *= o.z;
		} else if argument_count == 3 {
			x *= argument[0];
			y *= argument[1];
			z *= argument[2];
		} else if is_real(o) {
			x *= o;
			y *= o;
			z *= o;
		} else {
			throw "ERROR Vector3.multiply: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function normalize()
	/// @description Normalize a Vector3 (maintain direction but set length to 1)
	/// @returns {Vector3} self
    static normalize = function() {
        if ((x != 0) or (y != 0) or (z != 0)) {
            var factor = 1/sqrt(sqr(x) + sqr(y) + sqr(z));
            x *= factor;
            y *= factor;
			z *= factor;
        }
		return self;
    }

	/// @function length
	/// @description Get the length of the vector
	/// @returns {real} length
	static length = function(){
		return point_distance_3d(x, y, z, 0, 0, 0);
	}

	/// @function set
	/// @param {real/Vector3} x/other_vector
	/// @param {real} [y]
	/// @param {real} [z]
	/// @description Set the Vector's values
	/// @returns {Vector3} self
	static set = function(){
		if instanceof(argument[0]) == "Vector3" {
			x = argument[0].x;
			y = argument[0].y;
			z = argument[0].z;
		} else if argument_count == 1 {
			x = argument[0];
			y = argument[0];
			z = argument[0];
		} else if argument_count == 3 {
			x = argument[0];
			y = argument[1];
			z = argument[2];
		} else {
			throw "ERROR Vector3.set: Invalid argument(s) provided";
		}
		return self;
	}

	/// @function rotate
	/// @param {Vector3} axis - The vector representing the axis of rotation
	/// @param {real} rot_angle - The angle in degrees
	/// @returns {Vector3} self
	/// @description Rotates the point (x,y,z) around the vector [a,b,c] using Rodrigues' Rotation Formula
	static rotate = function(axis, rot_angle) {
		var c, s, d, rx, ry, rz;
		c = dcos(rot_angle);
		s = dsin(rot_angle);
		d = (1 - c) * (axis.x * x + axis.y * y + axis.z * z);

		rx = x * c + axis.x * d + (axis.y * z - axis.z * y) * s;
		ry = y * c + axis.y * d + (axis.z * x - axis.x * z) * s;
		rz = z * c + axis.z * d + (axis.x * y - axis.y * x) * s;

		return set(rx, ry, rz);
	}

	/// @function cross(other)
	/// @param {Vector3} other
	///	@description The sign of the 3D cross product tells you whether specific vector is on the left or right side of the first one (Direction of first one being front)
	/// @returns {Vector3} cross_product - The cross product with the provided Vector3
	static cross = function(o){
		return new Vector3(
			y * o.z - z * o.y,
			z * o.x - x * o.z,
			x * o.y - y * o.x
		);
	}
	
	/// @function to_array()
	/// @description Return this Vector as an array
	/// @returns {array} vector_as_array
	static to_array = function(){
		return [x, y, z];
	}
	
	/// @function to_list()
	/// @description Return this Vector as a ds_list
	/// @returns {ds_list} vector_as_list
	static to_list = function(){
		var l = ds_list_create();
		ds_list_insert(l, 0, x);
		ds_list_insert(l, 1, y);
		ds_list_insert(l, 2, z);
		return l;
	}
	
	/// @function dot(other)
	/// @description Find the dot product between this Vector3 and another
	/// @returns {real} dot_product
	static dot = function(o){
		return dot_product_3d(x, y, z, o.x, o.y, o.z);
	}
	
	/// @function get_square()
	/// @description Returns the square of the magnitude of the vector
	/// @returns {real} square
	static get_square = function() {
		return dot_product_3d(x, y, z, x, y, z);
	}
	
	/// @function get_magnitude()
	/// @description Returns the magnitude of the given vector
	/// @returns {real} magnitude
	static get_magnitude = function() {
		return sqrt(get_square());
	}

}