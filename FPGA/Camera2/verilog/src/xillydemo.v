`define TRUE 1'b1
`define FALSE 1'b0

module xillydemo(input CLK_P, CLK_N, reset
  // These come from Camera Link
  , input cl_fval, cl_x_pclk, cl_x_lval, cl_y_pclk, cl_y_lval, cl_z_pclk, cl_z_lval
  , input[7:0] cl_port_a, cl_port_b, cl_port_c, cl_port_d, cl_port_e
             , cl_port_f, cl_port_g, cl_port_h, cl_port_i, cl_port_j
  , input  PCIE_PERST_B_LS, //The host's master bus reset
  //For Virtex-6 a 250 MHz clock, which is derived from the PCIe bus clock,
  //is expected on these wires. If a different clock is applied, the Xilinx
  //PCIe Coregen core (defined by pcie v6 4x.xco in the bundle) must be
  //reconfigured to expect the real clock frequency. Such a change may also
  //involve changes in the constraints.
   input  PCIE_REFCLK_N, PCIE_REFCLK_P,
   input [3:0] PCIE_RX_N, PCIE_RX_P,
   output [7:0] GPIO_LED,
   output [3:0] PCIE_TX_N, PCIE_TX_P
   );
  wire bus_clk, quiesce;

`define FRAME_NUM_SIZE 20
  reg[`FRAME_NUM_SIZE-1:0] frame_num;
