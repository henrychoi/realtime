`timescale 500 ps / 500 ps
module simmain;
`include "function.v"
  wire[7:0] GPIO_LED;
  reg RESET, CLK;
  wire CLK_N;

  initial begin
    CLK <= `FALSE;
    RESET = `FALSE;
#5 RESET = `TRUE;
#5 RESET = `FALSE;
  end
  
  assign CLK_N = ~CLK;
  always #5 CLK <= ~CLK;  
  
  main main(.RESET(RESET), .CLK_P(CLK), .CLK_N(CLK_N), .GPIO_LED(GPIO_LED));
endmodule
