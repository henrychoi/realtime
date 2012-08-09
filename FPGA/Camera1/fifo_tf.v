`timescale 1ns / 200ps

module fifo_tf;
	reg reset, bus_clk, cl_pclk;
	reg [31:0] wr_in;
  wire[31:0] wr_out;
	reg wr_wren, wr_rden;
	wire wr_full, wr_empty;

	wire [31:0] rd_out;
  reg[63:0] frame_num, line_num;
	reg rd_wren, rd_rden;
	wire rd_full, rd_empty;

	// Instantiate the Unit Under Test (UUT)
	fifo_bram32b xb_wr_fifo(.wr_rst(reset), .rd_rst(reset)
		, .wr_clk(bus_clk), .rd_clk(cl_pclk)
		, .din(wr_in), .wr_en(wr_wren)
		, .rd_en(wr_rden), .dout(wr_out)
    , .full(wr_full), .empty(wr_empty));
    
  fifo_big232 xb_rd_fifo(//.wr_rst(reset), .rd_rst(reset)
		.wr_clk(cl_pclk), .wr_rst(reset) 
		, .rd_clk(bus_clk), .rd_rst(reset)
    , .din({frame_num, line_num}), .wr_en(rd_wren)
    , .rd_en(rd_rden), .dout(rd_out)
    , .full(rd_full), .empty(rd_empty));

	initial begin
		// Initialize Inputs
		bus_clk = 0; cl_pclk = 0;
		wr_in = 0; wr_wren = 0; wr_rden = 0;
    rd_wren = 0; rd_rden = 0;
    frame_num = 64'h100000002; line_num = 64'h300000004;
		reset = 1'b0;
    #10 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
    #14 wr_in = 32'h1234;
    wr_wren = 1'b1;
    #4 wr_wren = 1'b0;
    
    #12 rd_wren = 1;
    #12 rd_wren = 0;
	end

  always #2 bus_clk = ~bus_clk;
  always #6 cl_pclk = ~cl_pclk;
  always @(negedge rd_empty, posedge bus_clk) begin
    if(!rd_empty) rd_rden <= 1;
    else rd_rden <= 0;
  end
endmodule

