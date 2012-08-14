`timescale 100ps / 100ps

module sim;
  `include "function.v"
  reg CLK_P, CLK_N, reset;
  reg[31:0] wr_fifo_data;
  reg wr_fifo_empty;
  wire pc_msg_ack;
  wire cl_fval, cl_z_lval, cl_z_pclk;
  wire[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
          , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  wire[3:0] led;

  application#(.SIMULATION(1))
    app(CLK_P, CLK_N, reset
    , pc_msg_ack, !wr_fifo_empty, wr_fifo_data
    , led);

	initial begin
		reset = `FALSE; CLK_P = 0; CLK_N = 1;
#10 reset = `TRUE;
#20 reset = `FALSE;
#90 wr_fifo_data = 32'h002_00003;
    wr_fifo_empty = `FALSE;
  end
  
  always begin
    #25 CLK_N = ~CLK_N; CLK_P = ~CLK_P;
  end
  
  always @(posedge pc_msg_ack) wr_fifo_empty <= `TRUE;
endmodule
