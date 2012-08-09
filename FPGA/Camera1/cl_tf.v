`timescale 1ns / 200ps
`define TRUE 1'b1
`define FALSE 1'b0

module cl_tf;
`include "function.v"
  reg cl_fval // Let's say this ticks at 10 ms period
    //, cl_x_lval, cl_x_pclk, 
    //, cl_y_pclk, cl_y_lval
    , cl_z_pclk, cl_z_lval; // cl_z_pclk 85 MHz
  reg[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
         , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  reg bus_clk, reset;// bus_clk ticks at 250 MHz
  wire cl_pclk, cl_lval;
  
	initial begin
    bus_clk = 1'b0; cl_z_pclk = 1'b0;
    frame_num = 0; line_num = 0; clk_count = 0;
    cl_z_lval = `FALSE;
    cl_fval = `FALSE;
    wr_32_wren = `FALSE;
		reset = `FALSE;
    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
    cl_port_a = 8'h1A; cl_port_b = 8'h1B; cl_port_c = 8'h1C; cl_port_d = 8'h1D;
    cl_port_e = 8'h1E; cl_port_f = 8'h1F; cl_port_g = 8'h09; cl_port_h = 8'h06;
    cl_port_i = 8'h01; cl_port_j = 8'h07;

    #16 wr_32_data = 32'h1;
    #6 wr_32_wren = `TRUE;
    #4 wr_32_wren = `FALSE;
    cl_fval = `TRUE;
    cl_z_lval = `TRUE;
	end
  
  always #2 bus_clk = ~bus_clk;
  always #6 cl_z_pclk = ~cl_z_pclk;

endmodule

