`define TRUE 1'b1
`define FALSE 1'b0
`timescale 1ns / 200ps

module sim;
  reg cl_fval//, cl_x_lval, cl_x_pclk, , cl_y_pclk, cl_y_lval
    , cl_z_pclk, cl_z_lval;
  reg[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  reg reset, bus_clk;
  reg[31:0] wr_fifo_data;
  wire wr_fifo_ack, rd_fifo_wren;
  reg wr_fifo_empty, rd_fifo_full;
  wire[127:0] rd_fifo_data;
  wire[7:5] GPIO_LED;

  cl cl(.reset(reset), .bus_clk(bus_clk)
    , .pc_msg_pending(!wr_fifo_empty), .pc_msg_ack(wr_fifo_ack)
    , .pc_msg(wr_fifo_data), .fpga_msg_overflow(rd_fifo_full)
    , .fpga_msg(rd_fifo_data), .fpga_msg_valid(rd_fifo_wren)
    , .cl_clk(cl_z_pclk), .cl_lval(cl_z_lval), .cl_fval(cl_fval)
    , .cl_data({cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f
              , cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a})
    , .led(GPIO_LED));
    
	initial begin
		reset = `FALSE; bus_clk = `FALSE; cl_z_pclk = `TRUE;
    cl_fval = `FALSE; cl_z_lval = `FALSE;

#2  reset = `TRUE;
    wr_fifo_empty = `TRUE;
#2  reset = `FALSE;
    cl_port_a = 8'h1A; cl_port_b = 8'h1B; cl_port_c = 8'h1C; cl_port_d = 8'h1D;
    cl_port_e = 8'h1E; cl_port_f = 8'h1F; cl_port_g = 8'h09; cl_port_h = 8'h06;
    cl_port_i = 8'h01; cl_port_j = 8'h07;

#4  wr_fifo_data = 32'h001_00001;
    wr_fifo_empty = `FALSE;
	end
  
  always @(posedge bus_clk) if(wr_fifo_ack) wr_fifo_empty = `TRUE;
  always #2 bus_clk = ~bus_clk;
  always #6 cl_z_pclk = ~cl_z_pclk;
  
  always begin
    #1200 cl_fval = `TRUE; cl_fval <= #1176 `FALSE;
  end
  always begin
    #120 cl_z_lval = `TRUE; cl_z_lval <= #96 `FALSE;
  end
endmodule
