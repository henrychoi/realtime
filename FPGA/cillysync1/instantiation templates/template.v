module template
  (
  input  PCIE_PERST_B_LS,
  input  PCIE_REFCLK_N,
  input  PCIE_REFCLK_P,
  input [3:0] PCIE_RX_N,
  input [3:0] PCIE_RX_P,
  output [3:0] GPIO_LED,
  output [3:0] PCIE_TX_N,
  output [3:0] PCIE_TX_P
  );
  // Clock and quiesce
  wire  bus_clk;
  wire  quiesce;


  // Wires related to /dev/xillybus_rd
  wire  user_r_rd_rden;
  wire  user_r_rd_empty;
  wire [31:0] user_r_rd_data;
  wire  user_r_rd_eof;
  wire  user_r_rd_open;

  // Wires related to /dev/xillybus_rd_loop
  wire  user_r_rd_loop_rden;
  wire  user_r_rd_loop_empty;
  wire [31:0] user_r_rd_loop_data;
  wire  user_r_rd_loop_eof;
  wire  user_r_rd_loop_open;

  // Wires related to /dev/xillybus_wr
  wire  user_w_wr_wren;
  wire  user_w_wr_full;
  wire [31:0] user_w_wr_data;
  wire  user_w_wr_open;


  xillybus xillybus_ins (

    // Ports related to /dev/xillybus_rd
    // FPGA to CPU signals:
    .user_r_rd_rden(user_r_rd_rden),
    .user_r_rd_empty(user_r_rd_empty),
    .user_r_rd_data(user_r_rd_data),
    .user_r_rd_eof(user_r_rd_eof),
    .user_r_rd_open(user_r_rd_open),


    // Ports related to /dev/xillybus_rd_loop
    // FPGA to CPU signals:
    .user_r_rd_loop_rden(user_r_rd_loop_rden),
    .user_r_rd_loop_empty(user_r_rd_loop_empty),
    .user_r_rd_loop_data(user_r_rd_loop_data),
    .user_r_rd_loop_eof(user_r_rd_loop_eof),
    .user_r_rd_loop_open(user_r_rd_loop_open),


    // Ports related to /dev/xillybus_wr
    // CPU to FPGA signals:
    .user_w_wr_wren(user_w_wr_wren),
    .user_w_wr_full(user_w_wr_full),
    .user_w_wr_data(user_w_wr_data),
    .user_w_wr_open(user_w_wr_open),


    // General signals
    .PCIE_PERST_B_LS(PCIE_PERST_B_LS),
    .PCIE_REFCLK_N(PCIE_REFCLK_N),
    .PCIE_REFCLK_P(PCIE_REFCLK_P),
    .PCIE_RX_N(PCIE_RX_N),
    .PCIE_RX_P(PCIE_RX_P),
    .GPIO_LED(GPIO_LED),
    .PCIE_TX_N(PCIE_TX_N),
    .PCIE_TX_P(PCIE_TX_P),
    .bus_clk(bus_clk),
    .quiesce(quiesce)
  );
endmodule
