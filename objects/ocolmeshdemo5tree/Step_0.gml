/// @description Insert description here
// You can write your code in this editor

var xscale = -30;
var yscale = 30;
var zscale = 30;
M = matrix_build(x, y, 0, 0, x * 100 + current_time / 30, 0, xscale, yscale, zscale);
shape.setMatrix(M, true);









