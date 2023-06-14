module block_ram (	//INPUTS
						clk, write_en,
						read_addr, write_addr, write_data, 
						//OUTPUT
						data_out );

parameter DATA_SIZE = 8;	// # of bits for the input/output data
parameter ADDR_SIZE = 14;	// # of bits for the input/output address
parameter DATA_ELMT = 128*128;	// # of data elements to be stored in the block ram
								
input clk;
input write_en;
input [ADDR_SIZE-1:0] read_addr, write_addr; //, debug_addr;
input [DATA_SIZE-1:0] write_data;

output [DATA_SIZE-1:0] data_out; //, debug_data_out;

reg [DATA_SIZE-1:0] reg_file[0:DATA_ELMT-1];

reg [ADDR_SIZE-1:0] read_addr_d;
assign data_out = reg_file[read_addr_d]; // modified: old rhs val: reg_file[read_addr_d]

always @ (posedge clk)
begin
	read_addr_d <= read_addr[ADDR_SIZE-1:0];
	if (write_en) begin  
		reg_file[write_addr[ADDR_SIZE-1:0]] <= write_data;
		$strobe("new value of regFile address %b : %b", write_addr, reg_file[write_addr[ADDR_SIZE-1:0]]);
	end

end


endmodule
