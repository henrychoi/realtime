`timescale 100ps / 10ps

module sim;
  reg CLK_P, CLK_N;
  reg reset, bus_clk;
  reg[1:0] n_busclk;
  reg[31:0] wr_fifo_data;
  reg wr_fifo_empty;
  wire rd_fifo_full, rd_fifo_rden;
  wire[7:5] GPIO_LED;
`include "function.v"
`include "camera.v"
    
  xb_rd_fifo_bram rd_fifo(.wr_clk(cl_z_pclk), .rd_clk(bus_clk)//, .rst(reset)
    , .din(rd_fifo_data), .wr_en(fpga_msg_valid)
    , .rd_en(rd_fifo_rden), .dout(rd_data)
    , .full(rd_fifo_full), .empty(rd_empty));

  cl cl(.reset(reset), .bus_clk(bus_clk)
    , .pc_msg_pending(!wr_fifo_empty), .pc_msg_ack(wr_fifo_ack)
    , .pc_msg(wr_fifo_data), .fpga_msg_full(rd_fifo_full)
    , .fpga_msg(rd_fifo_data), .fpga_msg_valid(fpga_msg_valid)
    , .cl_clk(cl_z_pclk), .cl_lval(cl_z_lval), .cl_fval(cl_fval)
    , .cl_port_a(cl_port_a), .cl_port_b(cl_port_b), .cl_port_c(cl_port_b)
    , .cl_port_d(cl_port_d), .cl_port_e(cl_port_e), .cl_port_f(cl_port_f)
    , .cl_port_g(cl_port_g), .cl_port_h(cl_port_h), .cl_port_i(cl_port_i)
    , .cl_port_j(cl_port_j)
    , .led(GPIO_LED));
    
	initial begin
		reset = `FALSE; bus_clk = `FALSE; CLK_P = 0; CLK_N = 1;

#10 reset = `TRUE;
    wr_fifo_empty = `TRUE;
#20 reset = `FALSE;
#90 wr_fifo_data = 32'h001_00002;
    wr_fifo_empty = `FALSE;
	end
  
  always @(posedge bus_clk) if(wr_fifo_ack) wr_fifo_empty = `TRUE;
  always #40 bus_clk = ~bus_clk;
  always begin
    #25 CLK_N = ~CLK_N; CLK_P = ~CLK_P;
  end
  //assign cl_fval = n_clclk < 16'd65000;
  //assign cl_z_lval = n_clclk[9:0] < 10'd1000;
  assign rd_fifo_rden = n_busclk != 0;
  always @(posedge reset, posedge bus_clk)
    if(reset) n_busclk <= 0;
    else n_busclk <= n_busclk + 1'b1;
endmodule
