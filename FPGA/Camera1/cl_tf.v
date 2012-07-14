`timescale 10ns / 1ns
module cl_tf;
  reg reset, cl_fval, cl_x_pclk, cl_x_lval
    , cl_y_pclk, cl_y_lval, cl_z_pclk, cl_z_lval;
  wire[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  wire[7:0] led8;

	cl uut (reset, cl_fval, cl_x_pclk, cl_x_lval
  , cl_y_pclk, cl_y_lval, cl_z_pclk, cl_z_lval
  , cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
  , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j
  , led8);

	initial begin
		reset = 1'b0;
    #2 reset = 1'b1;//The rising of reset line should trigger the reset logic
    #2 reset = 1'b0;
	end      
endmodule