`define LINE_NUM_SIZE 12 // Enough for 1080 lines from Andor camera
  reg[`LINE_NUM_SIZE-1:0] line_num;
  //reg[2:0] fval_lval;
  wire[79:0] cl_val;
  wire[3:0] cl_meta;
  wire reassemble, x_fifo_empty, y_fifo_empty, z_fifo_empty;
  wire cl_fclk;
  reg bSend;
  wire[31:0] pc_msg32;
  // Wires related to /dev/xillybus_mem_8
  wire user_r_mem_8_rden, user_r_mem_8_empty, user_r_mem_8_eof
   , user_r_mem_8_open;
  reg [7:0]  user_r_mem_8_data;
  wire user_w_mem_8_wren, user_w_mem_8_full, user_w_mem_8_open;
  wire [7:0] user_w_mem_8_data;
  wire [4:0] user_mem_8_addr;
  wire       user_mem_8_addr_update;

  // Wires related to /dev/xillybus_read_8
  wire user_r_read_8_rden, user_r_read_8_empty, user_r_read_8_eof
   , user_r_read_8_open;
  wire[7:0] user_r_read_8_data;

  //Interface bet/ Xillybus and 32bit FIFO into my app
  wire user_w_write_32_wren, user_w_write_32_full, user_w_write_32_open;
  wire[31:0] user_w_write_32_data;
  // Wires related to /dev/xillybus_read_32
  wire user_r_read_32_rden, user_r_read_32_empty, user_r_read_32_eof
  , user_r_read_32_open;
  wire[31:0] user_r_read_32_data;
  reg pc_msg32_ack; //send ACK into FIFO to clear incoming data
  wire pc_msg32_empty;

  //IBUFGDS dsClkBuf(.O(clk), .I(CLK_P), .IB(CLK_N));

  xillybus xb(.GPIO_LED(GPIO_LED[3:0])
    , .PCIE_PERST_B_LS(PCIE_PERST_B_LS) // Signals to top level:
    , .PCIE_REFCLK_N(PCIE_REFCLK_N), .PCIE_REFCLK_P(PCIE_REFCLK_P)
    , .PCIE_RX_N(PCIE_RX_N), .PCIE_RX_P(PCIE_RX_P)
    , .PCIE_TX_N(PCIE_TX_N), .PCIE_TX_P(PCIE_TX_P)
    , .bus_clk(bus_clk), .quiesce(quiesce)

    // Ports related to /dev/xillybus_mem_8
    , .user_r_mem_8_rden(user_r_mem_8_rden) // FPGA to CPU signals
    , .user_r_mem_8_empty(user_r_mem_8_empty)
    , .user_r_mem_8_data(user_r_mem_8_data)
    , .user_r_mem_8_eof(user_r_mem_8_eof)
    , .user_r_mem_8_open(user_r_mem_8_open)
    , .user_w_mem_8_wren(user_w_mem_8_wren) // CPU to FPGA signals
    , .user_w_mem_8_full(user_w_mem_8_full)
    , .user_w_mem_8_data(user_w_mem_8_data)
    , .user_w_mem_8_open(user_w_mem_8_open)
    , .user_mem_8_addr(user_mem_8_addr) // Address signals
    , .user_mem_8_addr_update(user_mem_8_addr_update)

    , .user_r_read_8_rden(user_r_read_8_rden)  // /dev/xillybus_read_8
    , .user_r_read_8_empty(user_r_read_8_empty) // FPGA to CPU signals
    , .user_r_read_8_data(user_r_read_8_data)
    , .user_r_read_8_eof(user_r_read_8_eof)
    , .user_r_read_8_open(user_r_read_8_open)
    , .user_w_write_8_wren(user_w_write_8_wren) // /dev/xillybus_write_8
    , .user_w_write_8_full(user_w_write_8_full) // CPU to FPGA signals
    , .user_w_write_8_data(user_w_write_8_data)
    , .user_w_write_8_open(user_w_write_8_open)

    , .user_r_read_32_rden(user_r_read_32_rden)  // /dev/xillybus_read_32
    , .user_r_read_32_empty(user_r_read_32_empty)// FPGA to CPU signals
    , .user_r_read_32_data(user_r_read_32_data)
    , .user_r_read_32_eof(user_r_read_32_eof)
    , .user_r_read_32_open(user_r_read_32_open)
    , .user_w_write_32_wren(user_w_write_32_wren) // /dev/xillybus_write_32
    , .user_w_write_32_full(user_w_write_32_full) // CPU to FPGA signals
    , .user_w_write_32_data(user_w_write_32_data)
    , .user_w_write_32_open(user_w_write_32_open)
  );
  fifo_32b_2clk xb_wr_fifo(.rst(reset), .clk(bus_clk)//, .rd_clk(clk)
    , .din(user_w_write_32_data), .wr_en(user_w_write_32_wren)
    , .rd_en(pc_msg32_ack), .dout(pc_msg32)
    , .full(user_w_write_32_full), .empty(pc_msg32_empty));
  fifo_big232b xb_rd_fifo(.rst(reset), .wr_clk(bus_clk), .rd_clk(bus_clk)
    , .din({cl_val                       //                80 bits
            , 12'b000000000000, cl_meta  // 12 + 4 bits  = 96 bits
            , line_num, frame_num})      // 12 + 20 bits = 32 bits
    , .wr_en(reassemble), .rd_en(user_r_read_32_rden)
    , .dout(user_r_read_32_data), .full(), .empty(user_r_read_32_empty));
  cl_fifo x_fifo(.rst(reset), .wr_clk(cl_x_pclk), .rd_clk(bus_clk)
    , .wr_en(cl_x_pclk), .rd_en(reassemble)
    , .din({cl_port_d[1:0], cl_port_c, cl_port_b, cl_port_a, cl_x_lval, cl_fval})
    , .dout({cl_val[25:0], cl_meta[1:0]})
    , .full(/* TODO: reset HW */), .empty(x_fifo_empty));
  cl_fifo y_fifo(.rst(reset), .wr_clk(cl_y_pclk), .rd_clk(bus_clk)
    , .wr_en(cl_y_pclk), .rd_en(reassemble)
    , .din({cl_port_g[4:0], cl_port_f, cl_port_e, cl_port_d[7:2], cl_y_lval})
    , .dout({cl_val[52:26], cl_meta[2]})
    , .full(), .empty(y_fifo_empty));
  cl_fifo z_fifo(.rst(reset), .wr_clk(cl_z_pclk), .rd_clk(bus_clk)
    , .wr_en(cl_z_pclk), .rd_en(reassemble)
    , .din({cl_port_j, cl_port_i, cl_port_h, cl_port_g[7:5], cl_z_lval})
    , .dout({cl_val[79:53], cl_meta[3]})
    , .full(), .empty(z_fifo_empty));

  // GPIO_LED[0:3] are used by Xillybus
  assign GPIO_LED[7:4] = pc_msg32[3:0]; // Just show the last 4 bits
  assign reassemble = bSend
    & (~z_fifo_empty) & (~y_fifo_empty) & (~z_fifo_empty);

  always @(posedge reset, posedge bus_clk) begin
    if(reset) begin
      pc_msg32_ack <= `FALSE;
    end else begin
      pc_msg32_ack <= `FALSE;
      if(!pc_msg32_empty && !pc_msg32_ack) begin
        // Process the message
        pc_msg32_ack <= `TRUE;
      end
    end//posedge clk
  end//always

  always @(posedge reset, posedge cl_fval) begin
    if(reset) begin
      bSend <= `FALSE;
      frame_num <= 0;
      //fval_lval <= 3'b000;
    end else begin
      if(pc_msg32[1]) bSend <= `TRUE;
      if(bSend) bSend <= `FALSE;
      frame_num <= frame_num + 1'b1;
      //Q: does LVAL go high with FVAL?
      //fval_lval <= {cl_x_lval, cl_y_lval, cl_z_lval};
    end//posedge cl_fclk
  end//always
  
  always @(posedge cl_fval, posedge cl_x_lval) begin
    if(cl_fval) line_num <= 0;
    else line_num <= line_num + 1'b1;
  end//always

endmodule
