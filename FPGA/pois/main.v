module main#(parameter SIMULATION=0, DELAY=1)
(input RESET, CLK_P, CLK_N, output[7:0] GPIO_LED);
`include "function.v"
  wire CLK;
  IBUFGDS sysclk_buf(.I(CLK_P), .IB(CLK_N), .O(CLK));
  application#(.DELAY(DELAY))
    app(.CLK(CLK), .RESET(RESET), .GPIO_LED(GPIO_LED));
endmodule
