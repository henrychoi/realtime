module application#(parameter XB_SIZE=1, FP_SIZE=1)
(input reset, clk, output error, output heartbeat
, output reg app_done
, input bus_clk, input pc_msg_empty, output pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[XB_SIZE-1:0] fpga_msg
);
`include "function.v"
  integer i;
  localparam HB_CTR_SIZE = 16;
  reg[HB_CTR_SIZE-1:0] hb_ctr;


endmodule
