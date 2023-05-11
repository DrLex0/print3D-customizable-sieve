/* Customizable sieve by DrLex and contributors, formerly thing:2578935
 * based on Sieve (or Seive?) by pcstru (thing:341357).
 * Released under Creative Commons - Attribution - Share Alike license
 * https://github.com/DrLex0/print3D-customizable-sieve
 * Version 2.3, 2022/05
 */

shape = "round"; // [round,square,heart]

// All dimensions are in millimeters. For square shape, this is the length of one side. For heart shape, this is the width and depth of the heart.
outer_diameter = 40; //[5.0:.1:250.0]

// Additional X dimension length for creating elongated shapes (rectangles or ellipses).
stretch = 0.0; //[0:.1:250.0]

// Width of the filter wires. You shouldn't try to go below your nozzle diameter, although it might work within certain limits.
strand_width = .4; //[.10:.01:10.00]

// Thickness (height) of the filter wires. If 'Offset strands' is enabled, the filter grid will be twice this thick.
strand_thickness = .4; //[.10:.01:5]

// Spacing between filter wires, i.e. hole size.
gap_size = .8; //[.10:.01:10.00]

// Thickness (width) of the outer rim (will increase with height if taper > 1).
rim_thickness = 1.7; //[.3:.01:5]

// Total height of the outer rim.
rim_height = 3; //[0:.1:50]

// Taper of the tube: scale factor of top versus bottom contour
taper = 1; //[1:0.01:3]

// If yes, the wires will be placed in different layers, which leads to a quicker and possibly better print, especially when using thin strands.
offset_strands = "yes"; // [yes,no]

// For most accurate results with thin strands, set this to your first layer height. This will ensure the strands only start printing from the second layer, avoiding any problems due to the first layer being squished, or using a wider extrusion, etc.
lift_strands = 0; //[0.00:.01:2.00]

// Number of segments for round shape, low values can be used to obtain polygons that fit inside a circle of the specified outer diameter. For instance, 3 yields a triangle.
$fn = 72; //[3:1:256]


/* [Hidden] */

module flat_heart(r_x, r_y, thick, inside) {
    // radius + 2 * square
    s_x = (r_x * 2) / 1.5;
    b = s_x / 2;
    w = thick;

    if (inside == 1) {
    translate([-r_x, -r_x ,0])
    union() {
            square(s_x);
            translate([b, s_x, 0]) circle(d=s_x);
            translate([s_x, b, 0]) circle(d=s_x);
        }
    } else {
        translate([-r_x, -r_x ,0])
        difference() {
            union() {
                square(s_x);
                translate([b, s_x, 0]) circle(d=s_x);
                translate([s_x, b, 0]) circle(d=s_x);

            }
            translate([w/2, w/2]) square([s_x-(w/2), s_x-w]);
            translate([w/2, w/2]) square([s_x-w, s_x-(w/2)]);
            translate([b, s_x, 0]) circle(d=s_x-w);
            translate([s_x, b, 0]) circle(d=s_x-w);
       }
    }
}

// A tube:
// - hollow if inside == 0,
// - the inside volume if inside == 1,
// - else the outside volume.
// Taper applies to the entire shape, so wall thickness will vary if taper != 1.
module tube(r_x, r_y, thick, height, taper, inside=0) {
    if(shape == "round") {
        stretchx = r_x / r_y;
        linear_extrude(height=height, convexity=4, scale=taper) {
            if(inside == 0) {
                difference() {
                    scale(1/stretchx) scale([stretchx,1]) circle(r=r_x);
                    offset(delta=-thick) scale(1/stretchx) scale([stretchx,1]) circle(r=r_x);
                }
            }
            else if(inside == 1) {
                scale(1/stretchx) offset(delta=-thick) scale([stretchx,1]) circle(r=r_x);
            }
            else {
                scale(1/stretchx) scale([stretchx,1]) circle(r=r_x);
            }
        }
    }
    else if(shape == "heart") {
        linear_extrude(height = height)
            flat_heart(r_x, r_y, thick, inside);
    }
    else {
        linear_extrude(height=height, convexity=4, scale=taper) {
            if(inside == 0) {
                difference() {
                    square([2*r_x,2*r_y], center=true);
                    square([2*(r_x-thick),2*(r_y-thick)], center=true);
                }
            }
            else if(inside == 1) {
                square([2*(r_x-thick),2*(r_y-thick)], center=true);
            }
            else {
                square([2*r_x,2*r_y], center=true);
            }
        }
    }
}

// Grid
module grid(width, length, strand_width, strand_thick, gap, do_offset) {
    wh = width / 2;
    lh = length / 2;
    // Let's enforce symmetry just for the heck of it
    wh_align = (strand_width + gap) * floor(wh/(strand_width + gap)) + strand_width + gap/2;
    lh_align = (strand_width + gap) * floor(lh/(strand_width + gap)) + strand_width + gap/2;

    for(ix = [-wh_align:strand_width+gap:wh_align]) {
        translate([-lh,ix,0]) cube([length,strand_width,strand_thick]) ;
    }

    for(iy = [-lh_align:strand_width+gap:lh_align]) {
        if (do_offset=="yes") {
            translate([iy,-wh,strand_thick]) cube([strand_width,width,strand_thick]) ;
        }
        else {
            translate([iy,-wh,0]) cube([strand_width,width,strand_thick]) ;
        }
    }
}

// Module  : Sieve
// Params :
// 	od_x = outer X dimension of the cylinder or rectangle
// 	od_y = outer Y dimension of the cylinder or rectangle
// 	strand_width = width of grid strands
// 	strand_thick = thickness of grid strands
// 	gap = gap between strands
// 	rim_thick = thickness of outer rim
// 	rim_height = height of outer rim
// 	do_offset = offset the strands ("yes" or "no")
//
module sieve(od_x, od_y, strand_width, strand_thick, gap, rim_thick, rim_height, taper, do_offset) {
    or_x = od_x/2;
    or_y = od_y/2;
    upper_height = (do_offset == "yes") ?
        rim_height-2*strand_thick-lift_strands+.01 :
        rim_height-strand_thick-lift_strands+.01;
    upper_start = (do_offset == "yes") ?
        2*strand_thick-.01 :
        strand_thick-.01;

    // Add .01 margin to ensure good overlap, avoid non-manifold
    if(lift_strands > 0) {
        tube(or_x, or_y, rim_thick, lift_strands+.01, 1);
    }
    translate([0, 0, lift_strands]) {
        // Trim the grid to the outer shape, minus some margin
        intersection() {
            grid(od_y, od_x, strand_width, strand_thick, gap, do_offset);
            translate([0,0,-.01]) tube(or_x, or_y, .1, rim_height + 2*strand_thick + .1, 1, 1);
        }
        
        translate([0, 0, upper_start]) tube(or_x, or_y, rim_thick, upper_height, taper);
    }

    tube(or_x, or_y, rim_thick-.4, rim_height - upper_height, 1);
}

sieve(outer_diameter+stretch, outer_diameter, strand_width, strand_thickness, gap_size, rim_thickness, rim_height, taper, offset_strands);
