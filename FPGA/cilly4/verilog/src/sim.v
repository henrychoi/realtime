`define TRUE 1'b1
`define FALSE 1'b0
`timescale 100ps / 10ps

module sim;
  reg CLK_P, CLK_N;
  wire cl_fval//, cl_x_lval, cl_x_pclk, , cl_y_pclk, cl_y_lval
    , cl_z_pclk, cl_z_lval;
  reg[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j;
  reg reset, bus_clk;
  reg[1:0] n_busclk;
  reg[31:0] wr_fifo_data;
  wire wr_fifo_ack, fpga_msg_valid, rd_empty;
  reg wr_fifo_empty;
  wire rd_fifo_full, rd_fifo_rden;
  wire[127:0] rd_fifo_data;
  wire[7:5] GPIO_LED;
  localparam N_CLCLK_SIZE = 16;
  reg[N_CLCLK_SIZE-1:0] n_clclk;
    
  clock85MHz dsClkBuf(.CLK_IN1_P(CLK_P), .CLK_IN1_N(CLK_N)//, .RESET(reset)
    , .CLK_OUT1(cl_z_pclk));

  xb_rd_fifo rd_fifo(.wr_clk(cl_z_pclk), .rd_clk(bus_clk)//, .rst(reset)
    , .din(rd_fifo_data), .wr_en(fpga_msg_valid)
    , .rd_en(rd_fifo_rden), .dout(rd_data)
    , .full(rd_fifo_full), .empty(rd_empty));

  cl cl(.reset(reset), .bus_clk(bus_clk)
    , .pc_msg_pending(!wr_fifo_empty), .pc_msg_ack(wr_fifo_ack)
    , .pc_msg(wr_fifo_data), .fpga_msg_full(rd_fifo_full)
    , .fpga_msg(rd_fifo_data), .fpga_msg_valid(fpga_msg_valid)
    , .cl_clk(cl_z_pclk), .cl_lval(cl_z_lval), .cl_fval(cl_fval)
    , .cl_data_top({cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a})
    , .cl_data_btm({cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f})
    , .led(GPIO_LED));
    
	initial begin
		reset = `FALSE; bus_clk = `FALSE; CLK_P = 0; CLK_N = 1;

#10 reset = `TRUE;
    wr_fifo_empty = `TRUE;
#20 reset = `FALSE;
#20 wr_fifo_data = 32'h001_00001;
    wr_fifo_empty = `FALSE;
	end
  
  always @(posedge bus_clk) if(wr_fifo_ack) wr_fifo_empty = `TRUE;
  always #20 bus_clk = ~bus_clk;
  always begin
    #25 CLK_N = ~CLK_N; CLK_P = ~CLK_P;
  end
  assign cl_fval = n_clclk < 16'd65000;
  assign cl_z_lval = n_clclk[9:0] < 10'd1000;
  assign rd_fifo_rden = n_busclk != 0;
  always @(posedge reset, posedge bus_clk)
    if(reset) n_busclk <= 0;
    else n_busclk <= n_busclk + 1'b1;
  
  always @(posedge reset, posedge cl_z_pclk)
    if(reset) begin
      n_clclk <= ~0 - 1'b1;
      cl_port_a <= 8'h0A;
      cl_port_b <= 8'h0B;
      cl_port_c <= 8'h0C;
      cl_port_d <= 8'h0D;
      cl_port_e <= 8'h0E;
      cl_port_f <= 8'h0F;
      cl_port_g <= 8'h09;
      cl_port_h <= 8'h06;
      cl_port_i <= 8'h01;
      cl_port_j <= 8'h07;
    end else begin
      n_clclk <= n_clclk + 1'b1;
      cl_port_a[4] <= ~cl_port_a[4];
      cl_port_b[4] <= ~cl_port_b[4];
      cl_port_c[4] <= ~cl_port_c[4];
      cl_port_d[4] <= ~cl_port_d[4];
      cl_port_e[4] <= ~cl_port_e[4];
      cl_port_f[4] <= ~cl_port_f[4];
      cl_port_g[4] <= ~cl_port_g[4];
      cl_port_h[4] <= ~cl_port_h[4];
      cl_port_i[4] <= ~cl_port_i[4];
      cl_port_j[4] <= ~cl_port_j[4];
    end
endmodule
