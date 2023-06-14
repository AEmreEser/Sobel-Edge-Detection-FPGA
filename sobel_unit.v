`timescale 1ns / 1ps

module sobel_control_unit(

input clk,
input rst,
input sobel_ctrl_start, // BTN1
input op_done, // from sobel datapath
input [7:0] new_pixel, // from sobel datapath --> only valid when op_done is set

output reg image_generation_complete, // to top

output reg dp_start_signal, // to dp
output reg [7:0] pixel_x_coord, // to dp
output reg [7:0] pixel_y_coord, // to dp

output reg [13:0] write_address, // to bram
output reg [7:0] write_data, // to bram
output reg write_enable // to bram

);

reg [13:0] internal_bram_address; // set inside xcoord, ycoord update always block

always @ (posedge clk or posedge rst) begin

	if (rst) begin
		write_address <= 14'b0;
		write_data <= 8'd255;
		write_enable <= 0;
	end
	else if (op_done) begin // new px won't be buffered, will be directly fetched from input
		write_enable <= 1;
		write_address <= internal_bram_address;
		// write_data <= new_pixel;
		
		if (new_pixel >= 8'd150) begin
			write_data <= 8'b0;
		end
		else begin
			write_data <= 8'd255;
		end
		
	end // op_done
	else begin
		write_enable <= 0;
		write_address <= write_address;
		write_data <= write_data;
	end

end
	 
parameter SOBEL_CTRL_IDLE = 2'b0;
parameter SOBEL_CTRL_WORKING = 2'b01;
parameter SOBEL_CTRL_COMPLETELY_DONE = 2'b10;
parameter SOBEL_CTRL_DONE_SLEEP = 2'b11;	 

reg [1:0] SOBEL_CTRL_STATE;

wire [7:0] x_coord_plus; assign x_coord_plus = pixel_x_coord + 1;
wire [7:0] y_coord_plus; assign y_coord_plus = pixel_y_coord + 1;
	 
always @ (posedge clk or posedge rst) begin

	if (rst) begin
		SOBEL_CTRL_STATE <= 2'b0;
		pixel_x_coord <= 7'b0;
		pixel_y_coord <= 7'b0;
		image_generation_complete <= 1'b0;
		internal_bram_address <= 14'b0;
		dp_start_signal <= 1'b0;
	end
	else begin
	
		case (SOBEL_CTRL_STATE) 
		
			SOBEL_CTRL_IDLE : begin
				if (sobel_ctrl_start) begin
					SOBEL_CTRL_STATE <= SOBEL_CTRL_WORKING;
					image_generation_complete <= 1'b0;
				end
				else SOBEL_CTRL_STATE <= SOBEL_CTRL_STATE;
			
			end
			
			SOBEL_CTRL_WORKING : begin
			
				if (op_done) begin
					
					if (pixel_x_coord == 8'd128 && pixel_y_coord == 8'd128) begin
						pixel_x_coord <= 8'b0;
						pixel_y_coord <= 8'b0;
						internal_bram_address <= 14'b0;
						dp_start_signal <= 1'b0; // end sobel for entire image
						SOBEL_CTRL_STATE <= SOBEL_CTRL_COMPLETELY_DONE;
					end
					else if (pixel_x_coord == 8'd128) begin
						pixel_x_coord <= 8'b0;
						pixel_y_coord <= pixel_y_coord + 1;
						
						internal_bram_address <= { y_coord_plus[6:0] ,7'b0};
						
						dp_start_signal <= 1'b1; // continue sobel
						SOBEL_CTRL_STATE <= SOBEL_CTRL_STATE;
					end
					else begin
						pixel_x_coord <= pixel_x_coord + 1;
						pixel_y_coord <= pixel_y_coord;
						
						internal_bram_address <= { pixel_y_coord[6:0] , x_coord_plus[6:0] };
						
						dp_start_signal <= 1'b1; // continue sobel
						SOBEL_CTRL_STATE <= SOBEL_CTRL_STATE;
					end
			
				end // op_done
				else begin
					pixel_x_coord <= pixel_x_coord;
					pixel_y_coord <= pixel_y_coord;
					dp_start_signal <= 1'b1;
					SOBEL_CTRL_STATE <= SOBEL_CTRL_STATE;
				end
				
			end
			
			SOBEL_CTRL_COMPLETELY_DONE : begin
	
				SOBEL_CTRL_STATE <= SOBEL_CTRL_DONE_SLEEP; // MIGHT BE REDUNDANT????!!!!!
			
			end
			default begin // SOBEL_CTRL_DONE_SLEEP
			
				image_generation_complete <= 1'b1; // signal out to top module
				SOBEL_CTRL_STATE <= SOBEL_CTRL_STATE;			
			end
		
		endcase
	
	
	end // else: rst



end 


endmodule




module sobel_dp(
input rst,
input clk,
input [7:0] input_px_xcoord, // from sobel control
input [7:0] input_px_ycoord, // from sobel control
input dp_start_signal,  // from sobel control

output reg [7:0] new_px_value, // result of sobel convolution, to control
output reg op_done // to sobel control // WILL BE ON FOR JUST 1 CLK CYCLE UPON SOBEL COMPLETION

);


wire [7:0]  data_out;		// lena input BRAM pixel output
reg [13:0]  lena_address;
  
// Block RAM instantiation
lena_input lena_in(
	.addra(lena_address),
	.clka(clk),
	.douta(data_out));

// reg [2:0] DP_STATE; parameter DP_IDLE = 2'b0; parameter DP_WORKING = 2'b01; parameter DP_DONE = 2'b10;
reg [3:0] SOBEL_STATE; 			parameter SOBEL_IDLE = 0; 
parameter SOBEL_INIT = 1; parameter SOBEL_11 = 2; parameter SOBEL_12 = 3; parameter SOBEL_13 = 4;
parameter SOBEL_21 = 5; parameter SOBEL_22 = 6; parameter SOBEL_23 = 7; parameter SOBEL_31 = 8;
parameter SOBEL_32 = 9; parameter SOBEL_33 = 10; parameter SOBEL_END_DELAY = 11; parameter SOBEL_END = 12;

reg signed [10:0] sobel_x_val; reg signed [10:0] sobel_y_val; 
wire signed [10:0] sobel_x_val_complement; wire signed [10:0] sobel_y_val_complement;
assign sobel_x_val_complement = ~(sobel_x_val) + 1; assign sobel_y_val_complement = ~(sobel_y_val) + 1;
reg signed [8:0] sobel_row_cursor;  reg signed [8:0] sobel_col_cursor;
reg signed [8:0] sobel_row_index; reg signed [8:0] sobel_col_index;
wire signed[8:0] row_addr_extended; wire signed[8:0] col_addr_extended;
assign row_addr_extended = {2'sb0, input_px_ycoord[6:0]};  assign col_addr_extended = {2'sb0, input_px_xcoord[6:0]};
wire [8:0] data_out_times_two; wire signed[8:0] data_out_complement;
wire signed[9:0] complement_times_two; wire signed [8:0] row_addr_minus;
wire signed [8:0] col_addr_minus; wire signed [8:0] row_addr_plus;
wire signed [8:0] col_addr_plus;
assign row_addr_minus = row_addr_extended - 9'sb0_0000_0001; assign col_addr_minus = col_addr_extended - 9'sb0_0000_0001;
assign row_addr_plus = row_addr_extended + 9'sb0_0000_0001; assign col_addr_plus = col_addr_extended + 9'sb0_0000_0001;
assign data_out_times_two = (data_out << 1);  assign data_out_complement = ~(data_out) + 1;
assign complement_times_two = (data_out_complement << 1);

 
always @ (posedge clk or posedge rst) begin

if (rst) begin

	op_done <= 1'b0;
	new_px_value <= 8'd255;
	SOBEL_STATE <= 4'b0;
	lena_address <= 14'b0;
	SOBEL_STATE <= SOBEL_IDLE;
	new_px_value <= 8'b0;
	sobel_x_val <= 11'sb0;
	sobel_y_val <= 11'sb0;
	sobel_row_cursor <= 9'sb0;
	sobel_col_cursor <= 9'sb0;
	sobel_row_index <= 9'sb0;
	sobel_col_index <= 9'sb0;
	
end
else if (dp_start_signal) begin

	case (SOBEL_STATE) // case names represent what value in the multiplication area of the image are available @ data_out
	
	SOBEL_IDLE: begin // fetch 11
	
					// first row first column
					
					sobel_row_cursor <= row_addr_minus;
					sobel_col_cursor <= col_addr_minus;
					
					sobel_x_val <= 11'sb0;
					sobel_y_val <= 11'sb0;
	
					end
					
	SOBEL_INIT: begin
					
					sobel_x_val <= sobel_x_val;
					sobel_y_val <= sobel_y_val;
					
					sobel_row_cursor <= (row_addr_minus); // first row
					sobel_col_cursor <= (col_addr_extended); // second column
	
					end
	SOBEL_11: begin
					
					sobel_x_val <= ( sobel_x_val + ( ( sobel_row_index == -1 || sobel_col_index == -1) ? ( 11'sb0 ) : ( data_out_complement ) )   ); // mult by -1, add to x val
					sobel_y_val <= ( sobel_y_val + ( ( sobel_row_index == -1 || sobel_col_index == -1) ? ( 11'sb0 ) : data_out )   );
					
					sobel_row_cursor <= (row_addr_minus); // first row
					sobel_col_cursor <= (col_addr_plus); // third column

	
				end
	SOBEL_12: begin
					sobel_x_val <=  sobel_x_val; // mult by 0, add to x val;
					sobel_y_val <= ( sobel_y_val + ( (sobel_row_index == -1) ? (11'sb0) : ( data_out_times_two ) ) );
					
					sobel_row_cursor <= (row_addr_extended); // second row
					sobel_col_cursor <= (col_addr_minus); // first col

	
	
				end
	SOBEL_13: begin
					sobel_x_val <= ( sobel_x_val + ( ( sobel_row_index == -1 || sobel_col_index == 128) ? ( 11'sb0 ) : ( (data_out) ) )   ); // mult by 1, add to x val
					
					sobel_y_val <= (  sobel_y_val + ( ( sobel_row_index == -1 || sobel_col_index == 128) ? (11'sb0) : (data_out) )  );
					
				sobel_row_cursor <= (row_addr_extended);
				sobel_col_cursor <= (col_addr_extended);

					
				end
	SOBEL_21: begin
	
				sobel_x_val <= ( sobel_x_val + ( ( sobel_col_index == -1) ? ( 11'sb0 ) : ( complement_times_two ) )   ); // mult by -2, add to x val
				
				sobel_y_val <=  sobel_y_val;
				
				sobel_row_cursor <= (row_addr_extended);
				sobel_col_cursor <= (col_addr_plus);

				end
	SOBEL_22: begin
				sobel_x_val <= sobel_x_val; // mult by 0
				sobel_y_val <= sobel_y_val;
				
				sobel_row_cursor <= (row_addr_plus);
				sobel_col_cursor <= (col_addr_minus);

	
				end
	SOBEL_23: begin
				sobel_x_val <= (   sobel_x_val + ( (sobel_col_index == 128) ? (11'sb0) : ( data_out_times_two ) )   ); // mult by 2
				
				sobel_y_val <= sobel_y_val;
				
				sobel_row_cursor <= (row_addr_plus);
				sobel_col_cursor <= (col_addr_extended);

	
				end
	SOBEL_31: begin
				
				sobel_x_val <= (   sobel_x_val + ( ( sobel_row_index == 128 || sobel_col_index == -1 ) ? (11'sb0) : ( data_out_complement ) )   ); // mult by -1
				sobel_y_val <= (   sobel_y_val + ( ( sobel_row_index == 128 || sobel_col_index == -1 ) ? (11'sb0) : ( data_out_complement ) )   );
				
				sobel_row_cursor <= (row_addr_plus);
				sobel_col_cursor <= (col_addr_plus);

	
				end
	SOBEL_32: begin
				sobel_x_val <= sobel_x_val; // added 0
				sobel_y_val <= (   sobel_y_val + ( ( sobel_row_index == 128 ) ? (11'sb0) : ( complement_times_two ) )  );


				end
	SOBEL_33: begin
				sobel_x_val <= (   sobel_x_val + ( (sobel_row_index == 128 || sobel_col_index == 128) ? (11'sb0) : (data_out) )   );
				
				sobel_y_val <= (   sobel_y_val + ( (sobel_row_index == 128 || sobel_col_index == 128 ) ? (11'sb0) : ( data_out_complement ) )   );

	
				end
	SOBEL_END_DELAY: begin
	
				sobel_x_val <= sobel_x_val;
				sobel_y_val <= sobel_y_val;
				
				new_px_value <= ( ( (sobel_x_val[10]) ? ( sobel_x_val_complement[7:0] ) : (sobel_x_val[7:0]) )  + ( (sobel_y_val[10]) ? ( sobel_x_val_complement[7:0]) : (sobel_y_val[7:0]) )  );
				
				end				
	SOBEL_END: begin
				// final x_val and y_val values are available here at the earliest
	

				end	
	default: begin 
	
				sobel_x_val <= sobel_x_val;  
				sobel_y_val <= sobel_y_val;
	
				end
	endcase
	
	sobel_row_index <= sobel_row_cursor;
	sobel_col_index <= sobel_col_cursor;  
	lena_address <= { sobel_row_cursor[6:0], sobel_col_cursor[6:0] };
	SOBEL_STATE <= (SOBEL_STATE != SOBEL_END) ? (SOBEL_STATE + 1) : (SOBEL_IDLE);
	
	op_done <= ( (SOBEL_STATE == SOBEL_END) ? (1'b1) : (1'b0) ); // WILL BE ON FOR JUST 1 CLK CYCLE UPON SOBEL COMPLETION
	
	
end // dp_start_signal
else begin


end


end


endmodule
