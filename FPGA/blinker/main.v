module main#(parameter SIMULATION=0, DELAY=1)
(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));

  reg  [29:0] ctr;
  assign #DELAY GPIO_LED = {ctr[29-:4], 'b0000};
  
  always @(posedge CLK)
    if(RESET) ctr <= #DELAY 0;
    else ctr <= #DELAY ctr + `TRUE;
endmodule
