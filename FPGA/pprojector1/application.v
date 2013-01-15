module application#(parameter DELAY=1, XB_SIZE=32)
(input CLK, RESET, output[7:4] GPIO_LED
, input pc_msg_valid, input[XB_SIZE-1:0] pc_msg, output reg pc_msg_ack
, output reg fpga_msg_valid, output reg [XB_SIZE-1:0] fpga_msg);
`include "function.v"  
  localparam ERROR = 0, INIT = 1, READY = 2, N_STATE = 3;
  reg [log2(N_STATE)-1:0] state;
endmodule
