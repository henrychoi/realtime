`include "cl.v"
module main(input CLK_P, CLK_N, reset
  // These come from Camera Link
  , input cl_fval//, cl_x_lval, cl_x_pclk, 
    //, cl_y_pclk, cl_y_lval
    , cl_z_pclk, cl_z_lval
  , input[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j
  // Copied from Xillydemo
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
  //, output[4:0] led5
);
`include "function.v"
  reg[log2(`MAX_STATE)-1:0] state;
  wire bus_clk, quiesce;
  wire cl_pclk, cl_lval;
  
`define FRAME_NUM_SIZE 20
  reg[`FRAME_NUM_SIZE-1:0] frame_num;
`define LINE_NUM_SIZE 12 // Enough for 1080 lines from Andor camera
  reg[`LINE_NUM_SIZE-1:0] line_num;

  wire[31:0] pc_msg32;

  wire rd_32_rden, rd_32_empty, rd_32_open;
  wire [31:0] rd_32_data;
  wire wr_32_wren, wr_32_full, wr_32_open;
  wire [31:0] wr_32_data;
  wire[31:0] rd_loop_data;
  wire loop_rden, loop_empty, rd_loop_open, loop_full, wr_loop_open;

  reg pc_msg32_ack; //send ACK into FIFO to clear incoming data
  wire pc_msg32_empty, xb_rd_fifo_full;
    
  xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
    , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
    , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
    , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
    , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
    , .bus_clk(bus_clk), .quiesce(quiesce)

    , .user_r_rd_rden(rd_32_rden)  // /dev/xillybus_read_32
    , .user_r_rd_empty(rd_32_empty)// FPGA to CPU signals
    , .user_r_rd_data(rd_32_data)
    , .user_r_rd_eof(!pc_msg32_empty && (pc_msg32 == 0)) //Use this to indicate error
    , .user_r_rd_open(rd_32_open)
    , .user_w_wr_wren(wr_32_rden) // /dev/xillybus_write_32
    , .user_w_wr_full(wr_32_full) // CPU to FPGA signals
    , .user_w_wr_data(wr_32_data)
    , .user_w_wr_open(wr_32_open)

    , .user_r_rd_loop_rden(loop_rden),
    .user_r_rd_loop_empty(loop_empty),
    .user_r_rd_loop_data(rd_loop_data),
    .user_r_rd_loop_eof(!wr_32_open),
    .user_r_rd_loop_open(rd_loop_open),
    .user_w_wr_loop_wren(loop_wren),
    .user_w_wr_loop_full(loop_full),
    .user_w_wr_loop_data(wr_loop_data),
    .user_w_wr_loop_open(wr_loop_open)
    );
  
  fifo_32b xb_wr_fifo(.rst(reset), .wr_clk(bus_clk), .rd_clk(cl_x_pclk)
    , .din(wr_32_data), .wr_en(wr_32_rden)
    , .rd_en(pc_msg32_ack), .dout(pc_msg32)
    , .full(wr_32_full), .empty(pc_msg32_empty));

  fifo_big232 xb_rd_fifo(.rst(reset), .wr_clk(cl_pclk), .rd_clk(bus_clk)
    , .din({12'h0, frame_num
          , cl_port_b, cl_port_a, 4'b0, line_num
          , cl_port_f, cl_port_e, cl_port_d, cl_port_c
          , cl_port_j, cl_port_i, cl_port_h, cl_port_g}) 
    , .wr_en(cl_lval && state == `CAPTURING)
    , .rd_en(rd_32_rden), .dout(rd_32_data)
    , .full(xb_rd_fifo_full), .empty(rd_32_empty));

  //If you have a clock signal coming in, if it is routed over a global clock
  //buffer then everything that uses that clock must be after the clock buffer
  //IBUFG dsClkBuf(.O(cl_pclk), .I(cl_z_pclk));
  
  assign cl_lval = cl_z_lval;
  assign cl_pclk = cl_z_pclk;
  
  // GPIO_LED[0:3] are used by Xillybus
  assign GPIO_LED[7:4] = {wr_32_full, !rd_32_empty, wr_32_open, rd_32_open};
  //I cannot place this for some reason
  //assign led5 = {1'b1, fval_lval, frame_num[`FRAME_NUM_SIZE-1]};
  // {cl_x_pclk == cl_y_pclk, cl_y_pclk == cl_z_pclk
  //                      , cl_x_lval == cl_y_lval, cl_y_lval == cl_z_lval};

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg32_ack <= `FALSE;
      state <= `STANDBY;
      //fval_lval <= 3'b000;
    end else begin
      pc_msg32_ack <= `FALSE;
      
      if(!pc_msg32_empty && !pc_msg32_ack) begin
        if(pc_msg32 == 32'h01020304) state <= `ARMED;
        pc_msg32_ack <= `TRUE;
      end
    end//posedge clk
  end//always

  always @(posedge reset, posedge cl_fval) begin
    if(reset) frame_num <= 0;
    else frame_num <= frame_num + 1'b1;
    //Q: does LVAL go high with FVAL?
    //fval_lval <= {cl_x_lval, cl_y_lval, cl_z_lval};
  end//always

  always @(posedge cl_fval, posedge cl_lval) begin
    if(cl_fval) line_num <= 0;
    else line_num <= line_num + 1'b1;
  end//always

endmodule
