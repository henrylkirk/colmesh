/// @function Vector2
/// @param {real} [x]
/// @param {real} [y]
/// @description Create a 2 dimensional vector
function Vector2(x = 0, y = 0) constructor {
	self.x = x;
	self.y = y;

	/// @function add
	/// @description Add a Vector2 or real number to this Vector2
	/// @param {Vector2/real} _other
	/// @param {real} [add_y] - If two real arguments are provided, add each component
	/// @returns {Vector2} self
	static add = function(_other){
		if instanceof(_other) == "Vector2" {
		    x += _other.x;
		    y += _other.y;
		} else if argument_count == 2 {
			x += argument[0];
			y += argument[1];
		} else if is_real(argument[0]) {
			x += argument[0];
			y += argument[0];
		} else {
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function subtract
	/// @description Subtract another Vector2 or real number from self
	/// @param {Vector2/real} _other
	/// @returns {Vector2} self
	static subtract = function(_other){
		if instanceof(_other) == "Vector2" {
		    x -= _other.x;
		    y -= _other.y;
		} else if is_real(_other) {
			x -= _other;
			y -= _other;
		} else {
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function set
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
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function copy
	/// @description Create a new vector with the same values as this one
	/// @returns {Vector2} new_vector
	static copy = function(){
		return new Vector2(x, y);
	}

	/// @function equals
	/// @param {Vector2} other
	/// @returns {boolean} equals
	/// @description Check if two Vector2's have the same values
	static equals = function(_other) {
		return (x == _other.x and y == _other.y);
	}

	/// @function divide
	/// @description Divide two Vector2 structs or multiply by a real
	/// @param {Vector2/real} other
	/// @returns {Vector2} self
	static divide = function(_other){
		if instanceof(_other) == "Vector2" {
			x /= _other.x;
			y /= _other.y;
		} else if is_real(_other) {
			x /= _other;
			y /= _other;
		} else {
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function multiply
	/// @description Multiply two Vector2 structs
	/// @returns {Vector2} self
	static multiply = function(_other){
		if instanceof(_other) == "Vector2" {
		    x *= _other.x;
		    y *= _other.y;
		} else if is_real(_other) {
			x *= _other;
			y *= _other;
		} else {
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function length
	/// @description Get the length of a Vector2
	/// @returns {real} length
	static length = function(){
		return point_distance(0,0,x,y);
	}

	/// @function normalize
	/// @description Normalize a scalar
	/// @returns {Vector2} self
    static normalize = function() {
        if ((x != 0) or (y != 0)) {
			multiply(1/sqrt(sqr(x) + sqr(y)));
        }
		return self;
    }

	/// @function set_magnitude
	/// @description Set the Vector's magnitude
	/// @returns {Vector2} self
	static set_magnitude = function(_scalar) {
        normalize();
        multiply(_scalar);
		return self;
    }

	/// @function limit
	/// @description Returns the vector with a maximum length by limiting its length
	/// @param {real} limit
	/// @returns {Vector2} self
    static limit = function(_limit) {
		if(length() > _limit) {
			set_magnitude(_limit);
		}
		return self;
    }

	/// @function distance_to
	/// @param {Vector2/real} other/x
	/// @param {real} [y]
	/// @description Get the distance between two Vector2s
	/// @returns The distance between self and other Vector
	static distance_to = function(){
		var _x, _y;
		if argument_count == 2 {
			_x = argument[0];
			_y = argument[1];
		} else if instanceof(argument[0]) == "Vector2" {
			_x = argument[0].x;
			_y = argument[0].y;
		} else {
			throw "Invalid argument(s) provided";
		}
		return point_distance(x, y, _x, _y);
	}

	/// @function direction_to
	/// @param {Vector2/real} other/x
	/// @param {real} [y]
	/// @returns Direction of the given Vector2(s)
	static direction_to = function(){
		var _x, _y;
		if argument_count == 2 {
			_x = argument[0];
			_y = argument[1];
		} else if instanceof(argument[0]) == "Vector2" {
			_x = argument[0].x;
			_y = argument[0].y;
		} else {
			throw "Invalid argument(s) provided";
		}
		return point_direction(x, y, _x, _y);
	}

	/// @function angle
	/// @description Get the direction of this Vector2 in degrees
	/// @returns {real} angle
	static angle = function(){
		return point_direction(0, 0, x, y);
	}

	/// @function rotate_add
	/// @param {real} angle - The angle in degrees to add
	/// @param {real} [origin_x=0]
	/// @param {real} [origin_y=0]
	/// @returns {Vector2} self
	/// @description Rotate a vector around a point or the origin
	static rotate_add = function(_angle, _origin_x, _origin_y){
		_origin_x = is_real(_origin_x) ? _origin_x : 0;
		_origin_y = is_real(_origin_y) ? _origin_y : 0;

		var theta = point_direction(_origin_x, _origin_y, x, y);

		return rotate_set(theta+_angle, _origin_x, _origin_y);
	}

	/// @function rotate_set
	/// @param {real} angle - The angle in degrees to set
	/// @param {real} [origin_x=0]
	/// @param {real} [origin_y=0]
	/// @returns {Vector2} self
	/// @description Rotate a vector around a point or the origin
	static rotate_set = function(_angle, _origin_x, _origin_y){
		_origin_x = is_real(_origin_x) ? _origin_x : 0;
		_origin_y = is_real(_origin_y) ? _origin_y : 0;

		// Convert to polar
		var r = point_distance(_origin_x, _origin_y, x, y);

		// Convert back and apply
		x = _origin_x + lengthdir_x(r, _angle);
		y = _origin_y + lengthdir_y(r, _angle);

		return self;
	}

	/// @function to_string
	/// @param {boolean} [round_values=false]
	static to_string = function(_round_values){
		_round_values = !is_undefined(_round_values) ? _round_values : false;
		var names = variable_struct_get_names(self);
		var len = variable_struct_names_count(self);
		var result_string = instanceof(self)+"{";
		for (var i = 0; i < len; i++) {
			result_string += names[i] + ": ";
			var val = variable_instance_get(self, names[i]);
			if _round_values {
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
	static dot = function(_other) {
		return x * _other.y - y * _other.x;
	}
	
	/// @function to_array
	static to_array = function(){
		return [x, y];
	}
	
	/// @function clamp_value
	/// @param {real} value
	/// @description Use this vector as a range to clamp a value between
	static clamp_value = function(value){
		return clamp(value, x, y);
	}

}

/// @function Vector3
/// @param {real} [x]
/// @param {real} [y]
/// @param {real} [z]
/// @description Create a 3 dimensional vector (inherits from Vector2)
function Vector3(x = 0, y = 0, z = 0) : Vector2(x, y) constructor {
	self.z = z;

	/// @function add
	/// @param {Vector3/real} other
	/// @description Add two Vector3 structs
	static add = function(_other){
		if instanceof(_other) == "Vector3" {
		    x += _other.x;
		    y += _other.y;
			z += _other.z;
		} else if is_real(_other) {
			x += _other;
			y += _other;
			z += _other;
		} else {
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function copy
	/// @description Create a new vector with the same values as this one
	/// @returns {Vector3} new_vector
	static copy = function(){
		return new Vector3(x, y, z);
	}

	/// @function subtract
	/// @param {Vector3/real} other
	/// @description Subtract two Vector3 structs
	static subtract = function(_other){
		if instanceof(_other) == "Vector3" {
		    x -= _other.x;
		    y -= _other.y;
			z -= _other.z;
		} else if is_real(_other) {
			x -= _other;
			y -= _other;
			z -= _other;
		} else {
			throw "Invalid argument provided";
		}
		return self;
	}

	/// @function multiply
	/// @description Multiply two Vector3 structs
	static multiply = function(_other){
		if instanceof(_other) == "Vector3" {
			x *= _other.x;
			y *= _other.y;
			z *= _other.z;
		} else if is_real(_other) {
			x *= _other;
			y *= _other;
			z *= _other;
		} else {
			throw "Invalid argument provided";
		}
	}

	/// @function normalize()
	/// @description Normalize a scalar to Vector3
    static normalize = function() {
        if ((x != 0) or (y != 0) or (z != 0)) {
            var _factor = 1/sqrt(sqr(x) + sqr(y) + sqr(z));
            x *= _factor;
            y *= _factor;
			z *= _factor;
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
	/// @description Set the Vector's values
	/// @returns {Vector3} self
	static set = function(){
		if argument_count == 1 {
			x = argument[0].x;
			y = argument[0].y;
			z = argument[0].z;
		} else {
			x = argument[0];
			y = argument[1];
			z = argument[2];
		}
		return self;
	}

	/// @function rotate
	/// @param {Vector3} axis - The vector representing the axis of rotation
	/// @param {real} angle - The angle in degrees
	/// @returns {Vector3} self
	/// @description Rotates the point (x,y,z) around the vector [a,b,c] using Rodrigues' Rotation Formula
	static rotate = function(_axis, _angle) {
		var c, s, d, rx, ry, rz;
		c = dcos(_angle);
		s = dsin(_angle);
		d = (1 - c) * (_axis.x * x + _axis.y * y + _axis.z * z);

		rx = x * c + _axis.x * d + (_axis.y * z - _axis.z * y) * s;
		ry = y * c + _axis.y * d + (_axis.z * x - _axis.x * z) * s;
		rz = z * c + _axis.z * d + (_axis.x * y - _axis.y * x) * s;

		return set(rx, ry, rz);
	}

	/// @function cross
	/// @param {Vector3} other
	///	@description The sign of the 3D cross product tells you whether specific vector is on the left or right side of the first one (Direction of first one being front)
	/// @returns {real} The cross product
	static cross = function(_other){
		return new Vector3(
			y * _other.z - z * _other.y,
			z * _other.x - x * _other.z,
			x * _other.y - y * _other.x
		);
	}
	
	/// @function to_array
	static to_array = function(){
		return [x, y, z];
	}

}