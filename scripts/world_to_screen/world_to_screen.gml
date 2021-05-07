/// @function world_to_screen
function world_to_screen(x, y, z, view_mat, proj_mat) {
    /*
        Transforms a 3D world-space coordinate to a 2D window-space coordinate.
        Returns [-1, -1] if the 3D point is not in view
   
        Script created by TheSnidr
        www.thesnidr.com
    */
    
    if (proj_mat[15] == 0) { // This is a perspective projection
        var w = view_mat[2] * x + view_mat[6] * y + view_mat[10] * z + view_mat[14];
        if (w <= 0) return new Vector2(-1, -1);
        var cx = proj_mat[8] + proj_mat[0] * (view_mat[0] * x + view_mat[4] * y + view_mat[8] * z + view_mat[12]) / w;
        var cy = proj_mat[9] + proj_mat[5] * (view_mat[1] * x + view_mat[5] * y + view_mat[9] * z + view_mat[13]) / w;
    } else {    //This is an ortho projection
        var cx = proj_mat[12] + proj_mat[0] * (view_mat[0] * x + view_mat[4] * y + view_mat[8]  * z + view_mat[12]);
        var cy = proj_mat[13] + proj_mat[5] * (view_mat[1] * x + view_mat[5] * y + view_mat[9]  * z + view_mat[13]);
    }
    
    // the original script had (0.5 - 0.5 * cy) for the y component, but that was
    // causing things to be upside-down for some reason?
    return new Vector2((0.5 + 0.5 * cx) * window_get_width(), (0.5 + 0.5 * cy) * window_get_height());
};
