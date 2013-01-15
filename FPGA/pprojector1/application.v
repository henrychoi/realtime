module application#(parameter XB_SIZE=1, ADDR_WIDTH=1, APP_DATA_WIDTH=1
, DELAY=1)
(input reset, dram_clk, output error, output heartbeat
, input app_rdy, output reg app_en, output reg dram_read
, output reg[ADDR_WIDTH-1:0] app_addr
, input app_wdf_rdy, output reg app_wdf_wren, app_wdf_end
, output reg[APP_DATA_WIDTH-1:0] app_wdf_data
, input app_rd_data_valid, input[APP_DATA_WIDTH-1:0] app_rd_data
, input bus_clk
, input pc_msg_empty, output pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid
, output reg[XB_SIZE-1:0] fpga_msg
);
`include "function.v"  
  localparam ERROR = 0, INIT = 1, READY = 2, N_STATE = 3;
  reg [log2(N_STATE)-1:0] state;
  
  
endmodule
