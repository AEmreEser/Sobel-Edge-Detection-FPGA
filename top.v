`timescale 1ns / 1ps

module top (clk, rst, BTN_EAST, BTN_WEST, hs, vs, R, G, B, LED1, LED2);

//------------------------------------------------------------------------------
// IO ports
//------------------------------------------------------------------------------
// input
input clk, rst, BTN_EAST, BTN_WEST;
// output
output hs, vs; output reg R; output reg G; output reg B;
output reg LED1; output reg LED2;


//------------------------------------------------------------------------------
// VGA Controller
//------------------------------------------------------------------------------
// VGA display outputs
wire [10:0] hcount;
wire [10:0] vcount;
wire blank;

// VGA controller instantiation
vga_controller vga_cont (
	.clk(clk), 
	.rst(rst), 
	.HS(hs), 
	.VS(vs), 
	.hcount(hcount), 
	.vcount(vcount), 
	.blank(blank));



	wire BTN1, BTN2;
	assign BTN1 = BTN_WEST;
	assign BTN2 = BTN_EAST;

	// Inputs to control unit
	wire op_done;
	wire [7:0] new_px_value;

	// Outputs of control unit
	wire image_generation_complete;
	wire dp_start_signal;
	wire [6:0] pixel_x_coord;
	wire [6:0] pixel_y_coord;
	wire [13:0] write_address;
	wire [7:0] write_data;
	wire write_enable;

	// SOBEL CONTROL UNIT
	sobel_control_unit uut (
		.clk(clk), 
		.rst(rst), 
		.sobel_ctrl_start(BTN1), 
		.op_done(op_done), 
		.new_pixel(new_px_value), 
		.image_generation_complete(image_generation_complete), 
		.dp_start_signal(dp_start_signal), 
		.pixel_x_coord(pixel_x_coord), 
		.pixel_y_coord(pixel_y_coord), 
		.write_address(write_address), 
		.write_data(write_data), 
		.write_enable(write_enable)
	);

	// SOBEL DATAPATH
	sobel_dp DP(
		.rst(rst),
		.clk(clk),
		.input_px_xcoord(pixel_x_coord), // from sobel control
		.input_px_ycoord(pixel_y_coord), // from sobel control
		.dp_start_signal(dp_start_signal),  // from sobel control
		.new_px_value(new_px_value), // to sobel control // WILL BE ON FOR JUST 1 CLK CYCLE UPON SOBEL COMPLETION
		.op_done(op_done) // result of sobel convolution, to control
	);



// TOP STATE PART:
parameter TOP_IDLE = 2'b00;
parameter TOP_BTN1 = 2'b01;
parameter TOP_IMAGE_GEN_COMPLETE = 2'b10;
parameter TOP_BTN2 = 2'b11;
reg [1:0] TOP_STATE;

always @ (posedge clk or posedge rst) begin

	if (rst) begin
		TOP_STATE <= TOP_IDLE;
	end
	else begin
		case (TOP_STATE)
			TOP_IDLE: begin
				if (BTN1) begin
					TOP_STATE <= TOP_BTN1;
				end
				else begin
					TOP_STATE <= TOP_STATE;
				end
			end
			TOP_BTN1: begin
				if (image_generation_complete) begin
					TOP_STATE <= TOP_IMAGE_GEN_COMPLETE;
				end
				else begin
					TOP_STATE <= TOP_STATE;
				end
			end
			TOP_IMAGE_GEN_COMPLETE : begin
				if (BTN2) begin
					TOP_STATE <= TOP_BTN2;
				end
				else begin
					TOP_STATE <= TOP_STATE;
				end
			end
			TOP_BTN2 : begin
				TOP_STATE <= TOP_BTN2;
			end
		endcase
	end // else 

end // always


//------------------------------------------------------------------------------
// LEDs
//------------------------------------------------------------------------------
always @ (posedge clk or posedge rst) 
begin
	if(rst) begin
		LED1 <= 0;
		LED2 <= 0;
	end
	else begin
		// if current state is OP_FINISHED, turn on LED1
		if(TOP_STATE == TOP_IMAGE_GEN_COMPLETE) begin
			LED1 <= 1;
			LED2 <= 0;		
		end
		// if BTN_EAST is pressed, turn on both LED1 and LED2
		else if(TOP_STATE == TOP_BTN2) begin
			LED1 <= 1;
			LED2 <= 1;
		end
		// otherwise, both LEDs should be OFF
		else begin
			LED1 <= 0;
			LED2 <= 0;
		end
	end
end

	
	// inputs/ outputs of output bram
	reg [13:0] output_bram_read_address; // input
	wire [7:0] output_bram_read_data; // output

	block_ram output_bram(
		// INPUTS
		.clk(clk), .write_en(write_enable),
		.read_addr(output_bram_read_address), .write_addr(write_address), .write_data(write_data), 
		//OUTPUT
		.data_out(output_bram_read_data)
	);
	
	// inputs/ outputs of lena bram
	wire [7:0] lena_data_top; // output
	reg [13:0] lena_read_addr_top; // input

	lena_input lena_in(
		.addra(lena_read_addr_top),
		.clka(clk),
		.douta(lena_data_top)
	);



always @ (*)
begin
	// Read address generation for input (input image will be displayed at upper-left corner (128x128)
	if ((vcount < 10'd128) && (hcount < 10'd128))
		lena_read_addr_top = {vcount[6:0], hcount[6:0]};
	else 
		lena_read_addr_top = 14'd0; // Read address uses hcount and vcount from VGA controller as read address to locate currently displayed pixel
	
	// read address generation for output (output image will be displayed at next to input image (128x128)
	if ((vcount < 10'd128) && ((hcount >= 10'd128) && (hcount < 10'd256))) begin
		output_bram_read_address = {vcount[6:0], hcount[6:0]};
	end
	else 
		output_bram_read_address = 0;
	
	
	// Read pixel values 
	if (blank) 
	begin	
		R = 1'b0;  // if blank, color outputs should be reset to 0 or black should be sent ot R,G,B ports
		G = 1'b0;  // if blank, color outputs should be reset to 0 or black should be sent ot R,G,B ports
		B = 1'b0;  // if blank, color outputs should be reset to 0 or black should be sent ot R,G,B ports
	end
	// if operation is finished or BTN2 is pressed, display input image
	else if ((vcount < 10'd128) && (hcount < 10'd128) && (((TOP_STATE == TOP_IMAGE_GEN_COMPLETE)) | (TOP_STATE == TOP_BTN2)) ) 
	begin
		R = lena_data_top[7];  // pixel values are read here
		G = lena_data_top[7];
		B = lena_data_top[7];
		
	end
	// if BTN2 is pressed, display output image
	else if ((vcount < 10'd128) && ((hcount >= 10'd128) && (hcount < 10'd256)) && (TOP_STATE == TOP_BTN2)) 
	begin
		R = output_bram_read_data[7];  // pixel values are read here
		G = output_bram_read_data[7];
		B = output_bram_read_data[7];
	end
	else
	begin
		R = 1'b1; // outside of the image is white
		G = 1'b1; // outside of the image is white
		B = 1'b1; // outside of the image is white
	end
end


endmodule
