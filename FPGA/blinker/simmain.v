`timescale 1 ns / 1 ns
module simmain;
`include "function.v"
  wire[7:0] GPIO_LED;
  reg RESET, CLK;
  wire CLK_N;

  initial begin
    CLK <= `FALSE;
    RESET = `FALSE;
#2 RESET = `TRUE;
#6 RESET = `FALSE;
  end
  
  assign CLK_N = ~CLK;
  always #2 CLK <= ~CLK;

  main#(.SIMULATION(1), .DELAY(1))
    main(.RESET(RESET), .CLK_P(CLK), .CLK_N(CLK_N), .GPIO_LED(GPIO_LED));
endmodule
