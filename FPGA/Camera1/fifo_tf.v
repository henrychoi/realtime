`timescale 1ns / 100ps

module fifo_tf;

	// Inputs
	reg reset;
	reg bus_clk;
	reg cl_pclk;
	reg [31:0] wr_32_data;
	reg wr_32_wren;
	reg rd_en;

	// Outputs
	wire [31:0] dout;
	wire full;
	wire empty;

	// Instantiate the Unit Under Test (UUT)
	fifo_bram32b uut (.srst(reset), .clk(bus_clk)
		//.wr_clk(bus_clk)//, .wr_rst(reset) 
		//, .rd_clk(cl_pclk)//, .rd_rst(reset)
		, .din(wr_32_data), .wr_en(wr_32_wren)
		, .rd_en(rd_en), .dout(dout)
    , .full(full), .empty(empty));

	initial begin
		// Initialize Inputs
		bus_clk = 0;
		cl_pclk = 0;
		wr_32_data = 0;
		wr_32_wren = 0;
		rd_en = 0;
		reset = 1'b0;
    #10 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
    #14 wr_32_data = 32'h1234;
    wr_32_wren = 1'b1;
    #2 wr_32_wren = 1'b0;
	end

  always #2 bus_clk = ~bus_clk;
  always #6 cl_pclk = ~cl_pclk;

endmodule

