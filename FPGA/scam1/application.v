`timescale 1 ps/1 ps

module application#(parameter SIMULATION=0, DELAY=1
, XB_SIZE=1,ADDR_WIDTH=1, APP_DATA_WIDTH=1)
(input RESET, CLK, output[7:4] GPIO_LED
, input PCIe_CLK
, input pc_msg_pending, output pc_msg_ack, input[XB_SIZE-1:0] pc_msg
, input fpga_msg_full, output reg fpga_msg_valid, output reg[XB_SIZE-1:0] fpga_msg
);
`include "function.v"
  assign GPIO_LED[7:4] = {app_rdy, dramifc_state};
endmodule
