// VGA controller

// ----------------------------------------------------------------------
// This file contains the logic to generate the synchronization signals,
// horizontal and vertical pixel counter and video disable signal
// for the 640x480@60Hz resolution.
//----------------------------------------------------------------------
//  Behavioral description
//----------------------------------------------------------------------
// Please read the following article on the web regarding the
// vga video timings:
// http://www.epanorama.net/documents/pc/vga_timing.html

// This module generates the video synch pulses for the monitor to
// enter 640x480@60Hz resolution state. It also provides horizontal
// and vertical counters for the currently displayed pixel and a blank
// signal that is active when the pixel is not inside the visible screen
// and the color outputs should be reset to 0.

// timing diagram for the horizontal synch signal (HS)
// 0                         648    744           800 (pixels)
// -------------------------|______|-----------------
// timing diagram for the vertical synch signal (VS)
// 0                                  482    484  525 (lines)
// -----------------------------------|______|-------

// The blank signal is delayed one pixel clock period (40ns) from where
// the pixel leaves the visible screen, according to the counters, to
// account for the pixel pipeline delay. This delay happens because
// it takes time from when the counters indicate current pixel should
// be displayed to when the color data actually arrives at the monitor
// pins (memory read delays, synchronization delays).
//----------------------------------------------------------------------
//  Port definitions
//----------------------------------------------------------------------
// rst               - global reset signal
// clk         - input pin, the clock signal of 50 MHz
//		-inside the module it is converted 
//                  -to 25 MHz.
// HS                - output pin, to monitor
//                   - horizontal synch pulse
// VS                - output pin, to monitor
//                   - vertical synch pulse
// hcount            - output pin, 11 bits, to clients
//                   - horizontal count of the currently displayed
//                   - pixel (even if not in visible area)
// vcount            - output pin, 11 bits, to clients
//                   - vertical count of the currently active video
//                   - line (even if not in visible area)
// blank             - output pin, to clients
//                   - active when pixel is not in visible area.
//----------------------------------------------------------------------

module vga_controller(clk, rst, HS, VS, hcount, vcount, blank);

input clk;
input rst;
output HS;
output VS;
output [10:0] hcount;
output [10:0] vcount;
output blank;

// maximum value for the horizontal pixel counter
parameter HMAX = 11'b01100100000; // 800
// maximum value for the vertical pixel counter
parameter VMAX = 11'b01000001101; // 525
// total number of visible columns
parameter HLINES = 11'b01010000000; // 640
// value for the horizontal counter where front porch ends
parameter HFP = 11'b01010001000; // 648
// value for the horizontal counter where the synch pulse ends
parameter HSP = 11'b01011101000; // 744
// total number of visible lines
parameter VLINES = 11'b00111100000; // 480
// value for the vertical counter where the front porch ends
parameter VFP = 11'b00111100010; // 482
// value for the vertical counter where the synch pulse ends
parameter VSP = 11'b00111100100; // 484

reg HS;
reg VS;
reg [10:0] hcount;
reg [10:0] vcount;
reg blank;
reg clk_25;
wire video_enable;

// Generation of 25 MHz clock
always @(posedge clk or posedge rst)
begin
	if (rst) clk_25 <= 1'b0;
	else clk_25 <= !clk_25;
end

// Registers
always @(posedge clk_25 or posedge rst)
begin
	if (rst)
	begin
		blank <= 1'b0;	  // Controls the timing of blank region
		hcount <= 11'd0; // horizontal counter shows the location of currently displayed pixel and controls other timings like HS in one row
		vcount <= 11'd0; // vertical counter shows the location of currently displayed pixel and controls other timings like VS in one column
		HS <= 1'b0; 	  // Generates horizontal synch pulse 
		VS <= 1'b0; 	  // Generates vertical synch pulse
	end
	else 
	begin
		blank <= !video_enable;
		if (hcount == HMAX) hcount <= 11'd0;
		else hcount <= hcount + 1'b1;
		
		if ((hcount == HMAX) && (vcount == VMAX)) vcount <= 11'd0;
		else if (hcount == HMAX) vcount <= vcount + 1'b1;
		
		if ((hcount >= HFP) && (hcount < HSP)) HS <= 1'b0;
		else HS <= 1'b1;
		if ((vcount >= VFP) && (vcount < VSP)) VS <= 1'b0;
		else VS <= 1'b1;
	end
end

// Shows the visible region ie. shows inside VGA size 640x480 
assign video_enable = ((hcount < HLINES) && (vcount < VLINES)) ? 1'b1 : 1'b0; 

endmodule
