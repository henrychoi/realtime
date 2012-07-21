`define TRUE 1'b1
`define FALSE 1'b0

module xillydemo(input CLK_P, CLK_N, reset
  ,input  PCIE_PERST_B_LS
  ,input  PCIE_REFCLK_N, PCIE_REFCLK_P
  ,input [3:0] PCIE_RX_N, PCIE_RX_P
  ,output [3:0] PCIE_TX_N, PCIE_TX_P
  ,output [7:0] GPIO_LED);

  //Xillybus signals
  wire 	bus_clk, quiesce;
  wire rd_32_rden, rd_32_empty, rd_32_open;
  wire [31:0] rd_32_data;
  wire wr_32_wren, wr_32_full, wr_32_open;
  wire [31:0] wr_32_data;

  wire[31:0] rd_loop_data, wr_loop_data;
  wire loop_rden, loop_empty, loop_eof, rd_loop_open, loop_wren, loop_full
    , wr_loop_open;

  reg pc_msg32_ack; // Command from the PC to FPGA
  wire[31:0] pc_msg32;
  wire pc_msg32_empty;
  wire xb_rd_fifo_full;
  reg[31:0] n_frame;
  
  //IBUFGDS dsClkBuf(.O(clk), .I(CLK_P), .IB(CLK_N));
  
   xillybus xillybus_ins (
    // Ports related to /dev/xillybus_rd
    // FPGA to CPU signals:
    .user_r_rd_rden(rd_32_rden),
    .user_r_rd_empty(rd_32_empty),
    .user_r_rd_data(rd_32_data),
    .user_r_rd_eof(!pc_msg32_empty && (pc_msg32 == 0)),
    .user_r_rd_open(rd_32_open),

    // Ports related to /dev/xillybus_wr
    // CPU to FPGA signals:
    .user_w_wr_wren(wr_32_wren),
    .user_w_wr_full(wr_32_full),
    .user_w_wr_data(wr_32_data),
    .user_w_wr_open(wr_32_open),

    .user_r_rd_loop_rden(loop_rden),
    .user_r_rd_loop_empty(loop_empty),
    .user_r_rd_loop_data(rd_loop_data),
    .user_r_rd_loop_eof(loop_eof),
    .user_r_rd_loop_open(rd_loop_open),
    .user_w_wr_loop_wren(loop_wren),
    .user_w_wr_loop_full(loop_full),
    .user_w_wr_loop_data(wr_loop_data),
    .user_w_wr_loop_open(wr_loop_open),

    // Signals to top level
    .PCIE_PERST_B_LS(PCIE_PERST_B_LS),
    .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P),
    .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P),
    .GPIO_LED(GPIO_LED[3:0]),
    .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P),
    .bus_clk(bus_clk), .quiesce(quiesce));

  xb_wr_fifo xb_wr_fifo(.rst(reset), .clk(bus_clk)
    , .din(wr_32_data), .wr_en(wr_32_wren)
    , .rd_en(pc_msg32_ack), .dout(pc_msg32)
    , .full(wr_32_full), .empty(pc_msg32_empty));
    
  xb_rd_fifo xb_rd_fifo(.rst(reset), .clk(bus_clk)
    , .din(n_frame)
    , .wr_en(n_frame != 0 && !xb_rd_fifo_full)
    , .rd_en(rd_32_rden), .dout(rd_32_data)
    , .full(xb_rd_fifo_full), .empty(rd_32_empty));
    
  xb_loopback_fifo(.rst(reset), .clk(bus_clk)
    , .din(wr_loop_data), .wr_en(loop_wren)
    , .rd_en(loop_rden), .dout(rd_loop_data)
    , .full(loop_full), .empty(loop_empty));
    
  assign GPIO_LED[7:4] = {wr_32_full, wr_32_open, !rd_32_empty, rd_32_open};

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg32_ack <= 0;
      n_frame <= 0;
    end else begin
      pc_msg32_ack <= `FALSE; //Default value
      
      if(!pc_msg32_empty && !pc_msg32_ack) begin // a message from PC!
        pc_msg32_ack <= `TRUE;
        n_frame <= pc_msg32;
      end else if(n_frame != 0 && !xb_rd_fifo_full) begin
        n_frame <= n_frame - 1'b1;
      end
    end
  end//always

endmodule
