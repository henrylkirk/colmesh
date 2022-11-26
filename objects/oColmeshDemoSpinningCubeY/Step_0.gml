/// @description
M = matrix_build(x, y + 40 * cos(current_time / 600), z + 30 * cos(current_time / 250), 30 * cos(current_time / 200), 30 * cos(current_time / 300), 0, 1, 1, 1);
shape.setMatrix(M, true);