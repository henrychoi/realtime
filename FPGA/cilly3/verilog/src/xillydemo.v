`define TRUE 1'b1
`define FALSE 1'b0

module main(input CLK_P, CLK_N, reset
  // These come from Camera Link
  , input cl_fval//, cl_x_lval, cl_x_pclk, , cl_y_pclk, cl_y_lval
    , cl_z_pclk, cl_z_lval
  , input[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j

  // These come from PCIe
  , input PCIE_PERST_B_LS //The host's master bus reset
  //For Virtex-6 a 250 MHz clock, which is derived from the PCIe bus clock,
  //is expected on these wires. If a different clock is applied, the Xilinx
  //PCIe Coregen core (defined by pcie v6 4x.xco in the bundle) must be
  //reconfigured to expect the real clock frequency. Such a change may also
  //involve changes in the constraints.
  , input PCIE_REFCLK_N, PCIE_REFCLK_P
  , input[3:0] PCIE_RX_N, PCIE_RX_P
  , output[3:0] PCIE_TX_N, PCIE_TX_P
  , output[7:0] GPIO_LED // For debugging
);
  wire bus_clk, quiesce, cl_done
     , rd_rden, rd_empty, rd_open, wr_wren, wr_full, wr_open
     , loop_rden, loop_empty, rd_loop_open, loop_full
     , wr_fifo_ack, fpga_msg_valid, wr_fifo_empty, rd_fifo_full;
  wire [31:0] rd_data, wr_data, rd_loop_data, wr_fifo_data;
  wire[127:0] rd_fifo_data;
    
  //If you have a clock signal coming in, if it is routed over a global clock
  //buffer then everything that uses that clock must be after the clock buffer
  //IBUFG dsClkBuf(.O(cl_pclk), .I(cl_z_pclk));

  xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
    , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
    , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
    , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
    , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
    , .bus_clk(bus_clk), .quiesce(quiesce)

    , .user_r_rd_rden(rd_rden), .user_r_rd_empty(rd_empty)
    , .user_r_rd_data(rd_data), .user_r_rd_open(rd_open)
    , .user_r_rd_eof((!wr_fifo_empty && (wr_fifo_data == 0) && rd_empty)
                     || cl_done)
    , .user_w_wr_wren(wr_rden), .user_w_wr_full(wr_full)
    , .user_w_wr_data(wr_data), .user_w_wr_open(wr_open)
    , .user_r_rd_loop_rden(loop_rden), .user_r_rd_loop_empty(loop_empty)
    , .user_r_rd_loop_data(rd_loop_data), .user_r_rd_loop_open(rd_loop_open)
    , .user_r_rd_loop_eof(!wr_open && loop_empty));
  
  xb_wr_fifo(.wr_clk(bus_clk), .rd_clk(cl_z_pclk)//, .rst(reset),
    , .din(wr_data), .wr_en(wr_rden)
    , .rd_en(wr_fifo_ack), .dout(wr_fifo_data)
    , .full(wr_32_full), .empty(wr_fifo_empty));

  xb_rd_fifo(.wr_clk(cl_z_pclk), .rd_clk(bus_clk)//, .rst(reset)
    , .din(rd_fifo_data), .wr_en(fpga_msg_valid && rd_open)
    , .rd_en(rd_rden), .dout(rd_data)
    , .full(rd_fifo_full), .empty(rd_empty));

  xb_loopback_fifo(.clk(bus_clk)//, .rst(reset)
    , .din(wr_fifo_data), .wr_en(wr_fifo_ack)
    , .rd_en(loop_rden), .dout(rd_loop_data)
    , .full(loop_full), .empty(loop_empty));

  cl(.reset(reset), .bus_clk(bus_clk)
    , .pc_msg_pending(!wr_fifo_empty), .pc_msg_ack(wr_fifo_ack)
    , .pc_msg(wr_fifo_data), .fpga_msg_overflow(rd_fifo_full)
    , .fpga_msg(rd_fifo_data), .fpga_msg_valid(fpga_msg_valid)
    , .cl_clk(cl_z_pclk), .cl_lval(cl_z_lval), .cl_fval(cl_fval)
    , .cl_data({cl_port_j, cl_port_i, cl_port_h, cl_port_g, cl_port_f
              , cl_port_e, cl_port_d, cl_port_c, cl_port_b, cl_port_a})
    , .cl_done(cl_done)
    , .led(GPIO_LED[7:5]));
    
  assign GPIO_LED[4] = ~rd_empty;
endmodule
