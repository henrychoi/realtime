module main#(parameter SIMULATION=0, DELAY=1)
(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED
, input PCIE_PERST_B_LS //The host's master bus reset
, input PCIE_REFCLK_N, PCIE_REFCLK_P
, input[3:0] PCIE_RX_N, PCIE_RX_P
, output[3:0] PCIE_TX_N, PCIE_TX_P
 );
`include "function.v"
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  
  // Xillybus signals
  localparam XB_SIZE = 32;
  wire bus_clk, quiesce
   , xb_rd_rden         //xb_rd_fifo -> xillybus
   , xb_rd_empty        //xb_rd_fifo -> xillybus
   , xb_rd_open         //xillybus -> xb_rd_fifo
   , fpga_msg_valid     //app -> xb_rd_fifo
   , fpga_msg_full, fpga_msg_overflow//xb_rd_fifo -> app
   , pc_msg_empty //xb_wr_fifo -> app; NOT of empty
   //, pc_msg_pending
   , pc_msg_ack         // app -> xb_wr_fifo
   , xb_wr_wren         // xillybus -> xb_wr_fifo
   , xb_wr_full, xb_wr_overflow// xb_wr_fifo -> xillybus
   , xb_wr_open         // xillybus -> xb_wr_fifo
   , xb_loop_rden       // xillybus -> xb_loop_fifo
   , xb_loop_empty      // xb_loop_fifo -> xillybus
   , xb_loop_full;      // xb_loop_fifo -> xillybus
  reg xb_rd_eof, pc_msg_pending_d;
  wire[XB_SIZE-1:0] xb_rd_data //xb_rd_fifo -> xillybus
   , xb_loop_data       // xb_loopback_fifo -> xillybus
   , xb_wr_data         // xillybus -> xb_wr_fifo
   , pc_msg;
  reg [XB_SIZE-1:0] pc_msg_d;
  wire[XB_SIZE-1:0] fpga_msg;//app -> xb_rd_fifo

  generate
    if(SIMULATION) begin: simulate_xb
      reg[XB_SIZE-1:0] xb_wr_data_r;//pc_msg_r;
      
      always #4000 bus_clk_r = ~bus_clk_r;
      assign bus_clk = bus_clk_r;
      //assign pc_msg = pc_msg_r;
      //assign pc_msg_empty = wr_data_empty_r;
      assign xb_wr_data = xb_wr_data_r;
      assign xb_wr_wren = xb_wr_wren_r;
      assign xb_rd_open = `TRUE;
      assign xb_rd_rden = `TRUE;
      assign xb_loop_rden = `TRUE;
      initial begin
        //bus_clk_r <= #DELAY `FALSE;
        //xb_wr_wren_r <= #DELAY `FALSE;
      end
    end else begin// !SIMULATION
      xillybus xb(.GPIO_LED(GPIO_LED[3:0]) //For debugging
        , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
        , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
        , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
        , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
        , .bus_clk(bus_clk), .quiesce(quiesce)

        , .user_r_rd_rden(xb_rd_rden), .user_r_rd_empty(xb_rd_empty)
        , .user_r_rd_data(xb_rd_data), .user_r_rd_open(xb_rd_open)
        , .user_r_rd_eof(xb_rd_eof)
                         
        , .user_w_wr_wren(xb_wr_wren)
        , .user_w_wr_full(xb_wr_full/*|| xb_loop_full*/)
        , .user_w_wr_data(xb_wr_data), .user_w_wr_open(xb_wr_open)
        
        , .user_r_rd_loop_rden(xb_loop_rden)
        , .user_r_rd_loop_empty(xb_loop_empty)
        , .user_r_rd_loop_data(xb_loop_data)
        , .user_r_rd_loop_open(xb_loop_open)
        , .user_r_rd_loop_eof(!xb_wr_open && xb_loop_empty)
        );

    `ifdef PR_THIS
      xb_loopback_fifo xb_loopback_fifo(.wr_clk(CLK), .rd_clk(bus_clk), .rst(rst)
        , .din(pc_msg_d), .wr_en(pc_msg_pending_d /*pc_msg_ack*/)
        , .rd_en(xb_loop_rden), .dout(xb_loop_data)
        , .full(xb_loop_full), .empty(xb_loop_empty));
    `endif
      xb_rd_fifo xb_rd_fifo(.rst(rst) //RESET
        , .wr_clk(CLK), .din(fpga_msg), .wr_en(fpga_msg_valid /*&& xb_rd_open*/)
        , .full(), .almost_full(fpga_msg_full), .overflow(fpga_msg_overflow)
        , .rd_clk(bus_clk), .rd_en(xb_rd_rden), .dout(xb_rd_data)
        , .empty(xb_rd_empty));
    end//!SIMULATION
  endgenerate

  xb_wr_fifo xb_wr_fifo(.rst(rst)
    , .wr_clk(bus_clk), .din(xb_wr_data), .wr_en(xb_wr_wren)
    , .full(), .almost_full(xb_wr_full), .overflow(xb_wr_overflow)
    , .rd_clk(clk), .rd_en(pc_msg_ack), .dout(pc_msg), .empty(pc_msg_empty));

//`define DEBUG_MAIN
`ifdef DEBUG_MAIN
  reg [27:0] bus_clk_ctr, dram_clk_ctr;
  assign GPIO_LED[7:4] = {app_rdy, bus_clk_ctr[27], dram_clk_ctr[27], rst};
  assign pc_msg_ack = !pc_msg_empty;
  assign fpga_msg = pc_msg;  
  assign fpga_msg_valid = !pc_msg_empty;
  
  always @(posedge bus_clk)
    if(rst) bus_clk_ctr <= #DELAY 0;
    else bus_clk_ctr <= #DELAY bus_clk_ctr + `TRUE;

  always @(posedge clk)
    if(rst) dram_clk_ctr <= #DELAY 0;
    else dram_clk_ctr <= #DELAY dram_clk_ctr + `TRUE;

`else
  application#(.SIMULATION(SIMULATION), .DELAY(DELAY), .XB_SIZE(XB_SIZE))
    app(//dram signals
      .CLK(CLK), .RESET(RESET), .GPIO_LED(GPIO_LED[7:4])
      //xillybus signals
      , .pc_msg_pending(!pc_msg_empty), .pc_msg_ack(pc_msg_ack), .pc_msg(pc_msg)
      , .fpga_msg_valid(fpga_msg_valid), .fpga_msg_full(rd_fifo_full)
      , .fpga_msg(fpga_msg)
      , .PCIe_CLK(bus_clk)
      );
`endif

  //assign pc_msg_pending = !pc_msg_empty;
  always @(posedge bus_clk)
    if(RESET) begin
      pc_msg_pending_d <= #DELAY `FALSE;
    end else begin
      xb_rd_eof <= #DELAY pc_msg_pending_d && (&pc_msg_d);
      pc_msg_pending_d <= #DELAY !pc_msg_empty;
      pc_msg_d <= #DELAY pc_msg;
    end
endmodule
